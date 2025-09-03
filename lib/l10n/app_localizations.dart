import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'FuelMaster'**
  String get app_title;

  /// No description provided for @welcome_message.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fuel Master!'**
  String get welcome_message;

  /// No description provided for @go_to_history.
  ///
  /// In en, this message translates to:
  /// **'Go to History'**
  String get go_to_history;

  /// No description provided for @history_title.
  ///
  /// In en, this message translates to:
  /// **'Calculation History'**
  String get history_title;

  /// No description provided for @select_car.
  ///
  /// In en, this message translates to:
  /// **'Select a car'**
  String get select_car;

  /// No description provided for @all_cars.
  ///
  /// In en, this message translates to:
  /// **'All Cars'**
  String get all_cars;

  /// No description provided for @fuel_usage_chart.
  ///
  /// In en, this message translates to:
  /// **'Fuel Usage Chart'**
  String get fuel_usage_chart;

  /// No description provided for @no_chart_data.
  ///
  /// In en, this message translates to:
  /// **'No Chart Data'**
  String get no_chart_data;

  /// No description provided for @history_calculations.
  ///
  /// In en, this message translates to:
  /// **'History Calculations'**
  String get history_calculations;

  /// No description provided for @history_empty.
  ///
  /// In en, this message translates to:
  /// **'History is Empty'**
  String get history_empty;

  /// No description provided for @no_history_for_car.
  ///
  /// In en, this message translates to:
  /// **'No Records for Selected Car'**
  String get no_history_for_car;

  /// No description provided for @export_record.
  ///
  /// In en, this message translates to:
  /// **'Export Record'**
  String get export_record;

  /// No description provided for @export_email.
  ///
  /// In en, this message translates to:
  /// **'Export via Email'**
  String get export_email;

  /// No description provided for @export_telegram.
  ///
  /// In en, this message translates to:
  /// **'Export via Telegram'**
  String get export_telegram;

  /// No description provided for @export_whatsapp.
  ///
  /// In en, this message translates to:
  /// **'Export via WhatsApp'**
  String get export_whatsapp;

  /// No description provided for @clear_history.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clear_history;

  /// No description provided for @clear_history_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear the calculation history?'**
  String get clear_history_confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @history_cleared.
  ///
  /// In en, this message translates to:
  /// **'History Cleared'**
  String get history_cleared;

  /// No description provided for @history_empty_export.
  ///
  /// In en, this message translates to:
  /// **'History is Empty'**
  String get history_empty_export;

  /// No description provided for @fuel_history_message.
  ///
  /// In en, this message translates to:
  /// **'Fuel Calculation History'**
  String get fuel_history_message;

  /// No description provided for @email_subject.
  ///
  /// In en, this message translates to:
  /// **'Fuel History'**
  String get email_subject;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// No description provided for @error_email.
  ///
  /// In en, this message translates to:
  /// **'Unable to open email client'**
  String get error_email;

  /// No description provided for @error_telegram.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Telegram'**
  String get error_telegram;

  /// No description provided for @error_whatsapp.
  ///
  /// In en, this message translates to:
  /// **'Unable to open WhatsApp'**
  String get error_whatsapp;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @share_history.
  ///
  /// In en, this message translates to:
  /// **'Share History'**
  String get share_history;

  /// No description provided for @select_share_method.
  ///
  /// In en, this message translates to:
  /// **'Select a method to share the history'**
  String get select_share_method;

  /// No description provided for @invalid_input.
  ///
  /// In en, this message translates to:
  /// **'Invalid input format'**
  String get invalid_input;

  /// No description provided for @out_of_range.
  ///
  /// In en, this message translates to:
  /// **'Values out of range'**
  String get out_of_range;

  /// No description provided for @final_mileage_greater.
  ///
  /// In en, this message translates to:
  /// **'Final mileage must be greater than initial'**
  String get final_mileage_greater;

  /// No description provided for @highway_not_exceed_total.
  ///
  /// In en, this message translates to:
  /// **'Highway mileage cannot exceed total mileage'**
  String get highway_not_exceed_total;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @initial_mileage.
  ///
  /// In en, this message translates to:
  /// **'Initial Mileage'**
  String get initial_mileage;

  /// No description provided for @final_mileage.
  ///
  /// In en, this message translates to:
  /// **'Final Mileage'**
  String get final_mileage;

  /// No description provided for @total_mileage.
  ///
  /// In en, this message translates to:
  /// **'Total Mileage'**
  String get total_mileage;

  /// Label for city mileage in fuel calculation history
  ///
  /// In en, this message translates to:
  /// **'City Mileage'**
  String get city_mileage;

  /// No description provided for @city_norm.
  ///
  /// In en, this message translates to:
  /// **'City Norm'**
  String get city_norm;

  /// Label for highway mileage in fuel calculation history
  ///
  /// In en, this message translates to:
  /// **'Highway Mileage'**
  String get highway_mileage;

  /// No description provided for @highway_norm.
  ///
  /// In en, this message translates to:
  /// **'Highway Norm'**
  String get highway_norm;

  /// No description provided for @refuel.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get refuel;

  /// No description provided for @fuel_used.
  ///
  /// In en, this message translates to:
  /// **'Fuel Used'**
  String get fuel_used;

  /// No description provided for @final_fuel.
  ///
  /// In en, this message translates to:
  /// **'Final Fuel'**
  String get final_fuel;

  /// No description provided for @liters.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get liters;

  /// No description provided for @kilometers.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kilometers;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Calculation completed'**
  String get success;

  /// No description provided for @current_calculations.
  ///
  /// In en, this message translates to:
  /// **'Current Calculations'**
  String get current_calculations;

  /// Message displayed when there are no calculations to show
  ///
  /// In en, this message translates to:
  /// **'No calculations available'**
  String get no_calculations;

  /// Message shown when a calculation record is successfully deleted
  ///
  /// In en, this message translates to:
  /// **'Record deleted successfully'**
  String get record_deleted;

  /// Text for the OK button in dialogs
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @logo_not_found.
  ///
  /// In en, this message translates to:
  /// **'Logo not found'**
  String get logo_not_found;

  /// No description provided for @initial_mileage_short.
  ///
  /// In en, this message translates to:
  /// **'Init. km'**
  String get initial_mileage_short;

  /// No description provided for @final_mileage_short.
  ///
  /// In en, this message translates to:
  /// **'Final km'**
  String get final_mileage_short;

  /// No description provided for @initial_fuel_short.
  ///
  /// In en, this message translates to:
  /// **'Init. Fuel'**
  String get initial_fuel_short;

  /// No description provided for @refuel_short.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get refuel_short;

  /// No description provided for @highway_distance_short.
  ///
  /// In en, this message translates to:
  /// **'Highway km'**
  String get highway_distance_short;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Label for automatic theme selection
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @theme_changed.
  ///
  /// In en, this message translates to:
  /// **'Theme changed to %s'**
  String get theme_changed;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @language_changed.
  ///
  /// In en, this message translates to:
  /// **'Language changed to %s'**
  String get language_changed;

  /// No description provided for @step1.
  ///
  /// In en, this message translates to:
  /// **'Enter car details (brand, model, fuel norms).'**
  String get step1;

  /// No description provided for @step2.
  ///
  /// In en, this message translates to:
  /// **'Calculate fuel consumption by entering mileage and refueling data.'**
  String get step2;

  /// No description provided for @step3.
  ///
  /// In en, this message translates to:
  /// **'View history and export data.'**
  String get step3;

  /// No description provided for @step1_title.
  ///
  /// In en, this message translates to:
  /// **'Add Your Car'**
  String get step1_title;

  /// No description provided for @step1_description.
  ///
  /// In en, this message translates to:
  /// **'Add your car\'s details, including make, model, and fuel consumption rates.'**
  String get step1_description;

  /// No description provided for @step2_title.
  ///
  /// In en, this message translates to:
  /// **'Calculate Fuel Consumption'**
  String get step2_title;

  /// No description provided for @step2_description.
  ///
  /// In en, this message translates to:
  /// **'Use the calculator to track your fuel usage based on mileage and refueling.'**
  String get step2_description;

  /// No description provided for @step3_title.
  ///
  /// In en, this message translates to:
  /// **'Track Your History'**
  String get step3_title;

  /// No description provided for @step3_description.
  ///
  /// In en, this message translates to:
  /// **'View your fuel consumption history, export data, and get insights.'**
  String get step3_description;

  /// No description provided for @start_app.
  ///
  /// In en, this message translates to:
  /// **'Start Using'**
  String get start_app;

  /// No description provided for @enter_car_details.
  ///
  /// In en, this message translates to:
  /// **'Enter Car Details'**
  String get enter_car_details;

  /// No description provided for @save_and_continue.
  ///
  /// In en, this message translates to:
  /// **'Save and Continue'**
  String get save_and_continue;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous_cars.
  ///
  /// In en, this message translates to:
  /// **'Previously Added Cars'**
  String get previous_cars;

  /// No description provided for @no_cars.
  ///
  /// In en, this message translates to:
  /// **'No cars added'**
  String get no_cars;

  /// No description provided for @delete_car.
  ///
  /// In en, this message translates to:
  /// **'Delete Car'**
  String get delete_car;

  /// No description provided for @delete_car_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this car?'**
  String get delete_car_confirm;

  /// No description provided for @fill_all_fields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get fill_all_fields;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @liters_per_100km.
  ///
  /// In en, this message translates to:
  /// **'L/100km'**
  String get liters_per_100km;

  /// No description provided for @calculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calculate;

  /// No description provided for @save_and_back.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_and_back;

  /// No description provided for @continue_calculations.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_calculations;

  /// No description provided for @your_cars.
  ///
  /// In en, this message translates to:
  /// **'Your Cars'**
  String get your_cars;

  /// Message shown when a car is successfully saved
  ///
  /// In en, this message translates to:
  /// **'Car saved successfully'**
  String get car_saved;

  /// Button text for creating a new car
  ///
  /// In en, this message translates to:
  /// **'Create New Car'**
  String get create_new_car;

  /// Button text for navigating to car configuration
  ///
  /// In en, this message translates to:
  /// **'Configure Your Cars'**
  String get configure_cars;

  /// Button text for selecting a date range
  ///
  /// In en, this message translates to:
  /// **'Select Period'**
  String get select_period;

  /// Button text for resetting the selected date range
  ///
  /// In en, this message translates to:
  /// **'Reset Period'**
  String get reset_period;

  /// Button text for sharing the entire calculation history
  ///
  /// In en, this message translates to:
  /// **'Share All History'**
  String get share_all_history;

  /// No description provided for @go_to_calculator.
  ///
  /// In en, this message translates to:
  /// **'Go to Calculator'**
  String get go_to_calculator;

  /// No description provided for @calculation_complete.
  ///
  /// In en, this message translates to:
  /// **'Calculation Complete'**
  String get calculation_complete;

  /// No description provided for @calculation_options.
  ///
  /// In en, this message translates to:
  /// **'To continue, you can save the current calculation and return to the main menu or continue calculations in this window.'**
  String get calculation_options;

  /// Message shown when a duplicate model is detected
  ///
  /// In en, this message translates to:
  /// **'This model is already in use!'**
  String get duplicate_model;

  /// Message shown when the fuel norm input is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid fuel norm format!'**
  String get invalid_norm;

  /// Message shown when the fuel norm is not positive
  ///
  /// In en, this message translates to:
  /// **'Fuel norm must be positive!'**
  String get positive_norm;

  /// Text displayed on the splash screen while the app is loading
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @ad_not_available.
  ///
  /// In en, this message translates to:
  /// **'Advertisement not available'**
  String get ad_not_available;

  /// Label for date range period in history page
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @ad_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load ad, please try again later'**
  String get ad_load_failed;

  /// No description provided for @ad_show_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to show ad, please try again'**
  String get ad_show_failed;

  /// No description provided for @continue_calculation.
  ///
  /// In en, this message translates to:
  /// **'Continue Calculation'**
  String get continue_calculation;

  /// Prompt for choosing between new or continued calculation
  ///
  /// In en, this message translates to:
  /// **'Do you want to start a new calculation or continue the current one?'**
  String get choose_calculation_option;

  /// Button text for starting a new calculation
  ///
  /// In en, this message translates to:
  /// **'Start New Calculation'**
  String get start_new_calculation;

  /// Button text for continuing the current calculation
  ///
  /// In en, this message translates to:
  /// **'Continue Current Calculation'**
  String get continue_current_calculation;

  /// Message shown when a new calculation is started
  ///
  /// In en, this message translates to:
  /// **'New calculation started'**
  String get new_calculation_started;

  /// Message shown when continuing the current calculation
  ///
  /// In en, this message translates to:
  /// **'Continued current calculation'**
  String get continued_calculation;

  /// Message shown when there are no previous calculations to continue
  ///
  /// In en, this message translates to:
  /// **'No previous calculations available'**
  String get no_previous_calculation;

  /// Message shown when the final fuel from the previous calculation is negative
  ///
  /// In en, this message translates to:
  /// **'Previous final fuel is negative, please start a new calculation'**
  String get negative_final_fuel;

  /// Prompt shown when exiting FuelCalculatorPage with unsaved calculations
  ///
  /// In en, this message translates to:
  /// **'You have unsaved calculations. Save before exiting?'**
  String get confirm_save_before_exit;

  /// Label for car generation
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get generation;

  /// Label for car modification
  ///
  /// In en, this message translates to:
  /// **'Modification'**
  String get modification;

  /// Label for car's start production year
  ///
  /// In en, this message translates to:
  /// **'Year From'**
  String get year_from;

  /// Label for car's end production year
  ///
  /// In en, this message translates to:
  /// **'Year To'**
  String get year_to;

  /// Label for car's engine volume
  ///
  /// In en, this message translates to:
  /// **'Engine Volume'**
  String get engine_volume;

  /// Label for car's horsepower
  ///
  /// In en, this message translates to:
  /// **'Power (HP)'**
  String get power_hp;

  /// Label for car's fuel type
  ///
  /// In en, this message translates to:
  /// **'Fuel Type'**
  String get fuel_type;

  /// Label for petrol fuel type
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get petrol;

  /// Label for diesel fuel type
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get diesel;

  /// Label for LPG fuel type
  ///
  /// In en, this message translates to:
  /// **'LPG'**
  String get lpg;

  /// Label for CNG fuel type
  ///
  /// In en, this message translates to:
  /// **'CNG'**
  String get cng;

  /// Label for car's transmission type
  ///
  /// In en, this message translates to:
  /// **'Transmission Type'**
  String get transmission_type;

  /// Label for number of transmission speeds
  ///
  /// In en, this message translates to:
  /// **'Transmission Speeds'**
  String get transmission_speeds;

  /// Label for combined fuel consumption
  ///
  /// In en, this message translates to:
  /// **'Combined Fuel Consumption'**
  String get combined_norm;

  /// Label for base city fuel consumption norm
  ///
  /// In en, this message translates to:
  /// **'Base City Norm'**
  String get base_city_norm;

  /// Label for base highway fuel consumption norm
  ///
  /// In en, this message translates to:
  /// **'Base Highway Norm'**
  String get base_highway_norm;

  /// Label for base combined fuel consumption norm
  ///
  /// In en, this message translates to:
  /// **'Base Combined Norm'**
  String get base_combined_norm;

  /// Label for city input in fuel calculation
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Label for weather multiplier in fuel calculation
  ///
  /// In en, this message translates to:
  /// **'Weather Multiplier'**
  String get weather_multiplier;

  /// Message shown when engine volume is out of valid range
  ///
  /// In en, this message translates to:
  /// **'Engine volume must be between 0.5 and 10 liters'**
  String get invalid_engine_volume;

  /// Label for premium subscription option
  ///
  /// In en, this message translates to:
  /// **'Premium Subscription'**
  String get premium_subscription;

  /// Button text for purchasing premium subscription
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// Message shown when premium subscription is active
  ///
  /// In en, this message translates to:
  /// **'Premium Active'**
  String get premium_active;

  /// Message shown when in-app purchase store is unavailable
  ///
  /// In en, this message translates to:
  /// **'Store is unavailable'**
  String get store_unavailable;

  /// Message shown when premium product is not found
  ///
  /// In en, this message translates to:
  /// **'Premium product not found'**
  String get product_not_found;

  /// Message shown when premium purchase is in progress
  ///
  /// In en, this message translates to:
  /// **'Purchase in progress'**
  String get premium_purchase_in_progress;

  /// Message shown when premium subscription is successfully activated
  ///
  /// In en, this message translates to:
  /// **'Premium activated'**
  String get premium_activated;

  /// Message shown when premium purchase fails
  ///
  /// In en, this message translates to:
  /// **'Purchase error'**
  String get purchase_error;

  /// Message shown when weather data cannot be retrieved
  ///
  /// In en, this message translates to:
  /// **'Weather data unavailable, using default values'**
  String get weather_unavailable;

  /// Message shown when city input is empty
  ///
  /// In en, this message translates to:
  /// **'Enter city'**
  String get enter_city;

  /// Label for registration page and button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Label for email or phone input field
  ///
  /// In en, this message translates to:
  /// **'Email or Phone'**
  String get email_or_phone;

  /// Label for password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Button text for detecting current location
  ///
  /// In en, this message translates to:
  /// **'Detect Location'**
  String get detect_location;

  /// Message shown when location services are disabled
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get location_service_disabled;

  /// Message shown when location permission is denied
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get location_permission_denied;

  /// Message shown when location permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied'**
  String get location_permission_denied_forever;

  /// Message shown when email or phone number format is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid email or phone number format'**
  String get invalid_email_or_phone;

  /// Message shown when Google API key is not configured
  ///
  /// In en, this message translates to:
  /// **'Google API key is missing'**
  String get api_key_missing;

  /// Label for editing a car
  ///
  /// In en, this message translates to:
  /// **'Edit Car'**
  String get edit_car;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @selectVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle type'**
  String get selectVehicleType;

  /// No description provided for @passengerCar.
  ///
  /// In en, this message translates to:
  /// **'Passenger Car'**
  String get passengerCar;

  /// No description provided for @bus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get bus;

  /// No description provided for @truck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get truck;

  /// No description provided for @tractor.
  ///
  /// In en, this message translates to:
  /// **'Tractor'**
  String get tractor;

  /// No description provided for @dumpTruck.
  ///
  /// In en, this message translates to:
  /// **'Dump Truck'**
  String get dumpTruck;

  /// No description provided for @van.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get van;

  /// No description provided for @vanWithoutCargo.
  ///
  /// In en, this message translates to:
  /// **'Van without cargo (add 10% to norm)'**
  String get vanWithoutCargo;

  /// No description provided for @trailerMass.
  ///
  /// In en, this message translates to:
  /// **'Trailer Mass (tonnes)'**
  String get trailerMass;

  /// No description provided for @payloadCapacity.
  ///
  /// In en, this message translates to:
  /// **'Payload Capacity (tonnes)'**
  String get payloadCapacity;

  /// No description provided for @tripFuelRate.
  ///
  /// In en, this message translates to:
  /// **'Fuel Rate per Trip (liters)'**
  String get tripFuelRate;

  /// No description provided for @heaterRate.
  ///
  /// In en, this message translates to:
  /// **'Heater Fuel Rate (liters/hour)'**
  String get heaterRate;

  /// No description provided for @heaterTime.
  ///
  /// In en, this message translates to:
  /// **'Heater Operation Time (hours)'**
  String get heaterTime;

  /// No description provided for @mileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage (km)'**
  String get mileage;

  /// No description provided for @cargoMass.
  ///
  /// In en, this message translates to:
  /// **'Cargo Mass (tonnes)'**
  String get cargoMass;

  /// No description provided for @cargoMileage.
  ///
  /// In en, this message translates to:
  /// **'Cargo Mileage (km)'**
  String get cargoMileage;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Number of Trips'**
  String get trips;

  /// No description provided for @correctionFactor.
  ///
  /// In en, this message translates to:
  /// **'Correction Factor (%)'**
  String get correctionFactor;

  /// No description provided for @autoCorrectionFactor.
  ///
  /// In en, this message translates to:
  /// **'Use Automatic Correction Factor'**
  String get autoCorrectionFactor;

  /// No description provided for @winterConditions.
  ///
  /// In en, this message translates to:
  /// **'Winter Conditions (+10%)'**
  String get winterConditions;

  /// No description provided for @mountainConditions.
  ///
  /// In en, this message translates to:
  /// **'Mountain Conditions (+15%)'**
  String get mountainConditions;

  /// No description provided for @airConditioner.
  ///
  /// In en, this message translates to:
  /// **'Air Conditioner (+7%)'**
  String get airConditioner;

  /// No description provided for @calculatedFuelConsumption.
  ///
  /// In en, this message translates to:
  /// **'Calculated Fuel Consumption'**
  String get calculatedFuelConsumption;

  /// No description provided for @electric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get electric;

  /// No description provided for @gas_diesel.
  ///
  /// In en, this message translates to:
  /// **'Gas-Diesel'**
  String get gas_diesel;

  /// No description provided for @adjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get adjustments;

  /// No description provided for @history_exported.
  ///
  /// In en, this message translates to:
  /// **'History Exported'**
  String get history_exported;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Message shown when geocoding fails
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch location'**
  String get geocoding_error;

  /// Message shown when the API key is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid API key. Please check your settings.'**
  String get api_key_invalid;

  /// Label for winter condition toggle in fuel calculation
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get winter;

  /// Label for air conditioner toggle in fuel calculation
  ///
  /// In en, this message translates to:
  /// **'Air Conditioner'**
  String get ac;

  /// Label for mountain terrain toggle in fuel calculation
  ///
  /// In en, this message translates to:
  /// **'Mountain Terrain'**
  String get mountain;

  /// No description provided for @vehicle_type.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicle_type;

  /// No description provided for @passenger_car.
  ///
  /// In en, this message translates to:
  /// **'Passenger Car'**
  String get passenger_car;

  /// No description provided for @dump_truck.
  ///
  /// In en, this message translates to:
  /// **'Dump Truck'**
  String get dump_truck;

  /// No description provided for @special_equipment.
  ///
  /// In en, this message translates to:
  /// **'Special Equipment'**
  String get special_equipment;

  /// No description provided for @select_preset_car.
  ///
  /// In en, this message translates to:
  /// **'Select Predefined Car'**
  String get select_preset_car;

  /// No description provided for @custom_input.
  ///
  /// In en, this message translates to:
  /// **'Custom Input'**
  String get custom_input;

  /// No description provided for @license_plate.
  ///
  /// In en, this message translates to:
  /// **'License Plate'**
  String get license_plate;

  /// No description provided for @fill_license_plate.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the license plate'**
  String get fill_license_plate;

  /// No description provided for @duplicate_license_plate.
  ///
  /// In en, this message translates to:
  /// **'License plate already in use'**
  String get duplicate_license_plate;

  /// No description provided for @search_car.
  ///
  /// In en, this message translates to:
  /// **'Search car'**
  String get search_car;

  /// No description provided for @car_deleted.
  ///
  /// In en, this message translates to:
  /// **'Car deleted'**
  String get car_deleted;

  /// Label for selecting a car brand from a dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Brand'**
  String get select_brand;

  /// Label for selecting a car model from a dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get select_model;

  /// Label for selecting a car generation from a dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Generation'**
  String get select_generation;

  /// No description provided for @no_data_found.
  ///
  /// In en, this message translates to:
  /// **'No data found'**
  String get no_data_found;

  /// No description provided for @no_cars_available.
  ///
  /// In en, this message translates to:
  /// **'No cars available'**
  String get no_cars_available;

  /// Button text for requesting AI fuel efficiency advice
  ///
  /// In en, this message translates to:
  /// **'AI Fuel Efficiency Advice'**
  String get fuel_advice_button;

  /// Title for the dialog showing AI fuel efficiency advice
  ///
  /// In en, this message translates to:
  /// **'Fuel Efficiency Tips'**
  String get fuel_advice_title;

  /// Message shown when a premium feature is accessed by a non-premium user
  ///
  /// In en, this message translates to:
  /// **'This feature is available only for premium users'**
  String get premium_feature;

  /// Button text for sharing content, such as AI fuel efficiency advice
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Message shown when DeepSeek API returns a 402 error due to insufficient balance
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance for AI advice. Please top up your account.'**
  String get insufficient_balance;

  /// No description provided for @error_sharing.
  ///
  /// In en, this message translates to:
  /// **'Error while trying to share advice'**
  String get error_sharing;

  /// No description provided for @no_advice_to_share.
  ///
  /// In en, this message translates to:
  /// **'No advice available to share'**
  String get no_advice_to_share;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Label for heater operating time input in fuel calculation for buses
  ///
  /// In en, this message translates to:
  /// **'Heater Operating Time (h)'**
  String get heater_operating_time;

  /// Message shown when correction factor is out of valid range
  ///
  /// In en, this message translates to:
  /// **'Correction factor must be between -50 and 50%'**
  String get invalid_correction_factor;

  /// Message shown when heater operating time is negative
  ///
  /// In en, this message translates to:
  /// **'Heater operating time must be non-negative'**
  String get invalid_heater_time;

  /// Label for heater fuel consumption
  ///
  /// In en, this message translates to:
  /// **'Heater Fuel Consumption'**
  String get heater_fuel_consumption;

  /// Label for passenger capacity
  ///
  /// In en, this message translates to:
  /// **'Passenger Capacity'**
  String get passenger_capacity;

  /// No description provided for @sync_success.
  ///
  /// In en, this message translates to:
  /// **'Data synced successfully'**
  String get sync_success;

  /// No description provided for @sync_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync data. Please try again.'**
  String get sync_error;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalid_email;

  /// No description provided for @weak_password.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get weak_password;

  /// No description provided for @registration_success.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registration_success;

  /// No description provided for @email_already_in_use.
  ///
  /// In en, this message translates to:
  /// **'Email already in use'**
  String get email_already_in_use;

  /// No description provided for @login_success.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get login_success;

  /// No description provided for @invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalid_credentials;

  /// No description provided for @register_instead.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get register_instead;

  /// No description provided for @login_instead.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log In'**
  String get login_instead;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// No description provided for @sign_out_success.
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully'**
  String get sign_out_success;

  /// No description provided for @loading_car_database.
  ///
  /// In en, this message translates to:
  /// **'Loading car database...'**
  String get loading_car_database;

  /// No description provided for @duplicate_record.
  ///
  /// In en, this message translates to:
  /// **'Calculation has already been saved.'**
  String get duplicate_record;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @unsaved_changes.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsaved_changes;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @history_label_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get history_label_date;

  /// No description provided for @history_label_brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get history_label_brand;

  /// No description provided for @history_label_license_plate.
  ///
  /// In en, this message translates to:
  /// **'License Plate'**
  String get history_label_license_plate;

  /// No description provided for @history_label_initial_mileage.
  ///
  /// In en, this message translates to:
  /// **'Initial Mileage'**
  String get history_label_initial_mileage;

  /// No description provided for @history_label_final_mileage.
  ///
  /// In en, this message translates to:
  /// **'Final Mileage'**
  String get history_label_final_mileage;

  /// No description provided for @history_label_total_mileage.
  ///
  /// In en, this message translates to:
  /// **'Total Mileage'**
  String get history_label_total_mileage;

  /// No description provided for @history_label_city_mileage.
  ///
  /// In en, this message translates to:
  /// **'City Mileage'**
  String get history_label_city_mileage;

  /// No description provided for @history_label_highway_mileage.
  ///
  /// In en, this message translates to:
  /// **'Highway Mileage'**
  String get history_label_highway_mileage;

  /// No description provided for @history_label_city_norm.
  ///
  /// In en, this message translates to:
  /// **'City Norm'**
  String get history_label_city_norm;

  /// No description provided for @history_label_highway_norm.
  ///
  /// In en, this message translates to:
  /// **'Highway Norm'**
  String get history_label_highway_norm;

  /// No description provided for @history_label_initial_fuel.
  ///
  /// In en, this message translates to:
  /// **'Initial Fuel'**
  String get history_label_initial_fuel;

  /// No description provided for @history_label_refuel.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get history_label_refuel;

  /// No description provided for @history_label_fuel_used.
  ///
  /// In en, this message translates to:
  /// **'Fuel Used'**
  String get history_label_fuel_used;

  /// No description provided for @history_label_final_fuel.
  ///
  /// In en, this message translates to:
  /// **'Final Fuel'**
  String get history_label_final_fuel;

  /// No description provided for @condition_winter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get condition_winter;

  /// No description provided for @condition_ac.
  ///
  /// In en, this message translates to:
  /// **'A/C'**
  String get condition_ac;

  /// No description provided for @condition_mountain.
  ///
  /// In en, this message translates to:
  /// **'Mountain'**
  String get condition_mountain;

  /// No description provided for @confirm_delete_record_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirm_delete_record_title;

  /// No description provided for @confirm_delete_record_content.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record?'**
  String get confirm_delete_record_content;

  /// No description provided for @no_modification.
  ///
  /// In en, this message translates to:
  /// **'No modification'**
  String get no_modification;

  /// No description provided for @correction_factor_tooltip.
  ///
  /// In en, this message translates to:
  /// **'This factor adjusts the fuel consumption rate.\n\nAutomatic Mode:\nWhen this option is enabled, the factor is calculated automatically based on current weather data (temperature, wind, precipitation). This allows for an accurate accounting of weather\'s impact on fuel consumption.\n\nManual Mode:\nThe factor is entered manually as a percentage (%) and can be positive (increases consumption) or negative (decreases it). Use it to account for unique conditions not related to weather. For example: poor road conditions, frequent traffic jams, aggressive driving style, or the vehicle\'s technical condition.'**
  String get correction_factor_tooltip;

  /// No description provided for @heater_operating_time_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter the total operating time of the autonomous cabin heater in hours. The fuel consumed by the heater is calculated separately and added to the main fuel consumption from driving. The consumption rate for the heater is set in the vehicle\'s settings.'**
  String get heater_operating_time_tooltip;

  /// No description provided for @auto_factor_error.
  ///
  /// In en, this message translates to:
  /// **'Failed to get weather data. Manual input is enabled.'**
  String get auto_factor_error;

  /// No description provided for @onboarding_title.
  ///
  /// In en, this message translates to:
  /// **'Your Personal Fuel Assistant'**
  String get onboarding_title;

  /// No description provided for @onboarding_step1_title.
  ///
  /// In en, this message translates to:
  /// **'Smart Car Management'**
  String get onboarding_step1_title;

  /// No description provided for @onboarding_step1_desc.
  ///
  /// In en, this message translates to:
  /// **'Add your vehicles manually or choose from an extensive database with auto-filled consumption rates. All your cars in one convenient list.'**
  String get onboarding_step1_desc;

  /// No description provided for @onboarding_step2_title.
  ///
  /// In en, this message translates to:
  /// **'Accurate Calculations'**
  String get onboarding_step2_title;

  /// No description provided for @onboarding_step2_desc.
  ///
  /// In en, this message translates to:
  /// **'Use the calculator for precise fuel consumption tracking, considering winter conditions, AC usage, and mountain trips. Heater operation is available for buses.'**
  String get onboarding_step2_desc;

  /// No description provided for @onboarding_step3_title.
  ///
  /// In en, this message translates to:
  /// **'Analysis & Export'**
  String get onboarding_step3_title;

  /// No description provided for @onboarding_step3_desc.
  ///
  /// In en, this message translates to:
  /// **'Monitor your statistics with clear charts, view detailed calculation history, and share your data in a convenient format.'**
  String get onboarding_step3_desc;

  /// No description provided for @onboarding_button.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboarding_button;

  /// No description provided for @car_form_step1_title.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Identification'**
  String get car_form_step1_title;

  /// No description provided for @car_form_step2_title.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Model Selection (Autocomplete)'**
  String get car_form_step2_title;

  /// No description provided for @car_form_step3_title.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Consumption Rates & Details'**
  String get car_form_step3_title;

  /// No description provided for @selected_car.
  ///
  /// In en, this message translates to:
  /// **'Selected car'**
  String get selected_car;

  /// No description provided for @fill_license_plate_fully.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the license plate completely'**
  String get fill_license_plate_fully;

  /// Label for correction factor input in fuel calculation for buses
  ///
  /// In en, this message translates to:
  /// **'Correction Factor (%)'**
  String get correction_factor;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
