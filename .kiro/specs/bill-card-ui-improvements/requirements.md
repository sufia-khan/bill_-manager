# Requirements Document

## Introduction

This document outlines the requirements for improving the bill card UI in the Flutter bill manager application. The improvements focus on fixing date display issues, enhancing the layout of action buttons, improving category icon presentation, and adjusting the bill lifecycle behavior for paid bills.

## Glossary

- **Bill Card**: The expandable card widget that displays bill information in the application
- **Due Date Display**: The section showing when a bill payment is due
- **Paid At Date**: The timestamp when a bill was marked as paid
- **Past Bills**: The archived section where paid bills are moved after completion
- **Category Icon**: The visual indicator representing the bill category (Rent, Utilities, Subscriptions, etc.)
- **Action Row**: The horizontal layout containing status badges and action buttons
- **Dropdown Icon**: The chevron icon that expands/collapses the bill card details

## Requirements

### Requirement 1

**User Story:** As a user, I want to see the due date displayed correctly without duplication, so that I can quickly understand when my bill is due.

#### Acceptance Criteria

1. WHEN the Bill Card displays a due date, THE Bill Card SHALL show the relative date text (e.g., "Today", "Tomorrow") followed by a single formatted date (e.g., "Feb 18, 2026")
2. THE Bill Card SHALL NOT display duplicate date information in the due date section
3. THE Bill Card SHALL format the date display as "{relative_text} — {formatted_date}" with a single dash separator

### Requirement 2

**User Story:** As a user, I want to see both the paid date and due date for completed bills, so that I can track when I paid each bill and when it was originally due.

#### Acceptance Criteria

1. WHEN a bill status is "paid", THE Bill Card SHALL display the "Paid at" date with timestamp
2. WHEN a bill status is "paid", THE Bill Card SHALL also display the original due date
3. THE Bill Card SHALL format the paid date section to clearly distinguish between paid date and due date

### Requirement 3

**User Story:** As a user, I want paid bills to move to Past Bills immediately after marking them as paid, so that my active bills list stays current.

#### Acceptance Criteria

1. WHEN a bill is marked as paid, THE Bill Card SHALL move to Past Bills immediately without delay
2. THE Bill Card SHALL NOT wait 2 days before moving paid bills to Past Bills
3. THE Bill Card SHALL remove the auto-archive warning message that mentions "2 days"

### Requirement 4

**User Story:** As a user, I want the dropdown icon and action buttons to be in the same row, so that the card layout is more compact and intuitive.

#### Acceptance Criteria

1. THE Bill Card SHALL display the dropdown expand/collapse icon in the same horizontal row as the status badge and action button
2. THE Bill Card SHALL position the dropdown icon on the right side of the action row
3. THE Bill Card SHALL maintain proper spacing and alignment between all elements in the action row
4. THE Bill Card SHALL remove the separate "Show details" / "Show less" button section

### Requirement 5

**User Story:** As a user, I want each bill category to have its own distinct icon without colored borders, so that I can quickly identify bill types visually.

#### Acceptance Criteria

1. THE Bill Card SHALL display a unique icon for each category (Rent, Utilities, Subscriptions, and others)
2. THE Bill Card SHALL NOT display an orange gradient border around category icons
3. THE Bill Card SHALL render category icons with their own background colors as defined in the CategoryIcon widget
4. THE Bill Card SHALL ensure all categories have appropriate icon representations

### Requirement 6

**User Story:** As a user, I want the subscription category to use a different color scheme, so that it is visually distinct from the current purple color.

#### Acceptance Criteria

1. WHERE the category is "Subscriptions", THE Bill Card SHALL display the category icon with a non-purple color scheme
2. THE Bill Card SHALL use a color that provides good contrast and visual distinction from other categories
3. THE Bill Card SHALL maintain consistency with the overall application color palette
