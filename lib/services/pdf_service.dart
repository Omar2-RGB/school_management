import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static const String _schoolName = 'مدرسة النور';
  static const String _schoolAddress = 'دمشق - سوريا';
  static const String _schoolPhone = '0995339401';

  // ✅ طباعة كشف درجات الطالب
  static Future<void> printStudentGradesReport({
    required String studentName,
    required String className,
    required String schoolId,
    required List<Map<String, dynamic>> grades,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      _schoolName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(_schoolAddress, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(_schoolPhone, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.Text(
                      'كشف الدرجات',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // معلومات الطالب
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('اسم الطالب: $studentName'),
                  pw.Text('الصف: $className'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الرقم المدرسي: ${schoolId.isEmpty ? 'غير محدد' : schoolId}'),
                  pw.Text('التاريخ: ${DateTime.now().toLocal().toString().split(' ')[0]}'),
                ],
              ),
              pw.SizedBox(height: 20),

              // جدول الدرجات
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(2),
                },
                children: [
                  // رأس الجدول
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('المادة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('اختبار1', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('اختبار2', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('نهائي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('المجموع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // صفوف البيانات
                  ...grades.map((grade) {
                    final subject = grade['subjects'] as Map<String, dynamic>?;
                    final subjectName = subject?['name'] ?? 'بدون مادة';
                    final exam1 = grade['score'] as double? ?? 0.0;
                    final exam2 = 0.0; // ستضاف لاحقاً
                    final finalExam = 0.0; // ستضاف لاحقاً
                    final total = exam1 + exam2 + finalExam;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(subjectName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(exam1.toStringAsFixed(1)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(exam2.toStringAsFixed(1)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(finalExam.toStringAsFixed(1)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            total.toStringAsFixed(1),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // تذييل
              pw.Center(
                child: pw.Text(
                  'شكراً لثقتكم بنا',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf);
  }

  // ✅ طباعة تقرير حضور الطالب
  static Future<void> printStudentAttendanceReport({
    required String studentName,
    required String className,
    required List<Map<String, dynamic>> attendance,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          final present = attendance.where((a) => a['status'] == 'present').length;
          final absent = attendance.where((a) => a['status'] == 'absent').length;
          final late = attendance.where((a) => a['status'] == 'late').length;
          final excused = attendance.where((a) => a['status'] == 'excused').length;
          final total = attendance.length;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      _schoolName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(_schoolAddress, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(_schoolPhone, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.Text(
                      'تقرير الحضور والغياب',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // معلومات الطالب
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('اسم الطالب: $studentName'),
                  pw.Text('الصف: $className'),
                ],
              ),
              pw.Text('التاريخ: ${DateTime.now().toLocal().toString().split(' ')[0]}'),
              pw.SizedBox(height: 20),

              // إحصائيات سريعة
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('حاضر', style: pw.TextStyle(color: PdfColors.green)),
                      pw.Text(present.toString(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('غائب', style: pw.TextStyle(color: PdfColors.red)),
                      pw.Text(absent.toString(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('متأخر', style: pw.TextStyle(color: PdfColors.orange)),
                      pw.Text(late.toString(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('معذور', style: pw.TextStyle(color: PdfColors.blue)),
                      pw.Text(excused.toString(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // جدول الحضور التفصيلي
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('التاريخ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('الحالة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...attendance.map((a) {
                    final date = a['date'] ?? '';
                    final status = a['status'] ?? '';
                    final statusNames = {
                      'present': 'حاضر',
                      'absent': 'غائب',
                      'late': 'متأخر',
                      'excused': 'معذور',
                    };
                    final statusColors = {
                      'present': PdfColors.green,
                      'absent': PdfColors.red,
                      'late': PdfColors.orange,
                      'excused': PdfColors.blue,
                    };

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(date),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            statusNames[status] ?? status,
                            style: pw.TextStyle(color: statusColors[status] ?? PdfColors.black),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'شكراً لثقتكم بنا',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf);
  }

  // ✅ طباعة كشف المدفوعات
  static Future<void> printStudentPaymentsReport({
    required String studentName,
    required String className,
    required List<Map<String, dynamic>> payments,
  }) async {
    final pdf = pw.Document();

    final total = payments.fold(0.0, (sum, p) => sum + (p['amount'] as double? ?? 0.0));

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          final feeTypeNames = {
            'registration': 'تسجيل',
            'monthly': 'شهري',
            'activity': 'نشاط',
            'uniform': 'زي مدرسي',
          };

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      _schoolName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(_schoolAddress, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(_schoolPhone, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.Text(
                      'كشف المدفوعات',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('اسم الطالب: $studentName'),
                  pw.Text('الصف: $className'),
                ],
              ),
              pw.Text('التاريخ: ${DateTime.now().toLocal().toString().split(' ')[0]}'),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('التاريخ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('النوع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('المبلغ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('ملاحظة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...payments.map((p) {
                    final date = p['date'] ?? '';
                    final feeType = p['fee_type'] ?? '';
                    final amount = p['amount'] as double? ?? 0.0;
                    final note = p['note'] ?? '';

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(date),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(feeTypeNames[feeType] ?? feeType),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${amount.toStringAsFixed(2)} د.أ'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(note),
                        ),
                      ],
                    );
                  }),
                  // صف المجموع
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('المجموع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Container(),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${total.toStringAsFixed(2)} د.أ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Container(),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'شكراً لثقتكم بنا',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf);
  }

  // ✅ دالة المشاركة
  static Future<void> _sharePdf(pw.Document pdf) async {
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'تقرير_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ✅ طباعة مباشرة (إذا كان الطابعة متصلة)
  static Future<void> printPdf(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}