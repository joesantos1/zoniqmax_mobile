import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zoniqmax/main.dart';

void main() {
  testWidgets('App inicia e renderiza um MaterialApp', (tester) async {
    await tester.pumpWidget(const ZonIQmaxApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
