import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _students = [];
  int? _selectedStudentId;
  bool _isLoading = true;
  double _totalPayments = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await DatabaseHelper.getAllStudents();
      setState(() => _students = students);

      if (students.isNotEmpty) {
        _selectedStudentId = students.first['id'];
        await _loadPayments(students.first['id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPayments(int studentId) async {
    try {
      final payments = await DatabaseHelper.getPaymentsByStudent(studentId);
      setState(() {
        _payments = payments;
        _totalPayments = payments.fold(0.0, (sum, p) => sum + (p['amount'] as double? ?? 0.0));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _addPayment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddPaymentDialog(students: _students),
    );
    if (result != null) {
      try {
        await DatabaseHelper.addPayment(result);
        if (_selectedStudentId != null) {
          await _loadPayments(_selectedStudentId!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إضافة الدفعة'), backgroundColor: AppColors.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _deletePayment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الدفعة؟'),
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
      await DatabaseHelper.deletePayment(id);
      if (_selectedStudentId != null) {
        await _loadPayments(_selectedStudentId!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حذف الدفعة'), backgroundColor: AppColors.success),
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
        title: const Text('المدفوعات'),
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
                // اختيار الطالب
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: _selectedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'الطالب',
                      border: OutlineInputBorder(),
                    ),
                    items: _students.map((student) {
                      return DropdownMenuItem<int>(
                        value: student['id'],
                        child: Text(student['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedStudentId = val);
                      if (val != null) _loadPayments(val);
                    },
                  ),
                ),

                // إجمالي المدفوعات
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي المدفوعات:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${_totalPayments.toStringAsFixed(2)} د.أ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // قائمة المدفوعات
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(child: Text('لا توجد مدفوعات'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final payment = _payments[index];
                            final id = payment['id'] as int;
                            final amount = payment['amount'] as double? ?? 0.0;
                            final feeType = payment['fee_type'] ?? '';
                            final date = payment['date'] ?? '';
                            final note = payment['note'] ?? '';

                            final feeTypeNames = {
                              'registration': 'تسجيل',
                              'monthly': 'شهري',
                              'activity': 'نشاط',
                              'uniform': 'زي مدرسي',
                            };

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Icon(Icons.money, color: AppColors.primary),
                                ),
                                title: Text('${amount.toStringAsFixed(2)} د.أ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('النوع: ${feeTypeNames[feeType] ?? feeType}'),
                                    Text('التاريخ: $date'),
                                    if (note.isNotEmpty) Text('ملاحظة: $note', style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.danger),
                                  onPressed: () => _deletePayment(id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPayment,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// حوار إضافة دفعة
class _AddPaymentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> students;

  const _AddPaymentDialog({required this.students});

  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedStudentId;
  String _feeType = 'monthly';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.students.isNotEmpty) {
      _selectedStudentId = widget.students.first['id'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة دفعة جديدة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedStudentId,
                decoration: const InputDecoration(labelText: 'الطالب'),
                items: widget.students.map((student) {
                  return DropdownMenuItem<int>(
                    value: student['id'],
                    child: Text(student['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedStudentId = val),
                validator: (v) => v == null ? 'اختر طالباً' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  if (double.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _feeType,
                decoration: const InputDecoration(labelText: 'نوع الدفعة'),
                items: const [
                  DropdownMenuItem(value: 'registration', child: Text('تسجيل')),
                  DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                  DropdownMenuItem(value: 'activity', child: Text('نشاط')),
                  DropdownMenuItem(value: 'uniform', child: Text('زي مدرسي')),
                ],
                onChanged: (val) => setState(() => _feeType = val!),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('التاريخ'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _date = date);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
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
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'student_id': _selectedStudentId,
                'amount': double.parse(_amountController.text.trim()),
                'fee_type': _feeType,
                'date': _date.toIso8601String().split('T').first,
                'note': _noteController.text.trim(),
              });
            }
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}