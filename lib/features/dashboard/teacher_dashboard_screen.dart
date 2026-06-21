import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import '../attendance/attendance_screen.dart';
import '../grades/grades_screen.dart';
import '../students/students_list_screen.dart';
import '../auth/login_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String userName;
  final int teacherId;

  const TeacherDashboardScreen({
    super.key,
    required this.userName,
    required this.teacherId,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _studentsCount = 0;
  int _todayClasses = 0;
  double _attendanceRate = 0.0;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // جلب طلاب المعلم
      final students = await DatabaseHelper.getAllStudentsForTeacher(widget.teacherId);
      _students = students;
      _studentsCount = students.length;

      // جلب المواد التي يدرسها المعلم (للحصص)
      final subjects = await DatabaseHelper.getTeacherSubjects(widget.teacherId);
      _todayClasses = subjects.length;

      // حساب نسبة الحضور لليوم
      final today = DateTime.now().toIso8601String().split('T').first;
      final attendance = await DatabaseHelper.getAttendanceByDate(today);
      final teacherStudents = students.map((s) => s['id'] as int).toList();
      final todayAttendance = attendance.where((a) => teacherStudents.contains(a['student_id'])).toList();
      final present = todayAttendance.where((a) => a['status'] == 'present').length;
      _attendanceRate = todayAttendance.isNotEmpty ? (present / todayAttendance.length) * 100 : 0.0;

      // آخر النشاطات (آخر 5 حركات)
      // هنا يمكن جلب آخر الحضور أو الدرجات المسجلة
      _recentActivities = [];

      setState(() => _isLoading = false);
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
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text('مرحباً، ${widget.userName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقات الإحصائيات
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatCard(
                          title: 'طلابي',
                          value: _studentsCount.toString(),
                          icon: Icons.person,
                          color: Colors.blue,
                        ),
                        _buildStatCard(
                          title: 'حصص اليوم',
                          value: _todayClasses.toString(),
                          icon: Icons.class_,
                          color: Colors.green,
                        ),
                        _buildStatCard(
                          title: 'الحضور',
                          value: '${_attendanceRate.toStringAsFixed(0)}%',
                          icon: Icons.check_circle,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // أزرار سريعة
                    const Text(
                      'الإجراءات السريعة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.check_circle,
                          label: 'الحضور',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AttendanceScreen(
                                  userRole: 'teacher',
                                  teacherId: widget.teacherId,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          icon: Icons.grade,
                          label: 'الدرجات',
                          color: Colors.red,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GradesScreen(
                                  userRole: 'teacher',
                                  teacherId: widget.teacherId,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          icon: Icons.person,
                          label: 'طلابي',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentsListScreen(
                                  teacherId: widget.teacherId,
                                  userRole: 'teacher',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // قائمة الطلاب
                    const Text(
                      'طلابي',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _students.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderWhite),
                            ),
                            child: const Center(child: Text('لا يوجد طلاب مسجلين لديك')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _students.length > 3 ? 3 : _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final name = student['name'] ?? 'بدون اسم';
                              final className = student['classes']?['name'] ?? 'بدون صف';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(name.isNotEmpty ? name[0] : 'ط'),
                                  ),
                                  title: Text(name),
                                  subtitle: Text('الصف: $className'),
                                  trailing: const Icon(Icons.chevron_left),
                                  onTap: () {
                                    // فتح ملف الطالب
                                  },
                                ),
                              );
                            },
                          ),
                    if (_students.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentsListScreen(
                                  teacherId: widget.teacherId,
                                  userRole: 'teacher',
                                ),
                              ),
                            );
                          },
                          child: Text('عرض جميع الطلاب (${_students.length})'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawer() {
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
                  const Text(
                    'معلم',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'لوحة التحكم',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.check_circle,
              title: 'الحضور والغياب',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(
                      userRole: 'teacher',
                      teacherId: widget.teacherId,
                    ),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.grade,
              title: 'الدرجات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GradesScreen(
                      userRole: 'teacher',
                      teacherId: widget.teacherId,
                    ),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.person,
              title: 'طلابي',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentsListScreen(
                      teacherId: widget.teacherId,
                      userRole: 'teacher',
                    ),
                  ),
                );
              },
            ),
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
      onTap: onTap,
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderWhite),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}