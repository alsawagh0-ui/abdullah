import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/dashboard_screen.dart';

/// شاشة تسجيل الدخول: تطلب من الطالب رقمه المدني فقط (12 رقماً حسب
/// النظام الكويتي)، وتنقله بعد التحقق إلى لوحة التحكم.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _civilIdController = TextEditingController();

  @override
  void dispose() {
    _civilIdController.dispose();
    super.dispose();
  }

  /// يتحقق من صحة النموذج، ثم يستدعي AuthProvider لتسجيل الدخول،
  /// وينقل الطالب للوحة التحكم عند النجاح.
  Future<void> _handleLogin() async {
    // إخفاء لوحة المفاتيح قبل بدء العملية.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithCivilId(_civilIdController.text.trim());

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'حدث خطأ غير متوقع')),
      );
    }
  }

  /// يتحقق أن الرقم المدني مكوّن من 12 رقماً بالضبط، وأنه أرقام فقط.
  String? _validateCivilId(String? value) {
    final trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'الرجاء إدخال الرقم المدني';
    }
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'الرقم المدني يجب أن يتكوّن من أرقام فقط';
    }
    if (trimmed.length != AppConstants.civilIdLength) {
      return 'الرقم المدني يجب أن يتكوّن من ${AppConstants.civilIdLength} رقماً';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LogoHeader(),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _civilIdController,
                      label: 'الرقم المدني',
                      hint: '285xxxxxxxx',
                      prefixIcon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: AppConstants.civilIdLength,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateCivilId,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'تسجيل الدخول',
                      icon: Icons.login_rounded,
                      isLoading: isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'بيانات الطالب مسجّلة مسبقاً من قبل المدرسة، ولا حاجة لإنشاء حساب جديد',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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

/// رأس الشاشة: شعار المنصة وعنوانها الترحيبي.
class _LogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'منصة التعليم الذكي',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'مدرّسك الخاص المدعوم بالذكاء الاصطناعي',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
