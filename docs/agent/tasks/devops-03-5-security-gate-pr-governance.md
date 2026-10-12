# DEVOPS-03.5 — Security Gate & PR Governance

## Contexto verificado

Repositorio: `devops-enterprise-lab`.
Rama del Pull Request #1: `chore/devops-03-first-ci` hacia `main`.
Última ejecución remota observada: GitHub Actions Run #2, cinco jobs exitosos, decisión de seguridad `PASS_WITH_REVIEW`, un HIGH residual asociado a `deepmerge-ts` en la imagen de migraciones y aprobación humana pendiente.

**No confundir CI verde con aceptación del riesgo.** No se ha autorizado el merge.

## Objetivo

Auditar y proponer un mecanismo de gobernanza que impida integrar cambios con vulnerabilidades HIGH pendientes sin una aceptación humana explícita, verificable, acotada y trazable. Conservar los bloqueos existentes para CRITICAL y fallos técnicos. No ocultar ni modificar hallazgos para conseguir un check verde.

## Fase 0 — Inspección de contratos existentes (solo lectura)

1. Leer `.github/workflows/ci.yml`, `scripts/security/evaluate-policy.sh`, `scripts/security/npm-audit-report.sh`, `scripts/security/trivy-scan.sh`, `docs/assessments/devops-03-2-1-final-hardening.md` y `docs/assessments/devops-03-4-first-remote-ci-fix.md`.
2. Identificar el JSON exacto de política, sus campos, sus exit codes y el flujo real de artifacts. No inventar nombres ni rutas.
3. Revisar el alcance del HIGH `deepmerge-ts`: paquete, versión, identificador de vulnerabilidad, imagen afectada, etapa/uso de Prisma CLI, exposición y opciones reales de remediación. Distinguir hechos respaldados por reportes de hipótesis. No asumir que es explotable ni inocuo.
4. Inspeccionar el estado de protección de `main`, rulesets, branch protection, revisiones requeridas, checks requeridos y permisos de bypass solo si hay acceso autorizado y de solo lectura. Si no se puede consultar, registrar `NOT VERIFIED` y proporcionar pasos manuales.
5. Comprobar las capacidades efectivamente disponibles para el repositorio privado y el plan GitHub; no asumir que branch protection, required reviewers, environments o rulesets estén disponibles o sean exigibles. No modificar ajustes remotos.

## Fase 1 — Diseñar el contrato de aprobación

Definir y documentar:

- Estados inequívocos: `PASS`, `PASS_WITH_REVIEW`, `BLOCKED_CRITICAL`, `BLOCKED_TECHNICAL` y, solo si es compatible con el contrato existente, un estado diferenciado para aceptación aprobada. No introducir estados nuevos sin justificar migración y pruebas.
- `PASS_WITH_REVIEW` siempre requiere decisión humana explícita; nunca es equivalente a `PASS` ni aprobación tácita por el autor del PR.
- Datos mínimos de una aceptación: identificador de vulnerabilidad, componente/imagen, versión, severidad, justificación y análisis de exposición, medidas compensatorias, aprobador identificado, fecha de aprobación, fecha de vencimiento y referencia al PR o evidencia.
- Separación de funciones: quien propone el cambio no debe autoaprobar su propio riesgo; documentar las limitaciones si el repositorio es mantenido por una sola persona.
- Comportamiento al vencer, cambiar la versión o aparecer otro HIGH: la aceptación anterior no cubre automáticamente hallazgos nuevos ni queda indefinida.
- Evidencia auditable sin secretos ni datos sensibles.

## Fase 2 — Diseñar y aplicar solo cambios locales mínimos

1. Proponer primero la arquitectura de enforcement: checks obligatorios, revisión humana y, si es técnicamente viable, un check de decisión separado que falle o permanezca bloqueado hasta aceptación válida.
2. Evitar un check circular o imposible de aprobar. No crear un gate que solo se pueda superar editando el propio workflow o saltando las reglas.
3. No tratar un comentario libre, una etiqueta del PR o un booleano escrito por el autor como autorización suficiente. Si se usa una excepción versionada, exigir una identidad/autorización verificable y una revisión independiente, o documentar que el enforcement no es automático.
4. Conservar el fail-closed ante reportes faltantes, JSON inválido, fallos técnicos y CRITICAL.
5. No hacer downgrade de HIGH, no añadir exclusiones generales y no desactivar Trivy, npm audit ni SBOM.
6. Si no existe mecanismo confiable de aprobación verificable con las capacidades disponibles, NO simularlo: entregar diseño, limitaciones, configuración manual y dejar el PR sin merge.
7. Si se requiere tocar `.github/workflows/ci.yml` o scripts, aplicar el cambio mínimo y agregar pruebas positivas y negativas para los estados relevantes. Evitar acciones de GitHub que puedan ejecutar código no confiable con permisos elevados.

## Fase 3 — Validaciones

- YAML, sintaxis shell, lint/tests aplicables y validación del contrato de artifacts.
- Casos: cero HIGH, HIGH sin aprobación, HIGH con aprobación válida y verificable (si está implementada), aceptación expirada, aceptación de vulnerabilidad diferente, CRITICAL, reporte faltante/incorrecto.
- Demostrar que la aceptación no puede ser fabricada únicamente desde el mismo PR sin una revisión autorizada.
- Reportar explícitamente qué validaciones son locales y cuáles requieren GitHub remoto; nunca declarar `REMOTE PASS` sin ejecución real.

## Fase 4 — Documentación y salida

Crear o actualizar, según sea necesario:

- `docs/assessments/devops-03-5-security-gate-pr-governance.md`: hallazgos, opciones evaluadas, decisión, limitaciones del plan GitHub, archivos modificados, matriz de pruebas, riesgos pendientes y recomendación `MERGE BLOCKED` / `READY FOR HUMAN REVIEW` sustentada.
- `docs/agent/tasks/devops-03-5-security-gate-pr-governance.md`: este contrato si aún no existe en el repositorio.

Proporcionar instrucciones **manuales, exactas y comprobables** para proteger `main`, incluyendo checks por nombre real, número de revisiones y restricciones de bypass, pero solo para funciones verificadas como disponibles.

## Restricciones obligatorias

- No `git commit`, `git push`, `git merge`, despliegues ni cambios en AWS.
- No cambiar ajustes de GitHub, permisos, rulesets o branch protection automáticamente.
- No modificar Dockerfiles, Prisma, dependencias o datos históricos salvo incompatibilidad demostrada y autorizada.
- No inventar resultados, reportes, aprobaciones, endpoints, identidades o estados.
- No aprobar el HIGH residual de `deepmerge-ts` en nombre del usuario.
- Si hay dudas o falta acceso para una decisión de seguridad, detener la automatización de esa decisión y documentar el bloqueo.

## Formato de respuesta de Codex

En consola: resumen breve de diagnóstico, archivos cambiados, pruebas, resultado del gate y pasos manuales pendientes. El detalle completo debe quedar en el Markdown de assessment.
