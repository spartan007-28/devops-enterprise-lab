# DEVOPS-00 — Evaluación del entorno local

**Fecha de evaluación:** 2026-10-09<br>
**Plataforma:** macOS 27.0.1, arm64<br>
**Repositorio:** `devops-enterprise-lab`<br>
**Alcance:** diagnóstico de lectura; no se instalaron herramientas, no se modificó configuración y no se accedió a AWS.

## Resumen ejecutivo

El entorno tiene una base suficiente para comenzar el trabajo local con Git, Docker CLI, Docker Compose, Node.js, npm, Terraform, AWS CLI y kubectl. Faltan Helm, kind y Ansible. Docker CLI está instalado, pero el daemon no pudo validarse: la conexión al socket local terminó en `permission denied`. El repositorio está vacío, sin commits ni archivos de aplicación.

La recomendación es completar primero la base local y fijar versiones mediante documentación y archivos de proyecto. Antes de ejecutar cualquier flujo con contenedores, debe resolverse y volver a probarse la disponibilidad del daemon. AWS debe quedar fuera del primer incremento: el presupuesto de 500 MXN mensuales requiere controles de costos y una validación explícita antes de crear recursos.

## Herramientas detectadas

| Herramienta | Ubicación | Versión observada | Estado de verificación | Compatibilidad inicial |
|---|---|---:|---|---|
| Git | `/usr/bin/git` | 2.54.0 | Ejecutable | Adecuado para el monorepo y GitHub Actions |
| Docker CLI | `/usr/local/bin/docker` | 29.8.1 | Ejecutable; daemon no validado | Adecuado, sujeto a Docker Desktop/daemon accesible |
| Docker Compose | `/usr/local/bin/docker-compose` | v5.5.1 | Ejecutable | Adecuado; usar preferentemente `docker compose` |
| Node.js | `~/.nvm/versions/node/v24.19.0/bin/node` | v24.19.0 | Ejecutable | Compatible con Vite/NestJS, pero conviene fijar una línea LTS para estabilidad |
| npm | junto a Node.js | 11.17.0 | Ejecutable | Compatible con workspaces; fijar versión en la documentación |
| Terraform | `/opt/homebrew/bin/terraform` | v1.15.8, darwin_arm64 | Ejecutable | Adecuado; fijar versión y provider lockfile cuando se implemente |
| AWS CLI | `/usr/local/bin/aws` | 2.36.5, arm64 | Ejecutable | Adecuado; no se inspeccionaron perfiles, credenciales ni identidad |
| kubectl | `/usr/local/bin/kubectl` | v1.36.1, darwin_arm64 | Ejecutable como cliente | Adecuado; aún no se validó un clúster |

## Herramientas faltantes

| Herramienta | Resultado | Impacto |
|---|---|---|
| Helm | No encontrado en PATH | Impide empaquetar/instalar charts localmente y preparar el camino a Argo CD |
| kind | No encontrado en PATH | Impide crear el clúster Kubernetes local previsto |
| Ansible | No encontrado en PATH | No bloquea el MVP; sólo afecta automatización adicional de máquinas/configuración |

## Compatibilidad y observaciones

- La arquitectura arm64 es consistente entre el host y los binarios principales. Las imágenes Docker y charts deberán probarse explícitamente en arm64; algunas imágenes de observabilidad o herramientas pueden depender de soporte multi-arquitectura.
- Node.js v24.19.0 no debe asumirse como línea de producción hasta fijar la matriz soportada por NestJS, Vite y dependencias. Se recomienda seleccionar una versión LTS y declarar el requisito con `.nvmrc` o `engines`.
- Docker Compose responde mediante el plugin/comando disponible, pero la prueba del daemon falló con `permission denied` sobre `~/.docker/run/docker.sock`. No se verificaron builds, pulls, redes ni volúmenes.
- Terraform y AWS CLI sólo se validaron a nivel de binario/ayuda/versionado. No se ejecutaron comandos de identidad, plan, apply ni consultas que pudieran tocar AWS.
- kubectl sólo se validó como cliente. No existe evidencia de que kind, EKS o cualquier otro clúster esté configurado.
- El repositorio reporta `No commits yet on main` y no contiene archivos de proyecto detectables. No hay base existente que preservar ni configuración que validar.

## Riesgos

### Técnicos

1. Docker daemon inaccesible: bloquea la ejecución local de PostgreSQL, builds y Kubernetes basado en contenedores.
2. Herramientas faltantes: kind y Helm bloquean el primer laboratorio Kubernetes; Ansible no es prioritario.
3. Drift de versiones: Node/npm, Terraform, kubectl y charts pueden cambiar el comportamiento si no se fijan.
4. Arm64: riesgo de imágenes incompatibles o diferencias entre desarrollo local y runners/arquitectura de EKS.
5. Complejidad prematura: desplegar observabilidad completa y GitOps antes del flujo mínimo puede consumir tiempo y recursos sin validar el producto.

