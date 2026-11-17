import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../models/landlord_settings.dart';
import '../../models/property.dart';
import '../../models/rent_payment.dart';
import '../../models/tenant.dart';

/// Tout ce qu'il faut pour produire une quittance.
class ReceiptData {
  const ReceiptData({
    required this.landlord,
    required this.property,
    required this.tenants,
    required this.payment,
  });

  final LandlordSettings landlord;
  final Property property;
  final List<Tenant> tenants;
  final RentPayment payment;

  String get tenantNames => tenants.map((t) => t.formalName).join(' et ');

  String get fileName {
    final p = payment;
    final kind = p.isPartial ? 'Recu' : 'Quittance';
    final who = tenants.isEmpty
        ? ''
        : '_${tenants.first.lastName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';
    return '${kind}_${p.year}-${p.month.toString().padLeft(2, '0')}$who.pdf';
  }
}

pw.ThemeData? _cachedTheme;

/// Police Roboto embarquée : les polices PDF standard (Helvetica) ne savent
/// pas afficher le symbole €.
Future<pw.ThemeData> _theme() async {
  if (_cachedTheme != null) return _cachedTheme!;
  Future<pw.Font> load(String name) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
  return _cachedTheme = pw.ThemeData.withFont(
    base: await load('Roboto-Regular'),
    bold: await load('Roboto-Bold'),
    italic: await load('Roboto-Italic'),
  );
}

/// Génère la quittance (ou le reçu en cas de paiement partiel) en PDF,
/// conforme à l'article 21 de la loi n° 89-462 du 6 juillet 1989 :
/// détail du loyer et des charges, période, identité des parties, adresse.
Future<Uint8List> buildReceiptPdf(ReceiptData d) async {
  final p = d.payment;
  final l = d.landlord;
  final from = Dates.firstDayOfMonth(p.year, p.month);
  final to = Dates.lastDayOfMonth(p.year, p.month);
  final title = p.isPartial ? 'REÇU DE PAIEMENT PARTIEL' : 'QUITTANCE DE LOYER';
  final accent = PdfColor.fromHex('#1F4E79');

  final doc = pw.Document(
    title: '$title - ${p.periodLabel}',
    author: l.name,
    theme: await _theme(),
  );

  pw.Widget block(String label, List<String> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
          letterSpacing: 1,
        ),
      ),
      pw.SizedBox(height: 3),
      for (final line in lines.where((s) => s.trim().isNotEmpty))
        pw.Text(line, style: const pw.TextStyle(fontSize: 11)),
    ],
  );

  pw.TableRow row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );
    return pw.TableRow(
      decoration: bold
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(label, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  final period = 'du ${Dates.day(from)} au ${Dates.day(to)}';
  final statement = p.isPartial
      ? 'Je soussigné(e) ${l.name}, bailleur du logement désigné ci-dessus, '
            'déclare avoir reçu de ${d.tenantNames} la somme de '
            '${Money.format(p.paidCents)} à titre d\'acompte sur le loyer et '
            'les charges de la période $period. '
            'Il reste dû la somme de ${Money.format(p.remainingCents)}. '
            'Le présent reçu ne vaut pas quittance.'
      : 'Je soussigné(e) ${l.name}, bailleur du logement désigné ci-dessus, '
            'déclare avoir reçu de ${d.tenantNames} la somme de '
            '${Money.format(p.paidCents)} au titre du paiement du loyer et des '
            'charges pour la période $period, et lui en donne quittance, sous '
            'réserve de tous mes droits.';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Période : ${p.periodLabel}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Text(
                'N° ${p.receiptNumber}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: accent, thickness: 1.5),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: block('BAILLEUR', [
                  l.name,
                  l.address,
                  [l.postalCode, l.city].join(' '),
                ]),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: block(
                  d.tenants.length > 1 ? 'LOCATAIRES' : 'LOCATAIRE',
                  d.tenants.map((t) => t.formalName).toList(),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          block('ADRESSE DU LOGEMENT LOUÉ', [
            d.property.address,
            [d.property.postalCode, d.property.city].join(' '),
          ]),
          pw.SizedBox(height: 24),
          pw.Text(
            statement,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.4),
            },
            children: [
              row('Loyer hors charges', Money.format(p.rentCents)),
              row('Provision pour charges', Money.format(p.chargesCents)),
              row(
                'Total dû pour la période',
                Money.format(p.dueCents),
                bold: true,
              ),
              row('Montant reçu', Money.format(p.paidCents), bold: true),
              if (p.isPartial) row('Reste dû', Money.format(p.remainingCents)),
              row('Date du paiement', Dates.day(p.paymentDate)),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Fait à ${l.effectiveSignatureCity}, le ${Dates.day(p.createdAt)}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  l.name,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Text(
            p.isPartial
                ? 'En cas de paiement partiel, le bailleur délivre un reçu '
                      '(article 21 de la loi n° 89-462 du 6 juillet 1989).'
                : 'Cette quittance annule tous les reçus qui auraient pu être '
                      'établis précédemment en cas de paiement partiel du montant '
                      'du présent terme. Document à conserver par le locataire.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
