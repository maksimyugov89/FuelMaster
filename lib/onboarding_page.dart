import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'widgets.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onFinish;

  const OnboardingPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark; // Проверяем тему
    final l10n = AppLocalizations.of(context)!;

    // --- ШАГ 1: Выносим всё содержимое страницы в отдельный виджет ---
    final pageContent = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      Hero(
                        tag: 'appLogo',
                        child: ThemedAppLogo(),
                      ),
                      const SizedBox(height: 24),
                      GradientText(
                        l10n.onboarding_title,
                        gradient: primaryActionGradient,
                        style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      _buildFeatureCard(
                        context,
                        icon: Icons.directions_car,
                        title: l10n.onboarding_step1_title,
                        description: l10n.onboarding_step1_desc,
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        context,
                        icon: Icons.calculate,
                        title: l10n.onboarding_step2_title,
                        description: l10n.onboarding_step2_desc,
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        context,
                        icon: Icons.bar_chart,
                        title: l10n.onboarding_step3_title,
                        description: l10n.onboarding_step3_desc,
                      ),
                      const Expanded(
                        child: SizedBox(height: 32),
                      ),
                      GradientButton(
                        text: l10n.onboarding_button,
                        gradient: primaryActionGradient,
                        iconData: Icons.arrow_forward,
                        onPressed: onFinish,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    // --- ШАГ 2: Собираем финальный экран с фоном ---
    return Scaffold(
      // Убираем старый фон, который был в Container
      body: GradientBackground(child: pageContent), // Для светлой - применяем наш новый фон
    );
  }

  // Метод _buildFeatureCard остается без изменений
  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String title, required String description}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4.0,
      shadowColor: theme.colorScheme.primary.withOpacity(0.1),
      color: theme.cardTheme.color?.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(icon, size: 28, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
