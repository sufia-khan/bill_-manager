# Implementation Plan

- [x] 1. Fix due date display to remove duplication





  - Modify the due date display section in `ExpandableBillCard` to show relative text followed by a single formatted date
  - Ensure `getRelativeDateText()` returns only relative text without the date
  - Verify the format displays as "{relative_text} — {formatted_date}"
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Add paid date display for completed bills


  - Add conditional rendering to show "Paid at" date when bill status is "paid"
  - Display both the paid date and original due date with distinct styling
  - Access `paidAt` field from `BillHive` via `BillProvider`
  - Add null checks for `paidAt` field
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Update bill archival to move paid bills immediately





  - Modify `markBillAsPaid()` in `BillProvider` to set `isArchived: true` and `archivedAt: now` immediately
  - Remove or disable the `_buildAutoArchiveWarning()` method in `ExpandableBillCard`
  - Remove the days remaining warning display for paid bills
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Consolidate action row layout with dropdown icon





  - Combine status badge, payment button, and dropdown icon into a single Row
  - Position dropdown icon on the right side of the action row
  - Remove the separate "Show details" / "Show less" button section
  - Adjust flex values to ensure proper spacing for paid vs unpaid bills
  - Update dropdown icon styling to match the new layout
  - _Requirements: 4.1, 4.2, 4.3, 4.4_
-

- [x] 5. Update category icon display and styling




- [x] 5.1 Remove orange gradient container from bill card


  - Remove the gradient `Container` wrapper around `CategoryIcon` in `ExpandableBillCard`
  - Pass appropriate size parameter directly to `CategoryIcon`
  - _Requirements: 5.2, 5.3_

- [x] 5.2 Enhance CategoryIcon widget with all category icons


  - Add unique icons for all categories (Insurance, Loan, Entertainment, Healthcare, Education, Transportation, Food)
  - Update Subscriptions category color from purple to teal/cyan (`Color(0xFFCCFBF1)` background, `Color(0xFF0891B2)` foreground)
  - Ensure each category has appropriate background and foreground colors
  - Add default fallback for unknown categories
  - _Requirements: 5.1, 5.4, 6.1, 6.2, 6.3_
