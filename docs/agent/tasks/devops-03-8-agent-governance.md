# DEVOPS-03.8 — Agent Governance & Repository Instructions

## Objetivo
Integrar una capa mínima y verificable de gobernanza para Codex sin interferir con DEVOPS-03.7 ni modificar aplicaciones, CI o infraestructura.

## Preflight obligatorio
1. `git branch --show-current`, `git status --short`, `git diff --stat`.
2. Verificar si DEVOPS-03.7 sigue en ejecución y si modificó archivos compartidos. Si hay conflicto, **detener la integración**, documentar y pedir reconciliación.
3. Inspeccionar instrucciones y skills ya existentes; no duplicar ni sobrescribir.
4. Revisar si la versión local de Codex reconoce `.agents/skills` y `AGENTS.md`. No declarar descubrimiento automático sin prueba.

## Implementación
- Integrar `AGENTS.md`, `.agents/rules/*.md`, `.agents/skills/*/SKILL.md` del paquete entregado, adaptando hechos si difieren del repositorio real.
- Mantener `docs/agent/tasks/` y `docs/assessments/` existentes.
- No crear `.mcp.json`, `.codex/config.toml`, `AGENTS.local.md` ni agentes ficticios sin necesidad comprobada; si se requieren, documentar esquema, soporte y secretos antes de crearlos.
- Garantizar que no se incluyan secretos, rutas personales ni datos sensibles.
- Actualizar `.gitignore` sólo si se comprueba necesidad y sin ocultar archivos de proyecto legítimos.
- No cambiar workflow, Dockerfiles, package files, Prisma, infra ni código de aplicación.

## Validación
- Validar Markdown y enlaces/rutas internas; detectar referencias inexistentes.
- Verificar frontmatter de SKILL.md y soporte real del agente; si no hay soporte, tratarlos como procedimientos documentados y reportar gap.
- Probar con una tarea de auditoría **read-only** que Codex pueda encontrar `AGENTS.md` y referenciar una regla, sin tocar GitHub/AWS.
- `git diff --check`; inspeccionar archivos nuevos para secretos.

## Evidencia y cierre
Guardar `docs/assessments/devops-03-8-agent-governance.md` con inventario, pruebas, compatibilidad, gaps y lista exacta de archivos.
Estado máximo: `PASS LOCAL` si hay pruebas locales; nunca afirmar PASS remoto sin evidencia.
No commits, pushes, merges, cambios remotos ni operaciones AWS.
