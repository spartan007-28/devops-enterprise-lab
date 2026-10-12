# DEVOPS-02 — Plan de containerization & local persistence

## Objetivo

Convertir el esqueleto de DEVOPS-01 en un entorno local reproducible con Docker Compose, PostgreSQL persistente y Prisma, manteniendo una separación explícita entre liveness y readiness. El alcance queda limitado a desarrollo local sobre ARM64; no incluye AWS, Terraform apply, Kubernetes, autenticación ni funcionalidades completas de TaskFlow.

## Estado inicial confirmado

- Monorepo npm workspace con `apps/frontend` y `apps/backend`.
- Node.js `24.19.0`, npm `11.17.0`, dependencias directas fijadas y `package-lock.json` versionado.
- Backend NestJS sin dependencias de persistencia.
- `/health/live` y `/health/ready` existen; readiness aún devuelve `database: not-configured`.
- No existen Dockerfiles, `docker-compose.yml`, Prisma schema ni migraciones.
- Docker Engine `29.8.2`, Docker Compose `5.5.1`, contexto `desktop-linux`, arquitectura ARM64 confirmados por el solicitante.

## Cambios previstos y rutas exactas

### Raíz

- `docker-compose.yml`: servicios `frontend`, `backend` y `postgres`, red interna de datos, volumen nombrado, healthchecks y dependencias.
- `.env.example`: variables no sensibles de desarrollo; no incluir contraseñas reales.
- `README.md`: comandos de build/start/stop/logs/reinicio/limpieza y límites de persistencia.
- `package.json` y `package-lock.json`: scripts raíz, si hacen falta, y versiones bloqueadas.

### Frontend

- `apps/frontend/Dockerfile`: multi-stage ARM64-compatible, build Vite y servidor estático no-root.
- `apps/frontend/.dockerignore`: excluir `node_modules`, `dist`, `.env` y artefactos locales.

### Backend

- `apps/backend/Dockerfile`: multi-stage ARM64-compatible, dependencias reproducibles, generación Prisma y ejecución no-root.
- `apps/backend/.dockerignore`: excluir dependencias, builds, coverage, `.env` y secretos.
- `apps/backend/prisma/schema.prisma`: datasource PostgreSQL y modelo mínimo `Task`.
- `apps/backend/prisma/migrations/<timestamp>_init/migration.sql`: migración inicial no destructiva para una base nueva.
- `apps/backend/src/prisma/prisma.service.ts`: cliente Prisma y lifecycle Nest.
- `apps/backend/src/health/health.controller.ts`: liveness independiente y readiness con comprobación real de base de datos.
- `apps/backend/src/health/health.service.ts`: `SELECT 1`/equivalente Prisma, contrato estable y manejo de error.
- `apps/backend/src/app.module.ts`: registrar Prisma/health.
- `apps/backend/test/health.e2e-spec.ts`: actualizar pruebas live/ready con mock o base disponible según el nivel.
- `apps/backend/test/prisma.integration-spec.ts`: prueba de persistencia real contra PostgreSQL Compose, condicionada al entorno de integración.

## Dependencias y versionado

- Añadir `@prisma/client` y `prisma` con versiones exactas compatibles con Node 24 y ARM64.
- Mantener Prisma CLI como dependencia de desarrollo y ejecutar `prisma generate` en instalación/build de backend.
- Añadir sólo dependencias necesarias para el cliente Prisma, integración Nest y tests.
- Ejecutar `npm install`/`npm ci` para actualizar `package-lock.json`; no instalar paquetes globalmente.
- Verificar imágenes base multi-arquitectura antes de aceptar el build. Preferir imágenes oficiales con variantes `linux/arm64`.

## Diseño de Compose

- Servicio `postgres`: imagen PostgreSQL multi-arquitectura, volumen nombrado `taskflow-postgres-data`, red privada `taskflow-data`, healthcheck `pg_isready` y sin publicar el puerto al host por defecto.
- Servicio `backend`: depende de `postgres` con condición `service_healthy`, recibe `DATABASE_URL` sólo por interpolación del archivo `.env`, expone `3000` al host para pruebas y define healthcheck HTTP de readiness.
- Servicio `frontend`: build multi-stage, expone `5173` al host si el servidor elegido lo permite; el runtime no recibe secretos.
- La red de datos será interna para PostgreSQL/backend. Si el frontend necesita acceso al backend desde el navegador, la URL pública de desarrollo se documentará separadamente; no se expondrá PostgreSQL.
- `restart` se limitará a una política de desarrollo razonable y no sustituirá healthchecks.

## Persistencia y seguridad

