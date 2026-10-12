---
name: docker-security
description: Revisar Dockerfiles, imágenes runtime y migraciones, arranque y escaneo Trivy.
---
# Docker security
1. Leer `AGENTS.md`, `.agents/rules/docker.md` y `.agents/rules/security.md`.
2. Inspeccionar Dockerfiles, Compose y scripts de escaneo existentes.
3. Validar arranque autónomo, usuario runtime, arquitectura y migraciones desechables.
4. Registrar hallazgos reales Trivy y diferenciar vulnerabilidades de npm audit.
5. No excluir hallazgos ni cambiar políticas sin autorización.
