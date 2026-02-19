#!/usr/bin/env bash
set -euo pipefail

rm -rf /usr/lib/tuned/profiles/accelerator-performance/
rm -rf /usr/lib/tuned/profiles/hpc-compute/
rm -rf /usr/lib/tuned/profiles/latency-performance/
rm -rf /usr/lib/tuned/profiles/powersave/
rm -rf /usr/lib/tuned/profiles/throughput-performance/
rm -rf /usr/lib/tuned/profiles/virtual-guest/
rm -rf /usr/lib/tuned/profiles/virtual-host/
rm -rf /usr/lib/tuned/profiles/desktop/
rm -rf /usr/lib/tuned/profiles/optimize-serial-console/
rm -rf /usr/lib/tuned/profiles/network-latency/
rm -rf /usr/lib/tuned/profiles/network-throughput/
rm -rf /usr/lib/tuned/profiles/intel-sst/
rm -rf /usr/lib/tuned/profiles/aws/
rm -rf /usr/lib/tuned/profiles/balanced/
rm -rf /usr/lib/tuned/profiles/balanced-battery/