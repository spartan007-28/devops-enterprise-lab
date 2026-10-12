# DEVOPS-03.1 — Image Vulnerability Remediation Assessment

Fecha: 2026-10-09<br>
Estado general: **PASS_WITH_REVIEW para imágenes; npm audit mantiene hallazgos de tooling**

## Resumen ejecutivo

Se remediaron las vulnerabilidades CRITICAL presentes en las imágenes Docker sin cambiar Node major, NestJS, Prisma ni Vitest. La causa principal era el npm global incluido en `node:24.19.0-alpine`; la imagen base contenía `tar`, `brace-expansion`, `ip-address`, `undici` y `http-cache-semantics`. `tinypool` sólo entraba a la imagen de migraciones por Vitest.

La remediación actualiza la base a `node:24.20.0-alpine`, elimina npm global de las imágenes que no lo necesitan, separa las dependencias de producción de la CLI de Prisma y actualiza los paquetes Alpine en las etapas finales. Las imágenes frontend y backend quedaron sin vulnerabilidades reportadas por Trivy; la imagen de migraciones conserva un HIGH de `deepmerge-ts` asociado a Prisma CLI.

El gate de seguridad de imágenes queda **PASS_WITH_REVIEW**: 0 CRITICAL, pero 1 HIGH residual de tooling. No se modificó la política para conseguir un resultado verde.

## Causa raíz

### `tar`

En las tres imágenes iniciales se resolvió en:

```text
/usr/local/lib/node_modules/npm/node_modules/tar
```

No era una dependencia del workspace ni de la aplicación. La versión observada era `7.5.16`, incluida por npm de la imagen `node:24.19.0-alpine`; Trivy reportó `CVE-2026-59873` CRITICAL y HIGH relacionados. Node `24.20.0-alpine` incluye npm `11.19.0` y `tar 7.5.19`, que elimina el CRITICAL observado.

### `tinypool`

La ruta npm confirmada fue:

```text
@taskflow/frontend > vitest@3.2.7 > tinypool@1.1.1
```

La dependencia estaba en `/workspace/node_modules/tinypool` de la imagen de migraciones porque esa etapa heredaba el `npm ci` completo. No era necesaria para `prisma generate` ni `prisma migrate deploy`. Se reemplazó la etapa por dependencias de producción más una instalación controlada de `prisma@6.19.3`; la imagen de migraciones final conserva Prisma CLI, pero no `tinypool`.

### HIGH del npm global de la base

La inspección de la imagen inicial confirmó estas rutas bajo npm global:

```text
/usr/local/lib/node_modules/npm/node_modules/brace-expansion
/usr/local/lib/node_modules/npm/node_modules/http-cache-semantics
/usr/local/lib/node_modules/npm/node_modules/ip-address
/usr/local/lib/node_modules/npm/node_modules/undici
```

Como frontend, backend runtime y migraciones no necesitan npm para arrancar —Compose ahora ejecuta Node directamente— se eliminó npm global de las imágenes finales. Esto evita transportar ese tooling al runtime y remedia los hallazgos correspondientes.

### OpenSSL Alpine

Trivy reportó `libcrypto3`/`libssl3` `3.5.7-r0` con `CVE-2026-14456` HIGH. Las etapas finales ahora ejecutan `apk upgrade --no-cache`, y el escaneo posterior ya no reporta ese HIGH.

### `deepmerge-ts`

La imagen de migraciones conserva `deepmerge-ts 7.1.5`, ruta transitiva de la configuración/CLI de Prisma 6.19.3. Trivy reporta `CVE-2026-40345` HIGH y corrección `8.0.0`. Cambiar a esa major no se aplicó porque podría romper la compatibilidad del CLI y el contrato Prisma 6; queda como riesgo residual de tooling y requiere una tarea de compatibilidad aprobada.

## Cambios aplicados

### `apps/frontend/Dockerfile`

- Base build/runtime: `node:24.20.0-alpine`.
- `apk upgrade --no-cache` en runtime.
- Eliminación de npm/npx globales en runtime.
- Se conserva `USER node` y el servidor Node directo.

### `apps/backend/Dockerfile`

- Todas las etapas usan `node:24.20.0-alpine`.
- La etapa `production-dependencies` instala sólo dependencias de producción.
- La etapa `migrations` instala explícitamente Prisma CLI `6.19.3` sobre producción, genera el cliente y elimina npm global.
- La etapa runtime elimina Prisma CLI/config/engines innecesarios y npm global; conserva `@prisma/client` y engines generados.
- `apk upgrade --no-cache` en migraciones y runtime.
- Se conserva usuario `node`, Prisma 6 y arquitectura ARM64.

### `docker-compose.yml`

