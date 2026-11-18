-- INSTALACIÓN: ejecutar TODO este archivo UNA VEZ en SQL Editor de un proyecto Supabase NUEVO.
-- No ejecutar sobre una base con tablas del mismo nombre. Realizar respaldo primero.
begin;
create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text not null default '',email text not null,created_at timestamptz not null default now());
create table public.studios(id uuid primary key default gen_random_uuid(),name text not null check(length(trim(name)) between 1 and 160),created_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create table public.studio_members(studio_id uuid not null references public.studios(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,role text not null check(role in ('Administrador','Jefe de Obra')),created_at timestamptz not null default now(),primary key(studio_id,user_id));
create table public.projects(id uuid primary key default gen_random_uuid(),studio_id uuid not null references public.studios(id) on delete cascade,name text not null check(length(trim(name)) between 1 and 160),address text not null default '',client text not null default '',budget numeric(16,2) not null default 0 check(budget>=0),status text not null default 'Activa' check(status in ('Activa','Pausada','Finalizada')),start_date date,end_date date,created_at timestamptz not null default now(),unique(id,studio_id));
create table public.project_members(project_id uuid not null,studio_id uuid not null,user_id uuid not null,primary key(project_id,user_id),foreign key(project_id,studio_id) references public.projects(id,studio_id) on delete cascade,foreign key(studio_id,user_id) references public.studio_members(studio_id,user_id) on delete cascade);

create function private.is_admin(s uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.studio_members where studio_id=s and user_id=auth.uid() and role='Administrador');$$;
create function private.is_member(s uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.studio_members where studio_id=s and user_id=auth.uid());$$;
create function private.can_project(p uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.projects x where x.id=p and (private.is_admin(x.studio_id) or exists(select 1 from public.project_members m where m.project_id=p and m.user_id=auth.uid())));$$;
create function private.project_admin(p uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.projects x where x.id=p and private.is_admin(x.studio_id));$$;
create function private.valid_assignee(p uuid,u uuid) returns boolean language sql stable security definer set search_path='' as $$select u is null or exists(select 1 from public.projects x join public.studio_members sm on sm.studio_id=x.studio_id where x.id=p and sm.user_id=u and (sm.role='Administrador' or exists(select 1 from public.project_members pm where pm.project_id=p and pm.user_id=u)));$$;

create table public.tasks(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,title text not null check(length(trim(title)) between 1 and 150),trade text not null default 'Albañilería',assignee_id uuid references public.profiles(id) on delete set null,priority text not null default 'Media' check(priority in ('Baja','Media','Alta')),due_date date,status text not null default 'Por comenzar' check(status in ('Por comenzar','En curso','En pausa','Terminada')),tags text[] not null default '{}',description text not null default '',created_by uuid not null default auth.uid() references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.orders(id uuid primary key default gen_random_uuid(),number bigint generated always as identity unique,project_id uuid not null references public.projects(id) on delete cascade,supplier text not null check(length(trim(supplier)) between 1 and 180),trade text not null,due_date date not null,status text not null default 'Solicitado' check(status in ('Borrador','Solicitado','Aprobado','En camino','Entregado','Rechazado')),notes text not null default '',created_by uuid not null default auth.uid() references public.profiles(id),approved_by uuid references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(id,project_id));
create table public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,description text not null check(length(trim(description))>0),unit text not null,quantity numeric(14,2) not null check(quantity>0),received numeric(14,2) not null default 0 check(received>=0 and received<=quantity),note text not null default '');
create table public.order_receipts(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,received_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create table public.order_receipt_items(receipt_id uuid not null references public.order_receipts(id) on delete cascade,item_id uuid not null references public.order_items(id) on delete cascade,quantity numeric(14,2) not null check(quantity>0),primary key(receipt_id,item_id));

-- Resto de módulos: tablas listas para desarrollar sus interfaces.
create table public.workers(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,full_name text not null,category text not null default 'Peón' check(category in ('Oficial','Medio oficial','Peón','Otro')),hourly_rate numeric(14,2) not null default 0 check(hourly_rate>=0),active boolean not null default true,unique(id,project_id));
create table public.cash_movements(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,date date not null default current_date,concept text not null,category text not null,direction text not null check(direction in ('Ingreso','Egreso')),amount numeric(14,2) not null check(amount>0),created_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now());
create table public.attendance(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,worker_id uuid not null,date date not null,hours numeric(5,2) not null check(hours>=0 and hours<=24),hourly_rate numeric(14,2) not null check(hourly_rate>=0),notes text not null default '',foreign key(worker_id,project_id) references public.workers(id,project_id),unique(worker_id,date));
create table public.extras(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,description text not null,cost_impact numeric(14,2) not null default 0,days_impact integer not null default 0,status text not null default 'Pendiente' check(status in ('Pendiente','Aprobado','Rechazado')),client_approval_note text not null default '',created_at timestamptz not null default now());
create table public.daily_logs(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,date date not null default current_date,weather text not null default '',personnel_count integer not null default 0 check(personnel_count>=0),visits text not null default '',inspections text not null default '',notes text not null default '',created_by uuid default auth.uid() references public.profiles(id),unique(project_id,date));
create table public.meetings(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,date timestamptz not null default now(),title text not null,attendees text[] not null default '{}',topics text not null default '',agreements text not null default '',unique(id,project_id));
create table public.meeting_actions(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,meeting_id uuid not null,description text not null,task_id uuid references public.tasks(id) on delete set null,foreign key(meeting_id,project_id) references public.meetings(id,project_id));
create table public.freights(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,scheduled_at timestamptz not null,carrier text not null,origin text not null,destination text not null,cost numeric(14,2) not null default 0 check(cost>=0),status text not null default 'Programado' check(status in ('Programado','En camino','Entregado','Cancelado')),notes text not null default '');
create table public.dumpsters(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,provider text not null,requested_date date not null default current_date,delivered_date date,removal_due_date date not null,removed_date date,cost numeric(14,2) not null default 0 check(cost>=0),status text not null default 'Solicitado' check(status in ('Solicitado','En obra','Retirado','Cancelado')));
create table public.insurance_policies(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,type text not null check(type in ('ART','Responsabilidad civil','Maquinaria','Personal','Otro')),provider text not null,policy_number text not null,starts_on date not null,expires_on date not null,notes text not null default '',check(expires_on>=starts_on));
create table public.ppe_deliveries(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,worker_id uuid not null,item text not null,size text not null default '',quantity integer not null default 1 check(quantity>0),delivered_on date not null default current_date,conformity_name text,conformity_at timestamptz,foreign key(worker_id,project_id) references public.workers(id,project_id));
create table public.inventory_items(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,name text not null,unit text not null default 'u',condition text not null default 'Bueno',responsible_id uuid references public.profiles(id),unique(id,project_id));
create table public.inventory_movements(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,item_id uuid not null,direction text not null check(direction in ('Entrada','Salida')),quantity numeric(14,2) not null check(quantity>0),notes text not null default '',created_at timestamptz not null default now(),created_by uuid default auth.uid() references public.profiles(id),foreign key(item_id,project_id) references public.inventory_items(id,project_id));
create table public.attachments(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,order_id uuid,name text not null,path text not null unique,size bigint check(size between 0 and 10485760),mime_type text,created_by uuid not null default auth.uid() references public.profiles(id),created_at timestamptz not null default now(),foreign key(order_id,project_id) references public.orders(id,project_id) on delete cascade,check(split_part(path,'/',1)=project_id::text));
create table public.audit_events(id bigint generated always as identity primary key,project_id uuid references public.projects(id) on delete cascade,actor_id uuid,table_name text not null,record_id uuid,operation text not null,created_at timestamptz not null default now());

create function private.validate_links() returns trigger language plpgsql security definer set search_path='' as $$begin
 if TG_TABLE_NAME='meeting_actions' then
  if new.task_id is not null then
   if not exists(select 1 from public.tasks where id=new.task_id and project_id=new.project_id) then raise exception 'La tarea pertenece a otra obra';end if;
  end if;
 elsif TG_TABLE_NAME='inventory_items' then
  if not private.valid_assignee(new.project_id,new.responsible_id) then raise exception 'Responsable ajeno a la obra';end if;
 end if;return new;end $$;
create trigger validate_meeting_task before insert or update on public.meeting_actions for each row execute function private.validate_links();
create trigger validate_inventory_owner before insert or update on public.inventory_items for each row execute function private.validate_links();

-- RLS de todas las tablas operativas, sin recursión de políticas de membresía.
do $$declare t text;begin foreach t in array array['tasks','orders','workers','cash_movements','attendance','extras','daily_logs','meetings','meeting_actions','freights','dumpsters','insurance_policies','ppe_deliveries','inventory_items','inventory_movements','attachments','audit_events'] loop
 execute format('alter table public.%I enable row level security',t);execute format('create index on public.%I(project_id)',t);
 execute format('create policy read_project on public.%I for select to authenticated using(private.can_project(project_id))',t);
 if t not in ('orders','audit_events','tasks') then
 execute format('create policy insert_project on public.%I for insert to authenticated with check(private.can_project(project_id))',t);
 execute format('create policy update_project on public.%I for update to authenticated using(private.can_project(project_id)) with check(private.can_project(project_id))',t);
 execute format('create policy delete_project on public.%I for delete to authenticated using(private.can_project(project_id))',t);end if;end loop;end $$;
create policy task_insert on public.tasks for insert to authenticated with check(private.can_project(project_id) and private.valid_assignee(project_id,assignee_id) and created_by=auth.uid());
create policy task_update on public.tasks for update to authenticated using(private.can_project(project_id)) with check(private.can_project(project_id) and private.valid_assignee(project_id,assignee_id));
create policy task_delete on public.tasks for delete to authenticated using(private.can_project(project_id));
alter table public.profiles enable row level security;alter table public.studios enable row level security;alter table public.studio_members enable row level security;alter table public.project_members enable row level security;alter table public.projects enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid());
create policy studios_read on public.studios for select to authenticated using(private.is_member(id));
create policy studios_update on public.studios for update to authenticated using(private.is_admin(id)) with check(private.is_admin(id));
create policy membership_read on public.studio_members for select to authenticated using(user_id=auth.uid() or private.is_admin(studio_id));
create policy project_read on public.projects for select to authenticated using(private.can_project(id));
create policy project_insert on public.projects for insert to authenticated with check(private.is_admin(studio_id));
create policy project_update on public.projects for update to authenticated using(private.is_admin(studio_id)) with check(private.is_admin(studio_id));
create policy assignment_read on public.project_members for select to authenticated using(private.can_project(project_id));
create policy assignment_delete on public.project_members for delete to authenticated using(private.is_admin(studio_id));
alter table public.order_items enable row level security;alter table public.order_receipts enable row level security;alter table public.order_receipt_items enable row level security;
create policy item_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id));
create policy receipt_read on public.order_receipts for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id));
create policy receipt_item_read on public.order_receipt_items for select to authenticated using(exists(select 1 from public.order_receipts r where r.id=receipt_id));
create index on public.studio_members(user_id);create index on public.project_members(user_id);create index on public.projects(studio_id);create index on public.order_items(order_id);create index on public.order_receipts(order_id);

