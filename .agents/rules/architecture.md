# Arquitectura
- Stack actual: React/Vite/TypeScript (`apps/frontend`), NestJS/TypeScript (`apps/backend`), PostgreSQL/Prisma, Docker Compose y GitHub Actions.
- Infraestructura futura: Terraform, Kubernetes y observabilidad; no asumir que ya están implementados.
- Respetar contratos existentes, rutas y migraciones históricas. Evitar refactors no solicitados.
- Identificar explícitamente diferencias entre desarrollo local (arm64) y CI (Linux amd64).
