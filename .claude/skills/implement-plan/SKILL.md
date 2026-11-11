---
name: implement-plan
description: Implementa un plan guardado en plans/<num_issue>-<breve-descripcion>.md en una rama propia creada desde development, aplicando TDD estricto tarea a tarea, marcando cada tarea como hecha en el plan y haciendo un commit por tarea. Úsalo cuando pidan implementar, ejecutar o desarrollar un plan.
argument-hint: <ruta o nombre del plan, p. ej. plans/12-paginacion-vendehumos.md>
---

# Implementar un plan

Implementa el plan indicado por el usuario, tarea por tarea, con TDD estricto y un commit por tarea.

Plan a implementar: $ARGUMENTS

## 1. Localizar y leer el plan

1. Resuelve el plan a partir del argumento: ruta completa, nombre de archivo o `<num_issue>`. Los planes viven en `plans/`. Si no hay argumento o hay varias coincidencias, pregunta al usuario cuál es. No adivines.
2. Lee el plan completo (Objetivo, Alcance, Archivos afectados, Tareas, Criterios de aceptación, Dudas y decisiones).
3. Si en "Dudas y decisiones" quedan preguntas abiertas que bloqueen la implementación, consúltalas con el usuario antes de empezar.
4. Lee `CLAUDE.md` y respeta sus convenciones: capas `controllers`, `services`, `repositories`, `models`, `utils`; funciones en snake_case; prettier (sin `;` innecesarios, comillas simples); eslint; tests con vitest.
5. Si todas las tareas ya están marcadas (`- [x]`), avisa al usuario y detente.

## 2. Preparar la rama

El nombre de la rama es el **nombre del plan**: el nombre del archivo sin la extensión `.md` (ej. `plans/12-paginacion-vendehumos.md` → rama `12-paginacion-vendehumos`).

1. Comprueba que el árbol de trabajo está limpio con `git status --short`. Si hay cambios sin commitear ajenos al plan, avisa al usuario y pregunta qué hacer (no los pierdas ni los mezcles en los commits del plan).
2. Comprueba si existe `development` (`git branch --list development` y `git branch -r --list origin/development`).
   - **Si no existe**, créala primero a partir de `main`: `git switch main` y `git switch -c development`. Si `main` tampoco existe, avisa al usuario y detente.
   - **Si existe**, úsala tal cual (si solo existe en remoto, crea la local con `git switch development`).
3. Crea la rama del plan a partir de `development`: `git switch development` y `git switch -c <nombre-del-plan>`.
   - Si la rama del plan ya existe, no la recrees ni la sobrescribas: pregunta al usuario si quiere continuar en ella (retomar el plan) o usar otro nombre.
4. No hagas `git push` ni cambies de rama durante la implementación salvo que el usuario lo pida.

Si el propio archivo del plan está sin commitear (p. ej. recién generado con plan-feature), llévalo a la rama del plan y haz con él el primer commit (`docs(plans): ...` con el comando `/commit`) antes de empezar con las tareas.

## 3. Implementar tarea a tarea

Recorre las tareas pendientes (`- [ ]`) **en el orden del plan**. Para cada tarea, sigue este ciclo sin saltarte ningún paso:

1. **Red — escribe primero el test.** Escribe (en vitest) el test más pequeño que describa el comportamiento de la tarea. No escribas código de producción antes. Ejecuta el test y **comprueba que falla** y que falla por la razón esperada (no por un error de sintaxis o de importación). Si pasa sin haber implementado nada, el test no sirve: corrígelo.
2. **Green — implementa lo mínimo.** Escribe solo el código necesario para que ese test pase, en la capa que corresponda. Ejecuta el test y comprueba que pasa.
3. **Refactor.** Con los tests en verde, limpia el código si hace falta, sin cambiar el comportamiento ni añadir funcionalidad.
4. **Verifica.** Ejecuta toda la suite de tests, eslint y prettier. Todo debe estar en verde y sin errores. Si algo falla, arréglalo antes de seguir.
5. **Marca la tarea como hecha** en el archivo del plan, cambiando `- [ ]` por `- [x]` solo en esa tarea y solo **después** de que el test y el código pasen.
6. **Commit.** Invoca el slash command `/commit` (con la herramienta Skill/slash command `commit`) para crear el commit de esa tarea, incluyendo el código, los tests y el plan actualizado. Un commit por tarea. Pásale como contexto el nombre de la tarea.

Reglas del ciclo:

- **TDD estricto:** nunca hay código de producción sin un test previo que haya fallado. Nada de escribir el código y el test después.
- **Tareas sin comportamiento testeable** (configuración de eslint/prettier/vitest, documentación, formato): no inventes un test artificial. Verifica la tarea con el comando que corresponda (p. ej. `npx eslint .`, `npx prettier --check .`), márcala y haz commit. Indica en el resumen final qué tareas se verificaron así.
- **No marques una tarea como hecha** si su test no existe, no pasa o rompe otros tests.
- **Un commit por tarea:** no agrupes varias tareas en un commit ni dejes tareas hechas sin commitear.
- Si una tarea es más grande de lo previsto o el plan es incorrecto/incompleto, detente y consúltalo con el usuario en lugar de improvisar. Si decides algo por tu cuenta, anótalo en "Dudas y decisiones tomadas" del plan.
- No toques código fuera del alcance del plan.
- Si un test no consigue pasar tras varios intentos razonables, detente y explica el bloqueo al usuario; no desactives ni debilites el test para que pase.

## 4. Cierre

1. Cuando todas las tareas estén marcadas, recorre los **Criterios de aceptación** del plan y verifícalos uno a uno (tests, eslint, prettier, códigos HTTP, etc.). Si alguno no se cumple, añade la tarea necesaria al plan y trátala con el mismo ciclo TDD. Y aquellos que se cumplen marcalas.
2. Muestra `git status` y `git log --oneline` de la rama para confirmar que el árbol está limpio y que hay un commit por tarea.
3. Resume al usuario: nombre de la rama, tareas completadas, resultado de tests/lint/formato, tareas verificadas sin test (si las hay) y decisiones tomadas. No hagas `git push` ni abras PR salvo que el usuario lo pida.

## 5. Avisar por Slack

Como último paso, envía un mensaje al canal de Slack `curso-claude-ed3` indicando que el plan ya se ha implementado:

1. Usa la herramienta `slack_post_message` del MCP de Slack con el ID de canal `C0CGZ01R9M2` (canal `curso-claude-ed3`). No hace falta buscar el ID con `slack_list_channels`.
2. Mensaje en español, breve, con el nombre del plan, la rama y el número de tareas completadas. Ej.: `✅ Implementado el plan 12-paginacion-vendehumos en la rama 12-paginacion-vendehumos (8 tareas completadas, tests/lint/formato en verde).`
3. Solo envíalo si todas las tareas están completadas y verificadas. Si la implementación se detuvo por un bloqueo, no lo envíes.
4. Si el canal no existe o el MCP de Slack no está disponible, no inventes alternativas: indícalo al usuario en el resumen y termina.
