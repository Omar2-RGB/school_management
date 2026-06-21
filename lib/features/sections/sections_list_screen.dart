import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import 'add_section_screen.dart';

class SectionsListScreen extends StatefulWidget {
  final int? classId; // إذا تم تمرير classId، نعرض شعب هذا الصف فقط

  const SectionsListScreen({super.key, this.classId});

  @override
  State<SectionsListScreen> createState() => _SectionsListScreenState();
}

class _SectionsListScreenState extends State<SectionsListScreen> {
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _classes = [];
  int? _selectedClassId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.classId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // جلب الصفوف (للفلتر)
      final classes = await DatabaseHelper.getAllClasses();
      setState(() => _classes = classes);

      // إذا لم يتم تحديد صف، نختار أول صف
      if (_selectedClassId == null && classes.isNotEmpty) {
        _selectedClassId = classes.first['id'];
      }

      // جلب الشعب
      await _loadSections();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _loadSections() async {
    if (_selectedClassId == null) {
      setState(() {
        _sections = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final sections = await DatabaseHelper.getSectionsByClass(_selectedClassId!);
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الشعب: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _deleteSection(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الشعبة؟'),
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
      await DatabaseHelper.deleteSection(id);
      _loadSections();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حذف الشعبة'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشعب / الأقسام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // فلتر الصف
                if (widget.classId == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<int>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'اختر الصف',
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
                          _isLoading = true;
                        });
                        _loadSections();
                      },
                    ),
                  ),
                Expanded(
                  child: _sections.isEmpty
                      ? Center(
                          child: Text(
                            _selectedClassId == null
                                ? 'اختر صفاً لعرض شعبها'
                                : 'لا توجد شعب لهذا الصف',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sections.length,
                          itemBuilder: (context, index) {
                            final section = _sections[index];
                            final id = section['id'] as int;
                            final name = section['name'] ?? 'بدون اسم';
                            final className = section['classes']?['name'] ?? 'بدون صف';
                            final teacherName = section['teachers']?['name'] ?? 'غير معين';
                            final capacity = section['capacity'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Text(
                                    name.isNotEmpty ? name : 'ش',
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ),
                                title: Text('شعبة $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الصف: $className'),
                                    Text('المعلم: $teacherName'),
                                    Text('السعة: $capacity'),
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
                                            builder: (context) => AddSectionScreen(sectionData: section),
                                          ),
                                        ).then((_) => _loadSections());
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppColors.danger),
                                      onPressed: () => _deleteSection(id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: widget.classId == null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddSectionScreen()),
                ).then((_) => _loadData());
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}