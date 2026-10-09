# DEVOPS-03 — CI Foundation Assessment

Fecha: 2026-10-09<br>
Estado general: **IMPLEMENTADO LOCALMENTE; CI REMOTO PENDIENTE**

## Alcance

Se implementó una base de CI para Pull Requests y pushes a `main`. El pipeline valida calidad, auditoría npm, configuración Compose, construcción de las imágenes finales y de migraciones, escaneo Trivy y generación de SBOM. No publica imágenes, no despliega recursos y no utiliza AWS, secretos ni `pull_request_target`.

## Archivos creados o modificados

- `.github/workflows/ci.yml`: workflow con acciones de terceros fijadas a SHA, permisos `contents: read`, timeouts, artefactos con retención de 14 días y jobs de calidad, auditoría, contenedores, Compose y resumen.
- `docs/agent/tasks/devops-03-ci-foundation.md`: plan ejecutable, rutas, controles y criterios de aceptación.
- `scripts/security/npm-audit-report.sh`: conserva auditorías completa y de producción en JSON; distingue hallazgos de vulnerabilidad de fallos técnicos.
- `scripts/security/trivy-scan.sh`: valida Trivy `0.67.2`, genera JSON y CycloneDX SBOM, y usa caché local de la base de datos por ejecución.
- `scripts/security/evaluate-policy.sh`: aplica el gate de CRITICAL en imágenes y reporta HIGH de runtime y metadatos de npm.
- `.gitignore`: excluye `reports/`, que contiene salidas locales de auditoría y escaneo.

## Gates locales ejecutados

| Gate | Resultado | Evidencia |
|---|---|---|
| Sintaxis YAML | PASS | Ruby `YAML.load_file` sobre `.github/workflows/ci.yml` |
| `actionlint` | NOT RUN | herramienta no disponible localmente; requiere validación equivalente en GitHub o instalación autorizada |
| `npm ci` | PASS | instalación reproducible del lockfile |
| `npm run lint` | PASS | workspaces frontend/backend |
| `npm test` | PASS | 2 suites, 5 pruebas |
| `npm run build` | PASS | Vite, Prisma generate y Nest build |
| `docker compose config --quiet` | PASS | configuración válida |
| Docker frontend | PASS | `taskflow/frontend:ci` construida |
| Docker backend | PASS | `taskflow/backend:ci` construida |
| Docker migraciones | PASS | target `migrations` construida |
| Trivy/SBOM frontend | PASS técnico; hallazgos | Trivy `0.67.2`, JSON y CycloneDX generados |
| Trivy/SBOM backend | PASS técnico; hallazgos | Trivy `0.67.2`, JSON y CycloneDX generados |
| Trivy/SBOM migraciones | PASS técnico; hallazgos | Trivy `0.67.2`, JSON y CycloneDX generados |
| Evaluación de política | **BLOCKED** | salida `BLOCKED_CRITICAL`, código 10 |

El digest observado para `aquasec/trivy:0.67.2` fue `sha256:e2b22eac59c02003d8749f5b8d9bd073b62e30fefaef5b7c8371204e0a4b0c08`. La etiqueta se fija además mediante `TRIVY_VERSION` y el helper verifica la versión dentro del contenedor.

## Hallazgos de seguridad

### npm audit

La auditoría completa reportó 27 vulnerabilidades: 2 CRITICAL, 3 HIGH, 21 MODERATE y 1 LOW. La auditoría de producción reportó 3 HIGH, sin CRITICAL, MODERATE ni LOW. Los JSON se conservaron localmente bajo `reports/ci/` y el workflow los sube como artefacto.

Estos resultados describen el lockfile/workspace y no se interpretan como el contenido exacto de las imágenes finales.

### Trivy

Los reportes locales acumularon 5 CRITICAL, 40 HIGH, 69 MEDIUM y 47 LOW entre frontend, backend runtime y migraciones. Se detectó, entre otros:

- `tar` 7.5.16 con `CVE-2026-59873` CRITICAL en las tres imágenes; existe corrección reportada `7.5.19`.
- `tinypool` 1.1.1 con `CVE-2026-104848` y `CVE-2026-104849` CRITICAL en la imagen de migraciones; existen correcciones reportadas 2.1.1/2.1.2.
- En backend runtime, HIGH de OpenSSL (`libcrypto3`/`libssl3` 3.5.7-r0), `brace-expansion`, `ip-address`, `undici`, `tar` y `http-cache-semantics`; Trivy reportó correcciones para algunos paquetes y ninguna para `http-cache-semantics`.

No se aplicaron upgrades mayores ni exclusiones para forzar un resultado verde. El gate bloquea por política; la remediación de estas dependencias queda fuera del alcance seguro de esta implementación y requiere una tarea aprobada.

## Política CI implementada

- CRITICAL en cualquiera de las imágenes finales o de migraciones: bloquea.
- HIGH del runtime: queda visible y requiere revisión de exposición y mitigaciones.
- Vulnerabilidades de tooling/migraciones: se reportan separadamente y no se ocultan.
- Fallo técnico de Trivy o reporte inválido: bloquea; nunca se convierte en PASS.
- `npm audit` conserva los resultados completos y de producción; un hallazgo no se confunde con un escaneo de imagen.
- No hay excepciones generales en el workflow. Las excepciones futuras deben ser específicas, aprobadas y tener expiración.

## Riesgos y gaps

1. El gate remoto no se ejecutó en GitHub Actions; no existe evidencia de una corrida alojada.
2. Debe validarse en GitHub la resolución de cada SHA de action, los artefactos, la caché de npm, la disponibilidad de Docker en el runner y los límites de tiempo.
3. El pipeline queda bloqueado por vulnerabilidades CRITICAL reales. No se debe marcar CI como PASS hasta remediarlas o aprobar una excepción temporal explícita.
4. La base Trivy se descarga desde el contenedor fijado; el helper comparte caché dentro de la ejecución local/job para evitar descargas redundantes.

## Checks únicamente verificables en GitHub Actions

- Ejecución real en `pull_request` y `push` a `main`.
- Aplicación efectiva de permisos mínimos de `GITHUB_TOKEN`.
- Comportamiento con Pull Requests externos y ausencia de acceso a secretos.
- Subida y retención de artefactos en el runner hospedado.
- Resultado final de jobs y del resumen en la interfaz de GitHub.

## Reproducción local

```bash
npm ci
npm run lint
npm test
npm run build
docker compose config --quiet
docker build --tag taskflow/frontend:ci --file apps/frontend/Dockerfile .
docker build --tag taskflow/backend:ci --file apps/backend/Dockerfile .
docker build --target migrations --tag taskflow/migrate:ci --file apps/backend/Dockerfile .
scripts/security/npm-audit-report.sh reports/ci
scripts/security/trivy-scan.sh taskflow/frontend:ci trivy-frontend reports/ci
scripts/security/trivy-scan.sh taskflow/backend:ci trivy-backend reports/ci
scripts/security/trivy-scan.sh taskflow/migrate:ci trivy-migrate reports/ci
scripts/security/evaluate-policy.sh reports/ci
```
