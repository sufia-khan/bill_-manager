# Design Document

## Overview

This document outlines the technical design for implementing recurring bill automation and past bills management in the BillManager application. The solution provides automatic recurring bill creation, 30-day visibility for paid bills, and a comprehensive Past Bills section with export capabilities.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Home Screen  │  │ Past Bills   │  │ Bill Details │      │
│  │              │  │ Screen       │  │ Screen       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                    Provider Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Bill         │  │ Recurring    │  │ Export       │      │
│  │ Provider     │  │ Bill Service │  │ Service      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Hive Local   │  │ Firebase     │  │ Sync         │      │
│  │ Storage      │  │ Firestore    │  │ Service      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

1. **UI Layer**: Displays bills, handles user interactions, shows Past Bills section
2. **Provider Layer**: Manages state, business logic, and data flow
3. **Data Layer**: Handles persistence, synchronization, and data consistency

## Data Models

### Updated BillHive Model

```dart
@HiveType(typeId: 0)
class BillHive extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  String vendor;
  
  @HiveField(3)
  double amount;
  
  @HiveField(4)
  DateTime dueAt;
  
  @HiveField(5)
  String? notes;
  
  @HiveField(6)
  String category;
  
  @HiveField(7)
  bool isPaid;
  
  @HiveField(8)
  bool isDeleted;
  
  @HiveField(9)
  DateTime updatedAt;
  
  @HiveField(10)
  DateTime clientUpdatedAt;
  
  @HiveField(11)
  String repeat; // 'none', 'weekly', 'monthly', 'quarterly', 'yearly'
  
  @HiveField(12)
  bool needsSync;
  
  // NEW FIELDS
  @HiveField(13)
  DateTime? paidAt; // Timestamp when bill was marked as paid
  
  @HiveField(14)
  bool isArchived; // Flag indicating if bill is in Past Bills
  
  @HiveField(15)
  DateTime? archivedAt; // Timestamp when bill was archived
  
  @HiveField(16)
  String? parentBillId; // Links to original recurring bill
  
  @HiveField(17)
  int? recurringSequence; // Sequence number for recurring instances
}
```

### RecurringBillConfig Model

```dart
class RecurringBillConfig {
  final String billId;
  final String recurringType; // 'weekly', 'monthly', 'quarterly', 'yearly'
  final DateTime lastCreatedDate;
  final DateTime nextDueDate;
  final bool isActive;
  
  RecurringBillConfig({
    required this.billId,
    required this.recurringType,
    required this.lastCreatedDate,
    required this.nextDueDate,
    required this.isActive,
  });
}
```

## Components and Interfaces

### 1. RecurringBillService

Handles automatic creation of recurring bill instances.

```dart
class RecurringBillService {
  // Check all recurring bills and create next instances if needed
  Future<void> processRecurringBills();
  
  // Create next instance of a recurring bill
  Future<BillHive?> createNextInstance(BillHive parentBill);
  
  // Calculate next due date based on recurring type
  DateTime calculateNextDueDate(DateTime currentDue, String recurringType);
  
  // Check if next instance already exists
  Future<bool> hasNextInstance(String parentBillId, DateTime nextDueDate);
  
  // Get all active recurring bills
  Future<List<BillHive>> getActiveRecurringBills();
}
```

### 2. BillArchivalService

Manages automatic archival of paid bills after 30 days.

```dart
class BillArchivalService {
  // Check and archive eligible paid bills
  Future<void> processArchival();
  
  // Check if a bill is eligible for archival
  bool isEligibleForArchival(BillHive bill);
  
  // Archive a single bill
  Future<void> archiveBill(BillHive bill);
  
  // Get all archived bills
  Future<List<BillHive>> getArchivedBills({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  });
  
  // Get bills that will be archived soon (within 5 days)
  Future<List<BillHive>> getBillsNearArchival();
}
```

### 3. ExportService

Handles exporting past bills to various formats.

```dart
class ExportService {
  // Export bills to PDF
  Future<String> exportToPDF(List<BillHive> bills);
  
  // Export bills to CSV
  Future<String> exportToCSV(List<BillHive> bills);
  
  // Export bills to Excel
  Future<String> exportToExcel(List<BillHive> bills);
  
  // Save file to device storage
  Future<void> saveFile(String filePath, String fileName);
  
  // Share exported file
  Future<void> shareFile(String filePath);
}
```

### 4. Updated BillProvider

Extended to support recurring bills and archival.

```dart
class BillProvider extends ChangeNotifier {
  // Existing methods...
  
  // NEW METHODS
  
  // Mark bill as paid and record payment date
  Future<void> markBillAsPaid(String billId);
  
  // Get active bills (excluding archived)
  List<BillHive> getActiveBills();
  
  // Get archived bills
  List<BillHive> getArchivedBills();
  
  // Import past bills
  Future<void> importPastBills(List<BillHive> bills);
  
  // Run background maintenance (recurring + archival)
  Future<void> runMaintenance();
}
```

## Error Handling

### Recurring Bill Creation Errors

1. **Duplicate Detection**: Check for existing next instance before creation
2. **Date Calculation Errors**: Validate calculated dates are in the future
3. **Sync Conflicts**: Use timestamp-based conflict resolution

### Archival Errors

1. **Date Validation**: Ensure paidAt date exists before archival
2. **State Consistency**: Verify bill is actually paid before archiving
3. **Rollback Support**: Keep transaction log for failed archival operations

### Export Errors

1. **File Permission Errors**: Request storage permissions before export
2. **Large Dataset Handling**: Implement chunked processing for large exports
3. **Format Errors**: Validate data before export, show user-friendly error messages

## Testing Strategy

### Unit Tests

