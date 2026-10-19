/// Server qaysi kirish oqimlarini qo'llashi (TZ S33–S36). Kanal yo'q bo'lsa kodli tugmalar ko'rsatilmaydi.
class AuthOptions {
  AuthOptions({this.channels = const [], this.devCodes = false, this.termsVersion, this.otpTtl = 300, this.otpResend = 60});
  final List<String> channels;
  final bool devCodes;
  final String? termsVersion;
  final int otpTtl, otpResend;

  bool get sms => channels.contains('sms');
  bool get email => channels.contains('email');
  bool get any => channels.isNotEmpty;

  factory AuthOptions.fromJson(Map<String, dynamic> j) => AuthOptions(
        channels: List<String>.from(j['channels'] ?? const []),
        devCodes: j['dev_codes'] ?? false,
        termsVersion: j['terms_version'],
        otpTtl: j['otp_ttl'] ?? 300,
        otpResend: j['otp_resend'] ?? 60,
      );
}

/// Yuborilgan bir martalik kod (server holati). Kodning o'zi saqlanmaydi.
class Challenge {
  Challenge({
    required this.id,
    required this.purpose,
    required this.channel,
    required this.destinationMasked,
    required this.expiresIn,
    required this.resendIn,
    required this.attemptsLeft,
    this.devCode,
  });
  final String id, purpose, channel, destinationMasked;
  final int expiresIn, resendIn, attemptsLeft;
  final String? devCode;

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['challenge_id'],
        purpose: j['purpose'],
        channel: j['channel'],
        destinationMasked: j['destination_masked'] ?? '',
        expiresIn: j['expires_in'] ?? 0,
        resendIn: j['resend_in'] ?? 0,
        attemptsLeft: j['attempts_left'] ?? 0,
        devCode: j['dev_code'],
      );
}
