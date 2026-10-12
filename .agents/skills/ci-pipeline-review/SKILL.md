---
name: ci-pipeline-review
description: Auditar workflows GitHub Actions, artifacts, gates y política de seguridad sin cambios remotos.
---
# CI pipeline review
1. Leer `AGENTS.md` y `.agents/rules/ci-cd.md` y `.agents/rules/security.md`.
2. Inspeccionar `.github/workflows/ci.yml` y scripts referenciados.
3. Comprobar dependencias entre jobs, nombres de checks, artifacts y condiciones fail-closed.
4. Validar sintaxis y pruebas locales disponibles; no declarar ejecución remota no observada.
5. Reportar riesgos, evidencia y cambios propuestos en `docs/assessments/`.
