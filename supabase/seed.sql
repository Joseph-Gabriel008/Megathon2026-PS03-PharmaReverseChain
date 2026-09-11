-- ============================================================
--  MediLoop — Demo Seed Data
--  Run AFTER schema.sql in your Supabase SQL editor.
--
--  IMPORTANT: After running this SQL, you must also create
--  the 5 demo users in Supabase Auth → Authentication → Users:
--
--    retailer@demo.com     / Demo@2025
--    distributor@demo.com  / Demo@2025
--    manufacturer@demo.com / Demo@2025
--    facility@demo.com     / Demo@2025
--    admin@demo.com        / Demo@2025
--
--  Then update the UUID references below with the actual Auth UUIDs.
--  OR use the Supabase inviteUserByEmail / signUp approach in a script.
-- ============================================================

-- ────────────────────────────────────────────────────────────
--  ORGANIZATIONS
-- ────────────────────────────────────────────────────────────

insert into organizations (id, name, type, license_number, verification_status) values
  -- Pharmacies
  ('11111111-0000-0000-0000-000000000001', 'MediCare Pharmacy Andheri',      'PHARMACY',      'PH-MH-2024-001', 'VERIFIED'),
  ('11111111-0000-0000-0000-000000000002', 'Apollo Health Pharmacy Bandra',   'PHARMACY',      'PH-MH-2024-002', 'VERIFIED'),
  ('11111111-0000-0000-0000-000000000003', 'Jan Aushadhi Kendra Dadar',        'PHARMACY',      'PH-MH-2024-003', 'VERIFIED'),
  -- Distributors
  ('22222222-0000-0000-0000-000000000001', 'Apex Pharma Distributors',         'DISTRIBUTOR',   'DI-MH-2024-001', 'VERIFIED'),
  ('22222222-0000-0000-0000-000000000002', 'Bharat Med Logistics',             'DISTRIBUTOR',   'DI-MH-2024-002', 'VERIFIED'),
  -- Manufacturers
  ('33333333-0000-0000-0000-000000000001', 'Cipla Ltd',                        'MANUFACTURER',  'MF-IN-2024-001', 'VERIFIED'),
  ('33333333-0000-0000-0000-000000000002', 'Sun Pharmaceutical Industries',    'MANUFACTURER',  'MF-IN-2024-002', 'VERIFIED'),
  -- Waste Facility
  ('44444444-0000-0000-0000-000000000001', 'GreenDispose Waste Solutions',     'WASTE_FACILITY','WF-MH-2024-001', 'VERIFIED'),
  -- Regulator (Admin)
  ('55555555-0000-0000-0000-000000000001', 'CDSCO Regional Office Mumbai',     'REGULATOR',     'RG-IN-2024-001', 'VERIFIED');

-- ────────────────────────────────────────────────────────────
--  MEDICINES
-- ────────────────────────────────────────────────────────────

insert into medicines (id, name, generic_name, manufacturer_id, dosage, strength) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Calpol 500',        'Paracetamol',      '33333333-0000-0000-0000-000000000001', 'Tablet', '500mg'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'Mox 250',           'Amoxicillin',      '33333333-0000-0000-0000-000000000001', 'Capsule', '250mg'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Glycomet 500',      'Metformin',        '33333333-0000-0000-0000-000000000002', 'Tablet', '500mg'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'Augmentin 625',     'Amoxicillin+Clav', '33333333-0000-0000-0000-000000000001', 'Tablet', '625mg'),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'Atorva 20',         'Atorvastatin',     '33333333-0000-0000-0000-000000000002', 'Tablet', '20mg'),
  ('aaaaaaaa-0000-0000-0000-000000000006', 'Pantop 40',         'Pantoprazole',     '33333333-0000-0000-0000-000000000001', 'Tablet', '40mg'),
  ('aaaaaaaa-0000-0000-0000-000000000007', 'Azithral 500',      'Azithromycin',     '33333333-0000-0000-0000-000000000002', 'Tablet', '500mg'),
  ('aaaaaaaa-0000-0000-0000-000000000008', 'Telma 40',          'Telmisartan',      '33333333-0000-0000-0000-000000000001', 'Tablet', '40mg'),
  ('aaaaaaaa-0000-0000-0000-000000000009', 'Cefixime 200',      'Cefixime',         '33333333-0000-0000-0000-000000000002', 'Capsule', '200mg'),
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Dolo 650',          'Paracetamol',      '33333333-0000-0000-0000-000000000002', 'Tablet', '650mg');

-- ────────────────────────────────────────────────────────────
--  MEDICINE BATCHES
-- ────────────────────────────────────────────────────────────

