import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import '../students/students_list_screen.dart';
import '../students/student_profile_screen.dart';
import '../teachers/teachers_list_screen.dart';
import '../classes/classes_list_screen.dart';
import '../attendance/attendance_screen.dart';
import '../grades/grades_screen.dart';
import '../payments/payments_screen.dart';
import '../auth/login_screen.dart';
import '../classes/class_subjects_screen.dart';
import '../sections/sections_list_screen.dart';
import '../schedules/schedule_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const DashboardScreen({
    super.key,
    required this.userName,
    this.userRole = 'admin',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _studentsCount = 0;
  int _teachersCount = 0;
  int _classesCount = 0;
  int _todayAttendance = 0;
  double _totalPayments = 0.0;
  bool _isLoading = true;
  int? _parentStudentId;
  int? _teacherId;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadUserIds();
  }

  Future<void> _loadUserIds() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('teacher_id, child_student_id')
          .eq('id', user.id)
          .single();

      if (widget.userRole == 'teacher') {
        _teacherId = profile['teacher_id'] as int?;
      } else if (widget.userRole == 'parent') {
        _parentStudentId = profile['child_student_id'] as int?;
      }
    } catch (e) {
      debugPrint('خطأ في جلب معرف المستخدم: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> students = [];
      List<Map<String, dynamic>> teachers = [];
      List<Map<String, dynamic>> classes = [];
      List<Map<String, dynamic>> attendance = [];
      List<Map<String, dynamic>> payments = [];

      if (widget.userRole == 'admin') {
        final results = await Future.wait([
          DatabaseHelper.getAllStudents(),
          DatabaseHelper.getAllTeachers(),
          DatabaseHelper.getAllClasses(),
          DatabaseHelper.getAttendanceByDate(DateTime.now().toIso8601String().split('T').first),
          DatabaseHelper.getAllPayments(),
        ]);
        students = results[0] as List<Map<String, dynamic>>;
        teachers = results[1] as List<Map<String, dynamic>>;
        classes = results[2] as List<Map<String, dynamic>>;
        attendance = results[3] as List<Map<String, dynamic>>;
        payments = results[4] as List<Map<String, dynamic>>;
      } else if (widget.userRole == 'teacher' && _teacherId != null) {
        students = await DatabaseHelper.getAllStudentsForTeacher(_teacherId!);
        teachers = await DatabaseHelper.getAllTeachers();
        classes = await DatabaseHelper.getAllClasses();
        final allAttendance = await DatabaseHelper.getAttendanceByDate(
          DateTime.now().toIso8601String().split('T').first,
        );
        final studentIds = students.map((s) => s['id'] as int).toList();
        attendance = allAttendance.where((a) => studentIds.contains(a['student_id'])).toList();
        payments = await DatabaseHelper.getAllPayments();
      } else {
        students = [];
        teachers = [];
        classes = [];
        attendance = [];
        payments = [];
      }

      setState(() {
        _studentsCount = students.length;
        _teachersCount = teachers.length;
        _classesCount = classes.length;
        _todayAttendance = attendance.length;
        _totalPayments = payments.fold(0.0, (sum, p) => sum + (p['amount'] as double? ?? 0.0));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _logout() {
    Supabase.instance.client.auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';
    final isTeacher = widget.userRole == 'teacher';
    final isParent = widget.userRole == 'parent';

    return Scaffold(
      drawer: _buildDrawer(isAdmin, isTeacher, isParent),
      appBar: AppBar(
        title: Text('مرحباً، ${widget.userName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        // ✅ بطاقة الطلاب (قابلة للضغط)
                        _buildStatCard(
                          title: 'الطلاب',
                          value: _studentsCount.toString(),
                          icon: Icons.person,
                          color: Colors.blue,
                          onTap: (isAdmin || isTeacher)
                              ? () {
                                  // ✅ هنا الانتقال إلى شاشة الطلاب
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const StudentsListScreen(),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        _buildStatCard(
                          title: 'المعلمون',
                          value: _teachersCount.toString(),
                          icon: Icons.person_outline,
                          color: Colors.green,
                          onTap: isAdmin
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TeachersListScreen(),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        _buildStatCard(
                          title: 'الصفوف',
                          value: _classesCount.toString(),
                          icon: Icons.class_,
                          color: Colors.orange,
                          onTap: isAdmin
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ClassesListScreen(),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        _buildStatCard(
                          title: 'الحضور اليوم',
                          value: _todayAttendance.toString(),
                          icon: Icons.check_circle,
                          color: Colors.purple,
                          onTap: (isAdmin || isTeacher)
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AttendanceScreen(
                                        userRole: widget.userRole,
                                        teacherId: _teacherId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        _buildStatCard(
                          title: 'إجمالي المدفوعات',
                          value: '${_totalPayments.toStringAsFixed(2)} د.أ',
                          icon: Icons.money,
                          color: Colors.teal,
                          onTap: isAdmin
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PaymentsScreen(),
                                    ),
                                  );
                                }
                              : null,
                        ),
                        _buildStatCard(
                          title: 'الدرجات',
                          value: '0',
                          icon: Icons.grade,
                          color: Colors.red,
                          onTap: (isAdmin || isTeacher)
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GradesScreen(
                                        userRole: widget.userRole,
                                        teacherId: _teacherId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'آخر النشاطات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderWhite),
                      ),
                      child: const Center(
                        child: Text('سيتم إضافة آخر النشاطات قريباً'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ✅ بناء القائمة الجانبية
  Widget _buildDrawer(bool isAdmin, bool isTeacher, bool isParent) {
    return Drawer(
      child: Container(
        color: AppColors.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.school, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isAdmin ? 'مدير المدرسة' : (isTeacher ? 'معلم' : 'ولي أمر'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              _buildDrawerGroup(
                title: 'الإدارة',
                icon: Icons.settings_applications,
                children: [
                  _buildDrawerItem(
                    icon: Icons.class_,
                    title: 'الصفوف',
                    onTap: () => _navigateTo(context, const ClassesListScreen()),
                  ),
                  // ✅ الطلاب في القائمة الجانبية
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'الطلاب',
                    onTap: () => _navigateTo(context, const StudentsListScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: 'المعلمين',
                    onTap: () => _navigateTo(context, const TeachersListScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.book,
                    title: 'مواد الصفوف',
                    onTap: () => _navigateTo(context, const ClassSubjectsScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.group,
                    title: 'الشعب',
                    onTap: () => _navigateTo(context, const SectionsListScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'جدول الحصص',
                    onTap: () => _navigateTo(context, const ScheduleManagementScreen()),
                  ),
                ],
              ),
            ],
            if (isAdmin || isTeacher) ...[
              _buildDrawerGroup(
                title: 'المتابعة',
                icon: Icons.timeline,
                children: [
                  _buildDrawerItem(
                    icon: Icons.check_circle,
                    title: 'الحضور والغياب',
                    onTap: () => _navigateTo(
                      context,
                      AttendanceScreen(
                        userRole: widget.userRole,
                        teacherId: _teacherId,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.grade,
                    title: 'الدرجات',
                    onTap: () => _navigateTo(
                      context,
                      GradesScreen(
                        userRole: widget.userRole,
                        teacherId: _teacherId,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.money,
                    title: 'المدفوعات',
                    onTap: () => _navigateTo(context, const PaymentsScreen()),
                  ),
                ],
              ),
            ],
            if (isParent) ...[
              _buildDrawerGroup(
                title: 'متابعة الطالب',
                icon: Icons.person,
                children: [
                  _buildDrawerItem(
                    icon: Icons.assignment_ind,
                    title: 'ملفي الشخصي',
                    onTap: () {
                      if (_parentStudentId != null) {
                        _navigateTo(
                          context,
                          StudentProfileScreen(studentId: _parentStudentId!),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لم يتم ربط الطالب بحساب ولي الأمر بعد'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
            const Divider(),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              color: AppColors.danger,
              onTap: _logout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        ...children,
        const Divider(height: 8),
      ],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_left, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderWhite),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}