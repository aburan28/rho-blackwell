#!/usr/bin/env bash
# Entry point for the rho-blackwell image.
#
#   walk       (default) walk ECC2K-130 with the campaign's parameters, on the
#              GPU if one is visible and on the CPU otherwise; distinguished
#              points and a resumable checkpoint go to /data
#   bench      throughput only, no distinguished-point handling
#   test       the client's validation suite (CPU, no GPU needed)
#   planted    solve planted logarithms on small curves of the same family
#   ecc2k95    solve the retired ECC2K-95 challenge end to end (answer known)
#   nist       NIST P-256/P-384 rho bench (Blackwell sm_120 only)
#   help       this text
#
# Environment:
#   RUN_ID      16-bit seed salt (1-65535). Default: a random id in 20000-65535,
#               kept in /data/run-id so a restarted container resumes the same walks.
#               Two containers must never share one: identical seeds walk identical trails.
#   DP_WEIGHT   distinguished-point cutoff (default 32, as in the campaign)
#   THREADS     total walks; default: the audited 385,024 workers on an RTX PRO 6000,
#               the client's automatic choice elsewhere
#   CPU_THREADS host threads for the CPU fallback (default: all cores)
#   DEVICE      CUDA device index (default 0)
set -euo pipefail

mode=${1:-walk}
shift || true
DATA=${DATA:-/data}
mkdir -p "$DATA"
DP_WEIGHT=${DP_WEIGHT:-32}
DEVICE=${DEVICE:-0}

gpu_name() {
    command -v nvidia-smi >/dev/null 2>&1 || return 1
    nvidia-smi --query-gpu=name --format=csv,noheader -i "$DEVICE" 2>/dev/null | head -n 1
}

run_id() {
    if [ -n "${RUN_ID:-}" ]; then echo "$RUN_ID"; return; fi
    if [ -s "$DATA/run-id" ]; then cat "$DATA/run-id"; return; fi
    local id=$(( 20000 + RANDOM % 45536 ))
    echo "$id" > "$DATA/run-id"
    echo "$id"
}

gpu_args() {
    local name=$1
    local args=(--packed --device "$DEVICE")
    if [ -n "${THREADS:-}" ]; then
        args+=(--threads "$THREADS")
    elif [[ "$name" == *"RTX PRO 6000"* ]]; then
        args+=(--threads 385024)
    fi
    echo "${args[@]}"
}

case "$mode" in
walk)
    rid=$(run_id)
    common=(--curve 131 --launches 0 --run-id "$rid" --dp-weight "$DP_WEIGHT"
            --dp-file "$DATA/dp-$rid.bin" --checkpoint "$DATA/checkpoint-$rid"
            --checkpoint-every 600 --verify 0 --max-iters 4294967296 --dp-cap 65536)
    if name=$(gpu_name) && [ -n "$name" ]; then
        echo "ECC2K-130 walk on $name, run id $rid, cutoff $DP_WEIGHT; output in $DATA"
        # shellcheck disable=SC2046
        exec ecc2k130 "${common[@]}" --steps 1024 $(gpu_args "$name") "$@"
    fi
    echo "no GPU visible: ECC2K-130 walk on the CPU, run id $rid, cutoff $DP_WEIGHT; output in $DATA"
    exec ecc2k130-cpu "${common[@]}" --steps 64 --threads "${CPU_THREADS:-$(nproc)}" "$@"
    ;;
bench)
    if name=$(gpu_name) && [ -n "$name" ]; then
        echo "throughput on $name"
        # shellcheck disable=SC2046
        exec ecc2k130 --curve 131 --bench --steps 1024 --launches 32 $(gpu_args "$name") "$@"
    fi
    exec ecc2k130-cpu --curve 131 --bench --steps 64 --launches 32 --threads "${CPU_THREADS:-$(nproc)}" "$@"
    ;;
test)
    exec ecc2k130-cpu --curve 131 --test "$@"
    ;;
planted)
    for i in 0 1 2 3; do
        ecc2k130-cpu --curve 41 --instance "$i" --threads "${CPU_THREADS:-$(nproc)}" --steps 64 --verify 2 \
            | grep -E "planted|MISMATCH|solved"
    done
    ;;
ecc2k95)
    if name=$(gpu_name) && [ -n "$name" ]; then
        exec ecc2k130 --curve 97 --launches 0 --dp-file "$DATA/ecc2k95.bin" --device "$DEVICE" "$@"
    fi
    exec ecc2k130-cpu --curve 97 --launches 0 --dp-file "$DATA/ecc2k95.bin" \
        --threads "${CPU_THREADS:-$(nproc)}" "$@"
    ;;
nist)
    exec nist-bench "${1:-256}" rho "${2:-16}" "${3:-8192}"
    ;;
help|-h|--help)
    sed -n '2,25p' "$0"
    ;;
*)
    exec "$mode" "$@"
    ;;
esac
