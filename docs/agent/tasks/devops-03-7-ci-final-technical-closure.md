# DEVOPS-03.7 — Cierre técnico y auditoría final CI/CD

## Contexto verificado

Repositorio: `devops-enterprise-lab`. Rama de trabajo: `chore/devops-03-first-ci`. PR #1 abierto hacia `main`, protegido por ruleset con checks obligatorios y aprobación independiente. GitHub Actions Run #3 (`379?` no usar; identificador real observado: `38299613783`) finalizó SUCCESS con cinco jobs exitosos. El resumen visible indica `Decision: PASS_WITH_REVIEW` y `HIGH findings: 0`. DEVOPS-03.6 remediaba `deepmerge-ts` en imagen de migraciones. Hay un hallazgo previo sobre posible ruta incorrecta de `CMD` en Dockerfile backend; requiere verificación, no asumirlo sin inspección.

## Objetivo

Cerrar técnicamente DEVOPS-03 sin alterar controles de seguridad ni aprobar el PR. Investigar de forma reproducible por qué el evaluador retorna `PASS_WITH_REVIEW`, verificar/corregir el arranque autónomo de la imagen backend, consolidar evidencias y señalar bloqueos remotos.

## Fase 0 — Preflight y límites

1. Inspeccionar `git status --short`, rama actual, commits recientes y diff existente. Preservar cualquier cambio ajeno; no sobrescribirlo.
2. Leer `.github/workflows/ci.yml`, `scripts/security/evaluate-policy.sh`, `scripts/security/npm-audit-report.sh`, `scripts/security/trivy-scan.sh`, Dockerfiles, `docker-compose.yml`, `package.json`, `package-lock.json`, `.nvmrc` y assessments DEVOPS-03.2.1 a DEVOPS-03.6 presentes.
3. Distinguir evidencia local de evidencia remota. No declarar que un test corre en GitHub si el workflow no lo ejecuta.
4. Prohibido commit, push, merge, cambios remotos en GitHub, acciones AWS, publicación de imágenes o modificaciones históricas de migraciones.

## Fase 1 — Diagnóstico de política

1. Reconstruir el flujo exacto de los reportes npm y Trivy hasta el JSON de política, sus campos `decision`, `humanApprovalRequired`, conteos por severidad y códigos de salida.
2. Explicar, citando rutas y condiciones de código, por qué se obtiene `PASS_WITH_REVIEW` cuando `HIGH findings: 0` en el resumen del Run #3.
3. Distinguir hallazgos de imágenes finales, npm producción y npm completo (incluidas dependencias de desarrollo). Comprobar si existen CRITICAL de herramientas y qué significa realmente el estado del job `Dependency audit`.
4. Confirmar si `humanApprovalRequired` es `true` o `false` con evidencia real. No inferirlo a partir del nombre `PASS_WITH_REVIEW`.
5. Si hay error de clasificación, reporte o presentación, proponer y aplicar la corrección mínima respaldada por pruebas. No modificar umbrales, exclusiones, severidades, aprobaciones ni criterios fail-closed para forzar `PASS`.
6. Probar casos con reportes reales y negativos: reporte ausente/vacío, CRITICAL, HIGH, cero hallazgos y error técnico. Usar fixtures aislados sin falsear evidencia de producción. Verificar exit codes y decisión resultante.
7. Si el comportamiento es deliberado y correcto, documentarlo sin cambiar código.

## Fase 2 — Imagen Docker backend

1. Comparar el `CMD`/`ENTRYPOINT` efectivo de `apps/backend/Dockerfile`, el output real de Nest/TypeScript y los overrides de `docker-compose.yml`.
2. Construir la imagen backend con la configuración real. Ejecutarla sin override de command/entrypoint, usando las variables y servicios necesarios para un arranque válido. Distinguir error de ruta de error por dependencia de base de datos.
3. Si el `CMD` está incorrecto, corregir únicamente `apps/backend/Dockerfile` (o el archivo estrictamente necesario, justificándolo). No modificar código de aplicación salvo incompatibilidad demostrada.
4. Probar arranque autónomo, endpoint health si aplica, salida limpia ante señales, usuario no root y persistencia de funcionalidad en Compose.
5. No introducir credenciales reales ni exponer puertos/servicios innecesarios.

