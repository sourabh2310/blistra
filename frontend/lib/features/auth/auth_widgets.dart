/// Premium, reusable authentication components in the Blistra design language.
///
/// Warm off-white surfaces, deep ink type, teal primary actions, soft borders,
/// generous whitespace. No generic Material form look, no heavy shadows.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass.dart';
import '../../core/api/api_client.dart';

/// Auth screen colours. Backed by the active [BlistraColors] (kept in sync by
/// the app's `MaterialApp.builder`), so every auth widget follows the accent
/// palette and light/dark mode without threading a context through helpers.
class AuthColors {
  AuthColors._();

  static BlistraColors _c =
      BlistraColors.of(AccentPalette.lagoon, Brightness.light);

  static void sync(BlistraColors colors) => _c = colors;

  static Color get cream => Colors.transparent;
  static Color get ink => _c.text;
  static Color get muted => _c.muted;
  static Color get teal => _c.accent;
  static Color get tealSoft => _c.accent.withValues(alpha: .14);
  static Color get border => _c.glassBorder;
  static Color get surface => _c.isDark ? const Color(0xFF1B2330) : Colors.white;
  static Color get error => _c.isDark ? const Color(0xFFFF8A80) : const Color(0xFFB42318);
  static Color get errorBg => _c.isDark ? const Color(0x33FF5A4F) : const Color(0xFFFDECEC);
}

/// Minimal auth page chrome: safe area, keyboard-aware scroll, optional back.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.bottom,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;

  Widget _themeToggle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Consumer<ThemeController>(
      builder: (context, controller, _) => IconButton(
        tooltip: controller.isDark(brightness)
            ? 'Switch to light mode'
            : 'Switch to dark mode',
        onPressed: () => controller.toggle(brightness),
        icon: Icon(
          controller.isDark(brightness)
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: Icon(Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  _themeToggle(context),
                ],
              ),
            ),
            const _WakingBanner(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  onBack == null ? 32 : 4,
                  24,
                  16,
                ),
                child: child,
              ),
            ),
            if (bottom != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    16,
                  ),
                  child: bottom!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Explains a slow first request (free hosting wakes up on demand).
class _WakingBanner extends StatelessWidget {
  const _WakingBanner();

  @override
  Widget build(BuildContext context) {
    ApiClient? api;
    try {
      api = context.read<ApiClient>();
    } catch (_) {
      api = null;
    }
    if (api == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: api.slowRequest,
      builder: (context, slow, _) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: slow
            ? Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AuthColors.tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Waking up the server. This can take up to a minute the first time.',
                        style: TextStyle(fontSize: 12.5, color: AuthColors.ink),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Subtle step progress: "Step 3 of 8" + slim bar. Never dominant.
class AuthProgress extends StatelessWidget {
  const AuthProgress(
      {super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $step of $total',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AuthColors.muted)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : step / total,
            minHeight: 5,
            backgroundColor: softBg(context, Color(0xFFEDE9E2)),
            valueColor:
                AlwaysStoppedAnimation(AuthColors.teal),
          ),
        ),
      ],
    );
  }
}

/// Large, comfortable rounded input with inline error + optional success.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.keyboardType,
    this.obscure = false,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.suffix,
    this.error,
    this.success = false,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.inputFormatters,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final String? error;
  final bool success;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
           decoration: BoxDecoration(
             color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AuthColors.error
                  : success
                      ? BlistraColors.resolve(context).accent
                      : BlistraColors.resolve(context).glassBorder,
              width: hasError || success ? 1.4 : 1,
            ),
          ),
          child: Semantics(
            label: semanticLabel ?? label ?? hint,
            textField: true,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscure,
              autofocus: autofocus,
              autocorrect: false,
              textCapitalization: textCapitalization,
              autofillHints: autofillHints,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
               style: TextStyle(
                   fontSize: 17,
                   color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                labelText: label,
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 17),
                suffixIcon: suffix,
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          InlineError(message: error!),
        ],
      ],
    );
  }
}

