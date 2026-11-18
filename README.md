# Obra · React + TypeScript + Supabase

Proyecto estructurado para VS Code y Vercel. React 19, TypeScript, Vite, Lucide y CSS responsivo. Esta entrega sustituye el acceso libre por autenticación real. La vista del panel anterior sigue siendo una demo local independiente; el código conectado está en este ZIP.

## Inicio rápido
Requiere Node.js 22.12 o superior.

```bash
npm install
cp .env.example .env.local
npm run dev
```
En Windows copiá `.env.example` desde VS Code y renombralo `.env.local`.

```env
VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_TU_CLAVE
```
Reiniciá Vite después de editar las variables. NUNCA pongas Secret key o service_role en una variable VITE_: el bundle es público.

## Crear la base: obligatorio una sola vez
Cambiar variables NO crea tablas. No tengo acceso a tu cuenta y no ejecuté SQL allí.
1. Creá un proyecto NUEVO en Supabase.
2. Abrí SQL Editor.
3. Copiá TODO `supabase/install.sql` y ejecutalo UNA VEZ.
4. Se crean 25 tablas de aplicación, índices, relaciones, RLS, funciones transaccionales, triggers de perfiles/auditoría y bucket privado obra-files.

No ejecutar en una base con tablas del mismo nombre sin respaldo y revisión. El archivo es transaccional: si falla la instalación se revierte.

## Tablas incluidas
- Identidad/equipos: profiles, studios, studio_members, projects, project_members.
- Seguimiento: tasks.
- Pedidos: orders, order_items, order_receipts, order_receipt_items.
- Administración: workers, cash_movements, attendance, extras, daily_logs, meetings, meeting_actions.
- Servicios: freights, dumpsters, insurance_policies.
- Recursos: ppe_deliveries, inventory_items, inventory_movements.
- Documentos/control: attachments, audit_events.
`auth.users` y las tablas Storage son administradas por Supabase.

## Auth y URLs
En Authentication habilitá Email y registro. Recomendado: confirmación de correo activa y SMTP propio para producción (el servicio de prueba tiene límites).
En Authentication → URL Configuration:
- Site URL: tu dominio definitivo, por ejemplo https://tu-app.vercel.app.
- Redirect URLs: http://localhost:5173/, http://localhost:5173/?recovery=1, https://tu-app.vercel.app/ y https://tu-app.vercel.app/?recovery=1.
No autorices comodines amplios de dominios ajenos.

## Primer administrador y equipo
1. Registrate con tu correo real y confirmalo.
2. Entrá y elegí Crear mi estudio. Esto crea un estudio INDEPENDIENTE y te hace administrador solo de ese estudio.
3. En Equipo y obras, creá la primera obra.
4. Cada colaborador se registra y confirma su correo. Si no tiene permisos, verá una pantalla de espera.
5. Elegí la obra activa y asigná su correo registrado en Equipo y obras.
6. Jefe de Obra solo ve obras asignadas; Administrador ve todas las obras de su estudio.
7. El colaborador pulsa Actualizar accesos o vuelve a entrar.

El formulario de equipo asigna accesos a cuentas existentes, NO envía invitaciones. El registro no permite elegir rol ni da acceso automático a obras ajenas. La aplicación no usa Admin API ni una clave secreta.

## Vercel
Subí la carpeta a Git e importá el repositorio en Vercel. Framework Vite; comando npm run build; carpeta de salida dist. Configurá VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY para Production y Preview si corresponde. Después de cambiar variables, redesplegá: VITE_ se incorpora al bundle durante el build. vercel.json incluye fallback SPA.

```bash
npm run build
npm run preview
```
No se ejecutó compilación ni SQL durante la generación. Verificá el build y los permisos con cuentas de prueba antes de producción. Conservá el package-lock.json que genere npm install para despliegues reproducibles.

## Funcionalidades implementadas
- Login real, registro, recuperación de contraseña y sesión individual con Supabase Auth.
- Selector de estudio y obra, administración de equipo y creación de obras.
- Kanban con cuatro estados, drag & drop escritorio, edición de estado desde móvil, CRUD de tareas, responsable, rubro, prioridad, etiquetas, fechas, filtros, vista lista paginada y CSV.
- Pedidos: materiales dinámicos, borradores, solicitar un borrador guardado, aprobación/rechazo restringidos en SQL al administrador, marcar envío, recepción parcial/total con bloqueo transaccional e histórico de recepciones.
- Adjuntos privados PDF/JPG/PNG/WEBP, máximo 10 MB por archivo y enlaces firmados de 60 segundos.
- Dashboard con presupuesto asignado, tareas, pedidos y saldo de caja desde la base real.
- Calculadora geométrica de hormigón: resultado se copia manualmente a un pedido.
- Navegación completa del diseño original.

## Alcance pendiente (no confundir tablas con pantallas)
Las tablas de Caja Chica, Jornales, Adicionales, Manifiesto, Minutas, Fletes, Volquetes, Seguros, EPP e Inventario tienen RLS, pero sus interfaces CRUD todavía NO están implementadas.
Tampoco hay reportes PDF/XLSX, edición de ítems de un borrador ya guardado, invitación automática, importación de datos del prototipo ni sincronización Realtime. Para cambios externos usá Actualizar.
El esquema es extensible: no incluye liquidación laboral certificada, firma electrónica certificada ni cálculo contable consolidado. El stock puede calcularse sumando entradas menos salidas, pero todavía no hay RPC para impedir salidas que produzcan stock negativo. EPP registra nombre/fecha de conformidad; no certifica identidad. La aprobación de adicionales es un registro administrativo, no firma del cliente. Los adjuntos de la UI están vinculados a pedidos; para tickets/pólizas se deben extender las relaciones. Auditoría inicial cubre tareas y cabeceras de pedidos.
Las consultas de lista cargan los registros accesibles y paginan en cliente; para volúmenes grandes agregar paginación servidor e índices de búsqueda.

## Pruebas manuales recomendadas
- A crea estudio A/obra A; B crea estudio B/obra B. A no puede consultar datos de B ni generar enlaces de sus archivos incluso manipulando peticiones.
- C se registra sin asignación: no ve obras. A le asigna obra A como Jefe; C no puede aprobar pedidos ni asignar accesos.
- Crear, editar, mover cuatro estados y eliminar tareas; recargar y comprobar persistencia.
- Crear pedido de 10 bolsas, aprobar como A, recibir 4 como C y luego 6: debe quedar Entregado, con dos registros de recepción.
- Recibir más de lo pendiente, estados inválidos o repetir el mismo ítem en una recepción: debe fallar sin escrituras parciales.
- Adjuntar PDF; comprobar que usuario ajeno no pueda descargarlo. Enlaces ya emitidos pueden durar hasta 60 segundos tras revocar acceso.
- Recuperar contraseña y volver a iniciar sesión; verificar que la anterior ya no funciona.

## Seguridad operativa
RLS no es solo ocultar botones. Pedidos, aprobaciones y recepciones se modifican únicamente por RPC validada. Todas las obras se aíslan por estudio y asignación. Supabase persiste la sesión en el navegador: cerrá sesión en dispositivos compartidos. Antes de producción revisá RLS, backups, límites de registros, SMTP, política de retención y gestión de documentos sensibles. Las operaciones SQL manuales con rol postgres bypassan RLS: restringí el acceso al dashboard Supabase.

Documentación oficial:
https://supabase.com/docs/guides/getting-started/api-keys
https://supabase.com/docs/guides/auth/redirect-urls
