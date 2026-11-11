---
name: update-openapi-docs
description: Mantiene sincronizada la documentación de la API (docs/api/openapi.yml) con el código y regenera el HTML con Redocly. Úsalo siempre que cambie algo de la API (rutas, parámetros, validaciones, categorías, formato de respuestas o códigos HTTP) o cuando pidan actualizar, validar o generar la documentación OpenAPI.
---

# Actualizar la documentación OpenAPI

La fuente de verdad de la documentación es `docs/api/openapi.yml` (OpenAPI 3.1, en español). El HTML `docs/api/index.html` se genera a partir de él con Redocly y no se edita a mano.

## 1. Detectar qué ha cambiado en la API

1. Mira los cambios con `git status` y `git diff` (o `git diff <rama_base>...HEAD`) en `src/`.
2. Revisa los archivos que definen el contrato de la API:
   - `src/app.js`: rutas y métodos, 404 y manejo de errores.
   - `src/controllers/`: parámetros de query/body, códigos HTTP y forma de la respuesta.
   - `src/services/`: validaciones y sus mensajes.
   - `src/models/`: campos devueltos (la API devuelve camelCase: `fotoUrl`, `numVotos`) y `categorias.js` (lista de categorías permitidas).
   - `src/utils/paginacion.js`: valores por defecto y límites de `page` y `limit`, y los enlaces de la respuesta paginada.
3. Si no hay cambios que afecten al contrato (solo refactor interno, tests...), dilo y no toques el `openapi.yml`; aun así puedes regenerar el HTML si se pide.

## 2. Actualizar `docs/api/openapi.yml`

- Cada endpoint nuevo o modificado va en `paths`, con `tags`, `summary`, `operationId` en snake_case, parámetros, `requestBody` y todas sus respuestas (200/201, 400, 500...).
- Reutiliza `components/schemas`, `components/parameters` y `components/responses` en lugar de duplicar. Elimina los componentes que dejen de usarse (el lint avisa).
- Si cambia `CATEGORIAS`, actualiza el enum `Categoria`. Si cambian las reglas de validación, actualiza `required`, `minLength`, `pattern`, límites, etc.
- Si desaparece un endpoint, quítalo del documento.
- Descripciones en español, formato prettier (comillas simples, 2 espacios).

## 3. Validar y generar el HTML

Ejecuta el script de esta skill desde cualquier directorio:

```bash
bash .claude/skills/update-openapi-docs/scripts/generar_docs.sh
```

Equivale a `npm run docs:build`. El script valida el `openapi.yml` con `redocly lint` y, solo si es válido, genera `docs/api/index.html` con `redocly build-docs`. Acepta opcionalmente la ruta del spec y del HTML de salida como argumentos.

- Si el lint falla, corrige el `openapi.yml` y vuelve a ejecutarlo. No desactives reglas en `redocly.yaml` para esquivar un error real.
- Si faltan dependencias, ejecuta `npm install` (Redocly es una devDependency, `@redocly/cli`).

## 4. Comprobar y resumir

1. Ejecuta `npx prettier --check docs/api/openapi.yml`.
2. Verifica que el `openapi.yml` coincide con el comportamiento real (códigos HTTP, nombres de campos, categorías, límites).
3. Resume al usuario qué se ha cambiado en la documentación y confirma que `docs/api/openapi.yml` y `docs/api/index.html` están actualizados y versionables.
