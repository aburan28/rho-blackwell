# Pollard rho on NVIDIA Blackwell: the ECC2K-130 client and the NIST rho bench.
#
#   docker build -t rho-blackwell -f docker/Dockerfile .
#   docker run --gpus all -v rho-data:/data rho-blackwell            # walk ECC2K-130
#   docker run --gpus all rho-blackwell bench                         # throughput only
#   docker run rho-blackwell test                                      # CPU validation suite
#
# Native carry-less multiplication (clmad) needs CUDA 13.3 or newer, so both
# stages use the 13.3.1 images. ARCHES picks the GPU generations compiled
# into the fat binary; each one costs several minutes of ptxas time.
#   80 86 = Ampere, 89 = Ada, 90 = Hopper, 100 = B200/B300, 120 = RTX PRO / RTX 50.
# Turing (75) has no clmad: build it separately with ARCHES=75 CLMAD=0.

ARG CUDA_VERSION=13.3.1
ARG UBUNTU=ubuntu24.04

FROM nvidia/cuda:${CUDA_VERSION}-devel-${UBUNTU} AS build
ARG ARCHES="80 86 89 90 100 120"
ARG CLMAD=1
# The CPU fallback client: x86-64-v3 is AVX2; x86-64-v4 enables AVX-512.
ARG CPU_MARCH=x86-64-v3
RUN apt-get update -q && apt-get install -y -q --no-install-recommends \
        build-essential python3 && rm -rf /var/lib/apt/lists/*
COPY ecc2k130 /src/ecc2k130
COPY nist /src/nist
WORKDIR /src/ecc2k130
# The audited RTX PRO 6000 campaign preset (sigma walk, batch 16, 256-thread
# blocks, native carry-less products, 256-worker tiles, compact state, shared
# Frobenius masks). WITNESS=0 keeps distinguished-point records at 32 bytes.
ENV KNOBS="BATCH=16 THREADS=256 MINBLOCKS=2 PACKED_SINGLE_PRODUCT=1 PACKED_CACHE_DENOM=1 \
PACKED_BY_VALUE=1 PACKED_PERM_SIGMA=3 PACKED_POLY_CHAIN=1 PACKED_UNROLL_INV=1 \
PACKED_PAIR_PRODUCTS=1 PACKED_POLY_STATE=1 PACKED_DIRECT_REDUCE=1 PACKED_GENERATED_PRODUCT=1 \
PACKED_STATE_TILE=256 PACKED_WEIGHTED_PREFIX=2 PACKED_COMPACT_STATE=1 PACKED_SHARED_SIGMA=1 \
WALK_TABLE=0 TABLE_BRANCHES=8 WITNESS=0"
RUN gencode=""; for a in $ARCHES; do gencode="$gencode -gencode arch=compute_$a,code=sm_$a"; done; \
    (cd codegen && python3 gen.py --out ../generated --leaf 0) && \
    make gpu ARCH="$gencode" $KNOBS PACKED_CLMAD=$CLMAD && \
    make cpu MARCH=$CPU_MARCH $KNOBS && \
    ./ecc2k130-cpu --curve 131 --test
WORKDIR /src/nist
RUN make test_rho && ./test_rho && make bench ARCH=sm_120 NIST_PTX=1

FROM nvidia/cuda:${CUDA_VERSION}-runtime-${UBUNTU}
RUN apt-get update -q && apt-get install -y -q --no-install-recommends libgomp1 \
        && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/ecc2k130/ecc2k130 /src/ecc2k130/ecc2k130-cpu /opt/rho/bin/
COPY --from=build /src/nist/bench /opt/rho/bin/nist-bench
COPY docker/entrypoint.sh /opt/rho/entrypoint.sh
ENV PATH=/opt/rho/bin:$PATH
VOLUME /data
WORKDIR /data
ENTRYPOINT ["/opt/rho/entrypoint.sh"]
CMD ["walk"]
