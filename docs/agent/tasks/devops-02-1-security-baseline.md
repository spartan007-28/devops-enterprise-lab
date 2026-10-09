# DEVOPS-02.1 — Plan de security baseline & vulnerability triage

## Objetivo

Auditar dependencias npm e imágenes finales de DEVOPS-02, revisar la superficie de seguridad de Compose y aplicar sólo remediaciones compatibles, de bajo riesgo y sin upgrades mayores forzados. El contrato actual de TaskFlow, Prisma 6 y el flujo local deben conservarse.

## Alcance y rutas

### Artefactos a auditar

- `package.json`, `package-lock.json`: dependencias raíz y lockfile.
- `apps/backend/package.json`: runtime, Prisma y herramientas de test.
- `apps/frontend/package.json`: runtime Vite/React y herramientas de build.
- `apps/backend/Dockerfile`, `apps/frontend/Dockerfile`, `.dockerignore`: usuarios, etapas, secretos y contenido de imagen.
- `docker-compose.yml`, `.env.example`: puertos, redes, volumen, secretos de desarrollo y healthchecks.

### Artefactos de documentación

- Este plan: `docs/agent/tasks/devops-02-1-security-baseline.md`.
- Reporte final: `docs/assessments/devops-02-1-security-assessment.md`.

## Fase 1 — Auditoría reproducible

1. Ejecutar `npm audit --json` y conservar el resultado completo fuera del repositorio para análisis; registrar código de salida, severidad, paquetes directos/transitivos, rutas y versiones corregidas.
2. Comparar `npm audit --omit=dev` con la auditoría completa para separar runtime de desarrollo.
3. Ejecutar `npm ls --omit=dev --all` y `npm ls --all` para confirmar rutas instaladas.
4. Detectar Trivy sin instalarlo. Si está disponible, escanear las imágenes finales de Compose con severidad completa; si falta, documentar el bloqueo y no ocultar la ausencia.
5. Revisar Dockerfiles y Compose sin imprimir valores de entorno sensibles: usuario efectivo, puertos, redes, volumen, scripts, `COPY`, tags y exposición.
6. Verificar el volumen y persistencia recreando sólo el contenedor PostgreSQL de este proyecto, sin `down -v`, sin borrar datos y sin tocar recursos externos.

## Matriz previa a remediación

Antes de cambiar manifiestos o dependencias se registrará una matriz con:

| Hallazgo | Severidad | Paquete/ruta | Runtime o dev | Corregido disponible | Acción | Riesgo |
|---|---|---|---|---|---|---|

Las acciones serán `actualizar`, `aceptar temporalmente`, `aislar/mitigar` o `solicitar aprobación`. No se aplicará `npm audit fix --force`.

## Fase 2 — Remediación controlada

- Aplicar sólo parches/minor compatibles dentro del contrato actual.
- Mantener Prisma 6 y las versiones mayores actuales de Nest/Vite/React salvo aprobación explícita.
- Preferir cambios directos y lockfile determinista.
- No modificar funcionalidad de TaskFlow ni credenciales de desarrollo.
- Si un advisory sólo tiene corrección en una major incompatible, documentarlo como riesgo residual y solicitar aprobación antes de cambiarlo.

## Fase 3 — Validación posterior

Ejecutar y registrar evidencia de:

- `npm ci`.
- `npm run lint`.
- `npm test`.
- `npm run build`.
- `docker compose config`.
- `docker compose build`.
- `docker compose up -d`, `docker compose ps` y endpoints de salud.
- auditoría npm posterior; Trivy posterior si está disponible.
- recreación exclusiva del contenedor PostgreSQL y lectura de un registro de prueba creado por la validación.

La prueba de persistencia sólo puede eliminar el registro de prueba creado por este sprint; nunca se eliminará el volumen ni datos históricos.

## Política inicial de CI

- Bloquear `CRITICAL` confirmado en artefactos finales, salvo excepción temporal con propietario, fecha de expiración y aprobación.
- Evaluar `HIGH` considerando exposición, runtime/dev, disponibilidad de parche y explotabilidad; bloquear si afecta runtime final sin mitigación.
- Registrar `MEDIUM` y `LOW` como deuda con seguimiento y fecha objetivo.
- No bloquear automáticamente por vulnerabilidades exclusivas de herramientas de desarrollo sin análisis de riesgo.
- No usar exclusiones globales que oculten hallazgos; cualquier excepción debe ser específica, justificada y temporal.
- Un escaneo limpio no equivale a seguridad completa: mantener revisión de configuración, secretos, permisos, imagen base, SBOM y comportamiento runtime.

## Riesgos y límites

- Trivy podría no estar instalado o no disponer de su base de datos; documentar el bloqueo sin instalar globalmente.
- `npm audit` puede reportar vulnerabilidades de herramientas de desarrollo que no llegan a la imagen final.
- Las imágenes base tagueadas pueden cambiar si no se fijan por digest; cualquier pinning de digest requiere validar ARM64.
- El `.env.example` contiene valores conocidos de desarrollo; nunca debe reutilizarse en entornos compartidos.
- El stack Compose local queda fuera de AWS, Kubernetes y Terraform.

## Criterios de aceptación

- [ ] Auditoría npm completa y runtime registrada sin ocultar hallazgos.
- [ ] Trivy ejecutado o ausencia documentada como prerequisito.
- [ ] Matriz de hallazgos y remediaciones creada antes de aplicar cambios.
- [ ] Sólo remediaciones compatibles y de bajo riesgo aplicadas.
- [ ] Prisma 6 y contrato TaskFlow conservados.
- [ ] Usuario, permisos, redes, puertos y secretos revisados.
- [ ] Persistencia verificada recreando sólo PostgreSQL y conservando el volumen.
- [ ] Lint, tests, build, Compose config/build/up/ps y healthchecks repetidos.
- [ ] Política DevSecOps y riesgos residuales documentados.
- [ ] Sin AWS, upgrades mayores forzados, instalaciones globales, borrado de volúmenes, commits o pushes.
