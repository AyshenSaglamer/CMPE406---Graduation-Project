import 'package:flutter/material.dart';

import '../screens/ai_assistant_screen.dart';

/// Assistant button for the bottom-right corner of the patient's screens.
/// Use it as a Scaffold's `floatingActionButton`, so it sits above the
/// navigation bar and moves up with the keyboard.
///
/// Looks like the assistant's own icon (purple robot on the pink-lilac
/// gradient of the assistant header), so the button and the screen it opens
/// read as the same thing.
///
/// Not used on the entry forms (their Save button is at the bottom) or on
/// the assistant screen itself.
///
/// A screen that shows it ends its scrolling content with
/// [scrollClearance] of bottom padding, so the last item can be scrolled
/// out from under the button.
class AiChatButton extends StatelessWidget {
  /// The 62 dp button, its 16 dp margin and a little air.
  static const double scrollClearance = 96;

  const AiChatButton({super.key});

  static const assistantPurple = Color(0xFF8B62D6);

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    return Tooltip(
      message: 'DiaMate Assistant',
      child: Semantics(
        button: true,
        child: Container(
          width: 62,
          height: 62,
          decoration: ShapeDecoration(
            shape: shape,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE9FA), Color(0xFFF1EBFF)],
            ),
            shadows: [
              BoxShadow(
                color: assistantPurple.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(context),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: assistantPurple,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
