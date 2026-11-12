# Auditoría OWASP Top 10 (2021) - `packages/api`

Alcance: `packages/api/src` y `package.json` (sin `node_modules` ni `dist`). Auditoría de solo lectura. Rutas relativas a `packages/api/src` salvo que se indique otra cosa. Fecha: 2026-11-12.

## Resumen ejecutivo

| Severidad | Nº | Hallazgos |
|---|---|---|
| Crítica | 3 | A01-1, A01-2, A07-1 |
| Alta | 6 | A01-3, A01-4, A01-5, A04-1, A05-1, A06-1 |
| Media | 8 | A01-6, A03-1, A04-2, A05-2, A05-3, A07-2, A07-3, A09-1 |
| Baja | 4 | A02-1, A04-3, A07-4, A08-1 |

Total: 21 hallazgos. A03 (inyección SQL) sin inyección real; A10 (SSRF) sin hallazgos de código.

Lo más grave:
1. **Secreto JWT hardcodeado por defecto** (`'super-secret-resttek-key'`) y `dotenv` nunca se importa: si no se exporta `JWT_SECRET`, cualquiera puede forjar un token de `admin`.
2. **Sin aislamiento entre restaurantes (IDOR)**: ningún endpoint compara el `restaurantId` del token con el de la ruta; un `manager` de un restaurante puede leer, editar y borrar platos e ingredientes de otro.
3. **Pedidos sin control de acceso**: cualquier usuario autenticado (incluso un `cliente` recién registrado) lee cualquier pedido, lista los pedidos activos de cualquier restaurante y cambia el estado de cualquier ítem.
4. **Contraseñas triviales** en el seed (contraseña = email, incluido `admin@resttek.com`), sin política de contraseñas ni límite de intentos.
5. **Dependencias vulnerables** (`npm audit`: 2 críticas, 7 altas en el monorepo), entre ellas `body-parser` (vía Express) y la cadena `sqlite3`/`tar`.

Positivo verificado: todas las consultas SQL usan parámetros `?`; bcrypt con coste 10; JWT con expiración de 8 h; las respuestas de empleados no devuelven `passwordHash`; `*.db` está en `.gitignore` y no hay `.env` versionado.

---

## A01:2021 - Broken Access Control

### A01-1 (Crítica) - Ausencia de aislamiento entre restaurantes en `/restaurants/:restaurantId/*`

- Archivos: `routes/dish.routes.ts:14-18`, `routes/ingredient.routes.ts:14-18`, `controllers/dish.controller.ts:47-70`, `controllers/ingredient.controller.ts:44-64`, `repositories/dish.repository.ts:61,82`, `repositories/ingredient.repository.ts:46,58`.
- `authorize` solo comprueba el rol (`contexts/shared/infrastructure/http/middlewares.ts:35`). El `restaurantId` del JWT nunca se compara con `req.params.restaurantId`, y `update`/`delete`/`getById` ignoran el `restaurantId` de la URL y usan solo `:id`.

```ts
router.put('/:id', authenticate, authorize(['admin', 'manager']), dishController.update)
// dish.controller.ts:49
const dish = await this.dishService.update(req.params.id as string, {...})
// dish.repository.ts:61
'UPDATE dishes SET name = ?, ... WHERE id = ?'
```

- Explotación: un `manager` de `rest-1` hace `DELETE /api/v1/restaurants/rest-1/dishes/<id-de-plato-de-rest-2>` y borra un plato de otro negocio, o `PUT` para cambiar precios. Con `GET /api/v1/restaurants/rest-2/dishes` o `/ingredients` un cocinero/manager de otro restaurante lista platos e inventario ajenos. Los UUID de platos se obtienen de `GET /api/v1/public/restaurants/:id/dishes` (público). Lo mismo para `PUT/DELETE` de ingredientes (admin).
- Corrección: middleware que exija `user.role === 'admin' || user.restaurantId === req.params.restaurantId`; en los servicios verificar `resource.restaurantId === req.params.restaurantId` (404 si no coincide); añadir `AND restaurant_id = ?` a UPDATE/DELETE.

### A01-2 (Crítica) - Cualquier usuario autenticado lee cualquier pedido y los pedidos activos de cualquier restaurante

