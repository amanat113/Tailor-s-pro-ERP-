class Validators {
  Validators._();

  static String normalizeIndianMobile(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length > 10 && input.trim().startsWith('+')) return '+$digits';
    return digits;
  }

  static bool isValidMobile(String input) {
    final normalized = normalizeIndianMobile(input);
    return RegExp(r'^\+?[1-9]\d{9,14}$').hasMatch(normalized);
  }

  static bool isValidOtp(String input) {
    return RegExp(r'^\d{6}$').hasMatch(input.trim());
  }

  static bool isValidPin(String input) {
    return RegExp(r'^\d{4,8}$').hasMatch(input.trim());
  }
}