### Seguridad

1. No deben almacenarse credenciales AWS, tokens, `.env` reales ni kubeconfigs sensibles en el repositorio.
2. Los workflows deben usar OIDC y roles de mínimo privilegio cuando se habilite AWS; evitar claves estáticas.
3. Trivy, Checkov, lockfiles, branch protection y revisión de secretos deben ser gates antes de publicar imágenes o infraestructura.
4. PostgreSQL local debe estar aislado en una red Docker y usar credenciales sólo para desarrollo.

### Costos

1. El límite de 500 MXN/mes es estrecho para EKS, NAT Gateway, balanceadores y observabilidad persistente.
2. NAT Gateway, volúmenes EBS, IPs públicas, logs y snapshots pueden generar costos inesperados.
3. La estrategia inicial debe ser local/kind y usar AWS sólo con presupuesto, alertas, tags, TTL y apagado/eliminación planificada.

## Estructura propuesta del monorepo

```text
devops-enterprise-lab/
├── apps/
│   ├── frontend/                 # React + Vite
│   └── backend/                  # NestJS + Prisma
├── packages/                    # Librerías compartidas opcionales
├── infra/
│   ├── terraform/
│   │   ├── modules/
│   │   └── environments/
│   └── kubernetes/
│       ├── base/
│       ├── overlays/local/
│       └── overlays/eks/
├── deploy/
│   ├── helm/
│   └── argocd/
├── observability/
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   └── tempo/
├── .github/workflows/
├── docs/
│   ├── assessments/
│   ├── agent/tasks/
│   └── architecture/
├── docker-compose.yml
├── Makefile
├── README.md
└── .gitignore
```

La estructura es propuesta, no creada como parte de esta auditoría. La separación entre `infra`, `deploy`, `observability` y `apps` evita mezclar código de producto con estado/configuración operacional.

## Arquitectura local inicial

```text
Developer
  ├── frontend (Vite) :5173 ──HTTP──┐
  └── backend (NestJS) :3000 ───────┼── PostgreSQL :5432
                                    └── Prisma migrations

Docker Compose: frontend, backend y PostgreSQL
kind (fase siguiente): Kubernetes local para backend/frontend/PostgreSQL
```

- **Frontend:** interfaz TaskFlow; consume la API mediante una URL configurable.
- **Backend:** API NestJS, validación, autenticación futura, reglas de tareas/proyectos y health checks.
- **Prisma:** esquema, migraciones y acceso tipado a PostgreSQL; las migraciones deben ejecutarse de forma explícita.
- **PostgreSQL:** persistencia local, volumen nombrado y red interna; no publicar el puerto fuera de desarrollo salvo necesidad.
- **Docker Compose:** reproducibilidad de desarrollo y dependencias locales.
- **kind:** clúster efímero para manifests, ingress y prácticas Kubernetes; queda bloqueado hasta instalarse.
- **Observabilidad inicial:** health endpoint y logs estructurados; Prometheus/Grafana/Loki/Tempo se incorporan por etapas.
- **CI/CD y GitOps:** GitHub Actions valida y construye; Argo CD se introduce después de tener manifests reproducibles.

## Criterios de aceptación

### DEVOPS-00 — Evaluación del entorno

- Existe este informe en `docs/assessments/devops-00-environment-assessment.md`.
- Cada herramienta solicitada figura como detectada, faltante o no validada, con evidencia de versión cuando existe.
- Docker distingue entre CLI instalada y daemon no validado.
- No se imprimen credenciales, secretos, perfiles AWS ni contenido sensible.
- Se documentan compatibilidad, riesgos técnicos/seguridad/costos y recomendaciones.
- La estructura del monorepo y la arquitectura local están definidas sin crear la aplicación.
- El estado inicial del repositorio se conserva sin commits ni cambios fuera de los documentos solicitados.

### DEVOPS-01 — Foundation

- Existe un plan ejecutable en `docs/agent/tasks/devops-01-foundation.md`.
- El plan prioriza prerequisitos locales y define responsables, entradas, salidas y validaciones por incremento.
- Incluye un `Definition of Done` verificable para Docker, Node, Compose, Git, documentación y controles básicos.
- No asume que kind, Helm, Ansible o el daemon Docker ya están disponibles.
- Define guardrails de secretos, costos, arquitectura arm64 y reversibilidad.

## Recomendación inmediata

1. Resolver el acceso local al daemon Docker y repetir una prueba no destructiva.
2. Elegir y fijar una versión LTS de Node para el proyecto.
3. Instalar posteriormente kind y Helm mediante el mecanismo aprobado por el equipo; no forma parte de esta tarea.
4. Mantener Ansible fuera del camino crítico inicial.
5. Implementar primero una base local reproducible y dejar AWS/EKS para un incremento con presupuesto y controles aprobados.
