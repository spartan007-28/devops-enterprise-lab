# DEVOPS-03 — Plan de Continuous Integration Foundation

## Objetivo

Crear un pipeline de GitHub Actions reproducible para Pull Requests y pushes a `main` que valide código, builds Docker, vulnerabilidades y SBOM sin publicar imágenes, desplegar recursos ni usar AWS/Kubernetes.

## Estado inicial

- Monorepo npm workspace con Node `24.19.0` y npm `11.x` fijados.
- Frontend y backend tienen scripts de lint, test y build.
- Compose construye `frontend`, `backend` y el target one-shot `migrate`.
- El runtime backend usa `@prisma/client`; Prisma CLI vive en el artefacto de migraciones.
- DEVOPS-02.1 reporta 2 CRITICAL de tooling Vitest/tinypool y hallazgos HIGH/MODERATE residuales; no se ocultarán en CI.
- Trivy no está instalado localmente. El workflow usará una imagen Trivy versionada y comprobará su versión; la ausencia o fallo técnico dejará el gate bloqueado.

## Archivo y componentes exactos

### Workflow

`.github/workflows/ci.yml`

- Triggers: `pull_request` y `push` a `main`.
- `permissions: contents: read` al nivel del workflow.
- `timeout-minutes` por job.
- Acciones externas fijadas a commits SHA completos.
- Sin `pull_request_target`, secrets, AWS, Docker privileged, push de imágenes o deploy.

### Scripts auxiliares

- `scripts/security/npm-audit-report.sh`: ejecuta auditoría completa y `--omit=dev`, conserva JSON y distingue hallazgos npm de errores técnicos.
- `scripts/security/trivy-scan.sh`: ejecuta Trivy versionado mediante contenedor no privilegiado sobre el Docker socket del runner, genera JSON y CycloneDX SBOM; diferencia scanner failure de vulnerabilidades.
- `scripts/security/evaluate-policy.sh`: consume reportes Trivy/npm, bloquea CRITICAL en imágenes, clasifica HIGH runtime/tooling y emite resumen sin exclusiones generales.
- `scripts/ci/yaml-validate.sh` o validación equivalente documentada: comprueba sintaxis YAML local sin instalar herramientas globales automáticamente.

### Reportes y artefactos

La ejecución generará bajo `reports/ci/`:

- `npm-audit-full.json`.
- `npm-audit-production.json`.
- `trivy-frontend.json`, `trivy-backend.json`, `trivy-migrate.json`.
- `sbom-frontend.cdx.json`, `sbom-backend.cdx.json`, `sbom-migrate.cdx.json`.
- `security-policy-summary.md` y `security-policy-summary.json`.

El workflow subirá `reports/ci` como artifact con retención de 14 días. Los reportes no se versionan ni contienen credenciales.

## Jobs del workflow

### `quality`

1. Checkout SHA fijo.
2. Setup Node 24 SHA fijo con cache npm basado en `package-lock.json`.
3. `npm ci`.
4. `npm run lint`.
5. `npm test`.
6. `npm run build`.

Todos son gates obligatorios. No usar `continue-on-error`.

### `audit-dependencies`

1. Instalar dependencias con `npm ci`.
2. Ejecutar el helper de auditoría.
3. Conservar JSON completo y de producción.
4. Subir reportes aunque existan vulnerabilidades; fallar sólo por error técnico del comando/helper, no ocultar hallazgos.

### `container-security`

1. Checkout y `npm ci` implícito en el build Docker.
2. Construir sin publicar:
   - `taskflow/frontend:ci` desde `apps/frontend/Dockerfile`.
   - `taskflow/backend:ci` desde `apps/backend/Dockerfile`.
   - `taskflow/migrate:ci` desde target `migrations`.
3. Comprobar que la imagen backend no contiene Prisma CLI/config del runtime y que el proceso conserva usuario no-root mediante inspección no sensible.
4. Ejecutar `scripts/security/trivy-scan.sh` para las tres imágenes.
5. Generar SBOM CycloneDX por imagen.
6. Evaluar política y fallar por CRITICAL confirmado en imágenes o por fallo técnico del scanner.