- Archivos: `routes/order.routes.ts:14-18` (solo `authenticate`, sin `authorize`), `controllers/order.controller.ts:28-41, 57-68`.

```ts
router.get('/:id', authenticate, orderController.getById.bind(orderController))
const order = await this.orderService.getById(req.params.id as string)   // sin comprobar clientId ni restaurantId
const { restaurantId } = req.query                                       // restaurantId arbitrario
```

- Explotación: un `cliente` registrado vía `POST /auth/register` (público) llama a `GET /api/v1/orders/active?restaurantId=rest-1` y obtiene todos los pedidos en curso (clientId, mesa, notas, platos); con `GET /api/v1/orders/<id>` accede a pedidos de otros clientes.
- Corrección: `authorize` de personal en `/active` y exigir `user.restaurantId === restaurantId` (salvo admin); en `getById` permitir solo al `clientId` propietario o al personal del restaurante del pedido.

### A01-3 (Alta) - Cualquier usuario autenticado cambia el estado de cualquier ítem de pedido

- Archivos: `routes/order.routes.ts:18`, `controllers/order.controller.ts:70-85`, `services/order.service.ts:69-84`.

```ts
router.patch('/:orderId/items/:itemId/status', authenticate, orderController.updateItemStatus.bind(orderController))
```

- Explotación: un `cliente` marca como `entregado` los ítems de cualquier pedido (desaparecen de la cola de cocina, `order.repository.ts:179`) o los reabre. Sabotaje operativo.
- Corrección: restringir a camarero/cocinero/manager/admin del restaurante del pedido y validar transiciones de estado permitidas.

### A01-4 (Alta) - `GET /restaurants/:id` autenticado no aplica el filtro por restaurante que sí aplica `getAll`

- Archivos: `routes/restaurant.routes.ts:16`, `controllers/restaurant.controller.ts:25-32` frente a `:34-52`.
- `getAll` limita a no-admin a su `user.restaurantId`, pero `getById` solo exige `authenticate`: cualquier usuario obtiene email, teléfono y propietario de cualquier restaurante. La intención de restringir se elude. (El mismo `getById` está además montado sin autenticación en `restaurant.public.routes.ts:14`, ver A01-5.)
- Corrección: aplicar la regla admin o `user.restaurantId === id`.

### A01-5 (Alta) - Endpoints públicos exponen datos personales del propietario

- Archivos: `routes/restaurant.public.routes.ts:13-14`, `controllers/restaurant.controller.ts:54-61, 80-93`.
- Sin autenticación, `GET /api/v1/public/restaurants` y `/public/restaurants/:id` devuelven `email`, `phone`, `ownerFirstName`, `ownerLastName` con el mismo `toJSON` de la vista privada.
- Explotación: scraping masivo de datos personales de propietarios para phishing/spam.
- Corrección: DTO público con solo `id`, `name`, `address`, `logoUrl`.

### A01-6 (Media) - Relaciones entre recursos de distintos restaurantes sin validar

- Archivos: `repositories/dish.repository.ts:72-76`, `services/order.service.ts:26-37`, `contexts/employee/application/CreateEmployeeUseCase.ts:30-38`.
- Un plato acepta `ingredientId` de cualquier restaurante (solo la FK exige que exista); un pedido acepta `dishId` de un restaurante distinto al `restaurantId` del pedido; un empleado se crea con cualquier `restaurantId` sin coherencia con el rol (un `cliente` con restaurante, un `manager` sin él).
- Corrección: validar pertenencia al mismo restaurante y coherencia rol/restaurante en servicios.

---

## A02:2021 - Cryptographic Failures

### A02-1 (Baja) - Verificación JWT sin `algorithms`/`issuer`; coste bcrypt mejorable

- Archivos: `contexts/shared/infrastructure/http/middlewares.ts:25`, `contexts/employee/infrastructure/BcryptAuthService.ts:6,18`.
- `jwt.verify(token, JWT_SECRET)` no fija `algorithms: ['HS256']` ni `issuer`/`audience`. Con jsonwebtoken 9 y secreto string no hay `alg:none`, por lo que es endurecimiento. `SALT_ROUNDS = 10` es aceptable, recomendable 12. El problema real del secreto está en A07-1. TLS: no se gestiona en la app; *a verificar* en el despliegue (HTTPS/HSTS).
- Positivo: bcrypt para contraseñas; el hash nunca se serializa en las respuestas.
- Corrección: `jwt.verify(token, secret, { algorithms: ['HS256'], issuer: 'resttek' })`.

