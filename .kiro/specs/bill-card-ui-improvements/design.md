# Design Document

## Overview

This design document outlines the UI improvements for the ExpandableBillCard widget in the Flutter bill manager application. The improvements address date display issues, layout optimization, category icon presentation, and bill lifecycle behavior changes.

## Architecture

### Component Structure

The changes will be made primarily to the `ExpandableBillCard` widget (`lib/widgets/expandable_bill_card.dart`) and the `CategoryIcon` widget (`lib/widgets/custom_icons.dart`). The modifications will maintain the existing widget hierarchy while improving the visual presentation and user experience.

### Data Flow

- The widget receives `Bill` data through props
- The widget accesses `BillHive` data from `BillProvider` for additional fields like `paidAt`
- Date formatting utilities from `utils/formatters.dart` are used for display
- No changes to the underlying data models are required

## Components and Interfaces

### 1. Due Date Display Fix

**Current Issue:**
The due date section displays: "Feb 18 - Feb 18 2026" showing duplicate date information.

**Root Cause:**
The code calls both `getRelativeDateText()` and `getFormattedDate()` which may return overlapping information.

**Solution:**
Modify the due date display section to show:
- Relative text (e.g., "Today", "Tomorrow", "In 3 days")
- Single dash separator
- Full formatted date (e.g., "Feb 18, 2026")

**Implementation:**
```dart
// Current code (lines ~310-330)
Text(
  getRelativeDateText(widget.bill.due),
  style: const TextStyle(...),
),
const SizedBox(width: 8),
Text('—', style: TextStyle(color: Colors.grey.shade400)),
const SizedBox(width: 8),
Text(
  getFormattedDate(widget.bill.due),
  style: TextStyle(...),
),
```

Ensure `getRelativeDateText()` returns only relative text (not including the date) and `getFormattedDate()` returns the full date.

### 2. Paid Bills Date Display

**Current Issue:**
Paid bills only show the due date, not when they were actually paid.

**Solution:**
For paid bills, display both:
- "Paid at: {formatted_date}" - when the bill was marked as paid
- "Due date: {formatted_date}" - original due date

**Implementation:**
Add conditional rendering in the date display section:
```dart
if (widget.bill.status == 'paid') {
  // Show paid date first
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 14, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        Text('Paid at: ', style: TextStyle(...)),
        Text(getFormattedDate(billHive.paidAt), style: TextStyle(...)),
      ],
    ),
  ),
  const SizedBox(height: 8),
  // Show original due date
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('Due date: ', style: TextStyle(...)),
        Text(getFormattedDate(widget.bill.due), style: TextStyle(...)),
      ],
    ),
  ),
} else {
  // Existing due date display for unpaid bills
}
```

### 3. Immediate Past Bills Movement

**Current Issue:**
The code shows a warning "Will move to Past Bills in X days" and waits 2 days before archiving paid bills.

**Solution:**
Remove the 2-day delay logic and archive bills immediately when marked as paid.

**Implementation Changes:**

**A. Remove Auto-Archive Warning Widget**
Delete or disable the `_buildAutoArchiveWarning()` method and its usage (lines ~82-135).

**B. Update BillProvider Logic**
Modify `markBillAsPaid()` in `lib/providers/bill_provider.dart`:
```dart
// Change from:
final updatedBill = bill.copyWith(
  isPaid: true,
  paidAt: now,
  isArchived: false, // Don't archive immediately
  archivedAt: null,
  ...
);

// To:
final updatedBill = bill.copyWith(
  isPaid: true,
  paidAt: now,
  isArchived: true, // Archive immediately
  archivedAt: now,
  ...
);
```

**C. Remove Days Remaining Warning**
Remove the conditional rendering of the days remaining warning (lines ~336-360).

### 4. Action Row Layout Optimization

**Current Issue:**
The dropdown icon is in a separate row below the status badge and action button, taking up extra vertical space.

**Solution:**
Consolidate the action row to include:
- Status badge (left)
- Mark as Paid button (center) - only for unpaid bills
- Dropdown icon (right)

**Implementation:**
```dart
// Replace the current separate sections with a single Row
Row(
  children: [
    // Status badge
    Expanded(
      flex: widget.bill.status != 'paid' ? 1 : 2,
      child: _buildStatusBadge(),
    ),
    const SizedBox(width: 12),
    // Payment button (only for unpaid bills)
    if (widget.bill.status != 'paid')
      Expanded(
        flex: 1,
        child: _buildPaymentButton(),
      ),
    if (widget.bill.status != 'paid')
      const SizedBox(width: 12),
    // Dropdown icon
    InkWell(
      onTap: _toggleExpanded,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedRotation(
          turns: _isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey.shade600,
            size: 20,
          ),
        ),
      ),
    ),
  ],
),
```

Remove the separate "Show details" / "Show less" button section (lines ~362-385).

### 5. Category Icon Improvements

**Current Issue:**
- Category icons have an orange gradient border/background
- Only "Subscriptions" category has a custom icon
- Other categories use generic icons

**Solution A: Remove Orange Gradient Container**
Remove the gradient container wrapper around the CategoryIcon and let the CategoryIcon widget handle its own styling.

**Current code (lines ~180-205):**
```dart
Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      ...
    ),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [...],
  ),
  child: Center(
    child: CategoryIcon(
      category: widget.bill.category,
      size: 20,
    ),
  ),
),
```

**Replace with:**
```dart
CategoryIcon(
  category: widget.bill.category,
  size: 48,
),
```

