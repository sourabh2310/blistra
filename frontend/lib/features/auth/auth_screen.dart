/// Minimal login/register screen backed by the real auth API.
library;

import 'package:flutter/material.dart';

import '../../core/auth/auth_state.dart';
import '../../core/api/api_exception.dart';
import '../finance/finance_scope.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _registering = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthState auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _error = null;
    });
    if (_registering) {
      await auth.register(_email.text.trim(), _password.text);
    } else {
      await auth.login(_email.text.trim(), _password.text);
    }
    if (!mounted) {
      return;
    }
    final ApiException? error = auth.lastError;
    setState(() {
      _error = error?.toString() ?? (auth.isAuthenticated ? null : _error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = AuthScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'Blistra',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _registering
                          ? 'Create an account to start tracking your money'
                          : 'Sign in to your money tracker',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (_registering && value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(auth),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: auth.status == AuthStatus.busy
                          ? null
                          : () => _submit(auth),
                      child: auth.status == AuthStatus.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering
                              ? 'Create account'
                              : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: auth.status == AuthStatus.busy
                          ? null
                          : () => setState(() {
                              _error = null;
                              _registering = !_registering;
                            }),
                      child: Text(_registering
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}