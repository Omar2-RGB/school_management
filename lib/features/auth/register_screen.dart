import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // حقول مشتركة
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  // الدور المختار
  String _selectedRole = 'parent'; // 'admin' أو 'teacher' أو 'parent'

  // حقول ولي الأمر
  final _childNameController = TextEditingController();
  final _childBirthDateController = TextEditingController();
  final _parentCodeController = TextEditingController(); // ✅ رمز الطالب PIN

  // حقول الإدارة
  final _positionController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _classList = ['الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس'];
  String? _selectedClass;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _childNameController.dispose();
    _childBirthDateController.dispose();
    _parentCodeController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. التحقق من رمز الطالب (إذا كان الدور "ولي أمر")
      int? studentId;
      String? studentName;

      if (_selectedRole == 'parent') {
        final code = _parentCodeController.text.trim().toUpperCase();

        if (code.isEmpty) {
          throw Exception('يرجى إدخال رمز الطالب');
        }

        final student = await Supabase.instance.client
            .from('students')
            .select('id, name')
            .eq('parent_code', code)
            .maybeSingle();

        if (student == null) {
          throw Exception('❌ رمز الطالب غير صحيح، يرجى التأكد من الرقم');
        }

        studentId = student['id'] as int;
        studentName = student['name'] as String;

        // التحقق من أن الطالب لم يتم ربطه بولي أمر آخر
        final existingParent = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('child_student_id', studentId)
            .eq('role', 'parent')
            .maybeSingle();

        if (existingParent != null) {
          throw Exception('⚠️ هذا الطالب مرتبط بالفعل بولي أمر آخر');
        }
      }

      // 2. تجهيز البيانات
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
      };

      if (_selectedRole == 'parent') {
        userData['child_name'] = _childNameController.text.trim();
        userData['child_class'] = _selectedClass;
        userData['child_birth_date'] = _childBirthDateController.text.trim();
        userData['child_student_id'] = studentId; // ✅ ربط ولي الأمر بالطالب
      } else {
        userData['position'] = _positionController.text.trim();
        userData['department'] = _departmentController.text.trim();
      }

      // 3. تسجيل المستخدم
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: userData,
      );

      if (response.user == null) {
        throw Exception('فشل إنشاء الحساب');
      }

      // 4. إذا كان ولي أمر، نحدث جدول profiles لإضافة child_student_id (في حال لم يضف عبر Trigger)
      if (_selectedRole == 'parent' && studentId != null) {
        final accessToken = response.session?.accessToken;
        if (accessToken != null) {
          final url = Uri.parse(
            'https://kxujxjsyvdqbxcefytrl.supabase.co/rest/v1/profiles?id=eq.${response.user!.id}',
          );

          final headers = {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'apikey': 'sb_publishable_ZuumFuds79JhyS8tfwjNCQ_oG2U9-rW',
            'Prefer': 'return=minimal',
          };

          final body = jsonEncode({
            'child_student_id': studentId,
            'child_name': studentName ?? _childNameController.text.trim(),
          });

          await http.patch(url, headers: headers, body: body);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedRole == 'parent'
                ? '✅ تم إنشاء الحساب بنجاح! تم ربطك بالطالب ${studentName ?? _childNameController.text.trim()}'
                : '✅ تم إنشاء الحساب بنجاح! يرجى تأكيد بريدك الإلكتروني.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اختيار الدور
                    const Text(
                      'اختر نوع الحساب:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRoleCard(
                            title: 'مدير',
                            icon: Icons.admin_panel_settings,
                            value: 'admin',
                            isSelected: _selectedRole == 'admin',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRoleCard(
                            title: 'معلم',
                            icon: Icons.school,
                            value: 'teacher',
                            isSelected: _selectedRole == 'teacher',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRoleCard(
                            title: 'ولي أمر',
                            icon: Icons.family_restroom,
                            value: 'parent',
                            isSelected: _selectedRole == 'parent',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // حقول مشتركة
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                          return 'بريد إلكتروني غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone),
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (v != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ✅ حقول خاصة حسب الدور
                    if (_selectedRole == 'parent') ...[
                      const Text(
                        'معلومات الطالب',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // ✅ حقل رمز الطالب (PIN)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _parentCodeController,
                              decoration: const InputDecoration(
                                labelText: '🔑 رمز الطالب (من المدرسة)',
                                prefixIcon: Icon(Icons.vpn_key),
                                border: OutlineInputBorder(),
                                hintText: 'مثال: STU-123456',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'أدخل الرمز الذي حصلت عليه من المدرسة لربط حسابك بالطالب',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _childNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الطالب (تأكيد)',
                          prefixIcon: Icon(Icons.child_care),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: const InputDecoration(
                          labelText: 'الصف',
                          prefixIcon: Icon(Icons.class_),
                          border: OutlineInputBorder(),
                        ),
                        items: _classList.map((cls) {
                          return DropdownMenuItem(value: cls, child: Text(cls));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedClass = val),
                        validator: (v) => v == null ? 'اختر الصف' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _childBirthDateController,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ ميلاد الطالب (اختياري)',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else if (_selectedRole == 'admin') ...[
                      const Text(
                        'معلومات الموظف',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _positionController,
                        decoration: const InputDecoration(
                          labelText: 'المسمى الوظيفي',
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'القسم / الإدارة',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                      ),
                    ],

                    // رسالة للمعلم
                    if (_selectedRole == 'teacher') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'سيتم ربط حساب المعلم بالمواد والصفوف لاحقاً من قبل المدير.',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // زر التسجيل
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'إنشاء الحساب',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('لديك حساب بالفعل؟'),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          child: const Text('تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderWhite,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}