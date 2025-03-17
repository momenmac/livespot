import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DirectApiTestPage extends StatefulWidget {
  const DirectApiTestPage({super.key});

  @override
  _DirectApiTestPageState createState() => _DirectApiTestPageState();
}

class _DirectApiTestPageState extends State<DirectApiTestPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController =
      TextEditingController(text: 'http://10.0.2.2:8000/accounts/register/');
  final _emailController = TextEditingController(text: 'test@example.com');
  final _passwordController = TextEditingController(text: 'Password123');
  final _firstNameController = TextEditingController(text: 'Test');
  final _lastNameController = TextEditingController(text: 'User');

  String _response = 'No response yet';
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _testApi() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _response = 'Sending request...';
    });

    try {
      final url = Uri.parse(_urlController.text);

      // Log request details
      final requestBody = {
        'email': _emailController.text,
        'password': _passwordController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
      };

      print('🧪 API Test: Sending request to ${url.toString()}');
      print('🧪 Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('🧪 Response status: ${response.statusCode}');
      print('🧪 Response headers: ${response.headers}');
      print('🧪 Response body: ${response.body}');

      setState(() {
        _response = '''
Status Code: ${response.statusCode}
Headers: ${response.headers}
Body: ${response.body}
        ''';
      });
    } catch (e) {
      print('🧪 Error: $e');
      setState(() {
        _response = 'Error: ${e.toString()}';
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
      appBar: AppBar(title: const Text('Direct API Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'API URL'),
                validator: (value) => value!.isEmpty ? 'URL is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value!.isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                    value!.isEmpty ? 'Password is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) =>
                    value!.isEmpty ? 'First name is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Last name is required' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _testApi,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Send Request'),
              ),
              const SizedBox(height: 24),
              const Text('Response:',
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
                    child: Text(_response),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
