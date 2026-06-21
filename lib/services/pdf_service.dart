import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// ============================================================
// ✅ 0. كلاس بيانات المدرسة (يُمرر ديناميكياً لكل تقرير)
// ============================================================
class SchoolInfo {
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoPath;      // مسار الشعار في assets (مثال: assets/logo.png)
  final PdfColor primaryColor; // اللون المعتمد لهوية هذه المدرسة بالذات

  const SchoolInfo({
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.logoPath,
    this.primaryColor = PdfColors.blueGrey800, // لون افتراضي كلاسيكي
  });
}

class PdfService {
  // ============================================================
  // ✅ دوال التحميل المركزية (الخطوط + الشعار)
  // ============================================================
  static Future<pw.ThemeData> _getArabicTheme() async {
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();
    return pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicBold,
    );
  }

  static Future<pw.ImageProvider?> _loadLogo(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final ByteData data = await rootBundle.load(path);
      final Uint8List bytes = data.buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('لم يتم العثور على صورة الشعار في المسار: $path');
      return null;
    }
  }

  // ============================================================
  // ✅ 1. فاتورة (للمحاسبة العامة / الإدارة)
  // ============================================================
  static Future<void> printInvoice({
    required SchoolInfo school, // 💡 مرر المدرسة هنا
    required String invoiceNumber,
    required String customerName,
    required String customerPhone,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double grandTotal,
    required String currencySymbol,
    required String status,
    String? note,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logo = await _loadLogo(school.logoPath);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(school, logo, 'فاتورة مالية #$invoiceNumber'),
              pw.SizedBox(height: 20),

              // بطاقة بيانات العميل
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('العميل: $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        if (customerPhone.isNotEmpty) pw.Text('الهاتف: $customerPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(date)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('الحالة: ${_getStatusText(status)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: status == 'paid' ? PdfColors.green700 : PdfColors.red700)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // جدول البنود
              pw.Table(
                border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5), bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  _buildModernTableHeader(['الوصف', 'الكمية', 'السعر', 'المجموع'], school.primaryColor),
                  ...items.asMap().entries.map((entry) => _buildModernTableRow([
                        entry.value['description'] ?? '',
                        (entry.value['quantity'] as double? ?? 0).toString(),
                        (entry.value['unit_price'] as double? ?? 0).toStringAsFixed(2),
                        (entry.value['total'] as double? ?? 0).toStringAsFixed(2),
                      ], entry.key)),
                ],
              ),
              pw.SizedBox(height: 15),

              // الملخص المالي
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: school.primaryColor.withAlpha(15), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('المجموع الفرعي: ${subtotal.toStringAsFixed(2)} $currencySymbol', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('الضريبة: ${tax.toStringAsFixed(2)} $currencySymbol', style: const pw.TextStyle(fontSize: 10)),
                        pw.Divider(color: school.primaryColor.withAlpha(50)),
                        pw.Text('الإجمالي: ${grandTotal.toStringAsFixed(2)} $currencySymbol', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: school.primaryColor)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              if (note != null && note.isNotEmpty) pw.Text('ملاحظات: $note', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.Spacer(),
              _buildModernFooter(school),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'فاتورة_$invoiceNumber');
  }

  // ============================================================
  // ✅ 2. كشف الدرجات الأكاديمي
  // ============================================================
  static Future<void> printStudentGradesReport({
    required SchoolInfo school, // 💡 مرر المدرسة
    required String studentName,
    required String className,
    required String schoolId,
    required List<Map<String, dynamic>> grades,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logo = await _loadLogo(school.logoPath);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(school, logo, 'كشف الدرجات الأكاديمي'),
              pw.SizedBox(height: 20),

              _buildStudentInfoCard(studentName, className, schoolId),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5), bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  _buildModernTableHeader(['المادة', 'الاختبار 1', 'الاختبار 2', 'النهائي', 'المجموع'], school.primaryColor),
                  ...grades.asMap().entries.map((entry) {
                    final grade = entry.value;
                    final subject = grade['subjects'] as Map<String, dynamic>?;
                    final exam1 = grade['score'] as double? ?? 0.0;
                    final total = exam1; // اجمع بقية الاختبارات هنا لاحقاً

                    return _buildModernTableRow([
                      subject?['name'] ?? 'بدون مادة',
                      exam1.toStringAsFixed(1),
                      '0.0',
                      '0.0',
                      total.toStringAsFixed(1),
                    ], entry.key);
                  }),
                ],
              ),
              pw.Spacer(),
              _buildModernFooter(school),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'كشف_درجات_$studentName');
  }

  // ============================================================
  // ✅ 3. تقرير الحضور والغياب
  // ============================================================
  static Future<void> printStudentAttendanceReport({
    required SchoolInfo school, // 💡 مرر المدرسة
    required String studentName,
    required String className,
    required List<Map<String, dynamic>> attendance,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logo = await _loadLogo(school.logoPath);

    final present = attendance.where((a) => a['status'] == 'present').length;
    final absent = attendance.where((a) => a['status'] == 'absent').length;
    final late = attendance.where((a) => a['status'] == 'late').length;
    final excused = attendance.where((a) => a['status'] == 'excused').length;

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(school, logo, 'تقرير الحضور والغياب'),
              pw.SizedBox(height: 20),

              _buildStudentInfoCard(studentName, className, null),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatBox('حاضر', present.toString(), PdfColors.green600),
                  _buildStatBox('غائب', absent.toString(), PdfColors.red600),
                  _buildStatBox('متأخر', late.toString(), PdfColors.orange600),
                  _buildStatBox('معذور', excused.toString(), PdfColors.blue600),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5), bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  _buildModernTableHeader(['التاريخ', 'الحالة'], school.primaryColor),
                  ...attendance.asMap().entries.map((entry) {
                    final statusNames = {'present': 'حاضر', 'absent': 'غائب', 'late': 'متأخر', 'excused': 'معذور'};
                    final st = entry.value['status'];
                    return _buildModernTableRow([
                      entry.value['date'] ?? '',
                      statusNames[st] ?? st.toString(),
                    ], entry.key);
                  }),
                ],
              ),
              pw.Spacer(),
              _buildModernFooter(school),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'تقرير_حضور_$studentName');
  }

  // ============================================================
  // ✅ 4. كشف المدفوعات المالي
  // ============================================================
  static Future<void> printStudentPaymentsReport({
    required SchoolInfo school, // 💡 مرر المدرسة
    required String studentName,
    required String className,
    required List<Map<String, dynamic>> payments,
    String currencySymbol = 'د.أ',
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logo = await _loadLogo(school.logoPath);
    final total = payments.fold(0.0, (sum, p) => sum + (p['amount'] as double? ?? 0.0));

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          final feeTypeNames = {'registration': 'تسجيل', 'monthly': 'شهري', 'activity': 'نشاط', 'uniform': 'زي مدرسي'};

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(school, logo, 'كشف المدفوعات المالي'),
              pw.SizedBox(height: 20),

              _buildStudentInfoCard(studentName, className, null),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5), bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  _buildModernTableHeader(['التاريخ', 'النوع', 'المبلغ', 'الملاحظات'], school.primaryColor),
                  ...payments.asMap().entries.map((entry) {
                    final p = entry.value;
                    final feeType = p['fee_type'] ?? '';
                    return _buildModernTableRow([
                      p['date'] ?? '',
                      feeTypeNames[feeType] ?? feeType,
                      '${(p['amount'] as double? ?? 0.0).toStringAsFixed(2)} $currencySymbol',
                      p['note'] ?? '',
                    ], entry.key);
                  }),
                  // صف الإجمالي في أسفل الجدول
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: school.primaryColor.withAlpha(20)),
                    children: [
                      _buildModernTableCell('المجموع الإجمالي', isHeader: true, align: pw.TextAlign.right, color: school.primaryColor),
                      _buildModernTableCell('', isHeader: true),
                      _buildModernTableCell('${total.toStringAsFixed(2)} $currencySymbol', align: pw.TextAlign.center, isHeader: true, color: school.primaryColor),
                      _buildModernTableCell('', isHeader: true),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              _buildModernFooter(school),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'كشف_مدفوعات_$studentName');
  }

  // ============================================================
  // ✅ وحدات البناء الهندسية للتصميم الحديث (UI Helpers)
  // ============================================================

  static pw.Widget _buildModernHeader(SchoolInfo school, pw.ImageProvider? logo, String reportTitle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(school.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: school.primaryColor)),
              pw.SizedBox(height: 4),
              if (school.address != null) pw.Text(school.address!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (school.phone != null) pw.Text('هاتف: ${school.phone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (school.email != null) pw.Text('بريد: ${school.email}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        if (logo != null)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            child: pw.Container(height: 50, width: 50, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(color: school.primaryColor.withAlpha(20), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(reportTitle, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: school.primaryColor)),
            ),
            pw.SizedBox(height: 6),
            pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildStudentInfoCard(String name, String className, String? schoolId) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: PdfColors.grey200), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('اسم الطالب: $name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('الصف: $className', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          if (schoolId != null) pw.Text('الرقم المدرسي: $schoolId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _buildModernTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.right, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: isHeader ? 10 : 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? (isHeader ? PdfColors.white : PdfColors.grey900)),
      ),
    );
  }

  static pw.TableRow _buildModernTableHeader(List<String> headers, PdfColor primaryColor) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: primaryColor),
      children: headers.map((h) => _buildModernTableCell(h, isHeader: true, align: pw.TextAlign.center)).toList(),
    );
  }

  static pw.TableRow _buildModernTableRow(List<String> cells, int index) {
    final isEven = index % 2 == 0;
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : PdfColors.grey50),
      children: cells.map((c) => _buildModernTableCell(c, align: pw.TextAlign.center)).toList(),
    );
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        decoration: pw.BoxDecoration(color: color.withAlpha(15), border: pw.Border.all(color: color.withAlpha(80)), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildModernFooter(SchoolInfo school) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey200),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('نظام إدارة المدارس | تم الإصدار لصالح: ${school.name}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('وثيقة إلكترونية معتمدة', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  static String _getStatusText(String status) {
    switch (status) {
      case 'paid': return 'مدفوعة بالكامل';
      case 'partial': return 'مدفوعة جزئياً';
      default: return 'غير مدفوعة';
    }
  }

  static Future<void> _sharePdf(pw.Document pdf, String filename) async {
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$filename.pdf');
  }
}