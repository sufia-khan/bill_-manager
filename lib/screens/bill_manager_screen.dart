import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../widgets/custom_icons.dart';
import '../widgets/animated_subtitle.dart';
import '../utils/formatters.dart';
import 'add_bill_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';

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
              const SizedBox(height: 32),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Categories',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCategoryTabs(),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isSelected = selectedCategory == category['name'];

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => _handleCategoryTap(index),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                key: _categoryKeys[index],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF8C00) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Icon(
                        category['icon'],
                        size: 16,
                        color: Colors.white,
                      ),
                    if (isSelected) const SizedBox(width: 6),
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
    );
  }

  void _handleCategoryTap(int index) {
    setState(() {
      selectedCategory = categories[index]['name'];
    });

    // Auto-scroll functionality
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCategory(index);
    });
  }

  void _scrollToCategory(int index) {
    if (!_scrollController.hasClients) return;

    final tabKey = _categoryKeys[index];
    final tabContext = tabKey.currentContext;

    if (tabContext != null) {
      final RenderBox? tabRenderBox = tabContext.findRenderObject() as RenderBox?;
      if (tabRenderBox != null) {
        final tabPosition = tabRenderBox.localToGlobal(Offset.zero);
        final tabWidth = tabRenderBox.size.width;
        final screenWidth = MediaQuery.of(context).size.width;
        final padding = 32; // Horizontal padding from the scroll view

        // Calculate the center position for the tab
        final targetCenterPosition = (screenWidth / 2) - (tabWidth / 2);
        final currentTabPosition = tabPosition.dx;

        // Only scroll if tab needs centering
        if ((currentTabPosition < targetCenterPosition - 50) ||
            (currentTabPosition > targetCenterPosition + 50)) {

          // Calculate the scroll offset needed to center the tab
          final scrollOffset = currentTabPosition - targetCenterPosition + _scrollController.offset;
          final targetOffset = scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

          _animateScroll(targetOffset);
        }
      }
    }
  }

  // Simplified helper to get last visible tab index
  int _getLastVisibleTabIndex() {
    final screenWidth = MediaQuery.of(context).size.width - 32; // Account for padding

    for (int i = 0; i < categories.length && i < _categoryKeys.length; i++) {
      final context = _categoryKeys[i].currentContext;
      if (context != null) {
        final RenderBox? tabRenderBox = context.findRenderObject() as RenderBox?;
        if (tabRenderBox != null) {
          final tabPosition = tabRenderBox.localToGlobal(Offset.zero);
          final tabRight = tabPosition.dx + tabRenderBox.size.width - 16; // Account for padding

          // If tab is visible within screen bounds
          if (tabRight <= screenWidth) {
            return i;
          }
        }
      }
    }

    return -1;
  }

  void _animateScroll(double offset) {
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade300,
                    Colors.grey.shade200,
                  ],
                  ),
                ),
              ),
            ),
          
          const SizedBox(width: 12),
          Icon(
            Icons.circle,
            size: 6,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade300,
                    Colors.grey.shade200,
                  ],
                ),
              ),
            ),
          )]));
        
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
          margin: const EdgeInsets.only(bottom: 16),
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
              // Top row - Title and amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Icon and title
                  Expanded(
                    flex: 6,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                                '${bill.vendor} • ${bill.repeat}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right side - Amount and info icon
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: 'Amount: ${formatCurrencyFull(bill.amount)}',
                                child: Text(
                                  _compactAmounts ? formatCurrencyShort(bill.amount) : formatCurrencyFull(bill.amount),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Tap to view full value (mobile) / Hover to view full value (desktop)',
                              child: InkWell(
                                onTap: () => _showAmountBottomSheet(bill.amount),
                                borderRadius: BorderRadius.circular(12),
                                child: Semantics(
                                  label: 'View full amount: ${formatCurrencyFull(bill.amount)}',
                                  hint: 'Double tap to view full amount in bottom sheet',
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${getRelativeDateText(bill.due)} — ${getFormattedDate(bill.due)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Third row - Status badge and mark paid button
              Row(
                children: [
                  if (bill.status != 'paid')
                    Expanded(
                      flex: 6,
                      child: _buildStatusBadge(bill.status),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bill.status != 'paid')
                          InkWell(
                            onTap: () => _markPaid(bill.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF8C00),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Mark paid',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else
                          _buildStatusBadge(bill.status),
                      ],
                    ),
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
    Color textColor;

    switch (status) {
      case 'overdue':
        textColor = const Color(0xFFDC2626);
        break;
      case 'paid':
        textColor = const Color(0xFF059669);
        break;
      default: // due, upcoming
        textColor = const Color(0xFFD97706);
    }

    return Text(
      status.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
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
        if (index == 2) { // Calendar tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CalendarScreen(),
            ),
          );
        } else if (index == 3) { // Settings tab
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