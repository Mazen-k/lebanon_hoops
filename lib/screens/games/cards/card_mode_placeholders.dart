import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../../../widgets/menu_placeholder_page.dart';

class OneVOnePage extends StatelessWidget {
  const OneVOnePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('1v1'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: const MenuPlaceholderPage(
        title: '1v1',
        subtitle: 'Head-to-head card battles — coming soon.',
      ),
    );
  }
}

class SbcPage extends StatelessWidget {
  const SbcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('SBC'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: const MenuPlaceholderPage(
        title: 'SBC',
        subtitle: 'Squad building challenges — coming soon.',
      ),
    );
  }
}

