import 'package:flutter/material.dart';

import '../data/activity_store.dart';
import '../data/ai_store.dart';
import '../data/glucose_store.dart';
import '../data/insulin_store.dart';
import '../data/meal_store.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';

/// The patient types a sentence ("My glucose is 125 and I took 5 units of
/// insulin"); the assistant shows what it understood (POST /ai/parse, nothing
/// saved) and saves the entries only after the patient confirms them
/// (POST /patients/{id}/ai-entries). The assistant understands English.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.store, this.onSaved});

  /// Defaults to [aiStore]; tests pass one with a fake backend.
  final AiStore? store;

  /// Called after entries were saved. Defaults to reloading the patient's
  /// glucose, insulin, meal and activity logs so the dashboard shows them.
  final Future<void> Function()? onSaved;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

/// What happened to the entries of one assistant answer.
enum EntriesState { waiting, saving, saved, cancelled }

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final List<ChatMessage> messages = [
    ChatMessage(
      text:
          'Hello! I am your DiaMate Assistant. Tell me what you measured, '
          'took, ate or did, and I will add it to your logs.',
      isUser: false,
    ),
    ChatMessage(
      text:
          'For example: "My glucose is 125 and I took 5 units of insulin".',
      isUser: false,
    ),
  ];

  /// True while /ai/parse is answering; the send button waits meanwhile.
  bool isSending = false;

  AiStore get _store => widget.store ?? aiStore;

  void _addMessage(ChatMessage message) {
    setState(() {
      messages.add(message);
    });
    _scrollToEnd();
  }

  Future<void> _sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    if (message.length > AiStore.maxTextLength) {
      _addMessage(ChatMessage(
        text: 'That is a bit long. Please keep it under '
            '${AiStore.maxTextLength} characters.',
        isUser: false,
        isError: true,
      ));
      return;
    }

    setState(() {
      messages.add(ChatMessage(text: message, isUser: true));
      messageController.clear();
      isSending = true;
    });
    _scrollToEnd();

    try {
      final result = await _store.parse(message);

      if (!mounted) {
        return;
      }

      setState(() {
        isSending = false;

        if (result.entries.isEmpty) {
          messages.add(ChatMessage(
            text: result.message?.isNotEmpty == true
                ? result.message!
                : 'I could not find a glucose, insulin, meal or activity '
                    'value in that. Try "I walked for 30 minutes".',
            isUser: false,
          ));
        } else {
          messages.add(ChatMessage(
            text: result.savable.isEmpty
                ? 'I understood this, but something is missing:'
                : 'Here is what I understood. Shall I save it?',
            isUser: false,
            result: result,
          ));
        }
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSending = false;
        messages.add(ChatMessage(text: e.message, isUser: false, isError: true));
      });
    }

    _scrollToEnd();
  }

  Future<void> _save(ChatMessage message) async {
    final entries = message.result!.savable;

    setState(() {
      message.state = EntriesState.saving;
    });

    try {
      final saved = await _store.save(entries);

      if (!mounted) {
        return;
      }

      setState(() {
        message.state = EntriesState.saved;
      });

      _addMessage(ChatMessage(
        text: saved == 1
            ? 'Saved 1 entry to your logs.'
            : 'Saved $saved entries to your logs.',
        isUser: false,
      ));

      await (widget.onSaved ?? _reloadLogs)();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        message.state = EntriesState.waiting;
      });

      _addMessage(ChatMessage(text: e.message, isUser: false, isError: true));
    }
  }

  void _cancel(ChatMessage message) {
    setState(() {
      message.state = EntriesState.cancelled;
    });

    _addMessage(ChatMessage(
      text: 'Okay, nothing was saved.',
      isUser: false,
    ));
  }

  /// The dashboard reads these stores; a failed reload only means it shows
  /// the new entries a little later.
  static Future<void> _reloadLogs() async {
    try {
      await Future.wait([
        glucoseStore.load(),
        insulinStore.load(),
        mealStore.load(),
        activityStore.load(),
      ]);
    } on ApiException {
      // The entries are saved; the dashboard reloads them next time.
    }
  }

  void _scrollToEnd() {
    Future.delayed(
      const Duration(milliseconds: 100),
      () {
        if (!mounted || !scrollController.hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
    );
  }

  /// The quick prompts are examples with made-up numbers, so they only fill
  /// the text field: sending one as is would offer to save fake values.
  void _fillExample(String text) {
    messageController.text = text;
    messageController.selection =
        TextSelection.collapsed(offset: text.length);
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('DiaMate Assistant'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: Column(
        children: [
          _buildAssistantHeader(),

          const SizedBox(height: 10),

          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                18,
              ),
              itemCount: messages.length + (isSending ? 1 : 0),
              itemBuilder: (context, index) {
                // The last row while /ai/parse is answering.
                if (index == messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ChatBubble(
                      message: ChatMessage(text: 'Thinking…', isUser: false),
                    ),
                  );
                }

                final message = messages[index];

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: message.result == null
                      ? _ChatBubble(message: message)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChatBubble(message: message),
                            const SizedBox(height: 8),
                            _EntriesCard(
                              result: message.result!,
                              state: message.state,
                              onSave: () => _save(message),
                              onCancel: () => _cancel(message),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),

          _buildQuickPrompts(),

          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildAssistantHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE9FA),
              Color(0xFFF1EBFF),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Color(0xFF8B62D6),
                size: 30,
              ),
            ),

            const SizedBox(width: 13),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Health Companion',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF392F4A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Log glucose, insulin, meals and activity in one sentence.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFF786B84),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8B62D6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(
        left: 18,
        right: 8,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Tapping one puts an example in the text field to edit, not send.
          _QuickPrompt(
            label: 'Glucose',
            icon: Icons.water_drop_outlined,
            onTap: () => _fillExample('My glucose is 125'),
          ),

          _QuickPrompt(
            label: 'Insulin',
            icon: Icons.vaccines_outlined,
            onTap: () => _fillExample('I took 5 units of insulin'),
          ),

          _QuickPrompt(
            label: 'Meal',
            icon: Icons.restaurant_outlined,
            onTap: () => _fillExample('I ate 45 grams of carbs'),
          ),

          _QuickPrompt(
            label: 'Activity',
            icon: Icons.directions_walk_rounded,
            onTap: () => _fillExample('I walked for 30 minutes'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  _sendMessage();
                },
                decoration: InputDecoration(
                  hintText: 'e.g. My glucose is 125',
                  prefixIcon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7FAFD),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFFE3EAF1),
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFF8B62D6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF8B62D6),
                borderRadius: BorderRadius.circular(17),
              ),
              child: IconButton(
                tooltip: 'Send',
                onPressed: isSending ? null : _sendMessage,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  /// An error from the backend (shown in red).
  final bool isError;

  /// The entries the assistant understood, shown under the text.
  final AiParseResult? result;

  /// Whether [result] was saved, cancelled or still waits for the patient.
  EntriesState state = EntriesState.waiting;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.result,
  });
}

