import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../data/settings_repository.dart';
import '../../models/landlord_settings.dart';
import '../../models/lease.dart';
import '../../models/property.dart';
import '../../models/rent_payment.dart';
import '../../models/tenant.dart';
import '../../services/gmail_service.dart';
import '../../services/mime_message.dart';
import 'receipt_pdf.dart';

final receiptServiceProvider = Provider<ReceiptService>(
  (ref) => ReceiptService(
    payments: ref.watch(paymentRepositoryProvider),
    properties: ref.watch(propertyRepositoryProvider),
    tenants: ref.watch(tenantRepositoryProvider),
    leases: ref.watch(leaseRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    gmail: ref.watch(gmailServiceProvider),
  ),
);

/// Résultat de la validation d'un paiement, pour informer l'utilisateur.
class PaymentOutcome {
  PaymentOutcome(this.payment, {this.sent = false, this.error});
  final RentPayment payment;
  final bool sent;
  final Object? error;
}

/// Cœur métier du MVP : valider un paiement, générer la quittance, l'envoyer.
class ReceiptService {
  ReceiptService({
    required this.payments,
    required this.properties,
    required this.tenants,
    required this.leases,
    required this.settings,
    required this.gmail,
  });

  final Repository<RentPayment> payments;
  final Repository<Property> properties;
  final Repository<Tenant> tenants;
  final Repository<Lease> leases;
  final SettingsRepository settings;
  final GmailService gmail;

  /// Valide le paiement du mois et envoie la quittance par mail.
  ///
  /// [landlord] : paramètres déjà chargés (voir [GmailService.accessToken]).
  /// Si l'envoi échoue, le paiement reste enregistré et pourra être renvoyé.
  Future<PaymentOutcome> validatePayment({
    required Lease lease,
    required LandlordSettings landlord,
    required int year,
    required int month,
    int? paidCents,
    DateTime? paymentDate,
    bool sendEmail = true,
  }) async {
    // 1. Autorisation Gmail EN PREMIER, tant qu'on est encore dans le clic.
    String? token;
    Object? authError;
    if (sendEmail && landlord.isGmailConfigured) {
      try {
        token = await gmail.accessToken(current: landlord);
      } catch (e) {
        authError = e;
      }
    }

    // 2. Enregistrement du paiement.
    final payment = RentPayment(
      id: const Uuid().v4(),
      leaseId: lease.id,
      propertyId: lease.propertyId,
      year: year,
      month: month,
      rentCents: lease.rentCents,
      chargesCents: lease.chargesCents,
      paidCents: paidCents ?? lease.totalCents,
      paymentDate: paymentDate ?? DateTime.now(),
      receiptNumber: await _nextReceiptNumber(year),
    );
    await payments.save(payment);

    if (!sendEmail) return PaymentOutcome(payment);
    if (!landlord.isGmailConfigured) {
      return PaymentOutcome(
        payment,
        error: GmailException(
          "Gmail n'est pas configuré (Paramètres > Envoi des mails).",
        ),
      );
    }
    if (authError != null) return PaymentOutcome(payment, error: authError);

    // 3. Envoi.
    try {
      final sent = await sendReceipt(payment, token: token);
      return PaymentOutcome(sent, sent: true);
    } catch (e) {
      return PaymentOutcome(payment, error: e);
    }
  }

  /// (Ré)envoie la quittance d'un paiement existant.
  /// Passer [landlord] depuis l'écran permet d'ouvrir la fenêtre
  /// d'autorisation Google immédiatement au clic.
  Future<RentPayment> sendReceipt(
    RentPayment payment, {
    String? token,
    LandlordSettings? landlord,
  }) async {
    if (token == null && landlord != null) {
      token = await gmail.accessToken(current: landlord);
    }
    final data = await loadReceiptData(payment);
    final recipients = data.tenants
        .map((t) => t.email.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (recipients.isEmpty) {
      throw GmailException(
        "Aucune adresse e-mail renseignée pour le(s) locataire(s).",
      );
    }
    final pdf = await buildReceiptPdf(data);
    final l = data.landlord;
    String fill(String template) => template
        .replaceAll('{periode}', payment.periodLabel)
        .replaceAll(
          '{locataire}',
          data.tenants
              .map((t) => t.firstName.isNotEmpty ? t.firstName : t.formalName)
              .join(' et '),
        )
        .replaceAll('{montant}', Money.format(payment.paidCents))
        .replaceAll('{adresse}', data.property.fullAddress)
        .replaceAll('{bailleur}', l.name);

    final subject = payment.isPartial
        ? 'Reçu de paiement partiel - ${payment.periodLabel}'
        : fill(l.emailSubject);
    final message = MimeMessage(
      to: recipients,
      bcc: l.sendCopyToSelf && l.email.trim().isNotEmpty
          ? [l.email.trim()]
          : const [],
      subject: subject,
      body: fill(l.emailBody),
      attachments: [
        MailAttachment(
          filename: data.fileName,
          mimeType: 'application/pdf',
          bytes: pdf,
        ),
      ],
    );
    await gmail.send(message, token: token);
    final updated = payment.copyWith(
      sentAt: DateTime.now(),
      sentTo: recipients,
    );
    await payments.save(updated);
    return updated;
  }

  Future<ReceiptData> loadReceiptData(RentPayment payment) async {
    final lease = await leases.getById(payment.leaseId);
    final property = await properties.getById(payment.propertyId);
    if (lease == null || property == null) {
      throw StateError('Bail ou bien introuvable pour cette quittance.');
    }
    final tenantList = <Tenant>[];
    for (final id in lease.tenantIds) {
      final t = await tenants.getById(id);
      if (t != null) tenantList.add(t);
    }
    return ReceiptData(
      landlord: await settings.get(),
      property: property,
      tenants: tenantList,
      payment: payment,
    );
  }

  Future<Uint8List> buildPdf(RentPayment payment) async =>
      buildReceiptPdf(await loadReceiptData(payment));

  /// Numérotation annuelle : 2026-001, 2026-002…
  Future<String> _nextReceiptNumber(int year) async {
    final all = await payments.getAll();
    var max = 0;
    for (final p in all) {
      final parts = p.receiptNumber.split('-');
      if (parts.length == 2 && parts[0] == '$year') {
        final n = int.tryParse(parts[1]) ?? 0;
        if (n > max) max = n;
      }
    }
    return '$year-${(max + 1).toString().padLeft(3, '0')}';
  }
}