El target `migrate` se escanea por separado porque contiene Prisma CLI y tooling deliberadamente, pero sus hallazgos no se confunden con el runtime backend.

### `compose-validation`

1. Ejecutar `docker compose config`.
2. No arrancar PostgreSQL ni crear volúmenes en CI salvo que se agregue un job explícito y aislado en el futuro.
3. Validar que el workflow sólo construye y analiza; no publica ni despliega.

## Política de decisión

- **PASS:** gate técnico terminado y sin violación de política.
- **FINDINGS:** scanner ejecutó correctamente y reportó vulnerabilidades; el resumen conserva severidad, imagen, paquete/CVE y contexto.
- **BLOCKED:** scanner ausente, imagen no analizable, fallo de red/daemon o reporte inválido. Nunca convertirlo en PASS.
- CRITICAL en frontend/backend/migrate bloquea el job, salvo excepción explícita futura con propietario, aprobación y expiración.
- HIGH en runtime backend/frontend se evalúa y bloquea si tiene exposición relevante sin mitigación; HIGH sólo en migrate/tooling queda visible para triage.
- MEDIUM/LOW quedan documentadas como deuda.
- `npm audit` no decide por sí solo el contenido efectivo de la imagen: se conserva y se clasifica por runtime/dev; Trivy decide sobre imágenes construidas.

## Seguridad del workflow

- `GITHUB_TOKEN` sólo `contents: read`.
- Sin secrets, credenciales AWS ni acceso a registries.
- `pull_request`, nunca `pull_request_target`.
- No ejecutar scripts provenientes de PR con privilegios especiales.
- Docker sólo con el daemon estándar del runner; no `--privileged`.
- Acciones externas fijadas a SHA y versiones de Trivy fijadas/verificadas.
- `timeout-minutes` por job.
- Retención de artifacts 14 días.
- Sin `|| true`, exclusiones globales o `continue-on-error` indiscriminado.

## Validación local

Ejecutar desde la raíz:

```bash
npm ci
npm run lint
npm test
npm run build
docker compose config
docker build -t taskflow/frontend:ci -f apps/frontend/Dockerfile .
docker build -t taskflow/backend:ci -f apps/backend/Dockerfile .
docker build --target migrations -t taskflow/migrate:ci -f apps/backend/Dockerfile .
```

Si Trivy no está instalado localmente, el check de seguridad queda `BLOCKED/NOT RUN`; no se instalará globalmente automáticamente. La ejecución real de GitHub Actions es necesaria para validar triggers, permisos, cache, artifacts y los SHA de las acciones en el runner hospedado.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Trivy no disponible o falla técnicamente | Helper devuelve estado bloqueado y el artifact conserva diagnóstico |
| CVE sólo en tooling | Separar imágenes/runtime de migrate y clasificar contexto |
| Acción mutable por tag | SHA completo y comentario de versión |
| PR externo ejecuta código privilegiado | `pull_request`, permisos read-only, sin secrets/AWS |
| Falso PASS por npm audit | JSON conservado y política separada de Trivy |
| Build innecesario | Jobs separados, cache npm, sin Compose up en CI |
| Reportes con secretos | No imprimir env; artifact sólo reportes generados |

## Criterios de aceptación

- [ ] Plan creado antes del workflow.
- [ ] `.github/workflows/ci.yml` dispara PR y push a `main`.
- [ ] Lint, tests y build son gates obligatorios.
- [ ] Frontend, backend y migrate se construyen sin publicar.
- [ ] Trivy está versionado/verificado y escanea las tres imágenes; ausencia/fallo queda BLOCKED.
- [ ] SBOM CycloneDX generado para frontend/backend y migrate.
- [ ] npm audit full/production conserva JSON como artifacts.
- [ ] Política bloquea CRITICAL de imágenes y diferencia runtime/tooling.
- [ ] Permisos mínimos, SHA completos, sin secrets/AWS/privileged/pull_request_target.
- [ ] YAML y checks locales ejecutados; checks exclusivos de GitHub Actions identificados.
- [ ] Assessment final documenta resultados reales, bloqueos y riesgos residuales.
