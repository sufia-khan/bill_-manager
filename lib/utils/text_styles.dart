import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized text styles for consistent typography across the app
/// Uses Inter for general text and Poppins for amounts/numbers
class AppTextStyles {
  // ============ AMOUNTS (Poppins - great for numbers) ============

  /// Large amount display (e.g., bill amounts in cards)
  static TextStyle amount({Color? color}) => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFF1F2937),
  );

  /// Medium amount display (e.g., summary cards)
  static TextStyle amountMedium({Color? color}) => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: color ?? Colors.white,
  );

  /// Small amount display
  static TextStyle amountSmall({Color? color}) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFF1F2937),
  );

  // ============ HEADINGS (Inter) ============

  /// App title / Main heading
  static TextStyle appTitle({Color? color}) => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFFFF8C00),
    letterSpacing: 0.3,
  );

  /// Bill title in cards
  static TextStyle billTitle({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFF1F2937),
  );

  /// Section heading
  static TextStyle sectionHeading({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color ?? const Color(0xFF1F2937),
  );

  // ============ BODY TEXT (Inter) ============

  /// Regular body text
  static TextStyle body({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color ?? const Color(0xFF1F2937),
  );

  /// Medium body text
  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0xFF1F2937),
  );

  /// Bold body text
  static TextStyle bodyBold({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color ?? const Color(0xFF1F2937),
  );

  // ============ LABELS & CAPTIONS (Inter) ============

  /// Category label
  static TextStyle label({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0xFF6B7280),
  );

  /// Small label
  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0xFF6B7280),
  );

  /// Caption text
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0xFF6B7280),
  );

  // ============ STATUS & BADGES (Inter) ============

  /// Status badge (PAID, OVERDUE, UPCOMING)
  static TextStyle status({Color? color}) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFF1F2937),
    letterSpacing: 0.5,
  );

  // ============ BUTTONS (Inter) ============

  /// Button text
  static TextStyle button({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color ?? Colors.white,
  );

  /// Large button text
  static TextStyle buttonLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color ?? Colors.white,
  );

  // ============ DATES & TIMES (Inter) ============

  /// Due date text
  static TextStyle dueDate({Color? color}) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFF1F2937),
  );

  /// Due date prefix (e.g., "Due in:")
  static TextStyle dueDatePrefix({Color? color}) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0xFF1F2937),
  );

  // ============ SUMMARY CARDS (Inter) ============

  /// Summary card title
  static TextStyle summaryTitle({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? Colors.white,
  );

  /// Summary card subtitle
  static TextStyle summarySubtitle({Color? color}) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: color ?? Colors.white.withValues(alpha: 0.9),
  );

  // ============ FILTER SECTION (Inter) ============

  /// Filter count text
  static TextStyle filterCount({Color? color}) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: color ?? const Color(0xFF1F2937),
  );

  /// Filter amount
  static TextStyle filterAmount({Color? color}) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFFFF8C00),
  );

  // ============ TABS (Inter) ============

  /// Tab text
  static TextStyle tab({Color? color, bool isSelected = false}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: color ?? const Color(0xFF6B7280),
      );

  // ============ NAVIGATION (Inter) ============

  /// Bottom nav label
  static TextStyle navLabel({Color? color}) => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0xFF6B7280),
  );
}
