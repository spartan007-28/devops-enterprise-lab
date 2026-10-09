# DEVOPS-03.2 — GitHub Repository & First CI Execution

Fecha: 2026-10-09<br>
Modo: preparación y auditoría; sin commits, pushes ni creación de remoto

## Objetivo

Documentar el procedimiento seguro para crear la primera rama, realizar el primer commit, configurar un repositorio GitHub y abrir un Pull Request que ejecute CI, sin ejecutar operaciones que cambien el historial o publiquen código.

## Estado inicial observado

- Repositorio Git inicializado, sin commits: `No commits yet on main`.
- Rama actual: `main`; no existen ramas adicionales.
- No hay remotos configurados.
- Todos los archivos del proyecto aparecen como no rastreados porque todavía no existe el primer commit.
- `gh` está disponible; no se consultó ni imprimió identidad o tokens.
- `gitleaks` y `trufflehog` no están disponibles localmente.

## Auditoría previa al primer commit

Antes de añadir archivos, la persona autorizada debe revisar:

```bash
git ls-files --others --exclude-standard
```

La auditoría actual no encontró `node_modules`, `.env`, `reports/`, `dist/`, `coverage/`, estados Terraform ni llaves privadas entre los candidatos. `.env.example` es la única plantilla permitida y contiene valores deliberadamente locales; no debe sustituirse por secretos reales.

## Workflow auditado

`.github/workflows/ci.yml` usa `pull_request` y `push` a `main`, solicita sólo `contents: read`, y fija acciones externas a SHA completo:

- checkout v4.2.2: `11bd71901bbe5b1630ceea73d27597364c9af683`.
- setup-node v4.4.0: `49933ea5288caeca8642d1e84afbd3f7d6820020`.
- upload-artifact v4.6.2: `ea165f8d65b6e75b540449e92b4886f43607fa02`.

Los tres SHA coincidieron con sus tags consultados en GitHub. No usa `pull_request_target`, secrets, AWS, publicación de imágenes, despliegue, Docker privileged ni permisos de escritura.

## Compatibilidad Linux amd64

- El host local es ARM64, pero `node:24.20.0-alpine` publica manifiestos Linux `amd64` y `arm64`; los Dockerfiles no contienen instrucciones específicas de ARM.
- Prisma se genera dentro de la imagen durante el build, por lo que el engine debe corresponder al runner amd64 cuando CI construya en `ubuntu-latest`.
- La verificación local ARM64 no prueba por sí misma el binario amd64. La primera ejecución remota debe ser la evidencia definitiva.
- Existe deriva de versión: `.nvmrc` y `NODE_VERSION` indican `24.19.0`, mientras Docker usa `24.20.0`. Ambos satisfacen `>=24.19.0 <25`, pero se recomienda alinearlos antes de declarar reproducibilidad exacta.

## Riesgo `PASS_WITH_REVIEW`

El evaluador de política devuelve código 0 para `PASS_WITH_REVIEW` cuando no hay CRITICAL, aunque conserve HIGH en el reporte. Por tanto, `container-security` y el resumen pueden aparecer verdes con HIGH residual. El artefacto contiene evidencia, pero no existe todavía un check explícito de revisión humana ni una anotación visible en Summary. Esto es un gap de gobernanza que debe resolverse antes de tratar el check como aprobación de seguridad completa.

## Procedimiento propuesto — no ejecutar sin autorización

Reemplazar `ORG` y `REPO_URL` por valores aprobados y revisar cada diff antes de confirmar:

```bash
git switch -c chore/devops-03-first-ci
git status --short
git ls-files --others --exclude-standard
git add -A
git diff --cached --check
git diff --cached --name-status
git diff --cached -- .env .env.example .github/workflows/ci.yml
git commit -m "chore: establish CI foundation"
git remote add origin REPO_URL
git remote -v
git push --set-upstream origin chore/devops-03-first-ci
gh pr create --repo ORG/devops-enterprise-lab --base main --head chore/devops-03-first-ci --title "chore: establish CI foundation" --body-file /tmp/devops-03-pr-body.md
```

Si el repositorio GitHub ya existe, `git remote add` es suficiente. Si no existe, su creación debe autorizarse y hacerse explícitamente; no se propone ejecutarla automáticamente.

## Secuencia de validación del primer PR

1. Abrir la rama sin tocar `main`.
2. Confirmar que el workflow aparece en Actions.
3. Verificar `quality`, `audit-dependencies`, `container-security`, `compose-validation` y `summary`.
4. Descargar artefactos npm audit, Trivy, SBOM y resumen.
5. Confirmar que los HIGH residuales están visibles y tienen decisión/propietario, no sólo resultado verde.
6. Revisar diff y checks antes de mergear.
7. Ejecutar el workflow de push a `main` sólo después de aprobar el PR.

## Criterios de aceptación

- [ ] Primer commit revisado y autorizado.
- [ ] Remoto GitHub configurado explícitamente y verificado.
- [ ] No hay secretos, `.env`, dependencias, reportes ni artefactos locales en el commit.
- [ ] Workflow ejecutado en runner Linux amd64.
- [ ] Tres builds Docker y SBOM finalizan correctamente en amd64.
- [ ] Trivy no tiene fallo técnico y sus reportes se conservan.
- [ ] HIGH residual no se considera aprobación automática; existe revisión explícita.
- [ ] No se realiza push, PR, creación remota o cambio de `main` sin autorización.
