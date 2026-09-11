-- ============================================================
--  MediLoop — Complete Database Schema
--  Run this in your Supabase SQL editor (Database > SQL Editor)
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ────────────────────────────────────────────────────────────
--  ENUMS
-- ────────────────────────────────────────────────────────────

create type org_type as enum (
  'PHARMACY', 'DISTRIBUTOR', 'MANUFACTURER', 'WASTE_FACILITY', 'REGULATOR'
);

create type verification_status as enum (
  'PENDING', 'VERIFIED', 'SUSPENDED'
);

create type batch_status as enum (
  'ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'RETURN_INITIATED',
  'IN_TRANSIT', 'COLLECTED', 'DISTRIBUTOR_VERIFIED',
  'MANUFACTURER_RECEIVED', 'DISPOSAL_PENDING',
  'SENT_FOR_DESTRUCTION', 'DESTROYED', 'CLOSED'
);

create type request_status as enum (
  'PENDING', 'ACCEPTED', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED'
);

create type pickup_status as enum (
  'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'FAILED'
);

create type disposal_status as enum (
  'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
);

create type alert_type as enum (
  'DESTROYED_BATCH_REENTRY', 'QUANTITY_MISMATCH',
  'EXPIRED_BATCH_SALE', 'INVALID_BATCH', 'DUPLICATE_BATCH_SCAN'
);

create type alert_severity as enum ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW');

create type alert_status as enum (
  'OPEN', 'INVESTIGATING', 'RESOLVED', 'FALSE_POSITIVE'
);

create type return_reason as enum (
  'EXPIRED', 'DAMAGED', 'RECALLED', 'OTHER'
);

create type disposal_method as enum (
  'INCINERATION', 'CHEMICAL', 'LANDFILL'
);

-- ────────────────────────────────────────────────────────────
--  ORGANIZATIONS
-- ────────────────────────────────────────────────────────────

