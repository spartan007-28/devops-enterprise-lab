# AGENTS.md — DevOps Enterprise Lab

## Alcance y precedencia
Estas instrucciones aplican a todo el repositorio. Leer el contrato de tarea en `docs/agent/tasks/` antes de actuar. Las reglas temáticas de `.agents/rules/` son documentación vinculante **cuando la tarea las referencia**; no asumir que Codex las carga automáticamente. Si hay conflicto, detenerse y documentarlo; nunca relajar seguridad por conveniencia.

## Reglas no negociables
- Responder y documentar en español. Indicar ruta exacta de archivos modificados.
- No realizar `git commit`, `git push`, merges, cambios remotos en GitHub, ni despliegues sin autorización explícita.
- No ejecutar acciones sobre AWS ni crear recursos facturables sin autorización; presupuesto objetivo <= 500 MXN/mes.
- No modificar migraciones históricas Prisma ni datos persistentes reales.
- No inventar endpoints, resultados, evidencias, CVE, versiones ni estados.
- No introducir secretos, tokens o credenciales en Git, logs o reportes. Revisar staged diff antes de proponer commit.
- Mantener seguridad fail-closed: nunca omitir Trivy, npm audit, controles de acceso o checks para conseguir PASS.
- `PASS_WITH_REVIEW` no implica aprobación humana; respetar rulesets y PR review.
- Hacer cambios mínimos y reversibles; no modificar componentes ajenos a la tarea.

## Flujo obligatorio
1. Auditar archivos reales, branch, cambios locales y dependencias; no sobrescribir trabajo concurrente.
2. Definir alcance y evidencias; leer reglas pertinentes indicadas abajo.
3. Implementar cambios mínimos, con pruebas positivas y negativas donde corresponda.
4. Guardar reporte en `docs/assessments/<id>.md`: estado, comandos, resultados, gaps, archivos y riesgos.
5. Responder en consola sólo con resumen, evidencias y bloqueos. Nunca declarar PASS remoto sin ejecución remota comprobada.

## Reglas por dominio
- Arquitectura: `.agents/rules/architecture.md`
- Seguridad: `.agents/rules/security.md`
- Git y PR: `.agents/rules/git-workflow.md`
- Docker: `.agents/rules/docker.md`
- CI/CD: `.agents/rules/ci-cd.md`
- Terraform: `.agents/rules/terraform.md`

## Skills disponibles (invocar sólo cuando correspondan)
- `.agents/skills/ci-pipeline-review/SKILL.md`
- `.agents/skills/docker-security/SKILL.md`
- `.agents/skills/terraform-validation/SKILL.md`

## Estado de trabajo concurrente
DEVOPS-03.7 puede estar en ejecución. No tocar archivos afectados por esa tarea hasta reconciliar su resultado y revisar `git status`/`git diff`.