-- Perfil automático. Roles nunca se toman de user_metadata.
create function private.on_signup() returns trigger language plpgsql security definer set search_path='' as $$begin insert into public.profiles(id,email,full_name) values(new.id,lower(new.email),coalesce(new.raw_user_meta_data->>'full_name',''));return new;end $$;
create trigger auth_signup after insert on auth.users for each row execute function private.on_signup();
insert into public.profiles(id,email,full_name) select id,lower(email),coalesce(raw_user_meta_data->>'full_name','') from auth.users on conflict(id) do nothing;
create function private.sync_email() returns trigger language plpgsql security definer set search_path='' as $$begin update public.profiles set email=lower(new.email) where id=new.id;return new;end $$;
create trigger auth_email_update after update of email on auth.users for each row execute function private.sync_email();

-- No permitir cambiar la pertenencia de los registros entre obras/estudios.
create function private.prevent_project_change() returns trigger language plpgsql set search_path='' as $$begin if new.project_id is distinct from old.project_id then raise exception 'No se permite trasladar registros entre obras';end if;return new;end $$;
do $$declare t text;begin foreach t in array array['tasks','orders','workers','cash_movements','attendance','extras','daily_logs','meetings','meeting_actions','freights','dumpsters','insurance_policies','ppe_deliveries','inventory_items','inventory_movements','attachments'] loop execute format('create trigger immutable_project before update on public.%I for each row execute function private.prevent_project_change()',t);end loop;end $$;
create function private.prevent_studio_change() returns trigger language plpgsql set search_path='' as $$begin if new.studio_id is distinct from old.studio_id then raise exception 'No se permite trasladar obras entre estudios';end if;return new;end $$;
create trigger immutable_studio before update on public.projects for each row execute function private.prevent_studio_change();
create function private.prevent_author_change() returns trigger language plpgsql set search_path='' as $$begin if new.created_by is distinct from old.created_by then raise exception 'No se permite cambiar el autor';end if;return new;end $$;
create trigger immutable_task_author before update on public.tasks for each row execute function private.prevent_author_change();
create trigger immutable_attachment_author before update on public.attachments for each row execute function private.prevent_author_change();
create function private.audit_record() returns trigger language plpgsql security definer set search_path='' as $$declare r record;begin if TG_OP='DELETE' then r:=old;else r:=new;end if;insert into public.audit_events(project_id,actor_id,table_name,record_id,operation) values(r.project_id,auth.uid(),TG_TABLE_NAME,r.id,TG_OP);if TG_OP='DELETE' then return old;else return new;end if;end $$;
create trigger audit_tasks after insert or update or delete on public.tasks for each row execute function private.audit_record();
create trigger audit_orders after insert or update or delete on public.orders for each row execute function private.audit_record();
create function private.touch_updated() returns trigger language plpgsql set search_path='' as $$begin new.updated_at:=now();return new;end $$;
create trigger touch_task before update on public.tasks for each row execute function private.touch_updated();create trigger touch_order before update on public.orders for each row execute function private.touch_updated();

