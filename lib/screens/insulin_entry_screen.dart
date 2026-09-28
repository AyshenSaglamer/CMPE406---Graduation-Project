import 'package:flutter/material.dart';

class InsulinEntryScreen extends StatefulWidget {
  const InsulinEntryScreen({super.key});

  @override
  State<InsulinEntryScreen> createState() => _InsulinEntryScreenState();
}

class _InsulinEntryScreenState extends State<InsulinEntryScreen> {
  final amountController = TextEditingController();

  String selectedType = 'Rapid-acting';

  final List<String> insulinTypes = [
    'Rapid-acting',
    'Short-acting',
    'Intermediate-acting',
    'Long-acting',
  ];

  void _saveInsulin() {
    final value = amountController.text.trim();
    final amount = double.tryParse(value);

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter the insulin amount.',
          ),
        ),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid insulin amount.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${amountController.text} units of $selectedType insulin saved.',
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
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

            const SizedBox(height: 24),

            _buildInfoCard(),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveInsulin,
                icon: const Icon(
                  Icons.check_rounded,
                ),
                label: const Text(
                  'Save Insulin Record',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
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
          colors: [
            Color(0xFFF0ECFF),
            Color(0xFFF8F5FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
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
        border: Border.all(
          color: const Color(0xFFE7EDF3),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Enter dose',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF718096),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
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
              onTap: () {
                setState(() {
                  selectedType = type;
                });
              },
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
                  color: isSelected
                      ? const Color(0xFFF6F2FF)
                      : Colors.white,
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