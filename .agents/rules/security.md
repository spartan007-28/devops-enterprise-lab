# Seguridad
- Fail-closed cuando falten reportes obligatorios o fallen escáneres.
- Distinguir npm audit (árbol de dependencias) de Trivy (imágenes finales).
- CRITICAL/HIGH: evaluar exposición, remediación y política vigente; no afirmar equivalencia entre 0 HIGH de imágenes y seguridad total.
- `PASS_WITH_REVIEW` no equivale a aceptación de riesgo. Una aceptación requiere hallazgo concreto, responsable independiente, justificación y expiración, conforme a la gobernanza del repositorio.
- No ignorar CVE, añadir excepciones ni bajar umbrales sin autorización y evidencia.
- No imprimir secretos ni subir archivos `.env` reales, tfvars con credenciales o tokens.
