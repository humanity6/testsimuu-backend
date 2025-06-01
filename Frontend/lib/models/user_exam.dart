import 'package:flutter/material.dart';
import 'exam.dart';

class UserExam {
  final String id;
  final Exam exam;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'ACTIVE', 'EXPIRED', etc.
  final bool autoRenew;
  final String? progress; // '0%', '50%', '100%', etc.

  UserExam({
    required this.id,
    required this.exam,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.autoRenew = false,
    this.progress,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isPendingPayment => status == 'PENDING_PAYMENT';
  bool get isInGracePeriod => status == 'GRACE_PERIOD';

  // Check if the subscription is expiring soon (within 7 days)
  bool get isExpiringSoon {
    final now = DateTime.now();
    final difference = endDate.difference(now).inDays;
    return isActive && difference >= 0 && difference <= 7;
  }

  // Get days remaining in subscription
  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays;
  }

  factory UserExam.fromJson(Map<String, dynamic> json) {
    return UserExam(
      id: json['id'] ?? '',
      exam: Exam.fromJson(json['exam'] ?? {}),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : DateTime.now().add(const Duration(days: 30)),
      status: json['status'] ?? 'INACTIVE',
      autoRenew: json['auto_renew'] ?? false,
      progress: json['progress'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam': exam.toJson(),
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'auto_renew': autoRenew,
      'progress': progress,
    };
  }

  // Create a copy of this UserExam with optional modifications
  UserExam copyWith({
    String? id,
    Exam? exam,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    bool? autoRenew,
    String? progress,
  }) {
    return UserExam(
      id: id ?? this.id,
      exam: exam ?? this.exam,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      autoRenew: autoRenew ?? this.autoRenew,
      progress: progress ?? this.progress,
    );
  }

  // Get color based on status
  Color getStatusColor() {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'EXPIRED':
        return Colors.red;
      case 'PENDING_PAYMENT':
        return Colors.orange;
      case 'GRACE_PERIOD':
        return Colors.amber;
      case 'CANCELED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
} 