create table organizations (
  id                  uuid primary key default uuid_generate_v4(),
  name                text not null,
  type                org_type not null,
  license_number      text not null unique,
  verification_status verification_status not null default 'PENDING',
  created_at          timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
--  USERS (linked to Supabase Auth)
-- ────────────────────────────────────────────────────────────

create table users (
  id              uuid primary key references auth.users(id) on delete cascade,
  name            text not null,
  email           text not null unique,
  role            org_type not null,
  organization_id uuid not null references organizations(id),
  status          text not null default 'ACTIVE',
  created_at      timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
--  MEDICINES
-- ────────────────────────────────────────────────────────────

create table medicines (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  generic_name    text not null,
  manufacturer_id uuid not null references organizations(id),
  dosage          text,
  strength        text,
  created_at      timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
--  MEDICINE BATCHES
-- ────────────────────────────────────────────────────────────

create table medicine_batches (
  id                  uuid primary key default uuid_generate_v4(),
  medicine_id         uuid not null references medicines(id),
  batch_number        text not null unique,
  manufacturing_date  date not null,
  expiry_date         date not null,
  original_quantity   integer not null check (original_quantity > 0),
  current_quantity    integer not null check (current_quantity >= 0),
  status              batch_status not null default 'ACTIVE',
  pharmacy_id         uuid references organizations(id),
  distributor_id      uuid references organizations(id),
  manufacturer_id     uuid references organizations(id),
  waste_facility_id   uuid references organizations(id),
  qr_code             text,
  created_at          timestamptz not null default now()
);

create index on medicine_batches(pharmacy_id);
create index on medicine_batches(status);
create index on medicine_batches(batch_number);
create index on medicine_batches(expiry_date);

-- ────────────────────────────────────────────────────────────
--  REVERSE REQUESTS
-- ────────────────────────────────────────────────────────────

create table reverse_requests (
  id                 uuid primary key default uuid_generate_v4(),
  batch_id           uuid not null references medicine_batches(id),
  retailer_id        uuid not null references users(id),
  distributor_id     uuid references organizations(id),
  requested_quantity integer not null check (requested_quantity > 0),
  reason             return_reason not null,
  status             request_status not null default 'PENDING',
  initiated_at       timestamptz not null default now(),
  pickup_date        timestamptz,
  completed_at       timestamptz
);

create index on reverse_requests(retailer_id);
create index on reverse_requests(status);

-- ────────────────────────────────────────────────────────────
--  PICKUPS
-- ────────────────────────────────────────────────────────────

create table pickups (
  id                  uuid primary key default uuid_generate_v4(),
  reverse_request_id  uuid not null references reverse_requests(id),
  distributor_id      uuid not null references organizations(id),
  scheduled_date      timestamptz,
  pickup_status       pickup_status not null default 'SCHEDULED',
  actual_quantity     integer,
  notes               text,
  created_at          timestamptz not null default now()
);

create index on pickups(distributor_id);

-- ────────────────────────────────────────────────────────────
--  DISPOSAL RECORDS
-- ────────────────────────────────────────────────────────────

create table disposal_records (
  id                   uuid primary key default uuid_generate_v4(),
  batch_id             uuid not null references medicine_batches(id),
  manufacturer_id      uuid not null references organizations(id),
  waste_facility_id    uuid references organizations(id),
  disposal_method      disposal_method not null,
  actual_disposal_date date,
  quantity_destroyed   integer not null check (quantity_destroyed > 0),
  status               disposal_status not null default 'SCHEDULED',
  certificate_id       uuid,
  created_at           timestamptz not null default now()
);

create index on disposal_records(batch_id);
create index on disposal_records(waste_facility_id);

-- ────────────────────────────────────────────────────────────
--  DESTRUCTION CERTIFICATES
-- ────────────────────────────────────────────────────────────

create table destruction_certificates (
  id                 uuid primary key default uuid_generate_v4(),
  disposal_record_id uuid not null references disposal_records(id),
  certificate_number text not null,
  document_url       text,
  issued_date        date not null,
  hash               text not null,
  created_at         timestamptz not null default now()
);

-- Add FK from disposal_records back to certificates
alter table disposal_records
  add constraint fk_disposal_certificate
  foreign key (certificate_id) references destruction_certificates(id)
  deferrable initially deferred;

-- ────────────────────────────────────────────────────────────
--  BATCH EVENTS (tamper-evident hash chain)
-- ────────────────────────────────────────────────────────────

create table batch_events (
  id                  uuid primary key default uuid_generate_v4(),
  batch_id            uuid not null references medicine_batches(id),
  event_type          text not null,
  actor_id            uuid not null references users(id),
  organization_id     uuid not null references organizations(id),
  quantity            integer not null default 0,
  previous_status     batch_status,
  new_status          batch_status not null,
  timestamp           timestamptz not null default now(),
  event_hash          text not null,
  previous_event_hash text
);

create index on batch_events(batch_id);
create index on batch_events(timestamp desc);

-- ────────────────────────────────────────────────────────────
--  FRAUD ALERTS
-- ────────────────────────────────────────────────────────────

create table fraud_alerts (
  id              uuid primary key default uuid_generate_v4(),
  batch_id        uuid not null references medicine_batches(id),
  alert_type      alert_type not null,
  severity        alert_severity not null,
  description     text not null,
  ai_narrative    text,
  status          alert_status not null default 'OPEN',
  organization_id uuid references organizations(id),
  detected_at     timestamptz not null default now()
);

create index on fraud_alerts(status);
create index on fraud_alerts(severity);
create index on fraud_alerts(detected_at desc);

-- ────────────────────────────────────────────────────────────
--  QR SCANS
-- ────────────────────────────────────────────────────────────

create table qr_scans (
  id              uuid primary key default uuid_generate_v4(),
  batch_id        uuid not null references medicine_batches(id),
  scanned_by      uuid not null references users(id),
  organization_id uuid not null references organizations(id),
  result          text not null,
  timestamp       timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
--  NOTIFICATIONS
-- ────────────────────────────────────────────────────────────

create table notifications (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references users(id),
  title           text not null,
  message         text not null,
  type            text not null,
  related_batch_id uuid references medicine_batches(id),
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
--  ENABLE REALTIME on fraud_alerts
-- ────────────────────────────────────────────────────────────

alter publication supabase_realtime add table fraud_alerts;
alter publication supabase_realtime add table batch_events;

-- ────────────────────────────────────────────────────────────
--  ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────

-- Enable RLS on all tables
alter table organizations enable row level security;
alter table users enable row level security;
alter table medicines enable row level security;
alter table medicine_batches enable row level security;
alter table reverse_requests enable row level security;
alter table pickups enable row level security;
alter table disposal_records enable row level security;
alter table destruction_certificates enable row level security;
alter table batch_events enable row level security;
alter table fraud_alerts enable row level security;
alter table qr_scans enable row level security;
alter table notifications enable row level security;

-- Helper function: get role of current user
create or replace function get_my_role()
returns text
language sql security definer
as $$
  select role::text from users where id = auth.uid()
$$;

-- Helper function: get org_id of current user
create or replace function get_my_org_id()
returns uuid
language sql security definer
as $$
  select organization_id from users where id = auth.uid()
$$;

-- Organizations: everyone authenticated can read; Admin can manage
create policy "authenticated can read orgs"
  on organizations for select
  to authenticated using (true);

create policy "admin can insert orgs"
  on organizations for insert
  to authenticated
  with check (get_my_role() = 'REGULATOR');

create policy "admin can update orgs"
  on organizations for update
  to authenticated
  using (get_my_role() = 'REGULATOR');

-- Users: users can read their own row; admin reads all
create policy "users can read own profile"
  on users for select
  to authenticated
  using (id = auth.uid() or get_my_role() = 'REGULATOR');

-- Medicine batches: RLS based on role
create policy "pharmacy reads own batches"
  on medicine_batches for select
  to authenticated
  using (
    get_my_role() = 'REGULATOR'
    or get_my_role() = 'MANUFACTURER'
    or get_my_role() = 'DISTRIBUTOR'
    or pharmacy_id = get_my_org_id()
    or waste_facility_id = get_my_org_id()
  );

create policy "batch update allowed for relevant roles"
  on medicine_batches for update
  to authenticated
  using (get_my_role() in ('PHARMACY','DISTRIBUTOR','MANUFACTURER','WASTE_FACILITY','REGULATOR'));

-- Batch events: all authenticated users can insert; read based on involvement
create policy "any auth can insert batch event"
  on batch_events for insert
  to authenticated
  with check (actor_id = auth.uid());

create policy "any auth can read batch events"
  on batch_events for select
  to authenticated
  using (true);

-- Fraud alerts: any auth can insert (fraud engine); admin manages
create policy "any auth can insert fraud alert"
  on fraud_alerts for insert
  to authenticated
  with check (true);

create policy "any auth can read fraud alerts"
  on fraud_alerts for select
  to authenticated
  using (true);

create policy "admin can update fraud alert"
  on fraud_alerts for update
  to authenticated
  using (get_my_role() = 'REGULATOR');

-- Reverse requests: retailer can insert own; distributor/admin can see all
create policy "retailer can insert request"
  on reverse_requests for insert
  to authenticated
  with check (retailer_id = auth.uid());

create policy "relevant roles can read requests"
  on reverse_requests for select
  to authenticated
  using (
    retailer_id = auth.uid()
    or get_my_role() in ('DISTRIBUTOR','MANUFACTURER','REGULATOR')
  );

create policy "relevant roles can update requests"
  on reverse_requests for update
  to authenticated
  using (get_my_role() in ('DISTRIBUTOR','REGULATOR'));

-- Pickups: distributor can insert/update
create policy "distributor can manage pickups"
  on pickups for all
  to authenticated
  using (
    distributor_id = get_my_org_id()
    or get_my_role() = 'REGULATOR'
  )
  with check (
    distributor_id = get_my_org_id()
    or get_my_role() = 'REGULATOR'
  );

-- Disposal records
create policy "relevant roles can manage disposal"
  on disposal_records for all
  to authenticated
  using (
    manufacturer_id = get_my_org_id()
    or waste_facility_id = get_my_org_id()
    or get_my_role() = 'REGULATOR'
  )
  with check (
    manufacturer_id = get_my_org_id()
    or waste_facility_id = get_my_org_id()
    or get_my_role() = 'REGULATOR'
  );

-- Destruction certificates
create policy "relevant roles can manage certs"
  on destruction_certificates for all
  to authenticated
  using (get_my_role() in ('WASTE_FACILITY','MANUFACTURER','REGULATOR'))
  with check (get_my_role() in ('WASTE_FACILITY','MANUFACTURER','REGULATOR'));

-- Medicines
create policy "authenticated can read medicines"
  on medicines for select
  to authenticated using (true);

-- QR scans
create policy "any auth can insert scan"
  on qr_scans for insert
  to authenticated
  with check (scanned_by = auth.uid());

create policy "any auth can read scans"
  on qr_scans for select
  to authenticated using (true);

-- Notifications
create policy "users read own notifications"
  on notifications for select
  to authenticated
  using (user_id = auth.uid());
