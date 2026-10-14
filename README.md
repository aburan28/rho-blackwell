# rho-blackwell

Code, data and evidence for the paper **"Accelerating Pollard Rho with GPU Field
Arithmetic on NVIDIA Blackwell"**
([`paper/rho-blackwell.pdf`](paper/rho-blackwell.pdf)).

The paper measures what Pollard rho costs on current NVIDIA hardware with the
Certicom challenge ECC2K-130 as the yardstick: 14.64 billion iterations per
second on one RTX PRO 6000 Blackwell in the audited campaign build (15.88 in the
best later build), about 230 times the best published 2010 GPU kernel, built
around the carry-less multiply that CUDA 13.3 exposes in PTX (`clmad`).

## Status

This snapshot is not yet public. The CPU client, its validation suite, a
planted-logarithm solve and every mode of the entry point have been run from
this copy of the source; the Docker image itself has not yet been built, and its
GPU modes have not been run. The commands below are the intended workflow and
will be checked before release.

## Run it

The Docker image builds the client with CUDA 13.3 for Ampere, Ada, Hopper and
both Blackwell families and, by default, starts walking ECC2K-130 with the
campaign's parameters.

```sh
docker build -t rho-blackwell -f docker/Dockerfile .
docker run --gpus all -v rho-data:/data rho-blackwell        # walk ECC2K-130 (default)
docker run --gpus all rho-blackwell bench                     # throughput only
docker run rho-blackwell test                                  # validation suite, CPU
docker run rho-blackwell planted                               # planted logs on small curves
docker run --gpus all rho-blackwell ecc2k95                    # ECC2K-95 end to end (answer known)
docker run --gpus all rho-blackwell nist                       # NIST P-256/P-384 rho bench (sm_120)
docker run rho-blackwell help
```

`walk` uses the GPU when one is visible and the CPU otherwise. Distinguished
points (32-byte records) and a resumable checkpoint go to `/data`; a restarted
container with the same volume resumes its walks. Each container picks a random
run identifier in 20000–65535, keeps it in `/data/run-id` and warns that it did
so. Two containers with the same identifier walk the same trails, and random
choices collide with probability about 0.1% for 10 containers, 10% for 100 and
63% for 300, so give every container of a multi-container run its own `RUN_ID`. Other settings: `DP_WEIGHT` (default 32), `THREADS` (default:
the audited 385,024 workers on an RTX PRO 6000, automatic elsewhere),
`CPU_THREADS`, `DEVICE`.

Build arguments: `ARCHES` (default `"80 86 89 90 100 120"`; each architecture
adds several minutes of `ptxas`), `CLMAD` (default 1; Turing has no `clmad`, so
build it separately with `ARCHES=75 CLMAD=0`), `CPU_MARCH` (default
`x86-64-v3`; `x86-64-v4` enables AVX-512 in the CPU fallback).

A single container is very unlikely to find a collision on its own: the
expected work is 2^60.9 iterations, about five RTX PRO 6000 GPU-years. A
collision is found by merging the distinguished points of many walkers that used
the same cutoff. The paper's Section 16 sizes a fleet: five RTX PRO 6000s expect a
collision in about a year, 56 in a month, and a thousand in about three days,
half of which is the delay before the last trail reaches a distinguished point
at cutoff 32.

## What is here

| directory | contents |
|---|---|
| `paper/` | LaTeX source, figures (TikZ/pgfplots, in `figures/`), bibliography, built PDF. `make` builds it; `make figures-export` writes SVG and PNG copies of the figures. |
| `ecc2k130/` | The ECC2K-130 client: CUDA and CPU from one source, the field code generator, generated field routines, and the toy walk in `examples/`. |
| `nist/` | NIST P-256/P-384 field arithmetic and the Pollard-rho kernel; `make test` runs the CPU checks, `make bench` the GPU bench. |
| `docker/` | `Dockerfile` and the entry point. |
| `benchmarks/` | Data and plotting source behind the NIST batch-width figure; `solvetime/solvetime.py`, the arithmetic behind the paper's time-to-solve section. |
| `evidence/` | The paper's evidence records: `E01-…` to `E80-…`, numbered as in the paper's Appendix B, with `map.json` naming the original file of each. |

### Building without Docker

```sh
cd ecc2k130
make cpu MARCH=native                       # CPU client: ./ecc2k130-cpu
./ecc2k130-cpu --curve 131 --test           # validation suite
make gpu-rtx-pro6000-sigma-fused            # GPU: fused sigma walk (15.44 measured)
make gpu-rtx-pro6000-sigma-table            # GPU: nibble-table sigma walk (15.88 measured)
make gpu-b200-19b                           # GPU: B200 table-walk preset (pre-v3 cycle rule)
make gpu-local-packed                       # GPU: RTX PRO 4500 x-only bridge map
./ecc2k130 --help
```

The GPU builds need CUDA 13.3 or newer. The audited campaign preset (the build
the Docker image uses) is the knob set in `docker/Dockerfile`. Some Makefile
targets drive measurements on Modal or AWS through scripts that live in the
development repository and are not included here.

## Provenance

This repository is a release snapshot. The work was developed in three
repositories, `aburan28/crypto` (client, campaign, measurements),
`aburan28/cryptanalysis` (independent C model, packed CPU client)
and `aburan28/crypto-autoresearcher` (research ledger); `evidence/map.json`
records where each evidence file came from. AWS account identifiers in the
operations records are redacted.

No license file is included yet; licensing is the owner's decision.
