---
description: Crea un commit siguiendo la especificación de Conventional Commits
argument-hint: [contexto opcional sobre el cambio]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

# Commit con Conventional Commits

Crea un commit de los cambios actuales siguiendo la especificación [Conventional Commits 1.0.0](https://www.conventionalcommits.org/es/v1.0.0/).

Contexto adicional del usuario (opcional): $ARGUMENTS

## Contexto

- Estado: `git status --short`
- Cambios en staging: `git diff --cached`
- Cambios sin stage: `git diff`
- Últimos commits (para seguir el estilo): `git log --oneline -10`

## Formato

```
<tipo>[ámbito opcional][!]: <descripción>

[cuerpo opcional]

[pie(s) opcional(es)]
```

### Tipos permitidos

- `feat`: nueva funcionalidad (SemVer MINOR)
- `fix`: corrección de un bug (SemVer PATCH)
- `docs`: cambios solo en documentación
- `style`: formato que no afecta al significado del código (espacios, comillas, punto y coma)
- `refactor`: cambio de código que no corrige un bug ni añade funcionalidad
- `perf`: mejora de rendimiento
- `test`: añadir o corregir tests
- `build`: cambios en el sistema de build o dependencias
- `ci`: cambios en la configuración de CI
- `chore`: tareas de mantenimiento que no tocan `src` ni tests
- `revert`: revierte un commit anterior

### Reglas

1. La descripción va en minúsculas, en imperativo, sin punto final y con un máximo de ~72 caracteres en la primera línea.
2. El ámbito es un sustantivo entre paréntesis que indica la zona afectada, por ejemplo `feat(controllers):` o `fix(repositories):`. Usa las capas del proyecto (`controllers`, `services`, `repositories`, `models`, `utils`) cuando aplique.
3. El cuerpo explica el *qué* y el *por qué*, no el *cómo*. Se separa de la descripción con una línea en blanco.
4. Los cambios incompatibles (breaking changes) se marcan con `!` tras el tipo/ámbito y/o con un pie `BREAKING CHANGE: <descripción>`.
5. Los pies usan el formato `Token: valor` (por ejemplo `Refs: #123`).
6. Escribe el mensaje en español, salvo que el historial del repositorio use otro idioma.

## Pasos

1. Si no es un repositorio git, avisa al usuario y detente.
2. Revisa el estado y los diffs de arriba. Si no hay cambios, díselo al usuario y detente.
3. Si hay cambios en staging, commitea solo eso. Si no hay nada en staging, añade con `git add` los archivos relevantes (por nombre, nunca con `git add -A` ni `.`) y no incluyas archivos sensibles (`.env`, credenciales) ni la base de datos `data.db`.
4. Si los cambios mezclan propósitos distintos, propón dividirlos en varios commits y haz uno por cada tipo de cambio.
5. Elige el tipo y el ámbito que mejor describan el cambio y redacta el mensaje según las reglas.
6. Crea el commit con `git commit` (usa un HEREDOC para mensajes de varias líneas). No uses `--no-verify` ni `--amend`.
7. Muestra el mensaje del commit resultante y el resultado de `git status`.

No hagas `git push` salvo que el usuario lo pida explícitamente.
