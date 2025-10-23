# Status Filter Feature Added

## What's New

Added three status filter tabs to the Bill Manager screen:
- **Upcoming** (Blue) - Shows bills that are not yet due
- **Overdue** (Red) - Shows bills that are past their due date
- **Paid** (Green) - Shows bills that have been marked as paid

## Layout

The status tabs are positioned **above** the category tabs for better visual hierarchy:

```
┌─────────────────────────────────────┐
│  [Upcoming] [Overdue] [Paid]        │  ← Status Filter (Primary)
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│  All  Rent  Utilities  Electricity  │  ← Category Filter (Secondary)
└─────────────────────────────────────┘
```

## How It Works

1. **Status Filter First**: User selects a status (Upcoming/Overdue/Paid)
2. **Category Filter Second**: User can further filter by category (All/Rent/Utilities/etc.)
3. **Combined Filtering**: Bills are filtered by BOTH status AND category

### Example:
- Select "Upcoming" + "Rent" = Shows all upcoming bills in the Rent category
- Select "Overdue" + "All" = Shows all overdue bills across all categories
- Select "Paid" + "Utilities" = Shows all paid bills in the Utilities category

## Visual Design

- **Status tabs**: Horizontal row with icons and labels, colored backgrounds when selected
  - Upcoming: Blue (#3B82F6)
  - Overdue: Red (#EF4444)
  - Paid: Green (#10B981)
- **Category tabs**: Scrollable horizontal list (unchanged from before)
- **Filtered section**: Updated to show both status and category in the summary

## Default State

- Default status: **Upcoming** (shows upcoming bills by default)
- Default category: **All** (shows all categories)