---

## A03:2021 - Injection

Sin inyección SQL verificada: todas las consultas de los repositorios (`SqliteEmployeeRepository`, dish, ingredient, restaurant, order) usan parámetros `?`; no hay concatenación de entrada de usuario en SQL ni `eval`/`exec`. No hay NoSQL.

### A03-1 (Media) - Validación de entrada insuficiente (tipos y límites)

- Archivos: `services/order.service.ts:27-37`, `models/dish.model.ts:37`, `services/dish.service.ts:103`, controladores (`req.body.*` sin esquema).
- Verificado: `item.quantity` se usa directo en `for (let i = 0; i < item.quantity; i++)` sin validar tipo ni máximo. `quantity: 1000000000` crea mil millones de ítems en memoria y filas en SQLite (DoS) por una sola petición autenticada (incluso de un `cliente`). `price`/`currentStock`/cantidades de ingrediente no se validan con `Number.isFinite`: `NaN` pasa `props.price <= 0` (es `false`) y `"abc"` también. `description`, `notes`, `name` y `logoUrl` sin límite de longitud ni esquema. `express.json()` usa el límite por defecto sin ajustar.
- Corrección: validar con Zod/Joi por ruta (tipos, `quantity` 1..50, `Number.isFinite`, longitudes máximas, `logoUrl` solo `https:`) y `express.json({ limit: '100kb' })`.

---

## A04:2021 - Insecure Design

### A04-1 (Alta) - El pedido no valida reglas de negocio ni fija el precio

- Archivos: `services/order.service.ts:21-51`, `repositories/order.repository.ts:129-141, 228-246`, `config/database.ts:157-166`.
- `order_items` no guarda precio; el importe se lee del precio actual del plato por JOIN, así que cambiar un precio altera pedidos históricos. Al crear un pedido no se comprueba que el plato esté `available`, ni que sea del restaurante del pedido, ni que `items` no esté vacío o sea un array (un cuerpo sin `items` produce `TypeError` devuelto con su mensaje, ver A05-3).
- Corrección: validar plato disponible del mismo restaurante y copiar `unit_price` a `order_items` al crear.

### A04-2 (Media) - Registro y pedidos sin límite de tasa ni anti-automatización

- Archivos: `app.ts:16-27`, `contexts/employee/infrastructure/http/auth.routes.ts:6-7`.
- No hay `express-rate-limit` ni CAPTCHA. Un script crea miles de cuentas y pedidos falsos (ruido en cocina, crecimiento ilimitado de la BD).
- Corrección: rate limiting global y estricto en `/auth/*` y `POST /orders`; tope de pedidos activos por cliente.

### A04-3 (Baja) - Clientes y empleados comparten tabla y contexto

- `RegisterClientUseCase.ts:46` crea clientes en `employees` con `restaurantId` nulo; el rol es el único separador, así que un fallo de autorización (como A01) expone ambos tipos de cuenta. Considerar separar tablas/contextos.

---

## A05:2021 - Security Misconfiguration

### A05-1 (Alta) - CORS abierto a cualquier origen y sin cabeceras de seguridad

- Archivo: `app.ts:16`.

```ts
app.use(cors())
```

- `cors()` por defecto responde `Access-Control-Allow-Origin: *`. Al usar `Authorization` (sin cookies) no hay CSRF clásico, pero cualquier web puede invocar la API desde el navegador de un usuario si obtiene su token (p. ej. por XSS en otro sitio, o con el secreto de A07-1). No hay `helmet` (sin `X-Content-Type-Options`, HSTS, etc.) y se envía `X-Powered-By: Express`.
- Corrección: `cors({ origin: [orígenes de las 3 apps] })`, `app.disable('x-powered-by')`, `helmet()`.

### A05-2 (Media) - `dotenv` declarado pero no usado; configuración y secreto duplicados

