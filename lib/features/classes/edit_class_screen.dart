import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class EditClassScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  const EditClassScreen({super.key, required this.classData});

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeLevelController = TextEditingController();
  final _capacityController = TextEditingController();
  final _academicYearController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.classData['name'] ?? '';
    _gradeLevelController.text = widget.classData['grade_level']?.toString() ?? '';
    _capacityController.text = widget.classData['capacity']?.toString() ?? '';
    _academicYearController.text = widget.classData['academic_year'] ?? '';
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'grade_level': int.tryParse(_gradeLevelController.text.trim()),
        'capacity': int.tryParse(_capacityController.text.trim()),
        'academic_year': _academicYearController.text.trim(),
      };
      await DatabaseHelper.updateClass(widget.classData['id'], data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التعديل بنجاح'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeLevelController.dispose();
    _capacityController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الصف')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الصف'),
                validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gradeLevelController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المستوى الدراسي (رقم)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  if (int.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعة (اختياري)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _academicYearController,
                decoration: const InputDecoration(labelText: 'العام الدراسي'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _update,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تحديث', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}