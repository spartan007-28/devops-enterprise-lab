# DEVOPS-03.2.1 — Pre-GitHub Final Hardening

Fecha: 2026-10-09<br>
Estado: **HARDENED; HUMAN REVIEW PENDING**

## Cambios aplicados

- `.nvmrc`: `24.20.0`.
- `.github/workflows/ci.yml`: `NODE_VERSION=24.20.0`.
- `package.json` y `package-lock.json`: engines exactos `node=24.20.0`, `npm=11.19.0`.
- `README.md`: requisitos alineados a Node 24.20.0/npm 11.19.0 y Prisma 6.19.3.
- `scripts/security/evaluate-policy.sh`: expone `highCount` y `humanApprovalRequired` en JSON/Markdown; CRITICAL continúa bloqueando.
- `.github/workflows/ci.yml`: publica la disposición de seguridad en `GITHUB_STEP_SUMMARY` y en el artefacto de resumen. Cuando hay HIGH con `PASS_WITH_REVIEW`, muestra explícitamente `HUMAN APPROVAL REQUIRED`.

No se hicieron commits, pushes, merges, creación de repositorios remotos, publicaciones de imágenes ni cambios AWS/Kubernetes.

## Compatibilidad Node/npm

La imagen remediada `node:24.20.0-alpine` contiene Node `v24.20.0` y npm `11.19.0`. Los Dockerfiles frontend/backend/migraciones siguen usando `node:24.20.0-alpine`.

El shell local actual es Node `v24.19.0` y npm `11.17.0`; `npm ci` terminó correctamente, pero emitió `EBADENGINE`. No se instaló ni modificó ninguna herramienta global. La ejecución oficial debe usar Node/npm alineados mediante `.nvmrc` y `setup-node`.

## Riesgo HIGH pendiente

La imagen de migraciones conserva `deepmerge-ts 7.1.5`, con `CVE-2026-40345` HIGH y corrección reportada `8.0.0`. Es una dependencia transitiva de Prisma CLI 6.19.3. La actualización a major 8 no fue aprobada ni aplicada.

Este hallazgo está clasificado como tooling/migraciones y queda pendiente de aceptación humana. No se considera aprobado, no se oculta y no genera una excepción automática.

## Resultado de política

Con los reportes Trivy remediados:

```json
{
  "decision": "PASS_WITH_REVIEW",
  "highCount": 1,
  "humanApprovalRequired": true,
  "critical": 0
}
```

El workflow conserva el comportamiento siguiente:

- CRITICAL: falla el gate.
- Fallo técnico o reporte ausente: falla/bloquea el gate.
- HIGH pendiente: mantiene `PASS_WITH_REVIEW`, muestra `HUMAN APPROVAL REQUIRED` y requiere revisión humana; no se presenta como aprobación de seguridad.

## Gates ejecutados

| Gate | Resultado | Evidencia |
|---|---|---|
| `npm ci` | PASS con warning | Node local 24.19/npm 11.17 emitió `EBADENGINE`; CI queda fijado a 24.20/11.19 |
| Lint | PASS | `npm run lint` |
| Tests | PASS fuera del sandbox | 2 suites, 5 tests; el primer intento aislado falló por `EPERM` al abrir Supertest |
| Build | PASS | Vite 7.3.7, Prisma 6.19.3, Nest |
| YAML | PASS | Ruby `YAML.load_file` |
| Scripts shell | PASS | `bash -n` |
| Política | PASS_WITH_REVIEW | 0 CRITICAL, 1 HIGH, `humanApprovalRequired=true` |
| Patrones prohibidos | PASS | sin publicación, despliegue, AWS, privileged ni exclusiones indiscriminadas |
| Auditoría Git | PASS | artefactos locales ignorados; sin commit/remoto |

No se repitió Trivy porque la modificación afecta solamente el consumo y la presentación de los reportes, no las imágenes. Los reportes finales de la remediación permanecen en `reports/devops-03-1/` y registran 0 CRITICAL en frontend/backend/migraciones y 1 HIGH en migraciones.

## Inclusión de archivos antes del primer commit

`git status --short --branch` confirma `No commits yet on main`, sin remotos y todos los archivos como no rastreados. `git check-ignore --no-index` confirmó que `node_modules`, `.env`, `reports/`, `dist/` y `coverage/` quedan excluidos; `.env.example` queda permitido intencionalmente.

La lista de candidatos se revisó con `git ls-files --others --exclude-standard`. No se encontraron secretos reales, llaves privadas, tokens, credenciales AWS ni artefactos locales entre los candidatos. `gitleaks` y `trufflehog` no están disponibles localmente, por lo que esto no sustituye un escaneo dedicado en CI.

## Bloqueos pendientes

1. El entorno local no está alineado todavía a Node 24.20/npm 11.19; no se instaló automáticamente.
2. El HIGH de `deepmerge-ts` requiere aceptación humana explícita y no está aprobado.
3. Falta la ejecución real en GitHub Actions/Linux amd64.
4. El repositorio sigue sin commit inicial ni remoto.

## Recomendación

Conservar el cambio de visibilidad del resumen y exigir revisión humana del artefacto Trivy/SBOM antes de permitir una excepción o merge. Después de disponer de Node 24.20/npm 11.19 en el entorno de ejecución, crear la rama y el primer commit sólo mediante autorización humana, y validar el workflow en GitHub sin modificar `main`.
