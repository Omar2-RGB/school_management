import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final int teacherId;

  const TeacherScheduleScreen({super.key, required this.teacherId});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  final List<String> _days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await DatabaseHelper.getSchedulesByTeacher(widget.teacherId);
      setState(() {
        _schedules = schedules;
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

  @override
  Widget build(BuildContext context) {
    List<List<Map<String, dynamic>?>> grid =
        List.generate(5, (i) => List.filled(8, null));

    for (var s in _schedules) {
      final day = s['day_of_week'] as int;
      final period = (s['period'] as int) - 1;
      if (day >= 0 && day < 5 && period >= 0 && period < 8) {
        grid[day][period] = s;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول حصصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? const Center(child: Text('لا توجد حصص مسجلة لك'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Table(
                        border: TableBorder.all(color: AppColors.borderWhite),
                        columnWidths: const {
                          0: FixedColumnWidth(80),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
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
                                    final className = schedule['classes']?['name'] ?? 'بدون';
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            subjectName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            className,
                                            style: const TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
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
    );
  }
}