import 'package:calendar_check/core/models.dart';
import 'package:calendar_check/widgets/month_calendar.dart';
import 'package:calendar_check/widgets/tally_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  Widget wrap(Widget child) => testApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('TallyMarks sin marcas muestra texto', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TallyMarks(
          tally: Tally(total: 0, groups: 0, remainder: 0),
          color: Colors.blue,
        ),
      ),
    );
    expect(find.text('Sin marcas'), findsOneWidget);
  });

  testWidgets('TallyMarks dibuja y envuelve en varias filas si no cabe', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 100,
          child: TallyMarks(
            tally: Tally(total: 47, groups: 9, remainder: 2),
            color: Colors.blue,
          ),
        ),
      ),
    );
    final paint = tester.getSize(
      find
          .descendant(
            of: find.byType(TallyMarks),
            matching: find.byType(CustomPaint),
          )
          .last,
    );
    expect(paint.width, lessThanOrEqualTo(100));
    expect(paint.height, greaterThan(28)); // más de una fila
    expect(find.bySemanticsLabel('47 marcas'), findsOneWidget);
  });

  testWidgets('MonthCalendar: tocar un día avisa con su estado actual', (
    tester,
  ) async {
    DateTime? tapped;
    LogStatus? current = LogStatus.partial;
    await tester.pumpWidget(
      wrap(
        MonthCalendar(
          month: DateTime(2020, 2, 10), // mes pasado: ningún día es futuro
          color: Colors.green,
          logs: {'2020-02-14': LogStatus.done},
          onDayTap: (d, s) {
            tapped = d;
            current = s;
          },
        ),
      ),
    );

    expect(find.text('29'), findsOneWidget); // 2020 es bisiesto
    expect(find.text('30'), findsNothing);
    // El día 14 se ve como cumplido para lectores de pantalla.
    expect(find.bySemanticsLabel(RegExp('14.*cumplido')), findsOneWidget);

    await tester.tap(find.text('14'));
    expect(tapped, DateTime(2020, 2, 14));
    expect(current, LogStatus.done);

    await tester.tap(find.text('3'));
    expect(current, isNull);
  });

  testWidgets('MonthCalendar: los días futuros no responden', (tester) async {
    var taps = 0;
    final next = DateTime(DateTime.now().year + 1, 1, 1);
    await tester.pumpWidget(
      wrap(
        MonthCalendar(
          month: next,
          color: Colors.green,
          logs: const {},
          onDayTap: (_, _) => taps++,
        ),
      ),
    );
    await tester.tap(find.text('15'));
    expect(taps, 0);
  });
}
