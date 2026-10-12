# CI/CD
- Preservar jobs Quality gates, Dependency audit, Container build and security, Compose validation y CI summary, salvo cambio justificado.
- Los jobs son aislados; compartir evidencia mediante artifacts con nombres/rutas verificados.
- Mantener `needs` correctos, fallos técnicos bloqueantes y reportes obligatorios.
- No inferir resultado remoto a partir de pruebas locales. Documentar run, SHA, plataforma y artifacts cuando estén disponibles.
- Distinguir éxito técnico del workflow y aprobación humana de riesgo.
