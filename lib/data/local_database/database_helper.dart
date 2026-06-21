import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:typed_data';

class DatabaseHelper {
  static final supabase = Supabase.instance.client;

  // ==================== اختبار الاتصال ====================
  static Future<bool> testConnection() async {
    try {
      await supabase.from('classes').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('خطأ في الاتصال: $e');
      return false;
    }
  }

  // ==================== الملفات الشخصية (Profiles) ====================
  static Future<void> addProfile(Map<String, dynamic> profile) async {
    final response = await supabase.from('profiles').insert(profile);
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  // ==================== الصفوف (Classes) ====================
  static Future<List<Map<String, dynamic>>> getAllClasses() async {
    final response = await supabase.from('classes').select('''
      *,
      teachers(name)
    ''');
    return response;
  }

  static Future<Map<String, dynamic>> addClass(Map<String, dynamic> data) async {
    final response = await supabase.from('classes').insert(data).select();
    return response.first;
  }

  static Future<Map<String, dynamic>> updateClass(int id, Map<String, dynamic> data) async {
    final response = await supabase.from('classes').update(data).eq('id', id).select();
    return response.first;
  }

  static Future<void> deleteClass(int id) async {
    await supabase.from('classes').delete().eq('id', id);
  }
// ==================== دوال جدول الحصص ====================

// جلب جميع الحصص
static Future<List<Map<String, dynamic>>> getAllSchedules() async {
  final response = await supabase
      .from('schedules')
      .select('''
        *,
        classes(name),
        teachers(name),
        subjects(name)
      ''');
  return response;
}

// جلب حصص صف معين
static Future<List<Map<String, dynamic>>> getSchedulesByClass(int classId) async {
  final response = await supabase
      .from('schedules')
      .select('''
        *,
        teachers(name),
        subjects(name)
      ''')
      .eq('class_id', classId);
  return response;
}

// جلب حصص معلم معين
static Future<List<Map<String, dynamic>>> getSchedulesByTeacher(int teacherId) async {
  final response = await supabase
      .from('schedules')
      .select('''
        *,
        classes(name),
        subjects(name)
      ''')
      .eq('teacher_id', teacherId);
  return response;
}

// إضافة حصة
static Future<Map<String, dynamic>> addSchedule(Map<String, dynamic> data) async {
  // التحقق من عدم وجود تعارض (نفس المعلم في نفس اليوم والفترة)
  final conflict = await supabase
      .from('schedules')
      .select('id')
      .eq('teacher_id', data['teacher_id'])
      .eq('day_of_week', data['day_of_week'])
      .eq('period', data['period'])
      .maybeSingle();

  if (conflict != null) {
    throw Exception('⚠️ هذا المعلم لديه حصة في نفس اليوم والفترة');
  }

  final response = await supabase.from('schedules').insert(data).select();
  return response.first;
}

// تعديل حصة
static Future<Map<String, dynamic>> updateSchedule(int id, Map<String, dynamic> data) async {
  final response = await supabase
      .from('schedules')
      .update(data)
      .eq('id', id)
      .select();
  return response.first;
}

// حذف حصة
static Future<void> deleteSchedule(int id) async {
  await supabase.from('schedules').delete().eq('id', id);
}
// ==================== دوال الإشعارات ====================

// جلب جميع إشعارات المستخدم
static Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
  final response = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return response;
}

// إضافة إشعار جديد
static Future<Map<String, dynamic>> addNotification(Map<String, dynamic> data) async {
  final response = await supabase.from('notifications').insert(data).select();
  return response.first;
}

// تحديث حالة الإشعار (قراءة)
static Future<void> markNotificationAsRead(int notificationId) async {
  await supabase
      .from('notifications')
      .update({'is_read': true})
      .eq('id', notificationId);
}

// تحديث جميع الإشعارات كمقروءة لمستخدم معين
static Future<void> markAllNotificationsAsRead(String userId) async {
  await supabase
      .from('notifications')
      .update({'is_read': true})
      .eq('user_id', userId);
}

// حذف إشعار
static Future<void> deleteNotification(int notificationId) async {
  await supabase.from('notifications').delete().eq('id', notificationId);
}
  // ==================== المواد (Subjects) ====================
  static Future<List<Map<String, dynamic>>> getAllSubjects() async {
    final response = await supabase.from('subjects').select('*');
    return response;
  }

