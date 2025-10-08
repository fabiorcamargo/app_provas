import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'acoes_page.dart';
import 'usuario_page.dart';
import 'package:uuid/uuid.dart';

class CidadesPage extends StatefulWidget {
  const CidadesPage({Key? key}) : super(key: key);

  @override
  State<CidadesPage> createState() => _CidadesPageState();
}

class _CidadesPageState extends State<CidadesPage> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Cidade> cidades = [];
  String? _endpoint;
  String? _token;
  bool _ativado = false;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _loadCidades();
    _loadAtivacao();
  }

  Future<void> _loadCidades() async {
    final lista = await dbHelper.getCidades();
    if (!mounted) return;
    setState(() {
      cidades = lista;
    });
  }

  Future<void> _addCidade() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty) return;
    await dbHelper.insertCidade(Cidade(uuid: '', nome: nome));
    _controller.clear();
    await _loadCidades();
  }

  Future<void> _confirmDeleteCidade(Cidade cidade) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a cidade "${cidade.nome}"?'),
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
      await dbHelper.deleteCidade(cidade.uuid);
      await _loadCidades();
    }
  }

  Future<void> _loadAtivacao() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _endpoint = prefs.getString('endpoint');
      _token = prefs.getString('token');
      _ativado = _endpoint != null && _token != null;
    });
  }

  Future<void> _ativar({bool editar = false}) async {
    final endpointController = TextEditingController(
      text: editar ? _endpoint : '',
    );
    final tokenController = TextEditingController(text: editar ? _token : '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editar ? 'Configurar' : 'Ativar sincronização'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: endpointController,
              decoration: const InputDecoration(labelText: 'Endpoint'),
            ),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(labelText: 'Token'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(editar ? 'Salvar' : 'Ativar'),
          ),
        ],
      ),
    );
    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('endpoint', endpointController.text.trim());
      await prefs.setString('token', tokenController.text.trim());
      if (!mounted) return;
      setState(() {
        _endpoint = endpointController.text.trim();
        _token = tokenController.text.trim();
        _ativado = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editar ? 'Configuração salva!' : 'Sincronização ativada!',
          ),
        ),
      );
    }
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      // Gera um UUID para identificar este lote de sincronização
      final syncUuid = const Uuid().v4();

      // Monta payload: não reenviar o que já estiver sincronizado
      final usuarios = await dbHelper.getUsuarios();

      final todasCidades = await dbHelper.getCidades();
      final cidadesParaEnviar = todasCidades
          .where((c) => !c.sincronizado)
          .toList();

      List<Acao> acoesParaEnviar = [];
      List<Cliente> clientesParaEnviar = [];
      for (final cidade in todasCidades) {
        final acs = await dbHelper.getAcoesByCidade(cidade.uuid);
        acoesParaEnviar.addAll(acs.where((a) => !a.sincronizado));
        for (final acao in acs) {
          final cls = await dbHelper.getClientesByAcao(acao.uuid);
          clientesParaEnviar.addAll(cls.where((cl) => !cl.sincronizado));
        }
      }

      String _stripPhone(String? v) => (v ?? '')
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(
            0,
            ((v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length > 11)
                ? 11
                : (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length,
          );

      final usuarioMap = usuarios.isNotEmpty
          ? Map<String, dynamic>.from(usuarios.first.toMap())
          : null;
      if (usuarioMap != null && usuarioMap['telefone'] != null) {
        usuarioMap['telefone'] = _stripPhone(
          usuarioMap['telefone']?.toString(),
        );
      }

      final dados = {
        'sincronizacaoUuid': syncUuid,
        'usuario': usuarioMap,
        'cidades': cidadesParaEnviar.map((c) => c.toMap()).toList(),
        'acoes': acoesParaEnviar.map((a) => a.toMap()).toList(),
        'clientes': clientesParaEnviar.map((c) {
          final m = c.toMap();
          m['telefone1'] = _stripPhone(m['telefone1']?.toString());
          m['telefone2'] = _stripPhone(m['telefone2']?.toString());
          return m;
        }).toList(),
      };

      final response = await http.post(
        Uri.parse(_endpoint!),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dados),
      );

      if (response.statusCode == 200) {
        // contadores para resumo
        int syncedClientes = 0;
        int syncedAcoes = 0;
        int syncedCidades = 0;
        int syncedUsuarios = 0;

        try {
          // O servidor pode retornar:
          // 1) [ { "data": [ "{\\n\\"cliente\\\": uuid}" , ... ] } ]
          // 2) [ "{\\n\\"cliente\\\": uuid}" , ... ]
          // 3) { "data": [ ... ] }
          final decoded = jsonDecode(response.body);
          List<dynamic> items = [];
          if (decoded is List) {
            if (decoded.isNotEmpty &&
                decoded.first is Map &&
                (decoded.first as Map).containsKey('data')) {
              final first = decoded.first as Map;
              final data = first['data'];
              if (data is List) items = data;
            } else {
              items = decoded;
            }
          } else if (decoded is Map && decoded.containsKey('data')) {
            final data = decoded['data'];
            if (data is List) items = data;
          }

          for (final item in items) {
            if (item is String) {
              try {
                final obj = jsonDecode(item);
                if (obj is Map<String, dynamic>) {
                  await _marcarPeloObjeto(
                    obj,
                    onCliente: (_) => syncedClientes++,
                    onAcao: (_) => syncedAcoes++,
                    onCidade: (_) => syncedCidades++,
                    onUsuario: (_) => syncedUsuarios++,
                  );
                }
              } catch (_) {
                // fallback por regex quando a string não é um JSON válido
                final s = item.toString();
                final re = RegExp(
                  r'"?(cliente|acao|cidade|user|usuario)"?\s*:\s*"?([0-9a-fA-F\-]{36})"?',
                );
                final m = re.firstMatch(s);
                if (m != null) {
                  final key = m.group(1);
                  final uuid = m.group(2);
                  if (uuid != null && uuid.isNotEmpty && key != null) {
                    await _marcarPelaChaveUuid(
                      key,
                      uuid,
                      onCliente: (_) => syncedClientes++,
                      onAcao: (_) => syncedAcoes++,
                      onCidade: (_) => syncedCidades++,
                      onUsuario: (_) => syncedUsuarios++,
                    );
                  }
                }
              }
            } else if (item is Map<String, dynamic>) {
              await _marcarPeloObjeto(
                item,
                onCliente: (_) => syncedClientes++,
                onAcao: (_) => syncedAcoes++,
                onCidade: (_) => syncedCidades++,
                onUsuario: (_) => syncedUsuarios++,
              );
            }
          }
        } catch (_) {
          // Se não conseguir interpretar, segue apenas com sucesso genérico
        }

        await _loadCidades();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Resumo da sincronização'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lote: $syncUuid'),
                const SizedBox(height: 8),
                Text('Cidades sincronizadas: $syncedCidades'),
                Text('Ações sincronizadas: $syncedAcoes'),
                Text('Clientes sincronizados: $syncedClientes'),
                Text('Usuários sincronizados: $syncedUsuarios'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Resposta do servidor:'),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 240,
                    minWidth: MediaQuery.of(dialogContext).size.width * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      response.body,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: response.body));
                  if (!dialogContext.mounted) return;
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Resposta copiada.')),
                  );
                },
                child: const Text('Copiar resposta'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) {
        setState(() => _sincronizando = false);
      }
    }
  }

  Future<void> _marcarPeloObjeto(
    Map<String, dynamic> obj, {
    void Function(String uuid)? onCliente,
    void Function(String uuid)? onAcao,
    void Function(String uuid)? onCidade,
    void Function(String uuid)? onUsuario,
  }) async {
    if (obj.containsKey('cliente')) {
      final uuid = obj['cliente']?.toString();
      if (uuid != null && uuid.isNotEmpty) {
        await dbHelper.markClienteSynced(uuid);
        onCliente?.call(uuid);
      }
    } else if (obj.containsKey('acao')) {
      final uuid = obj['acao']?.toString();
      if (uuid != null && uuid.isNotEmpty) {
        await dbHelper.markAcaoSynced(uuid);
        onAcao?.call(uuid);
      }
    } else if (obj.containsKey('cidade')) {
      final uuid = obj['cidade']?.toString();
      if (uuid != null && uuid.isNotEmpty) {
        await dbHelper.markCidadeSynced(uuid);
        onCidade?.call(uuid);
      }
    } else if (obj.containsKey('user') || obj.containsKey('usuario')) {
      final uuid = (obj['user'] ?? obj['usuario'])?.toString();
      if (uuid != null && uuid.isNotEmpty) {
        await dbHelper.markUsuarioSynced(uuid);
        onUsuario?.call(uuid);
      }
    }
  }

  Future<void> _marcarPelaChaveUuid(
    String key,
    String uuid, {
    void Function(String uuid)? onCliente,
    void Function(String uuid)? onAcao,
    void Function(String uuid)? onCidade,
    void Function(String uuid)? onUsuario,
  }) async {
    switch (key) {
      case 'cliente':
        await dbHelper.markClienteSynced(uuid);
        onCliente?.call(uuid);
        break;
      case 'acao':
        await dbHelper.markAcaoSynced(uuid);
        onAcao?.call(uuid);
        break;
      case 'cidade':
        await dbHelper.markCidadeSynced(uuid);
        onCidade?.call(uuid);
        break;
      case 'user':
      case 'usuario':
        await dbHelper.markUsuarioSynced(uuid);
        onUsuario?.call(uuid);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Cidades'),
            const SizedBox(width: 8),
            FutureBuilder<bool>(
              future: dbHelper.hasPendingSync(),
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
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Nome da cidade',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCidade,
                  child: const Text('Cadastrar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Usuário'),
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => UsuarioPage()),
                    );
                    if (!mounted) return;
                    if (result == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Usuário salvo!')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (!_ativado)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _ativar,
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Ativar sincronização'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                if (_ativado) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sincronizando ? null : _sincronizar,
                      icon: const Icon(Icons.sync),
                      label: _sincronizando
                          ? const Text('Sincronizando...')
                          : const Text('Sincronizar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _ativar(editar: true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                        alignment: Alignment.center,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: const [
                          Icon(Icons.settings),
                          SizedBox(width: 8),
                          Flexible(child: Text('Configurar sincronização')),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: cidades.isEmpty
                  ? const Center(child: Text('Nenhuma cidade cadastrada'))
                  : ListView.builder(
                      itemCount: cidades.length,
                      itemBuilder: (context, index) {
                        final cidade = cidades[index];
                        return FutureBuilder<bool>(
                          future: dbHelper.hasPendingForCidade(cidade.uuid),
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
                                      : (cidade.sincronizado
                                            ? Icons.cloud
                                            : Icons.cloud_off),
                                  color: pendente
                                      ? Colors.orange
                                      : (cidade.sincronizado
                                            ? Colors.blue
                                            : Colors.grey),
                                ),
                                title: Text(cidade.nome),
                                subtitle: Text(
                                  pendente
                                      ? 'Dados não sincronizados'
                                      : (cidade.sincronizado
                                            ? 'Sincronizado'
                                            : 'Não sincronizado'),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDeleteCidade(cidade),
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AcoesPage(cidade: cidade),
                                    ),
                                  );
                                },
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
