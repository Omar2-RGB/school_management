import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart'; // ✅ أضفناه لدعم ألوان الـ PDF في SchoolInfo
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import '../../services/pdf_service.dart';

class StudentProfileScreen extends StatefulWidget {
  final int studentId;

  const StudentProfileScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. جلب بيانات الطالب
      final allStudents = await DatabaseHelper.getAllStudents();
      final student = allStudents.firstWhere(
        (s) => s['id'] == widget.studentId,
        orElse: () => <String, dynamic>{},
      );

      if (student.isEmpty) {
        throw Exception('الطالب غير موجود');
      }

      // 2. جلب الدرجات
      final grades = await DatabaseHelper.getGradesByStudent(widget.studentId);

      // 3. جلب الحضور (آخر 30 يوماً)
      final today = DateTime.now();
      final allAttendance = await DatabaseHelper.getAttendanceByDate(
        today.toIso8601String().split('T').first,
      );
      final attendance = allAttendance.where((a) => a['student_id'] == widget.studentId).toList();

      // 4. جلب المدفوعات
      final payments = await DatabaseHelper.getPaymentsByStudent(widget.studentId);

      setState(() {
        _student = student;
        _grades = grades;
        _attendance = attendance;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  // حساب إجمالي الدرجات
  double _getTotalScore() {
    double total = 0;
    for (var grade in _grades) {
      total += (grade['score'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  // حساب نسبة الحضور
  double _getAttendancePercentage() {
    if (_attendance.isEmpty) return 0;
    final present = _attendance.where((a) => a['status'] == 'present').length;
    return (present / _attendance.length) * 100;
  }

  // حساب إجمالي المدفوعات
  double _getTotalPayments() {
    double total = 0;
    for (var payment in _payments) {
      total += (payment['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  // 💡 دالة ذكية لتوليد كائن المدرسة ديناميكياً للطباعة
  SchoolInfo _getCurrentSchoolInfo() {
    return SchoolInfo(
      name: _student?['school_name'] ?? 'مدرسة آفاق العلم النموذجية',
      address: _student?['address'] ?? 'الإدارة العامة',
      phone: '0790000000',
      primaryColor: PdfColors.blue800, // لون رسمي رزين
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف الطالب'),
        actions: [
          // ✅ زر طباعة كشف الدرجات
          IconButton(
            icon: const Icon(Icons.grade),
            onPressed: () async {
              if (_student != null && _grades.isNotEmpty) {
                await PdfService.printStudentGradesReport(
                  school: _getCurrentSchoolInfo(), // 💡 حقن الكائن هنا
                  studentName: _student!['name'] ?? 'بدون اسم',
                  className: _student!['classes']?['name'] ?? 'بدون صف',
                  schoolId: _student!['school_id']?.toString() ?? '',
                  grades: _grades,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد درجات لطباعتها')),
                );
              }
            },
            tooltip: 'طباعة كشف الدرجات',
          ),
          // ✅ زر طباعة تقرير الحضور
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: () async {
              if (_student != null && _attendance.isNotEmpty) {
                await PdfService.printStudentAttendanceReport(
                  school: _getCurrentSchoolInfo(), // 💡 وحقن الكائن هنا
                  studentName: _student!['name'] ?? 'بدون اسم',
                  className: _student!['classes']?['name'] ?? 'بدون صف',
                  attendance: _attendance,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد سجلات حضور لطباعتها')),
                );
              }
            },
            tooltip: 'طباعة تقرير الحضور',
          ),
          // ✅ زر طباعة كشف المدفوعات
          IconButton(
            icon: const Icon(Icons.money),
            onPressed: () async {
              if (_student != null && _payments.isNotEmpty) {
                await PdfService.printStudentPaymentsReport(
                  school: _getCurrentSchoolInfo(), // 💡 وحقن الكائن هنا
                  studentName: _student!['name'] ?? 'بدون اسم',
                  className: _student!['classes']?['name'] ?? 'بدون صف',
                  payments: _payments,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد مدفوعات لطباعتها')),
                );
              }
            },
            tooltip: 'طباعة كشف المدفوعات',
          ),
          // ✅ زر التحديث
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudentData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStudentData,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildQuickStats(),
                      const SizedBox(height: 16),
                      _buildGradesSection(),
                      const SizedBox(height: 16),
                      _buildAttendanceSection(),
                      const SizedBox(height: 16),
                      _buildPaymentsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final student = _student!;
    final className = student['classes']?['name'] ?? 'بدون صف';
    final photoUrl = student['photo_url'];
    final name = student['name'] ?? 'بدون اسم';
    final fatherName = student['father_name'] ?? '';
    final familyName = student['father_family_name'] ?? '';
    final schoolId = student['school_id']?.toString() ?? '';
    final phone = student['phone'] ?? '';
    final parentPhone = student['parent_phone'] ?? '';
    final birthDate = student['birth_date'] ?? '';
    final address = student['address'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderWhite),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1), // 💡 التحديث القياسي
            backgroundImage: photoUrl != null
                ? NetworkImage(photoUrl) as ImageProvider
                : null,
            child: photoUrl == null
                ? const Text(
                    'ط',
                    style: TextStyle(fontSize: 30, color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (fatherName.isNotEmpty || familyName.isNotEmpty)
                  Text(
                    '$fatherName $familyName'.trim(),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.class_, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('الصف: $className'),
                    const SizedBox(width: 16),
                    const Icon(Icons.numbers, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('الرقم المدرسي: ${schoolId.isNotEmpty ? schoolId : 'غير محدد'}'),
                  ],
                ),
                const SizedBox(height: 4),
                if (phone.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('جوال: $phone'),
                    ],
                  ),
                if (parentPhone.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone_android, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('ولي الأمر: $parentPhone'),
                    ],
                  ),
                if (birthDate.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.cake, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('تاريخ الميلاد: $birthDate'),
                    ],
                  ),
                if (address.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.home, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('العنوان: $address'),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'الدرجات',
            value: _grades.length.toString(),
            icon: Icons.grade,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'المجموع',
            value: _getTotalScore().toStringAsFixed(1),
            icon: Icons.calculate,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'الحضور',
            value: '${_getAttendancePercentage().toStringAsFixed(0)}%',
            icon: Icons.check_circle,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            title: 'المدفوعات',
            value: '${_getTotalPayments().toStringAsFixed(0)} د.أ',
            icon: Icons.money,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderWhite),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildGradesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📚 الدرجات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_grades.isEmpty)
            const Center(child: Text('لا توجد درجات مسجلة'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _grades.length,
              itemBuilder: (context, index) {
                final grade = _grades[index];
                final subject = grade['subjects'] as Map<String, dynamic>?;
                final subjectName = subject?['name'] ?? 'بدون مادة';
                final score = (grade['score'] as num?)?.toDouble() ?? 0.0;
                final examType = grade['exam_type'] ?? '';
                final term = grade['term'] ?? 1;

                final examTypeNames = {
                  'exam1': 'اختبار 1',
                  'exam2': 'اختبار 2',
                  'final': 'نهائي',
                  'assignment': 'واجب',
                };

                return ListTile(
                  title: Text(subjectName),
                  subtitle: Text('${examTypeNames[examType] ?? examType} - الفصل $term'),
                  trailing: Text(
                    score.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: score >= 50 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    final statusNames = {
      'present': 'حاضر',
      'absent': 'غائب',
      'late': 'متأخر',
      'excused': 'معذور',
    };
    final statusColors = {
      'present': Colors.green,
      'absent': AppColors.danger,
      'late': Colors.orange,
      'excused': Colors.blue,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 الحضور والغياب (آخر 30 يوم)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_attendance.isEmpty)
            const Center(child: Text('لا توجد سجلات حضور'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendance.length > 10 ? 10 : _attendance.length,
              itemBuilder: (context, index) {
                final item = _attendance[index];
                final date = item['date'] ?? '';
                final status = item['status'] ?? '';
                final statusName = statusNames[status] ?? status.toString();
                final statusColor = statusColors[status] ?? Colors.grey;

                return ListTile(
                  title: Text(date),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1), // 💡 التحديث القياسي
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusName,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection() {
    final feeTypeNames = {
      'registration': 'تسجيل',
      'monthly': 'شهري',
      'activity': 'نشاط',
      'uniform': 'زي مدرسي',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 المدفوعات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            const Center(child: Text('لا توجد مدفوعات'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _payments.length,
              itemBuilder: (context, index) {
                final payment = _payments[index];
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
                final feeType = payment['fee_type'] ?? '';
                final date = payment['date'] ?? '';
                final note = payment['note'] ?? '';

                return ListTile(
                  title: Text('${amount.toStringAsFixed(2)} د.أ'),
                  subtitle: Text('${feeTypeNames[feeType] ?? feeType} - $date'),
                  trailing: note.isNotEmpty ? Text(note, style: const TextStyle(fontSize: 10)) : null,
                );
              },
            ),
        ],
      ),
    );
  }
}