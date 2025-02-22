import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class MapPage extends StatelessWidget {
  final VoidCallback? onBackPress;
  final bool showBackButton;

  const MapPage({
    super.key,
    this.onBackPress,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBackButton
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (onBackPress != null) {
                    onBackPress!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: const Text('Map'),
            )
          : null,
      body: WebviewScaffold(
        url: 'assets/map.html',
        withZoom: true,
        withLocalStorage: true,
        hidden: true,
        initialChild: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
