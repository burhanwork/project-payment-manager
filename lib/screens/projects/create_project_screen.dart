import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/animated_gradient_button.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _totalCostController = TextEditingController();
  final _initialPaymentController = TextEditingController();

  final List<TextEditingController> _milestoneControllers = [
    TextEditingController(),
  ];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  ProjectStatus _selectedStatus = ProjectStatus.planned;
  bool _isLoading = false;
  File? _receiptImage;

  @override
  void initState() {
    super.initState();
    _initialPaymentController.addListener(() => setState(() {}));
  }

  void _addMilestone() {
    setState(() {
      _milestoneControllers.add(TextEditingController());
    });
  }

  void _removeMilestone(int index) {
    if (_milestoneControllers.length <= 1) return;
    setState(() {
      _milestoneControllers[index].dispose();
      _milestoneControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clientNameController.dispose();
    _totalCostController.dispose();
    _initialPaymentController.dispose();
    for (final c in _milestoneControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Upload Receipt',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor),
                ),
                title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) setState(() => _receiptImage = File(picked.path));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: AppTheme.accentColor),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) setState(() => _receiptImage = File(picked.path));
                },
              ),
              if (_receiptImage != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                  ),
                  title: Text('Remove Receipt', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _receiptImage = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final milestones = _milestoneControllers
        .map((c) => c.text.trim())
        .where((m) => m.isNotEmpty)
        .toList();

    // Milestone check
    if (milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please add at least one milestone for this project.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final totalCost =
        double.tryParse(_totalCostController.text.trim()) ?? 0.0;
    final initialPayment =
        double.tryParse(_initialPaymentController.text.trim()) ?? 0.0;

    // Receipt required when initial payment is entered
    if (initialPayment > 0 && _receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please upload a payment receipt as proof of the initial payment.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final project = Project(
        id: '',
        name: _nameController.text.trim(),
        clientName: _clientNameController.text.trim(),
        totalCost: totalCost,
        totalPaid: initialPayment,
        remainingBalance: totalCost - initialPayment,
        milestones: milestones,
        startDate: _startDate,
        expectedCompletionDate: _endDate,
        status: _selectedStatus,
        createdBy: '',
        createdAt: DateTime.now(),
      );

      await ref.read(projectsProvider.notifier).addProject(
            project,
            initialPayment: initialPayment,
            receiptPath: _receiptImage?.path,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Project created successfully'),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create project: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Project Details Card
              _buildSectionCard(
                title: 'Project Details',
                icon: Icons.business_center_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Project Name',
                        hintText: 'Enter project name',
                        prefixIcon: Icon(Icons.folder_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a project name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clientNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Client Name',
                        hintText: 'Enter client name',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a client name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalCostController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Total Cost',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the total cost';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _initialPaymentController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Initial Payment',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the initial payment';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount < 0) {
                          return 'Please enter a valid amount';
                        }
                        final totalCost = double.tryParse(_totalCostController.text.trim());
                        if (totalCost != null && amount > totalCost) {
                          return 'Cannot exceed total cost';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 16),

              // Milestones Card
              _buildSectionCard(
                title: 'Milestones',
                icon: Icons.flag_circle_rounded,
                child: Column(
                  children: [
                    ...List.generate(_milestoneControllers.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < _milestoneControllers.length - 1
                              ? 12
                              : 0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _milestoneControllers[index],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Milestone ${index + 1}',
                                  hintText: 'e.g. Frontend UI, Database Setup',
                                  prefixIcon:
                                      const Icon(Icons.check_circle_outline),
                                ),
                                validator: index == 0
                                    ? (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter at least one milestone';
                                        }
                                        return null;
                                      }
                                    : null,
                              ),
                            ),
                            if (_milestoneControllers.length > 1) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeMilestone(index),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.remove_circle_outline,
                                    color: AppTheme.errorColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addMilestone,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Add Milestone',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 100.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 16),

              // Timeline Card
              _buildSectionCard(
                title: 'Timeline',
                icon: Icons.calendar_month_rounded,
                child: Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start Date',
                        date: _startDate,
                        onTap: _pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End Date',
                        date: _endDate,
                        onTap: _pickEndDate,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 200.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 16),

              // Status Card
              _buildSectionCard(
                title: 'Status',
                icon: Icons.flag_rounded,
                child: Row(
                  children: ProjectStatus.values.map((status) {
                    final isSelected = _selectedStatus == status;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: status != ProjectStatus.completed ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedStatus = status),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? _statusGradient(status)
                                  : null,
                              color: isSelected
                                  ? null
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _statusColor(status)
                                    : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _statusIcon(status),
                                    key: ValueKey(isSelected),
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 350.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 16),

              // Payment Receipt Card
              _buildSectionCard(
                title: 'Payment Receipt',
                icon: Icons.receipt_rounded,
                child: Column(
                  children: [
                    if (_receiptImage != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _receiptImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _receiptImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickReceipt,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: Text('Change Receipt',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else
                      GestureDetector(
                        onTap: _pickReceipt,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.cloud_upload_rounded, size: 28, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(height: 12),
                              Text('Upload Receipt',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                              const SizedBox(height: 4),
                              Text(
                                _initialPaymentController.text.trim().isNotEmpty
                                    ? 'Required when initial payment is entered'
                                    : 'Proof of initial payment (optional)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _initialPaymentController.text.trim().isNotEmpty
                                      ? Colors.red.shade400
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 450.ms, duration: 400.ms)
                  .slideY(begin: 0.1, delay: 450.ms, duration: 400.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 32),

              // Submit Button
              AnimatedGradientButton(
                label: 'Create Project',
                icon: Icons.add_circle_rounded,
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    delay: 500.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  LinearGradient _statusGradient(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planned:
        return AppTheme.warningGradient;
      case ProjectStatus.inProgress:
        return AppTheme.accentGradient;
      case ProjectStatus.completed:
        return AppTheme.successGradient;
    }
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planned:
        return AppTheme.warningColor;
      case ProjectStatus.inProgress:
        return AppTheme.accentColor;
      case ProjectStatus.completed:
        return AppTheme.successColor;
    }
  }

  IconData _statusIcon(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planned:
        return Icons.schedule;
      case ProjectStatus.inProgress:
        return Icons.trending_up;
      case ProjectStatus.completed:
        return Icons.check_circle;
    }
  }

  String _statusLabel(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planned:
        return 'Planned';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    Formatters.date(date),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
