import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/data/mock_database.dart';
import 'package:mediloop/repositories/reverse_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  group('Distributor 3-Stage Journey Lifecycle Tests', () {
    late ReverseRepository repo;

    setUp(() {
      MockDatabase.instance.reset();
      repo = ReverseRepository(_FakeClient());
    });

    test('Stage 1: Distributor receives assigned pickup and accepts task', () async {
      // Create reverse request and assign pickup
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

      // Distributor queries queue
      final pickups = await repo.getPickupsForDistributor('org-distributor-01');
      expect(pickups.isNotEmpty, isTrue);

      final assignedPickup = pickups.firstWhere((p) => p.reverseRequestId == req.id);
      expect(assignedPickup.pickupStatus, 'ASSIGNED');

      // Distributor accepts task
      await repo.acceptPickupByDistributor(assignedPickup.id);

      final refreshed = await repo.getPickupsForDistributor('org-distributor-01');
      final acceptedPickup = refreshed.firstWhere((p) => p.id == assignedPickup.id);
      expect(acceptedPickup.pickupStatus, 'ACCEPTED');
    });

    test('Stage 2: In-person pharmacy verification & collection', () async {
      final req = MockDatabase.instance.createReverseRequest(
        batchId: 'batch-004',
        retailerId: 'org-retailer-01',
        requestedQuantity: 45,
        reason: 'DAMAGED',
        proofUrl: 'pharmacy_return_proof.jpg',
      );

      await repo.acceptPickup(
        requestId: req.id,
        distributorId: 'org-distributor-01',
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
      );

      final pickups = await repo.getPickupsForDistributor('org-distributor-01');
      final targetPickup = pickups.firstWhere((p) => p.reverseRequestId == req.id);

      await repo.acceptPickupByDistributor(targetPickup.id);

      // Counter collection with actual physical quantity and verification photo
      await repo.collectPickupAtPharmacy(
        pickupId: targetPickup.id,
        actualQuantity: 45,
        proofUrl: 'distributor_verified_photo.jpg',
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
      );

      final updatedPickups = await repo.getPickupsForDistributor('org-distributor-01');
      final collectedPickup = updatedPickups.firstWhere((p) => p.id == targetPickup.id);
      expect(collectedPickup.pickupStatus, 'COLLECTED');
      expect(collectedPickup.actualQuantity, 45);
      expect(collectedPickup.pickupProofUrl, 'distributor_verified_photo.jpg');

      // Batch status is updated to COLLECTED
      final batch = MockDatabase.instance.getBatchById('batch-004');
      expect(batch?.status, 'COLLECTED');
    });

    test('Stage 3: Manufacturer gate handover via 6-digit OTP verification', () async {
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

      // Attempt with wrong OTP must fail
      final wrongResult = await repo.completeHandoverWithOtp(
        pickupId: target.id,
        otp: '000000',
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
      );
      expect(wrongResult, isFalse);

      // Attempt with correct OTP must succeed
      final rightResult = await repo.completeHandoverWithOtp(
        pickupId: target.id,
        otp: expectedOtp,
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
      );
      expect(rightResult, isTrue);

      // Verify final states
      final finalPickups = await repo.getPickupsForDistributor('org-distributor-01');
      final finishedPickup = finalPickups.firstWhere((p) => p.id == target.id);
      expect(finishedPickup.pickupStatus, 'COMPLETED');

      final batch = MockDatabase.instance.getBatchById('batch-004');
      expect(batch?.status, 'MANUFACTURER_RECEIVED');
    });

    test('Demo Gate OTP bypass allows 123456 for effortless evaluator walkthrough', () async {
      final pickups = await repo.getPickupsForDistributor('org-distributor-01');
      final p = pickups.first;

      final result = await repo.completeHandoverWithOtp(
        pickupId: p.id,
        otp: '123456',
        actorId: 'usr-distributor-01',
        orgId: 'org-distributor-01',
      );
      expect(result, isTrue);
    });
  });
}
