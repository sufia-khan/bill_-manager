import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/trial_service.dart';

class AddBillScreen extends StatefulWidget {
  final Bill? billToEdit;

  const AddBillScreen({super.key, this.billToEdit});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Subscriptions';
  String _selectedRepeat = 'None';
  DateTime? _selectedDueDate;
  int? _repeatCount; // null = unlimited
  String? _reminderTiming; // Will be set from provider default
  TimeOfDay? _notificationTime; // Will be set from provider default

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Subscriptions', 'emoji': '📋'},
    {'name': 'Rent', 'emoji': '🏠'},
    {'name': 'Utilities', 'emoji': '💡'},
    {'name': 'Electricity', 'emoji': '⚡'},
    {'name': 'Water', 'emoji': '💧'},
    {'name': 'Gas', 'emoji': '🔥'},
    {'name': 'Internet', 'emoji': '🌐'},
    {'name': 'Phone', 'emoji': '📱'},
    {'name': 'Streaming', 'emoji': '📺'},
    {'name': 'Groceries', 'emoji': '🛒'},
    {'name': 'Transport', 'emoji': '🚌'},
    {'name': 'Fuel', 'emoji': '⛽'},
    {'name': 'Insurance', 'emoji': '🛡️'},
    {'name': 'Health', 'emoji': '💊'},
    {'name': 'Medical', 'emoji': '🏥'},
    {'name': 'Education', 'emoji': '📚'},
    {'name': 'Entertainment', 'emoji': '🎬'},
    {'name': 'Credit Card', 'emoji': '💳'},
    {'name': 'Loan', 'emoji': '💰'},
    {'name': 'Taxes', 'emoji': '📝'},
    {'name': 'Savings', 'emoji': '🏦'},
    {'name': 'Donations', 'emoji': '❤️'},
    {'name': 'Home Maintenance', 'emoji': '🔧'},
    {'name': 'HOA', 'emoji': '🏘️'},
    {'name': 'Gym', 'emoji': '💪'},
    {'name': 'Childcare', 'emoji': '👶'},
    {'name': 'Pets', 'emoji': '🐾'},
    {'name': 'Travel', 'emoji': '✈️'},
    {'name': 'Parking', 'emoji': '🅿️'},
    {'name': 'Other', 'emoji': '📁'},
  ];

  final List<String> _repeatOptions = [
    'None',
    '1 Minute (Testing)', // For testing recurring bills
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
  ];

  @override
  void initState() {
    super.initState();

    // Load default notification settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = context.read<NotificationSettingsProvider>();
      setState(() {
        _reminderTiming = notificationProvider.reminderTiming;
        _notificationTime = notificationProvider.notificationTime;
      });
    });

    // If editing, prefill the fields
    if (widget.billToEdit != null) {
      _prefillFieldsForEdit();
    } else {
      // Set default due date to 30 days from now for new bills
      _selectedDueDate = DateTime.now().add(const Duration(days: 30));
      _dueController.text = _formatDate(_selectedDueDate!);
    }
  }

  void _prefillFieldsForEdit() {
    final bill = widget.billToEdit!;
    _titleController.text = bill.title;
    _amountController.text = bill.amount.toString();
    _selectedCategory = bill.category;
    _selectedRepeat = _capitalizeFirst(bill.repeat);
    _selectedDueDate = DateTime.parse('${bill.due}T00:00:00');
    _dueController.text = _formatDate(_selectedDueDate!);

    // Get notes and notification settings from BillHive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final billProvider = context.read<BillProvider>();
        final notificationProvider = context
            .read<NotificationSettingsProvider>();
        final billHive = billProvider.bills.firstWhere((b) => b.id == bill.id);
        setState(() {
          _notesController.text = billHive.notes ?? '';
          // Load notification settings from bill or use defaults
          _reminderTiming =
              billHive.reminderTiming ?? notificationProvider.reminderTiming;
          if (billHive.notificationTime != null) {
            final parts = billHive.notificationTime!.split(':');
            _notificationTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          } else {
            _notificationTime = notificationProvider.notificationTime;
          }
        });
      } catch (e) {
        // Notes not found, leave empty
      }
    });
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getAmountPreview() {
    try {
      final amount = double.parse(_amountController.text);
      return '\$${amount.toStringAsFixed(2)}';
    } catch (e) {
      return '\$0.00';
    }
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate notification time is in the future
    if (!_validateNotificationTime()) {
      return;
    }

    try {
      final billProvider = context.read<BillProvider>();

      // Check bill limit for new bills (free users)
      if (widget.billToEdit == null) {
        final currentBillCount = billProvider.bills.length;
        if (TrialService.hasReachedBillLimit(currentBillCount)) {
          _showProFeatureDialog('Unlimited Bills');
          return;
        }
      }

      if (widget.billToEdit != null) {
        // Edit mode - update existing bill
        final billHive = billProvider.bills.firstWhere(
          (b) => b.id == widget.billToEdit!.id,
        );

        final updatedBill = billHive.copyWith(
          title: _titleController.text.trim(),
          vendor: _titleController.text.trim(), // Use title as vendor
          amount: double.parse(_amountController.text),
          dueAt:
              _selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          category: _selectedCategory,
          repeat: _selectedRepeat.toLowerCase(),
          updatedAt: DateTime.now(),
          clientUpdatedAt: DateTime.now(),
          needsSync: true,
          reminderTiming: _reminderTiming,
          notificationTime: _notificationTime != null
              ? '${_notificationTime!.hour}:${_notificationTime!.minute}'
              : null,
        );

        await billProvider.updateBill(updatedBill);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill updated successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Add mode - create new bill
        await billProvider.addBill(
          title: _titleController.text.trim(),
          vendor: _titleController.text.trim(), // Use title as vendor
          amount: double.parse(_amountController.text),
          dueAt:
              _selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          category: _selectedCategory,
          repeat: _selectedRepeat.toLowerCase(),
          repeatCount: _repeatCount,
          reminderTiming: _reminderTiming,
          notificationTime: _notificationTime != null
              ? '${_notificationTime!.hour}:${_notificationTime!.minute}'
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill saved successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bill: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _validateNotificationTime() {
    if (_selectedDueDate == null ||
        _reminderTiming == null ||
        _notificationTime == null) {
      return true; // Skip validation if not all fields are set
    }

    final now = DateTime.now();
    final dueDate = _selectedDueDate!;

    // Calculate notification date based on reminder timing
    int daysOffset = 0;
    switch (_reminderTiming) {
      case '1 Day Before':
        daysOffset = 1;
        break;
      case '2 Days Before':
        daysOffset = 2;
        break;
      case '1 Week Before':
        daysOffset = 7;
        break;
      case 'Same Day':
      default:
        daysOffset = 0;
    }

    final notificationDate = dueDate.subtract(Duration(days: daysOffset));
    final notificationDateTime = DateTime(
      notificationDate.year,
      notificationDate.month,
      notificationDate.day,
      _notificationTime!.hour,
      _notificationTime!.minute,
    );

    // Check if notification time is in the past
    if (notificationDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.access_time, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select a time that will be in the future from the due date of the bill.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF97316), // Orange color
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    return true;
  }

  void _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _dueController.text = _formatDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.billToEdit != null ? 'Edit Bill' : 'Add New Bill',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF97316),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF374151),
            size: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveBill,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              widget.billToEdit != null ? 'Update' : 'Save',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============ REQUIRED SECTION CONTAINER ============
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF97316,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF97316),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF97316),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Title field
                    _buildTextField(
                      controller: _titleController,
                      label: 'Bill Title',
                      hint: 'e.g., Electricity Bill',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a bill title';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Amount and Due Date in a row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount field
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                controller: _amountController,
                                label: 'Amount',
                                hint: '0.00',
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter an amount';
                                  }
                                  try {
                                    final amount = double.parse(value);
                                    if (amount <= 0) {
                                      return 'Amount must be greater than 0';
                                    }
                                  } catch (e) {
                                    return 'Please enter a valid amount';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                              if (_amountController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _getAmountPreview(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Due date field
                        Expanded(
                          child: InkWell(
                            onTap: _selectDueDate,
                            borderRadius: BorderRadius.circular(8),
                            child: IgnorePointer(
                              child: _buildTextField(
                                controller: _dueController,
                                label: 'Due Date',
                                hint: 'Select date',
                                readOnly: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please select a due date';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Category selector
                    _buildCategorySelector(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ============ OPTIONAL SECTION CONTAINER ============
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF), // Light blue tint
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF3B82F6),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Optional',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              Text(
                                'Customize your bill reminder',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Repeat selector
                    _buildRepeatSelector(),

                    // Repeat count selector
                    if (_selectedRepeat.toLowerCase() != 'none') ...[
                      const SizedBox(height: 16),
                      _buildRepeatCountSelector(),
                    ],

                    const SizedBox(height: 16),

                    // Notification Settings Section
                    _buildNotificationSettings(),

                    const SizedBox(height: 16),

                    // Notes field (Pro feature)
                    if (TrialService.canUseNotes())
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hint: 'Add any additional details...',
                        maxLines: 3,
                        validator: null,
                      )
                    else
                      _buildProLockedField(
                        label: 'Notes',
                        hint: 'Add notes to your bills',
                        featureName: 'Bill Notes',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    widget.billToEdit != null ? 'Update Bill' : 'Save Bill',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            if (validator != null)
              const Text(
                ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          readOnly: readOnly,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFE5CC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFE5CC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    Map<String, dynamic> selectedCategoryData = _categories.last;
    try {
      selectedCategoryData = _categories.firstWhere(
        (category) => category['name'] == _selectedCategory,
      );
    } catch (e) {
      // Use default if not found
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showCategoryBottomSheet,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFE5CC)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Text(
                  selectedCategoryData['emoji'] ?? '📁',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCategoryData['name'] ?? 'Other',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_up, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepeatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Repeat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showRepeatBottomSheet,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFE5CC)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedRepeat,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_up, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showProFeatureDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFD4AF37),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$featureName is a Pro Feature',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TrialService.getMembershipStatus() == MembershipStatus.free
                  ? 'Your free trial has ended. Upgrade to Pro to unlock:'
                  : 'Upgrade to Pro to unlock:',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            _buildProFeatureRow('Recurring bills (weekly, monthly, yearly)'),
            _buildProFeatureRow('Multiple reminder times'),
            _buildProFeatureRow('Unlimited bills'),
            _buildProFeatureRow('Cloud sync & backup'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pro subscription coming soon!'),
                  backgroundColor: Color(0xFFD4AF37),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  Widget _buildProFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFD4AF37), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildProLockedField({
    required String label,
    required String hint,
    required String featureName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showProFeatureDialog(featureName),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xFFD4AF37),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRepeatBottomSheet() {
    final canUseRecurring = TrialService.canAddRecurringBill();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Repeat',
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
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _repeatOptions.map((option) {
                      final isSelected = option == _selectedRepeat;
                      final isRecurring = option != 'None';
                      final isLocked = isRecurring && !canUseRecurring;

                      return Opacity(
                        opacity: isLocked ? 0.6 : 1.0,
                        child: InkWell(
                          onTap: isLocked
                              ? () => _showProFeatureDialog('Recurring Bills')
                              : () {
                                  setState(() {
                                    _selectedRepeat = option;
                                  });
                                  Navigator.of(context).pop();
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFFF97316,
                                    ).withValues(alpha: 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF97316)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                if (isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    color: Color(0xFFF97316),
                                    size: 20,
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Category',
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
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Add Custom Category Button at the top
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          _showAddCustomCategoryDialog();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF97316).withValues(alpha: 0.15),
                                const Color(0xFFF97316).withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFF97316),
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFFF97316),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add Custom Category',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF97316),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFFF97316),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Existing categories
                      ..._categories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value;
                        final isSelected =
                            category['name'] == _selectedCategory;
                        final maxCategories = TrialService.getMaxCategories();
                        final isLocked =
                            maxCategories != -1 && index >= maxCategories;

                        return Opacity(
                          opacity: isLocked ? 0.6 : 1.0,
                          child: InkWell(
                            onTap: isLocked
                                ? () => _showProFeatureDialog('All Categories')
                                : () {
                                    setState(() {
                                      _selectedCategory = category['name'];
                                    });
                                    Navigator.of(context).pop();
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFFF97316,
                                      ).withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFF97316)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    category['emoji'] ?? '📁',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      category['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? const Color(0xFFF97316)
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  if (isLocked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4AF37),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  else if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      color: Color(0xFFF97316),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepeatCountSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: 0.1),
            const Color(0xFFF97316).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.repeat,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How many times?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _repeatCount == null
                          ? 'Repeats forever ♾️'
                          : 'Repeats $_repeatCount ${_repeatCount == 1 ? 'time' : 'times'} 🔄',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRepeatChip('Forever', null, '♾️'),
              _buildRepeatChip('2 times', 2, '2️⃣'),
              _buildRepeatChip('3 times', 3, '3️⃣'),
              _buildRepeatChip('5 times', 5, '5️⃣'),
              _buildRepeatChip('10 times', 10, '🔟'),
              _buildRepeatChip('Custom', -1, '✏️'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatChip(String label, int? count, String emoji) {
    final isSelected = _repeatCount == count;
    return InkWell(
      onTap: () {
        if (count == -1) {
          _showCustomRepeatDialog();
        } else {
          setState(() => _repeatCount = count);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF97316) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomRepeatDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('✏️'),
            SizedBox(width: 8),
            Text(
              'Custom Repeat Count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many times should this bill repeat?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Number of times',
                hintText: 'e.g., 12',
                prefixIcon: const Icon(Icons.repeat, color: Color(0xFFF97316)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFF97316),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                setState(() => _repeatCount = value);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    final notificationProvider = context.watch<NotificationSettingsProvider>();

    // Use defaults if not set
    final reminderTiming =
        _reminderTiming ?? notificationProvider.reminderTiming;
    final notificationTime =
        _notificationTime ?? notificationProvider.notificationTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: 0.1),
            const Color(0xFFF97316).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notification Settings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reminder Timing
          const Text(
            'Remind me',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showReminderTimingPicker(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Color(0xFFF97316),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reminderTiming,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Notification Time
          const Text(
            'At time',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showNotificationTimePicker(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Color(0xFFF97316),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatTimeOfDay(notificationTime),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReminderTimingPicker() {
    // Calculate days until due date
    final now = DateTime.now();
    final dueDate = _selectedDueDate ?? now;
    final daysUntilDue = dueDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    // Check if user can use multiple reminders (Pro feature)
    final canUseMultipleReminders = TrialService.isFeatureAvailable(
      'multiple_reminders',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final options = [
          'Same Day',
          '1 Day Before',
          '2 Days Before',
          '1 Week Before',
        ];

        // Determine which options should be disabled (due date too close)
        bool isOptionDisabled(String option) {
          if (option == 'Same Day') return false; // Always available
          if (option == '1 Day Before') return daysUntilDue < 1;
          if (option == '2 Days Before') return daysUntilDue < 2;
          if (option == '1 Week Before') return daysUntilDue < 7;
          return false;
        }

        // Check if option is Pro-only (free users only get Same Day)
        bool isProOnly(String option) {
          if (canUseMultipleReminders) return false;
          return option != 'Same Day';
        }

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Remind me',
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
                ...options.map((option) {
                  final isSelected = option == _reminderTiming;
                  final isDisabled = isOptionDisabled(option);
                  final isLocked = isProOnly(option);

                  return Opacity(
                    opacity: (isDisabled || isLocked) ? 0.6 : 1.0,
                    child: InkWell(
                      onTap: isDisabled
                          ? null
                          : isLocked
                          ? () => _showProFeatureDialog('Multiple Reminders')
                          : () {
                              setState(() {
                                _reminderTiming = option;
                              });
                              Navigator.of(context).pop();
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF97316).withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF97316)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            if (isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else if (isSelected)
                              const Icon(
                                Icons.check,
                                color: Color(0xFFF97316),
                                size: 20,
                              )
                            else if (isDisabled)
                              const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF9CA3AF),
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (daysUntilDue < 7) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE5CC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Color(0xFFF97316),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            daysUntilDue == 0
                                ? 'Bill is due today. Only "Same Day" reminder is available.'
                                : 'Some options are disabled because the due date is only $daysUntilDue day${daysUntilDue == 1 ? '' : 's'} away.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationTimePicker() async {
    final notificationProvider = context.read<NotificationSettingsProvider>();
    final time = await showTimePicker(
      context: context,
      initialTime: _notificationTime ?? notificationProvider.notificationTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFF97316)),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _notificationTime = time;
      });

      // Validate the selected time immediately
      _validateNotificationTimeAfterSelection();
    }
  }

  void _validateNotificationTimeAfterSelection() {
    if (_selectedDueDate == null ||
        _reminderTiming == null ||
        _notificationTime == null) {
      return;
    }

    final now = DateTime.now();
    final dueDate = _selectedDueDate!;

    // Calculate notification date based on reminder timing
    int daysOffset = 0;
    switch (_reminderTiming) {
      case '1 Day Before':
        daysOffset = 1;
        break;
      case '2 Days Before':
        daysOffset = 2;
        break;
      case '1 Week Before':
        daysOffset = 7;
        break;
      case 'Same Day':
      default:
        daysOffset = 0;
    }

    final notificationDate = dueDate.subtract(Duration(days: daysOffset));
    final notificationDateTime = DateTime(
      notificationDate.year,
      notificationDate.month,
      notificationDate.day,
      _notificationTime!.hour,
      _notificationTime!.minute,
    );

    // Check if notification time is in the past
    if (notificationDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.access_time, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select a time that will be in the future from the due date of the bill.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF97316), // Orange color
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _showAddCustomCategoryDialog() {
    final categoryNameController = TextEditingController();
    const String defaultEmoji = '📋'; // Single default icon for all categories

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Color(0xFFF97316)),
            SizedBox(width: 8),
            Text(
              'Add Custom Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Name Input
            TextField(
              controller: categoryNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Car Payment',
                prefixIcon: const Icon(Icons.label, color: Color(0xFFF97316)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFF97316),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final categoryName = categoryNameController.text.trim();
              if (categoryName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a category name'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              // Add the new category to the list with default icon
              setState(() {
                _categories.insert(0, {
                  'name': categoryName,
                  'emoji': defaultEmoji,
                });
                _selectedCategory = categoryName;
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Category "$categoryName" added successfully!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }
}
