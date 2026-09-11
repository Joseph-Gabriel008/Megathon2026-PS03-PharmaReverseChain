-- ============================================================
--  MediLoop — Live Supabase Demo Setup & Seed Script
--  File: supabase/demo_setup.sql
--
--  Run this in your Supabase SQL Editor (Database > SQL Editor).
--  Prerequisites:
--    1. schema.sql executed
--    2. schema_patch.sql executed
--    3. 5 Auth users created in Supabase Auth:
--       - retailer@demo.com
--       - distributor@demo.com
--       - manufacturer@demo.com
--       - facility@demo.com
--       - admin@demo.com
--
--  SAFETY GUARANTEE:
--  - ZERO unconditional UPDATE statements.
--  - ZERO unconditional DELETE statements.
--  - Strictly scoped with WHERE clauses to MediLoop demo UUIDs.
--  - 100% idempotent: safe to run multiple times without corrupting data.
--  - Completely isolates demo data; NEVER touches non-demo/production records.
-- ============================================================

DO $$
DECLARE
  -- ──────────────────────────────────────────────────────────
  -- 1. REAL SUPABASE AUTH USER UUIDs
  -- Looked up dynamically from auth.users (with verified fallback IDs)
  -- ──────────────────────────────────────────────────────────
  v_retailer_id     uuid;
  v_distributor_id  uuid;
  v_manufacturer_id uuid;
  v_facility_id     uuid;
  v_admin_id        uuid;

  -- Organization UUIDs (Deterministic for demo reproducibility)
  v_pharmacy_org_id     constant uuid := '11111111-0000-0000-0000-000000000001';
  v_distributor_org_id  constant uuid := '22222222-0000-0000-0000-000000000001';
  v_manufacturer_org_id constant uuid := '33333333-0000-0000-0000-000000000001';
  v_facility_org_id     constant uuid := '44444444-0000-0000-0000-000000000001';
  v_admin_org_id        constant uuid := '55555555-0000-0000-0000-000000000001';

  -- Batch 1 (Demonstration Destroyed Batch)
  v_demo_batch_id constant uuid := 'bbbbbbbb-0000-0000-0000-000000000001';
  v_demo_disp_id  constant uuid := 'dddddddd-0000-0000-0000-000000000001';
  v_demo_cert_id  constant uuid := 'eeeeeeee-0000-0000-0000-000000000001';

  -- Explicit Arrays of Demo UUIDs to strictly scope all cleanup operations
  v_demo_org_ids constant uuid[] := ARRAY[
    v_pharmacy_org_id,
    v_distributor_org_id,
    v_manufacturer_org_id,
    v_facility_org_id,
    v_admin_org_id
  ];

  v_demo_batch_ids constant uuid[] := ARRAY[
    'bbbbbbbb-0000-0000-0000-000000000001'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000002'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000003'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000004'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000005'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000006'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000007'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000008'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000009'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000011'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000012'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000013'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000014'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000015'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000016'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000017'::uuid,
    'bbbbbbbb-0000-0000-0000-000000000018'::uuid
  ];

  v_demo_med_ids constant uuid[] := ARRAY[
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000003'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000005'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000006'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000007'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000008'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000011'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000012'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000013'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000014'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000015'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000016'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000017'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000018'::uuid
  ];

  v_demo_request_ids constant uuid[] := ARRAY[
    'ffffffff-0000-0000-0000-000000000001'::uuid,
    'ffffffff-0000-0000-0000-000000000002'::uuid
  ];

  v_demo_disp_ids constant uuid[] := ARRAY[
    'dddddddd-0000-0000-0000-000000000001'::uuid,
    'dddddddd-0000-0000-0000-000000000002'::uuid
  ];

  -- Hash chain tracking variables
  v_hash1 text;
  v_hash2 text;
  v_hash3 text;
  v_hash4 text;
  v_hash5 text;

