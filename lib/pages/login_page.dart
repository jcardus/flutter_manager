import 'package:flutter/material.dart';
import 'package:manager/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _loading = false;
  String? _error;
  bool _hasSavedCredentials = false;

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _auth.hasSavedCredentials().then((has) {
        if (mounted) setState(() => _hasSavedCredentials = has);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (ok, msg) = await _auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = msg ?? l10n.loginFailed);
    }
  }

  Future<void> _biometricLogin() async {
    setState(() { _loading = true; _error = null; });
    final creds = await _auth.getCredentialsWithBiometrics();
    if (!mounted) return;
    if (creds == null) {
      setState(() => _loading = false);
      return;
    }
    final (email, password) = creds;
    final (ok, msg) = await _auth.login(email: email, password: password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = msg ?? l10n.loginFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.signIn, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        decoration: InputDecoration(labelText: l10n.emailOrUsername),
                        validator: (v) => (v == null || v.isEmpty) ? l10n.required : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        enabled: !_loading,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(labelText: l10n.password),
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty) ? l10n.required : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(l10n.login),
                        ),
                      ),
                      if (_hasSavedCredentials) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _biometricLogin,
                            icon: const Icon(Icons.face),
                            label: const Text('Face ID / Biometrics'),
                          ),
                        ),
                      ],
                    ],
                  ),
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
