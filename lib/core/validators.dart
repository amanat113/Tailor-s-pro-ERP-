class Validators {
  Validators._();

  static String normalizeIndianMobile(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (input.trim().startsWith('+')) return input.trim();
    return input.trim();
  }

  static bool isValidIndianMobile(String input) {
    final normalized = normalizeIndianMobile(input);
    return RegExp(r'^\+91[6-9][0-9]{9}$').hasMatch(normalized);
  }

  static bool isValidOtp(String input) => RegExp(r'^[0-9]{6}$').hasMatch(input.trim());

  static bool isValidPin(String input) => RegExp(r'^[0-9]{4,8}$').hasMatch(input.trim());

  static num parseMoney(String input) {
    return num.tryParse(input.trim().replaceAll(',', '')) ?? 0;
  }

  static int parseQty(String input) {
    return int.tryParse(input.trim()) ?? 0;
  }
}
