import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class AddStudentScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;

  const AddStudentScreen({super.key, this.studentData});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _fatherFamilyNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentCodeController = TextEditingController(); // ✅ رمز ولي الأمر (PIN)

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  int? _selectedClassId;
  int? _selectedSectionId;
  DateTime? _birthDate;
  XFile? _selectedImage;
  bool _isLoading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (widget.studentData != null) {
      _nameController.text = widget.studentData!['name'] ?? '';
      _studentIdController.text = widget.studentData!['student_id'] ?? '';
      _fatherNameController.text = widget.studentData!['father_name'] ?? '';
      _fatherFamilyNameController.text = widget.studentData!['father_family_name'] ?? '';
      _motherNameController.text = widget.studentData!['mother_name'] ?? '';
      _phoneController.text = widget.studentData!['phone'] ?? '';
      _parentPhoneController.text = widget.studentData!['parent_phone'] ?? '';
      _addressController.text = widget.studentData!['address'] ?? '';
      _parentCodeController.text = widget.studentData!['parent_code'] ?? ''; // ✅
      _selectedClassId = widget.studentData!['class_id'];
      _selectedSectionId = widget.studentData!['section_id'];
      _imageUrl = widget.studentData!['photo_url'];
      if (widget.studentData!['birth_date'] != null) {
        _birthDate = DateTime.parse(widget.studentData!['birth_date']);
        _birthDateController.text = _formatDate(_birthDate!);
      }
      if (_selectedClassId != null) {
        _loadSections(_selectedClassId!);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadClasses() async {
    try {
      final data = await DatabaseHelper.getAllClasses();
      if (mounted) setState(() => _classes = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الصفوف: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _loadSections(int classId) async {
    try {
      final data = await DatabaseHelper.getSectionsByClass(classId);
      if (mounted) {
        setState(() {
          _sections = data;
          if (_selectedSectionId != null &&
              !_sections.any((s) => s['id'] == _selectedSectionId)) {
            _selectedSectionId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الشعب: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (mounted) setState(() => _selectedImage = pickedFile);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      if (mounted) {
        setState(() {
          _birthDate = date;
          _birthDateController.text = _formatDate(date);
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصف'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? photoUrl = _imageUrl;

      if (_selectedImage != null) {
        photoUrl = await DatabaseHelper.uploadStudentPhoto(_selectedImage!);
      }

      final data = {
        'name': _nameController.text.trim(),
        'student_id': _studentIdController.text.trim(),
        'father_name': _fatherNameController.text.trim(),
        'father_family_name': _fatherFamilyNameController.text.trim(),
        'mother_name': _motherNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'parent_phone': _parentPhoneController.text.trim(),
        'birth_date': _birthDate?.toIso8601String().split('T').first,
        'address': _addressController.text.trim(),
        'class_id': _selectedClassId,
        'section_id': _selectedSectionId,
        'photo_url': photoUrl,
        'parent_code': _parentCodeController.text.trim().toUpperCase(), // ✅
        'status': 'active',
        'enrollment_date': DateTime.now().toIso8601String().split('T').first,
      };

      if (widget.studentData != null) {
        await DatabaseHelper.updateStudent(widget.studentData!['id'], data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم تعديل الطالب بنجاح'), backgroundColor: AppColors.success),
          );
        }
      } else {
        await DatabaseHelper.addStudent(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إضافة الطالب بنجاح'), backgroundColor: AppColors.success),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _fatherNameController.dispose();
    _fatherFamilyNameController.dispose();
    _motherNameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _parentCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentData != null ? 'تعديل طالب' : 'إضافة طالب جديد'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // صورة الطالب
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.cardColor,
                        backgroundImage: _selectedImage != null
                            ? NetworkImage(_selectedImage!.path) as ImageProvider
                            : (_imageUrl != null ? NetworkImage(_imageUrl!) as ImageProvider : null),
                        child: (_selectedImage == null && _imageUrl == null)
                            ? Icon(Icons.camera_alt, size: 40, color: AppColors.textMuted)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _pickImage,
                      child: Text(_imageUrl != null ? 'تغيير الصورة' : 'إضافة صورة'),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _studentIdController,
                      decoration: const InputDecoration(
                        labelText: 'الرقم المدرسي (ID)',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                        hintText: 'مثال: 2024-001',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),

                    // ✅ حقل رمز ولي الأمر (PIN)
                    TextFormField(
                      controller: _parentCodeController,
                      decoration: const InputDecoration(
                        labelText: '🔑 رمز ولي الأمر (PIN)',
                        prefixIcon: Icon(Icons.vpn_key),
                        border: OutlineInputBorder(),
                        hintText: 'مثال: STU-123456',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'مطلوب لربط ولي الأمر';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _fatherNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الأب',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _fatherFamilyNameController,
                      decoration: const InputDecoration(
                        labelText: 'كنية الأب (العائلة)',
                        prefixIcon: Icon(Icons.family_restroom),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _motherNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الأم',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الطالب (جوال)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _parentPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم ولي الأمر',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
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
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                          _selectedSectionId = null;
                          _sections = [];
                        });
                        if (val != null) {
                          _loadSections(val);
                        }
                      },
                      validator: (v) => v == null ? 'اختر الصف' : null,
                    ),
                    const SizedBox(height: 16),

                    if (_sections.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        value: _selectedSectionId,
                        decoration: const InputDecoration(
                          labelText: 'الشعبة',
                          prefixIcon: Icon(Icons.group),
                          border: OutlineInputBorder(),
                        ),
                        items: _sections.map((s) {
                          return DropdownMenuItem<int>(
                            value: s['id'],
                            child: Text('شعبة ${s['name']}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedSectionId = val),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _birthDateController,
                      decoration: InputDecoration(
                        labelText: 'تاريخ الميلاد',
                        prefixIcon: const Icon(Icons.cake),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectDate,
                        ),
                      ),
                      readOnly: true,
                      onTap: _selectDate,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        prefixIcon: Icon(Icons.home),
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
                        widget.studentData != null ? 'تعديل الطالب' : 'إضافة الطالب',
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