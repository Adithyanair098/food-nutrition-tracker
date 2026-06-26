import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  // The selected image file. Null means no image picked yet.
  File? _selectedImage;

  // Controller for the weight text field.
  final TextEditingController _weightController = TextEditingController();

  // ImagePicker instance — reused across calls.
  final ImagePicker _imagePicker = ImagePicker();

  // True while the image picker dialog is opening (prevents double-taps).
  bool _isPickerLoading = false;

  @override
  void dispose() {
    // Always dispose controllers to free memory.
    _weightController.dispose();
    super.dispose();
  }

  // The Next button is only enabled when BOTH inputs are provided.
  bool get _canProceed {
    final weight = double.tryParse(_weightController.text.trim());
    return _selectedImage != null && weight != null && weight > 0;
  }

  // ── Image Picker Logic ─────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickerLoading) return; // Prevent double-tap

    setState(() => _isPickerLoading = true);

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,   // Keeps file size manageable for AI API calls
        maxHeight: 1024,
        imageQuality: 85, // Good quality without being excessively large
      );

      // pickImage returns null if the user cancels without selecting.
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Surface a friendly error message if permissions are denied
      // or the camera is unavailable.
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

  // ── Next Button Logic ──────────────────────────────────────────────────

  void _onAnalysePressed() {
    final double weight = double.parse(_weightController.text.trim());

    // ── Milestone 3 will replace this SnackBar with navigation ──
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ready! Photo selected · Weight: ${weight.toStringAsFixed(0)} g',
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meal'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section label
              Text(
                'Food Photo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),

              // Image display area
              _ImagePickerArea(
                selectedImage: _selectedImage,
                isLoading: _isPickerLoading,
              ),
              const SizedBox(height: 14),

              // Camera / Gallery buttons
              _PickerButtons(onPickImage: _pickImage),

              const SizedBox(height: 32),

              // Weight input
              _WeightInputField(
                controller: _weightController,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 40),

              // Analyse button
              ElevatedButton(
                onPressed: _canProceed ? _onAnalysePressed : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  disabledBackgroundColor: AppTheme.divider,
                  disabledForegroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Analyse Food  →'),
              ),

              // Helper text when button is disabled
              if (!_canProceed) ...[
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Add a photo and enter weight to continue.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
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
// Keeping these separate makes each piece of UI easy to read and modify.
// ═══════════════════════════════════════════════════════════════════════════

/// Displays the selected image, or an instructional placeholder if none.
class _ImagePickerArea extends StatelessWidget {
  final File? selectedImage;
  final bool isLoading;

  const _ImagePickerArea({
    required this.selectedImage,
    required this.isLoading,
  });

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
          color: AppTheme.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (selectedImage != null) {
      return Image.file(
        selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return const _EmptyImagePlaceholder();
  }
}

/// Shown inside the image area before any photo is selected.
class _EmptyImagePlaceholder extends StatelessWidget {
  const _EmptyImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt_outlined,
          size: 52,
          color: AppTheme.primaryLight,
        ),
        SizedBox(height: 14),
        Text(
          'Take or upload a photo of your food',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Use the buttons below to get started',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Row of Camera and Gallery buttons.
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

/// A single outlined source selection button (Camera or Gallery).
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

/// Weight input field with a 'g' suffix and explanatory label.
class _WeightInputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _WeightInputField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food Weight',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'e.g. 150',
            suffixText: 'g',
            suffixStyle: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Weigh your food first, then enter the value above.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}