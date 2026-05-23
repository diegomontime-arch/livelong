import 'package:flutter/services.dart';

/// Máscara EUA: `(305) 555-1234` enquanto digita (máx. 10 dígitos locais).
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.startsWith('1') && digits.length > 10) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

/// Extrai até 10 dígitos locais (sem o 1 do país).
String phoneDigitsFromInput(String text) {
  var digits = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.startsWith('1') && digits.length > 10) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) {
    digits = digits.substring(0, 10);
  }
  return digits;
}

/// Salva no Firestore como `1` + 10 dígitos (ex: `17868525672`).
String phoneForFirestore(String text) {
  final digits = phoneDigitsFromInput(text);
  if (digits.isEmpty) return '';
  return '1$digits';
}

/// Exibe número armazenado com máscara `(XXX) XXX-XXXX`.
String formatUsPhoneDisplay(String stored) {
  if (stored.trim().isEmpty) return '';
  var digits = stored.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.startsWith('1') && digits.length >= 11) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) {
    digits = digits.substring(0, 10);
  }
  if (digits.isEmpty) return stored;

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 0) buffer.write('(');
    if (i == 3) buffer.write(') ');
    if (i == 6) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
