import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class TNotificationTheme {
  TNotificationTheme._();

  static final notificationCardThemeLight = CardTheme(
    elevation: 0,
    margin: const EdgeInsets.all(16),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );

  static final notificationCardThemeDark = CardTheme(
    color: ThemeConstants.darkCardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    elevation: 0, // Reduced elevation for modern look
    margin: const EdgeInsets.all(16),
  );

  static final notificationIconThemeLight = IconThemeData(
    color: ThemeConstants.darkCardColor,
    size: 31,
    opacity: 0.95,
  );

  static final notificationIconThemeDark = IconThemeData(
    color: ThemeConstants.greyLight,
    size: 31,
    opacity: 0.95,
  );

  static final notificationButtonThemeLight = FloatingActionButtonThemeData(
    backgroundColor: ThemeConstants.primaryColor,
    elevation: 2.0,
    foregroundColor: ThemeConstants.lightBackgroundColor,
    splashColor: ThemeConstants.primaryColor.withAlpha(128),
    hoverColor: ThemeConstants.navigationHoverColor,
    focusColor: ThemeConstants.primaryColor,
    shape: const CircleBorder(),
  );

  static final notificationButtonThemeDark = FloatingActionButtonThemeData(
    backgroundColor: ThemeConstants.primaryColor,
    elevation: 2.0,
    foregroundColor: ThemeConstants.darkCardColor,
    splashColor: ThemeConstants.primaryColor.withAlpha(128),
    hoverColor: ThemeConstants.navigationHoverColor,
    focusColor: ThemeConstants.navigationPressColor,
    shape: const CircleBorder(),
  );

  static final notificationButtonStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(Colors.white),
    foregroundColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontWeight: FontWeight.bold),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(200),
      ),
    ),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(vertical: 13),
    ),
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(30)),
  );

  static final notificationButtonStyleDark = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(ThemeConstants.darkCardColor),
    foregroundColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontWeight: FontWeight.bold),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(200),
      ),
    ),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(vertical: 13),
    ),
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(30)),
  );

  static final notificationSecondaryButtonStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.all(ThemeConstants.primaryColor),
    foregroundColor: WidgetStateProperty.all(Colors.white),
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontWeight: FontWeight.bold),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(200),
      ),
    ),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(vertical: 13),
    ),
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(30)),
  );

  static final notificationListCardLight = CardTheme(
    color: ThemeConstants.greyLight,
    elevation: 0,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final notificationListCardDark = CardTheme(
    color: ThemeConstants.darkCardColor,
    elevation: 0,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final notificationTextStyleLight = TextStyle(
    color: Colors.black,
    fontSize: 16,
  );

  static final notificationTextStyleDark = TextStyle(
    color: Colors.white,
    fontSize: 16,
  );
}
