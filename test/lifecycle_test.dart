import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/services/batch_lifecycle_service.dart';

void main() {
  group('Batch Lifecycle State Machine Tests', () {
    test('Valid forward transitions with authorized roles', () {
      // Pharmacy returns active/expired batch
      expect(BatchLifecycleService.isValidTransition('ACTIVE', 'RETURN_INITIATED', 'PHARMACY'), isTrue);
      expect(BatchLifecycleService.isValidTransition('EXPIRED', 'RETURN_INITIATED', 'PHARMACY'), isTrue);

      // Distributor pickup and verification
      expect(BatchLifecycleService.isValidTransition('RETURN_INITIATED', 'PICKUP_ASSIGNED', 'DISTRIBUTOR'), isTrue);
      expect(BatchLifecycleService.isValidTransition('PICKUP_ASSIGNED', 'COLLECTED', 'DISTRIBUTOR'), isTrue);
      expect(BatchLifecycleService.isValidTransition('COLLECTED', 'DISTRIBUTOR_VERIFIED', 'DISTRIBUTOR'), isTrue);

      // Manufacturer receiving and disposal scheduling
      expect(BatchLifecycleService.isValidTransition('DISTRIBUTOR_VERIFIED', 'MANUFACTURER_RECEIVED', 'MANUFACTURER'), isTrue);
      expect(BatchLifecycleService.isValidTransition('MANUFACTURER_RECEIVED', 'DISPOSAL_PENDING', 'MANUFACTURER'), isTrue);
      expect(BatchLifecycleService.isValidTransition('DISPOSAL_PENDING', 'SENT_FOR_DESTRUCTION', 'MANUFACTURER'), isTrue);

      // Waste facility destruction
      expect(BatchLifecycleService.isValidTransition('SENT_FOR_DESTRUCTION', 'DESTROYED', 'WASTE_FACILITY'), isTrue);

      // Regulator close
      expect(BatchLifecycleService.isValidTransition('DESTROYED', 'CLOSED', 'REGULATOR'), isTrue);
    });

    test('Rejects transitions with unauthorized roles', () {
      // Pharmacy cannot mark batch as COLLECTED or DESTROYED
      expect(BatchLifecycleService.isValidTransition('RETURN_INITIATED', 'COLLECTED', 'PHARMACY'), isFalse);
      expect(BatchLifecycleService.isValidTransition('SENT_FOR_DESTRUCTION', 'DESTROYED', 'PHARMACY'), isFalse);

      // Distributor cannot schedule disposal
      expect(BatchLifecycleService.isValidTransition('MANUFACTURER_RECEIVED', 'DISPOSAL_PENDING', 'DISTRIBUTOR'), isFalse);

      // Waste facility cannot initiate return
      expect(BatchLifecycleService.isValidTransition('ACTIVE', 'RETURN_INITIATED', 'WASTE_FACILITY'), isFalse);
    });

    test('Rejects invalid transitions and reverse state skips', () {
      // Cannot jump from ACTIVE straight to DESTROYED
      expect(BatchLifecycleService.isValidTransition('ACTIVE', 'DESTROYED', 'WASTE_FACILITY'), isFalse);

      // Cannot re-enter DESTROYED batch back into ACTIVE (CRITICAL FRAUD PREVENTION)
      expect(BatchLifecycleService.isValidTransition('DESTROYED', 'ACTIVE', 'PHARMACY'), isFalse);
      expect(BatchLifecycleService.isValidTransition('DESTROYED', 'ACTIVE', 'MANUFACTURER'), isFalse);
      expect(BatchLifecycleService.isValidTransition('DESTROYED', 'ACTIVE', 'REGULATOR'), isFalse);

      // CLOSED is terminal
      expect(BatchLifecycleService.isValidTransition('CLOSED', 'ACTIVE', 'REGULATOR'), isFalse);
      expect(BatchLifecycleService.isValidTransition('CLOSED', 'DESTROYED', 'REGULATOR'), isFalse);
    });

    test('Provides human-readable transition rejection reasons', () {
      final invalidReason = BatchLifecycleService.getTransitionError('DESTROYED', 'ACTIVE', 'PHARMACY');
      expect(invalidReason, isNotNull);
      expect(invalidReason!.toLowerCase(), contains('invalid transition'));

      final roleReason = BatchLifecycleService.getTransitionError('RETURN_INITIATED', 'PICKUP_ASSIGNED', 'PHARMACY');
      expect(roleReason, isNotNull);
      expect(roleReason!.toLowerCase(), contains('role'));
    });
  });
}
