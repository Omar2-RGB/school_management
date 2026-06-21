import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() => _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  int? _selectedClassId;

  final List<String> _days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final List<int> _periods = [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final classes = await DatabaseHelper.getAllClasses();
      final schedules = await DatabaseHelper.getAllSchedules();

      setState(() {
        _classes = classes;
        _schedules = schedules;
        if (classes.isNotEmpty) _selectedClassId = classes.first['id'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _addSchedule() async {
    // جلب المعلمين والمواد عند فتح الحوار
    final teachers = await DatabaseHelper.getAllTeachers();
    final subjects = await DatabaseHelper.getAllSubjects();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddScheduleDialog(
        classes: _classes,
        teachers: teachers,
        subjects: subjects,
        days: _days,
        periods: _periods,
      ),
    );

    if (result != null) {
      try {
        await DatabaseHelper.addSchedule(result);
        if (mounted) {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إضافة الحصة'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Future<void> _deleteSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الحصة؟'),
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
      await DatabaseHelper.deleteSchedule(id);
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حذف الحصة'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSchedules = _selectedClassId != null
        ? _schedules.where((s) => s['class_id'] == _selectedClassId).toList()
        : _schedules;

    // إنشاء مصفوفة 5x8 للجدول
    List<List<Map<String, dynamic>?>> grid =
        List.generate(5, (i) => List.filled(8, null));

    for (var s in filteredSchedules) {
      final day = s['day_of_week'] as int;
      final period = (s['period'] as int) - 1;
      if (day >= 0 && day < 5 && period >= 0 && period < 8) {
        grid[day][period] = s;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الحصص'),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'الصف',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes.map((cls) {
                      return DropdownMenuItem<int>(
                        value: cls['id'],
                        child: Text(cls['name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedClassId = val),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Table(
                          border: TableBorder.all(color: AppColors.borderWhite),
                          columnWidths: const {
                            0: FixedColumnWidth(80),
                          },
                          children: [
                            // ✅ رأس الجدول
                            TableRow(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'الفترة',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                ..._days.map((day) => Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    day,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                )),
                              ],
                            ),
                            // ✅ صفوف الفترات
                            for (int p = 0; p < 8; p++) ...[
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'ف${p + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  ...List.generate(5, (day) {
                                    final schedule = grid[day][p];
                                    if (schedule != null) {
                                      final subjectName = schedule['subjects']?['name'] ?? 'بدون';
                                      final teacherName = schedule['teachers']?['name'] ?? 'بدون';
                                      return GestureDetector(
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          margin: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                subjectName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                teacherName,
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                textAlign: TextAlign.center,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 16, color: AppColors.danger),
                                                onPressed: () => _deleteSchedule(schedule['id']),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('', textAlign: TextAlign.center),
                                      );
                                    }
                                  }),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ============================================================
// حوار إضافة حصة
// ============================================================
class _AddScheduleDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> subjects;
  final List<String> days;
  final List<int> periods;

  const _AddScheduleDialog({
    required this.classes,
    required this.teachers,
    required this.subjects,
    required this.days,
    required this.periods,
  });

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  int? _selectedClassId;
  int? _selectedTeacherId;
  int? _selectedSubjectId;
  int? _selectedDay;
  int? _selectedPeriod;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة حصة جديدة'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedClassId,
                decoration: const InputDecoration(labelText: 'الصف'),
                items: widget.classes.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'],
                    child: Text(c['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedClassId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedTeacherId,
                decoration: const InputDecoration(labelText: 'المعلم'),
                items: widget.teachers.map((t) {
                  return DropdownMenuItem<int>(
                    value: t['id'],
                    child: Text(t['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedTeacherId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedSubjectId,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: widget.subjects.map((s) {
                  return DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text(s['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubjectId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedDay,
                decoration: const InputDecoration(labelText: 'اليوم'),
                items: widget.days.asMap().entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedDay = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedPeriod,
                decoration: const InputDecoration(labelText: 'الفترة'),
                items: widget.periods.map((p) {
                  return DropdownMenuItem<int>(
                    value: p,
                    child: Text('ف$p'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPeriod = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedClassId == null ||
                _selectedTeacherId == null ||
                _selectedSubjectId == null ||
                _selectedDay == null ||
                _selectedPeriod == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('املأ جميع الحقول'), backgroundColor: Colors.orange),
              );
              return;
            }
            Navigator.pop(context, {
              'class_id': _selectedClassId,
              'teacher_id': _selectedTeacherId,
              'subject_id': _selectedSubjectId,
              'day_of_week': _selectedDay,
              'period': _selectedPeriod,
            });
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}