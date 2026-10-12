# DEVOPS-03.7 — Cierre técnico y auditoría final de CI/CD

## Estado

**PASS WITH GAPS**.

Los gates técnicos locales pasan, el evaluador conserva el bloqueo de CRITICAL y no hay HIGH en las tres imágenes finales. Se corrigió el `CMD` autónomo del backend. El cierre remoto requiere una nueva ejecución de GitHub Actions porque el Run #3 ocurrió antes de este cambio local y no se realizaron pushes.

## Preflight

- Rama: `chore/devops-03-first-ci`.
- Remoto: `origin` apunta a `git@github-spartan:spartan007-28/devops-enterprise-lab.git`.
- No se realizaron commits, pushes, merges, aprobaciones ni cambios remotos.
- No se usó AWS.
- El único cambio de código de esta tarea es `apps/backend/Dockerfile`; el task contract permanece sin modificar.

## Causa de `PASS_WITH_REVIEW`

La causa está en `scripts/security/evaluate-policy.sh`, no en un HIGH oculto:

- Línea 55: `decision` es `BLOCKED_CRITICAL` si existe al menos un CRITICAL; en cualquier otro caso se fija en `PASS_WITH_REVIEW`.
- Línea 56: `humanApprovalRequired` se calcula independientemente como `high.length > 0`.
- Líneas 70–72: el Markdown muestra si CRITICAL/HIGH requieren bloqueo o revisión.
- Línea 84: el proceso termina con exit 10 únicamente cuando hay CRITICAL; sin CRITICAL termina con exit 0.

Por tanto, el caso real actual es:

```json
{
  "decision": "PASS_WITH_REVIEW",
  "highCount": 0,
  "humanApprovalRequired": false,
  "imageCounts": {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "UNKNOWN": 0}
}
```

`PASS_WITH_REVIEW` es una disposición conservadora del evaluador; no equivale a aprobación humana. No se cambió porque modificarlo a `PASS` alteraría el contrato de política y no corregiría ningún hallazgo. El workflow solo imprime `HUMAN APPROVAL REQUIRED` cuando `PASS_WITH_REVIEW` y `high_count > 0` (`.github/workflows/ci.yml:148-150`), de modo que no se solicita aprobación para el caso actual de cero HIGH.

## Separación de auditorías

Los tres reportes Trivy actuales (`reports/devops-03-7/`) registran:

| Artefacto | CRITICAL | HIGH | MEDIUM | LOW |
|---|---:|---:|---:|---:|
| frontend final | 0 | 0 | 0 | 0 |
| backend runtime final | 0 | 0 | 0 | 0 |
| migraciones Prisma | 0 | 0 | 0 | 0 |

`npm audit` completo reporta 2 CRITICAL, 0 HIGH, 21 MODERATE y 1 LOW en el grafo completo de workspace/tooling. `npm audit --omit=dev` reporta 0 vulnerabilidades. El job `Dependency audit` conserva ambos JSON y convierte el estado de vulnerabilidades npm en resultado informativo; solo un fallo técnico obtiene status 20 y bloquea ese job. Esto no se confunde con el contenido efectivo de las imágenes finales.

## Casos negativos de política

Se usaron copias temporales de reportes reales, fuera del repositorio:

| Caso | Resultado observado |
|---|---|
| Reportes reales, cero hallazgos de imagen | `PASS_WITH_REVIEW`, `humanApprovalRequired=false`, exit 0 |
| Fixture HIGH | `PASS_WITH_REVIEW`, `humanApprovalRequired=true`, exit 0 |
| Fixture CRITICAL | `BLOCKED_CRITICAL`, exit 10 |
| Falta `npm-audit-full.json` | error explícito, sin resumen, exit 1 |
| Reporte npm vacío | JSON inválido, sin resumen, exit 1 |
| Trivy JSON inválido | error de parseo, sin resumen, exit 1 |

Estos casos confirman que los reportes obligatorios faltantes o inválidos fallan de forma fail-closed; no se fabricaron reportes ni se alteraron umbrales.

## Defecto y corrección del backend

El Dockerfile copiaba el build a `/app/apps/backend/dist/main.js`, pero declaraba `CMD ["node", "dist/main.js"]`. La prueba autónoma de la imagen construida falló con:

