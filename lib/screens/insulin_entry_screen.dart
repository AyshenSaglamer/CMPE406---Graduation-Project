import 'package:flutter/material.dart';

import '../data/insulin_store.dart';
import '../services/api_exception.dart';
import '../utils/api_enums.dart';
import '../utils/client_uuid.dart';
import '../utils/form_helpers.dart';
import '../widgets/date_time_tile.dart';

class InsulinEntryScreen extends StatefulWidget {
  const InsulinEntryScreen({super.key});

  @override
  State<InsulinEntryScreen> createState() => _InsulinEntryScreenState();
}

class _InsulinEntryScreenState extends State<InsulinEntryScreen> {
  final amountController = TextEditingController();

  String selectedType = 'Rapid-acting';

  final List<String> insulinTypes = insulinTypeOptions.keys.toList();

  String selectedDelivery = 'Pen';

  final List<String> deliveryOptions = insulinDeliveryOptions.keys.toList();

  DateTime administeredAt = DateTime.now();

  bool isSaving = false;

  // Same id while retrying after a network error, so the dose is not
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

  Future<void> _saveInsulin() async {
    if (isSaving) {
      return;
    }

    final value = amountController.text.trim();

    if (value.isEmpty) {
      _showMessage('Please enter the insulin amount.');
      return;
    }

    final amount = parseUserNumber(value);

    if (amount == null ||
        amount <= 0 ||
        amount > insulinMaxUnits ||
        !hasAtMostDecimals(amount, 2)) {
      _showMessage(
        'Please enter a dose between 0 and 300 units '
        '(at most 2 decimal places).',
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await insulinStore.create({
        'doseUnits': amount,
        'insulinType': insulinTypeOptions[selectedType],
        'deliveryMethod': insulinDeliveryOptions[selectedDelivery],
        'administeredAt': administeredAt.toUtc().toIso8601String(),
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
          e.fieldErrors['doseUnits'] ?? e.fieldErrors['administeredAt'];

      _showMessage(fieldError ?? e.message);
      return;
    }

    if (!mounted) {
      return;
    }

    _showMessage(
      '${formatNumber(amount)} units of $selectedType insulin saved.',
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Insulin'),
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
              'Insulin Amount',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildAmountInput(),

            const SizedBox(height: 24),

            const Text(
              'Insulin Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildTypeSelector(),

            const SizedBox(height: 14),

            const Text(
              'Delivery Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildDeliverySelector(),

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
              value: administeredAt,
              accentColor: const Color(0xFF765BD4),
              onChanged: (value) => _changed(() => administeredAt = value),
            ),

            const SizedBox(height: 24),

            _buildInfoCard(),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveInsulin,
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
                  isSaving ? 'Saving...' : 'Save Insulin Record',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF765BD4),
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
          colors: [Color(0xFFF0ECFF), Color(0xFFF8F5FF)],
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
              Icons.medication_rounded,
              size: 31,
              color: Color(0xFF765BD4),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Insulin Record',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF31294B),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Record the insulin dose used.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF776D89),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Column(
        children: [
          const Text(
            'Enter dose',
            style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => clientUuid = newClientUuid(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
            decoration: const InputDecoration(
              hintText: '6',
              hintStyle: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD1D9E2),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 2),

          const Text(
            'units',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      children: insulinTypes.map((type) {
        final isSelected = selectedType == type;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => _changed(() => selectedType = type),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF765BD4)
                        : const Color(0xFFE1E8EF),
                    width: isSelected ? 1.5 : 1,
                  ),
                  color: isSelected ? const Color(0xFFF6F2FF) : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEDE7FF)
                            : const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.medication_outlined,
                        color: isSelected
                            ? const Color(0xFF765BD4)
                            : const Color(0xFF7D8996),
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF4D3E7B)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),

                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF765BD4)
                              : const Color(0xFFC6D0DA),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF765BD4),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDeliverySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: deliveryOptions.map((option) {
        final isSelected = selectedDelivery == option;

        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => _changed(() => selectedDelivery = option),
          selectedColor: const Color(0xFFEDE7FF),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF765BD4)
                : const Color(0xFFE1E8EF),
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? const Color(0xFF4D3E7B)
                : const Color(0xFF5F6E7D),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF765BD4),
            size: 21,
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'Record the dose and insulin type according to your prescribed plan.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF665C7A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
