# DEVOPS-03.6 — Prisma migrations HIGH remediation assessment

## Estado

**PASS REMEDIATED LOCAL** para las imágenes finales construidas localmente en ARM64.

La vulnerabilidad HIGH de `deepmerge-ts` dejó de estar presente en la imagen de migraciones. No se realizaron commits, pushes, merges, cambios remotos, operaciones AWS ni modificaciones a migraciones históricas.

## Diagnóstico y causa raíz

El reporte Trivy de DEVOPS-03.1 identificaba `CVE-2026-40345` en `deepmerge-ts@7.1.5` dentro de `taskflow/migrate:remediation`. La ruta efectiva era:

```text
prisma@6.19.3
└── @prisma/config@6.19.3
    └── deepmerge-ts@7.1.5
```

La imagen de migraciones requiere Prisma CLI y `@prisma/config` durante `prisma migrate deploy`; por tanto, eliminar `deepmerge-ts` únicamente desde la imagen no era compatible con el contrato. `tinypool` no estaba presente en la imagen final. Las imágenes frontend y backend runtime ya eliminaban las dependencias de tooling no necesarias.

La evidencia externa consultada describe un agotamiento de pila por grafos recursivos en versiones anteriores a `8.0.0`, con `8.0.0` como versión corregida: [GitHub Advisory Database](https://github.com/advisories/GHSA-ggr8-5vv4-36mx), [referencia del issue de Prisma](https://github.com/prisma/orm/issues/30052).

## Alternativas evaluadas

| Alternativa | Resultado |
|---|---|
| Override consumidor `deepmerge-ts@8.0.0` | Compatible en pruebas aisladas y en el workspace; seleccionada como cambio mínimo. |
| Eliminar más dependencias de la imagen | No elimina la dependencia necesaria de `@prisma/config` durante migraciones. |
| Actualizar Prisma | No se realizó; habría ampliado el cambio y el contrato exige conservar Prisma 6. |
| Aceptar el HIGH | Rechazada; no se alteró la política ni se simuló aprobación humana. |

## Cambios realizados

- `package.json`: se añadió el override exacto `deepmerge-ts: 8.0.0`.
- `package-lock.json`: se actualizó de forma consistente el override raíz, la dependencia efectiva de `@prisma/config` y la integridad/tarball de `deepmerge-ts@8.0.0`.

No se modificaron `Dockerfile`, `docker-compose.yml`, `schema.prisma` ni `apps/backend/prisma/migrations/`.

## Vulnerabilidades antes y después

Conteos Trivy con `aquasec/trivy:0.67.2`, `--ignore-unfixed=false`:

| Imagen | Antes C/H/M/L | Después C/H/M/L | Resultado |
|---|---:|---:|---|
| frontend | 0/0/0/0 | 0/0/0/0 | Sin hallazgos reportados |
| backend runtime | 0/0/0/0 | 0/0/0/0 | Sin hallazgos reportados |
| migraciones Prisma | 0/1/0/0 | 0/0/0/0 | `CVE-2026-40345` corregido |

La imagen remediada `taskflow/migrate:devops-03-6` fue inspeccionada como Linux ARM64, usuario efectivo UID 1000, Prisma `6.19.3`, Node `24.20.0`, `deepmerge-ts@8.0.0` y sin `tinypool`.

`npm audit` completo permanece separado del contenido efectivo de las imágenes: después registra `2 CRITICAL`, `0 HIGH`, `21 MODERATE` y `1 LOW`, asociados al grafo completo de desarrollo/tooling; el audit de producción registra `0` vulnerabilidades. Estos hallazgos no se ocultaron ni se usó `npm audit fix --force`.

## Pruebas ejecutadas

| Gate | Resultado | Evidencia |
|---|---|---|
| `npm ci --ignore-scripts --no-audit --no-fund` | PASS con warning | Lockfile aceptado; el entorno local es Node 24.19.0/npm 11.17.0 y el proyecto fija Node 24.20.0/npm 11.19.0. |
| `npm run lint` | PASS | Frontend y backend sin errores. |
| `npm run db:generate` | PASS | Prisma Client 6.19.3 generado. |
| `npm test` | PASS | Frontend 1 test; backend 2 suites y 5 tests. |
| `npm run build` | PASS | Frontend y backend compilados. |
| `docker compose config --quiet` | PASS | Configuración válida. |
| Builds Docker | PASS | Frontend, backend y target `migrations` construidos para ARM64. |
| Prisma CLI en imagen | PASS | Prisma 6.19.3; `deepmerge-ts` 8.0.0. |
| Migración inicial | PASS | PostgreSQL temporal con tmpfs; `20261009120000_init` aplicada. |
| Migración idempotente | PASS | Segunda ejecución: `No pending migrations to apply`. |
| Liveness/readiness | PASS | `/health/live` y `/health/ready` respondieron 200; readiness confirmó `database: ok`. |
| Trivy + SBOM | PASS | Tres imágenes; JSON y CycloneDX generados en `reports/devops-03-6/`. |
| Evaluación de política | PASS_WITH_REVIEW, exit 0 | 0 CRITICAL y 0 HIGH en imágenes; `humanApprovalRequired=false`. |

La primera comprobación directa del backend sin el comando de Compose falló porque el `CMD` de la imagen apunta a `/app/dist/main.js`, mientras que la imagen copia el artefacto en `/app/apps/backend/dist/main.js`; la verificación válida se repitió usando el comando explícito del Compose y pasó. Esto queda como gap operativo separado, no como resultado de seguridad de esta remediación.

## Riesgos y gaps pendientes

- El audit completo conserva vulnerabilidades CRITICAL/MODERATE de tooling; la política actual las reporta separadamente del contenido runtime y deben mantenerse visibles en CI.
- La validación local fue ARM64/macOS. La ejecución remota Linux amd64 de GitHub Actions sigue pendiente y debe confirmar la misma resolución, build, migraciones, Trivy y SBOM.
- El `CMD` por defecto del Dockerfile backend no es autosuficiente fuera del override de Compose; conviene corregirlo en una tarea separada y explícita.
- No se declara seguridad completa ni aprobación humana; esta evidencia no autoriza merge.

## Recomendación

Continuar con una ejecución real de GitHub Actions usando el lockfile actualizado. Mantener el bloqueo de CRITICAL y el fail-closed técnico. No introducir exclusiones Trivy ni aprobar automáticamente vulnerabilidades de npm. Si el runner amd64 reproduce 0 CRITICAL/HIGH en las tres imágenes y los gates pasan, registrar la evidencia remota antes de solicitar revisión/merge.

