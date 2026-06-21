import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import 'add_student_screen.dart';
import 'student_profile_screen.dart';

class StudentsListScreen extends StatefulWidget {
  final int? teacherId; // إذا كان معلم، نمرر معرفه
  final String? userRole;

  const StudentsListScreen({super.key, this.teacherId, this.userRole});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> data = [];

      if (widget.userRole == 'teacher' && widget.teacherId != null) {
        // معلم: فقط طلابه
        data = await DatabaseHelper.getAllStudentsForTeacher(widget.teacherId!);
      } else {
        // مدير: كل الطلاب
        data = await DatabaseHelper.getAllStudents();
      }

      setState(() {
        _students = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _deleteStudent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الطالب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DatabaseHelper.deleteStudent(id);
      _loadStudents();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حذف الطالب'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  String _getFullName(Map<String, dynamic> student) {
    final name = student['name'] ?? '';
    final fatherName = student['father_name'] ?? '';
    final familyName = student['father_family_name'] ?? '';
    List<String> parts = [];
    if (name.isNotEmpty) parts.add(name);
    if (fatherName.isNotEmpty) parts.add(fatherName);
    if (familyName.isNotEmpty) parts.add(familyName);
    return parts.join(' ');
  }

  bool _matchesSearch(Map<String, dynamic> student, String query) {
    if (query.isEmpty) return true;
    final fullName = _getFullName(student).toLowerCase();
    final name = (student['name'] ?? '').toLowerCase();
    final fatherName = (student['father_name'] ?? '').toLowerCase();
    final familyName = (student['father_family_name'] ?? '').toLowerCase();
    final q = query.toLowerCase();
    return fullName.contains(q) ||
        name.contains(q) ||
        fatherName.contains(q) ||
        familyName.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _students.where((s) => _matchesSearch(s, _searchQuery)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن طالب (اسم، أب، عائلة)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? const Center(child: Text('لا يوجد طلاب'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final id = student['id'] as int;
                          final fullName = _getFullName(student);
                          final className = student['classes']?['name'] ?? 'بدون صف';
                          final photoUrl = student['photo_url'];
                          final phone = student['phone'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl) as ImageProvider
                                    : null,
                                child: photoUrl == null
                                    ? Text(
                                        fullName.isNotEmpty ? fullName[0] : 'ط',
                                        style: TextStyle(color: AppColors.primary),
                                      )
                                    : null,
                              ),
                              title: Text(
                                fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الصف: $className'),
                                  if (phone.isNotEmpty) Text('الهاتف: $phone'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddStudentScreen(studentData: student),
                                        ),
                                      ).then((_) => _loadStudents());
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: AppColors.danger),
                                    onPressed: () => _deleteStudent(id),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StudentProfileScreen(studentId: id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: (widget.userRole == 'admin')
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddStudentScreen()),
                ).then((_) => _loadStudents());
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}