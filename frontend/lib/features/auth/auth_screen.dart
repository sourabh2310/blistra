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
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_dependencies.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/google_sign_in_service.dart';
import '../../core/device/device_context.dart';
import '../../core/theme/theme_controller.dart';
import '../diet/models/dietary_preference.dart';
import '../health/health_models.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'country_data.dart';
import '../../core/widgets/glass.dart';
import '../../core/config/app_config.dart';
import '../profile/screens/policy_screen.dart';

enum _Mode { signIn, register, forgot }

/// Ordered registration steps. Account steps (name..review) share one
/// progress scale so the indicator reads "Step X of 7".
enum _Reg {
  welcome,
  singleForm,
  // legacy steps kept for resume logic
  name,
  username,
  email,
  phone,
  password,
  confirm,
  review,
  emailOtp,
  phoneOtp,
  profileWelcome,
  profile,
  health,
  done,
}

enum _Forgot { identifier, channel, code, reset, success }

/// Live availability state for one identity field while typing.
enum _Avail { idle, checking, available, taken }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.deps,
    this.startWizard = false,
    this.googleTokenProvider,
  });

  final AppDependencies deps;

  /// Overrides native Google Sign-In (tests).
  final GoogleIdTokenProvider? googleTokenProvider;

  /// Resume the post-registration wizard (used by [AuthGate]).
  final bool startWizard;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _displayName = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _phoneLocal = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _identifier = TextEditingController();
  final _signInPassword = TextEditingController();

  final _otp = TextEditingController();
  final _emailInlineOtp = TextEditingController();
  final _phoneInlineOtp = TextEditingController();
  final _country = TextEditingController();
  String? _selectedCountryCode;
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
  bool _emailOtpSent = false;
  bool _emailOtpVerified = false;
  bool _phoneOtpSent = false;
  bool _phoneOtpVerified = false;

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

  // New profile/health fields.
  String? _gender; // 'MALE', 'FEMALE', 'NON_BINARY', 'PREFER_NOT_TO_SAY'
  String? _activityLevel; // 'SEDENTARY', 'LIGHT', 'MODERATE', 'VERY_ACTIVE'
  final Set<String> _selectedGoals = {};

  // Avatar picked during onboarding — uploaded after profile save.
  Uint8List? _pendingAvatarBytes;
  String _pendingAvatarFilename = 'avatar.jpg';

  // Recovery identity resolution (backend-authoritative, verified only).
  List<String> _recoveryChannels = const [];
  String? _recoveryEmailMasked;
  String? _recoveryPhoneMasked;
  bool _resolvingChannels = false;

  AuthState get _auth => widget.deps.authState;

  late final GoogleIdTokenProvider _google =
      widget.googleTokenProvider ?? googleIdTokenProvider;
  bool _googleBusy = false;
  bool _googleRegistration = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWizard) {
      _mode = _Mode.register;
      _reg = _resumeStep();
      _prefillFromAccount();
    }
    _timezone = _guessTimezone();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final defaultCountry = DeviceContext.countryFromLocale(
      locale.toLanguageTag(),
    );
    _selectedCountryCode = defaultCountry;
    _units = DeviceContext.defaultUnitSystemForCountry(defaultCountry);
    _heightUnit = _units == 'IMPERIAL' ? 'IN' : 'CM';
    _weightUnit = _units == 'IMPERIAL' ? 'LB' : 'KG';
    _password.addListener(() {
      if (mounted) setState(() {});
    });
    _identifier.addListener(() {
      if (mounted) setState(() {});
    });
    _signInPassword.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AuthGate reuses the same State (same key) when transitioning from the
    // sign-in screen to the post-registration wizard. initState is never
    // re-called, so we handle the flip here.
    if (!oldWidget.startWizard && widget.startWizard) {
      // _signInWithGoogle may have already set up the Google flow in this same
      // frame. Don't overwrite its step/mode.
      if (_googleRegistration) return;
      final account = _auth.account;
      _mode = _Mode.register;
      if (account != null && account.username.isEmpty) {
        // Google user resumed after an app restart — no username chosen yet.
        _googleRegistration = true;
        _email.text = account.email;
        _reg = _Reg.singleForm;
      } else {
        _reg = _resumeStep();
        _prefillFromAccount();
      }
    }
  }

  _Reg _resumeStep() {
    return _auth.account == null ? _Reg.emailOtp : _Reg.profileWelcome;
  }

  void _prefillFromAccount() {
    final account = _auth.account;
    if (account == null) return;
    _email.text = account.email;
    _username.text = account.username;
    if (account.phone != null) _phone.text = account.phone!;
  }

  static String _guessTimezone() => DeviceContext.currentTimezone();

  @override
  void dispose() {
    _timer?.cancel();
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _phoneDebounce?.cancel();
    _displayName.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _phoneLocal.dispose();
    _password.dispose();
    _confirm.dispose();
    _identifier.dispose();
    _signInPassword.dispose();
    _otp.dispose();
    _emailInlineOtp.dispose();
    _phoneInlineOtp.dispose();
    _country.dispose();
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
    final pwError = validatePassword(_signInPassword.text, registering: false);
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
      final generic = lower.contains('network') || lower.contains('connect')
          ? raw
          : "Your sign-in details don't match. Check them and try again.";
      setState(() => _loginError = generic);
      return;
    }
    setState(() => _finishing = true);
    await _initializeHome();
    if (mounted) setState(() => _finishing = false);
  }

  Future<void> _signInWithGoogle() async {
    if (_googleBusy || _busy) return;
    setState(() {
      _googleBusy = true;
      _loginError = null;
    });
    try {
      final idToken = await _google.getIdToken();
      if (!mounted) return;
      if (idToken == null) return; // user dismissed the account picker
      final account = await _auth.loginWithGoogle(idToken);
      if (!mounted) return;
      if (account == null) {
        final error = _auth.lastError;
        setState(
          () => _loginError = error != null && error.statusCode == 503
              ? 'Google sign-in is unavailable right now. Please try again later.'
              : error != null && error.code == 'RATE_LIMITED'
              ? _friendly(error)
              : "Blistra couldn't verify your Google sign-in. Please try again.",
        );
        return;
      }
      if (_auth.justRegistered && _auth.needsOnboarding) {
        // Brand-new Google user — route to registration wizard (no email/password).
        setState(() {
          _googleRegistration = true;
          _email.text = account.email;
          _mode = _Mode.register;
          _reg = _Reg.singleForm;
        });
        return;
      }
      setState(() => _finishing = true);
      await _initializeHome();
      if (mounted) setState(() => _finishing = false);
    } on GoogleSignInUnavailable catch (error) {
      if (mounted) setState(() => _loginError = error.message);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
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
      setState(() => _screenError = 'Please enter a little more.');
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
      setState(() => _screenError = 'That email is already registered.');
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
      setState(() => _screenError = 'Enter your phone number to continue.');
      return false;
    }
    final full = '$_countryCode${local.replaceAll(RegExp(r'[\s\-().]'), '')}';
    final err = validatePhone(full);
    if (err != null) {
      setState(() => _screenError = 'Enter a valid phone number.');
      return false;
    }
    if (_phoneAvail == _Avail.taken) {
      setState(() => _screenError = 'That phone number is already registered.');
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
      setState(
        () => _usernameAvail = available == null
            ? _Avail.idle
            : available
            ? _Avail.available
            : _Avail.taken,
      );
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
      setState(
        () => _emailAvail = available == null
            ? _Avail.idle
            : available
            ? _Avail.available
            : _Avail.taken,
      );
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
    final full = '$_countryCode${local.replaceAll(RegExp(r'[\s\-().]'), '')}';
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
      setState(
        () => _phoneAvail = available == null
            ? _Avail.idle
            : available
            ? _Avail.available
            : _Avail.taken,
      );
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
      )).usernameAvailable;
    } catch (_) {
      available = null;
    }
    if (!mounted || gen != _usernameGen) return false;
    if (available == null) {
      setState(() => _usernameAvail = _Avail.idle);
      return true;
    }
    final bool usernameFree = available;
    setState(
      () => _usernameAvail = usernameFree ? _Avail.available : _Avail.taken,
    );
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
      )).emailAvailable;
    } catch (_) {
      available = null;
    }
    if (!mounted || gen != _emailGen) return false;
    if (available == null) {
      setState(() => _emailAvail = _Avail.idle);
      return true;
    }
    final bool emailFree = available;
    setState(() => _emailAvail = emailFree ? _Avail.available : _Avail.taken);
    if (!emailFree) {
      setState(() => _screenError = 'That email is already registered.');
    }
    return emailFree;
  }

  Future<bool> _ensurePhoneAvailable(String full) async {
    _phoneDebounce?.cancel();
    final gen = ++_phoneGen;
    setState(() => _phoneAvail = _Avail.checking);
    bool? available;
    try {
      available = (await widget.deps.apiClient.checkAvailability(phone: full))
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
    setState(() => _phoneAvail = phoneFree ? _Avail.available : _Avail.taken);
    if (!phoneFree) {
      setState(() => _screenError = 'That phone number is already registered.');
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
        return Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Checking…',
                style: TextStyle(fontSize: 13, color: AuthColors.muted),
              ),
            ],
          ),
        );
      case _Avail.available:
        return Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: AuthColors.teal),
              SizedBox(width: 6),
              Text(
                'Available',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.teal,
                ),
              ),
            ],
          ),
        );
      case _Avail.taken:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: AuthColors.error),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  takenMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  bool _checkPassword() {
    final err = validatePassword(_password.text, registering: true);
    if (err != null) {
      setState(() => _screenError = err);
      return false;
    }
    return true;
  }

  bool _checkConfirm() {
    final err = validatePasswordConfirmation(_confirm.text, _password.text);
    if (err != null) {
      setState(
        () => _screenError = err == 'Passwords do not match'
            ? "Passwords don't match."
            : err,
      );
      return false;
    }
    return true;
  }

  Future<void> _submitAccount({bool inline = false}) async {
    if (!_terms) {
      setState(
        () => _screenError =
            'Please agree to the Terms and Privacy Policy to continue.',
      );
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
      if (!inline) {
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
      }
      return;
    }
    _startCooldown(60);
    if (inline) {
      _emailInlineOtp.clear();
      setState(() => _emailOtpSent = true);
    } else if (_emailOtpVerified) {
      // Email was already verified inline before registration — skip OTP screen.
      _otp.clear();
      setState(() => _reg = _Reg.profileWelcome);
    } else {
      _otp.clear();
      setState(() => _reg = _Reg.emailOtp);
    }
  }

  Future<void> _sendEmailOtpFromForm() async {
    if (validateEmail(_email.text) != null) return;
    setState(() => _screenError = null);
    final cooldown = await _auth.sendPreRegEmailOtp(_email.text.trim());
    if (!mounted) return;
    if (cooldown == null) {
      setState(() => _screenError = _friendly(_auth.lastError));
      return;
    }
    _emailInlineOtp.clear();
    _startCooldown(cooldown);
    setState(() => _emailOtpSent = true);
  }

  Future<void> _verifyEmailOtpInline() async {
    final code = _emailInlineOtp.text;
    setState(() => _screenError = null);
    final ok = await _auth.verifyPreRegEmailOtp(_email.text.trim(), code);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _screenError = _otpFriendly(_auth.lastError);
        _emailInlineOtp.clear();
      });
      return;
    }
    setState(() => _emailOtpVerified = true);
  }

  Future<void> _resendEmailOtpFromForm() async {
    setState(() => _screenError = null);
    final cooldown = await _auth.sendPreRegEmailOtp(_email.text.trim());
    if (!mounted) return;
    if (cooldown == null) {
      setState(() => _screenError = _friendly(_auth.lastError));
      return;
    }
    _emailInlineOtp.clear();
    _startCooldown(cooldown);
  }

  Future<void> _sendPhoneOtpFromForm() async {
    // Phone OTP is optional; verification happens on the dedicated phoneOtp
    // screen after account creation. The inline UI here is a UX preview only.
    _phoneInlineOtp.clear();
    setState(() => _phoneOtpSent = true);
  }

  Future<void> _verifyPhoneOtpInline() async {
    setState(() => _phoneOtpVerified = true);
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
    if (AppConfig.requirePhoneVerification &&
        account.phone != null &&
        account.phone!.isNotEmpty &&
        !account.phoneVerified) {
      _startCooldown(60);
      setState(() => _reg = _Reg.phoneOtp);
    } else {
      setState(() => _reg = _Reg.profileWelcome);
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
    setState(() => _reg = _Reg.profileWelcome);
  }

  Future<void> _resend(bool email) async {
    setState(() => _screenError = null);
    final seconds = email
        ? await _auth.resendEmailOtp()
        : await _auth.resendPhoneOtp();
    if (!mounted) return;
    if (seconds == null) {
      final err = _auth.lastError;
      if (err != null && err.isRateLimited) {
        _startCooldown(err.retryAfterSeconds ?? 60);
        setState(
          () => _screenError =
              'Too many attempts. Try again in ${err.retryAfterSeconds ?? 60} seconds.',
        );
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
    if (code.contains('RATE') ||
        code.contains('LIMIT') ||
        error.isRateLimited) {
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

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      // On mobile, bytes may be null — read from path.
      bytes = await _readFilePath(file.path!);
    }
    if (bytes == null || !mounted) return;
    setState(() {
      _pendingAvatarBytes = bytes;
      _pendingAvatarFilename = file.name.isNotEmpty ? file.name : 'avatar.jpg';
    });
  }

  Future<Uint8List?> _readFilePath(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_dob == null) {
      setState(() => _screenError = 'Please pick your date of birth.');
      return;
    }
    final dobError = validateDateOfBirth(_dob);
    if (dobError != null) {
      setState(() => _screenError = dobError);
      return;
    }
    final countryError = validateCountry(_selectedCountryCode);
    if (countryError != null || countryForCode(_selectedCountryCode) == null) {
      setState(
        () => _screenError = countryError ?? 'Please select your country.',
      );
      return;
    }
    if (_timezone == null || _timezone!.isEmpty) {
      setState(
        () => _screenError = "Your device timezone couldn't be detected.",
      );
      return;
    }
    setState(() {
      _screenError = null;
      _saving = true;
    });
    final displayName = _displayName.text.trim().isEmpty
        ? '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim()
        : _displayName.text.trim();
    final ok = await widget.deps.profile.save({
      'displayName': displayName.isEmpty ? (_auth.account?.email ?? '') : displayName,
      'dateOfBirth':
          '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
      'country': _selectedCountryCode,
      'timezone': _timezone,
      'unitSystem': DeviceContext.defaultUnitSystemForCountry(
        _selectedCountryCode,
      ),
      if (_gender != null) 'gender': _gender,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(
        () => _screenError = widget.deps.profile.error ?? 'Could not save.',
      );
      return;
    }
    // Upload avatar in the background — non-blocking, failure is silently ignored.
    if (_pendingAvatarBytes != null) {
      try {
        await widget.deps.apiClient.uploadAvatar(
          _pendingAvatarBytes!,
          _pendingAvatarFilename,
        );
      } catch (_) {}
    }
    setState(() => _reg = _Reg.health);
  }

  Future<void> _saveHealth() async {
    final heightVal = double.tryParse(_height.text.trim());
    if (heightVal == null || heightVal < 50 || heightVal > 300) {
      setState(() => _screenError = 'Enter a valid height.');
      return;
    }
    final weightVal = double.tryParse(_weight.text.trim());
    if (weightVal == null || weightVal < 5 || weightVal > 900) {
      setState(() => _screenError = 'Enter a valid weight.');
      return;
    }
    setState(() {
      _screenError = null;
      _saving = true;
    });
    try {
      await widget.deps.health.saveProfile(
        HealthProfileInput(
          heightCm: _heightUnit == 'IN' ? heightVal * 2.54 : heightVal,
          bloodType: null,
          dateOfBirth: _dob,
        ),
      );
      await widget.deps.health.createMeasurement(
        MeasurementInput(
          type: MeasurementType.weight,
          measuredAt: DateTime.now(),
          value: weightVal,
          unit: _weightUnit,
          source: 'onboarding',
        ),
      );
      if (_dietPreference != null) {
        await widget.deps.diet.saveProfile(
          dietaryPreference: _dietPreference!.wireName,
          customPreference: null,
          dislikedFoods: '',
          notes: '',
        );
      }
      if (mounted) setState(() => _reg = _Reg.done);
    } catch (_) {
      if (mounted) {
        setState(
          () => _screenError =
              'We couldn\'t save your health details. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          _screenError = 'No verified recovery option on this account. Check your inbox for the verification code first.';
          _resolvingChannels = false;
        });
        return;
      }
      setState(() {
        _recoveryChannels = result.channels;
        _recoveryEmailMasked = result.emailMasked;
        _recoveryPhoneMasked = result.phoneMasked;
        _forgotChannel = result.offersEmail ? 'EMAIL' : 'SMS';
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
        _screenError = "Couldn't connect. Check your connection and try again.";
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
    final pwError = validatePassword(_forgotNew.text, registering: true);
    if (pwError != null) {
      setState(() => _screenError = pwError);
      return;
    }
    final confirmError = validatePasswordConfirmation(
      _forgotConfirm.text,
      _forgotNew.text,
    );
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
    final field =
        error.fieldErrors['email'] ??
        error.fieldErrors['username'] ??
        error.fieldErrors['phone'] ??
        error.fieldErrors['identifier'] ??
        error.fieldErrors['password'] ??
        error.fieldErrors['dateOfBirth'] ??
        error.fieldErrors['country'] ??
        error.fieldErrors['timezone'] ??
        error.fieldErrors['unitSystem'];
    if (field != null) return field;
    if (error.message.toLowerCase().contains('failed host') ||
        error.message.toLowerCase().contains('socket') ||
        error.message.toLowerCase().contains('network')) {
      return "Couldn't connect. Check your connection and try again.";
    }
    if (error.code == 'VALIDATION_ERROR') {
      return "We couldn't save your details. Please try again.";
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
    final shown = local.length <= 2
        ? '$local•••'
        : '${local.substring(0, 2)}•••';
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
    return ChangeNotifierProvider<ThemeController>.value(
      value: widget.deps.theme,
      child: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) {
          // Depend on the theme so the screen repaints when light/dark or the
          // accent changes (AuthColors reads the active theme).
          Theme.of(context);
          if (_mode == _Mode.signIn) return _loginScreen();
          if (_mode == _Mode.forgot) return _forgotScreen();
          return _registerScreen();
        },
      ),
    );
  }

  // ═══════════════════════ LOGIN ═══════════════════════

  Widget _loginScreen() {
    final canSignIn = _identifier.text.isNotEmpty && _signInPassword.text.isNotEmpty;
    return AuthScaffold(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: canSignIn ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: AuthPrimaryButton(
              label: 'Sign in',
              busy: _busy,
              onPressed: _signIn,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: AuthColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(color: AuthColors.muted, fontSize: 13),
                ),
              ),
              Expanded(child: Divider(color: AuthColors.border)),
            ],
          ),
          const SizedBox(height: 16),
          _googleButton(),
          const SizedBox(height: 10),
          Text(
            'By continuing with Google you agree to the Terms and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AuthColors.muted, fontSize: 11.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  BlistraMark(size: 32),
                  const SizedBox(width: 8),
                  Text(
                    'Blistra',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.ink,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() {
                  _loginError = null;
                  _screenError = null;
                  _mode = _Mode.register;
                  _reg = _Reg.welcome;
                }),
                child: Text(
                  'Create account',
                  style: TextStyle(
                    color: AuthColors.teal,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: AuthColors.ink,
              ),
              children: [
                const TextSpan(text: 'Welcome '),
                TextSpan(
                  text: 'back.',
                  style: TextStyle(color: AuthColors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 36),
          _underlineField(
            label: 'EMAIL OR USERNAME',
            controller: _identifier,
            hint: 'Enter your email or username',
            keyboardType: TextInputType.text,
            autofillHints: const ['username'],
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: 24),
          _underlineField(
            label: 'PASSWORD',
            controller: _signInPassword,
            hint: 'Enter your password',
            obscure: !_showSignInPw,
            autofillHints: const ['password'],
            onSubmitted: (_) => _signIn(),
            suffix: IconButton(
              tooltip: _showSignInPw ? 'Hide' : 'Show',
              onPressed: () =>
                  setState(() => _showSignInPw = !_showSignInPw),
              icon: Icon(
                _showSignInPw
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AuthColors.muted,
              ),
            ),
          ),
          if (_loginError != null) ...[
            const SizedBox(height: 14),
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
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: AuthColors.teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: AuthColors.border, width: 1),
        ),
        onPressed: _googleBusy || _busy ? null : _signInWithGoogle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_googleBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _googleLogo(),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AuthColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _googleLogo() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  // ═══════════════════════ REGISTRATION ═══════════════════════

  Widget _registerScreen() {
    return switch (_reg) {
      _Reg.welcome => _welcomeScreen(),
      _Reg.singleForm => _singleFormScreen(),
      _Reg.profileWelcome => _profileWelcomeScreen(),
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
            _availRow(_usernameAvail, takenMessage: 'Username already taken.'),
            const SizedBox(height: 8),
            Text(
              '3–30 letters, digits, _ or .',
              style: TextStyle(fontSize: 12.5, color: AuthColors.muted),
            ),
          ],
        ),
        cta: 'Continue',
        onCta: _submitUsername,
      ),
      _Reg.email => _questionScreen(
        step: 3,
        title: "What's your email?",
        subtitle: "We'll use this for verification and account recovery.",
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
            _availRow(
              _emailAvail,
              takenMessage: 'That email is already registered.',
            ),
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
            tooltip: _showConfirm ? 'Hide password' : 'Show password',
            onPressed: () => setState(() => _showConfirm = !_showConfirm),
            icon: Icon(
              _showConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AuthColors.muted,
            ),
          ),
          onSubmitted: (_) => _submitConfirm(),
        ),
        cta: 'Continue',
        onCta: _submitConfirm,
      ),
      _Reg.review => _reviewScreen(),
      _Reg.emailOtp => _otpScreen(
        email: true,
        onBack: () => _backTo(_Reg.review),
      ),
      _Reg.phoneOtp => _otpScreen(
        email: false,
        onBack: () => _backTo(_Reg.emailOtp),
      ),
      _Reg.profile => _profileSetupScreen(),
      _Reg.health => _healthSetupScreen(),
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

  Future<void> _submitSingleForm() async {
    if (_googleRegistration) {
      await _submitGoogleSingleForm();
      return;
    }
    // Combine first + last name into displayName.
    _displayName.text =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    if (!_checkName()) return;
    if (!_checkUsername()) return;
    if (!await _ensureUsernameAvailable()) return;
    if (!mounted) return;
    if (!_checkEmail()) return;
    if (!await _ensureEmailAvailable()) return;
    if (!mounted) return;
    if (!_checkPassword()) return;
    if (!_checkConfirm()) return;
    // Implicit terms acceptance shown via footer text.
    _terms = true;
    await _submitAccount();
  }

  /// Registration path for Google sign-in: account already exists, email
  /// already verified. We just collect name, username, and (optionally) phone,
  /// then update the profile before moving to profile/health onboarding.
  Future<void> _submitGoogleSingleForm() async {
    _displayName.text =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    if (!_checkName()) return;
    if (!_checkUsername()) return;
    if (!await _ensureUsernameAvailable()) return;
    if (!mounted) return;
    _checkPhone(); // build _phone.text from _phoneLocal (allowEmpty = true)
    setState(() {
      _screenError = null;
      _saving = true;
    });
    final ok = await widget.deps.profile.save({
      'displayName': _displayName.text.trim(),
      'username': _username.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(
        () => _screenError =
            widget.deps.profile.error ?? 'Could not save. Please try again.',
      );
      return;
    }
    // Email is already verified by Google — skip OTP, go straight to profile.
    setState(() => _reg = _Reg.profileWelcome);
  }

  Widget _welcomeScreen() {
    const moduleColors = [
      Color(0xFF1FB99A),
      Color(0xFFFF5D7A),
      Color(0xFF4A8CFF),
      Color(0xFFFF9A3D),
      Color(0xFF8B6BFF),
      Color(0xFFE8B230),
    ];
    return AuthScaffold(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
            label: 'Get started',
            onPressed: () => _next(_Reg.singleForm),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _screenError = null;
                _mode = _Mode.signIn;
              }),
              child: Text(
                'Have an account? Sign in',
                style: TextStyle(
                  color: AuthColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              BlistraMark(size: 36),
              const SizedBox(width: 10),
              Text(
                'Blistra',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: AuthColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'YOUR PERSONAL OS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: AuthColors.teal,
            ),
          ),
          const SizedBox(height: 28),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 40,
                height: 1.08,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                color: AuthColors.ink,
              ),
              children: [
                const TextSpan(text: 'Everything you need.\n'),
                TextSpan(
                  text: 'One app.',
                  style: TextStyle(color: AuthColors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Planner · Health · Habits\nFinance · Diet · Medicines',
            style: TextStyle(fontSize: 13, color: AuthColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final c in moduleColors) ...[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          const SizedBox(height: 100),
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
      bottom: AuthPrimaryButton(label: cta, busy: _busy, onPressed: onCta),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthProgress(step: step, total: 7),
          const SizedBox(height: 28),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
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
        label: 'Continue',
        busy: _busy,
        onPressed: _submitPhone,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthProgress(step: 4, total: 7),
          const SizedBox(height: 28),
          Text(
            "What's your phone number?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll use this to verify your account and help you recover it. Optional — you can skip.",
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AuthColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dialCodes.contains(_countryCode)
                        ? _countryCode
                        : _dialCodes.first,
                    items: [
                      for (final c in _dialCodes)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (c) {
                      setState(() => _countryCode = c ?? '+91');
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
          _availRow(
            _phoneAvail,
            takenMessage: 'That phone number is already registered.',
          ),
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
            child: Text(
              'Skip for now',
              style: TextStyle(
                color: AuthColors.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        onPressed: _submitPassword,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthProgress(step: 5, total: 7),
          const SizedBox(height: 28),
          Text(
            'Create a password',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your account secure.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _password,
            hint: 'Password',
            obscure: !_showPw,
            autofillHints: const ['newPassword'],
            autofocus: true,
            semanticLabel: 'Password',
            suffix: IconButton(
              tooltip: _showPw ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPw = !_showPw),
              icon: Icon(
                _showPw
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AuthColors.muted,
              ),
            ),
            onSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 12),
          PasswordStrength(password: _password.text),
          const SizedBox(height: 12),
          _requirement('8+ characters', _password.text.length >= 8),
          _requirement(
            'At least one letter',
            RegExp(r'[A-Za-z]').hasMatch(_password.text),
          ),
          _requirement(
            'At least one digit',
            RegExp(r'[0-9]').hasMatch(_password.text),
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

  Widget _requirement(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? AuthColors.teal : AuthColors.muted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: met ? AuthColors.muted : AuthColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewScreen() {
    final busy = _auth.status == AuthStatus.busy || _finishing;
    return AuthScaffold(
      onBack: busy ? null : () => _backTo(_Reg.confirm),
      bottom: AuthPrimaryButton(
        label: 'Create account',
        busy: busy,
        onPressed: _submitAccount,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthProgress(step: 7, total: 7),
          const SizedBox(height: 28),
          Text(
            'Almost there.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your details before we create your account.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 20),
          _reviewRow(
            'Name',
            _displayName.text.trim(),
            () => _backTo(_Reg.name),
          ),
          _reviewRow(
            'Username',
            '@${_username.text.trim()}',
            () => _backTo(_Reg.username),
          ),
          _reviewRow('Email', _email.text.trim(), () => _backTo(_Reg.email)),
          _reviewRow(
            'Phone',
            _phone.text.trim().isEmpty ? '—' : _phone.text.trim(),
            () => _backTo(_Reg.phone),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: busy ? null : () => setState(() => _terms = !_terms),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AuthColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _terms,
                    activeColor: AuthColors.teal,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _terms = v ?? false),
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
              message:
                  _screenError ??
                  _emailTakenError ??
                  _usernameTakenError ??
                  _phoneTakenError ??
                  'Something went wrong.',
            ),
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
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuthColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AuthColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.ink,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }

  // ── OTP screens ──────────────────────────────────────────────

  Widget _otpScreen({required bool email, required VoidCallback onBack}) {
    final busy = _auth.status == AuthStatus.busy || _otpSubmitting;
    final destination = email ? _maskedEmail : _maskedPhone;
    return AuthScaffold(
      onBack: busy ? null : onBack,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
            label: 'Verify',
            busy: busy,
            onPressed: email ? _verifyEmailOtp : _verifyPhoneOtp,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: (busy || _cooldown > 0) ? null : () => _resend(email),
              child: Text(
                _cooldown > 0
                    ? 'Resend code in ${_cooldown}s'
                    : "Didn't receive it? Resend code",
                style: TextStyle(
                  color: AuthColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            email ? 'Verify your email' : 'Verify your phone',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check for a 6-digit code at\n$destination\nDelivery may take a minute.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 28),
          OtpInput(
            controller: _otp,
            enabled: !busy,
            onCompleted: email ? _verifyEmailOtp : _verifyPhoneOtp,
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

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Widget _doneScreen() {
    const moduleColors = [
      Color(0xFF1FB99A),
      Color(0xFFFF5D7A),
      Color(0xFF4A8CFF),
      Color(0xFFFF9A3D),
      Color(0xFF8B6BFF),
      Color(0xFFE8B230),
    ];
    return AuthScaffold(
      bottom: AuthPrimaryButton(
        label: 'Go to Blistra →',
        busy: _finishing,
        onPressed: _completeOnboarding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Module dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in moduleColors)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Checkmark ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AuthColors.teal.withValues(alpha: 0.10),
              border: Border.all(color: AuthColors.teal, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AuthColors.teal.withValues(alpha: 0.20),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: _finishing
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AuthColors.teal),
                  )
                : Icon(Icons.check, size: 36, color: AuthColors.teal),
          ),
          const SizedBox(height: 20),

          // Eyebrow
          Text(
            "YOU'RE ALL SET!",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.10,
              color: AuthColors.teal,
            ),
          ),
          const SizedBox(height: 12),

          // Heading
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AuthColors.ink,
                height: 1.1,
              ),
              children: [
                const TextSpan(text: 'Blistra is '),
                TextSpan(
                  text: 'ready',
                  style: TextStyle(color: AuthColors.teal),
                ),
                const TextSpan(text: '\nfor you.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your profile is complete.\nAll modules are unlocked.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AuthColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Stats card
          Container(
            decoration: BoxDecoration(
              color: AuthColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuthColors.border),
            ),
            child: Row(
              children: [
                _statItem('6', 'Modules', false),
                Container(width: 1, height: 48, color: AuthColors.border),
                _statItem('∞', 'Possibilities', true),
                Container(width: 1, height: 48, color: AuthColors.border),
                _statItem('100%', 'Done', false),
              ],
            ),
          ),

          if (_screenError != null) ...[
            const SizedBox(height: 14),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, bool accent) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: accent ? AuthColors.teal : AuthColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.08,
                color: AuthColors.muted,
              ),
            ),
          ],
        ),
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
    final busy = _auth.status == AuthStatus.busy || _resolvingChannels;
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
        onPressed: _forgotResolveIdentifier,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Forgot your password?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your username, email, or phone.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
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
    final offersSms =
        _recoveryChannels.contains('SMS') ||
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
        onPressed: _forgotSendCode,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Where should we send your code?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only verified destinations are shown. We never show full contact details here.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 20),
          if (offersEmail)
            _channelCard(
              'Email',
              _recoveryEmailMasked ?? 'Send to your email address',
              'EMAIL',
            ),
          if (offersEmail && offersSms) const SizedBox(height: 10),
          if (offersSms)
            _channelCard(
              'Phone (SMS)',
              _recoveryPhoneMasked ?? 'Send to your phone number',
              'SMS',
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

  Widget _channelCard(String title, String subtitle, String value) {
    final selected = _forgotChannel == value;
    return InkWell(
      onTap: () => setState(() => _forgotChannel = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AuthColors.teal : AuthColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value == 'EMAIL' ? Icons.mail_outline : Icons.sms_outlined,
              color: selected ? AuthColors.teal : AuthColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AuthColors.muted),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AuthColors.teal : AuthColors.muted,
            ),
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
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "Verify it's you",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A code was sent to your verified destination. Enter it below.',
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          const SizedBox(height: 28),
          OtpInput(
            controller: _forgotCode,
            onCompleted: () => setState(() => _forgot = _Forgot.reset),
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
        onPressed: _forgotSubmitNewPassword,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Create a new password',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AuthColors.ink,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _forgotNew,
            hint: 'New password',
            obscure: !_showForgotNew,
            autofillHints: const ['newPassword'],
            autofocus: true,
            semanticLabel: 'New password',
            suffix: IconButton(
              tooltip: _showForgotNew ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showForgotNew = !_showForgotNew),
              icon: Icon(
                _showForgotNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AuthColors.muted,
              ),
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
        }),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 48),
          Icon(Icons.check_circle, size: 72, color: AuthColors.teal),
          SizedBox(height: 20),
          Text(
            'Password updated',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AuthColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You can now sign in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AuthColors.muted),
          ),
          SizedBox(height: 120),
        ],
      ),
    );
  }

  // ══════════════ UNDERLINE FIELD HELPER ══════════════

  Widget _underlineField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    bool autofocus = false,
    bool readOnly = false,
    Iterable<String>? autofillHints,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? prefix,
    bool active = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10,
            color: active ? AuthColors.teal : AuthColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (prefix != null)
              Text(
                prefix,
                style: TextStyle(fontSize: 20, color: AuthColors.muted),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscure,
                autofocus: autofocus,
                readOnly: readOnly,
                autocorrect: false,
                autofillHints: autofillHints,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: AuthColors.muted.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            ?suffix,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1.5,
          color: active ? AuthColors.teal : AuthColors.border,
        ),
      ],
    );
  }

  // ══════════════ SINGLE FORM REGISTRATION ══════════════

  Widget _singleFormScreen() {
    final busy = _busy;
    final canCreate = _googleRegistration
        ? (_email.text.isNotEmpty &&
            _username.text.isNotEmpty &&
            (_firstNameCtrl.text.isNotEmpty || _lastNameCtrl.text.isNotEmpty))
        : (_password.text.isNotEmpty &&
            _confirm.text.isNotEmpty &&
            _email.text.isNotEmpty &&
            _username.text.isNotEmpty &&
            (_firstNameCtrl.text.isNotEmpty || _lastNameCtrl.text.isNotEmpty));

    return AuthScaffold(
      stickyHeader: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nav row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  BlistraMark(size: 30),
                  const SizedBox(width: 8),
                  Text(
                    'Blistra',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.ink,
                    ),
                  ),
                ],
              ),
              if (!_googleRegistration)
                TextButton(
                  onPressed: () => setState(() {
                    _screenError = null;
                    _mode = _Mode.signIn;
                  }),
                  child: Text(
                    'Sign in',
                    style: TextStyle(
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AuthColors.ink,
              ),
              children: [
                if (_googleRegistration) ...[
                  const TextSpan(text: 'Finish setting '),
                  TextSpan(
                    text: 'up.',
                    style: TextStyle(color: AuthColors.teal),
                  ),
                ] else ...[
                  const TextSpan(text: 'Create your '),
                  TextSpan(
                    text: 'account.',
                    style: TextStyle(color: AuthColors.teal),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _googleRegistration
                ? 'Just a few more details.'
                : 'Takes about 2 minutes.',
            style: TextStyle(fontSize: 14, color: AuthColors.muted),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: canCreate ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: AuthPrimaryButton(
              label: _googleRegistration ? 'Continue' : 'Create account',
              busy: busy,
              onPressed: canCreate ? _submitSingleForm : null,
            ),
          ),
          const SizedBox(height: 8),
          if (!_googleRegistration)
            Center(
              child: Text(
                'By tapping Create account, you agree to our Terms & Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AuthColors.muted),
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WHO ARE YOU?
          _sectionLabel('WHO ARE YOU?'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _underlineField(
                  label: 'FIRST NAME',
                  controller: _firstNameCtrl,
                  hint: 'First',
                  keyboardType: TextInputType.name,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _underlineField(
                  label: 'LAST NAME',
                  controller: _lastNameCtrl,
                  hint: 'Last',
                  keyboardType: TextInputType.name,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _underlineField(
            label: 'USERNAME',
            controller: _username,
            hint: 'yourname',
            prefix: '@',
            keyboardType: TextInputType.text,
            onChanged: _scheduleUsernameCheck,
          ),
          _availRow(_usernameAvail, takenMessage: 'Username already taken.'),
          const SizedBox(height: 32),

          // CONTACT
          _sectionLabel('CONTACT'),
          const SizedBox(height: 16),
          if (_googleRegistration) ...[
            // Email is provided and verified by Google — show read-only badge.
            _googleEmailRow(),
            const SizedBox(height: 24),
            _phoneRow(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _underlineField(
                    label: 'EMAIL',
                    controller: _email,
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const ['email'],
                    readOnly: _emailOtpSent,
                    active: _emailOtpVerified,
                    onChanged: (v) {
                      _scheduleEmailCheck(v);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _sendOtpButton(
                  sent: _emailOtpSent,
                  verified: _emailOtpVerified,
                  enabled: !_emailOtpSent && validateEmail(_email.text) == null,
                  onTap: _sendEmailOtpFromForm,
                ),
              ],
            ),
            _availRow(_emailAvail, takenMessage: 'Email already registered.'),
            if (_emailOtpSent && !_emailOtpVerified) ...[
              const SizedBox(height: 16),
              OtpInput(
                controller: _emailInlineOtp,
                onCompleted: _verifyEmailOtpInline,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _resendEmailOtpFromForm,
                  child: Text(
                    "Didn't get it? Resend",
                    style: TextStyle(
                      fontSize: 12,
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _phoneRow(),
            if (_phoneOtpSent && !_phoneOtpVerified) ...[
              const SizedBox(height: 16),
              OtpInput(
                controller: _phoneInlineOtp,
                onCompleted: _verifyPhoneOtpInline,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _phoneOtpSent = false;
                    _phoneInlineOtp.clear();
                  }),
                  child: Text(
                    "Didn't get it? Resend",
                    style: TextStyle(
                      fontSize: 12,
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // SECURITY — only for regular (non-Google) registration.
            _sectionLabel('SECURITY'),
            const SizedBox(height: 16),
            _underlineField(
              label: 'PASSWORD',
              controller: _password,
              hint: 'At least 8 characters',
              obscure: !_showPw,
              autofillHints: const ['newPassword'],
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                tooltip: _showPw ? 'Hide' : 'Show',
                onPressed: () => setState(() => _showPw = !_showPw),
                icon: Icon(
                  _showPw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AuthColors.muted,
                ),
              ),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              PasswordStrength(password: _password.text),
            ],
            const SizedBox(height: 24),
            _underlineField(
              label: 'CONFIRM PASSWORD',
              controller: _confirm,
              hint: 'Repeat password',
              obscure: !_showConfirm,
              autofillHints: const ['newPassword'],
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                tooltip: _showConfirm ? 'Hide' : 'Show',
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AuthColors.muted,
                ),
              ),
            ),
            if (_confirm.text.isNotEmpty &&
                _password.text == _confirm.text) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AuthColors.teal),
                  const SizedBox(width: 6),
                  Text(
                    'Passwords match',
                    style: TextStyle(
                      fontSize: 12,
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (_screenError != null) ...[
            const SizedBox(height: 14),
            InlineError(message: _screenError!),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.10,
        color: AuthColors.muted,
      ),
    );
  }

  Widget _googleEmailRow() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AuthColors.border, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EMAIL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.10,
              color: AuthColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _email.text,
                  style: TextStyle(fontSize: 16, color: AuthColors.ink),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: AuthColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Verified by Google',
                    style: TextStyle(
                      fontSize: 12,
                      color: AuthColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phoneRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () async {
            // Reuse existing country picker.
          },
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AuthColors.border, width: 1.5),
              ),
            ),
            child: Text(
              _countryCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AuthColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _underlineField(
            label: 'PHONE (OPTIONAL)',
            controller: _phoneLocal,
            hint: 'Phone number',
            keyboardType: TextInputType.phone,
            readOnly: _phoneOtpSent,
            active: _phoneOtpVerified,
            onChanged: (_) {
              _schedulePhoneCheck();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 10),
        _sendOtpButton(
          sent: _phoneOtpSent,
          verified: _phoneOtpVerified,
          enabled: !_phoneOtpSent && _phoneLocal.text.trim().isNotEmpty,
          onTap: _sendPhoneOtpFromForm,
        ),
      ],
    );
  }

  Widget _sendOtpButton({
    required bool sent,
    required bool enabled,
    required VoidCallback onTap,
    bool verified = false,
  }) {
    if (verified) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 14, color: AuthColors.teal),
            const SizedBox(width: 4),
            Text(
              'Verified',
              style: TextStyle(
                fontSize: 12,
                color: AuthColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (sent) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AuthColors.teal),
            const SizedBox(width: 4),
            Text(
              'Sent',
              style: TextStyle(
                fontSize: 12,
                color: AuthColors.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: AuthColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AuthColors.teal.withValues(alpha: 0.35)),
            ),
            child: Text(
              'Send OTP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AuthColors.teal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════ PROFILE WELCOME ══════════════

  Widget _profileWelcomeScreen() {
    final String name;
    if (_firstNameCtrl.text.trim().isNotEmpty) {
      name = _firstNameCtrl.text.trim();
    } else if (_auth.account?.email != null) {
      name = _auth.account!.email.split('@').first;
    } else if (_displayName.text.trim().isNotEmpty) {
      name = _displayName.text.split(' ').first;
    } else {
      name = 'there';
    }
    return AuthScaffold(
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
            label: 'Complete profile →',
            onPressed: () => setState(() => _reg = _Reg.profile),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _reg = _Reg.done),
              child: Text(
                'Do this later',
                style: TextStyle(
                  color: AuthColors.muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'WELCOME TO BLISTRA 🎉',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: AuthColors.teal,
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AuthColors.ink,
                height: 1.15,
              ),
              children: [
                TextSpan(text: 'Hey $name,\nlet\'s set up '),
                TextSpan(
                  text: 'your profile.',
                  style: TextStyle(color: AuthColors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Takes 2 minutes. Helps us personalise Health, Diet and Habits for you.',
            style: TextStyle(fontSize: 14, color: AuthColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoPill('📸 Photo'),
              _infoPill('🎂 Birthday'),
              _infoPill('⚖️ Height & weight'),
              _infoPill('🎯 Goals'),
            ],
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _infoPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AuthColors.teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthColors.teal.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AuthColors.teal,
        ),
      ),
    );
  }

  // ══════════════ PROFILE SETUP ══════════════

  Widget _profileSetupScreen() {
    final dobText = _dob == null
        ? null
        : '${_dob!.day} ${_months[_dob!.month - 1]} ${_dob!.year}';
    final canContinue = _dob != null && _gender != null;

    return AuthScaffold(
      onBack: _busy ? null : () => _backTo(_Reg.profileWelcome),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: canContinue ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: AuthPrimaryButton(
              label: 'Continue',
              busy: _saving,
              onPressed: canContinue ? _saveProfile : null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Text(
                'Profile 1 of 2',
                style: TextStyle(fontSize: 13, color: AuthColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: 0.5,
            minHeight: 3,
            backgroundColor: AuthColors.border,
            valueColor: AlwaysStoppedAnimation(AuthColors.teal),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AuthColors.ink,
              ),
              children: [
                const TextSpan(text: 'Your '),
                TextSpan(
                  text: 'profile.',
                  style: TextStyle(color: AuthColors.teal),
                ),
              ],
            ),
          ),
          Text(
            'Help us personalize Blistra for you.',
            style: TextStyle(fontSize: 14, color: AuthColors.muted),
          ),
          const SizedBox(height: 32),

          // Avatar picker
          GestureDetector(
            onTap: _pickAvatar,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      painter: _DashedCirclePainter(
                        color: _pendingAvatarBytes != null
                            ? AuthColors.teal
                            : AuthColors.teal.withValues(alpha: 0.5),
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AuthColors.teal.withValues(alpha: 0.08),
                        ),
                        child: ClipOval(
                          child: _pendingAvatarBytes != null
                              ? Image.memory(
                                  _pendingAvatarBytes!,
                                  fit: BoxFit.cover,
                                  width: 72,
                                  height: 72,
                                )
                              : Center(
                                  child: Text(
                                    () {
                                      final name = _displayName.text.isNotEmpty
                                          ? _displayName.text
                                          : '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim();
                                      return name.isNotEmpty ? name[0].toUpperCase() : '';
                                    }(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AuthColors.teal,
                                      height: 1,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AuthColors.teal,
                          border: Border.all(
                            color: AuthColors.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName.text.isNotEmpty
                          ? _displayName.text
                          : '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pendingAvatarBytes != null ? 'Tap to change photo' : 'Tap to add photo',
                      style: TextStyle(
                        fontSize: 13,
                        color: AuthColors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Date of birth
          GestureDetector(
            onTap: _showDobSheet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATE OF BIRTH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.10,
                    color: _dob != null ? AuthColors.teal : AuthColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dobText ?? 'Tap to select',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: dobText != null
                              ? AuthColors.ink
                              : AuthColors.muted.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                      color: AuthColors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 1.5,
                  color: _dob != null
                      ? AuthColors.teal.withValues(alpha: 0.5)
                      : AuthColors.border,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Gender
          Text(
            'GENDER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.10,
              color: AuthColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _genderChip('Male', 'MALE'),
              _genderChip('Female', 'FEMALE'),
              _genderChip('Non-binary', 'NON_BINARY'),
              _genderChip('Prefer not to say', 'PREFER_NOT_TO_SAY'),
            ],
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

  Widget _genderChip(String label, String value) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AuthColors.teal.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AuthColors.teal.withValues(alpha: 0.4)
                : AuthColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AuthColors.teal : AuthColors.muted,
          ),
        ),
      ),
    );
  }

  void _showDobSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DobSheet(
        initialDate: _dob,
        onConfirm: (date) {
          setState(() => _dob = date);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ══════════════ HEALTH SETUP ══════════════

  Widget _healthSetupScreen() {
    final heightFilled = _height.text.isNotEmpty;
    final weightFilled = _weight.text.isNotEmpty;
    final canFinish = heightFilled && weightFilled && _activityLevel != null;

    return AuthScaffold(
      onBack: _busy ? null : () => _backTo(_Reg.profile),
      bottom: AnimatedOpacity(
        opacity: canFinish ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: AuthPrimaryButton(
          label: 'Finish setup →',
          busy: _saving,
          onPressed: canFinish ? _saveHealth : null,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Text(
                'Profile 2 of 2',
                style: TextStyle(fontSize: 13, color: AuthColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: canFinish ? 1.0 : 0.75,
            minHeight: 3,
            backgroundColor: AuthColors.border,
            valueColor: AlwaysStoppedAnimation(AuthColors.teal),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AuthColors.ink,
              ),
              children: [
                const TextSpan(text: 'Your '),
                TextSpan(
                  text: 'health.',
                  style: TextStyle(color: AuthColors.teal),
                ),
              ],
            ),
          ),
          Text(
            'Used for Health, Diet & Habits modules.',
            style: TextStyle(fontSize: 14, color: AuthColors.muted),
          ),
          const SizedBox(height: 32),

          // Height
          _healthMeasureField(
            label: 'HEIGHT',
            controller: _height,
            hint: 'Enter height',
            unit: _heightUnit.toLowerCase(),
            unitA: 'cm',
            unitB: 'ft',
            activeUnit: _heightUnit == 'CM' ? 'cm' : 'ft',
            onToggle: (u) => setState(() {
              _heightUnit = u == 'cm' ? 'CM' : 'IN';
            }),
          ),
          const SizedBox(height: 24),

          // Weight
          _healthMeasureField(
            label: 'WEIGHT',
            controller: _weight,
            hint: 'Enter weight',
            unit: _weightUnit.toLowerCase(),
            unitA: 'kg',
            unitB: 'lbs',
            activeUnit: _weightUnit == 'KG' ? 'kg' : 'lbs',
            onToggle: (u) => setState(() {
              _weightUnit = u == 'kg' ? 'KG' : 'LB';
            }),
          ),
          const SizedBox(height: 28),

          // Activity
          _sectionLabel('ACTIVITY LEVEL'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _activityChip('🛋 Sedentary', 'SEDENTARY'),
              _activityChip('🚶 Light', 'LIGHT'),
              _activityChip('🏋 Moderate', 'MODERATE'),
              _activityChip('🏃 Very active', 'VERY_ACTIVE'),
            ],
          ),
          const SizedBox(height: 28),

          // Goals
          _sectionLabel('GOALS'),
          const SizedBox(height: 4),
          Text(
            'Pick any that apply',
            style: TextStyle(fontSize: 12, color: AuthColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _goalChip('💪 Build muscle', 'BUILD_MUSCLE'),
              _goalChip('🏃 Lose weight', 'LOSE_WEIGHT'),
              _goalChip('😴 Better sleep', 'BETTER_SLEEP'),
              _goalChip('❤️ Heart health', 'HEART_HEALTH'),
              _goalChip('🧘 Reduce stress', 'REDUCE_STRESS'),
              _goalChip('⚡ More energy', 'MORE_ENERGY'),
            ],
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

  Widget _healthMeasureField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String unit,
    required String unitA,
    required String unitB,
    required String activeUnit,
    required ValueChanged<String> onToggle,
  }) {
    final active = controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10,
            color: active ? AuthColors.teal : AuthColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AuthColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 20,
                    color: AuthColors.muted.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            if (active)
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.teal,
                ),
              ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AuthColors.teal.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [unitA, unitB].map((u) {
                  final isActive = u == activeUnit;
                  return GestureDetector(
                    onTap: () => onToggle(u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AuthColors.teal.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        u,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AuthColors.teal
                              : AuthColors.muted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1.5,
          color:
              active ? AuthColors.teal.withValues(alpha: 0.5) : AuthColors.border,
        ),
      ],
    );
  }

  Widget _activityChip(String label, String value) {
    final selected = _activityLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AuthColors.teal.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AuthColors.teal.withValues(alpha: 0.4)
                : AuthColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AuthColors.teal : AuthColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _goalChip(String label, String value) {
    final selected = _selectedGoals.contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedGoals.remove(value);
        } else {
          _selectedGoals.add(value);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AuthColors.teal.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AuthColors.teal.withValues(alpha: 0.4)
                : AuthColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AuthColors.teal : AuthColors.muted,
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Simplified Google "G" logo using colored arcs.
    const colors = [
      Color(0xFF4285F4), // Blue
      Color(0xFFEA4335), // Red
      Color(0xFFFBBC05), // Yellow
      Color(0xFF34A853), // Green
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.28;

    final angles = [
      [0.0, 1.57],
      [1.57, 1.57],
      [3.14, 1.57],
      [4.71, 1.57],
    ];

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
        angles[i][0],
        angles[i][1],
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashCount = 14;
    const sweepPerDash = (2 * 3.14159265) / dashCount;
    final radius = (size.shortestSide / 2) - 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepPerDash,
        sweepPerDash * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}

class _DobSheet extends StatefulWidget {
  const _DobSheet({this.initialDate, required this.onConfirm});

  final DateTime? initialDate;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_DobSheet> createState() => _DobSheetState();
}

class _DobSheetState extends State<_DobSheet> {
  late DateTime _viewing;
  DateTime? _selected;
  bool _manualMode = false;
  final _manualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    final now = DateTime.now();
    _viewing = _selected ?? DateTime(now.year - 25, now.month, 1);
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  DateTime? _parseManual(String v) {
    final parts = v.trim().split(RegExp(r'[/\-\.]'));
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900) return null;
    try { return DateTime(y, m, d); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    if (_manualMode) return _buildManualEntry(context);

    final daysInMonth =
        DateTime(_viewing.year, _viewing.month + 1, 0).day;
    final firstWeekday =
        DateTime(_viewing.year, _viewing.month, 1).weekday % 7;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            // "Enter manually" top-right link
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _manualMode = true),
                    child: Text(
                      'Enter manually',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AuthColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Month navigator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _viewing = DateTime(
                          _viewing.year, _viewing.month - 1, 1);
                    }),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_viewing.month - 1]} ${_viewing.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _viewing = DateTime(
                          _viewing.year, _viewing.month + 1, 1);
                    }),
                  ),
                ],
              ),
            ),
            // Day grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AuthColors.muted,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: firstWeekday + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < firstWeekday) return const SizedBox();
                    final day = index - firstWeekday + 1;
                    final date =
                        DateTime(_viewing.year, _viewing.month, day);
                    final isSel = _selected != null &&
                        _selected!.year == date.year &&
                        _selected!.month == date.month &&
                        _selected!.day == date.day;
                    final isToday = date.year == DateTime.now().year &&
                        date.month == DateTime.now().month &&
                        date.day == DateTime.now().day;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = date),
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel
                                ? AuthColors.teal
                                : isToday
                                    ? AuthColors.teal.withValues(alpha: 0.12)
                                    : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSel
                                    ? Colors.white
                                    : AuthColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AuthColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _selected == null
                      ? null
                      : () => widget.onConfirm(_selected!),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enter date',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AuthColors.ink,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _manualMode = false),
                    child: Text(
                      'Back to calendar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AuthColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _manualCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'DD/MM/YYYY',
                  hintStyle: TextStyle(color: AuthColors.muted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AuthColors.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AuthColors.teal, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AuthColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final date = _parseManual(_manualCtrl.text);
                    if (date != null) widget.onConfirm(date);
                  },
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker();

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(_query.text);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final country = results[index];
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(country.name),
                    trailing: Text(
                      country.code,
                      style: TextStyle(color: AuthColors.muted),
                    ),
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('By creating your account, you agree to our'),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PolicyScreen(privacy: false),
            ),
          ),
          child: const Text('Terms'),
        ),
        const Text('and'),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PolicyScreen(privacy: true),
            ),
          ),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}
