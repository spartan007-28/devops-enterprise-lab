# DEVOPS-03.2 — GitHub Readiness Assessment

Fecha: 2026-10-09<br>
Estado: **PREPARADO CON BLOQUEOS; NO EJECUTADO EN GITHUB**

## Git y remoto

| Control | Resultado |
|---|---|
| Repositorio Git | PASS — inicializado |
| Commits | NONE — `main` no tiene commits |
| Rama actual | `main` |
| Ramas adicionales | NONE |
| Remotos | NONE configurados |
| Archivos no rastreados | Todos los archivos del proyecto; esperado antes del primer commit |
| Push/commit ejecutado | NO |

No existe un repositorio remoto GitHub configurado en este checkout. No se creó ninguno.

## Auditoría de inclusión

`.gitignore` contiene reglas para `node_modules/`, `dist/`, `coverage/`, `reports/`, `.env`, `.vite/`, cachés, logs, estados Terraform, `.terraform/` y `*.tfvars`, manteniendo explícitamente `.env.example`.

Verificación mediante `git check-ignore --no-index`:

| Ruta | Resultado |
|---|---|
| `node_modules` | Ignorada |
| `.env` | Ignorada |
| `.env.example` | Permitida intencionalmente |
| `reports/` | Ignorada |
| `dist/` y `apps/*/dist` | Ignoradas |
| `coverage/` | Ignorada |

Los artefactos locales de Trivy/npm quedaron bajo `reports/` y no aparecen en `git ls-files --others --exclude-standard`. `dist/` no está presente; su patrón sí está activo.

## Auditoría de secretos

Se inspeccionaron nombres y contenido candidato sin imprimir valores. No se encontraron coincidencias de claves AWS `AKIA`/`ASIA`, tokens GitHub, bloques de llaves privadas, archivos `.pem`/`.key`, ni asignaciones sospechosas de passwords/secrets fuera de la plantilla local.

`.env.example` es intencionalmente versionable y usa credenciales de desarrollo local documentadas. No contiene credenciales de un servicio real según la inspección realizada.

No se ejecutaron `gitleaks` ni `trufflehog` porque no están instalados globalmente. Su ausencia no equivale a una garantía de ausencia de secretos.

## Workflow y acciones

La sintaxis YAML fue validada localmente con Ruby. Los SHA completos de checkout, setup-node y upload-artifact coincidieron con los tags v4.2.2, v4.4.0 y v4.6.2 consultados en GitHub. El workflow solicita únicamente:

```yaml
permissions:
  contents: read
```

No se detectaron `pull_request_target`, `docker push`, login de registry, AWS, Terraform apply, Kubernetes apply, `--privileged`, `continue-on-error` ni `|| true` en workflow/scripts.

## Compatibilidad de runner

La imagen `node:24.20.0-alpine` usada por los Dockerfiles publica Linux amd64 y ARM64. Los Dockerfiles son multi-stage y ejecutan Prisma generate dentro de la plataforma de build; por ello el runner amd64 debe producir el engine Prisma amd64. Esto sólo queda confirmado con una ejecución real en `ubuntu-latest`.

### Deriva detectada

- `.nvmrc`: Node `24.19.0`.
- Workflow `NODE_VERSION`: `24.19.0`.
- Dockerfiles remediados: `node:24.20.0-alpine`.
- `package.json`: Node `>=24.19.0 <25`, npm `>=11.17.0 <12`.

No es incompatibilidad de engine, pero sí una diferencia de reproducibilidad que debe alinearse antes del primer CI oficial.

## Gate `PASS_WITH_REVIEW`

El evaluador actual devuelve éxito cuando no hay CRITICAL y etiqueta el resultado como `PASS_WITH_REVIEW`; el workflow no transforma ese estado en fallo. Con las imágenes remediadas, frontend/backend están sin vulnerabilidades Trivy y migraciones conserva un HIGH de `deepmerge-ts` de Prisma CLI. Ese HIGH queda en artefactos, pero el check puede verse verde.

Conclusión: **la revisión HIGH no está representada como aprobación humana explícita**. Antes de usar el check como autorización de merge se debe añadir una salida visible en `GITHUB_STEP_SUMMARY`, un check requerido separado o un procedimiento de aprobación documentado. No se modificó el workflow en esta ejecución de preparación.

## Bloqueos

1. No hay commit inicial ni remoto GitHub configurado.
2. No se ha autorizado la creación/configuración del remoto, push ni PR.
3. No existe evidencia de ejecución en GitHub Actions/Linux amd64.
4. Deriva Node 24.19.0 vs 24.20.0 pendiente de decisión.
5. HIGH residual de migraciones requiere revisión; no debe convertirse silenciosamente en aprobación.
6. No hay scanner dedicado de secretos instalado localmente.

## Comandos propuestos, no ejecutados

```bash
git switch -c chore/devops-03-first-ci
git status --short
git ls-files --others --exclude-standard
git add -A
git diff --cached --check
git diff --cached --name-status
git commit -m "chore: establish CI foundation"
git remote add origin REPO_URL
git remote -v
git push --set-upstream origin chore/devops-03-first-ci
gh pr create --repo ORG/devops-enterprise-lab --base main --head chore/devops-03-first-ci --title "chore: establish CI foundation" --body-file /tmp/devops-03-pr-body.md
```

`REPO_URL`, `ORG` y el cuerpo del PR requieren decisión humana. La secuencia no debe ejecutarse hasta revisar el staged diff y confirmar que el repositorio remoto es el correcto.

## Recomendación

No abrir el PR todavía. Primero alinear la versión Node del workflow y `.nvmrc` con la base remediada, decidir cómo se expresa la aprobación de HIGH, y obtener autorización explícita para el primer commit y el remoto. Después, ejecutar la secuencia en una rama y validar el workflow remoto sin modificar `main`.
