import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'clientes_page.dart';

class AcoesPage extends StatefulWidget {
  final Cidade cidade;
  const AcoesPage({Key? key, required this.cidade}) : super(key: key);

  @override
  State<AcoesPage> createState() => _AcoesPageState();
}

class _AcoesPageState extends State<AcoesPage> {
  final TextEditingController _descricaoController = TextEditingController();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Acao> acoes = [];

  @override
  void initState() {
    super.initState();
    _loadAcoes();
  }

  Future<void> _loadAcoes() async {
    final lista = await dbHelper.getAcoesByCidade(widget.cidade.uuid);
    setState(() {
      acoes = lista;
    });
  }

  Future<void> _addAcao() async {
    final descricao = _descricaoController.text.trim();
    if (descricao.isEmpty) return;
    final acao = Acao(
      uuid: '',
      cidadeUuid: widget.cidade.uuid,
      descricao: descricao,
      data: DateTime.now(),
    );
    await dbHelper.insertAcao(acao);
    _descricaoController.clear();
    await _loadAcoes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Ações de ${widget.cidade.nome}'),
            const SizedBox(width: 8),
            FutureBuilder<bool>(
              future: dbHelper.hasPendingForCidade(widget.cidade.uuid),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final hasPending = snapshot.data == true;
                if (!hasPending) return const SizedBox.shrink();
                return Row(
                  children: const [
                    SizedBox(width: 8),
                    Icon(Icons.cloud_off, size: 18, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'dados não sincronizados',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição da ação',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addAcao,
                  child: const Text('Criar Ação'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: acoes.isEmpty
                  ? const Center(child: Text('Nenhuma ação cadastrada'))
                  : ListView.builder(
                      itemCount: acoes.length,
                      itemBuilder: (context, index) {
                        final acao = acoes[index];
                        return FutureBuilder<bool>(
                          future: dbHelper.hasPendingClientsForAcao(acao.uuid),
                          builder: (context, snap) {
                            final pendente = snap.data == true;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 0,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  pendente
                                      ? Icons.cloud_off
                                      : (acao.sincronizado
                                            ? Icons.cloud
                                            : Icons.cloud_off),
                                  color: pendente
                                      ? Colors.orange
                                      : (acao.sincronizado
                                            ? Colors.blue
                                            : Colors.grey),
                                ),
                                title: Text(acao.descricao),
                                subtitle: Text(
                                  'Data: ${acao.data.toString()}' +
                                      (pendente
                                          ? ' • dados não sincronizados'
                                          : ''),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.people),
                                  tooltip: 'Ver clientes',
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ClientesPage(acao: acao),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
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
