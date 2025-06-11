import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  final List<String> allowedIds;
  final String correctPassword;
  const LoginPage({
    required this.allowedIds,
    required this.correctPassword,
    Key? key,
  }) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  String? _error;

  void _login() {
    final id = _idController.text.trim();
    final pass = _passController.text;
    if (!widget.allowedIds.contains(id)) {
      setState(() => _error = 'IDが正しくありません');
      return;
    }
    if (pass != widget.correctPassword) {
      setState(() => _error = 'パスワードが正しくありません');
      return;
    }
    // ログイン成功
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ログイン',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _login, child: const Text('ログイン')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
