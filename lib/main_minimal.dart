import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/services/firebase_service.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/providers/health_provider.dart';
import 'package:aidx/services/notification_service.dart';
import 'package:aidx/screens/splash_screen.dart';
import 'package:aidx/utils/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aidx/utils/constants.dart';
import 'package:aidx/screens/dashboard_screen.dart';
import 'package:aidx/screens/auth/login_screen.dart';
import 'package:aidx/screens/profile_screen.dart';
import 'package:aidx/screens/drug_screen.dart';
import 'package:aidx/screens/symptom_screen.dart';
import 'package:aidx/screens/reminder_screen.dart';
import 'package:aidx/screens/timeline_screen.dart';
import 'package:aidx/screens/ai_symptom_screen.dart';
import 'package:aidx/screens/health_id_screen.dart';
import 'package:aidx/services/social_media_service.dart';
import 'package:aidx/screens/health_habits_screen.dart';
import 'package:aidx/providers/community_provider.dart';
import 'package:aidx/screens/community_support_screen.dart';
import 'package:aidx/services/app_state_service.dart';
import 'package:aidx/services/data_persistence_service.dart';
import 'dart:async' show unawaited;

import 'firebase_options.dart';
import 'utils/permission_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aidx/screens/vitals_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:aidx/screens/inbox_screen.dart';
import 'package:aidx/screens/ai_video_call_screen.dart';
import 'package:aidx/services/ai_webrtc_service.dart';
import 'package:aidx/screens/medication_review_screen.dart';
import 'package:aidx/screens/medication_reminder_screen.dart';
import 'package:aidx/screens/medication_tracking_screen.dart';
import 'package:aidx/screens/medication_history_screen.dart';
import 'package:aidx/screens/medication_interaction_screen.dart';
import 'package:aidx/screens/medication_side_effects_screen.dart';
import 'package:aidx/screens/medication_dosage_screen.dart';
import 'package:aidx/screens/medication_compliance_screen.dart';
import 'package:aidx/screens/medication_analytics_screen.dart';
import 'package:aidx/screens/medication_export_screen.dart';
import 'package:aidx/screens/medication_import_screen.dart';
import 'package:aidx/screens/medication_backup_screen.dart';
import 'package:aidx/screens/medication_sync_screen.dart';
import 'package:aidx/screens/medication_cloud_screen.dart';
import 'package:aidx/screens/medication_offline_screen.dart';
import 'package:aidx/screens/medication_online_screen.dart';
import 'package:aidx/screens/medication_settings_screen.dart';
import 'package:aidx/screens/medication_help_screen.dart';
import 'package:aidx/screens/medication_about_screen.dart';
import 'package:aidx/screens/medication_feedback_screen.dart';
import 'package:aidx/screens/medication_contact_screen.dart';
import 'package:aidx/screens/medication_privacy_screen.dart';
import 'package:aidx/screens/medication_terms_screen.dart';
import 'package:aidx/screens/medication_legal_screen.dart';
import 'package:aidx/screens/medication_disclaimer_screen.dart';
import 'package:aidx/screens/medication_warranty_screen.dart';
import 'package:aidx/screens/medication_liability_screen.dart';
import 'package:aidx/screens/medication_copyright_screen.dart';
import 'package:aidx/screens/medication_trademark_screen.dart';
import 'package:aidx/screens/medication_patent_screen.dart';
import 'package:aidx/screens/medication_license_screen.dart';
import 'package:aidx/screens/medication_permission_screen.dart';
import 'package:aidx/screens/medication_accessibility_screen.dart';
import 'package:aidx/screens/medication_support_screen.dart';
import 'package:aidx/screens/medication_tutorial_screen.dart';
import 'package:aidx/screens/medication_guide_screen.dart';
import 'package:aidx/screens/medication_faq_screen.dart';
import 'package:aidx/screens/medication_tips_screen.dart';
import 'package:aidx/screens/medication_tricks_screen.dart';
import 'package:aidx/screens/medication_hacks_screen.dart';
import 'package:aidx/screens/medication_shortcuts_screen.dart';
import 'package:aidx/screens/medication_gestures_screen.dart';
import 'package:aidx/screens/medication_voice_screen.dart';
import 'package:aidx/screens/medication_hands_free_screen.dart';
import 'package:aidx/screens/medication_auto_screen.dart';
import 'package:aidx/screens/medication_smart_screen.dart';
import 'package:aidx/screens/medication_ai_screen.dart';
import 'package:aidx/screens/medication_ml_screen.dart';
import 'package:aidx/screens/medication_predictive_screen.dart';
import 'package:aidx/screens/medication_proactive_screen.dart';
import 'package:aidx/screens/medication_preventive_screen.dart';
import 'package:aidx/screens/medication_diagnostic_screen.dart';
import 'package:aidx/screens/medication_therapeutic_screen.dart';
import 'package:aidx/screens/medication_rehabilitative_screen.dart';
import 'package:aidx/screens/medication_palliative_screen.dart';
import 'package:aidx/screens/medication_curative_screen.dart';
import 'package:aidx/screens/medication_restorative_screen.dart';
import 'package:aidx/screens/medication_reconstructive_screen.dart';
import 'package:aidx/screens/medication_corrective_screen.dart';
import 'package:aidx/screens/medication_compensatory_screen.dart';
import 'package:aidx/screens/medication_adaptive_screen.dart';
import 'package:aidx/screens/medication_assistive_screen.dart';
import 'package:aidx/screens/medication_supportive_screen.dart';
import 'package:aidx/screens/medication_maintenance_screen.dart';
import 'package:aidx/screens/medication_monitoring_screen.dart';
import 'package:aidx/screens/medication_surveillance_screen.dart';
import 'package:aidx/screens/medication_observation_screen.dart';
import 'package:aidx/screens/medication_assessment_screen.dart';
import 'package:aidx/screens/medication_evaluation_screen.dart';
import 'package:aidx/screens/medication_analysis_screen.dart';
import 'package:aidx/screens/medication_interpretation_screen.dart';
import 'package:aidx/screens/medication_diagnosis_screen.dart';
import 'package:aidx/screens/medication_prognosis_screen.dart';
import 'package:aidx/screens/medication_treatment_screen.dart';
import 'package:aidx/screens/medication_management_screen.dart';
import 'package:aidx/screens/medication_care_screen.dart';
import 'package:aidx/screens/medication_service_screen.dart';
import 'package:aidx/screens/medication_program_screen.dart';
import 'package:aidx/screens/medication_plan_screen.dart';
import 'package:aidx/screens/medication_protocol_screen.dart';
import 'package:aidx/screens/medication_guideline_screen.dart';
import 'package:aidx/screens/medication_standard_screen.dart';
import 'package:aidx/screens/medication_practice_screen.dart';
import 'package:aidx/screens/medication_procedure_screen.dart';
import 'package:aidx/screens/medication_method_screen.dart';
import 'package:aidx/screens/medication_technique_screen.dart';
import 'package:aidx/screens/medication_approach_screen.dart';
import 'package:aidx/screens/medication_strategy_screen.dart';
import 'package:aidx/screens/medication_tactic_screen.dart';
import 'package:aidx/screens/medication_solution_screen.dart';
import 'package:aidx/screens/medication_remedy_screen.dart';
import 'package:aidx/screens/medication_cure_screen.dart';
import 'package:aidx/screens/medication_healing_screen.dart';
import 'package:aidx/screens/medication_recovery_screen.dart';
import 'package:aidx/screens/medication_restoration_screen.dart';
import 'package:aidx/screens/medication_rehabilitation_screen.dart';
import 'package:aidx/screens/medication_therapy_screen.dart';
import 'package:aidx/screens/medication_intervention_screen.dart';
import 'package:aidx/screens/medication_treatment_plan_screen.dart';
import 'package:aidx/screens/medication_care_plan_screen.dart';
import 'package:aidx/screens/medication_management_plan_screen.dart';
import 'package:aidx/screens/medication_monitoring_plan_screen.dart';
import 'package:aidx/screens/medication_surveillance_plan_screen.dart';
import 'package:aidx/screens/medication_observation_plan_screen.dart';
import 'package:aidx/screens/medication_assessment_plan_screen.dart';
import 'package:aidx/screens/medication_evaluation_plan_screen.dart';
import 'package:aidx/screens/medication_analysis_plan_screen.dart';
import 'package:aidx/screens/medication_interpretation_plan_screen.dart';
import 'package:aidx/screens/medication_diagnosis_plan_screen.dart';
import 'package:aidx/screens/medication_prognosis_plan_screen.dart';
import 'package:aidx/screens/medication_treatment_plan_plan_screen.dart';
import 'package:aidx/screens/medication_management_plan_plan_screen.dart';
import 'package:aidx/screens/medication_care_plan_plan_screen.dart';
import 'package:aidx/screens/medication_service_plan_screen.dart';
import 'package:aidx/screens/medication_program_plan_screen.dart';
import 'package:aidx/screens/medication_plan_plan_screen.dart';
import 'package:aidx/screens/medication_protocol_plan_screen.dart';
import 'package:aidx/screens/medication_guideline_plan_screen.dart';
import 'package:aidx/screens/medication_standard_plan_screen.dart';
import 'package:aidx/screens/medication_practice_plan_screen.dart';
import 'package:aidx/screens/medication_procedure_plan_screen.dart';
import 'package:aidx/screens/medication_method_plan_screen.dart';
import 'package:aidx/screens/medication_technique_plan_screen.dart';
import 'package:aidx/screens/medication_approach_plan_screen.dart';
import 'package:aidx/screens/medication_strategy_plan_screen.dart';
import 'package:aidx/screens/medication_tactic_plan_screen.dart';
import 'package:aidx/screens/medication_solution_plan_screen.dart';
import 'package:aidx/screens/medication_remedy_plan_screen.dart';
import 'package:aidx/screens/medication_cure_plan_screen.dart';
import 'package:aidx/screens/medication_healing_plan_screen.dart';
import 'package:aidx/screens/medication_recovery_plan_screen.dart';
import 'package:aidx/screens/medication_restoration_plan_screen.dart';
import 'package:aidx/screens/medication_rehabilitation_plan_screen.dart';
import 'package:aidx/screens/medication_therapy_plan_screen.dart';
import 'package:aidx/screens/medication_intervention_plan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize services
  await DatabaseInit.initialize();
  await NotificationService.initialize();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const AidxApp());
}

