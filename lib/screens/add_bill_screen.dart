import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/trial_service.dart';
import '../services/user_preferences_service.dart';

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
  int _repeatCount = 12; // Default to 12 times
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

    // If editing, prefill the fields (including notification time from bill)
    if (widget.billToEdit != null) {
      _prefillFieldsForEdit();
    } else {
      // For new bills, load default notification settings from user preferences
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notificationProvider = context
            .read<NotificationSettingsProvider>();

        // Get default reminder time from user preferences (or 9:00 if not set)
        final defaultTime = UserPreferencesService.getDefaultReminderTime();
        final parts = defaultTime.split(':');
        final defaultTimeOfDay = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );

        setState(() {
          _reminderTiming = notificationProvider.reminderTiming;
          _notificationTime = defaultTimeOfDay;
        });
      });

      // Set default due date to 30 days from now for new bills
      final defaultDate = DateTime.now().add(const Duration(days: 30));
      _selectedDueDate = DateTime(
        defaultDate.year,
        defaultDate.month,
        defaultDate.day,
      );
      _dueController.text = _formatDate(_selectedDueDate!);
      debugPrint('📅 initState: Set default due date to $_selectedDueDate');
      debugPrint('📅 initState: _dueController.text = ${_dueController.text}');
    }
  }

  void _prefillFieldsForEdit() {
    final bill = widget.billToEdit!;
    _titleController.text = bill.title;
    _amountController.text = bill.amount.toString();
    _selectedCategory = bill.category;
    _selectedRepeat = _capitalizeFirst(bill.repeat);
    final parsedDate = DateTime.parse('${bill.due}T00:00:00');
    _selectedDueDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );
    _dueController.text = _formatDate(_selectedDueDate!);

    // Get notes and notification settings from BillHive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final billProvider = context.read<BillProvider>();
        final notificationProvider = context
            .read<NotificationSettingsProvider>();
        final billHive = billProvider.bills.firstWhere((b) => b.id == bill.id);

        // Priority for notification time when editing:
        // 1. Bill's existing time
        // 2. User's preferred time from settings
        // 3. Default (9:00)
        TimeOfDay timeToUse;
        if (billHive.notificationTime != null) {
          // Use bill's existing time
          final parts = billHive.notificationTime!.split(':');
          timeToUse = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        } else {
          // Use user's preferred time from settings
          final defaultTime = UserPreferencesService.getDefaultReminderTime();
          final parts = defaultTime.split(':');
          timeToUse = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }

        setState(() {
          _notesController.text = billHive.notes ?? '';
          _repeatCount =
              billHive.repeatCount ?? 12; // Default to 12 if was unlimited
          // Load reminder timing from bill or use defaults
          _reminderTiming =
              billHive.reminderTiming ?? notificationProvider.reminderTiming;
          _notificationTime = timeToUse;
        });
      } catch (e) {
        // Bill not found, use defaults
        final defaultTime = UserPreferencesService.getDefaultReminderTime();
        final parts = defaultTime.split(':');
        setState(() {
          _notificationTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
          _reminderTiming = context
              .read<NotificationSettingsProvider>()
              .reminderTiming;
        });
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
      // Only counts bills created AFTER trial expiration (grandfathering)
      // Check bill limit for new bills (free users)
      // Only counts bills created AFTER trial expiration (grandfathering)
      if (widget.billToEdit == null && !TrialService.canAccessProFeatures()) {
        final freeTierBillCount = billProvider.getFreeTierUsedCount();
        if (freeTierBillCount >= TrialService.freeMaxBills) {
          final remainingBills = billProvider.getRemainingFreeTierBills();
          _showProFeatureDialog(
            'Unlimited Bills',
            customMessage:
                'You can add up to ${TrialService.freeMaxBills} bills on the free plan. You have $remainingBills remaining. Upgrade to Pro for unlimited bills.',
          );
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
              ? '${_notificationTime!.hour.toString().padLeft(2, '0')}:${_notificationTime!.minute.toString().padLeft(2, '0')}'
              : null,
        );

        print(
          '📝 Updating bill: ${updatedBill.title}, Due: ${updatedBill.dueAt}, Notif: ${updatedBill.notificationTime}',
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
        // For 1-minute testing, set dueAt to include the notification time

        // CRITICAL: Check if _selectedDueDate is null
        if (_selectedDueDate == null) {
          debugPrint(
            '⚠️ WARNING: _selectedDueDate is NULL! This should not happen.',
          );
          debugPrint('   _dueController.text = ${_dueController.text}');
        }

        DateTime dueAt =
            _selectedDueDate ?? DateTime.now().add(const Duration(days: 30));

        print('🔍 _saveBill: _selectedDueDate = $_selectedDueDate');
        print('🔍 _saveBill: initial dueAt = $dueAt');
        print('🔍 _saveBill: _selectedRepeat = $_selectedRepeat');

        // For testing mode, keep the selected date but add notification time if provided
        if (_selectedRepeat.toLowerCase() == '1 minute (testing)' &&
            _notificationTime != null) {
          // Keep the selected date, just add the notification time
          dueAt = DateTime(
            dueAt.year,
            dueAt.month,
            dueAt.day,
            _notificationTime!.hour,
            _notificationTime!.minute,
          );
        }

        // Only pass repeatCount if it's a recurring bill
        final int? repeatCountToSave = _selectedRepeat.toLowerCase() != 'none'
            ? _repeatCount
            : null;

        debugPrint('📝 Saving bill with repeatCount: $repeatCountToSave');
        debugPrint('   _repeatCount state: $_repeatCount');
        debugPrint('   _selectedRepeat: $_selectedRepeat');
        debugPrint('📅 Due date being saved: $dueAt');
        debugPrint('   _selectedDueDate: $_selectedDueDate');
        debugPrint('   _dueController.text: ${_dueController.text}');
        debugPrint('   dueAt ISO: ${dueAt.toIso8601String()}');
        debugPrint(
          '   dueAt date only: ${dueAt.toIso8601String().split('T')[0]}',
        );
        debugPrint('⏰ Notification time: $_notificationTime');
        debugPrint('   Reminder timing: $_reminderTiming');

        debugPrint('\n🚀 CALLING billProvider.addBill with:');
        debugPrint('   title: ${_titleController.text.trim()}');
        debugPrint('   dueAt: $dueAt');
        debugPrint('   dueAt ISO: ${dueAt.toIso8601String()}');
        debugPrint('   repeat: ${_selectedRepeat.toLowerCase()}');
        debugPrint('   reminderTiming: $_reminderTiming');
        debugPrint(
          '   notificationTime: ${_notificationTime != null ? '${_notificationTime!.hour.toString().padLeft(2, '0')}:${_notificationTime!.minute.toString().padLeft(2, '0')}' : null}\n',
        );

        await billProvider.addBill(
          title: _titleController.text.trim(),
          vendor: _titleController.text.trim(), // Use title as vendor
          amount: double.parse(_amountController.text),
          dueAt: dueAt,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          category: _selectedCategory,
          repeat: _selectedRepeat.toLowerCase(),
          repeatCount: repeatCountToSave,
          reminderTiming: _reminderTiming,
          notificationTime: _notificationTime != null
              ? '${_notificationTime!.hour.toString().padLeft(2, '0')}:${_notificationTime!.minute.toString().padLeft(2, '0')}'
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
    debugPrint('\n📅 ========== DATE PICKER CALLED ==========');
    debugPrint('📅 Current _selectedDueDate: $_selectedDueDate');
    debugPrint('📅 Current _dueController.text: ${_dueController.text}');

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    debugPrint('📅 Date picker returned: $picked');
    if (picked != null) {
      setState(() {
        // Normalize the date to midnight to avoid time zone issues
        _selectedDueDate = DateTime(picked.year, picked.month, picked.day);
        _dueController.text = _formatDate(_selectedDueDate!);
        debugPrint('📅 ✅ Updated _selectedDueDate to: $_selectedDueDate');
        debugPrint(
          '📅 ✅ Updated _dueController.text to: ${_dueController.text}',
        );
        debugPrint('📅 ========================================\n');
      });
    } else {
      debugPrint('📅 ❌ User cancelled date picker');
      debugPrint('📅 ========================================\n');
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

  void _showProFeatureDialog(String featureName, {String? customMessage}) {
    // Get feature details
    final featureDetails = _getFeatureDetails(featureName);

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
              child: Icon(
                featureDetails['icon'] as IconData,
                color: const Color(0xFFD4AF37),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                featureName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feature-specific description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE5CC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_open,
                          color: Color(0xFFF97316),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            featureDetails['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      customMessage ??
                          (featureDetails['description'] as String),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trial status message
              Text(
                TrialService.getMembershipStatus() == MembershipStatus.free
                    ? 'Your free trial has ended. Upgrade to Pro to unlock all features.'
                    : 'Upgrade to Pro to unlock all premium features.',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Other Pro features
              const Text(
                'Other Pro Features:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              ...TrialService.getProFeaturesList()
                  .where((f) => f['title'] != featureDetails['title'])
                  .take(4)
                  .map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFFD4AF37),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature['title'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFeatureDetails(String featureName) {
    switch (featureName) {
      case 'Recurring Bills':
        return {
          'icon': Icons.repeat,
          'title': 'Set Up Recurring Bills',
          'description':
              'Automatically create bills that repeat weekly, monthly, or yearly. Never manually add the same bill again - set it once and forget it.',
        };
      case 'Multiple Reminders':
        return {
          'icon': Icons.notifications_active,
          'title': 'Multiple Reminder Options',
          'description':
              'Get notified 1 day, 2 days, or 1 week before bills are due. Choose the perfect reminder timing for each bill.',
        };
      case 'Unlimited Bills':
        return {
          'icon': Icons.all_inclusive,
          'title': 'Track Unlimited Bills',
          'description':
              'Add as many bills as you need without any limits. Free plan is limited to 5 bills, Pro gives you unlimited tracking.',
        };
      case 'All Categories':
        return {
          'icon': Icons.category,
          'title': 'Access All Categories',
          'description':
              'Choose from 30+ bill categories to organize your expenses. Free plan only has 10 basic categories.',
        };
      case 'Bill Notes':
        return {
          'icon': Icons.note,
          'title': 'Add Notes to Bills',
          'description':
              'Keep important information with each bill. Add account numbers, payment methods, or any details you need to remember.',
        };
      default:
        return {
          'icon': Icons.workspace_premium,
          'title': 'Pro Feature',
          'description':
              'This is a premium feature available only to Pro subscribers. Upgrade to unlock all Pro features.',
        };
    }
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
                      }),
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

  // Calculate the end date based on repeat type and count
  String _getRecurringPreviewText() {
    if (_selectedDueDate == null) return '';

    final startDate = _selectedDueDate!;
    DateTime endDate;
    String frequencyText;

    switch (_selectedRepeat.toLowerCase()) {
      case 'weekly':
        endDate = startDate.add(Duration(days: 7 * (_repeatCount - 1)));
        frequencyText = 'weekly';
        break;
      case 'monthly':
        endDate = DateTime(
          startDate.year,
          startDate.month + (_repeatCount - 1),
          startDate.day,
        );
        frequencyText = 'monthly';
        break;
      case 'quarterly':
        endDate = DateTime(
          startDate.year,
          startDate.month + (3 * (_repeatCount - 1)),
          startDate.day,
        );
        frequencyText = 'quarterly';
        break;
      case 'yearly':
        endDate = DateTime(
          startDate.year + (_repeatCount - 1),
          startDate.month,
          startDate.day,
        );
        frequencyText = 'yearly';
        break;
      case '1 minute (testing)':
        endDate = startDate.add(Duration(minutes: _repeatCount - 1));
        frequencyText = 'every minute';
        break;
      default:
        return '';
    }

    // Format the end date nicely
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final endDateStr =
        '${months[endDate.month - 1]} ${endDate.day}, ${endDate.year}';

    return 'This bill will repeat $_repeatCount times $frequencyText, ending on $endDateStr';
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
                      'Number of bills to create',
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
              _buildRepeatChip('2 times', 2, '2️⃣'),
              _buildRepeatChip('3 times', 3, '3️⃣'),
              _buildRepeatChip('5 times', 5, '5️⃣'),
              _buildRepeatChip('10 times', 10, '🔟'),
              _buildRepeatChip('12 times', 12, '📅'),
            ],
          ),
          // Dynamic preview sentence
          if (_selectedDueDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getRecurringPreviewText(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatChip(String label, int count, String emoji) {
    final isSelected = _repeatCount == count;
    return InkWell(
      onTap: () {
        setState(() => _repeatCount = count);
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
