# DEVOPS-02.1 — Security baseline & vulnerability assessment

**Fecha de auditoría inicial:** 2026-10-09<br>
**Proyecto:** `devops-enterprise-lab`<br>
**Alcance:** dependencias npm, imágenes Docker finales, Compose, permisos, secretos, puertos y persistencia local.<br>
**Restricciones respetadas:** sin AWS, Kubernetes, Terraform apply, publicación de imágenes, instalaciones globales, eliminación de volúmenes, commits o pushes.

## Estado inicial y evidencia

La auditoría inicial se ejecutó sobre el árbol instalado y los manifests reales:

- `npm audit --json`: salida completa conservada fuera del repositorio en `/tmp/devops-02-1-npm-audit.json`; código de salida `1` por hallazgos.
- `npm audit --omit=dev --json`: salida completa conservada en `/tmp/devops-02-1-npm-audit-prod.json`; código de salida `1` por hallazgos de runtime.
- Trivy: no está instalado en el entorno (`command not found`); no se instaló automáticamente.
- Dockerfile final backend/frontend: ambos usan `USER node`; backend hace `chown` antes de cambiar de usuario.
- Compose: backend/frontend sólo publican en `127.0.0.1`; PostgreSQL no tiene `ports`; la red `taskflow-data` es interna; el volumen es `taskflow-postgres-data`.
- `.env.example` contiene credenciales conocidas de desarrollo local, no secretos reales; `.env` está excluido por `.dockerignore`/`.gitignore`.

## Inventario inicial por severidad

| Árbol auditado | Critical | High | Moderate | Low | Total |
|---|---:|---:|---:|---:|---:|
| Completo: runtime + desarrollo | 2 | 45 | 13 | 1 | 61 |
| Producción: `npm audit --omit=dev` | 0 | 9 | 2 | 0 | 11 |

La cantidad de paquetes afectados por severidad coincide con el conteo de vulnerabilidades reportado por npm; un advisory puede afectar varias rutas transitivas.

## Matriz previa de hallazgos y remediación

| Hallazgo/ruta | Severidad inicial | Contexto | Corrección disponible | Decisión |
|---|---:|---|---|---|
| `@nestjs/core` 11.1.6 → `path-to-regexp`, advisory GHSA-36xv-jgw5-4q75 y DoS asociado | High | Runtime backend | `@nestjs/core` 11.2.7 | Aplicar; misma major, parche/minor compatible |
| `@nestjs/platform-express` 11.1.6 → `multer`, `path-to-regexp` | High | Runtime backend | 11.2.7 | Aplicar junto con Nest core/common |
| `@nestjs/common` 11.1.6 → `file-type` | Moderate | Runtime backend | 11.2.7 | Aplicar junto con Nest |
| `prisma`/`@prisma/config` 6.17.1 → `deepmerge-ts`, `effect` | High | Runtime porque Prisma CLI está en la imagen para migraciones | npm sugiere 6.12.0 como fix, downgrade incompatible con el pin actual | No degradar; probar último Prisma 6.19.3 y documentar si persiste |
| `vite` 7.1.7, path traversal/lectura arbitraria en dev server | High | Build/dev; no entra en backend runtime | 7.3.7 | Aplicar minor compatible y reconstruir frontend |
| `vitest` 3.2.4 → `tinypool`, `@vitest/mocker` | Critical | Sólo desarrollo/test | 3.2.7 | Aplicar patch; reduce critical dev |
| `jest` 30.1.3 y transitivas (`micromatch`, `braces`, `js-yaml`) | High/Moderate | Sólo desarrollo/test | 30.5.2 | Aplicar minor compatible |
| `@typescript-eslint/*` 8.45.0 → `fast-glob`, `micromatch` | High | Sólo lint/build | 8.71.1 | Aplicar minor compatible |
| `@nestjs/cli` 11.0.10 / schematics 11.0.7 → glob/webpack/AJ V | High/Moderate/Low | Sólo desarrollo | CLI 11.0.24; schematics 11.1.0 | Aplicar dentro de major 11 |

No se aplicará `npm audit fix --force`. No se añadirán exclusiones generales.

## Revisión de imágenes y Compose

### Permisos y usuarios

- Frontend final: `USER node`; no ejecuta como root.
- Backend final: `USER node`; `chown -R node:node /app` permite ejecutar Prisma y Nest sin root.
- PostgreSQL utiliza el usuario interno estándar de la imagen oficial; no se expone al host.

### Puertos y redes

- Frontend: `127.0.0.1:5173`.
- Backend: `127.0.0.1:3000`.
- PostgreSQL: sin publicación de puerto.
- `taskflow-data`: red Docker interna para backend/PostgreSQL.
- `taskflow-app`: tráfico local frontend/backend.

### Secretos

- No se encontraron secretos reales en los manifests revisados.
- Las credenciales de `.env.example` son deliberadamente conocidas y sólo para desarrollo local.
- No se imprimieron valores de entorno de contenedores durante la auditoría.
- `.dockerignore` raíz excluye `.env`, dependencias, artefactos y estados Terraform del contexto.

## Remediación aplicada

Se actualizaron sólo versiones no mayores y se regeneró el lockfile:

