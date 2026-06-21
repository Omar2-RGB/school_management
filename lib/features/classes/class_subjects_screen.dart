import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class ClassSubjectsScreen extends StatefulWidget {
  final int? classId;
  final String? className;

  const ClassSubjectsScreen({
    super.key,
    this.classId,
    this.className,
  });

  @override
  State<ClassSubjectsScreen> createState() => _ClassSubjectsScreenState();
}

class _ClassSubjectsScreenState extends State<ClassSubjectsScreen> {
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _assignedSubjects = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  int? _selectedTeacherId;
  int? _selectedClassId;
  String? _selectedClassName;

  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _subjectCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.classId;
    _selectedClassName = widget.className;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      if (_selectedClassId == null) {
        final classes = await DatabaseHelper.getAllClasses();
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
        return;
      }

      final assigned = await DatabaseHelper.getClassSubjects(_selectedClassId!);
      final teachers = await DatabaseHelper.getAllTeachers();

      setState(() {
        _assignedSubjects = assigned;
        _teachers = teachers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _selectClass(int id, String name) {
    setState(() {
      _selectedClassId = id;
      _selectedClassName = name;
      _isLoading = true;
    });
    _loadData();
  }

  Future<void> _addNewSubject() async {
    final name = _subjectNameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم المادة'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ حل مشكلة الكود الفارغ
      final code = _subjectCodeController.text.trim();
      final finalCode = code.isEmpty ? null : code;

      // 1. إضافة المادة الجديدة
      final newSubject = await DatabaseHelper.addSubject({
        'name': name,
        'code': finalCode,
      });

      final newSubjectId = newSubject['id'];

      // 2. ربطها بالصف مع المعلم المختار
      await DatabaseHelper.assignSubjectToClass({
        'class_id': _selectedClassId,
        'subject_id': newSubjectId,
        'teacher_id': _selectedTeacherId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إضافة المادة وربطها بالصف'), backgroundColor: AppColors.success),
        );
      }

      // مسح الحقول
      _subjectNameController.clear();
      _subjectCodeController.clear();
      setState(() => _selectedTeacherId = null);

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeSubject(int subjectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من إزالة هذه المادة من الصف؟'),
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
      await DatabaseHelper.removeSubjectFromClass(_selectedClassId!, subjectId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إزالة المادة'), backgroundColor: AppColors.success),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _subjectCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedClassId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('مواد الصفوف'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _classes.isEmpty
                ? const Center(child: Text('لا توجد صفوف'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classes.length,
                    itemBuilder: (context, index) {
                      final classItem = _classes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Icon(Icons.class_, color: AppColors.primary),
                          ),
                          title: Text(
                            classItem['name'] ?? 'بدون اسم',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('اضغط لعرض المواد'),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () {
                            _selectClass(classItem['id'], classItem['name']);
                          },
                        ),
                      );
                    },
                  ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('مواد صف ${_selectedClassName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _selectedClassId = null;
                _selectedClassName = null;
                _isLoading = true;
              });
              _loadData();
            },
            tooltip: 'رجوع لقائمة الصفوف',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ نموذج إضافة مادة جديدة
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderWhite),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '➕ إضافة مادة جديدة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subjectNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المادة *',
                          border: OutlineInputBorder(),
                          hintText: 'مثال: رياضيات',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subjectCodeController,
                        decoration: const InputDecoration(
                          labelText: 'رمز المادة (اختياري)',
                          border: OutlineInputBorder(),
                          hintText: 'مثال: MATH-101',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedTeacherId,
                        decoration: const InputDecoration(
                          labelText: 'المعلم (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('بدون معلم'),
                          ),
                          ..._teachers.map((t) {
                            return DropdownMenuItem<int>(
                              value: t['id'],
                              child: Text(t['name']),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedTeacherId = val),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addNewSubject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'إضافة المادة للصف',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ قائمة المواد المضافة
                Expanded(
                  child: _assignedSubjects.isEmpty
                      ? const Center(child: Text('لا توجد مواد مضافة لهذا الصف'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _assignedSubjects.length,
                          itemBuilder: (context, index) {
                            final item = _assignedSubjects[index];
                            final subject = item['subjects'] as Map<String, dynamic>?;
                            final teacher = item['teachers'] as Map<String, dynamic>?;
                            final subjectName = subject?['name'] ?? 'بدون اسم';
                            final teacherName = teacher?['name'] ?? 'غير محدد';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Text(
                                    subjectName.isNotEmpty ? subjectName[0] : 'م',
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                                title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('المعلم: $teacherName'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.danger),
                                  onPressed: () => _removeSubject(item['subject_id']),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}