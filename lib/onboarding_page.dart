import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'widgets.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onFinish;

  const OnboardingPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        // 1. Градиентный фон остается без изменений
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surface.withOpacity(0.2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // ИСПОЛЬЗУЕМ LayoutBuilder, чтобы получить реальную высоту экрана
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    // ЗАДАЕМ минимальную высоту контента равной высоте экрана
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight( // Помогает Column правильно рассчитать высоту
                      child: Column(
                        // ИЗМЕНЕНИЕ: MainAxisAlignment.center больше не нужен здесь
                        children: [
                          // УБРАЛИ ПЕРВЫЙ Spacer()
                          const SizedBox(height: 48), // Вместо Spacer используем отступ
                          
                          Hero(
                            tag: 'appLogo',
                            child: ThemedAppLogo(),
                          ),
                          const SizedBox(height: 24),
                          
                          GradientText(
                            l10n.onboarding_title,
                            gradient: blueGradient,
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

                          // ИЗМЕНЕНИЕ: Заменяем второй Spacer на Expanded
                          // Expanded будет работать внутри IntrinsicHeight + Column
                          const Expanded(
                            child: SizedBox(height: 32), // Минимальный отступ до кнопки
                          ),

                          GradientButton(
                            text: l10n.onboarding_button,
                            gradient: greenGradient,
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
        ),
      ),
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
