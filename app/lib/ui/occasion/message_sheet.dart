import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/wajb_store.dart';
import '../../engines/message_engine.dart';
import '../../models/ledger_entry.dart';
import '../../models/occasion.dart';
import '../../models/person.dart';
import '../store_scope.dart';

Future<void> showMessageSheet(
  BuildContext context, {
  required Occasion occasion,
  required Person person,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _MessageSheet(occasion: occasion, person: person),
    ),
  );
}

/// صياغة الرسالة.
///
/// خط أحمر: التعديل البشري خطوة إلزامية، ولا إرسال آلي إطلاقاً. الزر
/// النهائي ينسخ النص المعتمد إلى الحافظة ليرسله المستخدم بنفسه من تطبيق
/// المراسلة الذي يختاره.
class _MessageSheet extends StatefulWidget {
  const _MessageSheet({required this.occasion, required this.person});

  final Occasion occasion;
  final Person person;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  final MessageEngine _engine = const MessageEngine();
  final MessageDispatcher _dispatcher = const MessageDispatcher();
  late final TextEditingController _controller;
  MessageTone _tone = MessageTone.dialect;
  int _variant = 0;
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _currentDraft().text);
    _controller.addListener(() {
      // أي تعديل بعد المصادقة يُبطلها ويوجب اعتماداً جديداً.
      if (_reviewed) setState(() => _reviewed = false);
    });
  }

  MessageDraft _currentDraft() => _engine.draft(
        type: widget.occasion.type,
        person: widget.person,
        tone: _tone,
        variant: _variant,
      );

  void _regenerate() {
    setState(() {
      _variant++;
      _reviewed = false;
      _controller.text = _currentDraft().text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = StoreScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('رسالة مناسبة', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'الصياغة تختلف بحسب المناسبة ودرجة القرب — '
            '${widget.person.tier.label}.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<MessageTone>(
            segments: MessageTone.values
                .map((t) => ButtonSegment<MessageTone>(
                      value: t,
                      label: Text(t.label),
                    ))
                .toList(),
            selected: {_tone},
            onSelectionChanged: (selection) => setState(() {
              _tone = selection.first;
              _reviewed = false;
              _controller.text = _currentDraft().text;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'النص (عدّله كما يناسبك)',
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('صياغة أخرى'),
            ),
          ),
          CheckboxListTile(
            value: _reviewed,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) => setState(() => _reviewed = value ?? false),
            title: const Text('راجعت النص وأعتمده'),
            subtitle: const Text('التطبيق لا يرسل أي رسالة نيابةً عنك.'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _reviewed ? () => _copyApproved(store) : null,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('نسخ النص لإرساله بنفسك'),
          ),
        ],
      ),
    );
  }

  void _copyApproved(WajbStore store) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // المصادقة تؤخذ على النص كما يراه المستخدم في هذه اللحظة بالضبط.
    final draft = _currentDraft().approve(_controller.text);
    final text = _dispatcher.send(draft);

    Clipboard.setData(ClipboardData(text: text));
    store.markDone(widget.occasion, LedgerAction.message);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('نُسخ النص — أرسله من تطبيقك المفضل')),
    );
  }
}
