#!/usr/bin/env bash
set -euo pipefail

report_dir="${1:-reports/ci}"
mkdir -p "$report_dir"

run_audit() {
  local report_name="$1"
  shift
  local audit_exit

  set +e
  npm audit "$@" --json >"$report_dir/$report_name.json"
  audit_exit=$?
  set -e

  set +e
  node - "$report_dir/$report_name.json" "$audit_exit" <<'NODE'
const fs = require('node:fs');
const [file, exitCode] = process.argv.slice(2);
try {
  const audit = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!audit.metadata || !audit.vulnerabilities) {
    console.error(`TECHNICAL_FAILURE: invalid npm audit shape in ${file}`);
    process.exit(20);
  }
  const severity = audit.metadata.vulnerabilities;
  console.log(`${file}: npm_exit=${exitCode} total=${severity.total ?? 0} critical=${severity.critical ?? 0} high=${severity.high ?? 0} moderate=${severity.moderate ?? 0} low=${severity.low ?? 0}`);
  process.exit(Number(exitCode) > 1 ? 20 : Number(exitCode) === 1 ? 10 : 0);
} catch (error) {
  console.error(`TECHNICAL_FAILURE: could not parse ${file}: ${error.message}`);
  process.exit(20);
}
NODE
  local report_status=$?
  return "$report_status"
}

set +e
run_audit npm-audit-full
full_status=$?
run_audit npm-audit-production --omit=dev
production_status=$?
set -e

node - "$report_dir" "$full_status" "$production_status" <<'NODE'
const fs = require('node:fs');
const [dir, fullStatus, productionStatus] = process.argv.slice(2);
const result = {
  full: { file: `${dir}/npm-audit-full.json`, status: Number(fullStatus) },
  production: { file: `${dir}/npm-audit-production.json`, status: Number(productionStatus) },
  classification: 'clean',
};
if ([result.full.status, result.production.status].includes(20)) {
  result.classification = 'technical-failure';
} else if ([result.full.status, result.production.status].includes(10)) {
  result.classification = 'vulnerability-findings';
}
fs.writeFileSync(`${dir}/npm-audit-status.json`, `${JSON.stringify(result, null, 2)}\n`);
console.log(`npm audit classification=${result.classification}`);
process.exit(result.classification === 'technical-failure' ? 20 : result.classification === 'vulnerability-findings' ? 10 : 0);
NODE
