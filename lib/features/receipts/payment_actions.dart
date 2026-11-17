import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/form_fields.dart';
import '../../core/format.dart';
import '../../core/platform/file_io.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/landlord_settings.dart';
import '../../models/lease.dart';
import '../../models/rent_payment.dart';
import 'receipt_service.dart';

/// Actions utilisateur autour des paiements et quittances, partagées entre
/// le tableau de bord, la fiche d'un bien et l'historique.
abstract final class PaymentActions {
  static LandlordSettings _settings(WidgetRef ref) =>
      ref.read(settingsProvider).value ?? const LandlordSettings();

  static bool _checkLandlord(BuildContext context, LandlordSettings s) {
    if (s.isLandlordComplete) return true;
    showMessage(
      context,
      'Renseignez d\'abord vos nom et adresse de bailleur dans Paramètres '
      '(ils figurent sur la quittance).',
      error: true,
    );
    return false;
  }

  /// LE bouton "un clic" : paiement complet, date du jour, envoi du mail.
  static Future<void> validate(
    BuildContext context,
    WidgetRef ref, {
    required Lease lease,
    required int year,
    required int month,
    int? paidCents,
    DateTime? paymentDate,
    bool sendEmail = true,
  }) async {
    final settings = _settings(ref);
    if (!_checkLandlord(context, settings)) return;
    final outcome = await ref
        .read(receiptServiceProvider)
        .validatePayment(
          lease: lease,
          landlord: settings,
          year: year,
          month: month,
          paidCents: paidCents,
          paymentDate: paymentDate,
          sendEmail: sendEmail,
        );
    if (!context.mounted) return;
    if (outcome.sent) {
      showMessage(
        context,
        'Paiement validé · quittance envoyée à ${outcome.payment.sentTo.join(', ')}',
      );
    } else if (outcome.error != null) {
      showMessage(
        context,
        'Paiement enregistré, mais la quittance n\'a pas été envoyée : '
        '${outcome.error}',
        error: true,
      );
    } else {
      showMessage(context, 'Paiement enregistré.');
    }
  }

  /// Variante avec saisie du montant et de la date (paiement partiel, retard…).
  static Future<void> validateWithDetails(
    BuildContext context,
    WidgetRef ref, {
    required Lease lease,
    required int year,
    required int month,
  }) async {
    final amount = TextEditingController(text: Money.toInput(lease.totalCents));
    var date = DateTime.now();
    var send = true;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Paiement de ${Dates.monthYear(year, month)}'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montant dû : ${Money.format(lease.totalCents)}'),
                  const SizedBox(height: 12),
                  MoneyField(
                    controller: amount,
                    label: 'Montant reçu',
                    required: true,
                  ),
                  DateField(
                    label: 'Date du paiement',
                    value: date,
                    onChanged: (d) => setState(() => date = d ?? date),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: send,
                    onChanged: (v) => setState(() => send = v ?? true),
                    title: const Text('Envoyer la quittance par e-mail'),
                  ),
                  const Text(
                    'Si le montant est inférieur au dû, un reçu de paiement '
                    'partiel est émis à la place de la quittance.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await validate(
      context,
      ref,
      lease: lease,
      year: year,
      month: month,
      paidCents: Money.parse(amount.text),
      paymentDate: date,
      sendEmail: send,
    );
  }

  static Future<void> resend(
    BuildContext context,
    WidgetRef ref,
    RentPayment payment,
  ) async {
    final settings = _settings(ref);
    if (!_checkLandlord(context, settings)) return;
    try {
      final updated = await ref
          .read(receiptServiceProvider)
          .sendReceipt(payment, landlord: settings);
      if (context.mounted) {
        showMessage(
          context,
          'Quittance envoyée à ${updated.sentTo.join(', ')}',
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }

  static Future<void> download(
    BuildContext context,
    WidgetRef ref,
    RentPayment payment,
  ) async {
    try {
      final service = ref.read(receiptServiceProvider);
      final data = await service.loadReceiptData(payment);
      final bytes = await service.buildPdf(payment);
      await FileIO.saveOrShare(bytes, data.fileName, 'application/pdf');
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }

  /// Synchrone volontairement : l'onglet doit s'ouvrir pendant le clic.
  static void view(WidgetRef ref, RentPayment payment) {
    FileIO.openInNewTab(
      ref.read(receiptServiceProvider).buildPdf(payment),
      'application/pdf',
    );
  }

  static Future<void> cancel(
    BuildContext context,
    WidgetRef ref,
    RentPayment payment,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Annuler ce paiement ?',
      message: payment.sentAt != null
          ? 'La quittance a déjà été envoyée au locataire. Le paiement sera '
                'supprimé de l\'application, mais pas le mail envoyé.'
          : 'Le paiement de ${payment.periodLabel} sera supprimé.',
      confirmLabel: 'Supprimer le paiement',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(paymentRepositoryProvider).delete(payment.id);
    if (context.mounted) showMessage(context, 'Paiement supprimé.');
  }
}
