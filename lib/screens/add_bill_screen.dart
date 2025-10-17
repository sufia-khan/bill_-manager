import 'package:flutter/material.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Subscriptions';
  String _selectedRepeat = 'Monthly';
  DateTime? _selectedDueDate;

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
    'None', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'
  ];

  @override
  void initState() {
    super.initState();
    // Set default due date to 30 days from now
    _selectedDueDate = DateTime.now().add(const Duration(days: 30));
    _dueController.text = _formatDate(_selectedDueDate!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vendorController.dispose();
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

  void _saveBill() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Create the new bill
    final newBill = {
      'title': _titleController.text.trim(),
      'vendor': _vendorController.text.trim(),
      'amount': double.parse(_amountController.text),
      'due': _selectedDueDate != null ? _formatDate(_selectedDueDate!) : '',
      'repeat': _selectedRepeat,
      'category': _selectedCategory,
      'notes': _notesController.text.trim(),
      'status': 'upcoming',
    };

    // TODO: Add bill to your state management/backend
    print('New bill: $newBill');

    // Show success message and close
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill saved successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop();
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
        title: const Text(
          'Add New Bill',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFFF8C00), size: 20),
        ),
        actions: [
          TextButton(
            onPressed: _saveBill,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8C00),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              const SizedBox(height: 20),

              // Amount field
              _buildTextField(
                controller: _amountController,
                label: 'Amount',
                hint: '0.00',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                  setState(() {}); // Update preview
                },
              ),

              // Amount preview
              if (_amountController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    'Preview: ${_getAmountPreview()}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFF8C00),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Due date field
              InkWell(
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

              const SizedBox(height: 20),

              // Category selector
              _buildCategorySelector(),

              const SizedBox(height: 20),

              // Repeat selector
              _buildRepeatSelector(),

              const SizedBox(height: 20),

              // Notes field
              _buildTextField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Add any additional details...',
                maxLines: 3,
                validator: null,
              ),

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Bill',
                    style: TextStyle(
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
              borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
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
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
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
                const Icon(
                  Icons.keyboard_arrow_up,
                  color: Color(0xFF6B7280),
                ),
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
                const Icon(
                  Icons.keyboard_arrow_up,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRepeatBottomSheet() {
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

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRepeat = option;
                          });
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8C00).withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF8C00)
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
                                        ? const Color(0xFFFF8C00)
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  color: Color(0xFFFF8C00),
                                  size: 20,
                                ),
                            ],
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
                    children: _categories.map((category) {
                      final isSelected = category['name'] == _selectedCategory;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category['name'];
                          });
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8C00).withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF8C00)
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
                                        ? const Color(0xFFFF8C00)
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  color: Color(0xFFFF8C00),
                                  size: 20,
                                ),
                            ],
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
}