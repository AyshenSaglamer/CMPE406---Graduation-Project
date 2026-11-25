import 'package:flutter/material.dart';

/// App bar title of an entry screen. With [forName] (a caregiver logging
/// for a family member) it says whose diary the entry goes to.
class EntryTitle extends StatelessWidget {
  const EntryTitle(this.title, {super.key, this.forName});

  final String title;
  final String? forName;

  @override
  Widget build(BuildContext context) {
    final name = forName;
    final titleText = Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800),
    );

    if (name == null) {
      return titleText;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleText,
        Text(
          'For $name',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF765BD4),
          ),
        ),
      ],
    );
  }
}