**Solution B: Update CategoryIcon Widget**
Modify `lib/widgets/custom_icons.dart` to:
1. Add icons for all categories
2. Change Subscriptions color from purple to a different color
3. Ensure each category has proper sizing and styling

**Implementation:**
```dart
class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({super.key, required this.category, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    IconData iconData;

    switch (category) {
      case 'Rent':
        bgColor = const Color(0xFFECFDF5);
        fgColor = const Color(0xFF059669);
        iconData = Icons.home;
        break;
      case 'Utilities':
        bgColor = const Color(0xFFEFF6FF);
        fgColor = const Color(0xFF2563EB);
        iconData = Icons.bolt;
        break;
      case 'Subscriptions':
        // Change from purple to teal/cyan
        bgColor = const Color(0xFFCCFBF1);
        fgColor = const Color(0xFF0891B2);
        iconData = Icons.autorenew;
        break;
      case 'Insurance':
        bgColor = const Color(0xFFFEF3C7);
        fgColor = const Color(0xFFD97706);
        iconData = Icons.shield;
        break;
      case 'Loan':
        bgColor = const Color(0xFFFFEDD5);
        fgColor = const Color(0xFFF97316);
        iconData = Icons.account_balance;
        break;
      case 'Entertainment':
        bgColor = const Color(0xFFFCE7F3);
        fgColor = const Color(0xFFDB2777);
        iconData = Icons.movie;
        break;
      case 'Healthcare':
        bgColor = const Color(0xFFDCFCE7);
        fgColor = const Color(0xFF16A34A);
        iconData = Icons.local_hospital;
        break;
      case 'Education':
        bgColor = const Color(0xFFDDD6FE);
        fgColor = const Color(0xFF7C3AED);
        iconData = Icons.school;
        break;
      case 'Transportation':
        bgColor = const Color(0xFFE0E7FF);
        fgColor = const Color(0xFF4F46E5);
        iconData = Icons.directions_car;
        break;
      case 'Food':
        bgColor = const Color(0xFFFED7AA);
        fgColor = const Color(0xFFEA580C);
        iconData = Icons.restaurant;
        break;
      default:
        bgColor = const Color(0xFFF9FAFB);
        fgColor = const Color(0xFF4B5563);
        iconData = Icons.receipt;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: fgColor,
          size: size * 0.5, // Icon size is 50% of container
        ),
      ),
    );
  }
}
```

## Data Models

No changes to data models are required. The existing `BillHive` model already contains the `paidAt` field needed for displaying payment dates.

## Error Handling

### Date Formatting
- Ensure `getFormattedDate()` and `getRelativeDateText()` handle null values gracefully
- Add null checks when accessing `billHive.paidAt` for paid bills

### Missing Data
- If `paidAt` is null for a paid bill, fall back to showing only the due date
- Log a warning for data inconsistency

## Testing Strategy

### Manual Testing Checklist

1. **Due Date Display**
   - Verify unpaid bills show correct relative date + formatted date
   - Check that dates don't duplicate
   - Test with bills due today, tomorrow, and in the future

2. **Paid Bills Display**
   - Mark a bill as paid
   - Verify "Paid at" date displays correctly
   - Verify original due date still shows
   - Confirm bill moves to Past Bills immediately

3. **Action Row Layout**
   - Check that status badge, payment button, and dropdown icon are in one row
   - Verify proper spacing and alignment
   - Test expand/collapse functionality with new icon position
   - Verify paid bills show status badge and dropdown icon only

4. **Category Icons**
   - Create bills with different categories
   - Verify each category shows its unique icon
   - Confirm no orange gradient border appears
   - Check Subscriptions uses new teal/cyan color instead of purple

5. **Responsive Behavior**
   - Test on different screen sizes
   - Verify text doesn't overflow
   - Check that action row elements resize appropriately

### Edge Cases

1. Bills with very long titles
2. Bills with null or missing paidAt dates
3. Bills with categories not in the predefined list
4. Rapid expand/collapse interactions
5. Bills marked as paid then unmarked (if supported)

## Visual Design Specifications

### Colors

**Paid Date Section:**
- Background: `Color(0xFFECFDF5)` (light green)
- Border: `Color(0xFFA7F3D0)` (green)
- Icon: `Color(0xFF059669)` (green)
- Text: `Color(0xFF047857)` (dark green)

**Due Date Section (for paid bills):**
- Background: `Colors.grey.shade50`
- Icon: `Colors.grey.shade400`
- Text: `Colors.grey.shade600`

**Dropdown Icon:**
- Background: `Colors.grey.shade100`
- Icon: `Colors.grey.shade600`

**Category Colors:**
See CategoryIcon implementation above for complete color specifications.

### Spacing

- Gap between paid date and due date: 8px
- Gap between status badge and payment button: 12px
- Gap between payment button and dropdown icon: 12px
- Padding inside dropdown icon container: 8px

### Typography

- Paid date label: 14px, medium weight
- Due date label: 14px, medium weight
- Date values: 14px, regular weight

## Implementation Notes

1. **Backwards Compatibility**: The changes maintain the existing widget API, so no changes to parent components are required.

2. **Performance**: The removal of the auto-archive warning reduces unnecessary widget rebuilds.

3. **Accessibility**: Ensure all interactive elements (dropdown icon, buttons) have appropriate tap targets (minimum 48x48 logical pixels).

4. **Animation**: Maintain the existing smooth expand/collapse animation when moving the dropdown icon.

5. **State Management**: No changes to state management are required; the widget continues to use local state for expansion and Provider for bill data.
