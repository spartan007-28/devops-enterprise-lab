# Git y Pull Requests
- Trabajar en rama de feature; `main` protegida mediante ruleset.
- No commits, push, merge, rebase destructivo ni cambios remotos sin autorización.
- Antes de recomendar staging/commit: `git status --short`, `git diff --check`, `git diff --cached --check`, inspección de diff y escaneo de secretos si está disponible.
- No crear aprobaciones ficticias ni usar bypass de reglas.
- Revisión independiente requerida según configuración efectiva del repositorio.
