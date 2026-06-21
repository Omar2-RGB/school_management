import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class GradesScreen extends StatefulWidget {
  final String? userRole;
  final int? teacherId;

  const GradesScreen({super.key, this.userRole, this.teacherId});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _sections = [];
  Map<int, Map<String, double>> _gradesMap = {};
  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  int _selectedTerm = 1;
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
      List<Map<String, dynamic>> subjects;

      if (widget.userRole == 'teacher' && widget.teacherId != null) {
        final teacherSubjects = await DatabaseHelper.getTeacherSubjects(widget.teacherId!);
        final classIds = teacherSubjects.map((s) => s['class_id'] as int).toSet().toList();
        final subjectIds = teacherSubjects.map((s) => s['subject_id'] as int).toSet().toList();

        final allClasses = await DatabaseHelper.getAllClasses();
        classes = allClasses.where((c) => classIds.contains(c['id'])).toList();

        final allSubjects = await DatabaseHelper.getAllSubjects();
        subjects = allSubjects.where((s) => subjectIds.contains(s['id'])).toList();
      } else {
        classes = await DatabaseHelper.getAllClasses();
        subjects = await DatabaseHelper.getAllSubjects();
      }

      setState(() {
        _classes = classes;
        _subjects = subjects;
        if (classes.isNotEmpty && _selectedClassId == null) {
          _selectedClassId = classes.first['id'];
        }
        if (subjects.isNotEmpty && _selectedSubjectId == null) {
          _selectedSubjectId = subjects.first['id'];
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

      if (_selectedSectionId != null) {
        filteredStudents = filteredStudents.where((s) => s['section_id'] == _selectedSectionId).toList();
      }

      setState(() {
        _students = filteredStudents;
        _loadExistingGrades();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الطلاب: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _loadExistingGrades() async {
    try {
      for (var student in _students) {
        final grades = await DatabaseHelper.getGradesByStudent(student['id']);
        _gradesMap[student['id']] = {};
        for (var g in grades) {
          if (g['subject_id'] == _selectedSubjectId && g['term'] == _selectedTerm) {
            _gradesMap[student['id']]![g['exam_type']] = g['score'] as double;
          }
        }
      }
      setState(() {});
    } catch (e) {
      // تجاهل
    }
  }

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);

    try {
      for (var student in _students) {
        final grades = _gradesMap[student['id']] ?? {};
        for (var entry in grades.entries) {
          final examType = entry.key;
          final score = entry.value;

          final existing = await DatabaseHelper.getGradesByStudent(student['id']);
          final existingGrade = existing.firstWhere(
            (g) => g['subject_id'] == _selectedSubjectId &&
                   g['term'] == _selectedTerm &&
                   g['exam_type'] == examType,
            orElse: () => {},
          );

          if (existingGrade.isNotEmpty) {
            await DatabaseHelper.updateGrade(existingGrade['id'], {
              'score': score,
              'max_score': 100,
            });
          } else {
            await DatabaseHelper.addGrade({
              'student_id': student['id'],
              'subject_id': _selectedSubjectId,
              'class_id': _selectedClassId,
              'term': _selectedTerm,
              'exam_type': examType,
              'score': score,
              'max_score': 100,
              'date': DateTime.now().toIso8601String().split('T').first,
            });
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ الدرجات بنجاح'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرجات'),
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
                        child: DropdownButtonFormField<int>(
                          value: _selectedSubjectId,
                          decoration: const InputDecoration(
                            labelText: 'المادة',
                            border: OutlineInputBorder(),
                          ),
                          items: _subjects.map((sub) {
                            return DropdownMenuItem<int>(
                              value: sub['id'],
                              child: Text(sub['name']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedSubjectId = val);
                            _loadExistingGrades();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _selectedTerm,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('الفصل 1')),
                          DropdownMenuItem(value: 2, child: Text('الفصل 2')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedTerm = val!);
                          _loadExistingGrades();
                        },
                      ),
                    ],
                  ),
                ),
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
                            final grades = _gradesMap[id] ?? {};

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildGradeField(
                                            studentId: id,
                                            label: 'اختبار 1',
                                            examType: 'exam1',
                                            value: grades['exam1'],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildGradeField(
                                            studentId: id,
                                            label: 'اختبار 2',
                                            examType: 'exam2',
                                            value: grades['exam2'],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildGradeField(
                                            studentId: id,
                                            label: 'نهائي',
                                            examType: 'final',
                                            value: grades['final'],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildGradeField(
                                            studentId: id,
                                            label: 'واجب',
                                            examType: 'assignment',
                                            value: grades['assignment'],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'المجموع: ${grades.values.fold(0.0, (sum, v) => sum + (v ?? 0.0))}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                      onPressed: _isSaving ? null : _saveGrades,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('حفظ الدرجات', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGradeField({
    required int studentId,
    required String label,
    required String examType,
    double? value,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        TextFormField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          onChanged: (val) {
            final doubleVal = double.tryParse(val);
            if (doubleVal != null && doubleVal >= 0 && doubleVal <= 100) {
              setState(() {
                if (_gradesMap[studentId] == null) {
                  _gradesMap[studentId] = {};
                }
                _gradesMap[studentId]![examType] = doubleVal;
              });
            }
          },
        ),
      ],
    );
  }
}