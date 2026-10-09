# DEVOPS-01 — Plan de foundation

## Objetivo

Preparar una base reproducible y segura para TaskFlow: monorepo documentado, runtime local, contrato mínimo de desarrollo, validaciones automatizables y camino claro hacia Docker, kind, CI/CD, GitOps y AWS sin consumir presupuesto durante la fase inicial.

## Precondiciones verificadas

- Git, Docker CLI, Docker Compose, Node.js/npm, Terraform, AWS CLI y kubectl están disponibles.
- Docker daemon no está validado por un error de permisos en el socket local.
- Helm, kind y Ansible no están disponibles en el PATH.
- El repositorio no tiene commits ni archivos de aplicación.

## Alcance de DEVOPS-01

Incluye la creación posterior de la estructura base, convenciones, documentación, archivos de configuración no secretos y una validación local mínima. No incluye todavía funcionalidad completa de TaskFlow, despliegue AWS/EKS, acceso a infraestructura, Argo CD operativo ni observabilidad distribuida completa.

## Secuencia incremental

### Fase 1 — Contrato del repositorio

Definir README, `.gitignore`, licencia si aplica, convenciones de ramas, estrategia de commits, `.editorconfig`, versión de Node y estructura de `apps`, `packages`, `infra`, `deploy`, `observability`, `docs` y workflows.

**Salida:** cualquier colaborador puede entender el layout y los comandos esperados sin conocer decisiones implícitas.

### Fase 2 — Prerrequisitos locales

Resolver con el propietario del equipo el acceso al daemon Docker. Añadir una comprobación documentada para Git, Node/npm, Docker/Compose y, cuando estén disponibles, kind/Helm. No automatizar instalaciones.

**Validaciones:** `docker info` sólo como prueba de disponibilidad; un contenedor de prueba efímero y no destructivo podrá usarse únicamente cuando el daemon sea accesible.

### Fase 3 — Esqueleto de aplicaciones

Crear los proyectos React + Vite y NestJS dentro de `apps`, fijar package manager/versiones, habilitar linting, formatting, tests y health endpoint. Crear el contrato inicial de variables de entorno con `.env.example`, sin valores sensibles reales.

**Salida:** frontend y backend arrancan localmente y el backend expone un health check.

### Fase 4 — Persistencia local

Añadir PostgreSQL en Compose con volumen nombrado y red privada. Integrar Prisma, schema inicial y migración reproducible. Documentar inicialización y limpieza explícita de datos de desarrollo.

**Salida:** backend puede comprobar conectividad y ejecutar una migración en una base local nueva.

### Fase 5 — Contenedores y calidad

Crear Dockerfiles multi-stage para frontend/backend, `.dockerignore` y Compose de desarrollo. Añadir escaneo Trivy de imagen/FS y Checkov cuando existan Terraform/manifests. Evitar publicar imágenes durante esta fase.

**Salida:** build reproducible, imágenes con usuario no-root cuando sea viable y fallos visibles en CI.

### Fase 6 — Kubernetes local

Cuando kind y Helm estén disponibles, crear un clúster local efímero y desplegar sólo los servicios mínimos. Usar manifests base y overlay local; PostgreSQL puede permanecer gestionado por Compose inicialmente para reducir complejidad.

**Salida:** despliegue local repetible, health/readiness probes y rollback documentado.

### Fase 7 — CI/CD y GitOps

GitHub Actions ejecutará install reproducible, lint, tests, build, Trivy y Checkov. Argo CD se añadirá después de que manifests y despliegues locales sean estables. Usar OIDC para AWS en la fase cloud; no guardar claves en secrets estáticos salvo excepción justificada.

### Fase 8 — AWS bajo presupuesto

Diseñar primero Terraform con plan-only, tags obligatorios, variables de región/costos y validaciones. EKS no es el primer destino si el costo real excede el límite: evaluar alternativas de aprendizaje y destruir recursos temporales al terminar.

## Definition of Done

