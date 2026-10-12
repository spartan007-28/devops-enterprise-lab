# Terraform / IaC (fase futura)
- Antes de crear recursos: autorización explícita, estimación de costos, plan revisado, tags, región y mecanismo de destrucción.
- Preferir `fmt`, `validate`, lint, escaneo IaC y `plan` offline cuando sea viable.
- No ejecutar `terraform apply`, `destroy`, cambios de state, credenciales ni operaciones AWS sin autorización.
- No almacenar secretos ni state sensible en Git.