/// Full-width rounded primary CTA with loading state. Never stuck spinning:
/// callers must reset busy on every exit path.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: BlistraColors.resolve(context).accent,
          disabledBackgroundColor:
              BlistraColors.resolve(context).accent.withValues(alpha: 0.45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}

/// Inline, human-readable error associated with the field/screen.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuthColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          style: TextStyle(
              fontSize: 13.5,
              color: AuthColors.error,
              fontWeight: FontWeight.w500)),
    );
  }
}

/// Brand header: subtle mark + name + tagline. Not full-screen branding.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BlistraMark(size: compact ? 40 : 48),
            const SizedBox(width: 12),
            Text('Blistra',
                style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    color: AuthColors.ink)),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          Text('Everything you need. One app.',
              style: TextStyle(fontSize: 14, color: AuthColors.muted)),
        ],
      ],
    );
  }
}

/// Elegant 6-slot OTP input: auto-advance, backspace, paste distribution,
/// numeric keyboard, subtle focus ring, auto-verify callback at 6 digits.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback? onCompleted;
  final bool enabled;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _cells;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _cells = List.generate(6, (_) => TextEditingController());
    _nodes = List.generate(6, (_) => FocusNode());
    _syncFromExternal();
    widget.controller.addListener(_syncFromExternal);
  }

  void _syncFromExternal() {
    final text =
        widget.controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < 6; i++) {
      final ch = i < text.length ? text[i] : '';
      if (_cells[i].text != ch) _cells[i].text = ch;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternal);
    for (final c in _cells) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _push() {
    final code = _cells.map((c) => c.text).join();
    if (widget.controller.text != code) {
      widget.controller.text = code;
    }
    if (code.length == 6) widget.onCompleted?.call();
  }

  void _onChanged(int index, String value) {
    // Paste: distribute a multi-digit insertion across cells.
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 1) {
      final clean = digits.length > 6 ? digits.substring(0, 6) : digits;
      for (int i = 0; i < 6; i++) {
        _cells[i].text = i < clean.length ? clean[i] : '';
      }
      _push();
      if (clean.length == 6) {
        _nodes[5].unfocus();
      } else {
        _nodes[clean.length].requestFocus();
      }
      return;
    }
    final d = digits.isEmpty ? '' : digits[digits.length - 1];
    _cells[index].text = d;
    if (d.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    _push();
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _cells[index].text.isEmpty &&
        index > 0) {
      _nodes[index - 1].requestFocus();
      _cells[index - 1].clear();
      _push();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Six digit verification code',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < 6; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4, right: i == 5 ? 0 : 4),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (e) => _onKey(i, e),
                  child: TextField(
                    controller: _cells[i],
                    focusNode: _nodes[i],
                    enabled: widget.enabled,
                    autofocus: i == 0,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                       fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AuthColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AuthColors.teal, width: 1.6),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AuthColors.border),
                      ),
                    ),
                    onChanged: (v) => _onChanged(i, v),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Subtle password strength meter reusing backend rules
/// (8+ chars, letter, digit). Informational only — validation stays server-side.
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    final label = switch (score) {
      0 => '',
      1 => 'Weak',
      2 => 'Fair',
      _ => 'Strong',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    final color = switch (score) {
      1 => AuthColors.error,
      2 => const Color(0xFFB54708),
      _ => BlistraColors.resolve(context).accent,
    };
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: i < score ? color : softBg(context, Color(0xFFEDE9E2)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  static int _score(String v) {
    if (v.isEmpty) return 0;
    int s = 0;
    if (v.length >= 8) s++;
    if (RegExp(r'[A-Za-z]').hasMatch(v) &&
        RegExp(r'[0-9]').hasMatch(v)) {
      s++;
    }
    if (v.length >= 12 && s == 2) s++;
    return s.clamp(1, 3);
  }
}
