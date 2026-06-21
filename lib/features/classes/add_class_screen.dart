import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class AddClassScreen extends StatefulWidget {
  final Map<String, dynamic>? classData; // للتعديل

  const AddClassScreen({super.key, this.classData});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeLevelController = TextEditingController();
  final _academicYearController = TextEditingController();
  final _capacityController = TextEditingController();
  int? _selectedTeacherId;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    // إذا كان تعديلاً، نملأ الحقول
    if (widget.classData != null) {
      _nameController.text = widget.classData!['name'] ?? '';
      _gradeLevelController.text = (widget.classData!['grade_level'] ?? '').toString();
      _academicYearController.text = widget.classData!['academic_year'] ?? '';
      _capacityController.text = (widget.classData!['capacity'] ?? '').toString();
      _selectedTeacherId = widget.classData!['teacher_id'];
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await DatabaseHelper.getAllTeachers();
      setState(() => _teachers = teachers);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المعلمين: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'grade_level': int.tryParse(_gradeLevelController.text.trim()) ?? 0,
        'academic_year': _academicYearController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
        'teacher_id': _selectedTeacherId,
      };

      if (widget.classData != null) {
        // تعديل
        await DatabaseHelper.updateClass(widget.classData!['id'], data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تعديل الصف بنجاح'), backgroundColor: AppColors.success),
        );
      } else {
        // إضافة
        await DatabaseHelper.addClass(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إضافة الصف بنجاح'), backgroundColor: AppColors.success),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeLevelController.dispose();
    _academicYearController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData != null ? 'تعديل صف' : 'إضافة صف جديد'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصف',
                        prefixIcon: Icon(Icons.class_),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gradeLevelController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المرحلة (رقم)',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _academicYearController,
                      decoration: const InputDecoration(
                        labelText: 'السنة الدراسية',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                        hintText: 'مثال: 2024-2025',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعة',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'المعلم المشرف',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      items: _teachers.map((teacher) {
                        return DropdownMenuItem<int>(
                          value: teacher['id'],
                          child: Text(teacher['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedTeacherId = val),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        widget.classData != null ? 'تعديل الصف' : 'إضافة الصف',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}