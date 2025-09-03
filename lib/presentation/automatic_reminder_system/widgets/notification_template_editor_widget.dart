import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class NotificationTemplateEditorWidget extends StatefulWidget {
  final VoidCallback onTemplateUpdated;

  const NotificationTemplateEditorWidget({
    super.key,
    required this.onTemplateUpdated,
  });

  @override
  State<NotificationTemplateEditorWidget> createState() =>
      _NotificationTemplateEditorWidgetState();
}

class _NotificationTemplateEditorWidgetState
    extends State<NotificationTemplateEditorWidget> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _selectedTemplate = 'monthly_reminder';
  bool _isLoading = false;
  bool _hasChanges = false;

  final Map<String, Map<String, String>> _templates = {
    'monthly_reminder': {
      'name': 'Promemoria Mensile',
      'title': 'Promemoria Pagamento - Team Ragnarok ASD',
      'message': '''Ciao {NOME_UTENTE},

Ti ricordiamo che il tuo abbonamento {TIPO_ABBONAMENTO} scadrà il {DATA_SCADENZA}.

Per continuare a frequentare la nostra palestra, ricordati di rinnovare entro il giorno 10 del mese.

Puoi effettuare il pagamento direttamente nell'app o presso la nostra sede.

Team Ragnarok ASD
Via Giulio Bezzi 25, Russi (RA)''',
    },
    'payment_overdue': {
      'name': 'Pagamento Scaduto',
      'title': 'Abbonamento Scaduto - Team Ragnarok ASD',
      'message': '''Ciao {NOME_UTENTE},

Il tuo abbonamento {TIPO_ABBONAMENTO} è scaduto il {DATA_SCADENZA}.

Per poter continuare a utilizzare i nostri servizi, ti preghiamo di rinnovare il prima possibile.

Contattaci per maggiori informazioni.

Team Ragnarok ASD''',
    },
    'welcome_payment': {
      'name': 'Benvenuto - Primo Pagamento',
      'title': 'Benvenuto in Team Ragnarok ASD!',
      'message': '''Ciao {NOME_UTENTE},

Benvenuto/a nella famiglia Team Ragnarok ASD!

Il tuo abbonamento {TIPO_ABBONAMENTO} è attivo dal {DATA_INIZIO} al {DATA_SCADENZA}.

Siamo pronti ad accompagnarti nel tuo percorso nelle arti marziali.

A presto sui tatami!
Team Ragnarok ASD''',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadTemplate() {
    final template = _templates[_selectedTemplate]!;
    _titleController.text = template['title']!;
    _messageController.text = template['message']!;
    setState(() => _hasChanges = false);
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveTemplate() async {
    setState(() => _isLoading = true);

    try {
      // In real implementation, save template to database
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      // Update local template
      _templates[_selectedTemplate]!['title'] = _titleController.text;
      _templates[_selectedTemplate]!['message'] = _messageController.text;

      setState(() => _hasChanges = false);
      widget.onTemplateUpdated();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel salvare il template: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _previewTemplate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anteprima Template'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Titolo:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 1.h),
              Text(_titleController.text.isEmpty
                  ? 'Nessun titolo'
                  : _titleController.text),
              SizedBox(height: 2.h),
              Text(
                'Messaggio:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 1.h),
              Text(_messageController.text.isEmpty
                  ? 'Nessun messaggio'
                  : _messageController.text),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Variabili disponibili:',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '{NOME_UTENTE} - Nome completo dell\'utente\n'
                      '{TIPO_ABBONAMENTO} - Tipo di abbonamento\n'
                      '{DATA_SCADENZA} - Data di scadenza\n'
                      '{DATA_INIZIO} - Data di inizio abbonamento',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editor Template Notifiche',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryLight,
            ),
          ),
          SizedBox(height: 3.h),
          _buildTemplateSelector(),
          SizedBox(height: 3.h),
          _buildTemplateEditor(),
          SizedBox(height: 3.h),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleziona Template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          DropdownButtonFormField<String>(
            value: _selectedTemplate,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            ),
            items: _templates.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value['name']!),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && value != _selectedTemplate) {
                setState(() => _selectedTemplate = value);
                _loadTemplate();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateEditor() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modifica Template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Titolo Notifica',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
            ),
            onChanged: (_) => _onTextChanged(),
          ),
          SizedBox(height: 2.h),
          TextFormField(
            controller: _messageController,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: 'Messaggio',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
            ),
            onChanged: (_) => _onTextChanged(),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber[700],
                      size: 5.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Campi Dinamici Disponibili',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  '{NOME_UTENTE} - Nome completo dell\'utente\n'
                  '{TIPO_ABBONAMENTO} - Tipo di abbonamento (mensile/annuale)\n'
                  '{DATA_SCADENZA} - Data di scadenza abbonamento\n'
                  '{DATA_INIZIO} - Data di inizio abbonamento',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _previewTemplate,
            icon: const Icon(Icons.preview),
            label: const Text('Anteprima'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _hasChanges && !_isLoading ? _saveTemplate : null,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('Salva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              padding: EdgeInsets.symmetric(vertical: 2.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}