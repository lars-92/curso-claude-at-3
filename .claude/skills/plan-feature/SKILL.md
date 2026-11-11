---
name: plan-feature
description: Planifica una nueva funcionalidad o el arreglo de un error usando una plantilla común y guarda el plan en plans/<num_issue>-<breve-descripcion>.md. Úsalo cuando pidan planificar, diseñar o preparar el trabajo de una feature, issue o bug antes de implementarlo.
argument-hint: <num_issue> <descripción de la funcionalidad o del error>
---

# Plan de feature / bugfix

Genera un plan de implementación siguiendo siempre la plantilla [template.md](template.md), para que todos los planes tengan el mismo formato.

Petición del usuario: $ARGUMENTS

## Pasos

1. **Identifica el número de issue y la descripción.** Si falta el número de issue, pregúntalo al usuario (es necesario para el nombre del archivo). No lo inventes.
2. **Investiga el código antes de planificar.** Lee `CLAUDE.md` y los archivos relevantes de `src/` para saber qué se toca de verdad. Si la tarea es paginar endpoints GET, lee `docs/api/api-pagination.md`. Respeta las convenciones del proyecto:
   - Arquitectura por capas: `controllers`, `services`, `repositories`, `models`, `utils`.
   - Funciones en snake_case.
   - Prettier (sin `;` innecesarios, comillas simples), eslint y tests con vitest.
3. **Rellena la plantilla** [template.md](template.md) sin quitar ni reordenar secciones:
   - **Objetivo**: qué se quiere conseguir y por qué, en 1-3 frases.
   - **Alcance**: qué entra y qué queda explícitamente fuera.
   - **Archivos afectados**: rutas reales (existentes o nuevas) y qué cambia en cada una.
   - **Tareas**: lista de checkboxes ordenada; cada tarea debe poder hacerse en **5-10 minutos**. Si una es más grande, divídela. Incluye las tareas de tests, lint y formato.
   - **Criterios de aceptación**: condiciones verificables (comportamiento, códigos HTTP, tests en verde, lint sin errores) que deben cumplirse para dar la tarea por hecha.
   - **Dudas y decisiones tomadas**: al final del plan. Lista las preguntas abiertas y toda decisión que hayas tomado por tu cuenta, con su motivo. Si no hay ninguna, escribe "Ninguna".
4. **Guarda el plan** en `plans/<num_issue>-<breve-descripcion>.md` (crea la carpeta `plans` si no existe):
   - `<breve-descripcion>` en kebab-case, minúsculas, sin tildes ni caracteres especiales, 2-5 palabras (ej. `plans/12-paginacion-vendehumos.md`).
   - Si el archivo ya existe, no lo sobrescribas sin avisar: pregunta al usuario.
5. **Resume al usuario** la ruta del archivo creado y las dudas/decisiones abiertas para que las valide.
6. **Avisa por Slack.** Como último paso, envía un mensaje al canal de Slack `curso-claude-ed3` indicando que ya se ha planificado la tarea:
   - Usa las herramientas del MCP de Slack: obtén el ID del canal con `slack_list_channels` (busca el nombre `curso-claude-ed3`) y publica con `slack_post_message`.
   - Mensaje en español, breve, con el número de issue, la descripción y la ruta del plan. Ej.: `📝 Planificada la tarea #12 (paginación de vendehumos). Plan: plans/12-paginacion-vendehumos.md`.
   - Si el canal no existe o el MCP de Slack no está disponible, no inventes alternativas: indícalo al usuario en el resumen y termina.

## Reglas

- Escribe el plan en español.
- No implementes el código: este skill solo planifica.
- Sé concreto: nada de tareas vagas como "implementar la funcionalidad".
- Si el plan es un arreglo de error, indica en el Objetivo cómo se reproduce el fallo y añade un criterio de aceptación que lo cubra con un test.
