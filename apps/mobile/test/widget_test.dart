import 'dart:convert';

import 'package:cactus_fight/main.dart';
import 'package:cactus_fight/onboarding_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('cadastra academia, escolhe plano anual e confirma o e-mail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final receipt = <String, Object?>{};
    final api = OnboardingApi(
      'https://fight.example.com',
      client: MockClient((request) async {
        final body =
            jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
        if (request.url.path == '/api/onboarding') {
          expect(body['document'], '11.222.333/0001-81');
          expect(body['billingPeriod'], 'YEARLY');
          expect(body['paymentMethod'], 'CARD');
          expect(body['displayName'], 'Judô Tigre Kids');
          expect(body['primaryColor'], '#76D7FA');
          expect(body['billingAuthorized'], true);
          receipt.addAll({
            'registrationId': body['registrationId'],
            'academyName': body['academyName'],
            'email': body['email'],
            'amountCents': 32400,
            'firstDueDate': body['firstDueDate'],
            'emailVerified': false,
          });
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'registration': receipt, 'emailDelivery': 'SENT'}),
            ),
            202,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          );
        }
        expect(
          request.url.path,
          '/api/onboarding/${receipt['registrationId']}/verify',
        );
        expect(body['code'], '12345678');
        return http.Response.bytes(
          utf8.encode(jsonEncode({...receipt, 'emailVerified': true})),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(CactusFightApp(api: api));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String value) async {
      final finder = find.byKey(ValueKey(label));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
      await tester.pumpAndSettle();
    }

    await enter('CNPJ', '11222333000181');
    await enter('Razão social', 'Academia Tigre Ltda.');
    await enter('Nome da academia', 'Judô Tigre');
    await enter('Nome completo', 'Marina Alves');
    await enter('E-mail', 'marina@example.com');
    await enter('WhatsApp com DDD', '85900000000');
    await enter('Senha', 'uma-senha-de-teste');
    await tap(find.text('Continuar'));
    await tap(find.text('Anual'));
    await tap(find.text('Cartão'));
    await tap(find.text('Continuar'));
    await enter('Nome exibido no app', 'Judô Tigre Kids');
    await tap(find.byTooltip('Azul'));
    await tap(find.text('Revisar assinatura'));
    expect(find.textContaining('324,00'), findsOneWidget);
    await tap(find.byType(Checkbox));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
    await tap(find.text('Criar academia'));
    expect(
      find.text('Confirme seu e-mail'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .join(' | '),
    );
    await enter('Código de confirmação', '12345678');
    await tap(find.text('Confirmar e-mail'));
    expect(find.text('Academia cadastrada'), findsOneWidget);
    expect(find.text('Aguardando cobrança'), findsOneWidget);
  });
}
