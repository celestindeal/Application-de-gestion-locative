import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_locative/core/format.dart';
import 'package:gestion_locative/data/backup_service.dart';
import 'package:gestion_locative/data/sembast_repository.dart';
import 'package:gestion_locative/data/settings_repository.dart';
import 'package:gestion_locative/features/receipts/receipt_pdf.dart';
import 'package:gestion_locative/features/receipts/receipt_service.dart';
import 'package:gestion_locative/models/landlord_settings.dart';
import 'package:gestion_locative/models/lease.dart';
import 'package:gestion_locative/models/property.dart';
import 'package:gestion_locative/models/rent_payment.dart';
import 'package:gestion_locative/models/tenant.dart';
import 'package:gestion_locative/services/gmail_service.dart';
import 'package:gestion_locative/services/mime_message.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Intl.defaultLocale = 'fr_FR';
    await initializeDateFormatting('fr_FR');
  });

  group('Money', () {
    test('parse les saisies françaises', () {
      expect(Money.parse('650,50'), 65050);
      expect(Money.parse('650.5'), 65050);
      expect(Money.parse('1 200'), 120000);
      expect(Money.parse('80 €'), 8000);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse(''), isNull);
    });
    test('aller-retour saisie', () {
      expect(Money.parse(Money.toInput(123456)), 123456);
    });
  });

  test('Lease.coversMonth', () {
    final l = Lease(
      id: 'l',
      propertyId: 'p',
      tenantIds: const ['t'],
      startDate: DateTime(2026, 3, 15),
      endDate: DateTime(2026, 9, 10),
      rentCents: 60000,
    );
    expect(l.coversMonth(2026, 2), isFalse);
    expect(l.coversMonth(2026, 3), isTrue);
    expect(l.coversMonth(2026, 9), isTrue);
    expect(l.coversMonth(2026, 10), isFalse);
  });

  test('MimeMessage : en-têtes et pièce jointe', () {
    final raw = MimeMessage(
      to: const ['locataire@example.com'],
      bcc: const ['moi@example.com'],
      subject: 'Quittance de loyer - novembre 2026 é',
      body: 'Bonjour,\nCi-joint.',
      attachments: [
        MailAttachment(
          filename: 'q.pdf',
          mimeType: 'application/pdf',
          bytes: utf8.encode('%PDF-1.4'),
        ),
      ],
    ).build();
    expect(raw, contains('To: locataire@example.com'));
    expect(raw, contains('Bcc: moi@example.com'));
    expect(raw, contains('Subject: =?UTF-8?B?'));
    expect(raw, contains('filename="q.pdf"'));
  });

  group('Quittance', () {
    late SembastRepository<RentPayment> payments;
    late ReceiptService service;
    late SettingsRepository settingsRepo;
    late Lease lease;

    setUp(() async {
      final db = await newDatabaseFactoryMemory().openDatabase('test');
      final properties = SembastRepository(db, 'properties', Property.fromJson);
      final tenants = SembastRepository(db, 'tenants', Tenant.fromJson);
      final leases = SembastRepository(db, 'leases', Lease.fromJson);
      payments = SembastRepository(db, 'payments', RentPayment.fromJson);
      settingsRepo = SettingsRepository(db);

      await settingsRepo.save(
        const LandlordSettings(
          name: 'Jean Bailleur',
          address: '1 rue du Port',
          postalCode: '44000',
          city: 'Nantes',
        ),
      );
      await properties.save(
        Property(
          id: 'p1',
          name: 'T2 Centre',
          address: '12 rue Victor Hugo',
          postalCode: '44000',
          city: 'Nantes',
        ),
      );
      await tenants.save(
        Tenant(
          id: 't1',
          civility: 'Mme',
          firstName: 'Marie',
          lastName: 'Durand',
          email: 'marie@example.com',
        ),
      );
      lease = Lease(
        id: 'l1',
        propertyId: 'p1',
        tenantIds: const ['t1'],
        startDate: DateTime(2026, 1, 1),
        rentCents: 60000,
        chargesCents: 5000,
      );
      await leases.save(lease);

      service = ReceiptService(
        payments: payments,
        properties: properties,
        tenants: tenants,
        leases: leases,
        settings: settingsRepo,
        gmail: GmailService(settingsRepo),
      );
    });

    test(
      'validation sans Gmail : paiement enregistré, numéro annuel',
      () async {
        final landlord = await settingsRepo.get();
        final o1 = await service.validatePayment(
          lease: lease,
          landlord: landlord,
          year: 2026,
          month: 10,
        );
        final o2 = await service.validatePayment(
          lease: lease,
          landlord: landlord,
          year: 2026,
          month: 11,
        );
        expect(o1.sent, isFalse);
        expect(o1.error, isA<GmailException>());
        expect(o1.payment.receiptNumber, '2026-001');
        expect(o2.payment.receiptNumber, '2026-002');
        expect(o2.payment.paidCents, 65000);
        expect((await payments.getAll()).length, 2);
      },
    );

    test('génère un PDF valide, complet et partiel', () async {
      final landlord = await settingsRepo.get();
      final full = (await service.validatePayment(
        lease: lease,
        landlord: landlord,
        year: 2026,
        month: 11,
        sendEmail: false,
      )).payment;
      final data = await service.loadReceiptData(full);
      expect(data.fileName, 'Quittance_2026-11_Durand.pdf');
      final bytes = await buildReceiptPdf(data);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');

      final partial = full.copyWith(paidCents: 30000);
      expect(partial.isPartial, isTrue);
      expect(partial.remainingCents, 35000);
      final pdf2 = await service.buildPdf(partial);
      expect(pdf2.length, greaterThan(1000));
    });

    test('sauvegarde : export puis import', () async {
      final db = await newDatabaseFactoryMemory().openDatabase('backup');
      final backup = BackupService(
        properties: service.properties,
        tenants: service.tenants,
        leases: service.leases,
        payments: payments,
        settings: settingsRepo,
      );
      final json = await backup.exportJson();

      final target = BackupService(
        properties: SembastRepository(db, 'properties', Property.fromJson),
        tenants: SembastRepository(db, 'tenants', Tenant.fromJson),
        leases: SembastRepository(db, 'leases', Lease.fromJson),
        payments: SembastRepository(db, 'payments', RentPayment.fromJson),
        settings: SettingsRepository(db),
      );
      await target.importJson(json);
      expect((await target.properties.getAll()).single.name, 'T2 Centre');
      expect((await target.settings.get()).name, 'Jean Bailleur');
      expect((await target.leases.getAll()).single.totalCents, 65000);
    });
  });
}