-- Operaciones privilegiadas: SECURITY DEFINER con validación explícita y search_path vacío.
create function public.create_studio(p_name text) returns uuid language plpgsql security definer set search_path='' as $$declare s uuid;begin if auth.uid() is null then raise exception 'Iniciá sesión';end if;insert into public.studios(name,created_by) values(trim(p_name),auth.uid()) returning id into s;insert into public.studio_members(studio_id,user_id,role) values(s,auth.uid(),'Administrador');return s;end $$;
create function public.add_studio_member(p_studio uuid,p_email text,p_role text,p_project uuid default null) returns void language plpgsql security definer set search_path='' as $$declare u uuid;begin
 if not private.is_admin(p_studio) then raise exception 'Solo un administrador puede asignar accesos';end if;
 if p_role is null or p_role not in ('Administrador','Jefe de Obra') then raise exception 'Rol inválido';end if;
 if p_project is not null and not exists(select 1 from public.projects where id=p_project and studio_id=p_studio) then raise exception 'La obra no pertenece al estudio';end if;
 select id into u from public.profiles where email=lower(trim(p_email));if u is null then raise exception 'El usuario debe registrarse primero';end if;
 if not exists(select 1 from auth.users where id=u and email_confirmed_at is not null) then raise exception 'El usuario debe confirmar su correo primero';end if;
 if u=auth.uid() then raise exception 'No cambies tu propio rol';end if;
 if exists(select 1 from public.studio_members where studio_id=p_studio and user_id=u and role='Administrador') and p_role<>'Administrador' then raise exception 'La degradación de administradores requiere revisión manual';end if;
 insert into public.studio_members(studio_id,user_id,role) values(p_studio,u,p_role) on conflict(studio_id,user_id) do update set role=excluded.role;
 if p_project is not null then insert into public.project_members(project_id,studio_id,user_id) values(p_project,p_studio,u) on conflict do nothing;end if;end $$;