- Backend: `node apps/backend/dist/main.js`.
- Migraciones: `node node_modules/prisma/build/index.js migrate deploy --schema=apps/backend/prisma/schema.prisma`.
- No se publican puertos nuevos ni se cambian redes, volumen o credenciales locales.

No se modificaron `package.json` ni `package-lock.json`; no se ejecutó `npm audit fix --force`, no se cambió Vitest de major y no se introdujeron exclusiones Trivy.

## Comparación Trivy antes/después

| Imagen | Antes C/H/M/L | Después C/H/M/L | Estado |
|---|---:|---:|---|
| frontend | 1 / 13 / 22 / 15 | 0 / 0 / 0 / 0 | **Sin CRITICAL** |
| backend runtime | 1 / 13 / 22 / 15 | 0 / 0 / 0 / 0 | **Sin CRITICAL** |
| migraciones | 3 / 14 / 25 / 17 | 0 / 1 / 0 / 0 | **Sin CRITICAL; HIGH residual** |
| Total | 5 / 40 / 69 / 47 | 0 / 1 / 0 / 0 | PASS_WITH_REVIEW |

Trivy `0.67.2` generó JSON y SBOM CycloneDX para las tres imágenes. Los reportes locales están en `reports/devops-03-1/`, excluidos por `.gitignore`.

## npm audit

El lockfile no cambió y conserva los hallazgos previamente documentados:

| Árbol | Critical | High | Moderate | Low | Total |
|---|---:|---:|---:|---:|---:|
| Completo | 2 | 3 | 21 | 1 | 27 |
| Producción | 0 | 3 | 0 | 0 | 3 |

Estos resultados pertenecen al lockfile/workspace y no equivalen al contenido efectivo de las imágenes. El runtime backend ya no contiene Prisma CLI; la imagen de migraciones sí debe contenerla por función.

## Gates ejecutados

| Gate | Resultado | Evidencia |
|---|---|---|
| `npm ci` | PASS | instalación exacta completada; npm reportó 27 vulnerabilidades conocidas |
| Lint | PASS | `npm run lint` |
| Tests | PASS | `npm test`; 2 suites, 5 tests |
| Build | PASS | `npm run build`; Vite, Prisma 6.19.3 y Nest |
| Compose config | PASS | `docker compose config --quiet` |
| Docker frontend | PASS | `taskflow/frontend:remediation`, ARM64 |
| Docker backend | PASS | `taskflow/backend:remediation`, ARM64 |
| Docker migraciones | PASS | `taskflow/migrate:remediation`, ARM64 |
| Trivy frontend | PASS técnico | 0 C/H/M/L; JSON y SBOM generados |
| Trivy backend | PASS técnico | 0 C/H/M/L; JSON y SBOM generados |
| Trivy migraciones | PASS técnico | 0 C, 1 H, 0 M, 0 L; JSON y SBOM generados |
| Política de seguridad | **PASS_WITH_REVIEW** | `security-policy-summary.json`, código 0 |
| Migración Prisma | PASS | contenedor migrate terminó con exit code 0 |
| Liveness | PASS | HTTP 200, `service=backend` |
| Readiness | PASS | HTTP 200, `database=ok` |
| Frontend healthcheck | PASS | contenedor healthy, HTTP 200 |
| Persistencia PostgreSQL | PASS | registro sobrevivió reinicio exclusivo de PostgreSQL; volumen conservado |

El primer `npm test` dentro del sandbox produjo `EPERM` al abrir el listener HTTP de Supertest; repetido con permisos de ejecución del entorno pasó sin cambios de código. No se eliminaron volúmenes ni datos históricos; sólo se eliminaron los registros temporales creados por las pruebas mediante UUID y título exactos.

## Riesgos residuales

1. `deepmerge-ts 7.1.5` permanece HIGH en la imagen de migraciones. La corrección reportada es major `8.0.0`; requiere validar compatibilidad con Prisma 6 antes de aplicar.
2. `npm audit` continúa con 2 CRITICAL de tooling/dev y 3 HIGH de producción del lockfile; no se deben interpretar como vulnerabilidades presentes en los runtimes finales sin correlación de filesystem.
3. La base `node:24.20.0-alpine` se mantiene por tag compatible Node 24; el build observado resolvió digest `sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf`. Conviene evaluar pin explícito por digest en una tarea de supply chain.
4. El gate remoto de GitHub Actions todavía no se ha ejecutado; esta evaluación no declara PASS remoto.

## Recomendación para GitHub Actions

Continuar con GitHub Actions porque las imágenes ya no contienen CRITICAL y el evaluador devuelve `PASS_WITH_REVIEW`. Mantener el HIGH de migraciones visible como revisión obligatoria de tooling; no añadir una excepción automática. Antes de promover el gate como requisito organizacional, ejecutar el workflow real y conservar sus artefactos Trivy, SBOM y npm audit.
