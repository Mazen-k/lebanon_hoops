import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Simple empty / coming-soon body used by menu routes and games tabs.
class MenuPlaceholderPage extends StatelessWidget {
  const MenuPlaceholderPage({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_outlined, size: 56, color: AppColors.secondary.withAlpha(180)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
