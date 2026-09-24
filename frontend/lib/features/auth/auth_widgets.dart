/// Premium, reusable authentication components in the Blistra design language.
///
/// Warm off-white surfaces, deep ink type, teal primary actions, soft borders,
/// generous whitespace. No generic Material form look, no heavy shadows.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthColors {
  AuthColors._();

  static const cream = Color(0xFFFFFBF6);
  static const ink = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const teal = Color(0xFF0C6B6B);
  static const tealSoft = Color(0xFFE6F6F3);
  static const border = Color(0xFFEAE6DF);
  static const error = Color(0xFFB42318);
  static const errorBg = Color(0xFFFDECEC);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back,
                        color: AuthColors.ink),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  onBack == null ? 32 : 4,
                  24,
                  16 + MediaQuery.of(context).viewInsets.bottom * 0.0,
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
                    16 + MediaQuery.of(context).viewInsets.bottom,
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
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AuthColors.muted)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : step / total,
            minHeight: 5,
            backgroundColor: const Color(0xFFEDE9E2),
            valueColor:
                const AlwaysStoppedAnimation(AuthColors.teal),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AuthColors.error
                  : success
                      ? AuthColors.teal
                      : AuthColors.border,
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
              style: const TextStyle(
                  fontSize: 17, color: AuthColors.ink),
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
          backgroundColor: AuthColors.teal,
          disabledBackgroundColor:
              AuthColors.teal.withValues(alpha: 0.45),
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
          style: const TextStyle(
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
            Container(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              decoration: BoxDecoration(
                color: AuthColors.teal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.layers_outlined,
                  color: Colors.white, size: compact ? 22 : 26,
                  semanticLabel: 'Blistra logo'),
            ),
            const SizedBox(width: 12),
            const Text('Blistra',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AuthColors.ink)),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          const Text('Everything you need. One app.',
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
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.ink),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AuthColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AuthColors.teal, width: 1.6),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AuthColors.border),
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
      _ => AuthColors.teal,
    };
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: i < score ? color : const Color(0xFFEDE9E2),
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
