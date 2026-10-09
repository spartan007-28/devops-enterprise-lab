# devops-enterprise-lab

TaskFlow es una plataforma práctica para aprender el ciclo DevOps empresarial completo.

## Estado actual

DEVOPS-02 añade containerization y persistencia local:

- `apps/frontend`: React + Vite + TypeScript.
- `apps/backend`: NestJS + TypeScript.
- PostgreSQL 16.4 en un volumen Docker nombrado.
- Prisma `6.19.3` con el modelo mínimo `Task` y migración versionada.
- `/health/live`: confirma que el proceso backend está vivo y no consulta la base.
- `/health/ready`: ejecuta una consulta real contra PostgreSQL y devuelve `503` cuando no está disponible.

No se incluyen todavía autenticación, CRUD completo, Kubernetes, AWS ni Terraform operativo.

## Requisitos

- Node.js `24.20.0` (`.nvmrc`).
- npm `11.19.0`.

La arquitectura de desarrollo objetivo es ARM64. Las dependencias se fijan en `package.json` y las versiones transitivas en `package-lock.json`.

## Instalación y comandos npm

```bash
npm install
npm run lint
npm test
npm run build
```

## Docker Compose

Requiere Docker Engine/Compose operativo y una arquitectura con imágenes multi-arquitectura disponibles. El stack publica sólo los puertos de desarrollo en loopback:

- Frontend: `http://127.0.0.1:5173`.
- Backend: `http://127.0.0.1:3000`.
- PostgreSQL no publica ningún puerto al host; backend lo alcanza por DNS interno `postgres`.

Inicializa el contrato de variables sin añadir secretos al repositorio:

```bash
cp .env.example .env
docker compose config
docker compose build
docker compose up -d
docker compose ps
```

Operación diaria:

```bash
docker compose logs -f backend
docker compose logs -f postgres
docker compose restart backend
docker compose stop
docker compose start
```

Validación de salud:

```bash
curl http://127.0.0.1:3000/health/live
curl http://127.0.0.1:3000/health/ready
```

El volumen `taskflow-postgres-data` se conserva con `docker compose stop`, `start`, `restart` y `down` sin `-v`. La limpieza que elimina los datos de desarrollo es deliberadamente explícita:

```bash
docker compose down -v
```

No ejecutar ese último comando si se desea conservar la base local. No se usan comandos globales de limpieza ni se tocan recursos de otros proyectos.

Migraciones:

```bash
docker compose exec backend npm run prisma:migrate:deploy --workspace=@taskflow/backend
```

La migración inicial sólo crea la tabla `Task`; no contiene operaciones destructivas.

Desarrollo:

```bash
npm run dev:backend   # http://localhost:3000
npm run dev:frontend  # URL mostrada por Vite, normalmente http://localhost:5173
```

El backend requiere PostgreSQL cuando se ejecuta con Compose. `/health/live` permanece independiente de PostgreSQL, mientras que `/health/ready` sólo es `200` con una conexión real disponible.

## Estructura

```text
apps/
├── backend/        # API NestJS
│   └── prisma/      # schema y migraciones
└── frontend/       # UI React + Vite
docker-compose.yml  # stack local
apps/*/Dockerfile    # imágenes multi-stage
packages/           # Librerías compartidas futuras
docs/               # Decisiones, evaluaciones y tareas
```

## Seguridad y alcance

No se guardan secretos reales. Usa `.env.example` como contrato local y crea un `.env` sin versionarlo cuando sea necesario. AWS, PostgreSQL, Prisma, Docker y Kubernetes quedan fuera de este incremento.
