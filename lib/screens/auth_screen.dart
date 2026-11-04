import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const AuthScreen({super.key, required this.onLoginSuccess});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _confirm = TextEditingController();
  bool _login = true;
  bool _hidden = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final success = await context.read<AuthProvider>().submit(
      email: _email.text,
      password: _password.text,
      name: _login ? null : _name.text,
    );
    if (mounted && success) widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_library, size: 64),
                    const Text(
                      'LibFlow',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _login ? 'Жүйеге кіру' : 'Тіркелу',
                      style: const TextStyle(fontSize: 24),
                    ),
                    if (!_login)
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Аты-жөні',
                        ),
                        validator: (v) => v == null || v.trim().length < 2
                            ? 'Аты-жөніңізді енгізіңіз'
                            : null,
                      ),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          v == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v.trim())
                          ? 'Email дұрыс емес'
                          : null,
                    ),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidden,
                      decoration: InputDecoration(
                        labelText: 'Құпиясөз',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidden = !_hidden),
                          icon: const Icon(Icons.visibility),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 8
                          ? 'Кемінде 8 таңба енгізіңіз'
                          : null,
                    ),
                    if (!_login)
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Құпиясөзді қайталау',
                        ),
                        validator: (v) => v != _password.text
                            ? 'Құпиясөздер сәйкес емес'
                            : null,
                      ),
                    const SizedBox(height: 20),
                    if (auth.busy) const LinearProgressIndicator(),
                    if (auth.error != null)
                      Text(
                        auth.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: Text(_login ? 'Кіру' : 'Тіркелу'),
                    ),
                    TextButton(
                      onPressed: auth.busy
                          ? null
                          : () => setState(() {
                              _login = !_login;
                              _form.currentState?.reset();
                            }),
                      child: Text(_login ? 'Аккаунт жасау' : 'Аккаунтым бар'),
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