```text
Cannot find module '/app/dist/main.js'
```

Se corrigió únicamente la última línea de `apps/backend/Dockerfile` a:

```dockerfile
CMD ["node", "apps/backend/dist/main.js"]
```

La imagen corregida `taskflow/backend:devops-03-7` fue construida para Linux ARM64, mantiene usuario `node` y arrancó sin override de command contra PostgreSQL temporal. `/health/live` y `/health/ready` respondieron correctamente; readiness confirmó `database: ok`. El servicio Compose conserva su command explícito compatible.

## Gates ejecutados

| Comando/prueba | Entorno | Resultado | Limitación |
|---|---|---|---|
| `npm ci --no-audit --no-fund` | macOS ARM64, Node 24.19.0/npm 11.17.0 | PASS con `EBADENGINE` informativo | Proyecto fija Node 24.20.0/npm 11.19.0; GitHub usa Node 24.20.0. |
| `npm run lint` | local | PASS | — |
| `npm run db:generate` | local | PASS, Prisma 6.19.3 | — |
| `npm test` | local | PASS, frontend 1 test; backend 5 tests | — |
| `npm run build` | local | PASS | — |
| `bash -n` scripts security | local | PASS | — |
| YAML workflow | Ruby YAML parser | PASS | — |
| `docker compose config --quiet` | Docker desktop-linux | PASS | — |
| Docker builds | ARM64 | PASS | Linux amd64 remoto pendiente. |
| Backend autónomo sin override | ARM64 + PostgreSQL temporal | PASS después del CMD fix | No es evidencia amd64. |
| Trivy 0.67.2 + CycloneDX | tres imágenes ARM64 | PASS, 0 C/H/M/L | — |
| `npm-audit-report.sh` | local | findings, exit 10 | Hallazgos de tooling preservados. |
| `evaluate-policy.sh` | reportes actuales | `PASS_WITH_REVIEW`, exit 0 | `humanApprovalRequired=false`. |
| Migración inicial/idempotente | PostgreSQL desechable tmpfs | PASS | No se usó volumen histórico. |
| `git diff --check` | local | PASS | — |

## Evidencia remota

Consulta de solo lectura realizada el 12 de octubre de 2026:

- Run `38299613783`: SUCCESS.
- Jobs remotos SUCCESS: `Quality gates`, `Dependency audit`, `Container build and security`, `Compose validation`, `CI summary`.
- El log remoto confirma `npm audit` completo con 2 CRITICAL de tooling, producción con 0, artifact `npm-audit-reports` subido y descargado, y `security policy decision=PASS_WITH_REVIEW`.
- El resumen remoto mostró `HIGH findings: 0`.
- PR #1: OPEN, `mergeStateStatus=BLOCKED`, `reviewDecision=REVIEW_REQUIRED`, sin reviews observadas.
- Ruleset remoto activo: `protect-main-devops`. La API de branch protection clásica devuelve 404; el bloqueo observado procede del ruleset/estado de revisión, no de una modificación realizada en esta tarea.

El Run #3 no contiene el cambio local del `CMD`. Por ello no se declara cierre remoto ni PASS remoto.

## Archivos modificados

- `apps/backend/Dockerfile`: corrección mínima de la ruta del `CMD` autónomo.
- `docs/assessments/devops-03-7-ci-final-technical-closure.md`: esta evidencia.

No se modificaron workflow, scripts de seguridad, dependencias, Prisma, migraciones, Compose ni configuración remota.

## Riesgos y pasos pendientes

1. Ejecutar una nueva CI remota con el cambio del Dockerfile y conservar sus artifacts/reportes.
2. Confirmar en runner Linux amd64 el build, usuario, arranque autónomo, Trivy, SBOM y política.
3. Mantener revisión independiente del PR; `PASS_WITH_REVIEW` no es aprobación humana.
4. Mantener visibles los 2 CRITICAL del audit completo de tooling; producción e imágenes finales permanecen sin hallazgos.
5. No hacer merge hasta que la nueva ejecución remota sea exitosa y la aprobación requerida por el ruleset esté presente.