/// The understood entries with Save / Cancel. Entries the assistant could not
/// read completely (MISSING_VALUE, INVALID_VALUE) are listed with the reason
/// and are not saved.
class _EntriesCard extends StatelessWidget {
  final AiParseResult result;
  final EntriesState state;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EntriesCard({
    required this.result,
    required this.state,
    required this.onSave,
    required this.onCancel,
  });

  static const Color _purple = Color(0xFF8B62D6);
  static const Color _muted = Color(0xFF718096);

  static IconData _icon(String intent) => switch (intent) {
        AiEntry.glucose => Icons.water_drop_outlined,
        AiEntry.insulin => Icons.vaccines_outlined,
        AiEntry.meal => Icons.restaurant_outlined,
        AiEntry.activity => Icons.directions_walk_rounded,
        _ => Icons.edit_note_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final canSave = result.savable.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(left: 42),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in result.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _icon(entry.intent),
                    size: 20,
                    color: entry.canSave ? _purple : _muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          entry.canSave
                              ? '${formatNumber(entry.value!)} ${entry.unit ?? ''}'
                                  .trim()
                              : entry.message ?? 'Value missing',
                          style: TextStyle(
                            fontSize: 12,
                            color: entry.canSave
                                ? const Color(0xFF334155)
                                : const Color(0xFFE85D75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (canSave) ...[
            const SizedBox(height: 4),
            switch (state) {
              EntriesState.saved => const Text(
                  'Saved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF35B779),
                  ),
                ),
              EntriesState.cancelled => const Text(
                  'Not saved',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              _ => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          state == EntriesState.saving ? null : onCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: state == EntriesState.saving ? null : onSave,
                      style: FilledButton.styleFrom(backgroundColor: _purple),
                      child: Text(
                        state == EntriesState.saving ? 'Saving…' : 'Save',
                      ),
                    ),
                  ],
                ),
            },
          ],
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 18,
                color: Color(0xFF8B62D6),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 310,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF8B62D6)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                    isUser ? 18 : 5,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 5 : 18,
                  ),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: const Color(0xFFE5EAF0),
                      ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isUser
                      ? Colors.white
                      : message.isError
                          ? const Color(0xFFE85D75)
                          : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPrompt extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickPrompt({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
      ),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(
          icon,
          size: 16,
          color: const Color(0xFF8B62D6),
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5E5270),
          ),
        ),
        backgroundColor: const Color(0xFFF5F1FF),
        side: const BorderSide(
          color: Color(0xFFE7DFFF),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}