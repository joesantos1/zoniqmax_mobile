import 'package:shared_preferences/shared_preferences.dart';

const _pendingReferralKey = 'pending_referral_code';

String normalizeReferralCode(String code) {
  return code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String? extractReferralCodeFromUri(Uri uri) {
  final ref = uri.queryParameters['ref'];
  if (ref == null || ref.trim().isEmpty) return null;
  final normalized = normalizeReferralCode(ref);
  if (normalized.length < 6 || normalized.length > 16) return null;
  return normalized;
}

bool isReferralUri(Uri uri) {
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  final isHttpSignup = (host == 'zoniqmax.com' || host == 'www.zoniqmax.com') &&
      path == '/signup';
  final isSchemeSignup =
      uri.scheme.toLowerCase() == 'zoniqmax' && host == 'signup';
  return isHttpSignup || isSchemeSignup;
}

Future<void> savePendingReferralCode(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingReferralKey, normalizeReferralCode(code));
}

Future<String?> readPendingReferralCode() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_pendingReferralKey);
  if (code == null || code.isEmpty) return null;
  return normalizeReferralCode(code);
}

Future<void> clearPendingReferralCode() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_pendingReferralKey);
}
