import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill_hive.dart';
import '../providers/bill_provider.dart';
import '../providers/currency_provider.dart';
import '../utils/formatters.dart';
import '../widgets/custom_icons.dart';
import '../widgets/skeleton_loader.dart';
import '../services/export_service.dart';

class PastBillsScreen extends StatefulWidget {
  const PastBillsScreen({super.key});

  @override
  State<PastBillsScreen> createState() => _PastBillsScreenState();
}

class _PastBillsScreenState extends State<PastBillsScreen> {
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  static const int _billsPerPage = 50;
  bool _isLoadingMore = false;

  // Category data with icons
  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.apps},
    {'name': 'Rent', 'icon': Icons.home},
    {'name': 'Utilities', 'icon': Icons.electrical_services},
    {'name': 'Electricity', 'icon': Icons.bolt},
    {'name': 'Water', 'icon': Icons.water_drop},
    {'name': 'Gas', 'icon': Icons.local_fire_department},
    {'name': 'Internet', 'icon': Icons.wifi},
    {'name': 'Phone', 'icon': Icons.phone},
    {'name': 'Subscriptions', 'icon': Icons.card_membership},
    {'name': 'Streaming', 'icon': Icons.tv},
    {'name': 'Groceries', 'icon': Icons.shopping_cart},
    {'name': 'Transport', 'icon': Icons.directions_bus},
    {'name': 'Fuel', 'icon': Icons.local_gas_station},
    {'name': 'Insurance', 'icon': Icons.security},
    {'name': 'Health', 'icon': Icons.local_hospital},
    {'name': 'Medical', 'icon': Icons.medical_services},
    {'name': 'Education', 'icon': Icons.school},
    {'name': 'Entertainment', 'icon': Icons.movie},
    {'name': 'Credit Card', 'icon': Icons.credit_card},
    {'name': 'Loan', 'icon': Icons.account_balance},
    {'name': 'Taxes', 'icon': Icons.receipt},
    {'name': 'Savings', 'icon': Icons.savings},
    {'name': 'Donations', 'icon': Icons.volunteer_activism},
    {'name': 'Home Maintenance', 'icon': Icons.home_repair_service},
    {'name': 'HOA', 'icon': Icons.apartment},
    {'name': 'Gym', 'icon': Icons.fitness_center},
    {'name': 'Childcare', 'icon': Icons.child_care},
    {'name': 'Pets', 'icon': Icons.pets},
    {'name': 'Travel', 'icon': Icons.flight},
    {'name': 'Parking', 'icon': Icons.local_parking},
    {'name': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  Widget build(BuildContext context) {
    // Listen to currency changes to rebuild UI
    context.watch<CurrencyProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFFFF8C00),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Past Bills',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF8C00),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFFFF8C00)),
            onPressed: _showActionsMenu,
            tooltip: 'More Actions',
          ),
        ],
      ),
      body: Consumer<BillProvider>(
        builder: (context, billProvider, child) {
          // Show skeleton loaders during initial load
          if (billProvider.isLoading && !billProvider.isInitialized) {
            return Column(
              children: [
                // Summary skeleton
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(
                              width: 100,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            SkeletonLoader(
                              width: 150,
                              height: 24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                      SkeletonLoader(
                        width: 60,
                        height: 60,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                ),
                // Bills list skeleton
                const Expanded(child: BillListSkeleton()),
              ],
            );
          }

          final archivedBills = billProvider.getArchivedBills(
            startDate: _startDate,
            endDate: _endDate,
            category: _selectedCategory,
          );

          // Calculate summary statistics
          final totalAmount = archivedBills.fold<double>(
            0.0,
            (sum, bill) => sum + bill.amount,
          );
          final totalCount = archivedBills.length;

          // Apply pagination
          final displayedBills = archivedBills
              .take(_currentPage * _billsPerPage)
              .toList();
          final hasMore = archivedBills.length > displayedBills.length;

          return Column(
            children: [
              // Summary statistics
              _buildSummarySection(totalAmount, totalCount),

              // Active filters
              if (_selectedCategory != null ||
                  _startDate != null ||
                  _endDate != null)
                _buildActiveFilters(),

              // Bills list
              Expanded(
                child: archivedBills.isEmpty
                    ? _buildEmptyState()
                    : _buildBillsList(displayedBills, hasMore),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummarySection(double totalAmount, int totalCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF8C00).withValues(alpha: 0.1),
            const Color(0xFFFF8C00).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF8C00).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C00).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: Color(0xFFFF8C00),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Paid',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrencyFull(totalAmount),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: Color(0xFFFF8C00),
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCount',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Bills',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_selectedCategory != null)
            Chip(
              label: Text(_selectedCategory!),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                setState(() {
                  _selectedCategory = null;
                  _currentPage = 1;
                });
              },
              backgroundColor: const Color(0xFFFF8C00).withValues(alpha: 0.1),
              labelStyle: const TextStyle(
                color: Color(0xFFFF8C00),
                fontSize: 12,
              ),
            ),
          if (_startDate != null || _endDate != null)
            Chip(
              label: Text(
                '${_startDate != null ? DateFormat('MMM d, y').format(_startDate!) : 'Start'} - ${_endDate != null ? DateFormat('MMM d, y').format(_endDate!) : 'End'}',
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _currentPage = 1;
                });
              },
              backgroundColor: const Color(0xFFFF8C00).withValues(alpha: 0.1),
              labelStyle: const TextStyle(
                color: Color(0xFFFF8C00),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'No Past Bills',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid bills older than 30 days will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsList(List<BillHive> bills, bool hasMore) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == bills.length) {
          // Load more button
          return _buildLoadMoreButton();
        }

        final bill = bills[index];
        return _buildBillCard(bill);
      },
    );
  }

  Widget _buildBillCard(BillHive bill) {
    final formattedAmount = formatCurrencyShort(bill.amount);
    final fullAmount = formatCurrencyFull(bill.amount);
    final isFormatted = formattedAmount != fullAmount;

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) => _confirmDelete(bill),
      onDismissed: (direction) => _deleteBill(bill.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryIcon(category: bill.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bill.vendor,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedAmount,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showAmountBottomSheet(bill.amount),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isFormatted
                              ? const Color(0xFFFF8C00).withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: isFormatted
                              ? const Color(0xFFFF8C00)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bill.category,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
                const Spacer(),
                if (bill.paidAt != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Paid ${DateFormat('MMM d, y').format(bill.paidAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      // Show skeleton loaders while loading more
      return Column(
        children: List.generate(3, (index) => const BillCardSkeleton()),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: _loadMore,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8C00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Load More',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    });
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Text(
                      'Filter by Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
                    if (_selectedCategory != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                            _currentPage = 1;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              // Category list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected =
                        _selectedCategory == category['name'] ||
                        (_selectedCategory == null &&
                            category['name'] == 'All');

                    return ListTile(
                      leading: Icon(
                        category['icon'],
                        color: isSelected
                            ? const Color(0xFFFF8C00)
                            : Colors.grey.shade600,
                      ),
                      title: Text(
                        category['name'],
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFFF8C00)
                              : const Color(0xFF1F2937),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFFFF8C00))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category['name'] == 'All'
                              ? null
                              : category['name'];
                          _currentPage = 1;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDateRangeFilter() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF8C00),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
    }
  }

  void _showExportDialog() {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final archivedBills = billProvider.getArchivedBills(
      startDate: _startDate,
      endDate: _endDate,
      category: _selectedCategory,
    );

    if (archivedBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Export Bills',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export ${archivedBills.length} bills',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              _buildExportOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF',
                subtitle: 'Formatted report with tables',
                onTap: () {
                  Navigator.pop(context);
                  _exportToPDF(archivedBills);
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                icon: Icons.table_chart,
                title: 'Excel',
                subtitle: 'Spreadsheet with formatting',
                onTap: () {
                  Navigator.pop(context);
                  _exportToExcel(archivedBills);
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                icon: Icons.text_snippet,
                title: 'CSV',
                subtitle: 'Plain text comma-separated',
                onTap: () {
                  Navigator.pop(context);
                  _exportToCSV(archivedBills);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFFF8C00), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPDF(List<BillHive> bills) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
        ),
      );

      // Generate PDF
      final pdfBytes = await ExportService.exportToPDF(bills);

      // Save file
      final filePath = await ExportService.saveFile(pdfBytes, 'past_bills.pdf');

      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show success message with share option
      _showExportSuccess(filePath);
    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel(List<BillHive> bills) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
        ),
      );

      // Generate Excel
      final excelBytes = ExportService.exportToExcel(bills);

      // Save file
      final filePath = await ExportService.saveFile(
        excelBytes,
        'past_bills.xlsx',
      );

      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show success message with share option
      _showExportSuccess(filePath);
    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCSV(List<BillHive> bills) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
        ),
      );

      // Generate CSV
      final csvString = ExportService.exportToCSV(bills);
      final csvBytes = csvString.codeUnits;

      // Save file
      final filePath = await ExportService.saveFile(csvBytes, 'past_bills.csv');

      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show success message with share option
      _showExportSuccess(filePath);
    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSuccess(String filePath) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF059669), size: 28),
              SizedBox(width: 12),
              Text(
                'Export Successful',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File saved to:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filePath,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await Share.shareXFiles([
                  XFile(filePath),
                ], text: 'Past Bills Export');
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ImportPastBillsDialog(),
    );
  }

  // Show actions menu with all options
  void _showActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 20),
              // Action Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildActionTile(
                    icon: Icons.filter_list,
                    label: 'Filter',
                    onTap: () {
                      Navigator.pop(context);
                      _showCategoryFilter();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.date_range,
                    label: 'Date Range',
                    onTap: () {
                      Navigator.pop(context);
                      _showDateRangeFilter();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.upload_file,
                    label: 'Import',
                    onTap: () {
                      Navigator.pop(context);
                      _showImportDialog();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.file_download,
                    label: 'Export',
                    onTap: () {
                      Navigator.pop(context);
                      _showExportDialog();
                    },
                  ),
                  _buildActionTile(
                    icon: Icons.delete_sweep,
                    label: 'Clear All',
                    color: const Color(0xFFDC2626),
                    onTap: () {
                      Navigator.pop(context);
                      _showClearAllConfirmation();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? const Color(0xFFFF8C00);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tileColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: tileColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tileColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show amount bottom sheet
  void _showAmountBottomSheet(double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Compact amount
              Text(
                formatCurrencyShort(amount),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8C00),
                ),
              ),
              const SizedBox(height: 16),
              // Full amount
              Text(
                formatCurrencyFull(amount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // Confirm delete single bill
  Future<bool?> _confirmDelete(BillHive bill) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Bill?'),
        content: Text('Are you sure you want to delete "${bill.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete single bill
  Future<void> _deleteBill(String billId) async {
    try {
      await context.read<BillProvider>().deleteBill(billId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill deleted successfully'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting bill: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // Show clear all confirmation
  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_outlined,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Clear All History?'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL paid bills from your history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // Clear all history
  Future<void> _clearAllHistory() async {
    try {
      final billProvider = context.read<BillProvider>();
      final paidBills = billProvider.bills.where((b) => b.isPaid).toList();

      for (final bill in paidBills) {
        await billProvider.deleteBill(bill.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${paidBills.length} bills from history'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing history: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}

// Import Past Bills Dialog Widget
class _ImportPastBillsDialog extends StatefulWidget {
  const _ImportPastBillsDialog();

  @override
  State<_ImportPastBillsDialog> createState() => _ImportPastBillsDialogState();
}

class _ImportPastBillsDialogState extends State<_ImportPastBillsDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _billsToImport = [];

  // Form fields for current bill
  final _titleController = TextEditingController();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _paymentDate;
  String _selectedCategory = 'Other';
  final _notesController = TextEditingController();

  // Category data with icons
  final List<String> categories = [
    'Rent',
    'Utilities',
    'Electricity',
    'Water',
    'Gas',
    'Internet',
    'Phone',
    'Subscriptions',
    'Streaming',
    'Groceries',
    'Transport',
    'Fuel',
    'Insurance',
    'Health',
    'Medical',
    'Education',
    'Entertainment',
    'Credit Card',
    'Loan',
    'Taxes',
    'Savings',
    'Donations',
    'Home Maintenance',
    'HOA',
    'Gym',
    'Childcare',
    'Pets',
    'Travel',
    'Parking',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _vendorController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addBillToList() {
    if (_formKey.currentState!.validate()) {
      if (_dueDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a due date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_paymentDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a payment date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate dates are within 1 year past
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      if (_dueDate!.isBefore(oneYearAgo)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Due date must be within the last year'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_paymentDate!.isBefore(oneYearAgo)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment date must be within the last year'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _billsToImport.add({
          'title': _titleController.text,
          'vendor': _vendorController.text,
          'amount': double.parse(_amountController.text),
          'dueDate': _dueDate!,
          'paymentDate': _paymentDate!,
          'category': _selectedCategory,
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
        });

        // Clear form
        _titleController.clear();
        _vendorController.clear();
        _amountController.clear();
        _notesController.clear();
        _dueDate = null;
        _paymentDate = null;
        _selectedCategory = 'Other';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill added (${_billsToImport.length} total)'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _importAllBills() async {
    if (_billsToImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills to import. Add at least one bill.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
        ),
      );

      final billProvider = Provider.of<BillProvider>(context, listen: false);
      await billProvider.importPastBills(_billsToImport);

      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Close import dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${_billsToImport.length} bills',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file, color: Color(0xFFFF8C00)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Past Bills',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add bills from the last year that you\'ve already paid',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bills added counter
                      if (_billsToImport.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF059669,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF059669,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_billsToImport.length} bill${_billsToImport.length == 1 ? '' : 's'} ready to import',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Title field
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Bill Title *',
                          hintText: 'e.g., Netflix Subscription',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Vendor field
                      TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Vendor *',
                          hintText: 'e.g., Netflix',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a vendor';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Amount field
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          hintText: '0.00',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) <= 0) {
                            return 'Amount must be greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Due date picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFFF8C00),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Color(0xFF1F2937),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _dueDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due Date *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _dueDate != null
                                ? DateFormat('MMM d, y').format(_dueDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _dueDate != null
                                  ? const Color(0xFF1F2937)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment date picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _paymentDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFFF8C00),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Color(0xFF1F2937),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _paymentDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Payment Date *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _paymentDate != null
                                ? DateFormat('MMM d, y').format(_paymentDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _paymentDate != null
                                  ? const Color(0xFF1F2937)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes field
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Add any additional notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Add Another button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addBillToList,
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Import List'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF8C00),
                            side: const BorderSide(color: Color(0xFFFF8C00)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer with Import All button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _billsToImport.isEmpty
                          ? null
                          : _importAllBills,
                      icon: const Icon(Icons.upload),
                      label: Text(
                        'Import ${_billsToImport.isEmpty ? '' : '${_billsToImport.length} '}Bill${_billsToImport.length == 1 ? '' : 's'}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                      ),
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
}
