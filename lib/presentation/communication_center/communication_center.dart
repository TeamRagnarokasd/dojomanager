import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import 'package:intl/intl.dart';

class CommunicationCenter extends StatefulWidget {
  const CommunicationCenter({super.key});

  @override
  State<CommunicationCenter> createState() => _CommunicationCenterState();
}

class _CommunicationCenterState extends State<CommunicationCenter>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedRecipientGroup = 'all';
  String _messageTemplate = 'custom';
  bool _isLoading = true;
  bool _isSending = false;

  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _templates = [];
  final List<Map<String, dynamic>> _scheduledMessages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCommunicationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunicationData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService.instance.client;

      // Load existing communications
      final response = await supabase
          .from('admin_communications')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _messages.clear();
        for (var item in response) {
          _messages.add({
            'id': item['id'],
            'subject': item['title'],
            'preview': item['content'].toString().length > 100
                ? '${item['content'].toString().substring(0, 100)}...'
                : item['content'].toString(),
            'status': item['status'],
            'recipients': _getRecipientCount(item['target_audience']),
            'sent_at': DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.parse(item['created_at'])),
            'target_audience': item['target_audience'],
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading communication data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getRecipientCount(String audience) {
    switch (audience) {
      case 'students':
        return 120;
      case 'instructors':
        return 15;
      case 'admins':
        return 5;
      case 'active_subscriptions':
        return 95;
      case 'expired_subscriptions':
        return 25;
      default:
        return 140;
    }
  }

  Future<void> _sendMessage() async {
    if (_subjectController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci oggetto e messaggio')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final supabase = SupabaseService.instance.client;

      await supabase.from('admin_communications').insert({
        'title': _subjectController.text.trim(),
        'content': _contentController.text.trim(),
        'target_audience': _selectedRecipientGroup,
        'sender_id': supabase.auth.currentUser?.id,
        'status': 'sent',
      });

      _subjectController.clear();
      _contentController.clear();
      setState(() => _selectedRecipientGroup = 'all');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaggio inviato con successo!')),
      );

      await _loadCommunicationData();
      _tabController.animateTo(0); // Switch to messages tab
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'invio: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.secondaryLight))
          : Column(
              children: [
                _buildStatisticsHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMessagesTab(),
                      _buildComposeTab(),
                      _buildTemplatesTab(),
                      _buildScheduledTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildQuickComposeFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Centro Comunicazioni',
        style: GoogleFonts.inter(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_active_outlined,
            color: Colors.white,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildStatisticsHeader() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard(
                  'Messaggi Inviati', '${_messages.length}', Icons.send),
              SizedBox(width: 12.w),
              _buildStatCard('Tasso Apertura', '89.2%', Icons.mark_email_read),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildStatCard('Programmati', '${_scheduledMessages.length}',
                  Icons.schedule),
              SizedBox(width: 12.w),
              _buildStatCard(
                  'Template', '${_templates.length}', Icons.text_snippet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.sp),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(12.sp),
          border: Border.all(color: AppTheme.secondaryLight.withAlpha(77)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.sp),
              decoration: BoxDecoration(
                color: AppTheme.secondaryLight.withAlpha(51),
                borderRadius: BorderRadius.circular(8.sp),
              ),
              child: Icon(
                icon,
                color: AppTheme.secondaryLight,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.primaryColor,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.secondaryLight,
        labelColor: AppTheme.secondaryLight,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Messaggi'),
          Tab(text: 'Componi'),
          Tab(text: 'Template'),
          Tab(text: 'Programmati'),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Container(
      color: AppTheme.backgroundDark,
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState('Nessun messaggio inviato')
                : RefreshIndicator(
                    onRefresh: _loadCommunicationData,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.sp),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageCard(message);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab() {
    return Container(
      color: AppTheme.backgroundDark,
      padding: EdgeInsets.all(16.sp),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecipientSelection(),
            SizedBox(height: 16.h),
            _buildTemplateSelection(),
            SizedBox(height: 16.h),
            _buildMessageEditor(),
            SizedBox(height: 24.h),
            _buildSendActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return Container(
      color: AppTheme.backgroundDark,
      child: _templates.isEmpty
          ? _buildEmptyState('Nessun template disponibile')
          : ListView.builder(
              padding: EdgeInsets.all(16.sp),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return _buildTemplateCard(template);
              },
            ),
    );
  }

  Widget _buildScheduledTab() {
    return Container(
      color: AppTheme.backgroundDark,
      child: _scheduledMessages.isEmpty
          ? _buildEmptyState('Nessun messaggio programmato')
          : ListView.builder(
              padding: EdgeInsets.all(16.sp),
              itemCount: _scheduledMessages.length,
              itemBuilder: (context, index) {
                final message = _scheduledMessages[index];
                return _buildScheduledMessageCard(message);
              },
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      color: AppTheme.backgroundDark,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Cerca messaggi...',
          hintStyle: GoogleFonts.inter(color: Colors.white60),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.white60,
          ),
          filled: true,
          fillColor: AppTheme.primaryColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.sp),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          // TODO: Implement search functionality
        },
      ),
    );
  }

  Widget _buildRecipientSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destinatari',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _buildRecipientChip('Tutti', 'all'),
            _buildRecipientChip('Studenti', 'students'),
            _buildRecipientChip('Istruttori', 'instructors'),
            _buildRecipientChip('Amministratori', 'admins'),
            _buildRecipientChip('Abbonamenti Attivi', 'active_subscriptions'),
            _buildRecipientChip('Abbonamenti Scaduti', 'expired_subscriptions'),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipientChip(String label, String value) {
    final isSelected = _selectedRecipientGroup == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : Colors.white70,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedRecipientGroup = value);
      },
      backgroundColor: AppTheme.primaryColor,
      selectedColor: AppTheme.secondaryLight,
      side: BorderSide(
        color: isSelected ? AppTheme.secondaryLight : Colors.white30,
        width: 1.sp,
      ),
    );
  }

  Widget _buildTemplateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Template Messaggio',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: _messageTemplate,
          style: GoogleFonts.inter(color: Colors.white),
          dropdownColor: AppTheme.primaryColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.primaryColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.sp),
              borderSide: BorderSide(color: Colors.white30),
            ),
          ),
          items: [
            DropdownMenuItem(
                value: 'custom', child: Text('Messaggio Personalizzato')),
            DropdownMenuItem(
                value: 'class_cancelled', child: Text('Lezione Cancellata')),
            DropdownMenuItem(
                value: 'payment_reminder', child: Text('Promemoria Pagamento')),
            DropdownMenuItem(
                value: 'event_announcement', child: Text('Annuncio Evento')),
            DropdownMenuItem(
                value: 'welcome', child: Text('Messaggio di Benvenuto')),
          ],
          onChanged: (value) {
            setState(() => _messageTemplate = value!);
            _applyTemplate(value!);
          },
        ),
      ],
    );
  }

  void _applyTemplate(String template) {
    switch (template) {
      case 'class_cancelled':
        _subjectController.text = 'Lezione Cancellata';
        _contentController.text =
            'La lezione di oggi è stata cancellata. Sarà recuperata il [data]. Ci scusiamo per l\'inconveniente.';
        break;
      case 'payment_reminder':
        _subjectController.text = 'Promemoria Pagamento';
        _contentController.text =
            'Il tuo abbonamento scadrà tra 3 giorni. Rinnova ora per continuare ad allenarti senza interruzioni.';
        break;
      case 'event_announcement':
        _subjectController.text = 'Nuovo Evento';
        _contentController.text =
            'È stato organizzato un evento speciale. Partecipa e divertiti con noi!';
        break;
      case 'welcome':
        _subjectController.text = 'Benvenuto nel Team Ragnarok';
        _contentController.text =
            'Benvenuto nella famiglia del Team Ragnarok! Siamo felici di averti con noi.';
        break;
    }
  }

  Widget _buildMessageEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Oggetto',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _subjectController,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Inserisci oggetto...',
            hintStyle: GoogleFonts.inter(color: Colors.white60),
            filled: true,
            fillColor: AppTheme.primaryColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.sp),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'Messaggio',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 200.h,
          child: TextField(
            controller: _contentController,
            maxLines: null,
            expands: true,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Scrivi il tuo messaggio...',
              hintStyle: GoogleFonts.inter(color: Colors.white60),
              filled: true,
              fillColor: AppTheme.primaryColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.sp),
                borderSide: BorderSide.none,
              ),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSending
                ? null
                : () {
                    // TODO: Implement schedule message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Funzionalità di programmazione in arrivo')),
                    );
                  },
            icon: const Icon(
              Icons.schedule,
              color: Colors.white,
            ),
            label: Text(
              'Programma',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.sp),
                side: BorderSide(color: AppTheme.secondaryLight),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Icon(
                    Icons.send,
                    color: AppTheme.primaryColor,
                  ),
            label: Text(
              _isSending ? 'Invio...' : 'Invia Ora',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryLight,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.sp),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message['subject'] ?? 'Nessun oggetto',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryLight.withAlpha(51),
                  borderRadius: BorderRadius.circular(8.sp),
                ),
                child: Text(
                  message['status'] ?? 'Inviato',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryLight,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            message['preview'] ?? 'Anteprima messaggio...',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.group,
                size: 14.sp,
                color: Colors.white60,
              ),
              SizedBox(width: 4.w),
              Text(
                '${message['recipients'] ?? 0} destinatari',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
              const Spacer(),
              Text(
                message['sent_at'] ??
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template['name'] ?? 'Template senza nome',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  // TODO: Use template in compose tab
                  _tabController.animateTo(1);
                },
                icon: Icon(
                  Icons.edit,
                  color: AppTheme.secondaryLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            template['description'] ?? 'Descrizione template...',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledMessageCard(Map<String, dynamic> message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: AppTheme.secondaryLight.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message['subject'] ?? 'Nessun oggetto',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              PopupMenuButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white60,
                ),
                color: AppTheme.primaryColor,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Text('Modifica',
                        style: GoogleFonts.inter(color: Colors.white)),
                    value: 'edit',
                  ),
                  PopupMenuItem(
                    child: Text('Elimina',
                        style:
                            GoogleFonts.inter(color: AppTheme.secondaryLight)),
                    value: 'delete',
                  ),
                ],
                onSelected: (value) {
                  // TODO: Handle scheduled message actions
                },
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            message['preview'] ?? 'Anteprima messaggio...',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryLight.withAlpha(51),
                  borderRadius: BorderRadius.circular(8.sp),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12.sp,
                      color: AppTheme.secondaryLight,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      message['scheduled_at'] ??
                          DateFormat('dd/MM HH:mm').format(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${message['recipients'] ?? 0} destinatari',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 48.sp,
            color: Colors.white30,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickComposeFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        _tabController.animateTo(1);
      },
      backgroundColor: AppTheme.secondaryLight,
      icon: Icon(
        Icons.edit,
        color: AppTheme.primaryColor,
      ),
      label: Text(
        'Componi',
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}