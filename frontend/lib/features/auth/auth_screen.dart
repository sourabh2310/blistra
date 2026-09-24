/// Blistra V1 identity entry: premium sign-in, stepped registration,
///
/// password recovery.
///
/// SIGN-IN: one "Username, email or phone" field + password.
///
/// REGISTRATION (one focused question per screen, backend-backed only):
///   welcome → name → username → email → phone → password → confirm →
///   review + terms → email OTP → phone OTP (skipped without phone) →
///   profile → health → done → Home.
///
/// RECOVERY: identifier → channel → OTP → new password → sign in.
/// The server never reveals whether an identifier exists; the UI always shows
/// the same generic message.
///
/// [AuthGate] keeps fresh registrations ([AuthState.justRegistered]) in this
/// wizard until onboarding completes; all other sessions land on the shell.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_state.dart';
import '../diet/models/dietary_preference.dart';
import '../health/health_models.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';

enum _Mode { signIn, register, forgot }

/// Ordered registration steps. Account steps (name..review) share one
/// progress scale so the indicator reads "Step X of 7".
enum _Reg {
  welcome,
  name,
  username,
  email,
  phone,
  password,
  confirm,
  review,
  emailOtp,
  phoneOtp,
  profile,
  health,
  done,
}

enum _Forgot { identifier, channel, code, reset, success }

