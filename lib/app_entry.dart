import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/providers/theme_provider.dart';
import 'package:flutter_application_2/ui/theme/theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
    );
  }
}
