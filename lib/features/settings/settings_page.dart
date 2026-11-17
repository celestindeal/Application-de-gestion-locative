import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/form_fields.dart';
import '../../core/format.dart';
import '../../core/platform/file_io.dart';
import '../../core/widgets.dart';
import '../../data/backup_service.dart';
import '../../data/providers.dart';
import '../../models/landlord_settings.dart';
import '../../services/gmail_service.dart';
import '../../services/mime_message.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    properties: ref.watch(propertyRepositoryProvider),
    tenants: ref.watch(tenantRepositoryProvider),
    leases: ref.watch(leaseRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  ),
);

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _email = TextEditingController();
  final _signatureCity = TextEditingController();
  final _clientId = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _copyToSelf = true;
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(settingsRepositoryProvider).get();
    _name.text = s.name;
    _address.text = s.address;
    _postalCode.text = s.postalCode;
    _city.text = s.city;
    _email.text = s.email;
    _signatureCity.text = s.signatureCity;
    _clientId.text = s.googleClientId;
    _subject.text = s.emailSubject;
    _body.text = s.emailBody;
    _copyToSelf = s.sendCopyToSelf;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _postalCode,
      _city,
      _email,
      _signatureCity,
      _clientId,
      _subject,
      _body,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<LandlordSettings?> _save({bool quiet = false}) async {
    if (!_form.currentState!.validate()) return null;
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.get();
    final clientIdChanged =
        current.googleClientId.trim() != _clientId.text.trim();
    final updated = current.copyWith(
      name: _name.text.trim(),
      address: _address.text.trim(),
      postalCode: _postalCode.text.trim(),
      city: _city.text.trim(),
      email: _email.text.trim(),
      signatureCity: _signatureCity.text.trim(),
      googleClientId: _clientId.text.trim(),
      sendCopyToSelf: _copyToSelf,
      emailSubject: _subject.text.trim().isEmpty
          ? LandlordSettings.defaultSubject
          : _subject.text.trim(),
      emailBody: _body.text.trim().isEmpty
          ? LandlordSettings.defaultBody
          : _body.text,
      clearToken: clientIdChanged,
    );
    await repo.save(updated);
    if (clientIdChanged && updated.isGmailConfigured) {
      try {
        await ref.read(gmailServiceProvider).init(updated.googleClientId);
      } on GmailException catch (e) {
        if (mounted) showMessage(context, e.message, error: true);
      }
    }
    setState(() => _dirty = false);
    if (mounted && !quiet) showMessage(context, 'Paramètres enregistrés');
    return updated;
  }

  /// Envoie un mail de test au bailleur lui-même.
  Future<void> _testEmail() async {
    final s = ref.read(settingsProvider).value ?? const LandlordSettings();
    if (_dirty || !s.isGmailConfigured) {
      showMessage(
        context,
        'Enregistrez d\'abord l\'identifiant client Google.',
        error: true,
      );
      return;
    }
    if (s.email.isEmpty) {
      showMessage(context, 'Renseignez votre adresse Gmail.', error: true);
      return;
    }
    final gmail = ref.read(gmailServiceProvider);
    try {
      final token = await gmail.accessToken(current: s, forcePrompt: true);
      await gmail.send(
        MimeMessage(
          to: [s.email],
          subject: 'Test - Gestion locative',
          body:
              'Ce mail de test confirme que l\'envoi des quittances depuis '
              'votre compte Gmail fonctionne.',
        ),
        token: token,
      );
      if (mounted) showMessage(context, 'Mail de test envoyé à ${s.email}');
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _export() async {
    final json = await ref.read(backupServiceProvider).exportJson();
    final name =
        'gestion-locative-sauvegarde-${Dates.isoDate(DateTime.now())}.json';
    await FileIO.saveOrShare(
      Uint8List.fromList(utf8.encode(json)),
      name,
      'application/json',
    );
  }

  Future<void> _import() async {
    final content = await FileIO.pickTextFile();
    if (content == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Restaurer cette sauvegarde ?',
      message:
          'Toutes les données actuelles de cet appareil seront '
          'remplacées par celles du fichier.',
      confirmLabel: 'Restaurer',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(backupServiceProvider).importJson(content);
      await _load();
      if (mounted) showMessage(context, 'Sauvegarde restaurée');
    } catch (e) {
      if (mounted) showMessage(context, 'Import impossible : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final connected = settings?.validGmailToken != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loading || !_dirty ? null : _save,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: Form(
                key: _form,
                onChanged: () => setState(() => _dirty = true),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  children: [
                    const SectionTitle(
                      'Bailleur (apparaît sur les quittances)',
                    ),
                    AppTextField(
                      controller: _name,
                      label: 'Nom et prénom (ou société)',
                      required: true,
                    ),
                    AppTextField(
                      controller: _address,
                      label: 'Adresse',
                      required: true,
                    ),
                    FieldRow(
                      children: [
                        AppTextField(
                          controller: _postalCode,
                          label: 'Code postal',
                        ),
                        AppTextField(controller: _city, label: 'Ville'),
                      ],
                    ),
                    AppTextField(
                      controller: _signatureCity,
                      label: 'Ville de signature ("Fait à …")',
                      hint: 'Par défaut : votre ville',
                    ),
                    const SectionTitle('Envoi des mails (Gmail)'),
                    AppTextField(
                      controller: _email,
                      label: 'Votre adresse Gmail',
                      keyboardType: TextInputType.emailAddress,
                      validator: emailValidator,
                    ),
                    AppTextField(
                      controller: _clientId,
                      label: 'Identifiant client OAuth Google',
                      hint: 'xxxxxxxx.apps.googleusercontent.com',
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'À créer une seule fois dans Google Cloud Console '
                        '(gratuit). La marche à suivre est dans le fichier '
                        'docs/CONFIGURATION_GMAIL.md du projet.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Recevoir une copie de chaque quittance',
                      ),
                      subtitle: const Text('En copie cachée sur votre Gmail'),
                      value: _copyToSelf,
                      onChanged: (v) => setState(() {
                        _copyToSelf = v;
                        _dirty = true;
                      }),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _testEmail,
                          icon: const Icon(Icons.outgoing_mail),
                          label: const Text('Envoyer un mail de test'),
                        ),
                        if (connected)
                          TextButton(
                            onPressed: () async {
                              await ref.read(gmailServiceProvider).disconnect();
                              if (context.mounted) {
                                showMessage(context, 'Gmail déconnecté');
                              }
                            },
                            child: const Text('Déconnecter Gmail'),
                          ),
                        Chip(
                          avatar: Icon(
                            connected ? Icons.link : Icons.link_off,
                            size: 18,
                          ),
                          label: Text(
                            connected
                                ? 'Autorisation active'
                                : 'Autorisation demandée au 1er envoi',
                          ),
                        ),
                      ],
                    ),
                    const SectionTitle('Modèle du mail'),
                    AppTextField(controller: _subject, label: 'Objet'),
                    AppTextField(
                      controller: _body,
                      label: 'Message',
                      maxLines: 8,
                    ),
                    const Text(
                      'Variables : {locataire}, {periode}, {montant}, '
                      '{adresse}, {bailleur}',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SectionTitle('Données'),
                    const Text(
                      'Vos données sont enregistrées uniquement dans ce '
                      'navigateur, sur cet appareil. Exportez régulièrement '
                      'une sauvegarde ; elle permet aussi de transférer vos '
                      'données vers un autre appareil (ex. iPhone).',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _export,
                          icon: const Icon(Icons.download),
                          label: const Text('Exporter une sauvegarde'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _import,
                          icon: const Icon(Icons.upload),
                          label: const Text('Restaurer une sauvegarde'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _dirty ? _save : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
