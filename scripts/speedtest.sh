#!/bin/sh
# Internet speed test against Cloudflare's public speed endpoints
# (the same ones speed.cloudflare.com uses).
#
# usage: speedtest.sh [dl_secs] [ul_secs] [dl_budget_bytes] [ul_budget_bytes]
#
# Prints one record per line (speeds in bytes per second):
#   META|<json>             ISP / server location
#   PHASE|ping|download|upload
#   PING|median_ms|jitter_ms
#   DLP|bps   ULP|bps       live speed, every 0.5 s
#   DL|bps|bytes  UL|bps|bytes
#   DONE      ERR|message
export LC_ALL=C

BASE=https://speed.cloudflare.com
DL_SECS=${1:-10}
UL_SECS=${2:-8}
DL_BUDGET=${3:-300000000}
UL_BUDGET=${4:-100000000}
DL_STREAMS=4
UL_STREAMS=3
DL_CHUNK=25000000   # the endpoint refuses requests of 100 MB and more
UL_CHUNK=10000000

tmp=$(mktemp -d) || exit 1
pids=""

stop_workers() {
    for p in $pids; do
        pkill -P "$p" 2>/dev/null
        kill "$p" 2>/dev/null
    done
    pids=""
}
cleanup() {
    stop_workers
    rm -rf "$tmp"
}
trap 'cleanup; exit 130' INT TERM
trap cleanup EXIT

now_ms() { date +%s%3N; }

iface=$(ip -o route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}')

# Byte counter of the default-route interface; $1 = 1 (rx) or 9 (tx)
counter() {
    [ -n "$iface" ] || { echo 0; return; }
    sed -n "s/^ *$iface://p" /proc/net/dev | awk -v c="$1" '{ printf "%d", $c }'
}

worker() { # kind end_ms id
    while :; do
        rem=$(($2 - $(now_ms)))
        [ "$rem" -le 200 ] && break
        secs=$(awk -v r="$rem" 'BEGIN { printf "%.2f", r / 1000 }')
        if [ "$1" = down ]; then
            curl -s -o /dev/null --max-time "$secs" -w '%{size_download}\n' "$BASE/__down?bytes=$DL_CHUNK" >>"$tmp/down.$3"
        else
            head -c "$UL_CHUNK" /dev/zero |
                curl -s -o /dev/null --max-time "$secs" -w '%{size_upload}\n' --data-binary @- "$BASE/__up" >>"$tmp/up.$3"
        fi
        rc=$?
        # back off a little if the request failed outright
        [ "$rc" -ne 0 ] && [ "$rc" -ne 28 ] && sleep 0.3
    done
}

run_phase() { # kind secs budget streams live_tag final_tag
    kind=$1 secs=$2 budget=$3 n=$4
    col=1
    [ "$kind" = up ] && col=9
    start=$(now_ms)
    end=$((start + secs * 1000))
    warm=$((start + secs * 250)) # skip the first quarter (TCP ramp-up)

    i=0
    while [ "$i" -lt "$n" ]; do
        worker "$kind" "$end" "$i" &
        pids="$pids $!"
        i=$((i + 1))
    done

    c0=$(counter $col)
    prev=$c0 prevt=$start c=$c0 t=$start cw="" tw=""
    while :; do
        sleep 0.5
        t=$(now_ms)
        c=$(counter $col)
        [ "$t" -gt "$prevt" ] && echo "$5|$(((c - prev) * 1000 / (t - prevt)))"
        prev=$c prevt=$t
        if [ -z "$cw" ] && [ "$t" -ge "$warm" ]; then
            cw=$c tw=$t
        fi
        [ $((c - c0)) -ge "$budget" ] && break
        [ "$t" -ge "$end" ] && break
        alive=0
        for p in $pids; do kill -0 "$p" 2>/dev/null && alive=1; done
        [ "$alive" = 0 ] && break
    done
    stop_workers
    wait 2>/dev/null

    if [ -n "$iface" ]; then
        used=$((c - c0))
    else
        used=$(cat "$tmp/$kind".* 2>/dev/null | awk '{ s += $1 } END { printf "%d", s }')
    fi
    if [ -n "$cw" ] && [ "$t" -gt "$tw" ] && [ -n "$iface" ]; then
        rate=$(((c - cw) * 1000 / (t - tw)))
    else
        rate=$((used * 1000 / (t - start + 1)))
    fi
    echo "$6|$rate|$used"
}

# ── Server / ISP info ──
meta=$(curl -s --max-time 5 -H "Referer: $BASE/" "$BASE/meta" | tr -d '\n')
[ -n "$meta" ] && echo "META|$meta"

# ── Latency: 10 requests on one connection; the first includes the TLS handshake ──
echo "PHASE|ping"
urls=""
i=0
while [ "$i" -lt 10 ]; do
    urls="$urls $BASE/__down?bytes=0"
    i=$((i + 1))
done
# shellcheck disable=SC2086
curl -s --max-time 10 -w '%{time_pretransfer} %{time_starttransfer}\n' $urls >"$tmp/ping" 2>/dev/null
ping=$(awk 'NR > 1 && NF == 2 { v[n++] = ($2 - $1) * 1000 }
    END {
        if (n == 0) exit
        for (i = 1; i < n; i++) jit += (v[i] > v[i-1] ? v[i] - v[i-1] : v[i-1] - v[i])
        for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (v[j] < v[i]) { t = v[i]; v[i] = v[j]; v[j] = t }
        printf "%.0f|%.1f", v[int(n / 2)], (n > 1 ? jit / (n - 1) : 0)
    }' "$tmp/ping")
if [ -z "$ping" ]; then
    echo "ERR|Could not reach speed.cloudflare.com"
    exit 1
fi
echo "PING|$ping"

echo "PHASE|download"
run_phase down "$DL_SECS" "$DL_BUDGET" "$DL_STREAMS" DLP DL

echo "PHASE|upload"
run_phase up "$UL_SECS" "$UL_BUDGET" "$UL_STREAMS" ULP UL

echo "DONE"
