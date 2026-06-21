import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class AddSectionScreen extends StatefulWidget {
  final Map<String, dynamic>? sectionData;

  const AddSectionScreen({super.key, this.sectionData});

  @override
  State<AddSectionScreen> createState() => _AddSectionScreenState();
}

class _AddSectionScreenState extends State<AddSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teachers = [];
  int? _selectedClassId;
  int? _selectedTeacherId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.sectionData != null) {
      _nameController.text = widget.sectionData!['name'] ?? '';
      _capacityController.text = (widget.sectionData!['capacity'] ?? '').toString();
      _selectedClassId = widget.sectionData!['class_id'];
      _selectedTeacherId = widget.sectionData!['teacher_id'];
    }
  }

  Future<void> _loadData() async {
    try {
      final classes = await DatabaseHelper.getAllClasses();
      final teachers = await DatabaseHelper.getAllTeachers();
      setState(() {
        _classes = classes;
        _teachers = teachers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الصف'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'class_id': _selectedClassId,
        'teacher_id': _selectedTeacherId,
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
      };

      if (widget.sectionData != null) {
        await DatabaseHelper.updateSection(widget.sectionData!['id'], data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تعديل الشعبة'), backgroundColor: AppColors.success),
        );
      } else {
        await DatabaseHelper.addSection(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إضافة الشعبة'), backgroundColor: AppColors.success),
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
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sectionData != null ? 'تعديل شعبة' : 'إضافة شعبة جديدة'),
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
                        labelText: 'اسم الشعبة',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                        hintText: 'مثال: أ, ب, ج',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'الصف',
                        prefixIcon: Icon(Icons.class_),
                        border: OutlineInputBorder(),
                      ),
                      items: _classes.map((cls) {
                        return DropdownMenuItem<int>(
                          value: cls['id'],
                          child: Text(cls['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedClassId = val),
                      validator: (v) => v == null ? 'اختر الصف' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'المعلم المشرف',
                        prefixIcon: Icon(Icons.person),
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
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعة',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        widget.sectionData != null ? 'تعديل الشعبة' : 'إضافة الشعبة',
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