create function public.list_project_members(p_project uuid) returns table(user_id uuid,role text,full_name text,email text) language plpgsql stable security definer set search_path='' as $$begin if not private.can_project(p_project) then raise exception 'Sin acceso';end if;return query select m.user_id,m.role,p.full_name,p.email from public.studio_members m join public.profiles p on p.id=m.user_id join public.projects x on x.studio_id=m.studio_id where x.id=p_project and (m.role='Administrador' or exists(select 1 from public.project_members pm where pm.project_id=p_project and pm.user_id=m.user_id)) order by p.full_name;end $$;

-- Pedido + ítems atómicos. No se confía en received/status enviados por el cliente.
create function public.create_order(p_project uuid,p_supplier text,p_trade text,p_due date,p_notes text,p_items jsonb,p_draft boolean default false) returns uuid language plpgsql security definer set search_path='' as $$declare o uuid;i jsonb;begin
 if not private.can_project(p_project) then raise exception 'Sin acceso a la obra';end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Materiales inválidos';end if;
 if jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>100 then raise exception 'Incluí entre 1 y 100 materiales';end if;
 insert into public.orders(project_id,supplier,trade,due_date,notes,status,created_by) values(p_project,trim(p_supplier),p_trade,p_due,coalesce(p_notes,''),case when p_draft then 'Borrador' else 'Solicitado' end,auth.uid()) returning id into o;
 for i in select value from jsonb_array_elements(p_items) loop insert into public.order_items(order_id,description,unit,quantity,note) values(o,trim(i->>'description'),i->>'unit',(i->>'quantity')::numeric,coalesce(i->>'note',''));end loop;return o;end $$;