- Nest runtime a 11.2.7.
- `@nestjs/cli` a 11.0.24.
- `@nestjs/schematics` a 11.1.0.
- Jest a 30.5.2.
- Vitest a 3.2.7.
- Vite a 7.3.7.
- `@typescript-eslint/eslint-plugin` y parser a 8.71.1.
- Prisma y `@prisma/client` a 6.19.3, conservando Prisma 6.
- `@types/supertest` quedó fijado exactamente en 6.0.3.
- Prisma CLI se aisló en el target Docker `migrations`; el runtime backend instala sólo el cliente y elimina explícitamente `prisma`, `@prisma/config`, `@prisma/engines`, `deepmerge-ts` y `effect` de la etapa de producción.
- Compose añadió el servicio one-shot `migrate`, dependiente de PostgreSQL healthy; backend depende de su finalización exitosa.

## Resultado posterior a la remediación

| Árbol auditado | Critical | High | Moderate | Low | Total |
|---|---:|---:|---:|---:|---:|
| Completo: runtime + desarrollo | 2 | 3 | 21 | 1 | 27 |
| `npm audit --omit=dev` sobre lockfile/workspaces | 0 | 3 | 0 | 0 | 3 |

La reducción fue de 61→27 total y 11→3 en el grafo npm de producción. El `npm audit --omit=dev` posterior conserva tres HIGH de `prisma`, `@prisma/config` y `deepmerge-ts` porque npm resuelve la CLI como peer del workspace; no se aceptó el downgrade sugerido a Prisma 6.12.0.

En la imagen backend final se comprobó directamente:

- `prisma-cli=absent`.
- `prisma-config=absent`.
- `@prisma/client` carga correctamente.

Por ello, esos tres advisories no están presentes en el filesystem runtime construido con la etapa de producción. Esta mitigación no se considera un escaneo completo de seguridad: Trivy no está instalado y el gate de imagen permanece `NOT RUN/BLOCKED` hasta disponer de él.

### Riesgo residual no remediado

- `vitest` 3.2.7 y `tinypool` conservan 2 CRITICAL de desarrollo; npm indica Vitest 5.0.3 como corrección, que es major y requiere aprobación explícita. No se aplicó.
- Permanecen 21 MODERATE y 1 LOW, principalmente en tooling de test/build y rutas de `ts-jest`; las correcciones sugeridas implican majors de `ts-jest`/Vitest o cambios fuera del alcance.
- `npm audit` sigue devolviendo código 1 por estos hallazgos. No se ocultaron ni se usaron exclusiones generales.

## Política DevSecOps inicial para CI

- Bloquear vulnerabilidades `CRITICAL` confirmadas en artefactos finales, salvo excepción temporal documentada con propietario, justificación, aprobación y fecha de expiración.
- Evaluar `HIGH` por exposición, si alcanza runtime final, disponibilidad de parche y contexto. Un HIGH de runtime sin mitigación bloquea; uno exclusivo de tooling requiere evaluación.
- Documentar `MEDIUM` y `LOW` con seguimiento y fecha objetivo.
- No bloquear automáticamente por vulnerabilidades exclusivas de herramientas de desarrollo sin evaluar su riesgo.
- No ocultar hallazgos con exclusiones generales; las excepciones deben ser específicas y temporales.
- Un escaneo exitoso no significa seguridad completa: también se revisan secretos, usuarios, permisos, puertos, redes, imagen base, SBOM y comportamiento runtime.
- Trivy debe ser prerequisito explícito de CI para imágenes finales; si falta localmente, el gate queda `BLOCKED/NOT RUN`, no `PASS`.

## Criterios de aceptación

- [x] Auditorías npm completa y de producción ejecutadas sin ocultar hallazgos.
- [x] Ausencia de Trivy documentada.
- [x] Matriz previa de hallazgos y decisiones registrada antes de remediar.
- [x] Conteos posteriores y diferencias verificadas.
- [x] Lint, tests, build y health checks posteriores verificados.
- [x] Persistencia verificada recreando sólo PostgreSQL y conservando volumen.
- [x] Política DevSecOps inicial documentada.

## Gates ejecutados después de remediar

| Gate | Evidencia | Resultado |
|---|---|---|
| Instalación | `npm ci --no-audit --no-fund` | PASS |
| Lint | `npm run lint` | PASS |
| Tests | `npm test` | PASS — 2 suites, 5 tests |
| Build | `npm run build` | PASS — Vite 7.3.7, Prisma 6.19.3, Nest |
| Compose config | `docker compose config` | PASS |
| Compose build | `docker compose build --quiet` y backend `--no-cache` | PASS |
| Migration service | `docker compose up -d`; `migrate` exited 0 | PASS |
| Health | live 200 y ready 200 con DB | PASS |
| Runtime hardening | usuarios `node`, ports loopback, PostgreSQL sin ports | PASS |
| PostgreSQL recreation | `docker compose up -d --force-recreate --no-deps postgres` | PASS; volumen conservado |
| Persistence | Task leído después de recrear PostgreSQL | PASS |
| Trivy | `command -v trivy` | NOT RUN/BLOCKED; herramienta ausente |

No se ejecutó `npm audit fix --force`. No se ejecutó `docker compose down -v` y no se eliminaron volúmenes. Sólo se eliminaron los registros Task temporales creados por esta validación.