/// Live availability state for one identity field while typing.
enum _Avail { idle, checking, available, taken }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.deps, this.startWizard = false});

  final AppDependencies deps;

  /// Resume the post-registration wizard (used by [AuthGate]).
  final bool startWizard;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _phoneLocal = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _identifier = TextEditingController();
  final _signInPassword = TextEditingController();

  final _otp = TextEditingController();
  final _country = TextEditingController();
  final _language = TextEditingController(text: 'en');
  final _height = TextEditingController();
  final _weight = TextEditingController();

  final _forgotIdentifier = TextEditingController();
  final _forgotCode = TextEditingController();
  final _forgotNew = TextEditingController();
  final _forgotConfirm = TextEditingController();

  _Mode _mode = _Mode.signIn;
  _Reg _reg = _Reg.welcome;
  _Forgot _forgot = _Forgot.identifier;
  bool _terms = false;
  bool _finishing = false;
  bool _saving = false;
  bool _showSignInPw = false;
  bool _showPw = false;
  bool _showConfirm = false;
  bool _showForgotNew = false;

  // Per-screen inline errors (never a separate error page).
  String? _screenError;
  String? _loginError;
  String? _emailTakenError;
  String? _usernameTakenError;
  String? _phoneTakenError;

  // OTP state.
  int _cooldown = 0;
  Timer? _timer;
  bool _otpSubmitting = false;
  String _countryCode = '+91';

  // Live availability while typing (debounced GET /availability).
  _Avail _usernameAvail = _Avail.idle;
  _Avail _emailAvail = _Avail.idle;
  _Avail _phoneAvail = _Avail.idle;
  Timer? _usernameDebounce;
  Timer? _emailDebounce;
  Timer? _phoneDebounce;
  int _usernameGen = 0;
  int _emailGen = 0;
  int _phoneGen = 0;

  // Profile state.
  DateTime? _dob;
  String? _timezone;
  String _units = 'METRIC';
  String _heightUnit = 'CM';
  String _weightUnit = 'KG';
  DietaryPreference? _dietPreference;
  String _forgotChannel = 'EMAIL';

  // Recovery identity resolution (backend-authoritative, verified only).
  List<String> _recoveryChannels = const [];
  String? _recoveryEmailMasked;
  String? _recoveryPhoneMasked;
  bool _resolvingChannels = false;

  AuthState get _auth => widget.deps.authState;

  @override
  void initState() {
    super.initState();
    if (widget.startWizard) {
      _mode = _Mode.register;
      _reg = _resumeStep();
      _prefillFromAccount();
    }
    _timezone = _guessTimezone();
    _password.addListener(() {
      if (mounted) setState(() {});
    });
  }

  _Reg _resumeStep() {
    final account = _auth.account;
    if (account == null) return _Reg.emailOtp;
    if (!account.emailVerified) return _Reg.emailOtp;
    if (account.phone != null &&
        account.phone!.isNotEmpty &&
        !account.phoneVerified) {
      return _Reg.phoneOtp;
    }
    return _Reg.profile;
  }

  void _prefillFromAccount() {
    final account = _auth.account;
    if (account == null) return;
    _email.text = account.email;
    _username.text = account.username;
    if (account.phone != null) _phone.text = account.phone!;
  }

  static String _guessTimezone() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes == 330) return 'Asia/Kolkata';
    if (offset.inMinutes == 0) return 'UTC';
    return 'UTC';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _phoneDebounce?.cancel();
    _displayName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _phoneLocal.dispose();
    _password.dispose();
    _confirm.dispose();
    _identifier.dispose();
    _signInPassword.dispose();
    _otp.dispose();
    _country.dispose();
    _language.dispose();
    _height.dispose();
    _weight.dispose();
    _forgotIdentifier.dispose();
    _forgotCode.dispose();
    _forgotNew.dispose();
    _forgotConfirm.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  // ── Sign-in ──────────────────────────────────────────────────────

  Future<void> _signIn() async {
    final idError = validateIdentifier(_identifier.text);
    if (idError != null) {
      setState(() => _loginError = idError);
      return;
    }
    final pwError =
        validatePassword(_signInPassword.text, registering: false);
    if (pwError != null) {
      setState(() => _loginError = pwError);
      return;
    }
    setState(() => _loginError = null);
    FocusScope.of(context).unfocus();
    final account = await _auth.login(
      identifier: _identifier.text.trim(),
      password: _signInPassword.text,
    );
    if (!mounted) return;
    if (account == null) {
      // Enumeration-safe: never reveal which part failed.
      final raw = _friendly(_auth.lastError);
      final lower = raw.toLowerCase();
      final generic = lower.contains('network') ||
              lower.contains('connect')
          ? raw
          : "Your sign-in details don't match. Check them and try again.";
      setState(() => _loginError = generic);
      return;
    }
    setState(() => _finishing = true);
    await _initializeHome();
    if (mounted) setState(() => _finishing = false);
  }

  // ── Registration: per-step validation ────────────────────────────

  void _next(_Reg step) {
    setState(() {
      _screenError = null;
      _reg = step;
    });
  }

  void _backTo(_Reg step) {
    setState(() {
      _screenError = null;
      _reg = step;
    });
  }

  bool _checkName() {
    final v = _displayName.text.trim();
    if (v.isEmpty) {
      setState(() => _screenError = 'Enter your name to continue.');
      return false;
    }
    if (v.length < 2) {
      setState(
          () => _screenError = 'Please enter a little more.');
      return false;
    }
    final err = validateDisplayName(_displayName.text);
    if (err != null) {
      setState(() => _screenError = err);
      return false;
    }
    return true;
  }

  bool _checkUsername() {
    final err = validateUsername(_username.text);
    if (err != null) {
      setState(() {
        _screenError = err;
        _usernameTakenError = null;
      });
      return false;
    }
    if (_usernameAvail == _Avail.taken) {
      setState(() => _screenError = 'Username already taken.');
      return false;
    }
    // A check in flight is resolved authoritatively by _submitUsername.
    return true;
  }

  bool _checkEmail() {
    final err = validateEmail(_email.text);
    if (err != null) {
      setState(() {
        _screenError = err == 'Email is required'
            ? 'Enter your email to continue.'
            : 'Enter a valid email address.';
        _emailTakenError = null;
      });
      return false;
    }
    if (_emailAvail == _Avail.taken) {
      setState(() =>
          _screenError = 'That email is already registered.');
      return false;
    }
    // A check in flight is resolved authoritatively by _submitEmail.
    return true;
  }

  bool _checkPhone({bool allowEmpty = true}) {
    final local = _phoneLocal.text.trim();
    if (local.isEmpty) {
      if (allowEmpty) {
        _phone.text = '';
        return true;
      }
      setState(
          () => _screenError = 'Enter your phone number to continue.');
      return false;
    }
    final full = '$_countryCode${local.replaceAll(RegExp(r'[\s\-().]'), '')}';
    final err = validatePhone(full);
    if (err != null) {
      setState(() => _screenError = 'Enter a valid phone number.');
      return false;
    }
    if (_phoneAvail == _Avail.taken) {
      setState(() =>
          _screenError = 'That phone number is already registered.');
      return false;
    }
    // A check in flight is resolved authoritatively by _submitPhone.
    _phone.text = full;
    return true;
  }

  // ── Live availability (debounced, stale-guarded) ────────────────

  void _scheduleUsernameCheck(String value) {
    _usernameDebounce?.cancel();
    final gen = ++_usernameGen;
    if (validateUsername(value) != null) {
      setState(() => _usernameAvail = _Avail.idle);
      return;
    }
    setState(() => _usernameAvail = _Avail.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      bool? available;
      try {
        final result = await widget.deps.apiClient.checkAvailability(
          username: value.trim(),
        );
        available = result.usernameAvailable;
      } catch (_) {
        available = null; // Offline: stay silent, server decides at submit.
      }
      if (!mounted || gen != _usernameGen) return;
      setState(() => _usernameAvail = available == null
          ? _Avail.idle
          : available
              ? _Avail.available
              : _Avail.taken);
    });
  }

  void _scheduleEmailCheck(String value) {
    _emailDebounce?.cancel();
    final gen = ++_emailGen;
    if (validateEmail(value) != null) {
      setState(() => _emailAvail = _Avail.idle);
      return;
    }
    setState(() => _emailAvail = _Avail.checking);
    _emailDebounce = Timer(const Duration(milliseconds: 600), () async {
      bool? available;
      try {
        final result = await widget.deps.apiClient.checkAvailability(
          email: value.trim(),
        );
        available = result.emailAvailable;
      } catch (_) {
        available = null;
      }
      if (!mounted || gen != _emailGen) return;
      setState(() => _emailAvail = available == null
          ? _Avail.idle
          : available
              ? _Avail.available
              : _Avail.taken);
    });
  }

  void _schedulePhoneCheck() {
    _phoneDebounce?.cancel();
    final gen = ++_phoneGen;
    final local = _phoneLocal.text.trim();
    if (local.isEmpty) {
      setState(() => _phoneAvail = _Avail.idle);
      return;
    }
    final full =
        '$_countryCode${local.replaceAll(RegExp(r'[\s\-().]'), '')}';
    if (validatePhone(full) != null) {
      setState(() => _phoneAvail = _Avail.idle);
      return;
    }
    setState(() => _phoneAvail = _Avail.checking);
    _phoneDebounce = Timer(const Duration(milliseconds: 600), () async {
      bool? available;
      try {
        final result = await widget.deps.apiClient.checkAvailability(
          phone: full,
        );
        available = result.phoneAvailable;
      } catch (_) {
        available = null;
      }
      if (!mounted || gen != _phoneGen) return;
      setState(() => _phoneAvail = available == null
          ? _Avail.idle
          : available
              ? _Avail.available
              : _Avail.taken);
    });
  }

  /// Blocking server check used on Continue: cancels any pending debounce,
  /// invalidates in-flight checks, and resolves availability right now so
  /// the wizard can never outrun the live check. Offline (null) defers to
  /// the final registration endpoint, which re-validates everything.
  Future<bool> _ensureUsernameAvailable() async {
    _usernameDebounce?.cancel();
    final gen = ++_usernameGen;
    setState(() => _usernameAvail = _Avail.checking);
    bool? available;
    try {
      available = (await widget.deps.apiClient.checkAvailability(
        username: _username.text.trim(),
      ))
          .usernameAvailable;
    } catch (_) {
      available = null;
    }
    if (!mounted || gen != _usernameGen) return false;
    if (available == null) {
      setState(() => _usernameAvail = _Avail.idle);
      return true;
    }
    final bool usernameFree = available;
    setState(() => _usernameAvail =
        usernameFree ? _Avail.available : _Avail.taken);
    if (!usernameFree) {
      setState(() => _screenError = 'Username already taken.');
    }
    return usernameFree;
  }

  Future<bool> _ensureEmailAvailable() async {
    _emailDebounce?.cancel();
    final gen = ++_emailGen;
    setState(() => _emailAvail = _Avail.checking);
    bool? available;
    try {
      available = (await widget.deps.apiClient.checkAvailability(
        email: _email.text.trim(),
      ))
          .emailAvailable;
    } catch (_) {
      available = null;
    }
    if (!mounted || gen != _emailGen) return false;
    if (available == null) {
      setState(() => _emailAvail = _Avail.idle);
      return true;
    }
    final bool emailFree = available;
    setState(() =>
        _emailAvail = emailFree ? _Avail.available : _Avail.taken);
    if (!emailFree) {
      setState(
          () => _screenError = 'That email is already registered.');
    }
    return emailFree;
  }

  Future<bool> _ensurePhoneAvailable(String full) async {
    _phoneDebounce?.cancel();
    final gen = ++_phoneGen;
    setState(() => _phoneAvail = _Avail.checking);
    bool? available;
    try {
      available = (await widget.deps.apiClient.checkAvailability(
        phone: full,
      ))
          .phoneAvailable;
    } catch (_) {
      available = null;
    }
    if (!mounted || gen != _phoneGen) return false;
    if (available == null) {
      setState(() => _phoneAvail = _Avail.idle);
      return true;
    }
    final bool phoneFree = available;
    setState(() =>
        _phoneAvail = phoneFree ? _Avail.available : _Avail.taken);
    if (!phoneFree) {
      setState(() => _screenError =
          'That phone number is already registered.');
    }
    return phoneFree;
  }
  /// Inline availability row: spinner while checking, green confirmation
  /// with icon when free, red message when taken. Idle renders nothing.
  /// Never color-only: icon + text always accompany the state.
  Widget _availRow(_Avail state, {required String takenMessage}) {
    switch (state) {
      case _Avail.idle:
        return const SizedBox.shrink();
      case _Avail.checking:
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Checking…',
                  style: TextStyle(
                      fontSize: 13, color: AuthColors.muted)),
            ],
          ),
        );
      case _Avail.available:
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle,
                  size: 16, color: AuthColors.teal),
              SizedBox(width: 6),
              Text('Available',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.teal)),
            ],
          ),
        );
      case _Avail.taken:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 16, color: AuthColors.error),
              const SizedBox(width: 6),
              Flexible(
                child: Text(takenMessage,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AuthColors.error)),
              ),
            ],
          ),
        );
    }
  }

  bool _checkPassword() {
    final err =
        validatePassword(_password.text, registering: true);
    if (err != null) {
      setState(() => _screenError = err);
      return false;
    }
    return true;
  }

  bool _checkConfirm() {
    final err = validatePasswordConfirmation(
        _confirm.text, _password.text);
    if (err != null) {
      setState(() => _screenError = err == 'Passwords do not match'
          ? "Passwords don't match."
          : err);
      return false;
    }
    return true;
  }

  Future<void> _submitAccount() async {
    if (!_terms) {
      setState(() => _screenError =
          'Please agree to the Terms and Privacy Policy to continue.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _screenError = null;
      _emailTakenError = null;
      _usernameTakenError = null;
      _phoneTakenError = null;
    });
    final account = await _auth.register(
      username: _username.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      password: _password.text,
      displayName: _displayName.text.trim(),
    );
    if (!mounted) return;
    if (account == null) {
      final message = _friendly(_auth.lastError);
      setState(() {
        _screenError = message;
        final lower = message.toLowerCase();
        if (lower.contains('email')) {
          _emailTakenError = message;
        } else if (lower.contains('username')) {
          _usernameTakenError = message;
        } else if (lower.contains('phone')) {
          _phoneTakenError = message;
        }
      });
      // Route back to the offending step so the error is seen in context,
      // with the live row already showing Taken.
      final lower = message.toLowerCase();
      if (lower.contains('email')) {
        _emailAvail = _Avail.taken;
        _reg = _Reg.email;
      } else if (lower.contains('username')) {
        _usernameAvail = _Avail.taken;
        _reg = _Reg.username;
      } else if (lower.contains('phone')) {
        _phoneAvail = _Avail.taken;
        _reg = _Reg.phone;
      }
      return;
    }
    _otp.clear();
    _startCooldown(60);
    setState(() => _reg = _Reg.emailOtp);
  }

  // ── Registration: OTP ────────────────────────────────────────────

  Future<void> _verifyEmailOtp() async {
    if (_otpSubmitting) return;
    final codeError = validateOtpCode(_otp.text);
    if (codeError != null) {
      setState(() => _screenError = codeError);
      return;
    }
    setState(() {
      _screenError = null;
      _otpSubmitting = true;
    });
    final account = await _auth.verifyEmail(_otp.text);
    if (!mounted) return;
    setState(() => _otpSubmitting = false);
    if (account == null) {
      setState(() => _screenError = _otpFriendly(_auth.lastError));
      return;
    }
    _otp.clear();
    if (account.phone != null &&
        account.phone!.isNotEmpty &&
        !account.phoneVerified) {
      _startCooldown(60);
      setState(() => _reg = _Reg.phoneOtp);
    } else {
      setState(() => _reg = _Reg.profile);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    if (_otpSubmitting) return;
    final codeError = validateOtpCode(_otp.text);
    if (codeError != null) {
      setState(() => _screenError = codeError);
      return;
    }
    setState(() {
      _screenError = null;
      _otpSubmitting = true;
    });
    final account = await _auth.verifyPhone(_otp.text);
    if (!mounted) return;
    setState(() => _otpSubmitting = false);
    if (account == null) {
      setState(() => _screenError = _otpFriendly(_auth.lastError));
      return;
    }
    _otp.clear();
    setState(() => _reg = _Reg.profile);
  }

  Future<void> _resend(bool email) async {
    setState(() => _screenError = null);
    final seconds =
        email ? await _auth.resendEmailOtp() : await _auth.resendPhoneOtp();
    if (!mounted) return;
    if (seconds == null) {
      final err = _auth.lastError;
      if (err != null && err.isRateLimited) {
        _startCooldown(err.retryAfterSeconds ?? 60);
        setState(() => _screenError =
            'Too many attempts. Try again in ${err.retryAfterSeconds ?? 60} seconds.');
      } else {
        setState(() => _screenError = _friendly(err));
      }
      return;
    }
    _startCooldown(seconds);
  }

  String _otpFriendly(ApiException? error) {
    if (error == null) return 'Something went wrong. Please try again.';
    final code = (error.code).toUpperCase();
    if (code.contains('EXPIRED')) {
      return 'That code has expired. Request a new code.';
    }
    if (code.contains('RATE') || code.contains('LIMIT') || error.isRateLimited) {
      final s = error.retryAfterSeconds;
      return s != null
          ? 'Too many attempts. Try again in $s seconds.'
          : 'Too many attempts. Try again later.';
    }
    if (code.contains('INVALID') || error.statusCode == 400) {
      return 'That code is incorrect. Check and try again.';
    }
    return _friendly(error);
  }

  // ── Registration: profile + health ───────────────────────────────

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _saveProfile() async {
    if (_dob == null) {
      setState(
          () => _screenError = 'Please pick your date of birth.');
      return;
    }
    if (_country.text.trim().isEmpty) {
      setState(() => _screenError = 'Please enter your country.');
      return;
    }
    if (_timezone == null || _timezone!.isEmpty) {
      setState(() => _screenError = 'Please choose your timezone.');
      return;
    }
    setState(() {
      _screenError = null;
      _saving = true;
    });
    final ok = await widget.deps.profile.save({
      'displayName': _displayName.text.trim().isEmpty
          ? _auth.account?.email ?? ''
          : _displayName.text.trim(),
      'dateOfBirth':
          '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
      'country': _country.text.trim().toUpperCase(),
      'timezone': _timezone,
      'language': _language.text.trim().toLowerCase(),
      'unitSystem': _units,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() =>
          _screenError = widget.deps.profile.error ?? 'Could not save.');
      return;
    }
    setState(() => _reg = _Reg.health);
  }

  Future<void> _saveHealth() async {
    setState(() {
      _screenError = null;
      _saving = true;
    });
    try {
      final heightRaw = double.tryParse(_height.text.trim());
      if (heightRaw != null) {
        final heightCm =
            _heightUnit == 'IN' ? heightRaw * 2.54 : heightRaw;
        try {
          await widget.deps.health.saveProfile(HealthProfileInput(
            heightCm: heightCm,
            bloodType: null,
            dateOfBirth: _dob,
          ));
        } catch (e) {
          if (mounted) {
            setState(() {
              _screenError = 'Could not save height.';
              _saving = false;
            });
          }
          return;
        }
      }
      final weightRaw = double.tryParse(_weight.text.trim());
      if (weightRaw != null) {
        try {
          await widget.deps.health.createMeasurement(MeasurementInput(
            type: MeasurementType.weight,
            measuredAt: DateTime.now(),
            value: weightRaw,
            unit: _weightUnit,
            source: 'onboarding',
          ));
        } catch (e) {
          if (mounted) {
            setState(() {
              _screenError = 'Could not save weight.';
              _saving = false;
            });
          }
          return;
        }
      }
      if (_dietPreference != null) {
        await widget.deps.diet.saveProfile(
          dietaryPreference: _dietPreference!.wireName,
          customPreference: null,
          dislikedFoods: '',
          notes: '',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted || _screenError != null) return;
    setState(() => _reg = _Reg.done);
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _screenError = null;
      _finishing = true;
    });
    final profile = await _auth.completeOnboarding();
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _screenError = _friendly(_auth.lastError);
        _finishing = false;
      });
      return;
    }
    await _initializeHome();
    if (mounted) setState(() => _finishing = false);
  }

  // ── Recovery ─────────────────────────────────────────────────────

  /// Step 1: format check, then backend identity resolution. Unknown
  /// identifiers stop here with an inline error — no channel selection,
  /// no OTP generation, no navigation.
  Future<void> _forgotResolveIdentifier() async {
    final err = validateIdentifier(_forgotIdentifier.text);
    if (err != null) {
      setState(() => _screenError = err);
      return;
    }
    setState(() {
      _screenError = null;
      _resolvingChannels = true;
    });
    try {
      final result = await widget.deps.apiClient.recoveryChannels(
        identifier: _forgotIdentifier.text.trim(),
      );
      if (!mounted) return;
      if (result.channels.isEmpty) {
        setState(() {
          _screenError =
              'No verified recovery option on this account. Check your inbox for the verification code first.';
          _resolvingChannels = false;
        });
        return;
      }
      setState(() {
        _recoveryChannels = result.channels;
        _recoveryEmailMasked = result.emailMasked;
        _recoveryPhoneMasked = result.phoneMasked;
        _forgotChannel =
            result.offersEmail ? 'EMAIL' : 'SMS';
        _resolvingChannels = false;
        _forgot = _Forgot.channel;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _screenError = e.statusCode == 404
            ? (e.message.isNotEmpty
                ? e.message
                : "Couldn't find an account with those details.")
            : _friendly(e);
        _resolvingChannels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _screenError =
            "Couldn't connect. Check your connection and try again.";
        _resolvingChannels = false;
      });
    }
  }

  /// Step 2: issue the OTP to the chosen verified channel, then — only on
  /// success — advance to the OTP screen.
  Future<void> _forgotSendCode() async {
    setState(() => _screenError = null);
    final message = await _auth.forgotPassword(
      identifier: _forgotIdentifier.text.trim(),
      channel: _forgotChannel,
    );
    if (!mounted) return;
    if (message == null) {
      setState(() => _screenError = _friendly(_auth.lastError));
      return;
    }
    setState(() => _forgot = _Forgot.code);
  }

  Future<void> _forgotSubmitNewPassword() async {
    final codeError = validateOtpCode(_forgotCode.text);
    if (codeError != null) {
      setState(() => _screenError = codeError);
      return;
    }
    final pwError =
        validatePassword(_forgotNew.text, registering: true);
    if (pwError != null) {
      setState(() => _screenError = pwError);
      return;
    }
    final confirmError = validatePasswordConfirmation(
        _forgotConfirm.text, _forgotNew.text);
    if (confirmError != null) {
      setState(() => _screenError = confirmError);
      return;
    }
    setState(() => _screenError = null);
    final ok = await _auth.resetPassword(
      identifier: _forgotIdentifier.text.trim(),
      code: _forgotCode.text,
      newPassword: _forgotNew.text,
      confirmPassword: _forgotConfirm.text,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _screenError = _otpFriendly(_auth.lastError));
      return;
    }
    _identifier.text = _forgotIdentifier.text.trim();
    setState(() => _forgot = _Forgot.success);
  }

  // ── Shared ───────────────────────────────────────────────────────

  Future<void> _initializeHome() async {
    try {
      await widget.deps.profile.load();
    } catch (_) {}
    try {
      await widget.deps.dashboard.loadDashboard(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (_) {}
    try {
      await widget.deps.planner.loadToday();
    } catch (_) {}
  }

  String _friendly(ApiException? error) {
    if (error == null) return 'Something went wrong. Please try again.';
    if (error.code == 'RESEND_COOLDOWN') {
      return 'Please wait ${error.retryAfterSeconds ?? 60}s before requesting another code.';
    }
    if (error.code == 'RATE_LIMITED') {
      return 'Too many attempts. Please try again later.';
    }
    if (error.code == 'VERIFICATION_UNAVAILABLE') {
      return error.message;
    }
    if (error.statusCode == 409) return error.message;
    if (error.statusCode == 401) {
      return 'Invalid credentials. Please try again.';
    }
    final field = error.fieldErrors['email'] ??
        error.fieldErrors['username'] ??
        error.fieldErrors['phone'] ??
        error.fieldErrors['identifier'] ??
        error.fieldErrors['password'];
    if (field != null) return field;
    if (error.message.toLowerCase().contains('failed host') ||
        error.message.toLowerCase().contains('socket') ||
        error.message.toLowerCase().contains('network')) {
      return "Couldn't connect. Check your connection and try again.";
    }
    return error.message.isNotEmpty
        ? error.message
        : 'Something went wrong. Please try again.';
  }

  String get _maskedEmail {
    final email = _auth.account?.email ?? _email.text.trim();
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final local = parts[0];
    final shown =
        local.length <= 2 ? '$local•••' : '${local.substring(0, 2)}•••';
    return '$shown@${parts[1]}';
  }

  String get _maskedPhone {
    final phone = _auth.account?.phone ?? _phone.text.trim();
    if (phone.length < 4) return phone;
    return '••••••${phone.substring(phone.length - 4)}';
  }

  bool get _busy =>
      _auth.status == AuthStatus.busy ||
      _finishing ||
      _saving ||
      _otpSubmitting;

  // ── UI root ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        if (_mode == _Mode.signIn) return _loginScreen();
        if (_mode == _Mode.forgot) return _forgotScreen();
        return _registerScreen();
      },
    );
  }

  // ═══════════════════════ LOGIN ═══════════════════════

  Widget _loginScreen() {
    return AuthScaffold(
      bottom: AuthPrimaryButton(
        label: 'Sign in',
        busy: _busy,
        onPressed: _signIn,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const AuthBrand(),
          const SizedBox(height: 32),
          const Text('Welcome back',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AuthColors.ink)),
          const SizedBox(height: 6),
          const Text('Everything you need. One app.',
              style: TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 28),
          AuthTextField(
            controller: _identifier,
            hint: 'Username, email or phone',
            keyboardType: TextInputType.text,
            autofillHints: const ['username'],
            semanticLabel: 'Username, email or phone',
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _signInPassword,
            hint: 'Password',
            obscure: !_showSignInPw,
            autofillHints: const ['password'],
            semanticLabel: 'Password',
            suffix: IconButton(
              tooltip: _showSignInPw ? 'Hide password' : 'Show password',
              onPressed: () =>
                  setState(() => _showSignInPw = !_showSignInPw),
              icon: Icon(
                  _showSignInPw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthColors.muted),
            ),
            onSubmitted: (_) => _signIn(),
          ),
          if (_loginError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _loginError!),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _loginError = null;
                _screenError = null;
                _mode = _Mode.forgot;
                _forgot = _Forgot.identifier;
              }),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                  child: Divider(color: AuthColors.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: TextStyle(
                        fontSize: 13, color: AuthColors.muted)),
              ),
              const Expanded(
                  child: Divider(color: AuthColors.border)),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _loginError = null;
                _screenError = null;
                _mode = _Mode.register;
                _reg = _Reg.welcome;
              }),
              child: const Text(
                "Don't have an account? Create account",
                style: TextStyle(
                    color: AuthColors.teal,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ═══════════════════════ REGISTRATION ═══════════════════════

  Widget _registerScreen() {
    return switch (_reg) {
      _Reg.welcome => _welcomeScreen(),
      _Reg.name => _questionScreen(
          step: 1,
          title: "What's your name?",
          subtitle: "Let's personalize Blistra for you.",
          backTo: _Reg.welcome,
          field: AuthTextField(
            controller: _displayName,
            hint: 'Your name',
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const ['name'],
            autofocus: true,
            semanticLabel: 'Full name',
            error: null,
            onSubmitted: (_) => _submitName(),
          ),
          cta: 'Continue',
          onCta: _submitName,
        ),
      _Reg.username => _questionScreen(
          step: 2,
          title: 'Choose your username',
          subtitle: "This is how you'll be recognized on Blistra.",
          backTo: _Reg.name,
          field: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthTextField(
                controller: _username,
                hint: 'username',
                keyboardType: TextInputType.text,
                autofillHints: const ['newUsername'],
                autofocus: true,
                semanticLabel: 'Username',
                onChanged: _scheduleUsernameCheck,
                onSubmitted: (_) => _submitUsername(),
              ),
              _availRow(_usernameAvail,
                  takenMessage: 'Username already taken.'),
              const SizedBox(height: 8),
              const Text('3–30 letters, digits, _ or .',
                  style: TextStyle(
                      fontSize: 12.5, color: AuthColors.muted)),
            ],
          ),
          cta: 'Continue',
          onCta: _submitUsername,
        ),
      _Reg.email => _questionScreen(
          step: 3,
          title: "What's your email?",
          subtitle:
              "We'll use this for verification and account recovery.",
          backTo: _Reg.username,
          field: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthTextField(
                controller: _email,
                hint: 'email@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const ['email'],
                autofocus: true,
                semanticLabel: 'Email address',
                onChanged: _scheduleEmailCheck,
                onSubmitted: (_) => _submitEmail(),
              ),
              _availRow(_emailAvail,
                  takenMessage:
                      'That email is already registered.'),
            ],
          ),
          cta: 'Continue',
          onCta: _submitEmail,
        ),
      _Reg.phone => _phoneScreen(),
      _Reg.password => _passwordScreen(),
      _Reg.confirm => _questionScreen(
          step: 6,
          title: 'Confirm your password',
          subtitle: 'Just to make sure there are no typos.',
          backTo: _Reg.password,
          field: AuthTextField(
            controller: _confirm,
            hint: 'Confirm password',
            obscure: !_showConfirm,
            autofillHints: const ['newPassword'],
            autofocus: true,
            semanticLabel: 'Confirm password',
            suffix: IconButton(
              tooltip:
                  _showConfirm ? 'Hide password' : 'Show password',
              onPressed: () =>
                  setState(() => _showConfirm = !_showConfirm),
              icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthColors.muted),
            ),
            onSubmitted: (_) => _submitConfirm(),
          ),
          cta: 'Continue',
          onCta: _submitConfirm,
        ),
      _Reg.review => _reviewScreen(),
      _Reg.emailOtp => _otpScreen(
          email: true, onBack: () => _backTo(_Reg.review)),
      _Reg.phoneOtp => _otpScreen(
          email: false, onBack: () => _backTo(_Reg.emailOtp)),
      _Reg.profile => _profileScreen(),
      _Reg.health => _healthScreen(),
      _Reg.done => _doneScreen(),
    };
  }

  void _submitName() {
    if (_checkName()) _next(_Reg.username);
  }

  Future<void> _submitUsername() async {
    if (!_checkUsername()) return;
    if (!await _ensureUsernameAvailable()) return;
    if (!mounted) return;
    _next(_Reg.email);
  }

  Future<void> _submitEmail() async {
    if (!_checkEmail()) return;
    if (!await _ensureEmailAvailable()) return;
    if (!mounted) return;
    _next(_Reg.phone);
  }

  Future<void> _submitPhone() async {
    if (!_checkPhone()) return;
    if (!await _ensurePhoneAvailable(_phone.text)) return;
    if (!mounted) return;
    _next(_Reg.password);
  }

  void _submitPassword() {
    if (_checkPassword()) _next(_Reg.confirm);
  }

  void _submitConfirm() {
    if (_checkConfirm()) _next(_Reg.review);
  }

  Widget _welcomeScreen() {
    return AuthScaffold(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
              label: 'Get started',
              onPressed: () => _next(_Reg.name)),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _screenError = null;
                _mode = _Mode.signIn;
              }),
              child: const Text('Already have an account? Sign in',
                  style: TextStyle(
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const AuthBrand(),
          const SizedBox(height: 40),
          const Text('Everything\nyou need.\nOne app.',
              style: TextStyle(
                  fontSize: 44,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: AuthColors.ink)),
          const SizedBox(height: 14),
          const Text("Let's set up your account.",
              style:
                  TextStyle(fontSize: 16, color: AuthColors.muted)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// One focused question: back, progress, title, field, bottom CTA.
  Widget _questionScreen({
    required int step,
    required String title,
    required String subtitle,
    required _Reg backTo,
    required Widget field,
    required String cta,
    required VoidCallback onCta,
  }) {
    return AuthScaffold(
      onBack: _busy ? null : () => _backTo(backTo),
      bottom: AuthPrimaryButton(
          label: cta, busy: _busy, onPressed: onCta),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthProgress(step: step, total: 7),
          const SizedBox(height: 28),
          Text(title,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 24),
          field,
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  static const _dialCodes = [
    '+91',
    '+1',
    '+44',
    '+61',
    '+65',
    '+971',
    '+81',
    '+49',
    '+33',
    '+55',
  ];

  Widget _phoneScreen() {
    return AuthScaffold(
      onBack: _busy ? null : () => _backTo(_Reg.email),
      bottom: AuthPrimaryButton(
          label: 'Continue', busy: _busy, onPressed: _submitPhone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthProgress(step: 4, total: 7),
          const SizedBox(height: 28),
          const Text("What's your phone number?",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text(
              "We'll use this to verify your account and help you recover it. Optional — you can skip.",
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AuthColors.border),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dialCodes.contains(_countryCode)
                        ? _countryCode
                        : _dialCodes.first,
                    items: [
                      for (final c in _dialCodes)
                        DropdownMenuItem(
                            value: c, child: Text(c)),
                    ],
                    onChanged: (c) {
                      setState(
                          () => _countryCode = c ?? '+91');
                      _schedulePhoneCheck();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthTextField(
                  controller: _phoneLocal,
                  hint: 'Phone number',
                  keyboardType: TextInputType.phone,
                  autofillHints: const ['tel'],
                  autofocus: true,
                  semanticLabel: 'Phone number',
                  inputFormatters: [],
                  onChanged: (_) => _schedulePhoneCheck(),
                  onSubmitted: (_) => _submitPhone(),
                ),
              ),
            ],
          ),
          _availRow(_phoneAvail,
              takenMessage:
                  'That phone number is already registered.'),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    _phoneLocal.clear();
                    _phone.text = '';
                    _phoneAvail = _Avail.idle;
                    _next(_Reg.password);
                  },
            child: const Text('Skip for now',
                style: TextStyle(
                    color: AuthColors.teal,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _passwordScreen() {
    return AuthScaffold(
      onBack: _busy ? null : () => _backTo(_Reg.phone),
      bottom: AuthPrimaryButton(
          label: 'Continue',
          busy: _busy,
          onPressed: _submitPassword),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthProgress(step: 5, total: 7),
          const SizedBox(height: 28),
          const Text('Create a password',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text('Keep your account secure.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _password,
            hint: 'Password',
            obscure: !_showPw,
            autofillHints: const ['newPassword'],
            autofocus: true,
            semanticLabel: 'Password',
            suffix: IconButton(
              tooltip:
                  _showPw ? 'Hide password' : 'Show password',
              onPressed: () =>
                  setState(() => _showPw = !_showPw),
              icon: Icon(
                  _showPw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthColors.muted),
            ),
            onSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 12),
          PasswordStrength(password: _password.text),
          const SizedBox(height: 12),
          _requirement(
              '8+ characters', _password.text.length >= 8),
          _requirement('At least one letter',
              RegExp(r'[A-Za-z]').hasMatch(_password.text)),
          _requirement('At least one digit',
              RegExp(r'[0-9]').hasMatch(_password.text)),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _requirement(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: met ? AuthColors.teal : AuthColors.muted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: met
                      ? AuthColors.muted
                      : AuthColors.ink)),
        ],
      ),
    );
  }

  Widget _reviewScreen() {
    final busy =
        _auth.status == AuthStatus.busy || _finishing;
    return AuthScaffold(
      onBack: busy ? null : () => _backTo(_Reg.confirm),
      bottom: AuthPrimaryButton(
          label: 'Create account',
          busy: busy,
          onPressed: _submitAccount),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthProgress(step: 7, total: 7),
          const SizedBox(height: 28),
          const Text('Almost there.',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text('Review your details before we create your account.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 20),
          _reviewRow('Name', _displayName.text.trim(),
              () => _backTo(_Reg.name)),
          _reviewRow('Username', '@${_username.text.trim()}',
              () => _backTo(_Reg.username)),
          _reviewRow('Email', _email.text.trim(),
              () => _backTo(_Reg.email)),
          _reviewRow(
              'Phone',
              _phone.text.trim().isEmpty
                  ? '—'
                  : _phone.text.trim(),
              () => _backTo(_Reg.phone)),
          const SizedBox(height: 16),
          InkWell(
            onTap: busy
                ? null
                : () => setState(() => _terms = !_terms),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AuthColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _terms,
                    activeColor: AuthColors.teal,
                    onChanged: busy
                        ? null
                        : (v) =>
                            setState(() => _terms = v ?? false),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: _TermsText(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_screenError != null ||
              _emailTakenError != null ||
              _usernameTakenError != null ||
              _phoneTakenError != null) ...[
            const SizedBox(height: 12),
            InlineError(
                message: _screenError ??
                    _emailTakenError ??
                    _usernameTakenError ??
                    _phoneTakenError ??
                    'Something went wrong.'),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value, VoidCallback onEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuthColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AuthColors.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AuthColors.ink)),
              ],
            ),
          ),
          TextButton(
              onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }

  // ── OTP screens ──────────────────────────────────────────────

  Widget _otpScreen(
      {required bool email, required VoidCallback onBack}) {
    final busy =
        _auth.status == AuthStatus.busy || _otpSubmitting;
    final destination = email ? _maskedEmail : _maskedPhone;
    return AuthScaffold(
      onBack: busy ? null : onBack,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
            label: 'Verify',
            busy: busy,
            onPressed:
                email ? _verifyEmailOtp : _verifyPhoneOtp,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: (busy || _cooldown > 0)
                  ? null
                  : () => _resend(email),
              child: Text(
                  _cooldown > 0
                      ? 'Resend code in ${_cooldown}s'
                      : "Didn't receive it? Resend code",
                  style: const TextStyle(
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(email ? 'Verify your email' : 'Verify your phone',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          Text('We sent a 6-digit code to\n$destination',
              style: const TextStyle(
                  fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 28),
          OtpInput(
            controller: _otp,
            enabled: !busy,
            onCompleted:
                email ? _verifyEmailOtp : _verifyPhoneOtp,
          ),
          if (_screenError != null) ...[
            const SizedBox(height: 14),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ── Profile / health / done (existing onboarding, premium skin) ──

  Widget _profileScreen() {
    return AuthScaffold(
      bottom: AuthPrimaryButton(
          label: 'Continue', busy: _saving, onPressed: _saveProfile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A little about you',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text('Used across Home, Planner and your modules.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _pickDob,
            icon: const Icon(Icons.cake_outlined),
            label: Text(_dob == null
                ? 'Date of birth'
                : 'Born ${_dob!.day}/${_dob!.month}/${_dob!.year}'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AuthTextField(
                  controller: _country,
                  hint: 'Country (IN)',
                  textCapitalization:
                      TextCapitalization.characters,
                  semanticLabel: 'Country code',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: AuthTextField(
                  controller: _language,
                  hint: 'Language (en)',
                  semanticLabel: 'Language',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuthColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _timezone,
                isExpanded: true,
                hint: const Text('Timezone'),
                items: [
                  for (final z in _commonTimezones)
                    DropdownMenuItem(value: z, child: Text(z)),
                ],
                onChanged: (z) =>
                    setState(() => _timezone = z),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'METRIC', label: Text('Metric')),
              ButtonSegment(
                  value: 'IMPERIAL', label: Text('Imperial')),
            ],
            selected: {_units},
            onSelectionChanged: (s) =>
                setState(() => _units = s.first),
          ),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  static const _commonTimezones = [
    'UTC',
    'Asia/Kolkata',
    'Asia/Dubai',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Toronto',
    'America/Sao_Paulo',
  ];

  Widget _healthScreen() {
    return AuthScaffold(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
              label: 'Continue',
              busy: _saving,
              onPressed: _saveHealth),
          Center(
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _reg = _Reg.done),
              child: const Text('Skip for now',
                  style: TextStyle(
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health basics',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text('Optional. You can always add this later.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AuthTextField(
                  controller: _height,
                  hint: 'Height (optional)',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  semanticLabel: 'Height',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AuthColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _heightUnit,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'CM', child: Text('cm')),
                        DropdownMenuItem(
                            value: 'IN', child: Text('in')),
                      ],
                      onChanged: (u) => setState(
                          () => _heightUnit = u ?? 'CM'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AuthTextField(
                  controller: _weight,
                  hint: 'Weight (optional)',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  semanticLabel: 'Weight',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AuthColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _weightUnit,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'KG', child: Text('kg')),
                        DropdownMenuItem(
                            value: 'LB', child: Text('lb')),
                      ],
                      onChanged: (u) => setState(
                          () => _weightUnit = u ?? 'KG'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _doneScreen() {
    return AuthScaffold(
      bottom: AuthPrimaryButton(
          label: 'Go to Home',
          busy: _finishing,
          onPressed: _completeOnboarding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AuthColors.tealSoft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: _finishing
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        strokeWidth: 3),
                  )
                : const Icon(Icons.check,
                    size: 40, color: AuthColors.teal),
          ),
          const SizedBox(height: 20),
          const Text("You're all set!",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text('Your Home will load with your fresh profile.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          if (_screenError != null) ...[
            const SizedBox(height: 14),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ═══════════════════════ FORGOT ═══════════════════════

  Widget _forgotScreen() {
    return switch (_forgot) {
      _Forgot.identifier => _forgotIdentifierScreen(),
      _Forgot.channel => _forgotChannelScreen(),
      _Forgot.code => _forgotCodeScreen(),
      _Forgot.reset => _forgotResetScreen(),
      _Forgot.success => _forgotSuccessScreen(),
    };
  }

  Widget _forgotIdentifierScreen() {
    final busy =
        _auth.status == AuthStatus.busy || _resolvingChannels;
    return AuthScaffold(
      onBack: busy
          ? null
          : () => setState(() {
                _screenError = null;
                _mode = _Mode.signIn;
              }),
      bottom: AuthPrimaryButton(
          label: 'Continue',
          busy: busy,
          onPressed: _forgotResolveIdentifier),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Forgot your password?',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text('Enter your username, email, or phone.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _forgotIdentifier,
            hint: 'Username, email or phone',
            keyboardType: TextInputType.text,
            autofocus: true,
            semanticLabel: 'Username, email or phone',
            onSubmitted: (_) => _forgotResolveIdentifier(),
          ),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _forgotChannelScreen() {
    final busy = _auth.status == AuthStatus.busy;
    final offersEmail = _recoveryChannels.contains('EMAIL');
    final offersSms = _recoveryChannels.contains('SMS') ||
        _recoveryChannels.contains('PHONE');
    return AuthScaffold(
      onBack: busy
          ? null
          : () => setState(() {
                _screenError = null;
                _forgot = _Forgot.identifier;
              }),
      bottom: AuthPrimaryButton(
          label: 'Send code',
          busy: busy,
          onPressed: _forgotSendCode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Where should we send your code?',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text(
              'Only verified destinations are shown. We never show full contact details here.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 20),
          if (offersEmail)
            _channelCard('Email',
                _recoveryEmailMasked ?? 'Send to your email address', 'EMAIL'),
          if (offersEmail && offersSms) const SizedBox(height: 10),
          if (offersSms)
            _channelCard(
                'Phone (SMS)',
                _recoveryPhoneMasked ?? 'Send to your phone number',
                'SMS'),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _channelCard(String title, String subtitle, String value) {
    final selected = _forgotChannel == value;
    return InkWell(
      onTap: () => setState(() => _forgotChannel = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected
                  ? AuthColors.teal
                  : AuthColors.border,
              width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(
                value == 'EMAIL'
                    ? Icons.mail_outline
                    : Icons.sms_outlined,
                color: selected
                    ? AuthColors.teal
                    : AuthColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AuthColors.ink)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AuthColors.muted)),
                ],
              ),
            ),
            Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AuthColors.teal
                    : AuthColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _forgotCodeScreen() {
    final busy = _auth.status == AuthStatus.busy;
    return AuthScaffold(
      onBack: busy
          ? null
          : () => setState(() {
                _screenError = null;
                _forgot = _Forgot.channel;
              }),
      bottom: AuthPrimaryButton(
          label: 'Continue',
          onPressed: () {
            final err = validateOtpCode(_forgotCode.text);
            if (err != null) {
              setState(() => _screenError = err);
              return;
            }
            setState(() => _forgot = _Forgot.reset);
          }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("Verify it's you",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 8),
          const Text(
              'A code was sent to your verified destination. Enter it below.',
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          const SizedBox(height: 28),
          OtpInput(
            controller: _forgotCode,
            onCompleted: () =>
                setState(() => _forgot = _Forgot.reset),
          ),
          if (_screenError != null) ...[
            const SizedBox(height: 14),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _forgotResetScreen() {
    final busy = _auth.status == AuthStatus.busy;
    return AuthScaffold(
      onBack: busy
          ? null
          : () => setState(() {
                _screenError = null;
                _forgot = _Forgot.code;
              }),
      bottom: AuthPrimaryButton(
          label: 'Reset password',
          busy: busy,
          onPressed: _forgotSubmitNewPassword),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Create a new password',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AuthColors.ink)),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _forgotNew,
            hint: 'New password',
            obscure: !_showForgotNew,
            autofillHints: const ['newPassword'],
            autofocus: true,
            semanticLabel: 'New password',
            suffix: IconButton(
              tooltip: _showForgotNew
                  ? 'Hide password'
                  : 'Show password',
              onPressed: () => setState(
                  () => _showForgotNew = !_showForgotNew),
              icon: Icon(
                  _showForgotNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AuthColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          PasswordStrength(password: _forgotNew.text),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _forgotConfirm,
            hint: 'Confirm new password',
            obscure: true,
            semanticLabel: 'Confirm new password',
          ),
          if (_screenError != null) ...[
            const SizedBox(height: 12),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _forgotSuccessScreen() {
    return AuthScaffold(
      bottom: AuthPrimaryButton(
          label: 'Sign in',
          onPressed: () => setState(() {
                _screenError = null;
                _forgot = _Forgot.identifier;
                _mode = _Mode.signIn;
              })),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 48),
          Icon(Icons.check_circle,
              size: 72, color: AuthColors.teal),
          SizedBox(height: 20),
          Text('Password updated',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AuthColors.ink)),
          SizedBox(height: 8),
          Text('You can now sign in with your new password.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, color: AuthColors.muted)),
          SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 14, color: AuthColors.ink),
        children: [
          TextSpan(text: 'By creating your account, you agree to our '),
          TextSpan(
              text: 'Terms',
              style: TextStyle(
                  color: AuthColors.teal,
                  fontWeight: FontWeight.w700)),
          TextSpan(text: ' and '),
          TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                  color: AuthColors.teal,
                  fontWeight: FontWeight.w700)),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}