- `DATABASE_URL` sólo tendrá valores de desarrollo local en `.env.example` como plantilla; las credenciales reales no se versionan.
- El volumen nombrado persiste datos tras reinicios normales (`docker compose restart`, `up/down` sin `-v`).
- No ejecutar automáticamente `docker compose down -v`, `docker volume rm`, eliminación de imágenes ni limpiezas globales.
- Cualquier limpieza documentada requerirá que el usuario ejecute explícitamente `docker compose down -v` y se advertirá que elimina los datos de este stack.
- PostgreSQL no se publicará en todas las interfaces; el acceso de backend será por DNS interno `postgres`.
- Aplicaciones y servidor estático se ejecutarán como usuario no-root cuando las imágenes y permisos lo permitan.
- No copiar `.env`, `.env.*` reales, credenciales, logs sensibles ni `node_modules` a las imágenes.

## Health checks y pruebas

- `/health/live`: sólo prueba que el proceso Nest responde; nunca consulta Prisma.
- `/health/ready`: consulta PostgreSQL mediante Prisma y devuelve 200 sólo si la conexión está disponible; ante fallo devuelve estado no listo y código HTTP documentado.
- Test unitario: mockear Prisma para cubrir éxito y fallo de readiness sin requerir una base.
- Test de integración: usar PostgreSQL del Compose, ejecutar migración y crear/leer un `Task` mínimo.
- Validar recuperación: detener sólo `postgres`, comprobar fallo de readiness, iniciar/recrear el servicio y comprobar recuperación.
- Validar persistencia: crear un `Task`, reiniciar el stack sin `-v`, comprobar que el registro continúa.

## Secuencia de implementación

1. Añadir este plan y congelar el alcance.
2. Añadir Prisma, schema `Task`, configuración de generación y migración inicial.
3. Implementar `PrismaService` y readiness real, manteniendo liveness independiente.
4. Añadir tests unitarios/integración y ajustar scripts reproducibles.
5. Crear Dockerfiles multi-stage y `.dockerignore` para frontend/backend.
6. Crear Compose con red, volumen, healthchecks y dependencias.
7. Actualizar `.env.example` y README con ciclo operativo y advertencias de limpieza.
8. Ejecutar gates npm, Compose config/build/up/ps, migración, health, persistencia y recuperación.
9. Documentar resultados exactos, warnings, fallos y gaps en `docs/assessments/devops-02-containerization-assessment.md`.

## Riesgos y mitigaciones

| Riesgo | Mitigación | Evidencia requerida |
|---|---|---|
| Imagen/base sin ARM64 | Verificar manifest y ejecutar build local `linux/arm64` | `docker compose build` exitoso |
| Prisma/Node 24 incompatible | Fijar versiones y ejecutar generate/build/test | install/build/tests sin error |
| Readiness falso positivo | Prisma `SELECT 1` y pruebas con PostgreSQL detenido | 200/503 o contrato definido según estado |
| Pérdida accidental de datos | Volumen nombrado; no usar `down -v` automáticamente | Task sobrevive reinicio |
| Exposición de PostgreSQL | Sin `ports` por defecto y red privada | `docker compose config`/inspección de puertos |
| Secretos en imagen/repo | `.env.example`, dockerignore y revisión de contenido | sin secretos reales |
| Migración destructiva | Primera migración sólo crea tabla/índices | SQL revisado antes de ejecutar |
| Recursos ajenos afectados | Usar nombres/volumen/red propios del proyecto | sólo recursos `taskflow-*` |

## Criterios de aceptación

- [ ] El plan existe antes de los cambios de implementación.
- [ ] `npm ci`, lint, tests y build pasan con versiones fijadas.
- [ ] Frontend y backend tienen Dockerfiles multi-stage ejecutables en ARM64.
- [ ] Compose define frontend, backend y PostgreSQL con red privada, volumen nombrado y healthchecks.
- [ ] PostgreSQL no publica su puerto a todas las interfaces ni requiere acceso desde el host.
- [ ] Prisma está integrado con versiones exactas, schema mínimo `Task` y migración inicial versionada.
- [ ] `/health/live` sigue operando sin PostgreSQL.
- [ ] `/health/ready` refleja conectividad real de PostgreSQL y tiene pruebas de éxito/fallo/recuperación.
- [ ] Un `Task` persiste tras reiniciar el stack sin eliminar el volumen.
- [ ] `docker compose config`, `build`, `up -d`, `ps`, migración y health endpoints tienen evidencia real.
- [ ] README documenta build, start, stop, logs, restart y limpieza explícita con advertencia de datos.
- [ ] No hay secretos reales, cambios AWS, Terraform apply, Kubernetes, commits ni pushes.

## Gaps deliberados

- No autenticación ni autorización.
- No CRUD completo de tareas.
- No Docker Compose de producción.
- No migraciones automáticas destructivas.
- No AWS, EKS, Terraform apply ni Kubernetes.
