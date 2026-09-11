import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/data/mock_database.dart';
import 'package:mediloop/repositories/reverse_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  group('Manufacturer Gate OTP Verification Tests', () {
    late ReverseRepository repo;

    setUp(() {
      MockDatabase.instance.reset();
      repo = ReverseRepository(_FakeClient());
    });

    test('Displayed Plant Gate OTP (same one shown on screen) is accepted and completes handover', () async {
      final req = MockDatabase.instance.createReverseRequest(
        batchId: 'batch-004',
        retailerId: 'org-retailer-01',
        requestedQuantity: 50,
        reason: 'EXPIRED',
      );

      await repo.acceptPickup(
        requestId: req.id,
        distributorId: 'org-distributor-01',
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      );

      final pickups = await repo.getPickupsForDistributor('org-distributor-01');
      final target = pickups.firstWhere((p) => p.reverseRequestId == req.id);

      await repo.acceptPickupByDistributor(target.id);
      await repo.collectPickupAtPharmacy(
        pickupId: target.id,
        actualQuantity: 50,
      );

      final expectedOtp = target.expectedOtp;
      expect(expectedOtp.length, 6);

      // Verify that using the exact expectedOtp succeeds
      final success = await repo.completeHandoverWithOtp(
        pickupId: target.id,
        otp: expectedOtp,
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
        expectedOtp: expectedOtp,
      );
      expect(success, isTrue);

      // Verify batch status transitioned to MANUFACTURER_RECEIVED
      final batch = MockDatabase.instance.getBatchById('batch-004');
      expect(batch?.status, 'MANUFACTURER_RECEIVED');
    });

    test('Arbitrary UUID pickups from Supabase accept the displayed expectedOtp', () async {
      final foreignPickupId = '0612e6b5-796a-43c5-bcd5-022ecbb158a1';
      final displayedOtp = '905066';

      final success = await repo.completeHandoverWithOtp(
        pickupId: foreignPickupId,
        otp: displayedOtp,
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
        expectedOtp: displayedOtp,
      );
      expect(success, isTrue);
    });

    test('Demo bypass OTP 123456 always succeeds', () async {
      final foreignPickupId = '79a46096-0226-4027-b019-d4da61a18532';

      final success = await repo.completeHandoverWithOtp(
        pickupId: foreignPickupId,
        otp: '123456',
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
      );
      expect(success, isTrue);
    });

    test('Wrong OTP like 000000 fails', () async {
      final foreignPickupId = '79a46096-0226-4027-b019-d4da61a18532';

      final success = await repo.completeHandoverWithOtp(
        pickupId: foreignPickupId,
        otp: '000000',
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
        expectedOtp: '905066',
      );
      expect(success, isFalse);
    });
  });
}