insert into medicine_batches (
  id, medicine_id, batch_number, manufacturing_date, expiry_date,
  original_quantity, current_quantity, status,
  pharmacy_id, distributor_id, manufacturer_id, waste_facility_id
) values

  -- ★ DEMO BATCH: PARA500-2026-001 — fully DESTROYED (for fraud demo climax)
  ('bbbbbbbb-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0000-000000000001', 'PARA500-2026-001',
   '2025-06-01', '2026-03-31',
   100, 0, 'DESTROYED',
   '11111111-0000-0000-0000-000000000001',
   '22222222-0000-0000-0000-000000000001',
   '33333333-0000-0000-0000-000000000001',
   '44444444-0000-0000-0000-000000000001'),

  -- Active batch
  ('bbbbbbbb-0000-0000-0000-000000000002',
   'aaaaaaaa-0000-0000-0000-000000000002', 'AMOX250-2026-003',
   '2025-09-01', '2026-11-30',
   200, 185, 'EXPIRING_SOON',
   '11111111-0000-0000-0000-000000000001',
   null, '33333333-0000-0000-0000-000000000001', null),

  -- Expired, unreturned
  ('bbbbbbbb-0000-0000-0000-000000000003',
   'aaaaaaaa-0000-0000-0000-000000000003', 'MET500-2025-012',
   '2024-07-01', '2025-08-01',
   150, 60, 'EXPIRED',
   '11111111-0000-0000-0000-000000000002',
   null, '33333333-0000-0000-0000-000000000002', null),

  -- Quantity mismatch batch (in transit)
  ('bbbbbbbb-0000-0000-0000-000000000004',
   'aaaaaaaa-0000-0000-0000-000000000004', 'AUGM625-2026-007',
   '2025-03-01', '2027-02-28',
   80, 75, 'COLLECTED',
   '11111111-0000-0000-0000-000000000003',
   '22222222-0000-0000-0000-000000000002',
   '33333333-0000-0000-0000-000000000001', null),

  -- In-progress return
  ('bbbbbbbb-0000-0000-0000-000000000005',
   'aaaaaaaa-0000-0000-0000-000000000005', 'ATOR20-2025-019',
   '2024-12-01', '2026-01-31',
   120, 45, 'RETURN_INITIATED',
   '11111111-0000-0000-0000-000000000001',
   null, '33333333-0000-0000-0000-000000000002', null),

  -- Manufacturer received
  ('bbbbbbbb-0000-0000-0000-000000000006',
   'aaaaaaaa-0000-0000-0000-000000000006', 'PANT40-2025-031',
   '2024-05-01', '2025-06-30',
   300, 290, 'MANUFACTURER_RECEIVED',
   '11111111-0000-0000-0000-000000000002',
   '22222222-0000-0000-0000-000000000001',
   '33333333-0000-0000-0000-000000000001', null),

  -- Sent for destruction
  ('bbbbbbbb-0000-0000-0000-000000000007',
   'aaaaaaaa-0000-0000-0000-000000000007', 'AZIT500-2025-044',
   '2024-01-01', '2025-03-31',
   50, 50, 'SENT_FOR_DESTRUCTION',
   '11111111-0000-0000-0000-000000000003',
   '22222222-0000-0000-0000-000000000002',
   '33333333-0000-0000-0000-000000000002',
   '44444444-0000-0000-0000-000000000001'),

  -- Active normal batch
  ('bbbbbbbb-0000-0000-0000-000000000008',
   'aaaaaaaa-0000-0000-0000-000000000008', 'TELM40-2027-002',
   '2025-01-01', '2027-12-31',
   500, 498, 'ACTIVE',
   '11111111-0000-0000-0000-000000000001',
   null, '33333333-0000-0000-0000-000000000001', null),

  -- Expiring soon
  ('bbbbbbbb-0000-0000-0000-000000000009',
   'aaaaaaaa-0000-0000-0000-000000000009', 'CEF200-2026-011',
   '2025-04-01', '2026-12-15',
   90, 88, 'EXPIRING_SOON',
   '11111111-0000-0000-0000-000000000002',
   null, '33333333-0000-0000-0000-000000000002', null),

  -- Verified by distributor
  ('bbbbbbbb-0000-0000-0000-000000000010',
   'aaaaaaaa-0000-0000-0000-000000000010', 'DOLO650-2025-055',
   '2024-08-01', '2025-09-30',
   200, 195, 'DISTRIBUTOR_VERIFIED',
   '11111111-0000-0000-0000-000000000003',
   '22222222-0000-0000-0000-000000000001',
   '33333333-0000-0000-0000-000000000002', null);

-- ────────────────────────────────────────────────────────────
--  DEMO BATCH EVENTS for PARA500-2026-001
--  Shows the complete lifecycle in the batch detail timeline
-- ────────────────────────────────────────────────────────────
-- NOTE: Replace actor_id values with actual auth user UUIDs after creating demo users

