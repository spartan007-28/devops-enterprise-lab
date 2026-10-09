# DEVOPS-03.4 — First Remote CI Fix Assessment

Fecha: 2026-10-09  
Estado: **CORRECCIÓN IMPLEMENTADA LOCALMENTE; NUEVA EJECUCIÓN REMOTA PENDIENTE**

## Diagnóstico

El primer Pull Request mostró que los jobs de calidad, auditoría, construcción Docker, aislamiento Prisma, Trivy/SBOM y Compose terminaron correctamente. `Evaluate security policy` falló con:

```text
Error: missing npm audit report: reports/ci/npm-audit-full.json
```

La causa fue aislamiento de filesystem entre jobs de GitHub Actions:

1. `audit-dependencies` ejecuta `scripts/security/npm-audit-report.sh reports/ci`.
2. El helper genera `npm-audit-full.json`, `npm-audit-production.json` y `npm-audit-status.json`.
3. `audit-dependencies` sube esos archivos como artifact `npm-audit-reports` usando `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02`.
4. `container-security` tenía un workspace limpio y ejecutaba `evaluate-policy.sh reports/ci` sin descargar el artifact.
5. `evaluate-policy.sh` exige ambos reportes npm y falla closed cuando falta cualquiera; no fabrica valores ni acepta reportes vacíos.

## Corrección aplicada

Sólo se modificó `.github/workflows/ci.yml`:

- `container-security` ahora declara `needs: audit-dependencies`.
- Se añadió `actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093` (`v4.3.0`), con:

```yaml
name: npm-audit-reports
path: reports/ci
```

- Antes de evaluar la política se añadieron comprobaciones `test -s` para:
  - `reports/ci/npm-audit-full.json`;
  - `reports/ci/npm-audit-production.json`;
  - `reports/ci/npm-audit-status.json`.

Si el artifact no existe, no se puede descargar o alguno de los reportes falta/está vacío, el job falla antes de `evaluate-policy.sh`. Se mantiene el comportamiento fail-closed.

No se modificaron Dockerfiles, Prisma, dependencias, scripts de generación ni umbrales de seguridad.

## Contrato de seguridad conservado

- CRITICAL en imágenes: sigue bloqueando mediante `BLOCKED_CRITICAL` y código distinto de cero.
- Fallo técnico, JSON inválido o reporte npm ausente: sigue bloqueando.
- HIGH residual: continúa como `PASS_WITH_REVIEW` con `humanApprovalRequired: true` cuando corresponde.
- El HIGH residual conocido de `deepmerge-ts` no se aprobó ni se ocultó.
- Trivy, SBOM y npm audit continúan siendo obligatorios.

## Validaciones locales

| Validación | Resultado | Evidencia |
|---|---|---|
| Sintaxis YAML | PASS | `ruby -e 'require "yaml"; YAML.load_file(...)'` |
| Sintaxis shell | PASS | `bash -n` sobre los tres helpers |
| Reportes npm reales | PASS | `reports/devops-03-1/npm-audit-full.json`, producción y status no vacíos |
| Evaluación con reportes completos | PASS_WITH_REVIEW | exit 0; `highCount=1`, `humanApprovalRequired=true`, `critical=0` |
| Fail-closed sin `npm-audit-full.json` | PASS | evaluación terminó con exit 1 y error explícito de reporte faltante |
| Patrones prohibidos | PASS | sin publicación, AWS, despliegue, privileged ni exclusiones generales |

La validación local no puede ejecutar `actions/download-artifact`; la transferencia real del artifact sólo se confirma en GitHub Actions.

## Riesgos pendientes

1. Debe ejecutarse nuevamente el Pull Request en GitHub para demostrar que el artifact se descarga en el job consumidor.
2. El workflow queda serializado entre auditoría y seguridad por `needs`; aumenta el tiempo del pipeline, pero garantiza disponibilidad y dependencia explícita.
3. GitHub Actions debe conservar el artifact `npm-audit-reports` hasta que finalice el job consumidor; la action de descarga fallará si el artifact no está disponible.
4. `PASS_WITH_REVIEW` no es aprobación humana automática; el HIGH residual requiere la revisión definida en el contrato vigente.

## Resultado

La corrección mínima está implementada y validada localmente. No se declara PASS remoto ni se afirma que el Pull Request haya sido corregido hasta observar una nueva ejecución real de GitHub Actions con `Evaluate security policy` completado y los reportes npm descargados.
