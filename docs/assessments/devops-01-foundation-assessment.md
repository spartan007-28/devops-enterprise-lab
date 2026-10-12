# DEVOPS-01 — Foundation assessment

**Fecha:** 2026-10-09<br>
**Alcance ejecutado:** contrato del repositorio y esqueleto mínimo de aplicaciones.<br>
**AWS:** no utilizado.<br>
**Docker/PostgreSQL/Prisma/Terraform:** no implementados ni ejecutados en este sprint.

## Resultado ejecutivo

DEVOPS-01 quedó implementado para el alcance solicitado. El monorepo usa npm workspaces y contiene un frontend React + Vite + TypeScript y un backend NestJS + TypeScript. El backend expone `/health/live` y `/health/ready`; ambos están cubiertos por pruebas HTTP. Readiness todavía no consulta PostgreSQL, porque PostgreSQL y Prisma están explícitamente fuera de este sprint.

Los gates finales de instalación, lint, test y build terminaron correctamente. La suite HTTP necesitó ejecutarse fuera del sandbox restringido porque éste impedía abrir un socket efímero (`listen EPERM`); no fue un fallo de la aplicación.

## Archivos creados

### Contrato raíz

- `package.json`: npm workspaces, scripts raíz y engines Node/npm.
- `package-lock.json`: versiones transitivas bloqueadas.
- `.nvmrc`: Node `24.19.0`.
- `.editorconfig`.
- `.gitignore`.
- `.env.example`: contrato no sensible para `PORT` y `VITE_API_URL`.
- `eslint.config.mjs`.
- `README.md`.

### Frontend

- `apps/frontend/package.json`.
- `apps/frontend/index.html`.
- `apps/frontend/vite.config.ts`.
- `apps/frontend/tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json`.
- `apps/frontend/src/main.tsx` y `src/styles.css`.
- `apps/frontend/src/main.test.ts`.

### Backend

- `apps/backend/package.json`.
- `apps/backend/nest-cli.json`.
- `apps/backend/tsconfig.json` y `tsconfig.build.json`.
- `apps/backend/jest.config.cjs`.
- `apps/backend/src/main.ts` y `src/app.module.ts`.
- `apps/backend/src/health/health.controller.ts`.
- `apps/backend/test/health.e2e-spec.ts`.

### Directorios futuros

- `packages/.gitkeep`.
- `infra/.gitkeep`.
- `deploy/.gitkeep`.
- `observability/.gitkeep`.

## Contrato de runtime

| Endpoint | Respuesta | Dependencias |
|---|---|---|
| `GET /health/live` | HTTP 200, `{ status: "ok", service: "backend" }` | Ninguna |
| `GET /health/ready` | HTTP 200, `{ status: "ok", service: "backend", checks: { database: "not-configured" } }` | Ninguna por ahora |

`/health/ready` es deliberadamente provisional. No debe interpretarse como disponibilidad de PostgreSQL; su contrato se actualizará cuando Prisma y PostgreSQL se integren.

## Versionado y compatibilidad

- Node.js fijado a `24.19.0` mediante `.nvmrc` y `engines`.
- npm fijado por rango compatible `>=11.17.0 <12`.
- Dependencias directas fijadas a versiones exactas.
- Dependencias transitivas fijadas en `package-lock.json`.
- Plataforma verificada: macOS ARM64; la instalación resolvió dependencias para `darwin-arm64`.

No se observó una incompatibilidad bloqueante de Node.js 24 ni de ARM64. La instalación estándar emitió warnings de dependencias deprecated y npm reportó scripts pendientes de aprobación para algunos paquetes. En el intento inicial de instalación se observó además un warning no bloqueante de `fsevents@2.3.3` durante su script nativo (`binding.gyp not found`); `npm ci` terminó con código 0 y el paquete es opcional en macOS. Esto debe vigilarse al ejecutar CI en otras plataformas.

## Scripts reproducibles

Desde la raíz:

```bash
npm ci
npm run lint
npm test
npm run build
```

Desarrollo:

```bash
npm run dev:backend
npm run dev:frontend
```

## Comandos ejecutados y resultados

| Gate | Comando final | Resultado |
|---|---|---|
| Instalación | `npm ci --no-audit --no-fund` | PASS — código 0; 881 paquetes añadidos |
| Lint | `npm run lint` | PASS — frontend y backend sin errores |
| Test | `npm test` | PASS — frontend 1 test; backend 2 tests de endpoints |
| Build | `npm run build` | PASS — Vite produjo `apps/frontend/dist`; Nest compiló backend |

### Incidentes durante la validación

1. La primera instalación quedó bloqueada por la restricción de red del sandbox y no creó lockfile ni `node_modules`; se detuvo sin modificar configuración global.
2. La primera ejecución de lint detectó globals Jest ausentes; se corrigió `eslint.config.mjs`.
3. La primera ejecución de test no encontraba `*.e2e-spec.ts` y faltaba `@types/supertest`; se corrigieron Jest y las dependencias.
4. La suite HTTP inicialmente recibió `listen EPERM` dentro del sandbox. Reejecutada con acceso autorizado para socket efímero, pasó.

## Gaps pendientes

- PostgreSQL y Prisma aún no están implementados.
- `/health/ready` no valida base de datos.
- No hay Dockerfiles, Compose ni contenedores.
- No hay CI/CD, Trivy, Checkov, kind, Helm, Kubernetes ni Argo CD.
- No hay autenticación, dominio de TaskFlow ni persistencia.
- No se agregó una matriz CI para Node/ARM64; sólo se validó el entorno local.
- Los warnings de dependencias deprecated deben revisarse antes de convertirlos en gates estrictos de CI.

## Criterios de aceptación

- [x] Monorepo npm workspace funcional.
- [x] Frontend React + Vite + TypeScript configurado.
- [x] Backend NestJS + TypeScript configurado.
- [x] Endpoints live/ready sin dependencia externa.
- [x] Readiness documentado como provisional sin PostgreSQL.
- [x] Scripts reproducibles de lint, test, build y desarrollo.
- [x] Node/npm fijados y lockfile generado.
- [x] `.gitignore`, `.editorconfig`, `.nvmrc`, `.env.example` y README creados.
- [x] Pruebas mínimas de salud implementadas y ejecutadas.
- [x] Instalación, lint, test y build verificados.
- [x] AWS no utilizado y no se crearon contenedores, Dockerfiles, PostgreSQL ni Prisma.
