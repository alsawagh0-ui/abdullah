import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _apiService = ApiService();

  String _idType = 'civil_id'; // civil_id | student_number
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fullName = await _apiService.login(
        identifier: _identifierController.text.trim(),
        idType: _idType,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(studentName: fullName)),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.school_rounded, size: 72, color: Colors.indigo),
                    const SizedBox(height: 16),
                    Text(
                      'منصة التعليم الذكي',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سجّل دخولك للوصول إلى موادك ودروسك',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // اختيار طريقة تسجيل الدخول
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'civil_id', label: Text('الرقم المدني')),
                        ButtonSegment(value: 'student_number', label: Text('رقم الطالب')),
                      ],
                      selected: {_idType},
                      onSelectionChanged: (selection) {
                        setState(() => _idType = selection.first);
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: _idType == 'civil_id' ? 'الرقم المدني' : 'رقم الطالب',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'هذا الحقل مطلوب';
                        }
                        return null;
                      },
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],

                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('تسجيل الدخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