- Archivos: `middlewares.ts:4`, `BcryptAuthService.ts:5`, `package.json`, `server.ts`.
- `dotenv` está en dependencias pero ningún fichero de `src` lo importa (verificado con grep), así que un `.env` no se carga y `JWT_SECRET` cae al valor por defecto salvo que se exporte en el entorno. No existe `.env.example`. El secreto se lee en dos módulos distintos. La BD (`resttek.db`) se crea en el directorio del proyecto sin permisos restrictivos.
- Corrección: un único módulo de configuración con `import 'dotenv/config'` (o `--env-file`), y fallar al arrancar si falta `JWT_SECRET`.

### A05-3 (Media) - Manejo de errores inconsistente y filtrado de detalles internos

- Archivos: `controllers/order.controller.ts:19-25, 61-67, 78-84`, `contexts/shared/infrastructure/http/errorHandler.ts:4-33`.
- `createOrder` devuelve `error.message` con 400 para cualquier excepción, incluidos errores internos como `SQLITE_CONSTRAINT: FOREIGN KEY constraint failed` o `TypeError: items is not iterable`, revelando estructura interna. `updateItemStatus` responde 400 para `OrderNotFoundError` (debería ser 404). El `errorHandler` decide el código por listas de nombres (frágil) y todo `AppError` no listado es 400. Los controladores de pedidos no usan `next(error)`, por lo que el `errorHandler` central se elude.
- Corrección: no reenviar `error.message` de errores no controlados; unificar con `next(error)` y el handler central.

---

## A06:2021 - Vulnerable and Outdated Components

### A06-1 (Alta) - `npm audit --omit=dev`: 2 críticas, 7 altas, 1 moderada, 2 bajas (monorepo)

- Archivos: `packages/api/package.json`, `package-lock.json` (raíz).
- Relevantes para la API (verificado con `npm audit`):
  - `body-parser` 2.0.0-2.3.0 (alta; dependencia de `express@5.2.1`): DoS por `limit` inválido y por bytes sobrantes tras cuerpo comprimido.
  - `qs` (moderada; vía express): DoS remoto.
  - `proxy-addr` (crítica): suplantación de IP; solo explotable con `trust proxy`, que hoy no se configura (*a verificar* si se despliega tras proxy).
  - `sqlite3` 5.0.0-5.1.7 (alta, dependencia directa) por `node-gyp`/`tar`/`make-fetch-happen` (`tar` crítica: escritura arbitraria de ficheros). Riesgo de cadena de suministro en la instalación, no en ejecución. `npm audit fix --force` propone `sqlite3@6.0.1` (cambio ruptural).
  - Versiones instaladas: express 5.2.1, jsonwebtoken 9.0.3, bcrypt 6.0.0, cors 2.8.6, sqlite3 5.1.7.
- Las vulnerabilidades de `@angular/*` pertenecen a los frontends, fuera de alcance.
- Corrección: `npm audit fix`, subir Express a una versión con `body-parser`/`qs` parcheados, evaluar `sqlite3@6` o `better-sqlite3`, y añadir `npm audit` a CI/Dependabot.

---

## A07:2021 - Identification and Authentication Failures

### A07-1 (Crítica) - Secreto JWT hardcodeado con valor por defecto

- Archivos: `contexts/shared/infrastructure/http/middlewares.ts:4`, `contexts/employee/infrastructure/BcryptAuthService.ts:5`.

```ts
const JWT_SECRET: string = process.env.JWT_SECRET || 'super-secret-resttek-key'
```

- Explotación: el valor está en el código fuente. Si en un despliegue no se define `JWT_SECRET` (y dotenv no se carga, ver A05-2), un atacante ejecuta `jwt.sign({ id: 'x', role: 'admin', restaurantId: null }, 'super-secret-resttek-key')` y obtiene acceso total de administrador a todos los endpoints (A01 deja de ser relevante).
- Corrección: eliminar el valor por defecto, exigir un `JWT_SECRET` aleatorio de >= 32 bytes y abortar el arranque si falta; rotar el secreto.

### A07-2 (Media) - Sin política de contraseñas, contraseñas de seed débiles y sin protección contra fuerza bruta

