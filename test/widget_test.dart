import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inc09/main.dart';

void main() {
  testWidgets('Card catalog loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CardCatalogApp());

    expect(find.text('Folders'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
