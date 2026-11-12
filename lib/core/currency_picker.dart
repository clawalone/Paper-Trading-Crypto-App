import 'package:stock_arena/core/app_material.dart';
import 'app_theme.dart';
import 'currency_formatters.dart';

class CurrencyPicker {
  static Future<void> show(
    BuildContext context, {
    required String currentCode,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CurrencyPickerSheet(
        currentCode: currentCode,
        onSelected: onSelected,
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatefulWidget {
  final String currentCode;
  final ValueChanged<String> onSelected;

  const _CurrencyPickerSheet({
    required this.currentCode,
    required this.onSelected,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  List<CurrencyInfo> _filteredCurrencies = CurrencyFormatters.allCurrencies;

  static const List<String> _popularCodes = [
    'USD', 'INR', 'EUR', 'GBP', 'JPY', 'AED', 'CAD', 'AUD', 'SGD', 'CHF',
  ];

  @override
  void initState() {
    super.initState();
    _filteredCurrencies = CurrencyFormatters.allCurrencies;
  }

  void _onQueryChanged(String val) {
    final q = val.trim().toLowerCase();
    setState(() {
      _query = val.trim();
      if (q.isEmpty) {
        _filteredCurrencies = CurrencyFormatters.allCurrencies;
      } else {
        _filteredCurrencies = CurrencyFormatters.allCurrencies.where((c) {
          return c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              c.symbol.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectAndClose(String code) {
    Navigator.pop(context);
    widget.onSelected(code);
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      height: sheetHeight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Currency',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '160+ live global currencies supported',
                    style: TextStyle(color: AppColors.subtle, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.subtle, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Box
          TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search currency (e.g. EUR, Euro, €)...',
              hintStyle: const TextStyle(color: AppColors.subtle, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.subtle, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.subtle, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B4353), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Popular Row
          if (_query.isEmpty) ...[
            const Text(
              'POPULAR',
              style: TextStyle(
                color: Color(0xFF848E9C),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularCodes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final code = _popularCodes[idx];
                  final info = CurrencyFormatters.getInfo(code);
                  final isSelected = widget.currentCode == code;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _selectAndClose(code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF14243B)
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2196F3) : AppColors.outline,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(info.flag, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            code,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF64B5F6) : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // All Currencies Header
          Text(
            _query.isEmpty ? 'ALL CURRENCIES (${_filteredCurrencies.length})' : 'RESULTS (${_filteredCurrencies.length})',
            style: const TextStyle(
              color: Color(0xFF848E9C),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          // High-Performance Currency List with itemExtent
          Expanded(
            child: _filteredCurrencies.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No currency found for "$_query"',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemExtent: 58.0,
                    itemCount: _filteredCurrencies.length,
                    itemBuilder: (context, index) {
                      final c = _filteredCurrencies[index];
                      final isSelected = widget.currentCode == c.code;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF14243B)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF2196F3), width: 1.2)
                              : null,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _selectAndClose(c.code),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF162740) : AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(c.flag, style: const TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.code,
                                            style: TextStyle(
                                              color: isSelected ? const Color(0xFF64B5F6) : AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFF162740) : AppColors.surfaceAlt,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isSelected ? const Color(0xFF1E3A5F) : AppColors.outline),
                                            ),
                                            child: Text(
                                              c.symbol,
                                              style: TextStyle(
                                                color: isSelected ? const Color(0xFF90CAF9) : AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppColors.subtle, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3), size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
