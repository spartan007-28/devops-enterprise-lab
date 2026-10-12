# DEVOPS-03.5 — Security Gate & PR Governance Assessment

Fecha: 2026-10-09<br>
Proyecto: `devops-enterprise-lab`<br>
Decisión: **MERGE BLOCKED — READY FOR HUMAN REVIEW**

## Diagnóstico real

El contrato indicaba un repositorio privado, pero la consulta de solo lectura confirmó que el repositorio actual es público, con rama por defecto `main` y permisos administrativos disponibles para la identidad usada. No se modificó ninguna configuración remota.

Estado local:

- Rama: `chore/devops-03-first-ci`.
- Remoto: `origin` configurado hacia `spartan007-28/devops-enterprise-lab`.
- PR #1: abierto, base `main`, head `chore/devops-03-first-ci`.
- No hay cambios de código locales pendientes; sólo permanece sin seguimiento el contrato DEVOPS-03.5 y este assessment durante esta ejecución.

Estado remoto observado:

- Run `37981925051`: los cinco checks reportaron `SUCCESS`.
- `Quality gates`, `Dependency audit`, `Container build and security`, `Compose validation` y `CI summary`: SUCCESS.
- El job de seguridad descargó `npm-audit-reports`, verificó los tres reportes obligatorios y terminó con `security policy decision=PASS_WITH_REVIEW`.
- El log remoto confirma `HUMAN APPROVAL REQUIRED` en el Summary cuando hay HIGH.
- PR #1 no tiene reviews (`reviews=[]`) ni `reviewDecision`.
- `mergeStateStatus` observado: `CLEAN`.

## Estado de protección de `main`

Las consultas read-only devolvieron:

- Branch protection: `404 Branch not protected`.
- Rulesets: lista vacía `[]`.
- No se verificaron revisiones requeridas, checks requeridos ni restricciones de bypass porque no hay protección/ruleset configurado.

Conclusión: CI verde no impide el merge. El PR podría integrarse sin una aprobación humana aunque el resultado de seguridad sea `PASS_WITH_REVIEW`. Por contrato, el merge queda bloqueado manualmente.

## Política y HIGH residual

El reporte real de política contiene:

```json
{
  "decision": "PASS_WITH_REVIEW",
  "highCount": 1,
  "humanApprovalRequired": true,
  "critical": 0
}
```

El único HIGH de imagen pendiente es:

| Contexto | Vulnerabilidad | Paquete | Versión | Corrección reportada |
|---|---|---|---|---|
| `migrations-tooling` | `CVE-2026-40345` | `deepmerge-ts` | `7.1.5` | `8.0.0` |

Hechos confirmados:

- El paquete aparece en la imagen de migraciones.
- La imagen de migraciones contiene Prisma CLI 6.19.3 y se usa para `prisma migrate deploy`.
- La corrección reportada requiere major 8; no se aplicó porque no está demostrada la compatibilidad con el contrato Prisma 6.
- Trivy no reporta CRITICAL en las imágenes remediadas.

No se afirma que el HIGH sea explotable ni inocuo. Tampoco se acepta, exceptúa o degrada en nombre del usuario. La aprobación requiere una decisión humana trazable.

## Flujo de artifacts y fail-closed

El flujo vigente es:

1. `audit-dependencies` genera `reports/ci/npm-audit-full.json`, `npm-audit-production.json` y `npm-audit-status.json`.
2. Sube `npm-audit-reports` con `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02`.
3. `container-security` depende de `audit-dependencies`.
4. Descarga el artifact con `actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093`.
5. Ejecuta `test -s` sobre los tres JSON.
6. Sólo después ejecuta `evaluate-policy.sh`.

Un artifact ausente, un archivo vacío, JSON inválido, fallo técnico de Trivy/npm o CRITICAL mantiene el pipeline bloqueado. No se generan reportes vacíos.

## Mecanismo de aprobación

No existe actualmente un mecanismo confiable de aprobación humana asociado al HIGH:

- El workflow sólo expresa `PASS_WITH_REVIEW` y `HUMAN APPROVAL REQUIRED`.
- Un comentario libre, label, output o booleano escrito desde el mismo PR no sería identidad ni aprobación verificable.
- No hay branch protection ni ruleset que exija review.
- No hay CODEOWNERS/security team verificado.
- No hay environment protegido configurado para este gate.

Por estas limitaciones no se implementó una falsa excepción versionada ni un check que simule aprobación. El PR queda `MERGE BLOCKED` hasta que un administrador configure y ejecute el mecanismo de revisión independiente.