- El layout del monorepo está documentado y coincide con los paths reales.
- La versión de Node y el gestor de paquetes están fijados y reproducibles.
- `npm ci`/equivalente, lint, tests y build tienen comandos documentados.
- Compose define sólo dependencias necesarias y no contiene secretos reales.
- PostgreSQL usa persistencia local explícita y credenciales de desarrollo separadas.
- Backend tiene health/readiness checks y logs útiles sin datos sensibles.
- Docker build funciona en la arquitectura soportada o documenta una limitación arm64.
- kind/Helm se marcan como prerequisitos y no se simula su disponibilidad.
- CI ejecuta validaciones antes de cualquier publicación.
- Trivy y Checkov tienen criterios de severidad documentados.
- Terraform tiene formato, validación, lockfile de providers y plan sin apply automático.
- AWS no se toca sin aprobación explícita, presupuesto, tags, alertas y plan revisado.
- No hay secretos, credenciales, kubeconfigs ni estados Terraform comprometidos.

## Controles de seguridad

- Secret scanning en pre-commit/CI y `.gitignore` para `.env`, estados y artefactos.
- Dependencias fijadas mediante lockfile y actualizaciones revisadas.
- Imágenes mínimas, escaneadas y ejecutadas como no-root cuando sea compatible.
- Variables sensibles inyectadas en runtime; nunca hardcodeadas.
- Terraform state remoto sólo después de diseñar cifrado, locking y mínimo privilegio.
- AWS OIDC y roles separados para plan/apply; apply manual con aprobación.

## Controles de costos

- Desarrollo local primero; no crear EKS como requisito de DEVOPS-01.
- Tags: `project`, `environment`, `owner`, `expires-at` y `cost-center`.
- Presupuesto/alerta antes del primer recurso facturable.
- Prohibir por defecto NAT Gateway, balanceadores permanentes y volúmenes sin TTL en laboratorios.
- Checklist de apagado/destrucción y revisión de costos después de cada laboratorio.

## Riesgos y mitigaciones del plan

| Riesgo | Mitigación | Señal de salida |
|---|---|---|
| Docker no accesible | Resolver permisos/daemon con el dueño del equipo y repetir prueba | `docker info` exitoso |
| Node no-LTS o dependencia incompatible | Fijar versión LTS y ejecutar matriz mínima | install/build/tests verdes |
| Imágenes no compatibles con arm64 | Verificar manifest de plataforma o documentar buildx | imagen ejecutable localmente |
| Helm/kind faltantes | Tratar como prerequisitos explícitos, sin mocks | clúster local creado por el equipo |
| Fuga de secretos | `.gitignore`, secret scan, revisión de workflows | scan sin hallazgos críticos |
| Sobrecosto AWS | local-first, alertas, tags, TTL y plan-only | costo estimado aprobado |

## Criterios de aceptación de DEVOPS-01

1. El repositorio contiene la estructura base acordada y documentación de onboarding.
2. El entorno requerido y sus estados reales están reflejados en la documentación.
3. Existe un flujo local reproducible para levantar las dependencias y validar health checks.
4. Las validaciones de calidad y seguridad están definidas antes de habilitar publicación.
5. El plan Kubernetes separa local/kind de EKS y no requiere AWS para completarse.
6. Las decisiones de costos y seguridad tienen gates explícitos.
7. Todo cambio es reversible, revisable y no depende de credenciales almacenadas en el repo.

## Orden recomendado de ejecución posterior

1. Confirmar acceso al daemon Docker.
2. Acordar la versión LTS de Node y el gestor de paquetes.
3. Crear el esqueleto y documentación del monorepo.
4. Crear frontend/backend mínimos y health check.
5. Integrar PostgreSQL/Prisma con Compose.
6. Añadir Dockerfiles, tests, lint, Trivy y Checkov.
7. Incorporar kind y Helm cuando estén disponibles.
8. Añadir GitHub Actions; después Argo CD.
9. Diseñar Terraform y revisar costos antes de cualquier `apply`.
