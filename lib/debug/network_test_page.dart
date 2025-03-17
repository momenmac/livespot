import 'package:flutter/material.dart';
import '../services/network_checker.dart';
import '../services/api/account/api_urls.dart';
import 'api_tester.dart';

class NetworkTestPage extends StatefulWidget {
  const NetworkTestPage({super.key});

  @override
  _NetworkTestPageState createState() => _NetworkTestPageState();
}

class _NetworkTestPageState extends State<NetworkTestPage> {
  String _results = 'No tests run yet';
  bool _isLoading = false;

  Future<void> _runNetworkTests() async {
    setState(() {
      _isLoading = true;
      _results = 'Running tests...';
    });

    try {
      // Check server reachability
      final isServerReachable = await NetworkChecker.isServerReachable();

      // Get detailed network info
      final networkInfo = await NetworkChecker.debugNetworkInfo();

      // Test register endpoint with multiple base URLs
      await ApiTester.testRegisterEndpoint();

      setState(() {
        _results = '''
Server reachable: $isServerReachable
Current API base URL: ${ApiUrls.baseUrl}
Network info: ${networkInfo.toString()}
Check console logs for detailed API test results.
        ''';
      });
    } catch (e) {
      setState(() {
        _results = 'Error running tests: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _runNetworkTests,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Run Network Tests'),
            ),
            const SizedBox(height: 24),
            const Text('Results:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(_results),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
