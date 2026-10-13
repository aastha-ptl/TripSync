import 'package:flutter/material.dart';
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
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Question
                    const Text(
                      'Poll Question',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _questionController.text.trim().isNotEmpty
                              ? const Color(0xFF0072FF)
                              : const Color(0xFFE2E8F0),
                          width: _questionController.text.trim().isNotEmpty ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2, right: 12),
                            child: Icon(Icons.help_outline_rounded, color: Color(0xFF0072FF), size: 22),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _questionController,
                              maxLength: 255,
                              maxLines: 3,
                              minLines: 1,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'What would you like to ask?',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                counterStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Poll Options',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_optionControllers.length} Options',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _optionControllers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final controller = _optionControllers[index];
                        final isFilled = controller.text.trim().isNotEmpty;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isFilled ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                              width: isFilled ? 1.4 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isFilled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isFilled ? const Color(0xFF0072FF) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  maxLength: 100,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Option ${index + 1}',
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    counterText: '${controller.text.length}/100',
                                    counterStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                  ),
                                ),
                              ),
                              if (_optionControllers.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 19),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeOption(index),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Add one more option button
                    InkWell(
                      onTap: _addOption,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0072FF), size: 20),
                            SizedBox(width: 8),
                            Text(
                              '+ Add one more option',
                              style: TextStyle(
                                color: Color(0xFF0072FF),
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Settings
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: const Text(
                          'Members can vote for more than one option',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
}
