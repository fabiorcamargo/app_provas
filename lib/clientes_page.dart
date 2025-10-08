import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'br_phone_input_formatter.dart';

class ClientesPage extends StatefulWidget {
  final Acao acao;
  const ClientesPage({Key? key, required this.acao}) : super(key: key);

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final _nomeController = TextEditingController();
  final _telefone1Controller = TextEditingController();
  final _telefone2Controller = TextEditingController();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Cliente> clientes = [];

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final lista = await dbHelper.getClientesByAcao(widget.acao.uuid);
    setState(() {
      clientes = lista;
    });
  }

  Future<void> _addCliente() async {
    final nome = _nomeController.text.trim();
    String telefone1 = _telefone1Controller.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    String telefone2 = _telefone2Controller.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (telefone1.length > 11) telefone1 = telefone1.substring(0, 11);
    if (telefone2.length > 11) telefone2 = telefone2.substring(0, 11);
    if (nome.isEmpty) return;
    await dbHelper.insertCliente(
      Cliente(
        uuid: '',
        acaoUuid: widget.acao.uuid,
        nome: nome,
        telefone1: telefone1,
        telefone2: telefone2,
      ),
    );
    _nomeController.clear();
    _telefone1Controller.clear();
    _telefone2Controller.clear();
    await _loadClientes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente cadastrado com sucesso!')),
      );
    }
  }

  // Removido: método antigo de exclusão por ID

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clientes da ação: ${widget.acao.descricao}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Excluir ação',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar exclusão'),
                  content: const Text(
                    'Deseja realmente excluir esta ação e todos os clientes relacionados?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await dbHelper.deleteAcao(widget.acao.uuid);
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 8.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Cadastrar Cliente',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telefone1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Telefone 1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [BRPhoneInputFormatter()],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telefone2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Telefone 2',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [BRPhoneInputFormatter()],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addCliente,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar Cliente'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clientes.isEmpty
                  ? const Center(child: Text('Nenhum cliente cadastrado'))
                  : ListView.builder(
                      itemCount: clientes.length,
                      itemBuilder: (context, index) {
                        final cliente = clientes[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 0,
                          ),
                          child: ListTile(
                            leading: Icon(
                              cliente.sincronizado
                                  ? Icons.cloud
                                  : Icons.cloud_off,
                              color: cliente.sincronizado
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            title: Text(cliente.nome),
                            subtitle: Text(
                              'Tel1: ${cliente.telefone1} | Tel2: ${cliente.telefone2}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmar exclusão'),
                                    content: const Text(
                                      'Deseja realmente excluir este cliente?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await dbHelper.deleteCliente(cliente.uuid);
                                  await _loadClientes();
                                }
                              },
                            ),
                          ),
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
