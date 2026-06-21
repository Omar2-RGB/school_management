import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class AttendanceScreen extends StatefulWidget {
  final String? userRole;
  final int? teacherId;

  const AttendanceScreen({super.key, this.userRole, this.teacherId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _attendance = [];
  Map<int, String> _statusMap = {};
  DateTime _selectedDate = DateTime.now();
  int? _selectedClassId;
  int? _selectedSectionId;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> classes;

      if (widget.userRole == 'teacher' && widget.teacherId != null) {
        final subjects = await DatabaseHelper.getTeacherSubjects(widget.teacherId!);
        final classIds = subjects.map((s) => s['class_id'] as int).toSet().toList();
        final allClasses = await DatabaseHelper.getAllClasses();
        classes = allClasses.where((c) => classIds.contains(c['id'])).toList();
      } else {
        classes = await DatabaseHelper.getAllClasses();
      }

      setState(() {
        _classes = classes;
        if (classes.isNotEmpty && _selectedClassId == null) {
          _selectedClassId = classes.first['id'];
        }
        _isLoading = false;
      });

      if (_selectedClassId != null) {
        await _loadSections(_selectedClassId!);
        await _loadStudents();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _loadSections(int classId) async {
    try {
      final sections = await DatabaseHelper.getSectionsByClass(classId);
      setState(() {
        _sections = sections;
        if (sections.isNotEmpty && _selectedSectionId == null) {
          _selectedSectionId = sections.first['id'];
        } else if (sections.isEmpty) {
          _selectedSectionId = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الشعب: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;

    try {
      List<Map<String, dynamic>> filteredStudents;

      if (widget.userRole == 'teacher' && widget.teacherId != null) {
        filteredStudents = await DatabaseHelper.getStudentsForTeacherByClass(
          widget.teacherId!,
          _selectedClassId!,
        );
      } else {
        final allStudents = await DatabaseHelper.getAllStudents();
        filteredStudents = allStudents.where((s) => s['class_id'] == _selectedClassId).toList();
      }

      // تصفية حسب الشعبة إذا تم اختيارها
      if (_selectedSectionId != null) {
        filteredStudents = filteredStudents.where((s) => s['section_id'] == _selectedSectionId).toList();
      }

      setState(() => _students = filteredStudents);

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendance = await DatabaseHelper.getAttendanceByDate(dateStr);
      setState(() {
        _attendance = attendance;
        _statusMap = {};
        for (var student in _students) {
          final existing = attendance.firstWhere(
            (a) => a['student_id'] == student['id'],
            orElse: () => {},
          );
          _statusMap[student['id']] = existing.isNotEmpty ? existing['status'] : 'present';
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الطلاب: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر صفاً أولاً'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      for (var student in _students) {
        final existing = _attendance.firstWhere(
          (a) => a['student_id'] == student['id'],
          orElse: () => {},
        );
        if (existing.isNotEmpty) {
          await DatabaseHelper.deleteAttendance(existing['id']);
        }
      }

      for (var student in _students) {
        final status = _statusMap[student['id']] ?? 'present';
        await DatabaseHelper.addAttendance({
          'student_id': student['id'],
          'class_id': _selectedClassId,
          'date': dateStr,
          'status': status,
          'note': '',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ الحضور بنجاح'), backgroundColor: AppColors.success),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _setAllStatus(String status) {
    setState(() {
      for (var student in _students) {
        _statusMap[student['id']] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور والغياب'),
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
                  child: Row(
                    children: [
                      Expanded(
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
                          onChanged: (val) {
                            setState(() {
                              _selectedClassId = val;
                              _selectedSectionId = null;
                              _sections = [];
                            });
                            if (val != null) {
                              _loadSections(val);
                              _loadStudents();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_sections.isNotEmpty)
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedSectionId,
                            decoration: const InputDecoration(
                              labelText: 'الشعبة',
                              border: OutlineInputBorder(),
                            ),
                            items: _sections.map((s) {
                              return DropdownMenuItem<int>(
                                value: s['id'],
                                child: Text('شعبة ${s['name']}'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedSectionId = val);
                              _loadStudents();
                            },
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _selectedDate = date);
                              _loadStudents();
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'التاريخ',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildStatusButton('كلهم حاضرين', 'present', Colors.green),
                      const SizedBox(width: 8),
                      _buildStatusButton('كلهم غائبين', 'absent', Colors.red),
                      const SizedBox(width: 8),
                      _buildStatusButton('كلهم متأخرين', 'late', Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _students.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب في هذا الصف'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            final id = student['id'] as int;
                            final name = student['name'] ?? 'بدون اسم';
                            final currentStatus = _statusMap[id] ?? 'present';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(name.isNotEmpty ? name[0] : 'ط'),
                                ),
                                title: Text(name),
                                trailing: DropdownButton<String>(
                                  value: currentStatus,
                                  items: const [
                                    DropdownMenuItem(value: 'present', child: Text('حاضر', style: TextStyle(color: Colors.green))),
                                    DropdownMenuItem(value: 'absent', child: Text('غائب', style: TextStyle(color: Colors.red))),
                                    DropdownMenuItem(value: 'late', child: Text('متأخر', style: TextStyle(color: Colors.orange))),
                                    DropdownMenuItem(value: 'excused', child: Text('معذور', style: TextStyle(color: Colors.blue))),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      if (val != null) _statusMap[id] = val;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('حفظ الحضور', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusButton(String label, String status, Color color) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _setAllStatus(status),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}