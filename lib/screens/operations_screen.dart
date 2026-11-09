import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../services/library_api_service.dart';
import '../services/library_repository.dart';
import 'catalog_screen.dart';
import 'qr_scanner_screen.dart';

const _roles = {
  'reader': 'Оқырман',
  'librarian': 'Кітапханашы',
  'admin': 'Әкімші',
};
const _statuses = {
  'reserved': 'Брондалған',
  'issued': 'Берілген',
  'cancelled': 'Жойылған',
  'returned': 'Қайтарылған',
  'expired': 'Мерзімі аяқталған',
};

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late final AuthProvider _auth = context.read<AuthProvider>();
  late final _repository = LibraryRepository(
    catalogueOnly: true,
    api: LibraryApiService()..sessionToken = _auth.api!.sessionToken,
  );
  late Future<dynamic> _data;
  int _tab = 0;
  String _query = '';
  String? _filter;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository.refresh();
    _repository.startRealtime();
    _data = _load();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<dynamic> _load() {
    final query = Uri.encodeQueryComponent(_query);
    return switch (_tab) {
      1 when _auth.isAdmin => _auth.api!.request(
        'GET',
        '/api/admin/users?q=$query${_filter == null ? '' : '&role=$_filter'}',
      ),
      2 when _auth.isAdmin => _auth.api!.request('GET', '/api/admin/audit'),
      1 || 3 => _auth.api!.request('GET', '/api/staff/reservations?q=$query'),
      _ => _auth.api!.request('GET', '/api/staff/summary'),
    };
  }

  void _refresh() => setState(() => _data = _load());

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _openCatalog() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ListenableBuilder(
        listenable: _repository,
        builder: (_, _) => CatalogScreen(
          staff: true,
          books: _repository.books,
          loading: _repository.status == LibraryStatus.loading,
          onBookUpdated: _repository.update,
          onBookAdded: _repository.add,
          onBookDeleted: _repository.delete,
          onScan: _openScanner,
        ),
      ),
    ),
  );

  void _openScanner() {
    final route = MaterialPageRoute<void>(
      builder: (scannerContext) =>
          QrScannerScreen(onCheck: (code) => _check(scannerContext, code)),
    );
    Navigator.push(context, route);
  }

  Future<void> _check(BuildContext scanner, String code) async {
    try {
      final encoded = Uri.encodeComponent(code);
      final item = await _auth.api!.request(
        'GET',
        '/api/staff/reservations/$encoded',
      ) as Map;
      if (!scanner.mounted) return;
      await _reservationActions(scanner, item);
    } on LibraryApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _reservationActions(BuildContext context, Map item) async {
    final status = item['display_status'] ?? item['status'];
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(item['title'] as String),
        content: Text(
          "${item['reader'] ?? ''}\n${_statuses[status] ?? status}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Жабу'),
          ),
          if (status == 'reserved') ...[
            TextButton(
              onPressed: () => Navigator.pop(dialog, 'cancel'),
              child: const Text('Броньды жою'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, 'issue'),
              child: const Text('Кітапты беру'),
            ),
          ],
          if (status == 'issued')
            FilledButton(
              onPressed: () => Navigator.pop(dialog, 'return'),
              child: const Text('Қайтаруды тіркеу'),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted || _saving) return;
    Map<String, dynamic>? body;
    if (action == 'issue') {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: now.add(const Duration(days: 14)),
      );
      if (date == null || !mounted) return;
      body = {'due': date.toIso8601String().split('T').first};
    }
    final code = Uri.encodeComponent(item['code'] as String);
    await _mutate('POST', '/api/staff/reservations/$code/$action', body);
  }

  Future<void> _mutate(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _auth.api!.request(method, path, body: body);
      if (mounted) {
        _refresh();
        _repository.refresh();
        _message('Өзгеріс сақталды.');
      }
    } on LibraryApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAccess(Map user) async {
    var role = user['role'] as String;
    var blocked = user['blocked'] as bool;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user['name'] as String),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user['email'] as String),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Рөл'),
                  items: [
                    for (final entry in _roles.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => role = value!),
                ),
                SwitchListTile(
                  title: const Text('Бұғатталған'),
                  value: blocked,
                  onChanged: (value) => setDialogState(() => blocked = value),
                ),
                const Text(
                  'Рөл немесе күй өзгерсе, пайдаланушы жүйеге қайта кіреді.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Бас тарту'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Растау'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _mutate('PUT', "/api/admin/users/${user['id']}/access", {
        'role': role,
        'blocked': blocked,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = _auth.isAdmin;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(admin ? 'LibFlow · Әкімші' : 'LibFlow · Кітапханашы'),
        actions: [
          IconButton(
            tooltip: 'Жаңарту',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'theme') {
                widget.onThemeToggle(!widget.isDarkMode);
              } else {
                await _auth.logout();
                if (_auth.error case final error?) _message(error);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(_auth.user?['email'] as String? ?? ''),
              ),
              const PopupMenuItem(
                value: 'theme',
                child: Text('Тақырыпты ауыстыру'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Жүйеден шығу')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              if (_saving) const LinearProgressIndicator(),
              if (_tab == 1 || _tab == 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      TextField(
                        key: ValueKey(
                          'search-${admin ? 'accounts' : 'reservations'}',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Аты бойынша іздеу',
                          prefixIcon: Icon(Icons.search),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          _query = value;
                          _refresh();
                        },
                      ),
                      if (admin && _tab == 1)
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Барлығы'),
                              selected: _filter == null,
                              onSelected: (_) {
                                _filter = null;
                                _refresh();
                              },
                            ),
                            for (final entry in _roles.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: _filter == entry.key,
                                onSelected: (_) {
                                  _filter = entry.key;
                                  _refresh();
                                },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: FutureBuilder<dynamic>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Қайта көру'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final result = snapshot.data;
                    final entries = _tab == 1 && admin
                        ? result['users'] as List
                        : result;
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (_tab == 0) ...[
                          Text(
                            admin ? 'Жүйе шолуы' : 'Бүгінгі жұмыс',
                            style: theme.textTheme.displaySmall,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _metric('Кітап', result['books']),
                              _metric('Дана', result['copies']),
                              _metric('Қолда бар', result['available']),
                              _metric('Белсенді бронь', result['reserved']),
                              _metric('Берілген', result['issued']),
                              _metric('Мерзімі өткен', result['overdue']),
                              if (admin) ...[
                                _metric('Аккаунт', result['accounts']),
                                _metric('Кітапханашы', result['librarians']),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _openCatalog,
                                icon: const Icon(Icons.shelves),
                                label: const Text('Қорды басқару'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openScanner,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('QR тексеру'),
                              ),
                            ],
                          ),
                        ] else if (entries is List) ...[
                          if (entries.isEmpty)
                            const ListTile(title: Text('Жазбалар жоқ')),
                          for (final item in entries.cast<Map>())
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: !admin || _tab == 3
                                  ? _reservationTile(item, context)
                                  : Card(
                                      child: _tab == 1
                                          ? ListTile(
                                              title: Text(
                                                item['name'] as String,
                                              ),
                                              subtitle: Text(
                                                "${item['email']} · ${_roles[item['role']]}${item['blocked'] == true ? ' · Бұғатталған' : ''}",
                                              ),
                                              trailing:
                                                  item['id'] ==
                                                      _auth.user?['id']
                                                  ? null
                                                  : const Icon(
                                                      Icons
                                                          .manage_accounts_outlined,
                                                    ),
                                              onTap:
                                                  item['id'] ==
                                                          _auth.user?['id'] ||
                                                      _saving
                                                  ? null
                                                  : () => _changeAccess(item),
                                            )
                                          : ListTile(
                                              leading: const Icon(
                                                Icons.history,
                                              ),
                                              title: Text(
                                                "${item['actor']} → ${item['target']}",
                                              ),
                                              subtitle: Text(
                                                "${_roles[item['previous_role']]} → ${_roles[item['new_role']]} · ${item['blocked'] == true ? 'Бұғатталған' : 'Ашық'}\n${item['created_at']}",
                                              ),
                                            ),
                                    ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() {
          _tab = index;
          _query = '';
          _filter = null;
          _data = _load();
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Шолу',
          ),
          NavigationDestination(
            icon: Icon(
              admin ? Icons.group_outlined : Icons.receipt_long_outlined,
            ),
            label: admin ? 'Аккаунттар' : 'Броньдар',
          ),
          if (admin)
            const NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Журнал',
            ),
          if (admin)
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Броньдар',
            ),
        ],
      ),
    );
  }

  Widget _reservationTile(Map item, BuildContext context) {
    final status = item['display_status'] ?? item['status'];
    final due = DateTime.tryParse(item['due_at']?.toString() ?? '')?.toLocal();
    final overdue =
        status == 'issued' && due != null && due.isBefore(DateTime.now());
    return Card(
      child: ListTile(
        title: Text(item['title'] as String),
        subtitle: Text(
          "${item['reader']} · ${overdue ? 'Мерзімі өткен' : _statuses[status]}${due == null ? '' : ' · ${MaterialLocalizations.of(context).formatShortDate(due)}'}",
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _saving ? null : () => _reservationActions(context, item),
      ),
    );
  }

  Widget _metric(String label, Object? value) => SizedBox(
    width: 145,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
