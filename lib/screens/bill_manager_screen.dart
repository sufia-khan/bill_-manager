import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../widgets/custom_icons.dart';
import '../widgets/animated_subtitle.dart';
import '../utils/formatters.dart';
import 'add_bill_screen.dart';
import 'settings_screen.dart';

class BillManagerScreen extends StatefulWidget {
  const BillManagerScreen({super.key});

  @override
  State<BillManagerScreen> createState() => _BillManagerScreenState();
}

class _BillManagerScreenState extends State<BillManagerScreen> {
  List<Bill> bills = [
    Bill(
      id: '1',
      title: 'Electricity',
      vendor: 'PowerCo',
      amount: 85.5,
      due: '2025-10-20',
      repeat: 'monthly',
      category: 'Utilities',
      status: 'upcoming',
    ),
    Bill(
      id: '2',
      title: 'Spotify',
      vendor: 'Spotify',
      amount: 9.99,
      due: '2025-10-18',
      repeat: 'monthly',
      category: 'Subscriptions',
      status: 'due',
    ),
    Bill(
      id: '3',
      title: 'Rent',
      vendor: 'Landlord',
      amount: 1200.0,
      due: '2025-11-01',
      repeat: 'monthly',
      category: 'Rent',
      status: 'upcoming',
    ),
    Bill(
      id: '4',
      title: 'Internet',
      vendor: 'ISP',
      amount: 50.0,
      due: '2025-10-14',
      repeat: 'monthly',
      category: 'Utilities',
      status: 'overdue',
    ),
    Bill(
      id: '5',
      title: 'Apartment Rent',
      vendor: 'Landlord',
      amount: 345.0,
      due: '2025-10-25',
      repeat: 'monthly',
      category: 'Rent',
      status: 'upcoming',
    ),
    Bill(
      id: '6',
      title: 'Storage Rent',
      vendor: 'StorageCo',
      amount: 345.0,
      due: '2025-10-28',
      repeat: 'monthly',
      category: 'Rent',
      status: 'upcoming',
    ),
  ];

