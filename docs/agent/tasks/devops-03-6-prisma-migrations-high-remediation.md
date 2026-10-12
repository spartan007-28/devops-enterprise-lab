# DEVOPS-03.6 — Análisis y remediación del HIGH residual en imagen de migraciones

## Contexto y evidencia conocida

Proyecto: `devops-enterprise-lab`.

- Rama de trabajo: `chore/devops-03-first-ci`; PR #1 hacia `main` abierto y sin merge.
- CI remoto: cinco checks exitosos y ruleset de `main` activo; se exige aprobación independiente.
- Política vigente: 0 CRITICAL; 1 HIGH en imagen de migraciones; `PASS_WITH_REVIEW`, `humanApprovalRequired=true`.
- Hallazgo reportado por el assessment previo: `CVE-2026-40345`, `deepmerge-ts@7.1.5`, versión corregida reportada `8.0.0`, en tooling de migraciones que utiliza Prisma CLI 6.19.3.
- Esta información es punto de partida, **no** autorización para asumir explotabilidad, compatibilidad de versiones o validez del identificador CVE sin comprobar evidencia actual.

## Objetivo

Investigar y, si es viable y demostrablemente seguro, remediar el HIGH en la imagen de migraciones sin alterar contratos, migraciones históricas ni controles de seguridad. Si la remediación no es viable, documentar un análisis de riesgo verificable y mantener el merge bloqueado.

## Fase 0 — Auditoría de estado y evidencia

1. Confirmar rama, estado de Git y cambios pendientes. No sobrescribir cambios de usuario.
2. Inspeccionar estos archivos exactos y sus relaciones, sin asumir nombres de etapas Docker:
   - `apps/backend/Dockerfile`
   - `apps/backend/package.json`
   - `package.json`
   - `package-lock.json`
   - `apps/backend/prisma/schema.prisma`
   - `docker-compose.yml`
   - `.github/workflows/ci.yml`
   - `scripts/security/trivy-scan.sh`
   - `scripts/security/evaluate-policy.sh`
   - `docs/assessments/devops-03-5-security-gate-pr-governance.md`
3. Revisar SBOM/JSON Trivy reales disponibles. Identificar cadena de dependencias que incorpora `deepmerge-ts`, versión instalada, alcance y etapa de la imagen donde está presente.
4. Contrastar CVE, severidad, rango afectado, versión corregida y fuentes del hallazgo mediante datos verificables. Si no hay acceso a fuentes externas, marcar la verificación externa como pendiente, sin inventar resultados.
5. Establecer baseline reproducible: digest/tag de imagen, plataforma, comandos, versiones de Node/npm/Prisma, resultado Trivy y estado de migraciones. Distinguir evidencia macOS arm64 de Linux amd64 en GitHub Actions.

## Fase 1 — Opciones de remediación, de menor a mayor riesgo

Evaluar y documentar por separado:

A. Actualización compatible de dependencias transitivas con resolución soportada y pruebas. No introducir overrides forzados a una major incompatible sin evidencia técnica.

B. Optimización de la imagen de migraciones para instalar/copiar únicamente lo indispensable para `prisma migrate deploy`, sin eliminar Prisma CLI, engines, schema o archivos SQL necesarios. Confirmar funcionamiento en runtime real, no sólo build.

C. Actualización de Prisma o del tooling de migraciones sólo si la alternativa anterior no es viable y existe compatibilidad demostrada. Requiere justificar alcance y no modificar migraciones históricas.

D. Si no es remediable de forma segura, elaborar evaluación de exposición y medidas compensatorias; no crear excepciones, aprobaciones ni marcar el HIGH como aceptado.

Seleccionar la alternativa mínima que elimine el hallazgo **sin romper comportamiento**. No aplicar varias estrategias simultáneamente sin necesidad.

## Fase 2 — Implementación controlada

1. Antes de editar, indicar los archivos y rutas exactas a modificar y por qué.
2. Conservar `prisma migrate deploy` y la semántica actual de despliegue.
3. No modificar migraciones SQL históricas, Prisma schema, datos existentes ni seeds, salvo incompatibilidad demostrada y documentada; ante una migración de esquema necesaria, detenerse y solicitar autorización.
4. No modificar frontend/backend de aplicación, reglas de negocio, endpoints o RBAC.
5. No agregar `.trivyignore`, suppressions, filtros de CVE, falsos reportes, umbrales más laxos ni saltos del gate de seguridad.
6. No ejecutar despliegues AWS ni operaciones sobre recursos remotos.

## Fase 3 — Pruebas obligatorias

- `npm ci` reproducible y controles de calidad afectados (lint, tests, build).
- Construcción de las imágenes pertinentes con Docker y validación de usuario/aislamiento de tooling.
- `docker compose config`.
- Ejecutar `prisma migrate deploy` contra **PostgreSQL local desechable**, confirmar aplicación inicial, segunda ejecución idempotente y disponibilidad de la aplicación/health check si aplica. No usar bases de datos reales ni alterar datos históricos.
- Escaneo Trivy con la misma política vigente y SBOM; guardar evidencia JSON real, reportar CRITICAL/HIGH por imagen y plataforma.
- Si es posible, validar Linux amd64 localmente; si no, declarar explícitamente pendiente la prueba remota en GitHub Actions.
- Probar fail-closed de la política cuando falten reportes obligatorios; conservar `humanApprovalRequired` para HIGH residuales.
- Revisar `git diff --check`, `git status --short` y alcance del diff.

## Criterios de salida

**PASS REMEDIATED LOCAL**: 0 CRITICAL y 0 HIGH en las imágenes objetivo, migraciones funcionales, pruebas aplicables PASS, sin debilitamiento de seguridad. No equivale a PASS remoto.

**PASS WITH GAPS / REVIEW**: persiste HIGH o falta una validación relevante. Documentar por qué, exposición conocida/desconocida, medidas compensatorias y pruebas pendientes. No aprobar el riesgo.

**BLOCKED**: regresión, pérdida de funcionalidad de migraciones, falta de evidencia confiable o remediación insegura. Revertir sólo cambios propios de esta tarea si corresponde y conservar el estado previo del usuario.

## Entregables

Crear `docs/assessments/devops-03-6-prisma-migrations-high-remediation.md` con:

1. Estado inicial y fuentes de evidencia.
2. Árbol/cadena de dependencia y análisis del CVE.
3. Alternativas consideradas, riesgos y decisión.
4. Archivos exactos modificados y diff relevante.
5. Comandos, resultados de pruebas y escaneos, con distinción local/remoto.
6. Resultado final y riesgos pendientes.
7. Recomendación para el PR #1, sin realizar merge.

Guardar artefactos de prueba en rutas ignoradas por Git si ya existe convención; no versionar logs sensibles, binarios, credenciales ni reportes voluminosos. En consola mostrar sólo un resumen breve y la ruta del assessment.

## Restricciones operativas

- No ejecutar `git commit`, `git push`, `git merge`, crear/revisar PR, cambiar rulesets o branch protection.
- No aprobar ni exceptuar `CVE-2026-40345` en nombre del usuario.
- No inventar pruebas, reportes, fuentes o resultados.
- No modificar AWS ni incurrir en costos cloud.
- Mantener PR #1 abierto y merge bloqueado hasta revisión posterior.
