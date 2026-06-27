import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../models/serving_unit.dart';
import '../services/gemini_service.dart';
import '../services/serving_converter.dart';
import 'food_selection_screen.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  File? _selectedImage;
  final TextEditingController _quantityController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Serving unit state — grams selected by default.
  ServingUnit _selectedUnit = ServingUnit.grams;

  bool _isPickerLoading = false;
  bool _isAnalysing = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    final qty = double.tryParse(_quantityController.text.trim());
    return _selectedImage != null &&
        qty != null &&
        qty > 0 &&
        !_isAnalysing;
  }

  // ── Image Picker ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickerLoading || _isAnalysing) return;

    setState(() => _isPickerLoading = true);
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(
          source == ImageSource.camera
              ? 'Could not open camera. Please allow camera access in Settings.'
              : 'Could not open gallery. Please allow storage access in Settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickerLoading = false);
    }
  }

  // ── Analyse Food ───────────────────────────────────────────────────────

  Future<void> _onAnalysePressed() async {
    if (!_canProceed) return;

    final double quantity = double.parse(_quantityController.text.trim());

    // Convert the user-entered quantity + unit into grams.
    // foodName is null here because Gemini hasn't run yet.
    // Piece-weight lookup will use the generic default (100 g) at this stage.
    final double weightG = const ServingConverter().toGrams(
      quantity: quantity,
      unit: _selectedUnit,
    );

    setState(() => _isAnalysing = true);

    // Show non-dismissible loading dialog while API call runs.
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AnalysingDialog(),
      );
    }

    try {
      final result = await GeminiService().analyzeFood(_selectedImage!);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodSelectionScreen(
            imageFile: _selectedImage!,
            weightG: weightG,
            geminiResult: result,
          ),
        ),
      );
    } on GeminiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Food Photo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),

              _ImagePickerArea(
                selectedImage: _selectedImage,
                isLoading: _isPickerLoading,
              ),
              const SizedBox(height: 14),

              _PickerButtons(onPickImage: _pickImage),
              const SizedBox(height: 32),

              // Replaced _WeightInputField with _ServingInputField.
              _ServingInputField(
                controller: _quantityController,
                selectedUnit: _selectedUnit,
                onChanged: (_) => setState(() {}),
                onUnitChanged: (unit) => setState(() => _selectedUnit = unit),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _canProceed ? _onAnalysePressed : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  disabledBackgroundColor: AppTheme.divider,
                  disabledForegroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Analyse Food  →'),
              ),

              if (!_canProceed && !_isAnalysing) ...[
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Add a photo and enter quantity to continue.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _ImagePickerArea extends StatelessWidget {
  final File? selectedImage;
  final bool isLoading;

  const _ImagePickerArea(
      {required this.selectedImage, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedImage != null ? AppTheme.primary : AppTheme.divider,
          width: selectedImage != null ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 3));
    }
    if (selectedImage != null) {
      return Image.file(selectedImage!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return const _EmptyImagePlaceholder();
  }
}

class _EmptyImagePlaceholder extends StatelessWidget {
  const _EmptyImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_outlined, size: 52, color: AppTheme.primaryLight),
        SizedBox(height: 14),
        Text(
          'Take or upload a photo of your food',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4),
        Text(
          'Use the buttons below to get started',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _PickerButtons extends StatelessWidget {
  final Future<void> Function(ImageSource) onPickImage;
  const _PickerButtons({required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () => onPickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SourceButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () => onPickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}

/// Quantity number field + unit dropdown side by side.
/// Replaces the old grams-only _WeightInputField.
class _ServingInputField extends StatelessWidget {
  final TextEditingController controller;
  final ServingUnit selectedUnit;
  final ValueChanged<String> onChanged;
  final ValueChanged<ServingUnit> onUnitChanged;

  const _ServingInputField({
    required this.controller,
    required this.selectedUnit,
    required this.onChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Quantity number field (40% width)
            Expanded(
              flex: 4,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'e.g. 1',
                  suffixText: selectedUnit.symbol,
                  suffixStyle: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Unit dropdown (60% width)
            Expanded(
              flex: 6,
              child: DropdownButtonFormField<ServingUnit>(
                initialValue: selectedUnit,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                items: ServingUnit.values
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit.label),
                      ),
                    )
                    .toList(),
                onChanged: (unit) {
                  if (unit != null) onUnitChanged(unit);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the quantity and select the unit.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// Non-dismissible dialog shown while the Gemini API call is in progress.
/// PopScope with canPop: false prevents the Android back button
/// from closing it mid-request.
class _AnalysingDialog extends StatelessWidget {
  const _AnalysingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                'Analysing your food...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'AI is identifying the food in your image.\nThis takes 5–10 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}