  // Comprehensive categories with icons
  final List<Map<String, dynamic>> _allCategories = [
    {'name': 'All', 'icon': Icons.apps},
    {'name': 'Rent', 'icon': Icons.home},
    {'name': 'Utilities', 'icon': Icons.electrical_services},
    {'name': 'Electricity', 'icon': Icons.bolt},
    {'name': 'Water', 'icon': Icons.water_drop},
    {'name': 'Gas', 'icon': Icons.local_fire_department},
    {'name': 'Internet', 'icon': Icons.wifi},
    {'name': 'Phone', 'icon': Icons.phone},
    {'name': 'Subscriptions', 'icon': Icons.subscriptions},
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

  String selectedCategory = 'All';
  int _selectedTabIndex = 0;
  bool _compactAmounts = true;
  bool _showSettings = false;
  bool _showAddBill = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // List to store keys for each category item for enhanced visibility detection
  // Generate enough keys for all categories plus buffer
  final List<GlobalKey> _categoryKeys = List.generate(50, (index) => GlobalKey());

  // Scroll controller for category tabs - initialized once at widget creation
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final filteredBills = selectedCategory == 'All'
        ? bills
        : bills.where((b) => b.category == selectedCategory).toList();

    final thisMonthTotal = _getThisMonthTotal();
    final next7DaysTotal = _getNext7DaysTotal();
    final filteredCount = filteredBills.length;
    final filteredAmount = filteredBills.fold(0.0, (sum, bill) => sum + bill.amount);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(filteredBills, thisMonthTotal, next7DaysTotal, filteredCount, filteredAmount),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildAddButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BillManager',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 2),
          const AnimatedSubtitle(),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _showSettings = !_showSettings;
            });
          },
          icon: Icon(
            Icons.settings_outlined,
            color: const Color(0xFFFF8C00),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<Bill> filteredBills, double thisMonthTotal, double next7DaysTotal,
                   int filteredCount, double filteredAmount) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showSettings) _buildSettingsSection(),
              _buildSummaryCards(thisMonthTotal, next7DaysTotal),
              const SizedBox(height: 24),
              _buildCategoriesSection(),
              const SizedBox(height: 24),
              _buildFilteredSection(filteredCount, filteredAmount),
              const SizedBox(height: 24),
              _buildBillsList(filteredBills),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
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
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                label: 'Compact amounts setting',
                value: _compactAmounts ? 'enabled' : 'disabled',
                child: const Text(
                  'Compact amounts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Switch(
                value: _compactAmounts,
                onChanged: (value) {
                  setState(() {
                    _compactAmounts = value;
                  });
                },
                activeTrackColor: const Color(0xFFFF8C00).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFFFF8C00),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double thisMonthTotal, double next7DaysTotal) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'This month',
            formatCurrencyFull(thisMonthTotal),
            'Total due this month',
            const MoneyIcon(size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Next 7 days',
            formatCurrencyFull(next7DaysTotal),
            'Bills due in the next 7 days',
            Icon(Icons.calendar_today_outlined, color: const Color(0xFFFF8C00), size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String amount, String subtitle, Widget icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: icon,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final GlobalKey containerKey = GlobalKey();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SingleChildScrollView(
            key: containerKey,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: _allCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final isSelected = selectedCategory == category['name'];

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedCategory = category['name'];
                        // Enhanced auto-scroll functionality
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _enhancedScrollToSelectedCategory(index, containerKey);
                        });
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      key: _categoryKeys[index], // Assign key for enhanced visibility detection
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF8C00) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF8C00) : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Icon(
                              category['icon'],
                              size: 16,
                              color: Colors.white,
                            )
                          else
                            Icon(
                              category['icon'],
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            category['name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  
  // Enhanced auto-scroll method for better visibility detection and smart scrolling
  void _enhancedScrollToSelectedCategory(int selectedIndex, GlobalKey containerKey) {
    if (selectedIndex == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // Get container render box for dimensions
      final RenderBox? containerRenderBox = containerKey.currentContext?.findRenderObject() as RenderBox?;
      if (containerRenderBox == null) return;

      // Get the selected tab's render box using its key
      final selectedTabContext = _categoryKeys[selectedIndex].currentContext;
      if (selectedTabContext == null) return;

      final RenderBox? selectedTabRenderBox = selectedTabContext.findRenderObject() as RenderBox?;
      if (selectedTabRenderBox == null) return;

      // Calculate positions in global coordinates
      final selectedTabPosition = selectedTabRenderBox.localToGlobal(Offset.zero);
      final containerPosition = containerRenderBox.localToGlobal(Offset.zero);
      final selectedTabSize = selectedTabRenderBox.size;
      final containerSize = containerRenderBox.size;

      // Calculate tab positions relative to container
      final tabLeft = selectedTabPosition.dx - containerPosition.dx;
      final tabRight = tabLeft + selectedTabSize.width;

      // Get current scroll position
      final currentOffset = _scrollController.offset;

      // Check if tab is not fully visible
      if (tabLeft < 0) {
        // Tab is partially hidden on the left - scroll to show it
        final targetOffset = (currentOffset + tabLeft - 20).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (tabRight > containerSize.width) {
        // Tab is partially hidden on the right - scroll to show it
        final overflow = tabRight - containerSize.width;
        final targetOffset = (currentOffset + overflow + 20).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Tab is fully visible, check if we should auto-scroll to show more tabs
        // Auto-scroll when clicking the last visible tab to reveal next ones
        final visibleTabCount = _getVisibleTabCount(containerRenderBox);
        final lastVisibleIndex = _getLastVisibleTabIndex(containerRenderBox);

        if (selectedIndex >= lastVisibleIndex - 1 && selectedIndex < _allCategories.length - 1) {
          // Clicked on one of the last visible tabs, scroll to show more
          final scrollAmount = containerSize.width * 0.6; // Scroll 60% of container width
          final targetOffset = (currentOffset + scrollAmount).clamp(0.0, _scrollController.position.maxScrollExtent);

          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  // Helper method to find last fully visible tab index
  int _findLastFullyVisibleIndex(RenderBox containerRenderBox) {
    int lastFullyVisibleIndex = -1;
    final containerSize = containerRenderBox.size;

    for (int i = 0; i < _allCategories.length && i < _categoryKeys.length; i++) {
      final context = _categoryKeys[i].currentContext;
      if (context != null) {
        final RenderBox? tabRenderBox = context.findRenderObject() as RenderBox?;
        if (tabRenderBox != null) {
          final tabPosition = tabRenderBox.localToGlobal(Offset.zero);
          final containerPosition = containerRenderBox.localToGlobal(Offset.zero);

          final tabLeft = tabPosition.dx;
          final tabRight = tabPosition.dx + tabRenderBox.size.width;
          final containerLeft = containerPosition.dx;
          final containerRight = containerPosition.dx + containerSize.width;

          // Check if tab is fully visible within container bounds
          if (tabLeft >= containerLeft && tabRight <= containerRight) {
            lastFullyVisibleIndex = i;
          }
        }
      }
    }

    return lastFullyVisibleIndex;
  }

  // Helper method to get count of visible tabs
  int _getVisibleTabCount(RenderBox containerRenderBox) {
    int visibleCount = 0;
    final containerSize = containerRenderBox.size;
    final containerPosition = containerRenderBox.localToGlobal(Offset.zero);
    final containerLeft = containerPosition.dx;
    final containerRight = containerPosition.dx + containerSize.width;

    for (int i = 0; i < _allCategories.length && i < _categoryKeys.length; i++) {
      final context = _categoryKeys[i].currentContext;
      if (context != null) {
        final RenderBox? tabRenderBox = context.findRenderObject() as RenderBox?;
        if (tabRenderBox != null) {
          final tabPosition = tabRenderBox.localToGlobal(Offset.zero);
          final tabLeft = tabPosition.dx;
          final tabRight = tabPosition.dx + tabRenderBox.size.width;

          // Check if tab is at least partially visible
          if (tabRight > containerLeft && tabLeft < containerRight) {
            visibleCount++;
          }
        }
      }
    }

    return visibleCount;
  }

  // Helper method to get last visible tab index
  int _getLastVisibleTabIndex(RenderBox containerRenderBox) {
    int lastVisibleIndex = -1;
    final containerSize = containerRenderBox.size;
    final containerPosition = containerRenderBox.localToGlobal(Offset.zero);
    final containerLeft = containerPosition.dx;
    final containerRight = containerPosition.dx + containerSize.width;

    for (int i = 0; i < _allCategories.length && i < _categoryKeys.length; i++) {
      final context = _categoryKeys[i].currentContext;
      if (context != null) {
        final RenderBox? tabRenderBox = context.findRenderObject() as RenderBox?;
        if (tabRenderBox != null) {
          final tabPosition = tabRenderBox.localToGlobal(Offset.zero);
          final tabLeft = tabPosition.dx;
          final tabRight = tabPosition.dx + tabRenderBox.size.width;

          // Check if tab is at least partially visible
          if (tabRight > containerLeft && tabLeft < containerRight) {
            lastVisibleIndex = i;
          }
        }
      }
    }

    return lastVisibleIndex;
  }

  // Helper method to get tab's scroll position
  double _getTabScrollPosition(int tabIndex) {
    if (tabIndex <= 0) return 0.0;

    double position = 0.0;
    for (int i = 0; i < tabIndex && i < _categoryKeys.length; i++) {
      final context = _categoryKeys[i].currentContext;
      if (context != null) {
        final RenderBox? tabRenderBox = context.findRenderObject() as RenderBox?;
        if (tabRenderBox != null) {
          position += tabRenderBox.size.width + 6.0; // Include padding
        }
      }
    }

    return position;
  }

  
  Widget _buildFilteredSection(int count, double amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const MoneyIcon(size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Showing',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    '$count bill${count != 1 ? 's' : ''} • ${formatCurrencyFull(amount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ],
          ),
          RichText(
            text: TextSpan(
              text: 'Filtered: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              children: [
                TextSpan(
                  text: selectedCategory,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsList(List<Bill> filteredBills) {
    if (filteredBills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'No bills match this filter.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adding a new bill or change the category.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredBills.map((bill) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CategoryIcon(category: bill.category),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${bill.vendor} • ${bill.repeat}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Tooltip(
                        message: 'Amount: ${formatCurrencyFull(bill.amount)}',
                        child: Text(
                          _compactAmounts ? formatCurrencyShort(bill.amount) : formatCurrencyFull(bill.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Tap to view full value (mobile) / Hover to view full value (desktop)',
                        child: InkWell(
                          onTap: () => _showAmountBottomSheet(bill.amount),
                          borderRadius: BorderRadius.circular(12),
                          child: Semantics(
                            label: 'View full amount: ${formatCurrencyFull(bill.amount)}',
                            hint: 'Double tap to view full amount in bottom sheet',
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${getRelativeDateText(bill.due)} — ${getFormattedDate(bill.due)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusBadge(bill.status),
                      if (bill.status != 'paid') ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _markPaid(bill.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8C00),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Mark paid',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'overdue':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        break;
      case 'paid':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        break;
      default: // due, upcoming
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_outlined, 'Home'),
            _buildNavItem(1, Icons.analytics_outlined, 'Analytics'),
            _buildNavItem(2, Icons.calendar_today_outlined, 'Calendar'),
            _buildNavItem(3, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });

        // Handle navigation for different tabs
        if (index == 3) { // Settings tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
        }
        // TODO: Add navigation for other tabs as needed
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFFFF8C00) : Colors.grey.shade600,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFFFF8C00) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddBillScreen(),
          ),
        );
      },
      backgroundColor: const Color(0xFFFF8C00),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildAddBillForm() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Bill',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showAddBill = false;
                        _clearForm();
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _vendorController,
                decoration: const InputDecoration(
                  labelText: 'Vendor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  helperText: 'Enter a decimal value (e.g., 50.00)',
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              if (_amountController.text.isNotEmpty)
                Text(
                  'Preview: ${_formatAmountPreview()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF8C00),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showAddBill = false;
                          _clearForm();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _addBill();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Add Bill'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmountPreview() {
    try {
      final amount = double.parse(_amountController.text);
      return formatCurrencyFull(amount);
    } catch (e) {
      return 'Invalid amount';
    }
  }

  void _clearForm() {
    _titleController.clear();
    _vendorController.clear();
    _amountController.clear();
  }

  void _addBill() {
    try {
      final amount = double.parse(_amountController.text);
      if (_titleController.text.isNotEmpty && _vendorController.text.isNotEmpty && amount > 0) {
        setState(() {
          bills.add(Bill(
            id: (bills.length + 1).toString(),
            title: _titleController.text,
            vendor: _vendorController.text,
            amount: amount,
            due: DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0],
            repeat: 'monthly',
            category: 'Other',
            status: 'upcoming',
          ));
          _showAddBill = false;
          _clearForm();
        });
      }
    } catch (e) {
      // Handle invalid amount
    }
  }

  double _getThisMonthTotal() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return bills
        .where((bill) => bill.due.startsWith(currentMonth))
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  double _getNext7DaysTotal() {
    final now = DateTime.now();
    final endOf7Days = now.add(const Duration(days: 7));

    return bills
        .where((bill) {
          final dueDate = DateTime.parse('${bill.due}T00:00:00');
          return dueDate.isAfter(now) && dueDate.isBefore(endOf7Days);
        })
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }

  void _markPaid(String billId) {
    setState(() {
      final index = bills.indexWhere((bill) => bill.id == billId);
      if (index != -1) {
        bills[index] = bills[index].copyWith(status: 'paid');
      }
    });
  }

  void _showAmountBottomSheet(double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                formatCurrencyFull(amount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8C00),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Full amount: ${formatCurrencyFull(amount)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}