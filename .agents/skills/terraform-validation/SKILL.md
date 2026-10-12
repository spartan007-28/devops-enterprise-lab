---
name: terraform-validation
description: Revisar IaC Terraform sin aplicar cambios ni crear costos AWS.
---
# Terraform validation
1. Leer `AGENTS.md` y `.agents/rules/terraform.md`.
2. Inspeccionar módulos y providers realmente existentes; no asumir infraestructura desplegada.
3. Ejecutar sólo validaciones locales autorizadas y no destructivas.
4. Reportar riesgos de costo, permisos, secretos y drift; solicitar autorización para operaciones remotas.
