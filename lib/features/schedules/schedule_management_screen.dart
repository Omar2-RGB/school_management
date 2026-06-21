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

  @override
  Widget build(BuildContext context) {
    final filteredSchedules = _selectedClassId != null
        ? _schedules.where((s) => s['class_id'] == _selectedClassId).toList()
        : _schedules;

    // ✅ بناء شبكة الجدول
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
                // ✅ فلتر الصف (محسّن)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: _selectedClassId,
                    decoration: InputDecoration(
                      labelText: 'اختر الصف',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.class_),
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
                
                const SizedBox(height: 8),

                // ✅ الجدول المحسن
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderWhite),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // ✅ رأس الجدول (الأيام)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // خلية "الفترة"
                                    Container(
                                      width: 60,
                                      padding: const EdgeInsets.all(12),
                                      child: const Text(
                                        'الفترة',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // الأيام
                                    ..._days.map((day) => Container(
                                      width: 100,
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        day,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              // ✅ صفوف الفترات
                              ...List.generate(8, (periodIndex) {
                                final periodNumber = periodIndex + 1;
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.borderWhite,
                                        width: periodIndex == 7 ? 0 : 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // رقم الفترة
                                      Container(
                                        width: 60,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardColor,
                                          border: Border(
                                            right: BorderSide(
                                              color: AppColors.borderWhite,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'ف$periodNumber',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // خلايا الجدول
                                      ...List.generate(5, (dayIndex) {
                                        final schedule = grid[dayIndex][periodIndex];
                                        return Container(
                                          width: 100,
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: schedule != null
                                                ? AppColors.primary.withValues(alpha: 0.1)
                                                : null,
                                            border: Border(
                                              right: BorderSide(
                                                color: AppColors.borderWhite,
                                              ),
                                            ),
                                          ),
                                          child: schedule != null
                                              ? GestureDetector(
                                                  onTap: () {
                                                    // عرض تفاصيل الحصة
                                                    _showScheduleDetails(schedule);
                                                  },
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        schedule['subjects']?['name'] ?? '',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        schedule['teachers']?['name'] ?? '',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : null,
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
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

  // ✅ عرض تفاصيل الحصة عند الضغط
  void _showScheduleDetails(Map<String, dynamic> schedule) {
    final subject = schedule['subjects']?['name'] ?? 'بدون مادة';
    final teacher = schedule['teachers']?['name'] ?? 'بدون معلم';
    final dayIndex = schedule['day_of_week'] as int;
    final period = schedule['period'] as int;
    final day = _days[dayIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الحصة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📚 المادة: $subject'),
            const SizedBox(height: 8),
            Text('👨‍🏫 المعلم: $teacher'),
            const SizedBox(height: 8),
            Text('📅 اليوم: $day'),
            const SizedBox(height: 8),
            Text('⏰ الفترة: $period'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // ✅ إضافة حصة جديدة
  Future<void> _addSchedule() async {
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
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'الصف',
                  border: OutlineInputBorder(),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'المعلم',
                  border: OutlineInputBorder(),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'المادة',
                  border: OutlineInputBorder(),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'اليوم',
                  border: OutlineInputBorder(),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'الفترة',
                  border: OutlineInputBorder(),
                ),
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