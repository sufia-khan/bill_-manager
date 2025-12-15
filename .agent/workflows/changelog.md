---
description: How to track code changes in the changelog
---

# Changelog Tracking Workflow

**IMPORTANT**: Every time you make code changes (add, edit, or delete), you MUST update the changelog file.

## Changelog File Location
`c:\Users\vasee\OneDrive\Desktop\bill_manager\CHANGELOG.md`

## What to Log

For every code change, add an entry with:

1. **Date and Time** (IST timezone) - Format: `YYYY-MM-DD` for date header, `HH:MM IST` for time
2. **Task/Feature Name** - Brief description of what was done
3. **Files Modified** - Table with:
   - File path (relative to project root)
   - Action: `ADDED`, `MODIFIED`, `DELETED`, or `REPLACED`
   - Line numbers affected (if applicable)
   - Details of what changed
4. **Summary** - Brief explanation of the change
5. **Commands Run** - Any terminal commands executed

## Entry Template

```markdown
### HH:MM IST - Task/Feature Name

**Files Modified:**

| File | Action | Lines | Details |
|------|--------|-------|---------|
| `path/to/file.dart` | MODIFIED | L45-L67 | Description of change |
| `path/to/new_file.dart` | ADDED | - | New file for XYZ |

**Summary:** Brief explanation of what was done and why.

**Commands Run:**
- `command 1` - Description
- `command 2` - Description

---
```

## End of Task Reference

At the end of every task or set of changes, say:
> "I've added these changes to the [CHANGELOG.md](file:///c:/Users/vasee/OneDrive/Desktop/bill_manager/CHANGELOG.md)"

## Remember
- Always check the current time before adding entries
- Use relative file paths from project root
- Include line numbers for code modifications
- Group related changes under a single timestamp
