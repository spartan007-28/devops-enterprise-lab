# DEVOPS-02 — Containerization & Local Persistence assessment

**Fecha:** 2026-10-09<br>
**Alcance:** Docker multi-stage, Compose local, PostgreSQL, Prisma y health checks.<br>
**Plataforma validada:** Docker Engine `29.8.2`, Compose `5.5.1`, contexto `desktop-linux`, Docker server `linux/arm64`.<br>
**AWS/Kubernetes/Terraform:** no utilizados.

## Resumen ejecutivo

DEVOPS-02 quedó implementado para el alcance solicitado. El stack local contiene frontend, backend y PostgreSQL; PostgreSQL usa un volumen nombrado y una red interna separada. Prisma `6.17.1` gestiona el modelo `Task` y la migración inicial. `/health/live` permanece independiente de la base; `/health/ready` ejecuta una consulta real y devuelve 503 cuando PostgreSQL no está disponible.

La validación real demostró build ARM64, migración aplicada, healthchecks healthy, endpoints funcionales, persistencia tras reinicio del backend y recuperación de readiness después de detener/iniciar PostgreSQL. El volumen no se eliminó. Se creó y eliminó únicamente el registro de prueba generado por esta validación.

## Cambios realizados

### Persistencia y backend

- `apps/backend/prisma/schema.prisma`: datasource PostgreSQL y modelo `Task`.
- `apps/backend/prisma/migrations/migration_lock.toml`.
- `apps/backend/prisma/migrations/20261009120000_init/migration.sql`: creación de `Task`, sin operaciones destructivas.
- `apps/backend/src/prisma/prisma.service.ts`: lifecycle de Prisma en Nest.
- `apps/backend/src/health/health.service.ts`: comprobación real mediante `SELECT 1`.
- `apps/backend/src/health/health.controller.ts`: separación live/ready y respuesta 503 ante fallo de DB.
- `apps/backend/src/app.module.ts`: providers de Prisma y health.
- `apps/backend/test/health.service.spec.ts`: pruebas unitarias de éxito/fallo.
- `apps/backend/test/health.e2e-spec.ts`: pruebas HTTP live, ready y error 503 con Prisma mockeado.
- `apps/backend/test/prisma.integration-spec.ts`: prueba de creación/lectura real de `Task`, activable con `RUN_INTEGRATION_TESTS=1`.

### Contenedores y Compose

- `apps/frontend/Dockerfile`: build Vite multi-stage y servidor Node estático como usuario `node`.
- `apps/backend/Dockerfile`: dependencias, build Nest/Prisma, dependencias de producción y runtime como usuario `node`.
- `apps/frontend/.dockerignore` y `apps/backend/.dockerignore`.
- `.dockerignore`: exclusión raíz de secretos, dependencias y artefactos del contexto Docker.
- `docker-compose.yml`:
  - `postgres:16.4-alpine` sobre ARM64.
  - volumen `taskflow-postgres-data`.
  - red `taskflow-data` con `internal: true` para PostgreSQL/backend.
  - red `taskflow-app` para tráfico de desarrollo frontend/backend.
  - puertos backend/frontend ligados a `127.0.0.1`.
  - PostgreSQL sin `ports` publicado al host.
  - healthchecks y `depends_on.condition: service_healthy`.

### Documentación y configuración

- `.env.example`: `DATABASE_URL`, credenciales de desarrollo local y URL del frontend; sin secretos reales.
- `README.md`: build, start, stop, logs, restart, migración, health y limpieza explícita.
- `docs/agent/tasks/devops-02-containerization.md`: plan previo con rutas, dependencias, riesgos y aceptación.
- `package.json`/`package-lock.json`: Prisma `6.17.1` fijado y scripts de generación/migración.

## Diseño de health checks

| Endpoint | PostgreSQL disponible | PostgreSQL detenido |
|---|---:|---:|
| `/health/live` | 200 | 200 |
| `/health/ready` | 200, `database: ok` | 503, `database: unavailable` |

El healthcheck de backend consulta `/health/ready`; el de PostgreSQL usa `pg_isready`; el de frontend solicita la página raíz con Node `fetch`.

## Comandos ejecutados y evidencia

