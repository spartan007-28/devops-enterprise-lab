# Docker
- Validar builds multi-stage, usuario no root, archivos `.dockerignore`, health checks y arranque autónomo sin overrides.
- Probar runtime, migraciones Prisma y Compose separadamente; no alterar migraciones históricas.
- Escanear imágenes finales y registrar arquitectura (arm64/amd64), versiones y resultados.
- Evitar credenciales en Dockerfile, build args persistidos o capas.
