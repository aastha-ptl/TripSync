import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';

class CreatePollScreen extends StatefulWidget {
  final String tripId;
  final Poll? existingPoll; // If editing

  const CreatePollScreen({
    super.key,
    required this.tripId,
    this.existingPoll,
  });

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final PollService _pollService = PollService();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  bool _allowMultipleAnswers = false;
  bool _isLoading = false;

  bool get _isEditing => widget.existingPoll != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existingPoll!;
      _questionController.text = p.question;
      _allowMultipleAnswers = p.allowMultipleAnswers;
      for (final opt in p.options) {
        _optionControllers.add(TextEditingController(text: opt.text));
      }
      while (_optionControllers.length < 2) {
        _optionControllers.add(TextEditingController());
      }
    } else {
      _optionControllers.add(TextEditingController());
      _optionControllers.add(TextEditingController());
    }

    _questionController.addListener(() => setState(() {}));
    for (final c in _optionControllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 options allowed.')),
      );
      return;
    }
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() => setState(() {}));
      _optionControllers.add(newController);
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 options are required.')),
      );
      return;
    }
    setState(() {
      final controller = _optionControllers.removeAt(index);
      controller.dispose();
    });
  }

  Future<void> _submitPoll() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a question for the poll.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final validOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least 2 non-empty options.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isEditing) {
      final existingOpts = widget.existingPoll!.options;
      final List<Map<String, dynamic>> payloadOptions = [];

      for (int i = 0; i < validOptions.length; i++) {
        final optText = validOptions[i];
        if (i < existingOpts.length) {
          payloadOptions.add({
            '_id': existingOpts[i].id,
            'text': optText,
          });
        } else {
          payloadOptions.add({'text': optText});
        }
      }

      final res = await _pollService.editPoll(
        widget.tripId,
        widget.existingPoll!.id,
        question: question,
        options: payloadOptions,
        allowMultipleAnswers: _allowMultipleAnswers,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        Navigator.pop(context, res['poll']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to update poll.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } else {
      final res = await _pollService.createPoll(
        widget.tripId,
        question: question,
        options: validOptions,
        allowMultipleAnswers: _allowMultipleAnswers,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        Navigator.pop(context, res['poll']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to create poll.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCanSubmit = _questionController.text.trim().isNotEmpty &&
        _optionControllers.where((c) => c.text.trim().isNotEmpty).length >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Poll' : 'Create Poll',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Question
                    _buildSectionTitle('Poll Question'),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: _questionController,
                      label: 'Poll Question',
                      hint: 'e.g. Where should we go for lunch?',
                      icon: Icons.title_outlined,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Poll Options'),
                        Text(
                          '${_optionControllers.length} Options',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _optionControllers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildInputField(
                          controller: _optionControllers[index],
                          label: 'Option ${index + 1}',
                          hint: 'Enter option ${index + 1}',
                          icon: Icons.radio_button_unchecked,
                          onChanged: (_) => setState(() {}),
                          suffixIcon: _optionControllers.length > 2
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textLight,
                                    size: 18,
                                  ),
                                  onPressed: () => _removeOption(index),
                                )
                              : null,
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Add one more option button
                    InkWell(
                      onTap: _addOption,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0072FF), size: 18),
                            SizedBox(width: 8),
                            Text(
                              '+ Add one more option',
                              style: TextStyle(
                                color: Color(0xFF0072FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Settings
                    _buildSectionTitle('Settings'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.01),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _allowMultipleAnswers,
                        activeThumbColor: const Color(0xFF0072FF),
                        activeTrackColor: const Color(0xFFBFDBFE),
                        onChanged: (val) {
                          setState(() => _allowMultipleAnswers = val);
                        },
                        title: const Text(
                          'Allow multiple answers',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Members can vote for more than one option',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isCanSubmit && !_isLoading
                        ? const LinearGradient(
                            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isCanSubmit && !_isLoading ? null : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: (isCanSubmit && !_isLoading) ? _submitPoll : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEditing ? Icons.check_circle_outline_rounded : Icons.send_rounded,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isEditing ? 'Save Changes' : 'Create Poll',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    Widget? suffixIcon,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
