import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'theme.dart';
import 'onboarding_api.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.api});

  final OnboardingApi api;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _document = TextEditingController();
  final _legalName = TextEditingController();
  final _academy = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _display = TextEditingController();
  final _welcome = TextEditingController();
  final _code = TextEditingController();
  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  final _payloadDate = DateFormat('yyyy-MM-dd');
  final _modalities = {'JUDO'};
  DateTime _due = _billingToday();
  String _documentType = 'CNPJ';
  String _period = 'MONTHLY';
  String _payment = 'PIX';
  Color _color = cactusAcid;
  Uint8List? _logo;
  String? _logoType;
  bool _authorized = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  Registration? _registration;
  int _step = 0;
  final String _registrationId = _uuid();

  bool get _yearly => _period == 'YEARLY';
  String get _displayName => _display.text.trim().isEmpty
      ? _academy.text.trim()
      : _display.text.trim();
  String get _price => _money.format(_yearly ? 324 : 30);

  static DateTime _billingToday() {
    final t = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return DateTime(t.year, t.month, t.day);
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    for (final controller in [
      _document,
      _legalName,
      _academy,
      _owner,
      _email,
      _phone,
      _password,
      _display,
      _welcome,
      _code,
    ]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _changeDueDate() async {
    final today = _billingToday();
    final selected = await showDatePicker(
      context: context,
      initialDate: _due.isBefore(today) ? today : _due,
      firstDate: today,
      lastDate: DateTime(today.year, today.month, today.day + 30),
    );
    if (mounted && selected != null) setState(() => _due = selected);
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.length > 2 * 1024 * 1024) {
        setState(() => _error = 'Escolha uma imagem PNG ou JPEG de até 2 MB.');
        return;
      }
      setState(() {
        _logo = bytes;
        _logoType = file.extension?.toLowerCase() == 'png' ? 'png' : 'jpeg';
        _error = null;
      });
    } on PlatformException {
      if (mounted) setState(() => _error = 'Não foi possível abrir a galeria.');
    }
  }

  Future<void> _chooseCustomColor() async {
    String hex = _colorHex(_color);
    final value = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cor personalizada'),
        content: TextFormField(
          initialValue: hex,
          decoration: const InputDecoration(
            labelText: 'Código hexadecimal',
            hintText: '#D7FA58',
          ),
          onChanged: (value) => hex = value.trim(),
          inputFormatters: [LengthLimitingTextInputFormatter(7)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final digits = hex.replaceFirst('#', '');
              if (!RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(digits)) return;
              Navigator.pop(
                context,
                Color(0xff000000 | int.parse(digits, radix: 16)),
              );
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (mounted && value != null) setState(() => _color = value);
  }

  String _colorHex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Future<void> _next() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if (_step == 2 && _modalities.isEmpty) {
      setState(() => _error = 'Escolha pelo menos uma modalidade.');
      return;
    }
    if (_step < 3) {
      _go(_step + 1);
      return;
    }
    if (_step == 3 && !_authorized) {
      setState(
        () => _error =
            'Confirme os dados e autorize a assinatura para continuar.',
      );
      return;
    }
    if (_step == 3) {
      await _submit(() async {
        final response = await widget.api.register({
          'registrationId': _registrationId,
          'documentType': _documentType,
          'document': _document.text.trim(),
          'legalName': _legalName.text.trim(),
          'academyName': _academy.text.trim(),
          'ownerName': _owner.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
          'billingPeriod': _period,
          'paymentMethod': _payment,
          'firstDueDate': _payloadDate.format(_due),
          'displayName': _displayName,
          'primaryColor': _colorHex(_color),
          'welcomeMessage': _welcome.text.trim(),
          'modalities': _modalities.toList(),
          'logo': _logo == null
              ? null
              : 'data:image/$_logoType;base64,${base64Encode(_logo!)}',
          'billingAuthorized': true,
        });
        if (!mounted) return;
        _registration = response;
        _password.clear();
        _go(response.emailVerified ? 5 : 4);
        if (response.delivery == 'FAILED') {
          setState(
            () => _error =
                'O cadastro foi salvo. Peça um novo código para confirmar o e-mail.',
          );
        }
      });
      return;
    }
    if (_step == 4) {
      await _submit(() async {
        final response = await widget.api.verify(_registration!.id, _code.text);
        if (!mounted) return;
        _registration = response;
        _code.clear();
        _go(5);
      });
    }
  }

  Future<void> _resend() async {
    await _submit(() async {
      final response = await widget.api.resend(_registration!.id);
      if (!mounted) return;
      if (response.emailVerified) {
        _registration = response;
        _go(5);
        return;
      }
      if (response.delivery == 'FAILED') {
        setState(
          () => _error =
              'O e-mail não saiu. Aguarde um minuto e tente novamente.',
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enviamos um novo código.')));
    });
  }

  Future<void> _submit(Future<void> Function() request) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await request();
    } on OnboardingException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on FormatException {
      if (mounted) {
        setState(() => _error = 'A API retornou uma resposta inválida.');
      }
    } on TypeError {
      if (mounted) {
        setState(() => _error = 'A API retornou uma resposta inválida.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                const _BrandHeader(),
                const SizedBox(height: 20),
                if (_step <= 3) _progress(context),
                const SizedBox(height: 20),
                Form(
                  key: _form,
                  child: AbsorbPointer(
                    absorbing: _busy,
                    child: switch (_step) {
                      0 => _academyStep(),
                      1 => _planStep(),
                      2 => _brandingStep(),
                      3 => _summaryStep(),
                      4 => _verifyStep(),
                      _ => _doneStep(),
                    },
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (_step < 5) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (_step > 0 && _step < 4) ...[
                        OutlinedButton(
                          onPressed: _busy ? null : () => _go(_step - 1),
                          child: const Text('Voltar'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _next,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  [
                                    'Continuar',
                                    'Continuar',
                                    'Revisar assinatura',
                                    'Criar academia',
                                    'Confirmar e-mail',
                                  ][_step],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progress(BuildContext context) {
    return Row(
      children: ['Academia', 'Plano', 'Marca', 'Resumo'].indexed.map((entry) {
        final (index, label) = entry;
        final selected = index == _step;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: index <= _step
                        ? cactusAcid
                        : Theme.of(context).dividerColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? cactusAcid : null,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _academyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading(
        'Cadastre sua academia',
        'Informe os dados da academia e crie a conta do responsável.',
      ),
      const _Section('Dados da academia'),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'CNPJ', label: Text('CNPJ')),
          ButtonSegment(value: 'CPF', label: Text('CPF')),
        ],
        selected: {_documentType},
        onSelectionChanged: (value) => setState(() {
          _documentType = value.single;
          _document.clear();
        }),
      ),
      const SizedBox(height: 12),
      _field(
        _document,
        _documentType,
        max: _documentType == 'CPF' ? 14 : 18,
        hint: _documentType == 'CPF' ? '000.000.000-00' : '00.000.000/0000-00',
        keyboard: _documentType == 'CPF'
            ? TextInputType.number
            : TextInputType.text,
        formatters: [_DocumentFormatter(_documentType == 'CPF')],
        validator: (value) {
          final normalized = (value ?? '').replaceAll(RegExp(r'[./\s-]'), '');
          final pattern = _documentType == 'CPF'
              ? r'^\d{11}$'
              : r'^[0-9A-Z]{12}\d{2}$';
          return RegExp(pattern).hasMatch(normalized)
              ? null
              : 'Informe um $_documentType completo.';
        },
      ),
      _field(
        _legalName,
        _documentType == 'CPF' ? 'Nome do titular' : 'Razão social',
        max: 100,
      ),
      _field(_academy, 'Nome da academia', hint: 'Ex.: Judô Tigre', max: 48),
      const Divider(),
      const _Section('Responsável pela conta'),
      _field(_owner, 'Nome completo', max: 100),
      _field(
        _email,
        'E-mail',
        max: 120,
        keyboard: TextInputType.emailAddress,
        validator: (value) =>
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((value ?? '').trim())
            ? null
            : 'Informe um e-mail válido.',
      ),
      _field(
        _phone,
        'WhatsApp com DDD',
        hint: '(85) 90000-0000',
        max: 20,
        keyboard: TextInputType.phone,
        validator: (value) =>
            RegExp(
              r'^[1-9]\d{9,10}$',
            ).hasMatch((value ?? '').replaceAll(RegExp(r'\D'), ''))
            ? null
            : 'Informe o telefone com DDD.',
      ),
      _field(
        _password,
        'Senha',
        hint: 'Pelo menos 10 caracteres',
        max: 72,
        obscure: !_showPassword,
        suffix: IconButton(
          tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
          onPressed: () => setState(() => _showPassword = !_showPassword),
          icon: Icon(
            _showPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
        validator: (value) {
          final password = value ?? '';
          if (password.trim().length < 10) {
            return 'Use pelo menos 10 caracteres.';
          }
          if (utf8.encode(password).length > 72) {
            return 'Use uma senha mais curta.';
          }
          return null;
        },
      ),
      const _Note(
        icon: Icons.mark_email_read_outlined,
        text: 'Você vai receber um código de confirmação por e-mail.',
      ),
    ],
  );

  Widget _planStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading(
        'Escolha seu plano',
        'Defina o vencimento e a forma de pagamento da assinatura.',
      ),
      const _Section('Periodicidade'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _option(
              'Mensal',
              _period == 'MONTHLY',
              () => setState(() => _period = 'MONTHLY'),
              subtitle: 'R\$ 30,00 por mês',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _option(
              'Anual',
              _period == 'YEARLY',
              () => setState(() => _period = 'YEARLY'),
              subtitle: 'R\$ 324,00 por ano\nEconomize R\$ 36,00 (10%)',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        title: const Text('Vencimento da primeira fatura'),
        subtitle: Text(_date.format(_due)),
        trailing: const Icon(Icons.event_outlined),
        onTap: _changeDueDate,
      ),
      const SizedBox(height: 12),
      const _Section('Forma de pagamento'),
      Row(
        children: [
          Expanded(
            child: _option(
              'Pix',
              _payment == 'PIX',
              () => setState(() => _payment = 'PIX'),
              icon: Icons.qr_code,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _option(
              'Cartão',
              _payment == 'CARD',
              () => setState(() => _payment = 'CARD'),
              icon: Icons.credit_card,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _brandingStep() {
    final color = _color.computeLuminance() > .179
        ? Colors.black
        : Colors.white;
    final initial = _displayName.isEmpty
        ? 'A'
        : _displayName.substring(0, 1).toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Personalize seu app',
          'Veja como a academia vai aparecer para seus alunos.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xff282d3e),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _color,
                    foregroundColor: color,
                    child: _logo == null
                        ? Text(initial)
                        : ClipOval(
                            child: Image.memory(
                              _logo!,
                              fit: BoxFit.contain,
                              width: 34,
                              height: 34,
                              errorBuilder: (_, _, _) => Text(initial),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const Text('Área do aluno'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Agenda   ·   Mensalidades'),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _welcome.text.trim().isEmpty
                      ? 'Boas-vindas à academia!'
                      : _welcome.text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _field(
          _display,
          'Nome exibido no app',
          hint: 'Usar nome da academia',
          max: 48,
          requiredField: false,
          onChanged: (_) => setState(() {}),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Enviar logotipo'),
              ),
            ),
            if (_logo != null)
              TextButton(
                onPressed: () => setState(() {
                  _logo = null;
                  _logoType = null;
                }),
                child: const Text('Remover'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _Section('Cor principal'),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final (label, shade) in const [
              ('Lima', cactusAcid),
              ('Azul', Color(0xff76d7fa)),
              ('Lilás', Color(0xffbbaaff)),
              ('Laranja', Color(0xffffba7c)),
            ])
              Semantics(
                selected: _color == shade,
                child: IconButton.filled(
                  tooltip: label,
                  style: IconButton.styleFrom(
                    backgroundColor: shade,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => setState(() => _color = shade),
                  icon: Icon(
                    _color == shade ? Icons.check : Icons.circle,
                    size: _color == shade ? 18 : 4,
                  ),
                ),
              ),
            TextButton(
              onPressed: _chooseCustomColor,
              child: const Text('Outra cor'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Section('Modalidades iniciais'),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            for (final (key, label) in const [
              ('JUDO', 'Judô'),
              ('JIUJITSU', 'Jiu-jitsu'),
              ('MUAY_THAI', 'Muay Thai'),
            ])
              FilterChip(
                label: Text(label),
                selected: _modalities.contains(key),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _modalities.add(key);
                  } else {
                    _modalities.remove(key);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _field(
          _welcome,
          'Mensagem de boas-vindas',
          max: 72,
          requiredField: false,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _summaryStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading(
        'Revise a assinatura',
        'Confira os dados da academia e o valor escolhido.',
      ),
      _line('Academia', _academy.text.trim()),
      _line(
        _documentType,
        _document.text.replaceAll(
          RegExp(r'[A-Z0-9](?=(?:[^A-Z0-9]*[A-Z0-9]){4})'),
          '•',
        ),
      ),
      _line('Responsável', _owner.text.trim()),
      _line('E-mail', _email.text.trim()),
      _line('Plano', _yearly ? 'Anual · 10% de desconto' : 'Mensal'),
      _line('Vencimento', _date.format(_due)),
      _line('Pagamento', _payment == 'PIX' ? 'Pix' : 'Cartão'),
      _line('Total da primeira fatura', _price, accent: true),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'Confirmo os dados e autorizo a assinatura escolhida.',
        ),
        value: _authorized,
        onChanged: (checked) => setState(() => _authorized = checked ?? false),
      ),
    ],
  );

  Widget _verifyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Heading(
        'Confirme seu e-mail',
        'Digite o código de 8 dígitos enviado para ${_registration!.email}.',
      ),
      _field(
        _code,
        'Código de confirmação',
        max: 8,
        keyboard: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (value) =>
            (value?.length ?? 0) == 8 ? null : 'Informe os 8 dígitos.',
      ),
      TextButton(
        onPressed: _busy ? null : _resend,
        child: const Text('Enviar novo código'),
      ),
    ],
  );

  Widget _doneStep() {
    final registration = _registration!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: cactusAcid, size: 40),
        const SizedBox(height: 10),
        _Heading(
          'Academia cadastrada',
          'O e-mail do responsável por ${registration.name} foi confirmado.',
        ),
        _line('Situação da assinatura', 'Aguardando cobrança'),
        _line(
          'Valor escolhido',
          _money.format(registration.amountCents / 100),
          accent: true,
        ),
        _line('Primeiro vencimento', _date.format(registration.firstDueDate)),
        const SizedBox(height: 12),
        const _Note(
          icon: Icons.info_outline,
          text: 'Nenhum pagamento foi cobrado nesta versão.',
        ),
      ],
    );
  }

  Widget _option(
    String label,
    bool selected,
    VoidCallback onTap, {
    String? subtitle,
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(47),
          side: BorderSide(
            color: selected ? cactusAcid : Theme.of(context).dividerColor,
          ),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: selected
              ? const Color(0xff282f24)
              : const Color(0xff202231),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool accent = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accent ? cactusAcid : null,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int? max,
    bool obscure = false,
    bool requiredField = true,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      key: ValueKey(label),
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLength: max,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        suffixIcon: suffix,
      ),
      validator:
          validator ??
          (requiredField
              ? (value) => value == null || value.trim().isEmpty
                    ? 'Campo obrigatório.'
                    : null
              : null),
    ),
  );
}

class _DocumentFormatter extends TextInputFormatter {
  _DocumentFormatter(this.cpf);

  final bool cpf;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final cleaned = newValue.text.toUpperCase().replaceAll(
      RegExp(cpf ? r'[^0-9]' : r'[^0-9A-Z]'),
      '',
    );
    final oldCleaned = oldValue.text.replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (newValue.text.length < oldValue.text.length &&
        cleaned == oldCleaned &&
        cleaned.isNotEmpty) {
      final formatted = _mask(cleaned.substring(0, cleaned.length - 1));
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    final formatted = _mask(cleaned);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _mask(String cleaned) {
    final sizes = cpf ? [3, 3, 3, 2] : [2, 3, 3, 4, 2];
    final separators = cpf ? ['.', '.', '-'] : ['.', '.', '/', '-'];
    final parts = StringBuffer();
    var index = 0;
    for (var part = 0; part < sizes.length && index < cleaned.length; part++) {
      if (part > 0) parts.write(separators[part - 1]);
      final end = min(index + sizes[part], cleaned.length);
      parts.write(cleaned.substring(index, end));
      index = end;
    }
    return parts.toString();
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cactusAcid,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bolt, color: Color(0xff1c250b), size: 22),
        ),
        const SizedBox(width: 8),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
            children: [
              TextSpan(text: 'cactus'),
              TextSpan(
                text: 'fight',
                style: TextStyle(color: cactusAcid),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: cactusAcid, size: 17),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