## Fase 3 — Gates técnicos

Ejecutar lo que permita el entorno, reportando comandos, resultados y limitaciones:

- `node -v`, `npm -v`, `npm ci` (si corresponde), lint, tests y build.
- `docker compose config` y validación de arranque de servicios.
- Construcción de imágenes frontend, backend runtime y migraciones; verificar plataforma local y aclarar si no es Linux amd64.
- Trivy/SBOM en las imágenes según scripts del repositorio; reportar CRITICAL/HIGH por imagen.
- Migraciones PostgreSQL en instancia desechable si un cambio afecta su ejecución; nunca modificar datos históricos.
- Shell syntax, validación YAML, `git diff --check` y pruebas negativas de política.
- Inspeccionar `.github/workflows/ci.yml` para confirmar qué pruebas se ejecutan realmente en GitHub y qué queda solo local.

No fabricar resultados ni declarar PASS ante pruebas omitidas.

## Fase 4 — Gobernanza y evidencia remota

1. Documentar la evidencia ya compartida del Run #3 de GitHub Actions: ID `38299613783`, cinco jobs SUCCESS, 2m20s, tres artifacts, resumen `PASS_WITH_REVIEW`, HIGH findings 0. Indicar que estos datos proceden de la captura y que no prueban por sí solos todos los detalles de artifacts o conteos CRITICAL.
2. Si hay acceso remoto autorizado de solo lectura, contrastar el estado del PR #1 y ruleset; si no, indicar `NOT VERIFIED REMOTELY IN THIS RUN` y usar únicamente la evidencia previa.
3. Mantener aprobación independiente obligatoria y prohibición de merge. Una aprobación de PR no debe confundirse con aceptación formal de riesgo.
4. Determinar si es necesario un nuevo run remoto después de cualquier cambio local; nunca declarar cierre remoto antes de ese run.

## Entregables

Crear `docs/assessments/devops-03-7-ci-final-technical-closure.md` con:

- Resumen ejecutivo y estado: `PASS`, `PASS WITH GAPS` o `BLOCKED` sustentado.
- Causa raíz de `PASS_WITH_REVIEW` con referencias a líneas/archivos y valor real de `humanApprovalRequired`.
- Diagnóstico del `CMD` backend, corrección aplicada si procede y pruebas de arranque autónomo.
- Matriz de gates: comando, entorno, resultado, evidencia, limitación.
- Matriz de vulnerabilidades separada por imagen, npm producción y npm completo.
- Cambios exactos por archivo y justificación.
- Evidencia del Run #3 y lista de comprobaciones remotas aún pendientes.
- Riesgos, deuda técnica, criterios de cierre y pasos manuales de Git/PR (sin ejecutarlos).

## Restricciones innegociables

- No commits, pushes, merges, bypasses, aprobaciones simuladas ni cambios de configuración remota.
- No AWS ni recursos cloud de pago.
- No ocultar vulnerabilidades, eliminar scans, relajar umbrales ni alterar política para obtener verde.
- No modificar migraciones históricas, Prisma o dependencias sin necesidad demostrada.
- No inventar resultados, rutas, CVEs ni evidencia de GitHub.
- Mantener `main` y PR #1 sin cambios remotos.

## Respuesta de Codex

En consola entregar solo: estado, explicación breve de `PASS_WITH_REVIEW`, resultado del arranque backend, pruebas ejecutadas, archivos modificados, riesgos y si requiere nueva ejecución remota. El detalle completo debe quedar en el assessment Markdown.