- Archivos: `scripts/seed.ts:22,51`, `RegisterClientUseCase.ts:38`, `CreateEmployeeUseCase.ts:28`, `auth.routes.ts:6`.
- La contraseña de cada usuario del seed es su email (`hashPassword('admin@resttek.com')`), incluido el `admin` (también documentado en CLAUDE.md). No hay longitud mínima ni complejidad (se acepta `""` o `"1"`; `undefined` provoca excepción de bcrypt y 500). No hay rate limiting ni bloqueo tras fallos en `/auth/login`.
- Explotación: probar `admin@resttek.com`/`admin@resttek.com` en cualquier instancia donde se ejecutó el seed; fuerza bruta ilimitada sobre cualquier cuenta.
- Corrección: política mínima (>= 12 caracteres), contraseñas aleatorias en el seed o cambio forzado, rate limit y bloqueo progresivo; no ejecutar el seed en producción.

### A07-3 (Media) - Enumeración de usuarios y emails sin normalizar

- Archivos: `RegisterClientUseCase.ts:33-36`, `LoginUseCase.ts:29-38`, `contexts/shared/domain/value-objects/Email.ts:10-14`.
- `POST /auth/register` responde `DuplicatedEmailError` si el email existe. En login, si el usuario no existe se responde sin ejecutar bcrypt, por lo que la diferencia de tiempo delata emails registrados. `Email` no hace trim ni lowercase: `A@x.com` y `a@x.com` son cuentas distintas y el login distingue mayúsculas.
- Corrección: normalizar email, comparar contra un hash ficticio si el usuario no existe y dar respuesta genérica en registro.

### A07-4 (Baja) - JWT de 8 h con rol embebido y sin revocación

- Archivos: `BcryptAuthService.ts:18`, `middlewares.ts:25-26`.
- Rol y `restaurantId` viajan en el token y no se revalidan en BD: un empleado despedido o degradado conserva privilegios hasta 8 h; no hay logout ni refresh. `req.user` es `any`.
- Corrección: expiración corta + refresh, o comprobar el usuario en BD en operaciones sensibles.

---

## A08:2021 - Software and Data Integrity Failures

### A08-1 (Baja) - Integridad de datos delegada solo a la aplicación

- Archivo: `config/database.ts:89-172`.
- Sin deserialización insegura (solo el parseo JSON de Express). El esquema no tiene `CHECK` sobre `role`, `status`, `quantity > 0` ni `price > 0`, y las migraciones son `CREATE TABLE IF NOT EXISTS` sin versionado: un fallo de validación en la app permite datos inválidos persistentes. `package-lock.json` existe (positivo); no se revisó CI/CD (*a verificar*).
- Corrección: añadir `CHECK` en el esquema, migraciones versionadas y `npm ci` en CI.

---

## A09:2021 - Security Logging and Monitoring Failures

### A09-1 (Media) - Sin registro de eventos de seguridad ni de errores

- Archivos: `contexts/shared/infrastructure/http/errorHandler.ts:32`, `controllers/order.controller.ts:38-40, 52-54`, `app.ts`.
- No hay logger de peticiones (morgan/pino) ni auditoría de logins fallidos, registros, creación de empleados, cambios de estado ni 401/403. El `errorHandler` devuelve 500 genérico sin registrar la excepción, y los `catch (error)` de `order.controller.ts` descartan el error.
- Explotación: un ataque de fuerza bruta (A07-2) o accesos no autorizados (A01) no dejan rastro ni permiten alertas; los fallos reales son indiagnosticables.
- Corrección: logging estructurado (pino) con id de petición, eventos de auth y accesos denegados, y registrar el error en el handler 500, sin volcar contraseñas ni tokens.

---

## A10:2021 - Server-Side Request Forgery (SSRF)

Sin hallazgos verificados: el código de la API no realiza peticiones salientes (no hay `fetch`, `axios`, `http.request` ni descargas de URLs en `src`). Nota informativa: `logoUrl` (`controllers/restaurant.controller.ts:17,72`, `services/restaurant.service.ts`) se guarda sin validar esquema ni host y solo se devuelve al cliente. Si el servidor llegara a descargar o procesar ese logo habría que permitir solo `https:` y bloquear IPs privadas. Un `logoUrl` con `javascript:`/`data:` podría ser riesgo de XSS en los frontends (*a verificar*, fuera de alcance).
