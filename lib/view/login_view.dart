// Directory: lib/view/
// File: login_view.dart

import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../service/auth_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool isSignUp = false;
  bool isLoading = false;
  bool _obscurePassword = true;
  DateTime? _dateOfBirth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final latestAdultBirthDate = DateTime(now.year - 18, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? latestAdultBirthDate,
      firstDate: DateTime(1900),
      lastDate: latestAdultBirthDate,
      helpText: AppText.tr(context, 'เลือกวันเกิด'),
    );
    if (date != null && mounted) setState(() => _dateOfBirth = date);
  }

  void _submit() async {
    if (isSignUp &&
        (_dateOfBirth == null || !AuthService.isAtLeast18(_dateOfBirth!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.tr(context, 'สมัครสมาชิกได้เมื่ออายุครบ 18 ปีบริบูรณ์'),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      if (isSignUp) {
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth!,
        );
      } else {
        await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppText.tr(context, 'เกิดข้อผิดพลาด')}: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_graph, size: 80, color: Colors.indigo),
                  const SizedBox(height: 16),
                  Text(
                    isSignUp
                        ? AppText.tr(context, 'สมัครสมาชิก AI Accounting')
                        : AppText.tr(context, 'เข้าสู่ระบบ AI Accounting'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: AppText.tr(
                          context,
                          'ชื่อร้านค้า / ผู้ใช้งาน',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake_outlined),
                      title: Text(AppText.tr(context, 'วันเดือนปีเกิด')),
                      subtitle: Text(
                        _dateOfBirth == null
                            ? AppText.tr(
                                context,
                                'เลือกวันเกิด (ต้องมีอายุ 18 ปีขึ้นไป)',
                              )
                            : AppText.formatDate(context, _dateOfBirth!),
                      ),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: _selectDateOfBirth,
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: AppText.tr(context, 'อีเมล'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: AppText.tr(context, 'รหัสผ่าน'),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                            ),
                            child: Text(
                              AppText.tr(
                                context,
                                isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                  TextButton(
                    onPressed: () => setState(() => isSignUp = !isSignUp),
                    child: Text(
                      isSignUp
                          ? AppText.tr(context, 'มีบัญชีแล้ว? เข้าสู่ระบบ')
                          : AppText.tr(context, 'ยังไม่มีบัญชี? สมัครสมาชิก'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
