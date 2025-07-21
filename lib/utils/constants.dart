class AppConstants {
  // API Keys
  static const String newsApiKey = "15c9a329f0244174907ceb45d6e00d32";
  
  // Development mode flag
  static const bool isDevelopmentMode = false;
  
  // Shared Preferences Keys
  static const String prefThemeMode = "theme_mode";
  static const String prefAutoSos = "auto_sos";
  static const String prefCountry = "news_country";
  static const String prefMood = "user_mood";
  
  // BLE Service UUIDs
  static const String heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateMeasurementCharUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  static const String pulseOximeterServiceUuid = "00001822-0000-1000-8000-00805f9b34fb";
  static const String spo2MeasurementCharUuid = "00002a5f-0000-1000-8000-00805f9b34fb";
  
  // Emergency SOS
  static const int sosMonitoringIntervalMs = 1000; // Check vitals every second
  static const int sosAbnormalDurationMs = 30000; // 30 seconds of abnormal vitals before alert
  static const int hrThresholdHigh = 180; // BPM
  static const int spo2ThresholdLow = 85; // Percent
  
  // Default emergency numbers by country code
  static const Map<String, String> emergencyNumbers = {
    "US": "911",
    "CA": "911",
    "GB": "999",
    "AU": "000",
    "EU": "112",
    "IN": "112"
  };
  static const String defaultEmergencyNumber = "112";
  
  // Routes
  static const String routeLogin = "/login";
  static const String routeDashboard = "/dashboard";
  static const String routeSymptom = "/symptom";
  static const String routeChat = "/chat";
  static const String routeDrug = "/drug";
  static const String routeHospital = "/hospital";
  static const String routePharmacy = "/pharmacy";
  static const String routeProfessionalsPharmacy = "/professionals-pharmacy";
  static const String routeWearable = "/wearable";
  static const String routeReminder = "/reminder";
  static const String routeTimeline = "/timeline";
  static const String routeSos = "/sos";
  static const String routeProfile = "/profile";
  static const String routeSymptomAI = "/symptom_ai";
  static const String routeNewsDetail = "/news_detail";
  static const String routeBloodDonation = "/blood-donation";

  // Telegram SOS
  // TODO: Replace with your actual bot token and chat ID
  static const String telegramBotToken = "8031117907:AAHJ3rN334Fhjf4QtYBCDIJOgpNO8A3F89g";
  static const String telegramChatId = "-1002835748169"; // aidx super-group

  // Extra chat IDs (e.g., private DMs) that should also receive SOS
  static const List<String> extraTelegramChatIds = [
    "7921789120", // Alvee personal DM
  ];
} 