import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _dateRange = 'this-month';
  bool _showCustomDate = false;
  DateTime? _startDate;
  DateTime? _endDate;

  final Map<String, bool> _selectedBills = {
    'paid': true,
    'active': true,
    'overdue': false,
  };

  String _exportFormat = 'csv';

  void _handleExport() {
    final selected = _selectedBills.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .join(', ');

    String dateInfo = _dateRange;
    if (_dateRange == 'custom' && _startDate != null && _endDate != null) {
      dateInfo =
          '${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export'),
        content: Text(
          'Exporting as ${_exportFormat.toUpperCase()}\nDate: $dateInfo\nBills: $selected',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? const Color(0xFF6366F1)
        : const Color(0xFFFF8C00);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF9FAFB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF374151),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Bills',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF8C00),
              ),
            ),
            Text(
              'Download and share your bill data',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Export Section
            _buildSectionHeader(
              icon: Icons.bolt,
              title: 'Quick Export',
              color: primaryColor,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickExportCard(
                    title: 'This Month',
                    description: 'Export all paid bills from this month',
                    icon: Icons.calendar_today,
                    accentColor: isDark
                        ? const Color(0xFF10B981)
                        : const Color(0xFF10B981),
                    onExport: () => _showExportDialog('This Month Paid Bills'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickExportCard(
                    title: 'This Year',
                    description: 'Export all paid bills for tax filing',
                    icon: Icons.description,
                    accentColor: isDark
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF3B82F6),
                    onExport: () => _showExportDialog('This Year Paid Bills'),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Custom Export Section
            _buildSectionHeader(
              icon: Icons.tune,
              title: 'Custom Export',
              color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildCustomExportCard(isDark, primaryColor),
            const SizedBox(height: 32),

            // Recent Exports Section
            _buildSectionHeader(
              icon: Icons.history,
              title: 'Recent Exports',
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildRecentExports(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomExportCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Export',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      'Build your own export',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date Range
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _dateRange,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF1F2937),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: const [
                  DropdownMenuItem(
                    value: 'this-month',
                    child: Text('This Month'),
                  ),
                  DropdownMenuItem(
                    value: 'last-month',
                    child: Text('Last Month'),
                  ),
                  DropdownMenuItem(
                    value: 'last-3-months',
                    child: Text('Last 3 Months'),
                  ),
                  DropdownMenuItem(
                    value: 'last-6-months',
                    child: Text('Last 6 Months'),
                  ),
                  DropdownMenuItem(
                    value: 'this-year',
                    child: Text('This Year'),
                  ),
                  DropdownMenuItem(value: 'all-time', child: Text('All Time')),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom Range'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _dateRange = value!;
                    _showCustomDate = value == 'custom';
                  });
                },
              ),
            ),
          ),

          // Custom Date Range
          if (_showCustomDate) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Select start date',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'End Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'Select end date',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Bill Status
          Text(
            'Bill Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          _buildBillStatusCheckbox(
            'paid',
            'Paid Bills',
            'Bills you\'ve already paid',
            5,
            const Color(0xFF10B981),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBillStatusCheckbox(
            'active',
            'Active Bills',
            'Upcoming bills to pay',
            3,
            primaryColor,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBillStatusCheckbox(
            'overdue',
            'Overdue Bills',
            'Bills past due date',
            0,
            const Color(0xFFEF4444),
            isDark,
          ),

          const SizedBox(height: 20),

          // Export Format
          Text(
            'File Format',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          _buildFormatOption(
            'pdf',
            'PDF Report',
            'Professional formatted document',
            Icons.picture_as_pdf,
            const Color(0xFFEF4444),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFormatOption(
            'csv',
            'CSV Spreadsheet',
            'Easy to edit and analyze',
            Icons.table_chart,
            const Color(0xFF10B981),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFormatOption(
            'excel',
            'Excel File',
            'Advanced spreadsheet format',
            Icons.grid_on,
            const Color(0xFF10B981),
            isDark,
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Preview functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preview functionality')),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    foregroundColor: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF374151),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleExport,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillStatusCheckbox(
    String key,
    String title,
    String subtitle,
    int count,
    Color color,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBills[key] = !_selectedBills[key]!;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedBills[key]!
                ? color
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _selectedBills[key],
              onChanged: (value) {
                setState(() {
                  _selectedBills[key] = value!;
                });
              },
              activeColor: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: count > 0
                    ? color.withOpacity(0.1)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: count > 0
                      ? color
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF9CA3AF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _exportFormat = value;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _exportFormat,
              onChanged: (val) {
                setState(() {
                  _exportFormat = val!;
                });
              },
              activeColor: isDark
                  ? const Color(0xFF6366F1)
                  : const Color(0xFFFF8C00),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExports(bool isDark) {
    return Column(
      children: [
        _RecentExportItem(
          name: 'Bills_Oct_2025.csv',
          date: 'Oct 20, 2025',
          size: '847 KB',
          format: 'csv',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _RecentExportItem(
          name: 'Tax_Report_2025.pdf',
          date: 'Oct 15, 2025',
          size: '1.2 MB',
          format: 'pdf',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _RecentExportItem(
          name: 'Monthly_Bills_Sep.xlsx',
          date: 'Sep 30, 2025',
          size: '956 KB',
          format: 'excel',
          isDark: isDark,
        ),
      ],
    );
  }

  void _showExportDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export'),
        content: Text('Exporting $type...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Quick Export Card Widget
class _QuickExportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onExport;
  final bool isDark;

  const _QuickExportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onExport,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Recent Export Item Widget
class _RecentExportItem extends StatelessWidget {
  final String name;
  final String date;
  final String size;
  final String format;
  final bool isDark;

  const _RecentExportItem({
    required this.name,
    required this.date,
    required this.size,
    required this.format,
    required this.isDark,
  });

  IconData _getFormatIcon() {
    switch (format) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'csv':
        return Icons.table_chart;
      case 'excel':
        return Icons.grid_on;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFormatColor() {
    switch (format) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'csv':
        return const Color(0xFF10B981);
      case 'excel':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getFormatColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getFormatIcon(), color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$date • $size',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Share functionality
            },
            icon: Icon(
              Icons.share,
              size: 18,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
