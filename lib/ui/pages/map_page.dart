import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map'),
      ),
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