  static Future<Map<String, dynamic>> addSubject(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('subjects').insert(data).select();
      return response.first;
    } catch (e) {
      throw Exception('خطأ في إضافة المادة: $e');
    }
  }

  static Future<Map<String, dynamic>> updateSubject(int id, Map<String, dynamic> data) async {
    final response = await supabase.from('subjects').update(data).eq('id', id).select();
    return response.first;
  }

  static Future<void> deleteSubject(int id) async {
    await supabase.from('subjects').delete().eq('id', id);
  }

  // ==================== المعلمين (Teachers) ====================
  static Future<List<Map<String, dynamic>>> getAllTeachers() async {
    final response = await supabase.from('teachers').select('*');
    return response;
  }

  static Future<Map<String, dynamic>> addTeacher(Map<String, dynamic> data) async {
    final response = await supabase.from('teachers').insert(data).select();
    return response.first;
  }

  static Future<Map<String, dynamic>> updateTeacher(int id, Map<String, dynamic> data) async {
    final response = await supabase.from('teachers').update(data).eq('id', id).select();
    return response.first;
  }

  static Future<void> deleteTeacher(int id) async {
    await supabase.from('teachers').delete().eq('id', id);
  }

  // ==================== الطلاب (Students) ====================
  static Future<List<Map<String, dynamic>>> getAllStudents() async {
    final response = await supabase.from('students').select('''
      *,
      classes(name)
    ''');
    return response;
  }

  static Future<Map<String, dynamic>> addStudent(Map<String, dynamic> data) async {
    final cleanedData = Map<String, dynamic>.from(data);
    cleanedData['father_family_name'] = data['father_family_name'] ?? '';
    cleanedData['school_id'] = data['school_id'] ?? ''; // ✅ الرقم المدرسي
    final response = await supabase.from('students').insert(cleanedData).select();
    return response.first;
  }

  static Future<Map<String, dynamic>> updateStudent(int id, Map<String, dynamic> data) async {
    final cleanedData = Map<String, dynamic>.from(data);
    cleanedData['father_family_name'] = data['father_family_name'] ?? '';
    cleanedData['school_id'] = data['school_id'] ?? ''; // ✅ الرقم المدرسي
    final response = await supabase.from('students').update(cleanedData).eq('id', id).select();
    return response.first;
  }

  static Future<void> deleteStudent(int id) async {
    await supabase.from('students').delete().eq('id', id);
  }

  // ==================== مواد الصف (Class Subjects) ====================
  static Future<List<Map<String, dynamic>>> getClassSubjects(int classId) async {
    final response = await supabase.from('class_subjects').select('''
      *,
      subjects(name, code),
      teachers(name)
    ''').eq('class_id', classId);
    return response;
  }

  // ✅ النسخة المصححة (باستخدام try-catch بدلاً من response.error)
  static Future<void> assignSubjectToClass(Map<String, dynamic> data) async {
    try {
      await supabase.from('class_subjects').insert(data);
    } catch (e) {
      throw Exception('خطأ في ربط المادة بالصف: $e');
    }
  }

  static Future<void> removeSubjectFromClass(int classId, int subjectId) async {
    await supabase.from('class_subjects')
        .delete()
        .eq('class_id', classId)
        .eq('subject_id', subjectId);
  }

  static Future<List<Map<String, dynamic>>> getSubjectsByClass(int classId) async {
    final response = await supabase.from('class_subjects').select('''
      subject_id,
      subjects(name, code)
    ''').eq('class_id', classId);
    return response;
  }

  // ==================== رفع صورة الطالب (يدعم الويب) ====================
  static Future<String> uploadStudentPhoto(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName = 'student_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('students').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(cacheControl: '3600', upsert: true),
      );

      final publicUrl = supabase.storage.from('students').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('خطأ في رفع الصورة: $e');
      rethrow;
    }
  }

  // ==================== الحضور والغياب (Attendance) ====================
  static Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    final response = await supabase.from('attendance').select('''
      *,
      students(name),
      classes(name)
    ''').eq('date', date);
    return response;
  }

  static Future<Map<String, dynamic>> addAttendance(Map<String, dynamic> data) async {
    final response = await supabase.from('attendance').insert(data).select();
    return response.first;
  }

  static Future<void> deleteAttendance(int id) async {
    await supabase.from('attendance').delete().eq('id', id);
  }

  // ==================== الدرجات (Grades) ====================
  static Future<List<Map<String, dynamic>>> getGradesByStudent(int studentId) async {
    final response = await supabase.from('grades').select('''
      *,
      subjects(name),
      classes(name)
    ''').eq('student_id', studentId);
    return response;
  }

  static Future<Map<String, dynamic>> addGrade(Map<String, dynamic> data) async {
    final response = await supabase.from('grades').insert(data).select();
    return response.first;
  }

  static Future<void> updateGrade(int id, Map<String, dynamic> data) async {
    await supabase.from('grades').update(data).eq('id', id);
  }

  static Future<void> deleteGrade(int id) async {
    await supabase.from('grades').delete().eq('id', id);
  }

  // ==================== المدفوعات (Payments) ====================
  static Future<List<Map<String, dynamic>>> getPaymentsByStudent(int studentId) async {
    final response = await supabase.from('payments').select('*').eq('student_id', studentId);
    return response;
  }

  static Future<List<Map<String, dynamic>>> getAllPayments() async {
    final response = await supabase.from('payments').select('*').order('created_at', ascending: false);
    return response;
  }

  static Future<Map<String, dynamic>> addPayment(Map<String, dynamic> data) async {
    final response = await supabase.from('payments').insert(data).select();
    return response.first;
  }

  static Future<void> deletePayment(int id) async {
    await supabase.from('payments').delete().eq('id', id);
  }
  // ==================== دوال خاصة بالمعلم ====================