BEGIN
  -- ──────────────────────────────────────────────────────────
  -- Fetch existing Auth UUIDs directly from auth.users
  -- ──────────────────────────────────────────────────────────
  SELECT id INTO v_retailer_id     FROM auth.users WHERE email = 'retailer@demo.com';
  SELECT id INTO v_distributor_id  FROM auth.users WHERE email = 'distributor@demo.com';
  SELECT id INTO v_manufacturer_id FROM auth.users WHERE email = 'manufacturer@demo.com';
  SELECT id INTO v_facility_id     FROM auth.users WHERE email = 'facility@demo.com';
  SELECT id INTO v_admin_id        FROM auth.users WHERE email = 'admin@demo.com';

  -- Fallback to verified project UUIDs if running in a context where auth.users is shadowed
  v_retailer_id     := COALESCE(v_retailer_id,     '8a303d55-66b6-4ba6-b1c8-24592e1d2ae3'::uuid);
  v_distributor_id  := COALESCE(v_distributor_id,  'f46731cd-ee32-4efc-ac73-1a098ab5eddb'::uuid);
  v_manufacturer_id := COALESCE(v_manufacturer_id, '4abeb5f8-abf1-48ec-b737-d319bd73aa43'::uuid);
  v_facility_id     := COALESCE(v_facility_id,     '0217ed55-aa83-4fb8-ba25-fe5ee42d1869'::uuid);
  v_admin_id        := COALESCE(v_admin_id,        '22e01bab-b4eb-4830-95c8-61904f59b7c9'::uuid);

  RAISE NOTICE 'Using Auth UUIDs:';
  RAISE NOTICE '  Retailer:     %', v_retailer_id;
  RAISE NOTICE '  Distributor:  %', v_distributor_id;
  RAISE NOTICE '  Manufacturer: %', v_manufacturer_id;
  RAISE NOTICE '  Facility:     %', v_facility_id;
  RAISE NOTICE '  Admin:        %', v_admin_id;

  -- ──────────────────────────────────────────────────────────
  -- 2. SAFE & TARGETED CLEANUP OF EXISTING DEMO DATA
  -- Every statement strictly contains a WHERE clause targeting only MediLoop demo IDs.
  -- Zero production or non-demo rows can be affected.
  -- ──────────────────────────────────────────────────────────

  -- Notifications: only delete notifications for demo users or demo batches
  DELETE FROM notifications
  WHERE user_id IN (v_retailer_id, v_distributor_id, v_manufacturer_id, v_facility_id, v_admin_id)
     OR related_batch_id = ANY(v_demo_batch_ids);

  -- QR Scans: only delete scans for demo batches or demo users
  DELETE FROM qr_scans
  WHERE batch_id = ANY(v_demo_batch_ids)
     OR scanned_by IN (v_retailer_id, v_distributor_id, v_manufacturer_id, v_facility_id, v_admin_id);

  -- Fraud Alerts: only delete alerts for demo batches or demo organizations
  DELETE FROM fraud_alerts
  WHERE batch_id = ANY(v_demo_batch_ids)
     OR organization_id = ANY(v_demo_org_ids);

  -- Batch Events: only delete events for demo batches
  DELETE FROM batch_events
  WHERE batch_id = ANY(v_demo_batch_ids)
     OR actor_id IN (v_retailer_id, v_distributor_id, v_manufacturer_id, v_facility_id, v_admin_id);

  -- Pickups: only delete demo pickups
  DELETE FROM pickups
  WHERE id = '99999999-0000-0000-0000-000000000001'::uuid
     OR reverse_request_id = ANY(v_demo_request_ids)
     OR distributor_id = v_distributor_org_id;

  -- Reverse Requests: only delete demo reverse requests
  DELETE FROM reverse_requests
  WHERE id = ANY(v_demo_request_ids)
     OR batch_id = ANY(v_demo_batch_ids)
     OR retailer_id = v_retailer_id;

  -- Break circular FK: ONLY on demo disposal records! (Never touches unrelated rows)
  UPDATE disposal_records
  SET certificate_id = NULL
  WHERE id = ANY(v_demo_disp_ids)
     OR batch_id = ANY(v_demo_batch_ids);

  -- Destruction Certificates: only delete demo certificates
  DELETE FROM destruction_certificates
  WHERE id = v_demo_cert_id
     OR batch_id = ANY(v_demo_batch_ids)
     OR certificate_number = 'CERT-BMW-2026-00431';

  -- Disposal Records: only delete demo disposal records
  DELETE FROM disposal_records
  WHERE id = ANY(v_demo_disp_ids)
     OR batch_id = ANY(v_demo_batch_ids);

  -- Medicine Batches: only delete demo batches
  DELETE FROM medicine_batches
  WHERE id = ANY(v_demo_batch_ids);

  -- Medicines: only delete demo medicines
  DELETE FROM medicines
  WHERE id = ANY(v_demo_med_ids);

  -- Users: only delete demo public user profiles
  DELETE FROM users
  WHERE id IN (v_retailer_id, v_distributor_id, v_manufacturer_id, v_facility_id, v_admin_id);

  -- Organizations: only delete demo organizations
  DELETE FROM organizations
  WHERE id = ANY(v_demo_org_ids);

  -- ──────────────────────────────────────────────────────────
  -- 3. SEED ORGANIZATIONS
  -- ──────────────────────────────────────────────────────────
  INSERT INTO organizations (id, name, type, license_number, verification_status, created_at, updated_at) VALUES
    (v_pharmacy_org_id,     'Apollo Pharmacy — Indiranagar',       'PHARMACY',       'DL-KA-BNG-2024-00182', 'VERIFIED', now(), now()),
    (v_distributor_org_id,  'MedSupply Southern Logistics Hub',   'DISTRIBUTOR',    'WDL-KA-2023-00912',   'VERIFIED', now(), now()),
    (v_manufacturer_org_id, 'Cipla Manufacturing Unit 4',          'MANUFACTURER',   'MFG-CDSCO-2021-081',  'VERIFIED', now(), now()),
    (v_facility_org_id,     'BioClean Bio-Medical Waste Facility', 'WASTE_FACILITY', 'CPCB-BMW-2022-0044',  'VERIFIED', now(), now()),
    (v_admin_org_id,        'CDSCO Southern Regional Office',      'REGULATOR',      'GOV-CDSCO-SOUTH',     'VERIFIED', now(), now())
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    license_number = EXCLUDED.license_number,
    verification_status = EXCLUDED.verification_status,
    updated_at = now();

  -- ──────────────────────────────────────────────────────────
  -- 4. SEED PUBLIC USERS (Mapped to real auth.users IDs)
  -- ──────────────────────────────────────────────────────────
  INSERT INTO users (id, name, email, role, organization_id, status, created_at) VALUES
    (v_retailer_id,     'Ramesh Patel, R.Ph.',        'retailer@demo.com',     'PHARMACY',       v_pharmacy_org_id,     'ACTIVE', now()),
    (v_distributor_id,  'Suresh Menon, Logistics Lead','distributor@demo.com',  'DISTRIBUTOR',    v_distributor_org_id,  'ACTIVE', now()),
    (v_manufacturer_id, 'Dr. Anita Roy, QA Director',  'manufacturer@demo.com', 'MANUFACTURER',   v_manufacturer_org_id, 'ACTIVE', now()),
    (v_facility_id,     'Vikram Joshi, Operations',    'facility@demo.com',     'WASTE_FACILITY', v_facility_org_id,     'ACTIVE', now()),
    (v_admin_id,        'Inspector Rajesh Sharma',     'admin@demo.com',        'REGULATOR',      v_admin_org_id,        'ACTIVE', now())
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    organization_id = EXCLUDED.organization_id,
    status = EXCLUDED.status;

  -- ──────────────────────────────────────────────────────────
  -- 5. SEED MEDICINES
  -- ──────────────────────────────────────────────────────────
  INSERT INTO medicines (id, name, generic_name, manufacturer_id, dosage, strength, created_at) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'Calpol 500',      'Paracetamol IP',            v_manufacturer_org_id, 'Tablet',  '500mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000002', 'Mox 500',         'Amoxicillin Trihydrate',    v_manufacturer_org_id, 'Capsule', '500mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000003', 'Glycomet 500',    'Metformin Hydrochloride',   v_manufacturer_org_id, 'Tablet',  '500mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000004', 'Atorva 20',       'Atorvastatin Calcium',      v_manufacturer_org_id, 'Tablet',  '20mg',  now()),
    ('aaaaaaaa-0000-0000-0000-000000000005', 'Azithral 250',    'Azithromycin Dihydrate',    v_manufacturer_org_id, 'Tablet',  '250mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000006', 'Cetzine 10',      'Cetirizine Hydrochloride',  v_manufacturer_org_id, 'Tablet',  '10mg',  now()),
    ('aaaaaaaa-0000-0000-0000-000000000007', 'Pan 40',          'Pantoprazole Sodium',       v_manufacturer_org_id, 'Tablet',  '40mg',  now()),
    ('aaaaaaaa-0000-0000-0000-000000000008', 'Levaquin 500',    'Levofloxacin Hemihydrate',  v_manufacturer_org_id, 'Tablet',  '500mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000011', 'Augmentin 625 Duo','Amoxicillin + Clavulanic', v_manufacturer_org_id, 'Tablet',  '625mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000012', 'Dolo 650',        'Paracetamol IP',            v_manufacturer_org_id, 'Tablet',  '650mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000013', 'Telma 40',         'Telmisartan IP',            v_manufacturer_org_id, 'Tablet',  '40mg',  now()),
    ('aaaaaaaa-0000-0000-0000-000000000014', 'Montair LC',       'Montelukast + Levocetirizine', v_manufacturer_org_id, 'Tablet', '10mg+5mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000015', 'Ecosprin 75',     'Aspirin Gastro-resistant',  v_manufacturer_org_id, 'Tablet',  '75mg',  now()),
    ('aaaaaaaa-0000-0000-0000-000000000016', 'Shelcal 500',      'Calcium + Vitamin D3',      v_manufacturer_org_id, 'Tablet',  '500mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000017', 'Ciplox 500',       'Ciprofloxacin HCl',         v_manufacturer_org_id, 'Tablet',  '500mg', now()),
    ('aaaaaaaa-0000-0000-0000-000000000018', 'Asthalin Inhaler', 'Salbutamol Inhalation',     v_manufacturer_org_id, 'Inhaler', '100mcg', now())
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    generic_name = EXCLUDED.generic_name,
    manufacturer_id = EXCLUDED.manufacturer_id,
    dosage = EXCLUDED.dosage,
    strength = EXCLUDED.strength;

  -- ──────────────────────────────────────────────────────────
  -- 6. SEED MEDICINE BATCHES
  -- ──────────────────────────────────────────────────────────
  INSERT INTO medicine_batches (
    id, medicine_id, batch_number, manufacturing_date, expiry_date,
    original_quantity, current_quantity, status,
    pharmacy_id, distributor_id, manufacturer_id, waste_facility_id,
    qr_code, created_at, updated_at
  ) VALUES
    -- ★ DEMO FRAUD BATCH: PARA500-2026-001 (Fully destroyed, for killer fraud demo)
    (v_demo_batch_id,
     'aaaaaaaa-0000-0000-0000-000000000001', 'PARA500-2026-001',
     '2025-06-01', '2026-03-31',
     100, 0, 'DESTROYED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, v_facility_org_id,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000001',
     now() - interval '90 days', now()),

    -- ── Pharmacy Active Inventory (Apollo Pharmacy) ──────────────────────────
    ('bbbbbbbb-0000-0000-0000-000000000002',
     'aaaaaaaa-0000-0000-0000-000000000001', 'PARA500-2026-002',
     CURRENT_DATE - interval '180 days', CURRENT_DATE + interval '240 days',
     500, 480, 'ACTIVE',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000002',
     now() - interval '60 days', now()),

    -- ── Pharmacy Expiring Soon (< 30 days) ──────────────────────────────────
    ('bbbbbbbb-0000-0000-0000-000000000003',
     'aaaaaaaa-0000-0000-0000-000000000003', 'METF500-2026-042',
     CURRENT_DATE - interval '330 days', CURRENT_DATE + interval '22 days',
     80, 80, 'EXPIRING_SOON',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000003',
     now() - interval '30 days', now()),

    -- ── Pharmacy Expired Stock (Needs Return) ───────────────────────────────
    ('bbbbbbbb-0000-0000-0000-000000000004',
     'aaaaaaaa-0000-0000-0000-000000000002', 'AMOX500-2025-089',
     CURRENT_DATE - interval '400 days', CURRENT_DATE - interval '45 days',
     120, 120, 'EXPIRED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000004',
     now() - interval '20 days', now()),

    -- ── Reverse Chain: Return Initiated by Apollo Pharmacy ──────────────────
    ('bbbbbbbb-0000-0000-0000-000000000005',
     'aaaaaaaa-0000-0000-0000-000000000005', 'AZITH250-2026-112',
     CURRENT_DATE - interval '200 days', CURRENT_DATE - interval '10 days',
     60, 60, 'RETURN_INITIATED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000005',
     now() - interval '5 days', now()),

    -- ── Distributor Queue: Pickup Assigned & Scheduled ──────────────────────
    ('bbbbbbbb-0000-0000-0000-000000000006',
     'aaaaaaaa-0000-0000-0000-000000000004', 'ATOR20-2025-015',
     CURRENT_DATE - interval '350 days', CURRENT_DATE - interval '15 days',
     200, 200, 'PICKUP_ASSIGNED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000006',
     now() - interval '3 days', now()),

    -- ── Manufacturer Queue: Collected & At Factory Gate ─────────────────────
    ('bbbbbbbb-0000-0000-0000-000000000007',
     'aaaaaaaa-0000-0000-0000-000000000008', 'LEVO500-2026-031',
     CURRENT_DATE - interval '300 days', CURRENT_DATE - interval '30 days',
     75, 75, 'COLLECTED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000007',
     now() - interval '2 days', now()),

    -- ── Manufacturer Queue: Verified, Disposal Pending ──────────────────────
    ('bbbbbbbb-0000-0000-0000-000000000008',
     'aaaaaaaa-0000-0000-0000-000000000007', 'PANT40-2025-031',
     CURRENT_DATE - interval '450 days', CURRENT_DATE - interval '60 days',
     290, 290, 'MANUFACTURER_RECEIVED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000008',
     now() - interval '4 days', now()),

    -- ── Waste Facility Queue: Assigned, Sent for Destruction ────────────────
    ('bbbbbbbb-0000-0000-0000-000000000009',
     'aaaaaaaa-0000-0000-0000-000000000006', 'CETR10-2025-044',
     CURRENT_DATE - interval '500 days', CURRENT_DATE - interval '90 days',
     50, 50, 'SENT_FOR_DESTRUCTION',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, v_facility_org_id,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000009',
     now() - interval '1 days', now()),

    -- ── Additional Returnable Batches for Apollo Pharmacy ───────────────────
    ('bbbbbbbb-0000-0000-0000-000000000011',
     'aaaaaaaa-0000-0000-0000-000000000011', 'AUG625-2025-104',
     CURRENT_DATE - interval '450 days', CURRENT_DATE - interval '30 days',
     150, 95, 'EXPIRED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000011',
     now() - interval '40 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000012',
     'aaaaaaaa-0000-0000-0000-000000000012', 'DOLO650-2026-018',
     CURRENT_DATE - interval '300 days', CURRENT_DATE + interval '15 days',
     300, 250, 'EXPIRING_SOON',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000012',
     now() - interval '25 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000013',
     'aaaaaaaa-0000-0000-0000-000000000013', 'TELM40-2025-088',
     CURRENT_DATE - interval '600 days', CURRENT_DATE - interval '60 days',
     200, 140, 'EXPIRED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000013',
     now() - interval '50 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000014',
     'aaaaaaaa-0000-0000-0000-000000000014', 'MONT-LC-2026-005',
     CURRENT_DATE - interval '200 days', CURRENT_DATE + interval '25 days',
     150, 110, 'EXPIRING_SOON',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000014',
     now() - interval '15 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000015',
     'aaaaaaaa-0000-0000-0000-000000000015', 'ECO75-2025-092',
     CURRENT_DATE - interval '500 days', CURRENT_DATE - interval '40 days',
     400, 300, 'EXPIRED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000015',
     now() - interval '35 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000016',
     'aaaaaaaa-0000-0000-0000-000000000016', 'SHEL500-2026-077',
     CURRENT_DATE - interval '220 days', CURRENT_DATE + interval '10 days',
     200, 160, 'EXPIRING_SOON',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000016',
     now() - interval '10 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000017',
     'aaaaaaaa-0000-0000-0000-000000000017', 'CIP500-2025-063',
     CURRENT_DATE - interval '550 days', CURRENT_DATE - interval '15 days',
     100, 85, 'EXPIRED',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000017',
     now() - interval '20 days', now()),

    ('bbbbbbbb-0000-0000-0000-000000000018',
     'aaaaaaaa-0000-0000-0000-000000000018', 'ASTH100-2026-021',
     CURRENT_DATE - interval '100 days', CURRENT_DATE + interval '365 days',
     50, 40, 'ACTIVE',
     v_pharmacy_org_id, v_distributor_org_id, v_manufacturer_org_id, NULL,
     'MEDILOOP:BATCH:bbbbbbbb-0000-0000-0000-000000000018',
     now() - interval '5 days', now())
  ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    current_quantity = EXCLUDED.current_quantity,
    pharmacy_id = EXCLUDED.pharmacy_id,
    distributor_id = EXCLUDED.distributor_id,
    manufacturer_id = EXCLUDED.manufacturer_id,
    waste_facility_id = EXCLUDED.waste_facility_id,
    qr_code = EXCLUDED.qr_code,
    updated_at = now();

  -- ──────────────────────────────────────────────────────────
  -- 7. SEED REVERSE REQUESTS
  -- ──────────────────────────────────────────────────────────
  INSERT INTO reverse_requests (
    id, batch_id, retailer_id, distributor_id, requested_quantity,
    reason, status, initiated_at
  ) VALUES
    -- Pending return from Apollo Pharmacy for AZITH250
    ('ffffffff-0000-0000-0000-000000000001',
     'bbbbbbbb-0000-0000-0000-000000000005',
     v_retailer_id, v_distributor_org_id, 60,
     'EXPIRED', 'PENDING', now() - interval '5 days'),

    -- Accepted return ready for pickup for ATOR20
    ('ffffffff-0000-0000-0000-000000000002',
     'bbbbbbbb-0000-0000-0000-000000000006',
     v_retailer_id, v_distributor_org_id, 200,
     'EXPIRED', 'ACCEPTED', now() - interval '3 days')
  ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    requested_quantity = EXCLUDED.requested_quantity;

  -- ──────────────────────────────────────────────────────────
  -- 8. SEED PICKUPS (Ensures Distributor queue is immediately active)
  -- ──────────────────────────────────────────────────────────
  INSERT INTO pickups (
    id, reverse_request_id, distributor_id, scheduled_date,
    pickup_status, actual_quantity, notes, created_at
  ) VALUES
    ('99999999-0000-0000-0000-000000000001',
     'ffffffff-0000-0000-0000-000000000002',
     v_distributor_org_id,
     now() + interval '1 day',
     'SCHEDULED', NULL,
     'Scheduled pickup at Apollo Pharmacy — Indiranagar. Verify tamper seal.',
     now())
  ON CONFLICT (id) DO UPDATE SET
    pickup_status = EXCLUDED.pickup_status,
    scheduled_date = EXCLUDED.scheduled_date;

  -- ──────────────────────────────────────────────────────────
  -- 9. SEED DISPOSAL RECORDS & CERTIFICATE METADATA
  -- ──────────────────────────────────────────────────────────
  -- A. Completed destruction for demo batch PARA500-2026-001
  INSERT INTO disposal_records (
    id, batch_id, manufacturer_id, waste_facility_id, disposal_method,
    actual_disposal_date, quantity_destroyed, status, created_at
  ) VALUES (
    v_demo_disp_id,
    v_demo_batch_id,
    v_manufacturer_org_id,
    v_facility_org_id,
    'INCINERATION',
    '2026-04-15',
    100,
    'COMPLETED',
    now() - interval '30 days'
  ) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    actual_disposal_date = EXCLUDED.actual_disposal_date;

  INSERT INTO destruction_certificates (
    id, disposal_record_id, batch_id, certificate_number,
    document_url, document_hash, issued_date, hash, verification_status, created_at
  ) VALUES (
    v_demo_cert_id,
    v_demo_disp_id,
    v_demo_batch_id,
    'CERT-BMW-2026-00431',
    NULL, -- Document can be uploaded live via Waste Facility / Admin app
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    '2026-04-15',
    'f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1',
    'VERIFIED',
    now() - interval '30 days'
  ) ON CONFLICT (id) DO UPDATE SET
    verification_status = EXCLUDED.verification_status,
    hash = EXCLUDED.hash;

  -- Strictly scoped UPDATE with exact primary key WHERE clause
  UPDATE disposal_records
  SET certificate_id = v_demo_cert_id
  WHERE id = v_demo_disp_id;

  -- B. Scheduled disposal for CETR10-2025-044 (Ready for Facility destruction demo)
  INSERT INTO disposal_records (
    id, batch_id, manufacturer_id, waste_facility_id, disposal_method,
    actual_disposal_date, quantity_destroyed, status, created_at
  ) VALUES (
    'dddddddd-0000-0000-0000-000000000002',
    'bbbbbbbb-0000-0000-0000-000000000009',
    v_manufacturer_org_id,
    v_facility_org_id,
    'INCINERATION',
    NULL,
    50,
    'SCHEDULED',
    now() - interval '1 day'
  ) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status;

  -- ──────────────────────────────────────────────────────────
  -- 10. CRYPTOGRAPHIC BATCH EVENTS FOR PARA500-2026-001
  -- Computes valid SHA-256 hash chain so verify_audit_chain passes!
  -- ──────────────────────────────────────────────────────────
  -- Event 1: Creation at Manufacturer
  v_hash1 := compute_event_hash(
    '',
    v_demo_batch_id,
    'BATCH_CREATED',
    v_manufacturer_id,
    100,
    'ACTIVE',
    '2025-06-01T10:00:00Z'::timestamptz
  );

  INSERT INTO batch_events (
    id, batch_id, event_type, actor_id, organization_id,
    quantity, previous_status, new_status, timestamp,
    event_hash, previous_event_hash
  ) VALUES (
    'cccccccc-0000-0000-0000-000000000001',
    v_demo_batch_id,
    'BATCH_CREATED',
    v_manufacturer_id,
    v_manufacturer_org_id,
    100, NULL, 'ACTIVE',
    '2025-06-01T10:00:00Z'::timestamptz,
    v_hash1, NULL
  ) ON CONFLICT (id) DO UPDATE SET
    event_hash = EXCLUDED.event_hash;

  -- Event 2: Return Initiated by Retailer
  v_hash2 := compute_event_hash(
    v_hash1,
    v_demo_batch_id,
    'RETURN_INITIATED',
    v_retailer_id,
    100,
    'RETURN_INITIATED',
    '2026-04-05T09:15:00Z'::timestamptz
  );

  INSERT INTO batch_events (
    id, batch_id, event_type, actor_id, organization_id,
    quantity, previous_status, new_status, timestamp,
    event_hash, previous_event_hash
  ) VALUES (
    'cccccccc-0000-0000-0000-000000000002',
    v_demo_batch_id,
    'RETURN_INITIATED',
    v_retailer_id,
    v_pharmacy_org_id,
    100, 'EXPIRED', 'RETURN_INITIATED',
    '2026-04-05T09:15:00Z'::timestamptz,
    v_hash2, v_hash1
  ) ON CONFLICT (id) DO UPDATE SET
    event_hash = EXCLUDED.event_hash;

  -- Event 3: Pickup Completed by Distributor
  v_hash3 := compute_event_hash(
    v_hash2,
    v_demo_batch_id,
    'PICKUP_COMPLETED',
    v_distributor_id,
    100,
    'COLLECTED',
    '2026-04-07T14:30:00Z'::timestamptz
  );

  INSERT INTO batch_events (
    id, batch_id, event_type, actor_id, organization_id,
    quantity, previous_status, new_status, timestamp,
    event_hash, previous_event_hash
  ) VALUES (
    'cccccccc-0000-0000-0000-000000000003',
    v_demo_batch_id,
    'PICKUP_COMPLETED',
    v_distributor_id,
    v_distributor_org_id,
    100, 'IN_TRANSIT', 'COLLECTED',
    '2026-04-07T14:30:00Z'::timestamptz,
    v_hash3, v_hash2
  ) ON CONFLICT (id) DO UPDATE SET
    event_hash = EXCLUDED.event_hash;

  -- Event 4: Disposal Scheduled by Manufacturer
  v_hash4 := compute_event_hash(
    v_hash3,
    v_demo_batch_id,
    'DISPOSAL_SCHEDULED',
    v_manufacturer_id,
    100,
    'SENT_FOR_DESTRUCTION',
    '2026-04-10T11:00:00Z'::timestamptz
  );

  INSERT INTO batch_events (
    id, batch_id, event_type, actor_id, organization_id,
    quantity, previous_status, new_status, timestamp,
    event_hash, previous_event_hash
  ) VALUES (
    'cccccccc-0000-0000-0000-000000000004',
    v_demo_batch_id,
    'DISPOSAL_SCHEDULED',
    v_manufacturer_id,
    v_manufacturer_org_id,
    100, 'MANUFACTURER_RECEIVED', 'SENT_FOR_DESTRUCTION',
    '2026-04-10T11:00:00Z'::timestamptz,
    v_hash4, v_hash3
  ) ON CONFLICT (id) DO UPDATE SET
    event_hash = EXCLUDED.event_hash;

  -- Event 5: Destruction Recorded by Waste Facility
  v_hash5 := compute_event_hash(
    v_hash4,
    v_demo_batch_id,
    'DESTRUCTION_RECORDED',
    v_facility_id,
    100,
    'DESTROYED',
    '2026-04-15T16:45:00Z'::timestamptz
  );

  INSERT INTO batch_events (
    id, batch_id, event_type, actor_id, organization_id,
    quantity, previous_status, new_status, timestamp,
    event_hash, previous_event_hash
  ) VALUES (
    'cccccccc-0000-0000-0000-000000000005',
    v_demo_batch_id,
    'DESTRUCTION_RECORDED',
    v_facility_id,
    v_facility_org_id,
    100, 'SENT_FOR_DESTRUCTION', 'DESTROYED',
    '2026-04-15T16:45:00Z'::timestamptz,
    v_hash5, v_hash4
  ) ON CONFLICT (id) DO UPDATE SET
    event_hash = EXCLUDED.event_hash;

  RAISE NOTICE 'Demo data setup successfully completed!';
  RAISE NOTICE 'PARA500-2026-001 cryptographic hash chain head: %', v_hash5;

END $$;
