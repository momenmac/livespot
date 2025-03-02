import 'package:flutter_application_2/services/interfaces/message_service.dart';
import 'package:flutter_application_2/services/implementations/mock_message_service.dart';
import 'package:flutter_application_2/services/implementations/firebase_message_service.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';

final serviceLocator = GetIt.instance;

/// Initialize service locator with appropriate implementations
///
/// This setup allows easy switching between mock data and real Firebase data
/// by simply changing the useMocks parameter.
void setupServiceLocator({bool? useMocks}) {
  // Determine if we should use mocks based on parameter or build mode
  final shouldUseMocks = useMocks ?? kDebugMode;

  // Register MessageService implementation
  serviceLocator.registerLazySingleton<MessageServiceInterface>(
    () => shouldUseMocks ? MockMessageService() : FirebaseMessageService(),
  );

  // Register other services as needed
  // serviceLocator.registerLazySingleton<AnalyticsService>(...);
  // serviceLocator.registerLazySingleton<AuthService>(...);
}

/// Update the message controller to use the registered service
void updateMessageController() {
  // This will be called when we need to refresh the controller
  final messageService = serviceLocator<MessageServiceInterface>();
  // Notify relevant parts of the app if needed
}