-- These are placeholder hashes; real hashes are computed by the app
insert into batch_events (
  id, batch_id, event_type, actor_id, organization_id,
  quantity, previous_status, new_status, timestamp,
  event_hash, previous_event_hash
) values
  ('cccccccc-0000-0000-0000-000000000001',
   'bbbbbbbb-0000-0000-0000-000000000001',
   'BATCH_CREATED',
   '00000000-0000-0000-0000-000000000001', -- replace with retailer auth UUID
   '33333333-0000-0000-0000-000000000001',
   100, null, 'ACTIVE',
   '2025-06-01T10:00:00Z',
   'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
   null),

  ('cccccccc-0000-0000-0000-000000000002',
   'bbbbbbbb-0000-0000-0000-000000000001',
   'RETURN_INITIATED',
   '00000000-0000-0000-0000-000000000001', -- retailer
   '11111111-0000-0000-0000-000000000001',
   100, 'EXPIRED', 'RETURN_INITIATED',
   '2026-04-05T09:15:00Z',
   'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3',
   'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'),

  ('cccccccc-0000-0000-0000-000000000003',
   'bbbbbbbb-0000-0000-0000-000000000001',
   'PICKUP_COMPLETED',
   '00000000-0000-0000-0000-000000000002', -- distributor
   '22222222-0000-0000-0000-000000000001',
   100, 'IN_TRANSIT', 'COLLECTED',
   '2026-04-07T14:30:00Z',
   'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
   'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3'),

  ('cccccccc-0000-0000-0000-000000000004',
   'bbbbbbbb-0000-0000-0000-000000000001',
   'DISPOSAL_SCHEDULED',
   '00000000-0000-0000-0000-000000000003', -- manufacturer
   '33333333-0000-0000-0000-000000000001',
   100, 'MANUFACTURER_RECEIVED', 'SENT_FOR_DESTRUCTION',
   '2026-04-10T11:00:00Z',
   'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5',
   'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4'),

  ('cccccccc-0000-0000-0000-000000000005',
   'bbbbbbbb-0000-0000-0000-000000000001',
   'DESTRUCTION_RECORDED',
   '00000000-0000-0000-0000-000000000004', -- facility
   '44444444-0000-0000-0000-000000000001',
   100, 'SENT_FOR_DESTRUCTION', 'DESTROYED',
   '2026-04-15T16:45:00Z',
   'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6',
   'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5');

-- ────────────────────────────────────────────────────────────
--  DEMO DISPOSAL RECORD + CERTIFICATE for PARA500-2026-001
-- ────────────────────────────────────────────────────────────

insert into disposal_records (
  id, batch_id, manufacturer_id, waste_facility_id, disposal_method,
  actual_disposal_date, quantity_destroyed, status
) values (
  'dddddddd-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000001',
  '33333333-0000-0000-0000-000000000001',
  '44444444-0000-0000-0000-000000000001',
  'INCINERATION',
  '2026-04-15',
  100,
  'COMPLETED'
);

insert into destruction_certificates (
  id, disposal_record_id, certificate_number, issued_date, hash
) values (
  'eeeeeeee-0000-0000-0000-000000000001',
  'dddddddd-0000-0000-0000-000000000001',
  'CERT-GDS-2026-00431',
  '2026-04-15',
  'f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1'
);

update disposal_records
  set certificate_id = 'eeeeeeee-0000-0000-0000-000000000001'
  where id = 'dddddddd-0000-0000-0000-000000000001';

-- ────────────────────────────────────────────────────────────
--  REVERSE REQUESTS for demo
-- ────────────────────────────────────────────────────────────
-- NOTE: retailer_id must be the actual Auth UUID of retailer@demo.com
-- Placeholder: '00000000-0000-0000-0000-000000000001'

insert into reverse_requests (
  id, batch_id, retailer_id, requested_quantity, reason, status, initiated_at
) values
  ('ffffffff-0000-0000-0000-000000000001',
   'bbbbbbbb-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000001',
   60, 'EXPIRED', 'PENDING',
   now() - interval '2 days'),

  ('ffffffff-0000-0000-0000-000000000002',
   'bbbbbbbb-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000001',
   45, 'EXPIRED', 'ACCEPTED',
   now() - interval '5 days');

-- ────────────────────────────────────────────────────────────
--  NOTE ON CREATING DEMO AUTH USERS
--  After running this SQL, go to:
--  Supabase Dashboard → Authentication → Users → "Invite user"
--  Create each of the 5 demo users with password "Demo@2025".
--
--  Then insert into the users table:
--
--  insert into users (id, name, email, role, organization_id) values
--    ('<retailer-auth-uuid>',     'Priya Sharma',    'retailer@demo.com',     'PHARMACY',      '11111111-0000-0000-0000-000000000001'),
--    ('<distributor-auth-uuid>',  'Rahul Mehta',     'distributor@demo.com',  'DISTRIBUTOR',   '22222222-0000-0000-0000-000000000001'),
--    ('<manufacturer-auth-uuid>', 'Anjali Reddy',    'manufacturer@demo.com', 'MANUFACTURER',  '33333333-0000-0000-0000-000000000001'),
--    ('<facility-auth-uuid>',     'Suresh Pillai',   'facility@demo.com',     'WASTE_FACILITY','44444444-0000-0000-0000-000000000001'),
--    ('<admin-auth-uuid>',        'CDSCO Inspector', 'admin@demo.com',        'REGULATOR',     '55555555-0000-0000-0000-000000000001');
-- ────────────────────────────────────────────────────────────
