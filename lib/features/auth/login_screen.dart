import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/teacher_dashboard_screen.dart';
import '../dashboard/parent_dashboard_screen.dart'; // ✅ استيراد لوحة تحكم ولي الأمر
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ✅ حشو الحقول بمثال لإيميل وكلمة مرور (مدير)
    _emailController.text = 'admin@admin.com';
    _passwordController.text = 'admin123';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // ✅ جلب بيانات المستخدم من جدول profiles (مع teacher_id و child_student_id)
        final userData = await Supabase.instance.client
            .from('profiles')
            .select('name, role, teacher_id, child_student_id')
            .eq('id', response.user!.id)
            .single();

        final userName = userData['name'] ?? 'مستخدم';
        final userRole = userData['role'] ?? 'admin';

        if (mounted) {
          // ✅ إذا كان المستخدم معلم → TeacherDashboardScreen
          if (userRole == 'teacher') {
            final teacherId = userData['teacher_id'] as int?;
            if (teacherId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ حساب المعلم غير مكتمل، يرجى التواصل مع المدير'),
                  backgroundColor: Colors.orange,
                ),
              );
              setState(() => _isLoading = false);
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TeacherDashboardScreen(
                  userName: userName,
                  teacherId: teacherId,
                ),
              ),
            );
          }
          // ✅ إذا كان المستخدم ولي أمر → ParentDashboardScreen
          else if (userRole == 'parent') {
            final childStudentId = userData['child_student_id'] as int?;
            if (childStudentId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ لم يتم ربط الطالب بحساب ولي الأمر بعد'),
                  backgroundColor: Colors.orange,
                ),
              );
              setState(() => _isLoading = false);
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ParentDashboardScreen(
                  userName: userName,
                  studentId: childStudentId,
                ),
              ),
            );
          }
          // ✅ مدير → DashboardScreen
          else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userName: userName,
                  userRole: userRole,
                ),
              ),
            );
          }
        }
      } else {
        setState(() => _errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
    } catch (e) {
      if (e is AuthApiException && e.statusCode == 400) {
        setState(() => _errorMessage = '❌ البريد الإلكتروني أو كلمة المرور غير صحيحة.\nتأكد من تأكيد بريدك الإلكتروني أولاً.');
      } else {
        setState(() => _errorMessage = '❌ حدث خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ إعادة تعيين كلمة المرور (نسيت كلمة المرور)
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل بريدك الإلكتروني أولاً')),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل إرسال رابط إعادة التعيين: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'نظام إدارة المدارس',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('سجل الدخول للمتابعة'),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                      ),
                      // ✅ رابط "نسيت كلمة المرور"
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ليس لديك حساب؟'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text('إنشاء حساب'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}