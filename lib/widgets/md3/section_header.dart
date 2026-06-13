import 'package:flutter/material.dart';

class M3SectionHeader extends StatelessWidget {
  const M3SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (actionLabel != null)
          TextButton(onPressed: onTap, child: Text(actionLabel!)),
      ],
    );
  }
}
