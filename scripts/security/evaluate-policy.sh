#!/usr/bin/env bash
set -euo pipefail

report_dir="${1:-reports/ci}"
summary_md="$report_dir/security-policy-summary.md"
summary_json="$report_dir/security-policy-summary.json"

node - "$report_dir" "$summary_md" "$summary_json" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const [dir, markdownFile, jsonFile] = process.argv.slice(2);
const imageReports = [
  ['frontend', 'trivy-frontend.json'],
  ['backend-runtime', 'trivy-backend.json'],
  ['migrations-tooling', 'trivy-migrate.json'],
];
const counts = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, UNKNOWN: 0 };
const findings = [];

for (const [context, filename] of imageReports) {
  const file = path.join(dir, filename);
  if (!fs.existsSync(file)) throw new Error(`missing Trivy report: ${file}`);
  const report = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!Array.isArray(report.Results)) throw new Error(`invalid Trivy report: ${file}`);
  for (const result of report.Results) {
    for (const vulnerability of result.Vulnerabilities ?? []) {
      const severity = vulnerability.Severity ?? 'UNKNOWN';
      counts[severity] = (counts[severity] ?? 0) + 1;
      findings.push({
        context,
        target: result.Target,
        vulnerabilityID: vulnerability.VulnerabilityID,
        pkg: vulnerability.PkgName,
        installedVersion: vulnerability.InstalledVersion,
        fixedVersion: vulnerability.FixedVersion ?? null,
        severity,
        title: vulnerability.Title ?? null,
      });
    }
  }
}

const npm = {};
for (const [key, filename] of [['full', 'npm-audit-full.json'], ['production', 'npm-audit-production.json']]) {
  const file = path.join(dir, filename);
  if (!fs.existsSync(file)) throw new Error(`missing npm audit report: ${file}`);
  const report = JSON.parse(fs.readFileSync(file, 'utf8'));
  npm[key] = report.metadata?.vulnerabilities ?? null;
}

const critical = findings.filter((finding) => finding.severity === 'CRITICAL');
const high = findings.filter((finding) => finding.severity === 'HIGH');
const runtimeHigh = findings.filter((finding) => finding.severity === 'HIGH' && finding.context === 'backend-runtime');
const decision = critical.length > 0 ? 'BLOCKED_CRITICAL' : 'PASS_WITH_REVIEW';
const output = { decision, imageCounts: counts, critical, highCount: high.length, high, runtimeHigh, humanApprovalRequired: high.length > 0, npm };
fs.writeFileSync(jsonFile, `${JSON.stringify(output, null, 2)}\n`);

const lines = [
  '# CI security policy summary',
  '',
  `Decision: **${decision}**`,
  '',
  '## Image findings',
  '',
  '| Severity | Count |',
  '|---|---:|',
  ...Object.entries(counts).map(([severity, count]) => `| ${severity} | ${count} |`),
  '',
  `CRITICAL image findings: ${critical.length} (blocker: ${critical.length > 0 ? 'yes' : 'no'})`,
  `HIGH image findings: ${high.length} (human approval required: ${high.length > 0 ? 'yes' : 'no'})`,
  `HIGH backend-runtime findings requiring exposure review: ${runtimeHigh.length}`,
  '',
  '## npm audit metadata',
  '',
  '```json',
  JSON.stringify(npm, null, 2),
  '```',
  '',
  'npm audit results are lockfile/workspace evidence and are not treated as the exact contents of final images.',
];
fs.writeFileSync(markdownFile, `${lines.join('\n')}\n`);
console.log(`security policy decision=${decision}`);
process.exit(critical.length > 0 ? 10 : 0);
NODE