class AidxApp extends StatelessWidget {
  const AidxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HealthProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirebaseService()),
        Provider(create: (_) => SocialMediaService()),
        Provider(create: (_) => AppStateService()),
        Provider(create: (_) => DataPersistenceService()),
      ],
      child: MaterialApp(
        title: 'Aidx - Medical Assistant',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/dashboard': (context) => const DashboardScreen(),
          '/login': (context) => const LoginScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/drug': (context) => const DrugScreen(),
          '/symptom': (context) => const SymptomScreen(),
          '/reminder': (context) => const ReminderScreen(),
          '/timeline': (context) => const TimelineScreen(),
          '/ai-symptom': (context) => const AiSymptomScreen(),
          '/health-id': (context) => const HealthIdScreen(),
          '/health-habits': (context) => const HealthHabitsScreen(),
          '/community-support': (context) => const CommunitySupportScreen(),
          '/vitals': (context) => const VitalsScreen(),
          '/inbox': (context) => const InboxScreen(),
          '/ai-video-call': (context) => const AiVideoCallScreen(),
          '/medication-review': (context) => const MedicationReviewScreen(),
          '/medication-reminder': (context) => const MedicationReminderScreen(),
          '/medication-tracking': (context) => const MedicationTrackingScreen(),
          '/medication-history': (context) => const MedicationHistoryScreen(),
          '/medication-interaction': (context) => const MedicationInteractionScreen(),
          '/medication-side-effects': (context) => const MedicationSideEffectsScreen(),
          '/medication-dosage': (context) => const MedicationDosageScreen(),
          '/medication-compliance': (context) => const MedicationComplianceScreen(),
          '/medication-analytics': (context) => const MedicationAnalyticsScreen(),
          '/medication-export': (context) => const MedicationExportScreen(),
          '/medication-import': (context) => const MedicationImportScreen(),
          '/medication-backup': (context) => const MedicationBackupScreen(),
          '/medication-sync': (context) => const MedicationSyncScreen(),
          '/medication-cloud': (context) => const MedicationCloudScreen(),
          '/medication-offline': (context) => const MedicationOfflineScreen(),
          '/medication-online': (context) => const MedicationOnlineScreen(),
          '/medication-settings': (context) => const MedicationSettingsScreen(),
          '/medication-help': (context) => const MedicationHelpScreen(),
          '/medication-about': (context) => const MedicationAboutScreen(),
          '/medication-feedback': (context) => const MedicationFeedbackScreen(),
          '/medication-contact': (context) => const MedicationContactScreen(),
          '/medication-privacy': (context) => const MedicationPrivacyScreen(),
          '/medication-terms': (context) => const MedicationTermsScreen(),
          '/medication-legal': (context) => const MedicationLegalScreen(),
          '/medication-disclaimer': (context) => const MedicationDisclaimerScreen(),
          '/medication-warranty': (context) => const MedicationWarrantyScreen(),
          '/medication-liability': (context) => const MedicationLiabilityScreen(),
          '/medication-copyright': (context) => const MedicationCopyrightScreen(),
          '/medication-trademark': (context) => const MedicationTrademarkScreen(),
          '/medication-patent': (context) => const MedicationPatentScreen(),
          '/medication-license': (context) => const MedicationLicenseScreen(),
          '/medication-permission': (context) => const MedicationPermissionScreen(),
          '/medication-accessibility': (context) => const MedicationAccessibilityScreen(),
          '/medication-support': (context) => const MedicationSupportScreen(),
          '/medication-tutorial': (context) => const MedicationTutorialScreen(),
          '/medication-guide': (context) => const MedicationGuideScreen(),
          '/medication-faq': (context) => const MedicationFaqScreen(),
          '/medication-tips': (context) => const MedicationTipsScreen(),
          '/medication-tricks': (context) => const MedicationTricksScreen(),
          '/medication-hacks': (context) => const MedicationHacksScreen(),
          '/medication-shortcuts': (context) => const MedicationShortcutsScreen(),
          '/medication-gestures': (context) => const MedicationGesturesScreen(),
          '/medication-voice': (context) => const MedicationVoiceScreen(),
          '/medication-hands-free': (context) => const MedicationHandsFreeScreen(),
          '/medication-auto': (context) => const MedicationAutoScreen(),
          '/medication-smart': (context) => const MedicationSmartScreen(),
          '/medication-ai': (context) => const MedicationAiScreen(),
          '/medication-ml': (context) => const MedicationMlScreen(),
          '/medication-predictive': (context) => const MedicationPredictiveScreen(),
          '/medication-proactive': (context) => const MedicationProactiveScreen(),
          '/medication-preventive': (context) => const MedicationPreventiveScreen(),
          '/medication-diagnostic': (context) => const MedicationDiagnosticScreen(),
          '/medication-therapeutic': (context) => const MedicationTherapeuticScreen(),
          '/medication-rehabilitative': (context) => const MedicationRehabilitativeScreen(),
          '/medication-palliative': (context) => const MedicationPalliativeScreen(),
          '/medication-curative': (context) => const MedicationCurativeScreen(),
          '/medication-restorative': (context) => const MedicationRestorativeScreen(),
          '/medication-reconstructive': (context) => const MedicationReconstructiveScreen(),
          '/medication-corrective': (context) => const MedicationCorrectiveScreen(),
          '/medication-compensatory': (context) => const MedicationCompensatoryScreen(),
          '/medication-adaptive': (context) => const MedicationAdaptiveScreen(),
          '/medication-assistive': (context) => const MedicationAssistiveScreen(),
          '/medication-supportive': (context) => const MedicationSupportiveScreen(),
          '/medication-maintenance': (context) => const MedicationMaintenanceScreen(),
          '/medication-monitoring': (context) => const MedicationMonitoringScreen(),
          '/medication-surveillance': (context) => const MedicationSurveillanceScreen(),
          '/medication-observation': (context) => const MedicationObservationScreen(),
          '/medication-assessment': (context) => const MedicationAssessmentScreen(),
          '/medication-evaluation': (context) => const MedicationEvaluationScreen(),
          '/medication-analysis': (context) => const MedicationAnalysisScreen(),
          '/medication-interpretation': (context) => const MedicationInterpretationScreen(),
          '/medication-diagnosis': (context) => const MedicationDiagnosisScreen(),
          '/medication-prognosis': (context) => const MedicationPrognosisScreen(),
          '/medication-treatment': (context) => const MedicationTreatmentScreen(),
          '/medication-management': (context) => const MedicationManagementScreen(),
          '/medication-care': (context) => const MedicationCareScreen(),
          '/medication-service': (context) => const MedicationServiceScreen(),
          '/medication-program': (context) => const MedicationProgramScreen(),
          '/medication-plan': (context) => const MedicationPlanScreen(),
          '/medication-protocol': (context) => const MedicationProtocolScreen(),
          '/medication-guideline': (context) => const MedicationGuidelineScreen(),
          '/medication-standard': (context) => const MedicationStandardScreen(),
          '/medication-practice': (context) => const MedicationPracticeScreen(),
          '/medication-procedure': (context) => const MedicationProcedureScreen(),
          '/medication-method': (context) => const MedicationMethodScreen(),
          '/medication-technique': (context) => const MedicationTechniqueScreen(),
          '/medication-approach': (context) => const MedicationApproachScreen(),
          '/medication-strategy': (context) => const MedicationStrategyScreen(),
          '/medication-tactic': (context) => const MedicationTacticScreen(),
          '/medication-solution': (context) => const MedicationSolutionScreen(),
          '/medication-remedy': (context) => const MedicationRemedyScreen(),
          '/medication-cure': (context) => const MedicationCureScreen(),
          '/medication-healing': (context) => const MedicationHealingScreen(),
          '/medication-recovery': (context) => const MedicationRecoveryScreen(),
          '/medication-restoration': (context) => const MedicationRestorationScreen(),
          '/medication-rehabilitation': (context) => const MedicationRehabilitationScreen(),
          '/medication-therapy': (context) => const MedicationTherapyScreen(),
          '/medication-intervention': (context) => const MedicationInterventionScreen(),
          '/medication-treatment-plan': (context) => const MedicationTreatmentPlanScreen(),
          '/medication-care-plan': (context) => const MedicationCarePlanScreen(),
          '/medication-management-plan': (context) => const MedicationManagementPlanScreen(),
          '/medication-monitoring-plan': (context) => const MedicationMonitoringPlanScreen(),
          '/medication-surveillance-plan': (context) => const MedicationSurveillancePlanScreen(),
          '/medication-observation-plan': (context) => const MedicationObservationPlanScreen(),
          '/medication-assessment-plan': (context) => const MedicationAssessmentPlanScreen(),
          '/medication-evaluation-plan': (context) => const MedicationEvaluationPlanScreen(),
          '/medication-analysis-plan': (context) => const MedicationAnalysisPlanScreen(),
          '/medication-interpretation-plan': (context) => const MedicationInterpretationPlanScreen(),
          '/medication-diagnosis-plan': (context) => const MedicationDiagnosisPlanScreen(),
          '/medication-prognosis-plan': (context) => const MedicationPrognosisPlanScreen(),
          '/medication-treatment-plan-plan': (context) => const MedicationTreatmentPlanPlanScreen(),
          '/medication-management-plan-plan': (context) => const MedicationManagementPlanPlanScreen(),
          '/medication-care-plan-plan': (context) => const MedicationCarePlanPlanScreen(),
          '/medication-service-plan': (context) => const MedicationServicePlanScreen(),
          '/medication-program-plan': (context) => const MedicationProgramPlanScreen(),
          '/medication-plan-plan': (context) => const MedicationPlanPlanScreen(),
          '/medication-protocol-plan': (context) => const MedicationProtocolPlanScreen(),
          '/medication-guideline-plan': (context) => const MedicationGuidelinePlanScreen(),
          '/medication-standard-plan': (context) => const MedicationStandardPlanScreen(),
          '/medication-practice-plan': (context) => const MedicationPracticePlanScreen(),
          '/medication-procedure-plan': (context) => const MedicationProcedurePlanScreen(),
          '/medication-method-plan': (context) => const MedicationMethodPlanScreen(),
          '/medication-technique-plan': (context) => const MedicationTechniquePlanScreen(),
          '/medication-approach-plan': (context) => const MedicationApproachPlanScreen(),
          '/medication-strategy-plan': (context) => const MedicationStrategyPlanScreen(),
          '/medication-tactic-plan': (context) => const MedicationTacticPlanScreen(),
          '/medication-solution-plan': (context) => const MedicationSolutionPlanScreen(),
          '/medication-remedy-plan': (context) => const MedicationRemedyPlanScreen(),
          '/medication-cure-plan': (context) => const MedicationCurePlanScreen(),
          '/medication-healing-plan': (context) => const MedicationHealingPlanScreen(),
          '/medication-recovery-plan': (context) => const MedicationRecoveryPlanScreen(),
          '/medication-restoration-plan': (context) => const MedicationRestorationPlanScreen(),
          '/medication-rehabilitation-plan': (context) => const MedicationRehabilitationPlanScreen(),
          '/medication-therapy-plan': (context) => const MedicationTherapyPlanScreen(),
          '/medication-intervention-plan': (context) => const MedicationInterventionPlanScreen(),
        },
      ),
    );
  }
}
