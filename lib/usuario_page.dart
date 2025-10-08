import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'br_phone_input_formatter.dart';
import 'package:flutter/services.dart';

class UsuarioPage extends StatefulWidget {
  final Usuario? usuario;
  const UsuarioPage({Key? key, this.usuario}) : super(key: key);

  @override
  State<UsuarioPage> createState() => _UsuarioPageState();
}

class _UsuarioPageState extends State<UsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    if (widget.usuario != null) {
      _nomeController.text = widget.usuario!.nome;
      _emailController.text = widget.usuario!.email;
      _telefoneController.text = widget.usuario!.telefone;
      _role = widget.usuario!.role;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  void _salvar() async {
    if (_formKey.currentState!.validate()) {
      String rawPhone = _telefoneController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (rawPhone.length > 11) rawPhone = rawPhone.substring(0, 11);
      final usuario = Usuario(
        id: widget.usuario?.id,
        uuid: '',
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        telefone: rawPhone,
        role: _role,
      );
      final dbHelper = DatabaseHelper();
      // Garante apenas um usuário: limpa e insere de novo
      await dbHelper.clearUsuarios();
      final usuarioId = await dbHelper.insertUsuario(usuario);
      // Salva usuário ativo nas SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usuarioId', usuarioId);
      await prefs.setString('usuarioUuid', usuario.uuid);
      await prefs.setString('usuarioNome', usuario.nome);
      await prefs.setString('usuarioEmail', usuario.email);
      await prefs.setString('usuarioTelefone', usuario.telefone);
      await prefs.setString('usuarioRole', usuario.role);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.usuario == null ? 'Cadastrar Usuário' : 'Editar Usuário',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o nome' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o email' : null,
              ),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  BRPhoneInputFormatter(),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Usuário')),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'user'),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
            ],
          ),
        ),
      ),
    );
  }
}
