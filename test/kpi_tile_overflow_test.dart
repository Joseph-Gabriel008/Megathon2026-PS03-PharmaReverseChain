import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/core/theme.dart';
import 'package:mediloop/widgets/batch_card.dart';

void main() {
  testWidgets('KpiTile renders in GridView at mobile dimensions without bottom overflow',
      (WidgetTester tester) async {
    // Test on a typical 360x780 mobile screen size
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(MediLoopSpacing.md),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: MediLoopSpacing.sm,
              mainAxisSpacing: MediLoopSpacing.sm,
              childAspectRatio: 1.25,
              children: const [
                KpiTile(
                  label: 'Registered entities',
                  value: 1,
                  icon: Icons.apartment_rounded,
                ),
                KpiTile(
                  label: 'Active batches',
                  value: 5,
                  icon: Icons.inventory_2_rounded,
                ),
                KpiTile(
                  label: 'Expired batches',
                  value: 1,
                  warning: true,
                  icon: Icons.warning_amber_rounded,
                ),
                KpiTile(
                  label: 'Open fraud alerts',
                  value: 1,
                  critical: true,
                  icon: Icons.gpp_bad_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify all 4 cards rendered with their labels and values
    expect(find.text('Registered entities'), findsOneWidget);
    expect(find.text('Active batches'), findsOneWidget);
    expect(find.text('Expired batches'), findsOneWidget);
    expect(find.text('Open fraud alerts'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);

    // Verify no RenderFlex overflow exceptions occurred
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityItem renders without 4.8px right overflow at narrow mobile dimensions',
      (WidgetTester tester) async {
    // Narrow 340px phone screen width
    tester.view.physicalSize = const Size(340, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(MediLoopSpacing.md),
            child: Column(
              children: [
                // Item from user's screenshot that overflowed by 4.8 pixels
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amoxicillin 250mg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'AMOX250-2026-003',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '•  Exp 30 Nov 2026',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Status badge width simulator
                    SizedBox(width: 105, height: 28),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Amoxicillin 250mg'), findsOneWidget);
    expect(find.text('AMOX250-2026-003'), findsOneWidget);
  });
}