1. **RecurringBillService Tests**
   - Test date calculation for all recurring types
   - Test duplicate detection logic
   - Test next instance creation

2. **BillArchivalService Tests**
   - Test 30-day eligibility calculation
   - Test archival process
   - Test filtering of archived bills

3. **ExportService Tests**
   - Test PDF generation with sample data
   - Test CSV formatting
   - Test Excel file creation

### Integration Tests

1. **End-to-End Recurring Flow**
   - Create recurring bill → Mark as paid → Verify next instance created

2. **Archival Flow**
   - Mark bill as paid → Wait 30 days (simulated) → Verify archived

3. **Export Flow**
   - Archive bills → Export to PDF → Verify file contents

### Performance Tests

1. **Large Dataset Tests**
   - Test with 1000+ bills
   - Measure archival processing time
   - Measure export generation time

2. **Offline Sync Tests**
   - Create recurring bills offline
   - Archive bills offline
   - Verify sync when online

## Implementation Phases

### Phase 1: Data Model Updates
- Update BillHive model with new fields
- Create migration script for existing data
- Update Hive type adapters

### Phase 2: Recurring Bill Service
- Implement RecurringBillService
- Add date calculation logic
- Integrate with BillProvider
- Add background task scheduling

### Phase 3: Archival Service
- Implement BillArchivalService
- Add 30-day eligibility check
- Create Past Bills screen UI
- Add archival indicators to main screen

### Phase 4: Export Functionality
- Implement ExportService
- Add PDF generation
- Add CSV/Excel export
- Add export UI to Past Bills screen

### Phase 5: Testing & Polish
- Write comprehensive tests
- Performance optimization
- UI/UX refinements
- Documentation

## Database Schema

### Hive Boxes

```dart
// Main bills box (active bills)
Box<BillHive> billsBox = Hive.box<BillHive>('bills');

// Archived bills box (separate for performance)
Box<BillHive> archivedBillsBox = Hive.box<BillHive>('archived_bills');

// Recurring bill configurations
Box<RecurringBillConfig> recurringConfigBox = Hive.box<RecurringBillConfig>('recurring_config');
```

### Firebase Firestore Collections

```
users/{userId}/bills/{billId}
  - All bill fields
  - Indexed on: isPaid, isArchived, dueAt, paidAt
  
users/{userId}/archived_bills/{billId}
  - Archived bill records
  - Indexed on: paidAt, category
```

## Performance Optimizations

1. **Separate Archived Bills Storage**: Keep archived bills in separate Hive box for faster main screen loading
2. **Lazy Loading**: Load archived bills only when Past Bills screen is opened
3. **Pagination**: Implement pagination for Past Bills list (50 bills per page)
4. **Background Processing**: Run recurring bill creation and archival in background isolates
5. **Indexed Queries**: Use Firestore indexes for efficient filtering

## Security Considerations

1. **Data Validation**: Validate all dates and amounts before processing
2. **User Permissions**: Ensure users can only access their own bills
3. **Export Security**: Sanitize data before export to prevent injection attacks
4. **Sync Integrity**: Use checksums to verify data integrity during sync

## Offline Support

1. **Local-First Architecture**: All operations work offline first
2. **Sync Queue**: Queue all changes for sync when online
3. **Conflict Resolution**: Use last-write-wins with timestamp comparison
4. **Background Sync**: Automatically sync when connectivity restored

## UI/UX Design

### Main Screen Updates

- Add "Past Bills" button in navigation
- Show "Moving to past bills in X days" badge on paid bills
- Display recurring icon badge on recurring bills

### Past Bills Screen

```
┌─────────────────────────────────────┐
│  ← Past Bills                       │
│                                     │
│  Total Paid: $12,450.00             │
│  Bills: 156                         │
│                                     │
│  [Export] [Filter]                  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Netflix                     │   │
│  │ $15.99 • Paid Jan 15, 2024  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Electricity                 │   │
│  │ $120.50 • Paid Jan 10, 2024 │   │
│  └─────────────────────────────┘   │
│                                     │
│  [Load More]                        │
└─────────────────────────────────────┘
```

### Export Dialog

```
┌─────────────────────────────────────┐
│  Export Past Bills                  │
│                                     │
│  Select Format:                     │
│  ○ PDF                              │
│  ○ CSV                              │
│  ○ Excel                            │
│                                     │
│  Date Range:                        │
│  From: [Jan 1, 2024]                │
│  To:   [Dec 31, 2024]               │
│                                     │
│  [Cancel]  [Export]                 │
└─────────────────────────────────────┘
```

## Dependencies

### New Packages Required

```yaml
dependencies:
  # PDF generation
  pdf: ^3.10.0
  printing: ^5.11.0
  
  # Excel export
  excel: ^4.0.0
  
  # CSV export
  csv: ^6.0.0
  
  # File handling
  path_provider: ^2.1.0
  share_plus: ^7.2.0
  
  # Background tasks
  workmanager: ^0.5.0
```

## Migration Strategy

### Existing Data Migration

```dart
Future<void> migrateExistingBills() async {
  final bills = HiveService.getAllBills();
  
  for (var bill in bills) {
    // Add new fields with default values
    bill.paidAt = bill.isPaid ? bill.updatedAt : null;
    bill.isArchived = false;
    bill.archivedAt = null;
    bill.parentBillId = null;
    bill.recurringSequence = null;
    
    await HiveService.saveBill(bill);
  }
}
```

## Monitoring and Analytics

1. **Track Metrics**:
   - Number of recurring bills created per day
   - Number of bills archived per day
   - Export usage statistics
   - Average time to archive

2. **Error Tracking**:
   - Failed recurring bill creations
   - Failed archival operations
   - Export errors

3. **Performance Monitoring**:
   - Archival processing time
   - Export generation time
   - Sync duration
