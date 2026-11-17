import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/rent_payment.dart';
import 'payment_actions.dart';

/// Une quittance dans une liste, avec ses actions.
class PaymentTile extends ConsumerWidget {
  const PaymentTile({super.key, required this.payment, this.subtitlePrefix});
  final RentPayment payment;
  final String? subtitlePrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    final scheme = Theme.of(context).colorScheme;
    final sent = p.sentAt != null;
    return Card(
      child: ListTile(
        leading: Icon(
          sent ? Icons.mark_email_read_outlined : Icons.mail_outline,
          color: sent ? scheme.primary : scheme.error,
        ),
        title: Text(
          '${Dates.monthYearCapitalized(p.year, p.month)} · ${Money.format(p.paidCents)}'
          '${p.isPartial ? ' (partiel)' : ''}',
        ),
        subtitle: Text(
          [
            ?subtitlePrefix,
            'N° ${p.receiptNumber} · payé le ${Dates.day(p.paymentDate)}',
            sent
                ? 'Envoyée le ${Dates.day(p.sentAt!)} à ${p.sentTo.join(', ')}'
                : 'Quittance non envoyée',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: PaymentMenu(payment: p),
      ),
    );
  }
}

class PaymentMenu extends ConsumerWidget {
  const PaymentMenu({super.key, required this.payment});
  final RentPayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'Actions',
    onSelected: (v) {
      switch (v) {
        case 'view':
          PaymentActions.view(ref, payment);
        case 'download':
          PaymentActions.download(context, ref, payment);
        case 'send':
          PaymentActions.resend(context, ref, payment);
        case 'cancel':
          PaymentActions.cancel(context, ref, payment);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'view',
        child: ListTile(
          leading: Icon(Icons.visibility_outlined),
          title: Text('Voir la quittance'),
        ),
      ),
      const PopupMenuItem(
        value: 'download',
        child: ListTile(
          leading: Icon(Icons.download_outlined),
          title: Text('Télécharger / partager'),
        ),
      ),
      PopupMenuItem(
        value: 'send',
        child: ListTile(
          leading: const Icon(Icons.send_outlined),
          title: Text(
            payment.sentAt == null
                ? 'Envoyer par e-mail'
                : 'Renvoyer par e-mail',
          ),
        ),
      ),
      const PopupMenuItem(
        value: 'cancel',
        child: ListTile(
          leading: Icon(Icons.undo),
          title: Text('Annuler le paiement'),
        ),
      ),
    ],
  );
}
