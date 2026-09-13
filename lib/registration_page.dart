import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:fuelmaster/utils/env_config.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuelmaster/widgets.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';
import 'package:fuelmaster/services/email_verification_service.dart';

class RegistrationPage extends StatefulWidget {
  final VoidCallback onRegistered;
  final Locale locale;

  const RegistrationPage({super.key, required this.onRegistered, required this.locale});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode cityFocus = FocusNode();
  String? _countryCode;
  String? selectedCity;
  bool _isApiKeyMissing = false;
  bool _isInitialLoad = true;
  bool _isProgrammaticChange = false;
  bool _isFetchingSuggestions = false;
  bool _isAuthenticating = false;
  bool _isLoginMode = false;
  Future<String?>? _locationFuture;
  List<Map<String, dynamic>> _citySuggestions = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final apiKey = EnvConfig.getOptional('GEOAPIFY_API_KEY');
    _isApiKeyMissing = apiKey == null || apiKey.isEmpty;
    if (_isApiKeyMissing) {
      logger.e('Geoapify API key is missing or empty in RegistrationPage');
    }
    _locationFuture = _loadInitialLocation();
    cityController.addListener(_onCityTextChanged);
  }
  
  @override
  void dispose() {
    cityController.removeListener(_onCityTextChanged);
    _debounceTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    cityController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    cityFocus.dispose();
    super.dispose();
  }

  Future<String?> _loadInitialLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('user_city');
    if (savedCity != null) {
      setState(() {
        _isProgrammaticChange = true;
        cityController.text = savedCity;
        selectedCity = savedCity;
        _countryCode = prefs.getString('user_country') ?? _mapLocaleToCountryCode(widget.locale.languageCode);
        _isProgrammaticChange = false;
        _isInitialLoad = false;
      });
      logger.d('Загружен сохранённый город (${savedCity.length} симв.)');
      return savedCity;
    }
    return _setDefaultCity();
  }

  String _mapLocaleToCountryCode(String locale) {
    return locale == 'ru' ? 'ru' : 'us';
  }

  Future<String?> _setDefaultCity([String? errorMessage]) async {
    final defaultCity = widget.locale.languageCode == 'ru' ? 'Москва' : 'New York';
    final defaultCountry = _mapLocaleToCountryCode(widget.locale.languageCode);
    if (mounted) {
      setState(() {
        _isProgrammaticChange = true;
        cityController.text = defaultCity;
        selectedCity = defaultCity;
        _countryCode = defaultCountry;
        _isProgrammaticChange = false;
        _isInitialLoad = false;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_city', defaultCity);
    await prefs.setString('user_country', defaultCountry);
    if (errorMessage != null && mounted) {
      _showSnackBar(errorMessage);
    }
    logger.d('Установлен город по умолчанию');
    return defaultCity;
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await _fetchLocation();
      if (mounted) {
        setState(() {
          _locationFuture = Future.value(location);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationFuture = Future.value(null);
        });
        _showSnackBar(AppLocalizations.of(context)!.geocoding_error);
      }
    }
  }

  Future<String?> _fetchLocation() async {
    // B-13: l10n берём до первого await — иначе BuildContext используется
    // после асинхронного разрыва (Geolocator, HTTP-запрос).
    final l10n = AppLocalizations.of(context)!;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _setDefaultCity(l10n.location_service_disabled);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _setDefaultCity(l10n.location_permission_denied);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _setDefaultCity(l10n.location_permission_denied_forever);
      }

      Position position = await Geolocator.getCurrentPosition();
      final apiKey = EnvConfig.getOptional('GEOAPIFY_API_KEY');
      if (apiKey == null || apiKey.isEmpty) {
        return _setDefaultCity(l10n.api_key_invalid);
      }

      final response = await http
          .get(Uri.parse(
              'https://api.geoapify.com/v1/geocode/reverse?lat=${position.latitude}&lon=${position.longitude}&apiKey=$apiKey'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      logger.d('Geoapify response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['features'] != null && data['features'].isNotEmpty) {
        final feature = data['features'][0]['properties'];
        final city = feature['city'] ?? feature['state'] ?? (widget.locale.languageCode == 'ru' ? 'Москва' : 'New York');
        final country = feature['country_code']?.toLowerCase() ?? _mapLocaleToCountryCode(widget.locale.languageCode);

        if (mounted) {
          setState(() {
            _isProgrammaticChange = true;
            cityController.text = city;
            selectedCity = city;
            _countryCode = country;
            _citySuggestions = [];
            _isProgrammaticChange = false;
            _isInitialLoad = false;
          });
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_city', city);
        await prefs.setString('user_country', country);
        await _setDefaultLanguage(country);
        logger.d('Город определён (${city.length} симв.)');
        return city;
      } else if (response.statusCode == 401) {
        logger.e('Geoapify API error: ${data['message'] ?? 'Invalid API key'}');
        return _setDefaultCity(l10n.api_key_invalid);
      } else {
        return _setDefaultCity(l10n.geocoding_error);
      }
    } catch (e) {
      logger.e('Error fetching location: $e');
      return _setDefaultCity(l10n.geocoding_error);
    }
  }

  Future<void> _setDefaultLanguage(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    final currentLanguage = prefs.getString('language') ?? widget.locale.languageCode;
    final newLanguage = countryCode == 'ru' ? 'ru' : 'en';
    if (currentLanguage != newLanguage) {
      await prefs.setString('language', newLanguage);
      if (mounted) {
        _showSnackBar(AppLocalizations.of(context)!.language_changed.replaceFirst('%s', newLanguage));
      }
      logger.d('Language set to $newLanguage based on country: $countryCode');
    }
  }

  void _onCityTextChanged() {
    if (_isProgrammaticChange || _isInitialLoad) return;

    final query = cityController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _citySuggestions = [];
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchCitySuggestions(query);
    });
  }

  Future<void> _fetchCitySuggestions(String query) async {
    if (_isApiKeyMissing) {
      logger.e('Cannot fetch city suggestions: Geoapify API key is missing');
      return;
    }

    setState(() {
      _isFetchingSuggestions = true;
    });

    try {
      final apiKey = EnvConfig.getOptional('GEOAPIFY_API_KEY');
      final response = await http
          .get(Uri.parse(
              'https://api.geoapify.com/v1/geocode/autocomplete?text=$query&type=city&limit=5&apiKey=$apiKey'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      logger.d('City suggestions response: ${response.statusCode}');

      if (response.statusCode == 200 && data['features'] != null) {
        final suggestions = (data['features'] as List<dynamic>).map((feature) {
          final properties = feature['properties'] as Map<String, dynamic>;
          return {
            'name': properties['city'] ?? properties['state'] ?? '',
            'country_name': properties['country'] ?? '',
            'country_code': properties['country_code']?.toLowerCase() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _citySuggestions = suggestions;
            _isFetchingSuggestions = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _citySuggestions = [];
            _isFetchingSuggestions = false;
          });
        }
      }
    } catch (e) {
      logger.e('Error fetching city suggestions: $e');
      if (mounted) {
        setState(() {
          _citySuggestions = [];
          _isFetchingSuggestions = false;
        });
      }
    }
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!;
    if (emailController.text.isEmpty || passwordController.text.isEmpty || cityController.text.isEmpty) {
      _showSnackBar(l10n.fill_all_fields);
      return;
    }
    if (!_isValidEmail(emailController.text)) {
      _showSnackBar(l10n.invalid_email);
      return;
    }
    if (passwordController.text.length < 6) {
      _showSnackBar(l10n.weak_password);
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // F-2: письмо подтверждения уходит сразу — иначе пользователь узнает о
      // нём только из напоминания на главном экране.
      final VerificationSendResult sendResult =
          await EmailVerificationService.send(respectCooldown: false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_city', cityController.text);
      await prefs.setString('user_country', _countryCode ?? _mapLocaleToCountryCode(widget.locale.languageCode));

      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'email': emailController.text.trim(),
        'city': cityController.text,
        'country': _countryCode,
        'created_at': FieldValue.serverTimestamp(),
      });

      final bool profileSaved = await _saveUserProfile(
        credential.user!.uid,
        email: emailController.text.trim(),
        city: cityController.text,
        country: _countryCode,
      );

      if (profileSaved) {
        _showSnackBar(l10n.registration_success);
        if (sendResult == VerificationSendResult.sent) {
          _showSnackBar(l10n.email_verify_sent(emailController.text.trim()));
        }
      } else {
        // B-10 аудита: аккаунт в Auth уже создан. Если оставить пользователя на
        // форме регистрации, повторная попытка ответит «email already in use», а
        // профиля в базе так и не будет. Переводим в режим входа — профиль
        // досоздастся сам (AccountService.ensureUserProfile).
        _showSnackBar(l10n.registration_profile_pending);
        setState(() => _isLoginMode = true);
      }
      widget.onRegistered();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = l10n.email_already_in_use;
          break;
        case 'invalid-email':
          errorMessage = l10n.invalid_email;
          break;
        case 'weak-password':
          errorMessage = l10n.weak_password;
          break;
        default:
          errorMessage = '${l10n.error}: ${e.message}';
      }
      _showSnackBar(errorMessage);
      logger.e('Registration error: $e');
    } catch (e) {
      _showSnackBar(l10n.error);
      logger.e('Unexpected error during registration: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackBar(l10n.fill_all_fields);
      return;
    }
    if (!_isValidEmail(emailController.text)) {
      _showSnackBar(l10n.invalid_email);
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      _showSnackBar(l10n.login_success);
      widget.onRegistered();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          errorMessage = l10n.invalid_credentials;
          break;
        case 'invalid-email':
          errorMessage = l10n.invalid_email;
          break;
        default:
          errorMessage = '${l10n.error}: ${e.message}';
      }
      _showSnackBar(errorMessage);
      logger.e('Login error: $e');
    } catch (e) {
      _showSnackBar(l10n.error);
      logger.e('Unexpected error during login: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  /// Пишет профиль пользователя в Firestore с ретраями (B-10 аудита).
  ///
  /// Раньше единственная попытка записи шла сразу после создания аккаунта: при
  /// сбое сети профиль терялся навсегда, а повторная регистрация тем же email
  /// уже невозможна. `merge: true` не затирает поля, если документ существует.
  Future<bool> _saveUserProfile(
    String uid, {
    required String email,
    required String city,
    required String? country,
  }) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
          'email': email,
          'city': city,
          'country': country,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      } catch (e) {
        logger.e('Профиль не сохранён (попытка $attempt из 3): $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    return false;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  Widget _buildCityField() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Stack(
      children: [
        TextField(
          controller: cityController,
          focusNode: cityFocus,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.location_city, color: theme.colorScheme.primary),
            labelText: l10n.city,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            suffixIcon: _isFetchingSuggestions
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          onSubmitted: (value) {
            if (_citySuggestions.isNotEmpty) {
              final suggestion = _citySuggestions[0];
              setState(() {
                _isProgrammaticChange = true;
                cityController.text = suggestion['name'];
                selectedCity = suggestion['name'];
                _countryCode = suggestion['country_code'] ?? _countryCode;
                _citySuggestions = [];
                _isProgrammaticChange = false;
              });
              _setDefaultLanguage(_countryCode ?? _mapLocaleToCountryCode(widget.locale.languageCode));
            }
            cityFocus.unfocus();
            emailFocus.unfocus();
            passwordFocus.unfocus();
          },
        ),
        if (_citySuggestions.isNotEmpty && cityController.text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _citySuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _citySuggestions[index];
                final cityName = suggestion['name'] ?? '';
                final countryName = suggestion['country_name'] ?? '';
                return ListTile(
                  leading: Icon(Icons.location_city, color: theme.colorScheme.primary),
                  title: Text(
                    countryName.isNotEmpty ? '$cityName, $countryName' : cityName,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _isProgrammaticChange = true;
                        cityController.text = cityName;
                        selectedCity = cityName;
                        _countryCode = suggestion['country_code'] ?? _countryCode;
                        _citySuggestions = [];
                        _isProgrammaticChange = false;
                      });
                    }
                    cityController.selection = TextSelection.fromPosition(
                      TextPosition(offset: cityName.length),
                    );
                    cityFocus.unfocus();
                    emailFocus.unfocus();
                    passwordFocus.unfocus();
                    _setDefaultLanguage(_countryCode ?? _mapLocaleToCountryCode(widget.locale.languageCode));
                    logger.d('Город выбран вручную');
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final pageContent = FutureBuilder<String?>(
      future: _locationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Lottie.asset('assets/loading_animation.json'));
        }
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4.0,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GradientText(
                      _isLoginMode ? l10n.login : l10n.register,
                      gradient: primaryActionGradient,
                      style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      controller: emailController,
                      focusNode: emailFocus,
                      labelKey: 'email',
                      icon: Icons.email,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: passwordController,
                      focusNode: passwordFocus,
                      labelKey: 'password',
                      icon: Icons.lock,
                      isPassword: true,
                    ),
                    if (!_isLoginMode) ...[
                      const SizedBox(height: 16),
                      _buildCityField(),
                      const SizedBox(height: 12),
                      GradientButton(
                        text: l10n.detect_location,
                        gradient: secondaryActionGradient,
                        iconData: Icons.my_location,
                        onPressed: _getCurrentLocation,
                      ),
                    ],
                    const SizedBox(height: 24),
                    GradientButton(
                      text: _isLoginMode ? l10n.login : l10n.register,
                      gradient: primaryActionGradient,
                      iconData: _isLoginMode ? Icons.login : Icons.person_add,
                      onPressed: _isAuthenticating ? () {} : (_isLoginMode ? _signIn : _register),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                      child: Text(
                        _isLoginMode ? l10n.register_instead : l10n.login_instead,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    
    return Scaffold(
      backgroundColor: Colors.transparent, // <--- ИЗМЕНЕНИЕ
      appBar: AppBar(
        toolbarHeight: 120.0,
        backgroundColor: Colors.transparent, // <--- ИЗМЕНЕНИЕ
        elevation: 0, // <--- ИЗМЕНЕНИЕ
        automaticallyImplyLeading: false,
        flexibleSpace: FlexibleSpaceBar(
          background: Hero(
            tag: 'appLogo',
            child: Image.asset(
              'assets/fuelmaster_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: GradientBackground(child: pageContent), // Для светлой - применяем наш новый фон
    );
  }
}