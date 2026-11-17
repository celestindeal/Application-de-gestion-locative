import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class MailAttachment {
  const MailAttachment({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });
  final String filename;
  final String mimeType;
  final Uint8List bytes;
}

/// Construit un message MIME (RFC 2822) multipart avec pièces jointes, au
/// format attendu par l'API Gmail (`users.messages.send`, champ `raw`).
class MimeMessage {
  MimeMessage({
    required this.to,
    this.bcc = const [],
    required this.subject,
    required this.body,
    this.attachments = const [],
  });

  final List<String> to;
  final List<String> bcc;
  final String subject;
  final String body;
  final List<MailAttachment> attachments;

  static String _encodeHeader(String value) {
    final isAscii = value.codeUnits.every((c) => c < 128);
    if (isAscii) return value;
    return '=?UTF-8?B?${base64.encode(utf8.encode(value))}?=';
  }

  static String _wrap76(String b64) {
    final sb = StringBuffer();
    for (var i = 0; i < b64.length; i += 76) {
      sb.write(b64.substring(i, min(i + 76, b64.length)));
      sb.write('\r\n');
    }
    return sb.toString();
  }

  String build() {
    final boundary =
        '----=_GL_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    final sb = StringBuffer()
      ..write('MIME-Version: 1.0\r\n')
      ..write('To: ${to.join(', ')}\r\n');
    if (bcc.isNotEmpty) sb.write('Bcc: ${bcc.join(', ')}\r\n');
    sb
      ..write('Subject: ${_encodeHeader(subject)}\r\n')
      ..write('Content-Type: multipart/mixed; boundary="$boundary"\r\n')
      ..write('\r\n')
      ..write('--$boundary\r\n')
      ..write('Content-Type: text/plain; charset="UTF-8"\r\n')
      ..write('Content-Transfer-Encoding: base64\r\n\r\n')
      ..write(_wrap76(base64.encode(utf8.encode(body))));
    for (final a in attachments) {
      final name = _encodeHeader(a.filename);
      sb
        ..write('--$boundary\r\n')
        ..write('Content-Type: ${a.mimeType}; name="$name"\r\n')
        ..write('Content-Disposition: attachment; filename="$name"\r\n')
        ..write('Content-Transfer-Encoding: base64\r\n\r\n')
        ..write(_wrap76(base64.encode(a.bytes)));
    }
    sb.write('--$boundary--\r\n');
    return sb.toString();
  }

  /// Encodage base64url demandé par l'API Gmail.
  String toGmailRaw() => base64Url.encode(utf8.encode(build()));
}
