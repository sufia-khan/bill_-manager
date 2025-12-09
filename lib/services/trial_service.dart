import 'package:firebase_auth/firebase_auth.dart';
import 'hive_service.dart';

class TrialService {
  static const int trialDurationDays = 30; // 1 month

  // ============ TEST MODE ============
  // Change this to test different states:
  // null = real mode (uses actual registration date)
  // 'trial_start' = Just started (30 days left)
  // 'trial_middle' = Middle of trial (15 days left)
  // 'trial_ending' = Trial ending soon (7 days left)
  // 'trial_expired' = Trial expired
  // 'pro' = Pro member
  static String? testMode; // Set to test different states (null = real mode)
  // ===================================

  /// Get registration date for current user
  static DateTime? getRegistrationDate() {
    // TEST MODE: Return fake dates based on test mode
    if (testMode != null) {
      switch (testMode) {
        case 'trial_start':
          return DateTime.now(); // Just registered
        case 'trial_middle':
          return DateTime.now().subtract(const Duration(days: 15));
        case 'trial_ending':
          return DateTime.now().subtract(
            const Duration(days: 23),
          ); // 7 days left
        case 'trial_expired':
          return DateTime.now().subtract(const Duration(days: 40)); // Expired
        case 'pro':
          return DateTime.now().subtract(const Duration(days: 60));
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final dateStr = HiveService.getUserData('registrationDate_${user.uid}');
    if (dateStr == null) {
      // For existing users without registration date, set it now
      _setRegistrationDateForExistingUser(user.uid);
      return DateTime.now();
    }

    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Set registration date for existing users who don't have one
  static Future<void> _setRegistrationDateForExistingUser(String uid) async {
    await HiveService.saveUserData(
      'registrationDate_$uid',
      DateTime.now().toIso8601String(),
    );
  }

  /// Check if user is in trial period
  static bool isInTrialPeriod() {
    // TEST MODE: Directly return false for expired test
    if (testMode == 'trial_expired') return false;

    final registrationDate = getRegistrationDate();
    if (registrationDate == null) return true; // Default to trial if unknown

    final now = DateTime.now();
    final trialEndDate = registrationDate.add(
      const Duration(days: trialDurationDays),
    );

    return now.isBefore(trialEndDate);
  }

  /// Get days remaining in trial
  static int getDaysRemaining() {
    final registrationDate = getRegistrationDate();
    if (registrationDate == null) return trialDurationDays;

    final now = DateTime.now();
    final trialEndDate = registrationDate.add(
      const Duration(days: trialDurationDays),
    );

    final remaining = trialEndDate.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Get trial end date
  static DateTime? getTrialEndDate() {
    final registrationDate = getRegistrationDate();
    if (registrationDate == null) return null;

    return registrationDate.add(const Duration(days: trialDurationDays));
  }

  /// Check if user has Pro subscription
  static bool hasProSubscription() {
    // TEST MODE: Return true if testing pro mode
    if (testMode == 'pro') return true;

    // Check actual subscription status from SubscriptionService
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final status = HiveService.getUserData('subscription_status_${user.uid}');
    return status == 'active';
  }

  /// Check if user can access Pro features
  static bool canAccessProFeatures() {
    return isInTrialPeriod() || hasProSubscription();
  }

  // ============ FEATURE LIMITS ============

  // FREE PLAN vs PRO PLAN COMPARISON:
  // ┌────────────────────────┬─────────────┬─────────────┐
  // │ Feature                │ FREE        │ PRO/TRIAL   │
  // ├────────────────────────┼─────────────┼─────────────┤
  // │ Max Bills              │ 5           │ Unlimited   │
  // │ Recurring Bills        │ ❌ No       │ ✅ Yes      │
  // │ Reminder Options       │ Same Day    │ All (4)     │
  // │ Categories             │ 10 basic    │ All (30+)   │
  // │ Currency Change        │ ❌ No       │ ✅ Yes      │
  // │ Analytics              │ Basic       │ Advanced    │
  // │ Cloud Sync             │ ❌ No       │ ✅ Yes      │
  // │ Export Data            │ ❌ No       │ ✅ Yes      │
  // │ Bill Notes             │ ❌ No       │ ✅ Yes      │
  // │ Archive Bills          │ ❌ No       │ ✅ Yes      │
  // └────────────────────────┴─────────────┴─────────────┘

  /// Free plan limits
  static const int freeMaxBills = 5; // Max 5 bills
  static const int freeMaxCategories = 10; // Only first 10 categories
  static const int freeMaxReminders = 1; // Only "Same Day" reminder
  static const bool freeCanUseRecurring = false; // No recurring bills
  static const bool freeCanChangeCurrency =
      false; // Stuck with default currency
  static const bool freeCanUseNotes = false; // No bill notes
  static const bool freeCanArchive = false; // No archiving
  static const bool freeCanExport = false; // No export
  static const bool freeCanSync = false; // No cloud sync

  /// Pro plan limits (unlimited)
  static const int proMaxBills = -1; // Unlimited (-1 = no limit)
  static const int proMaxCategories = -1; // All categories
  static const int proMaxReminders = 4; // All 4 reminder options
  static const bool proCanUseRecurring = true; // Full recurring support
  static const bool proCanChangeCurrency = true; // Can change currency
  static const bool proCanUseNotes = true; // Bill notes enabled
  static const bool proCanArchive = true; // Can archive bills
  static const bool proCanExport = true; // Can export data
  static const bool proCanSync = true; // Cloud sync enabled

  // ============ FEATURE CHECK METHODS ============

  /// Get max bills allowed (-1 = unlimited)
  static int getMaxBills() {
    return canAccessProFeatures() ? proMaxBills : freeMaxBills;
  }

  /// Get max categories allowed (-1 = unlimited)
  static int getMaxCategories() {
    return canAccessProFeatures() ? proMaxCategories : freeMaxCategories;
  }

  /// Get max reminders allowed
  static int getMaxReminders() {
    return canAccessProFeatures() ? proMaxReminders : freeMaxReminders;
  }

  /// Check if user can add recurring bills
  static bool canAddRecurringBill() {
    return canAccessProFeatures();
  }

  /// Check if user can change currency
  static bool canChangeCurrency() {
    return canAccessProFeatures();
  }

  /// Check if user can add notes to bills
  static bool canUseNotes() {
    return canAccessProFeatures();
  }

  /// Check if user can archive bills
  static bool canArchiveBills() {
    return canAccessProFeatures();
  }

  /// Check if user can export data
  static bool canExportData() {
    return canAccessProFeatures();
  }

  /// Check if user can use cloud sync
  static bool canUseCloudSync() {
    return canAccessProFeatures();
  }

  /// Check if user can access advanced analytics
  static bool canAccessAdvancedAnalytics() {
    return canAccessProFeatures();
  }

  /// Check if a specific feature is available
  static bool isFeatureAvailable(String feature) {
    if (canAccessProFeatures()) return true; // Pro/Trial users get everything

    // Free user feature restrictions
    switch (feature) {
      case 'recurring_bills':
        return false;
      case 'multiple_reminders':
        return false;
      case 'change_currency':
        return false;
      case 'bill_notes':
        return false;
      case 'archive_bills':
        return false;
      case 'cloud_sync':
        return false;
      case 'advanced_analytics':
        return false;
      case 'export_data':
        return false;
      case 'unlimited_bills':
        return false;
      case 'all_categories':
        return false;
      default:
        return true; // Allow basic features
    }
  }

  /// Get feature name for display
  static String getFeatureDisplayName(String feature) {
    switch (feature) {
      case 'recurring_bills':
        return 'Recurring Bills';
      case 'multiple_reminders':
        return 'Multiple Reminders';
      case 'change_currency':
        return 'Currency Settings';
      case 'bill_notes':
        return 'Bill Notes';
      case 'archive_bills':
        return 'Archive Bills';
      case 'cloud_sync':
        return 'Cloud Sync';
      case 'advanced_analytics':
        return 'Advanced Analytics';
      case 'export_data':
        return 'Export Data';
      case 'unlimited_bills':
        return 'Unlimited Bills';
      case 'all_categories':
        return 'All Categories';
      default:
        return feature;
    }
  }

  /// Check if user has reached bill limit
  /// For free users, only counts bills created AFTER trial expiration
  /// Bills created during trial/pro period are grandfathered (don't count toward limit)
  static bool hasReachedBillLimit(int currentBillCount) {
    if (canAccessProFeatures()) return false;
    return currentBillCount >= freeMaxBills;
  }

  /// Get remaining bills count for free users
  /// For free users, only counts bills created AFTER trial expiration
  /// Returns -1 for unlimited (Pro/Trial users)
  static int getRemainingBills(int currentBillCount) {
    if (canAccessProFeatures()) return -1; // Unlimited
    return (freeMaxBills - currentBillCount).clamp(0, freeMaxBills);
  }

  /// Count bills created after trial expiration (for free tier limit)
  /// Counts ACTIVE UPCOMING bills for free tier limit
  /// Only counts bills that are:
  /// - Not archived, not deleted, not paid, not overdue
  /// - Not grandfathered (created during trial/pro)
  ///
  /// This allows users to:
  /// - Delete upcoming bills to free up slots
  /// - Have paid/overdue bills without blocking new additions
  static int countFreeTierBills(List<dynamic> allBills) {
    if (canAccessProFeatures()) return 0; // Not applicable for Pro/Trial users

    // Count only ACTIVE UPCOMING bills (not paid, not overdue, not deleted, not archived)
    int count = 0;
    final now = DateTime.now();

    for (var bill in allBills) {
      // Skip archived bills
      if (bill.isArchived) continue;

      // Skip deleted bills - deleting frees up the slot
      if (bill.isDeleted) continue;

      // Skip paid bills - they're done, don't block new bills
      if (bill.isPaid || bill.paidAt != null) continue;

      // Skip overdue bills - they're past due, don't block new bills
      if (bill.dueAt.isBefore(now)) continue;

      // This is an ACTIVE UPCOMING bill
      // Check if it's grandfathered (created during trial/pro)
      if (bill.createdDuringProTrial == true) continue;

      // Count this bill toward the limit
      count++;
    }

    return count;
  }

  /// Get remaining bills for free users (considering grandfathered bills)
  /// Shows how many more bills a free user can add
  static int getRemainingFreeTierBills(List<dynamic> allBills) {
    if (canAccessProFeatures()) return -1; // Unlimited

    final freeTierBillCount = countFreeTierBills(allBills);
    return (freeMaxBills - freeTierBillCount).clamp(0, freeMaxBills);
  }

  /// Check if existing bill should keep its Pro features (grandfathering)
  /// Bills created during trial keep their settings even after trial expires
  static bool shouldGrandfatherBill(DateTime billCreatedDate) {
    final registrationDate = getRegistrationDate();
    if (registrationDate == null) return false;

    final trialEndDate = registrationDate.add(
      const Duration(days: trialDurationDays),
    );

    // If bill was created during trial period, grandfather it
    return billCreatedDate.isBefore(trialEndDate) &&
        billCreatedDate.isAfter(
          registrationDate.subtract(const Duration(days: 1)),
        );
  }

  /// Get list of all Pro features for display
  static List<Map<String, dynamic>> getProFeaturesList() {
    return [
      {
        'icon': '',
        'title': 'Unlimited Bills',
        'desc': 'Track as many bills as you need',
      },
      {
        'icon': '',
        'title': 'Recurring Bills',
        'desc': 'Weekly, monthly, yearly bills',
      },
      {
        'icon': '',
        'title': 'Multiple Reminders',
        'desc': 'Get reminded 1 day, 2 days, 1 week before',
      },
      {
        'icon': '',
        'title': 'Currency Settings',
        'desc': 'Change currency anytime',
      },
      {'icon': '', 'title': 'Bill Notes', 'desc': 'Add notes to your bills'},
      {
        'icon': '',
        'title': 'Archive Bills',
        'desc': 'Archive paid bills for records',
      },
      {
        'icon': '',
        'title': 'Advanced Analytics',
        'desc': 'Detailed spending insights',
      },
      {
        'icon': '',
        'title': 'Cloud Sync',
        'desc': 'Backup & sync across devices',
      },
      {'icon': '', 'title': 'Export Data', 'desc': 'Export bills to CSV/PDF'},
      {
        'icon': '',
        'title': 'All Categories',
        'desc': 'Access 30+ bill categories',
      },
    ];
  }

  /// Get user membership status
  static MembershipStatus getMembershipStatus() {
    if (hasProSubscription()) {
      return MembershipStatus.pro;
    } else if (isInTrialPeriod()) {
      return MembershipStatus.trial;
    } else {
      return MembershipStatus.free;
    }
  }
}

enum MembershipStatus { trial, pro, free }
