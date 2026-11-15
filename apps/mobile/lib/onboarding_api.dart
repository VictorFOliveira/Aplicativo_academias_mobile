import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class OnboardingApi {
  OnboardingApi(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Registration> register(Map<String, Object?> data) async {
    final body = await _post('', data);
    return Registration.fromJson(
      body['registration'] as Map<String, dynamic>,
      delivery: body['emailDelivery'] as String,
    );
  }

  Future<Registration> resend(String id) async {
    final body = await _post('/$id/resend', {});
    return Registration.fromJson(
      body['registration'] as Map<String, dynamic>,
      delivery: body['emailDelivery'] as String,
    );
  }

  Future<Registration> verify(String id, String code) async {
    return Registration.fromJson(await _post('/$id/verify', {'code': code}));
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> data,
  ) async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/onboarding$path',
    );
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' && _isLocal(uri.host))) {
      throw const OnboardingException('invalid_api_url');
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 25));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const OnboardingException('invalid_response');
      }
      if (response.statusCode >= 400) {
        final code = decoded['error'];
        throw OnboardingException(code is String ? code : 'invalid_response');
      }
      return decoded;
    } on TimeoutException {
      throw const OnboardingException('network_error');
    } on http.ClientException {
      throw const OnboardingException('network_error');
    } on FormatException {
      throw const OnboardingException('invalid_response');
    }
  }

  bool _isLocal(String host) =>
      const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(host);

  void close() => _client.close();
}

class Registration {
  const Registration({
    required this.id,
    required this.name,
    required this.email,
    required this.amountCents,
    required this.firstDueDate,
    required this.emailVerified,
    required this.delivery,
  });

  factory Registration.fromJson(
    Map<String, dynamic> value, {
    String? delivery,
  }) {
    return Registration(
      id: value['registrationId'] as String,
      name: value['academyName'] as String,
      email: value['email'] as String,
      amountCents: value['amountCents'] as int,
      firstDueDate: DateTime.parse(value['firstDueDate'] as String),
      emailVerified: value['emailVerified'] as bool,
      delivery: delivery,
    );
  }

  final String id;
  final String name;
  final String email;
  final int amountCents;
  final DateTime firstDueDate;
  final bool emailVerified;
  final String? delivery;
}

class OnboardingException implements Exception {
  const OnboardingException(this.code);

  final String code;

  String get message => switch (code) {
    'invalid_document' => 'Confira os dígitos do CPF ou CNPJ.',
    'invalid_phone' => 'Informe um WhatsApp válido com DDD.',
    'invalid_due_date' => 'Escolha um vencimento nos próximos 30 dias.',
    'invalid_logo' =>
      'Use um logo em PNG ou JPEG de até 2 MB e 2.400 px por lado.',
    'password_too_long' => 'Use uma senha mais curta e tente novamente.',
    'invalid_or_expired_code' =>
      'Código inválido ou expirado. Confira o e-mail ou peça um novo código.',
    'resend_wait' => 'Aguarde um minuto antes de pedir outro código.',
    'rate_limited' => 'Muitas tentativas. Aguarde um minuto.',
    'registration_conflict' =>
      'Este cadastro já foi iniciado. Use o e-mail informado no primeiro envio.',
    'registration_not_found' => 'Cadastro não localizado.',
    'email_service_unavailable' =>
      'O serviço de e-mail está indisponível. Tente novamente em instantes.',
    'invalid_api_url' => 'O endereço da API precisa usar HTTPS.',
    'network_error' =>
      'A conexão demorou ou caiu. Tente novamente para recuperar o envio.',
    _ => 'Não foi possível concluir agora. Tente novamente.',
  };
}
