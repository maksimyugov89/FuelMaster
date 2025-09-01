import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:fuelmaster/providers/app_settings_provider.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'package:fuelmaster/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _purchasePremium(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    const String premiumProductId = 'fuelmaster_premium_subscription';
    final InAppPurchase iap = InAppPurchase.instance;

    try {
      final bool available = await iap.isAvailable();
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.store_unavailable)),
        );
        return;
      }

      final ProductDetailsResponse response = await iap.queryProductDetails({premiumProductId});
      if (response.productDetails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.product_not_found)),
        );
        return;
      }

      final ProductDetails product = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      await iap.buyNonConsumable(purchaseParam: purchaseParam);

      iap.purchaseStream.listen((List<PurchaseDetails> purchases) async {
        for (var purchase in purchases) {
          if (purchase.status == PurchaseStatus.purchased) {
            appSettings.setPremium(true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.premium_activated)),
            );
            logger.d('Premium activated successfully');
          } else if (purchase.status == PurchaseStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.purchase_error)),
            );
            logger.e('Purchase error: ${purchase.error}');
          }
          if (purchase.pendingCompletePurchase) {
            await iap.completePurchase(purchase);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
      logger.e('Purchase exception: $e');
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.userEmailKey);
      await prefs.remove(AppConstants.userCityKey);
      await prefs.remove(AppConstants.userCountryKey);
      appSettings.setRegistered(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sign_out_success)),
      );
      logger.d('User signed out successfully');
    } catch (e) {
      logger.e('Sign out error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
    }
  }

    Widget _buildStyledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    // 1. Контейнер для рамки, фона и отступов
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      // 2. Убираем стандартное уродливое подчеркивание
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true, // Растягиваем на всю ширину
          dropdownColor: theme.cardTheme.color,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final currentLanguage = appSettings.locale.languageCode;
    final _isSignedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 120.0, // Используем 'toolbarHeight' для задания высоты
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false, 
        flexibleSpace: FlexibleSpaceBar( // flexibleSpace можно использовать и здесь
          background: Hero(
            tag: 'appLogo',
            child: Image.asset(
              'assets/fuelmaster_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      // --- Основное содержимое экрана ---
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- 2. Карточка "Внешний вид" ---
          // Группируем настройки темы и языка в один блок
          Card(
            elevation: 4.0,
            shadowColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Градиентный заголовок
                  GradientText(
                    l10n.theme, // "Тема"
                    gradient: blueGradient, // Синий градиент, как на других экранах
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Используем наш новый красивый выпадающий список
                  _buildStyledDropdown(
                    value: appSettings.themeMode,
                    items: [
                      DropdownMenuItem(value: 'auto', child: Text(l10n.auto)),
                      DropdownMenuItem(value: 'light', child: Text(l10n.light)),
                      DropdownMenuItem(value: 'dark', child: Text(l10n.dark)),
                    ],
                    onChanged: (value) {
                      if (value != null) appSettings.setTheme(value);
                    },
                  ),
                  const SizedBox(height: 24), // Увеличенный отступ между настройками
                  // Еще один градиентный заголовок
                  GradientText(
                    l10n.language, // "Язык"
                    gradient: blueGradient,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Снова используем наш шаблон
                  _buildStyledDropdown(
                    value: currentLanguage,
                    items: [
                      DropdownMenuItem(value: 'ru', child: Text(l10n.russian)),
                      DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                    ],
                    onChanged: (value) {
                      if (value != null) appSettings.setLocale(Locale(value));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- 3. Карточка "Премиум" ---
          Card(
            elevation: 4.0,
            shadowColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    l10n.premium_subscription,
                    gradient: orangeGradient, // Оранжевый для привлечения внимания
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Логика: если премиум куплен - показываем текст.
                  // Если нет - показываем зеленую кнопку "Купить".
                  appSettings.isPremium
                      ? Center(
                          child: Text(
                            l10n.premium_active,
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                      : GradientButton(
                          text: l10n.buy,
                          gradient: greenGradient, // Зеленый для "призыва к действию"
                          iconData: Icons.star,
                          onPressed: () => _purchasePremium(context),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- 4. Кнопка выхода из аккаунта ---
          // Показывается только если пользователь вошел в систему
          if (_isSignedIn)
            GradientButton(
              text: l10n.sign_out,
              // Красный градиент для "опасного" действия
              gradient: LinearGradient( 
                colors: [Colors.red.shade500, Colors.red.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              iconData: Icons.logout,
              onPressed: () => _signOut(context),
            ),
        ],
      ),
    );
  }
}