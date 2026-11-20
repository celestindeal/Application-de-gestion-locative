import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/env.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_remote.dart';
import '../../data/sync/sync_service.dart';

/// Paramètres › Synchronisation : relie cet appareil au serveur de la
/// Raspberry Pi (base prod ou test selon l'app ouverte).
class SyncSection extends ConsumerStatefulWidget {
  const SyncSection({super.key});

  @override
  ConsumerState<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<SyncSection> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    ref.read(syncConfigRepositoryProvider).get().then((c) {
      if (!mounted) return;
      setState(() {
        _url.text = c.serverUrl;
        _key.text = c.key;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await ref.read(syncServiceProvider).connect(_url.text, _key.text);
      if (mounted) showMessage(context, 'Synchronisation activée');
    } on SyncException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await confirmDialog(
      context,
      title: 'Déconnecter cet appareil ?',
      message:
          'Les données restent sur cet appareil et sur le serveur, mais ne '
          'seront plus partagées tant que vous ne reconnectez pas.',
      confirmLabel: 'Déconnecter',
    );
    if (!ok) return;
    await ref.read(syncServiceProvider).disconnect();
    _key.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(syncConfigProvider).value;
    final status =
        ref.watch(syncStatusProvider).value ??
        const SyncStatus(SyncState.disabled);
    final pending = ref.watch(syncPendingCountProvider).value ?? 0;
    final connected = config?.isConfigured ?? false;

    final (IconData icon, Color color, String label) = switch (status.state) {
      SyncState.disabled => (
        Icons.cloud_off,
        theme.colorScheme.onSurfaceVariant,
        'Non connecté : les données restent sur cet appareil.',
      ),
      SyncState.syncing => (
        Icons.sync,
        theme.colorScheme.primary,
        'Synchronisation en cours…',
      ),
      SyncState.ok => (
        Icons.cloud_done,
        Colors.green.shade700,
        'À jour${status.lastSync == null ? '' : ' (${DateFormat('HH:mm').format(status.lastSync!)})'}',
      ),
      SyncState.offline => (
        Icons.cloud_queue,
        Colors.orange.shade800,
        'Serveur injoignable : les changements partiront plus tard.',
      ),
      SyncState.error => (
        Icons.error_outline,
        theme.colorScheme.error,
        status.message ?? 'Erreur de synchronisation',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Partage des données entre vos appareils et utilisateurs, via le '
          'serveur de la Raspberry Pi. Cette app ${AppEnv.isTest ? 'de TEST' : 'de PROD'} '
          'utilise la base ${AppEnv.isTest ? 'TEST' : 'PROD'} du serveur, avec sa propre clé.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label${pending > 0 && connected ? ' · $pending changement(s) en attente' : ''}',
                style: TextStyle(color: color),
              ),
            ),
          ],
        ),
        if (status.state == SyncState.offline && status.message != null)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(status.message!, style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 8),
        if (_loaded) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Adresse du serveur',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _key,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Clé de la base ${AppEnv.isTest ? 'TEST' : 'PROD'}',
                helperText:
                    'Celle réglée dans le module Home Assistant '
                    '(${AppEnv.isTest ? 'cle_test' : 'cle_prod'}). '
                    'Gardée uniquement sur cet appareil.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showKey ? 'Masquer' : 'Afficher',
                  icon: Icon(
                    _showKey ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy || !_loaded ? null : _connect,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(connected ? 'Reconnecter' : 'Connecter'),
            ),
            if (connected)
              OutlinedButton.icon(
                onPressed: () => ref.read(syncServiceProvider).syncNow(),
                icon: const Icon(Icons.sync),
                label: const Text('Synchroniser maintenant'),
              ),
            if (connected)
              TextButton(
                onPressed: _disconnect,
                child: const Text('Déconnecter'),
              ),
          ],
        ),
      ],
    );
  }
}