## Contrato de aceptación propuesto

Una aceptación específica debe registrar, sin secretos:

- ID exacto: `CVE-2026-40345`.
- Componente/artefacto: `deepmerge-ts 7.1.5`, imagen `taskflow/migrate`, Prisma CLI 6.19.3.
- Severidad: HIGH.
- Justificación y análisis de exposición.
- Medidas compensatorias.
- Identidad del aprobador.
- Fecha de aprobación y vencimiento.
- Referencia al PR #1 y al reporte Trivy/SBOM.

La persona que propone el cambio no debe aprobar su propio riesgo. La aceptación vence si cambia la versión, la imagen, el uso de migraciones o aparece un hallazgo diferente. Si no existe separación de funciones por ser un repositorio de una sola persona, el bloqueo debe permanecer.

## Cambios locales aplicados

No se modificaron `.github/workflows/ci.yml`, scripts, Dockerfiles, dependencias, Prisma, datos ni configuración remota en DEVOPS-03.5. El workflow ya tenía el mecanismo correcto de transferencia, fail-closed y visibilidad de `HUMAN APPROVAL REQUIRED`; el problema restante es gobernanza remota, no un defecto local que deba simular una aprobación.

Archivo creado:

- `docs/assessments/devops-03-5-security-gate-pr-governance.md`

## Validaciones

| Caso | Resultado |
|---|---|
| YAML workflow | PASS previamente validado |
| Sintaxis shell | PASS previamente validado |
| Artifact npm descargado en Run #2 | PASS remoto; artifact `npm-audit-reports` observado en logs |
| Reportes npm obligatorios | PASS remoto; tres `test -s` pasaron |
| Política sin CRITICAL y con HIGH | PASS_WITH_REVIEW remoto; `humanApprovalRequired=true` |
| Fallo técnico/reporte faltante | PASS fail-closed validado localmente con reporte ausente |
| CRITICAL | La lógica mantiene salida bloqueante; no se fabricó un reporte para simular este caso |
| HIGH con aceptación válida | NOT RUN; no existe aprobación verificable configurada |
| Aceptación expirada o de otro CVE | NOT RUN; no existe mecanismo de aceptación implementado |
| Protección de `main` | NOT VERIFIED as configured; API confirmó branch no protegida |

No se declara `REMOTE PASS` de gobernanza. El CI remoto fue exitoso, pero la gobernanza del merge está incompleta.

## Pasos manuales exactos pendientes

Un administrador debe realizar estas acciones en GitHub, sin aceptar el HIGH automáticamente:

1. Abrir `Settings → Branches` del repositorio `spartan007-28/devops-enterprise-lab`.
2. Crear una regla de protección para `main`.
3. Activar `Require a pull request before merging`.
4. Exigir al menos **1 aprobación de una persona distinta del autor**; para riesgo HIGH se recomienda **2 aprobaciones**, incluyendo una persona con responsabilidad de seguridad.
5. Activar dismissal de approvals obsoletas y exigir aprobación del último push cuando la configuración lo permita.
6. Activar `Require status checks to pass before merging` y seleccionar los nombres reales observados:
   - `Quality gates`;
   - `Dependency audit`;
   - `Container build and security`;
   - `Compose validation`;
   - `CI summary`.
7. Restringir bypass y activar `Do not allow bypassing the above settings` si está disponible en la interfaz/plan.
8. Registrar la aceptación del HIGH en un registro aprobado, referenciando PR #1, `CVE-2026-40345`, imagen, versión, justificación, aprobador y vencimiento.
9. No mergear PR #1 hasta que la revisión independiente exista y el registro sea verificable.
10. Verificar después con lectura:

```bash
gh api repos/spartan007-28/devops-enterprise-lab/branches/main/protection
gh api repos/spartan007-28/devops-enterprise-lab/rulesets
gh pr view 1 --repo spartan007-28/devops-enterprise-lab --json reviews,reviewDecision,statusCheckRollup,mergeStateStatus
```

No se ejecutaron estos cambios remotos.

## Recomendación final

**MERGE BLOCKED / READY FOR HUMAN REVIEW.** El pipeline valida los artefactos y conserva los gates técnicos, pero GitHub actualmente no exige una aprobación independiente. Configurar branch protection/ruleset y obtener la aceptación humana específica del HIGH o remediar `deepmerge-ts` en una tarea compatible con Prisma 6.
