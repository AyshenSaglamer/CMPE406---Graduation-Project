import 'package:flutter/material.dart';

import '../data/meal_store.dart';
import '../services/api_exception.dart';
import '../utils/api_enums.dart';
import '../utils/client_uuid.dart';
import '../utils/form_helpers.dart';
import '../widgets/date_time_tile.dart';

class MealEntryScreen extends StatefulWidget {
  const MealEntryScreen({super.key});

  @override
  State<MealEntryScreen> createState() => _MealEntryScreenState();
}

class _MealEntryScreenState extends State<MealEntryScreen> {
  final mealDescriptionController = TextEditingController();
  final carbsController = TextEditingController();

  String selectedMealType = 'Breakfast';

  final List<String> mealTypes = mealTypeOptions.keys.toList();

  DateTime eatenAt = DateTime.now();

  bool isSaving = false;

  // Same id while retrying after a network error, so the record is not
  // stored twice. A new one after any change.
  String clientUuid = newClientUuid();

  void _changed(VoidCallback update) {
    setState(() {
      update();
      clientUuid = newClientUuid();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveMeal() async {
    if (isSaving) {
      return;
    }

    final description = mealDescriptionController.text.trim();
    final carbsText = carbsController.text.trim();

    if (description.isEmpty) {
      _showMessage('Please describe your meal.');
      return;
    }

    double? carbs;

    if (carbsText.isNotEmpty) {
      carbs = parseUserNumber(carbsText);

      if (carbs == null ||
          carbs < 0 ||
          carbs > 1000 ||
          !hasAtMostDecimals(carbs, 1)) {
        _showMessage(
          'Please enter carbohydrates between 0 and 1000 g '
          '(at most 1 decimal place).',
        );
        return;
      }
    }

    setState(() {
      isSaving = true;
    });

    try {
      await mealStore.create({
        'mealType': mealTypeOptions[selectedMealType],
        'eatenAt': eatenAt.toUtc().toIso8601String(),
        'description': description,
        'carbsG': ?carbs,
        'source': 'MANUAL',
        'clientUuid': clientUuid,
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      final fieldError =
          e.fieldErrors['description'] ??
          e.fieldErrors['carbsG'] ??
          e.fieldErrors['eatenAt'];

      _showMessage(fieldError ?? e.message);
      return;
    }

    if (!mounted) {
      return;
    }

    _showMessage('Meal record saved successfully.');

    Navigator.pop(context);
  }

  @override
  void dispose() {
    mealDescriptionController.dispose();
    carbsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Meal'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),

            const SizedBox(height: 24),

            const Text(
              'Meal Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildMealTypeSelector(),

            const SizedBox(height: 24),

            const Text(
              'Date & Time',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            DateTimeTile(
              value: eatenAt,
              accentColor: const Color(0xFFF0A126),
              onChanged: (value) => _changed(() => eatenAt = value),
            ),

            const SizedBox(height: 24),

            const Text(
              'What did you eat?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildDescriptionField(),

            const SizedBox(height: 24),

            const Text(
              'Carbohydrates',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildCarbsField(),

            const SizedBox(height: 22),

            _buildInfoCard(),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveMeal,
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  isSaving ? 'Saving...' : 'Save Meal Record',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0A126),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF2E2), Color(0xFFFFF8ED)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 31,
              color: Color(0xFFF0A126),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Meal Record',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF493827),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Record your meal and carbohydrate intake.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF806F5D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: mealTypes.map((type) {
        final isSelected = selectedMealType == type;

        return ChoiceChip(
          label: Text(type),
          selected: isSelected,
          onSelected: (_) => _changed(() => selectedMealType = type),
          selectedColor: const Color(0xFFFFEED8),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFF0A126)
                : const Color(0xFFE1E8EF),
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? const Color(0xFFCA821B)
                : const Color(0xFF5F6E7D),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: TextField(
        controller: mealDescriptionController,
        maxLines: 5,
        maxLength: 1000,
        onChanged: (_) => clientUuid = newClientUuid(),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'For example: Grilled chicken, salad and yogurt',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA0ACB8)),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, bottom: 72),
            child: Icon(Icons.edit_note_rounded, color: Color(0xFFF0A126)),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFE3EAF1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFF0A126), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCarbsField() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.grain_rounded, color: Color(0xFFF0A126)),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Carbohydrate Amount',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Optional',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 105,
            child: TextField(
              controller: carbsController,
              onChanged: (_) => clientUuid = newClientUuid(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'g',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE3EAF1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFF0A126),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFF0A126), size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recording meals and carbohydrates can help you review daily patterns together with your health data.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF78684F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