| Gate/validación | Comando | Resultado observado |
|---|---|---|
| Instalación | `npm ci --no-audit --no-fund` | PASS, código 0; 913 paquetes instalados |
| Lint | `npm run lint` | PASS, frontend/backend sin errores |
| Tests unitarios/e2e | `npm test` | PASS, 2 suites y 5 tests |
| Build local | `npm run build` | PASS, Vite + Prisma generate + Nest build |
| Compose config | `docker compose config` | PASS; redes, volumen, ports y condiciones visibles |
| Image build | `docker compose build` | PASS; frontend/backend imágenes creadas sobre `linux/arm64` |
| Arranque | `docker compose up -d` | PASS después de corregir rutas de runtime; PostgreSQL/backend/frontend iniciaron |
| Estado | `docker compose ps` | PASS; los tres servicios healthy |
| Migración | `prisma migrate deploy` dentro de backend | PASS; `20261009120000_init` aplicada |
| Liveness | `curl http://127.0.0.1:3000/health/live` | PASS, HTTP 200 sin DB |
| Readiness | `curl http://127.0.0.1:3000/health/ready` | PASS, HTTP 200 con `database: ok` |
| Persistencia | crear `Task`, `docker compose restart backend`, volver a leer | PASS; el mismo registro continuó disponible |
| Fallo de readiness | `docker compose stop postgres` + live/ready | PASS; live HTTP 200, ready HTTP 503 |
| Recuperación | `docker compose start postgres` + ready | PASS; ready volvió a HTTP 200 |

El registro de prueba `devops02-persistence-check` fue eliminado después de la validación. No se ejecutó `docker compose down -v` ni se eliminó el volumen.

## Incidentes y correcciones

1. Prisma no podía escribir engines en el runtime no-root; se corrigió con `chown -R node:node /app` antes de `USER node`.
2. El schema Prisma no estaba en el directorio del workspace dentro de la imagen; se copió a `/app/apps/backend/prisma`.
3. El `dist` backend estaba en `/app/dist` mientras npm ejecutaba desde `/app/apps/backend`; se copió a `/app/apps/backend/dist`.
4. El sandbox restringido bloqueó sockets HTTP y la caché de Prisma en validaciones locales; tests/build se repitieron con ejecución autorizada. No es un fallo de Node 24 ni de ARM64.

## Riesgos y gaps

### Riesgos observados

- `docker compose build` reportó vulnerabilidades npm en sus auditorías de imagen: 61 en la etapa completa y 11 en la etapa de producción. No se ejecutó `npm audit fix --force`; requiere triage separado para evitar upgrades incompatibles.
- npm reportó dependencias deprecated y scripts pendientes de aprobación. Deben revisarse antes de convertir el build en gate de CI estricto.
- Las imágenes base usan tags versionados pero todavía no están fijadas por digest en Compose/Dockerfiles.
- Las credenciales del `.env.example` son deliberadamente conocidas y sólo de desarrollo local; no son aptas para entornos compartidos.

### Gaps deliberados

- No hay CRUD completo de `Task`, autenticación ni autorización.
- La prueba `prisma.integration-spec.ts` está preparada para `RUN_INTEGRATION_TESTS=1`; la evidencia de integración ejecutada en este sprint fue el script Node dentro del contenedor backend contra PostgreSQL real.
- No hay CI, Trivy, Checkov, Kubernetes, AWS ni Terraform apply.
- No se publica PostgreSQL al host; para depuración se debe usar `docker compose exec`, no añadir un puerto permanente sin decisión documentada.

## Criterios de aceptación

- [x] Plan DEVOPS-02 creado antes de la implementación.
- [x] Dockerfiles multi-stage frontend/backend compatibles con ARM64.
- [x] Compose con frontend, backend, PostgreSQL, red interna y volumen nombrado.
- [x] Prisma `6.17.1`, schema `Task` y migración inicial versionada.
- [x] Readiness real y liveness independiente.
- [x] Healthchecks y dependencias de arranque.
- [x] Variables en `.env.example` sin secretos reales.
- [x] Tests unitarios, HTTP y prueba de persistencia real.
- [x] Documentación operativa y limpieza explícita sin ejecución automática destructiva.
- [x] npm y Compose gates ejecutados con evidencia.
- [x] No AWS, Kubernetes, Terraform apply, commits ni pushes.