create function public.change_order_status(p_order uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$declare o public.orders;begin select * into o from public.orders where id=p_order for update;if o.id is null or not private.can_project(o.project_id) then raise exception 'Sin acceso';end if;
 if o.status='Borrador' and p_status='Solicitado' then null;
 elsif o.status='Solicitado' and p_status in ('Aprobado','Rechazado') then if not private.project_admin(o.project_id) then raise exception 'Solo el administrador puede aprobar o rechazar';end if;
 elsif o.status='Aprobado' and p_status='En camino' then null;else raise exception 'Transición de estado inválida';end if;
 update public.orders set status=p_status,approved_by=case when p_status in ('Aprobado','Rechazado') then auth.uid() else approved_by end where id=p_order;end $$;

-- Bloqueo de pedido e ítems: evita sobre-recepciones concurrentes.
create function public.receive_order(p_order uuid,p_items jsonb) returns void language plpgsql security definer set search_path='' as $$declare o public.orders;r uuid;i jsonb;row_item public.order_items;q numeric;begin
 select * into o from public.orders where id=p_order for update;if o.id is null or not private.can_project(o.project_id) then raise exception 'Sin acceso';end if;
 if o.status not in ('Aprobado','En camino') then raise exception 'El pedido no permite recepciones';end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' then raise exception 'Recepción inválida';end if;
 if jsonb_array_length(p_items)=0 then raise exception 'Ingresá al menos una cantidad';end if;
 insert into public.order_receipts(order_id,received_by) values(p_order,auth.uid()) returning id into r;
 for i in select value from jsonb_array_elements(p_items) loop select * into row_item from public.order_items where id=(i->>'id')::uuid and order_id=p_order for update;q:=(i->>'quantity')::numeric;
 if row_item.id is null or q is null or q<=0 or q>row_item.quantity-row_item.received then raise exception 'Cantidad de recepción inválida';end if;
 insert into public.order_receipt_items(receipt_id,item_id,quantity) values(r,row_item.id,q);update public.order_items set received=received+q where id=row_item.id;end loop;
 update public.orders set status=case when not exists(select 1 from public.order_items where order_id=p_order and received<quantity) then 'Entregado' else 'En camino' end where id=p_order;end $$;

-- Bucket privado; primer segmento del path = UUID de la obra.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('obra-files','obra-files',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']);
create function private.file_access(path text) returns boolean language plpgsql stable security definer set search_path='' as $$begin return private.can_project(split_part(path,'/',1)::uuid);exception when invalid_text_representation then return false;end $$;
create policy obra_files_read on storage.objects for select to authenticated using(bucket_id='obra-files' and private.file_access(name));
create policy obra_files_insert on storage.objects for insert to authenticated with check(bucket_id='obra-files' and private.file_access(name));
create policy obra_files_delete on storage.objects for delete to authenticated using(bucket_id='obra-files' and private.file_access(name));

-- Privilegios explícitos; sin acceso anónimo y sin escritura directa en tablas RPC.
revoke all on all tables in schema public from anon;
grant select on all tables in schema public to authenticated;
grant insert,update,delete on public.tasks,public.workers,public.cash_movements,public.attendance,public.extras,public.daily_logs,public.meetings,public.meeting_actions,public.freights,public.dumpsters,public.insurance_policies,public.ppe_deliveries,public.inventory_items,public.inventory_movements,public.attachments to authenticated;
grant insert,update on public.projects to authenticated;grant update on public.studios to authenticated;grant delete on public.project_members to authenticated;
revoke insert,update,delete on public.profiles,public.studio_members,public.orders,public.order_items,public.order_receipts,public.order_receipt_items,public.audit_events from authenticated;
revoke insert,update on public.project_members from authenticated;revoke delete on public.projects,public.studios from authenticated;
revoke all on all functions in schema private from public,anon;
grant execute on function private.is_admin(uuid),private.is_member(uuid),private.can_project(uuid),private.project_admin(uuid),private.valid_assignee(uuid,uuid),private.file_access(text) to authenticated;
revoke all on function public.create_studio(text),public.add_studio_member(uuid,text,text,uuid),public.list_project_members(uuid),public.create_order(uuid,text,text,date,text,jsonb,boolean),public.change_order_status(uuid,text),public.receive_order(uuid,jsonb) from public,anon;
grant execute on function public.create_studio(text),public.add_studio_member(uuid,text,text,uuid),public.list_project_members(uuid),public.create_order(uuid,text,text,date,text,jsonb,boolean),public.change_order_status(uuid,text),public.receive_order(uuid,jsonb) to authenticated;
commit;
