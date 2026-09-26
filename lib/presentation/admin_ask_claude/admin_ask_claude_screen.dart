import 'package:flutter/material.dart';

import '../../services/admin_ask_claude_service.dart';

/// "Chiedi a Claude (dati app)": l'admin fa una domanda in linguaggio
/// naturale sui dati dell'app; Claude la legge da sé (query di sola
/// lettura lato server) ed elabora la risposta. Mostra anche le proprie
/// domande/risposte precedenti.
class AdminAskClaudeScreen extends StatelessWidget {
  const AdminAskClaudeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chiedi a Claude')),
      body: const AdminAskClaudeBody(),
    );
  }
}

/// Corpo di "Chiedi a Claude", senza AppBar propria: usato sia dalla
/// route a schermo intero [AdminAskClaudeScreen] sia dal foglio modale
/// aperto dalla bolla flottante globale in lib/main.dart.
class AdminAskClaudeBody extends StatefulWidget {
  const AdminAskClaudeBody({super.key});

  @override
  State<AdminAskClaudeBody> createState() => _AdminAskClaudeBodyState();
}

class _AdminAskClaudeBodyState extends State<AdminAskClaudeBody> {
  final _service = AdminAskClaudeService.instance;
  final _questionController = TextEditingController();

  bool _isLoadingHistory = true;
  bool _isAsking = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _service.getHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoadingHistory = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isAsking) return;

    setState(() => _isAsking = true);
    try {
      await _service.ask(question);
      _questionController.clear();
      await _loadHistory();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAsking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _questionController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Fai una domanda sui dati dell\'app...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAsking ? null : _submit,
                  icon: _isAsking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isAsking ? 'Sto pensando...' : 'Invia'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? Center(
                      child: Text(
                        'Nessuna domanda ancora.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) =>
                          _buildHistoryItem(_history[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final question = (item['question'] ?? '').toString();
    final answer = (item['answer'] ?? '').toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(answer),
        ],
      ),
    );
  }
}
