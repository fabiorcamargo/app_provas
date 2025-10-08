import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'usuario_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    final dbHelper = DatabaseHelper();
    final usuarios = await dbHelper.getUsuarios();
    final email = _emailController.text.trim();
    Usuario? usuario;
    try {
      usuario = usuarios.firstWhere((u) => u.email == email);
    } catch (_) {
      usuario = null;
    }
    if (usuario != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usuarioId', usuario.id!);
      await prefs.setString('usuarioUuid', usuario.uuid);
      await prefs.setString('usuarioNome', usuario.nome);
      await prefs.setString('usuarioEmail', usuario.email);
      await prefs.setString('usuarioTelefone', usuario.telefone);
      await prefs.setString('usuarioRole', usuario.role);
      Navigator.of(context).pushReplacementNamed('/cidades');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não encontrado!')));
    }
    setState(() => _loading = false);
  }

  void _cadastrar() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const UsuarioPage()));
    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cadastro realizado!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _cadastrar,
              child: const Text('Cadastrar novo usuário'),
            ),
          ],
        ),
      ),
    );
  }
}
