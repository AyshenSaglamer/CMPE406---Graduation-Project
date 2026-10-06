import 'package:flutter/material.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final List<ChatMessage> messages = [
    ChatMessage(
      text:
          'Hello! I am your DiaMate Assistant. How can I help you today?',
      isUser: false,
    ),
    ChatMessage(
      text:
          'You can ask about your health records, glucose trends, meals, insulin, or activity.',
      isUser: false,
    ),
  ];

  void _sendMessage() {
    final message = messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    setState(() {
      messages.add(
        ChatMessage(
          text: message,
          isUser: true,
        ),
      );

      messages.add(
        const ChatMessage(
          text:
              'Your message was received. AI-powered responses will be connected to the backend.',
          isUser: false,
        ),
      );

      messageController.clear();
    });

    Future.delayed(
      const Duration(milliseconds: 100),
      () {
        if (!scrollController.hasClients) {
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

  void _sendQuickPrompt(String text) {
    messageController.text = text;
    _sendMessage();
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
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _ChatBubble(
                    message: messages[index],
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
                    'Ask questions about your DiaMate records.',
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
          _QuickPrompt(
            label: 'Glucose trends',
            icon: Icons.show_chart_rounded,
            onTap: () {
              _sendQuickPrompt(
                'Can you help me understand my glucose trends?',
              );
            },
          ),

          _QuickPrompt(
            label: 'My records',
            icon: Icons.analytics_outlined,
            onTap: () {
              _sendQuickPrompt(
                'Can you summarize my recent health records?',
              );
            },
          ),

          _QuickPrompt(
            label: 'Meals',
            icon: Icons.restaurant_outlined,
            onTap: () {
              _sendQuickPrompt(
                'Can you help me review my meal records?',
              );
            },
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
                  hintText: 'Ask something...',
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
                onPressed: _sendMessage,
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

  const ChatMessage({
    required this.text,
    required this.isUser,
  });
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