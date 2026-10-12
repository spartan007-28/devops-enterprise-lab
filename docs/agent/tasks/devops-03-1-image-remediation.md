# DEVOPS-03.1 — Image Vulnerability Remediation Plan

Fecha: 2026-10-09<br>
Proyecto: `devops-enterprise-lab`

## Objetivo

Reducir vulnerabilidades verificadas en las imágenes `taskflow/frontend`, `taskflow/backend` y `taskflow/migrate` sin debilitar la política de CI, mantener Node 24, NestJS 11, Prisma 6 y Vitest 3, ni modificar datos, AWS o recursos externos.

## Análisis previo requerido

1. Confirmar las rutas transitivas de `tar`, `tinypool`, `brace-expansion`, `ip-address`, `undici` y `http-cache-semantics` con `npm ls`, `npm explain` y el lockfile.
2. Inspeccionar cada imagen real: usuario efectivo, paquetes npm globales, módulos de producción y presencia de Prisma CLI/tooling.
3. Separar componentes por uso:
   - build/test/lint: dependencias de desarrollo del workspace;
   - migraciones: Prisma CLI y sus dependencias, sin Vitest ni Jest requeridos para ejecutar `prisma migrate deploy`;
   - runtime backend: NestJS, `@prisma/client`, artefactos compilados y engine Prisma;
   - runtime frontend: servidor estático y archivos Vite compilados.
4. Registrar conteos Trivy previos por imagen y severidad a partir de los reportes de DEVOPS-03.

## Archivos previstos

- `apps/frontend/Dockerfile`: actualizar la imagen base compatible con Node 24/ARM64 si existe una versión parcheada; conservar runtime no-root.
- `apps/backend/Dockerfile`: separar con precisión build, migraciones y runtime; evitar copiar dependencias de desarrollo al runtime final.
- `package.json`, manifests de workspaces y `package-lock.json`: sólo actualizar dependencias directas/transitivas compatibles y aprobadas; no ejecutar `npm audit fix --force`.
- `scripts/security/trivy-scan.sh`: conservar el escaneo completo, SBOM y clasificación técnica; no introducir exclusiones.
- `scripts/security/evaluate-policy.sh`: no relajar la política; sólo ajustar el contexto si la composición real de imágenes lo exige.
- `docs/assessments/devops-03-1-image-remediation-assessment.md`: evidencia antes/después, causa raíz, cambios, gates, riesgos y decisión final.

## Estrategia de remediación

1. Prioridad 1: eliminar de las imágenes finales las dependencias que sólo pertenecen a tooling. No copiar `node_modules` de build/migrations a runtime.
2. Prioridad 2: actualizar la imagen base Node 24 Alpine a un parche compatible que contenga versiones corregidas de npm/tar/OpenSSL, verificando digest, arquitectura ARM64 y compatibilidad de ejecución.
3. Prioridad 3: actualizar sólo paquetes compatibles dentro de sus majors actuales. Prisma permanece en 6, NestJS en 11, Node en 24 y Vitest en 3.
4. Para `tinypool`, no saltar a Vitest 5 sin aprobación; si la única corrección requiere esa major, documentar el bloqueo.
5. Para HIGH de runtime sin parche directo (`http-cache-semantics`) documentar exposición, presencia real y mitigación; no usar una excepción general.
6. Reconstruir desde cero las tres imágenes y conservar JSON/SBOM de Trivy para la comparación.

## Riesgos

- Actualizar la imagen base puede modificar OpenSSL, npm y certificados; requiere repetir build, tests, healthchecks y migración.
- `npm ci --omit=dev` en un workspace puede conservar peers de Prisma; se debe inspeccionar el filesystem final, no inferirlo sólo de `npm audit`.
- La imagen de migraciones requiere Prisma CLI y no es equivalente al runtime backend; el gate debe seguir escaneando ambos contextos.
- Una vulnerabilidad reportada por Trivy puede estar en el npm global de la imagen base y no ser usada por la aplicación; aun así debe permanecer visible y evaluada.
- Si persiste cualquier CRITICAL, el estado final será BLOCKED y no se alterará la política para obtener PASS.

## Criterios de aceptación

- [ ] Causa raíz y ruta de cada CRITICAL documentadas por imagen.
- [ ] Imágenes finales no contienen dependencias de test/build que no sean necesarias para su función.
- [ ] `tar` y `tinypool` se eliminan o actualizan de manera verificable; si no es posible, queda bloqueo explícito.
- [ ] HIGH de OpenSSL, `brace-expansion`, `ip-address`, `undici` y `http-cache-semantics` evaluados con evidencia de contenido y exposición.
- [ ] `npm ci`, lint, tests y build pasan.
- [ ] `docker compose config --quiet` pasa.
- [ ] Builds frontend, backend y migraciones pasan en la arquitectura disponible.
- [ ] Trivy genera reporte JSON y SBOM para las tres imágenes sin error técnico.
- [ ] Migración Prisma, health endpoints y persistencia PostgreSQL pasan sin eliminar el volumen.
- [ ] Conteos antes/después por imagen y severidad publicados.
- [ ] Estado del gate de seguridad declarado como PASS, PASS_WITH_REVIEW o BLOCKED según evidencia real.
- [ ] No se realizan commits, pushes, publicaciones, AWS, Kubernetes ni cambios globales.