// جلب المواد التي يدرسها معلم معين
static Future<List<Map<String, dynamic>>> getTeacherSubjects(int teacherId) async {
  final response = await supabase
      .from('class_subjects')
      .select('''
        subject_id,
        class_id,
        subjects(name),
        classes(name)
      ''')
      .eq('teacher_id', teacherId);
  return response;
}

// جلب جميع الطلاب الذين يدرسهم معلم (جميع الصفوف والمواد)
static Future<List<Map<String, dynamic>>> getAllStudentsForTeacher(int teacherId) async {
  // جلب جميع class_subjects لهذا المعلم
  final classSubjects = await supabase
      .from('class_subjects')
      .select('class_id')
      .eq('teacher_id', teacherId);

  if (classSubjects.isEmpty) return [];

  final classIds = classSubjects.map((c) => c['class_id'] as int).toList();

  // جلب الطلاب في هذه الصفوف
  final students = await supabase
      .from('students')
      .select('*, classes(name)')
      .inFilter('class_id', classIds);

  return students;
}

// جلب طلاب صف معين لمعلم معين
static Future<List<Map<String, dynamic>>> getStudentsForTeacherByClass(
  int teacherId,
  int classId,
) async {
  // التحقق من أن المعلم يدرس هذا الصف
  final classSubject = await supabase
      .from('class_subjects')
      .select('class_id')
      .eq('teacher_id', teacherId)
      .eq('class_id', classId)
      .maybeSingle();

  if (classSubject == null) return [];

  // جلب طلاب هذا الصف
  final students = await supabase
      .from('students')
      .select('*, classes(name)')
      .eq('class_id', classId);

  return students;
}
// ==================== دوال الشعب/الأقسام ====================

// جلب جميع الشعب
static Future<List<Map<String, dynamic>>> getAllSections() async {
  final response = await supabase
      .from('sections')
      .select('''
        *,
        classes(name),
        teachers(name)
      ''');
  return response;
}

// جلب شعب صف معين
static Future<List<Map<String, dynamic>>> getSectionsByClass(int classId) async {
  final response = await supabase
      .from('sections')
      .select('''
        *,
        teachers(name)
      ''')
      .eq('class_id', classId);
  return response;
}

// إضافة شعبة
static Future<Map<String, dynamic>> addSection(Map<String, dynamic> data) async {
  final response = await supabase.from('sections').insert(data).select();
  return response.first;
}

// تعديل شعبة
static Future<Map<String, dynamic>> updateSection(int id, Map<String, dynamic> data) async {
  final response = await supabase.from('sections').update(data).eq('id', id).select();
  return response.first;
}

// حذف شعبة
static Future<void> deleteSection(int id) async {
  await supabase.from('sections').delete().eq('id', id);
}
}