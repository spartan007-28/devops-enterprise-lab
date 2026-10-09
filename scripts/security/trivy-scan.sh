#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <image> <report-name> <report-dir>" >&2
  exit 20
fi

image="$1"
report_name="$2"
report_dir="$3"
trivy_image="${TRIVY_IMAGE:-aquasec/trivy:0.67.2}"
expected_version="${TRIVY_VERSION:-0.67.2}"

mkdir -p "$report_dir"
trivy_cache_dir="${TRIVY_CACHE_DIR:-$report_dir/.trivy-cache}"
mkdir -p "$trivy_cache_dir"

run_trivy() {
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$(cd "$report_dir" && pwd):/reports" \
    -v "$(cd "$trivy_cache_dir" && pwd):/root/.cache/trivy" \
    "$trivy_image" "$@"
}

version_output="$(run_trivy --version)" || {
  echo "BLOCKED: Trivy technical failure while checking version" >&2
  exit 20
}
printf '%s\n' "$version_output" | grep -F "Version: ${expected_version}" >/dev/null || {
  echo "BLOCKED: expected Trivy ${expected_version}, got: ${version_output}" >&2
  exit 20
}

run_trivy image \
  --scanners vuln \
  --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL \
  --ignore-unfixed=false \
  --format json \
  --output "/reports/${report_name}.json" \
  "$image"

run_trivy image \
  --scanners vuln \
  --format cyclonedx \
  --output "/reports/${report_name}.cdx.json" \
  "$image"

node - "$report_dir/${report_name}.json" <<'NODE'
const fs = require('node:fs');
const file = process.argv[2];
try {
  const report = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!Array.isArray(report.Results)) throw new Error('missing Results');
  console.log(`${file}: Trivy report valid; results=${report.Results.length}`);
} catch (error) {
  console.error(`BLOCKED: invalid Trivy report ${file}: ${error.message}`);
  process.exit(20);
}
NODE
