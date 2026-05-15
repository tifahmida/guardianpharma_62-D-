import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pharmacy_wrapper_page.dart';

// ============================================================
// InventoryListPage — standalone inventory browser
// ============================================================
class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    searchController.addListener(_filter);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('medicine_name');
      setState(() {
        allMedicines = List<Map<String, dynamic>>.from(res);
        filtered = allMedicines;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _filter() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filtered = allMedicines.where((m) {
        final name = (m['medicine_name'] ?? '').toString().toLowerCase();
        final generic = (m['generic_name'] ?? '').toString().toLowerCase();
        final batch = (m['batch_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || generic.contains(q) || batch.contains(q);
      }).toList();
    });
  }

  Color _expiryColor(String? s) {
    if (s == null) return Colors.grey;
    final d = DateTime.tryParse(s);
    if (d == null) return Colors.grey;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.redAccent;
    if (days <= 30) return Colors.orange;
    return Colors.greenAccent;
  }

  String _expiryLabel(String? s) {
    if (s == null) return 'Expiry: N/A';
    final d = DateTime.tryParse(s);
    if (d == null) return 'Expiry: $s';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '⛔ EXPIRED ($s)';
    if (days == 0) return '⚠️ Expires TODAY';
    if (days <= 30) return '⚠️ Expires in $days days ($s)';
    return '✅ Expires: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.50)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.inventory_2, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Inventory & Medicine Lookup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.blueAccent,
                      ),
                      hintText: 'Search by name, generic name, batch...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                              ),
                              onPressed: () => searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.medication_outlined,
                                color: Colors.white24,
                                size: 60,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                searchController.text.isEmpty
                                    ? 'No medicines in inventory'
                                    : 'No results found',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final int qty = (m['quantity'] as int?) ?? 0;
                            final int spb = (m['strips_per_box'] as int?) ?? 10;
                            final Color expColor = _expiryColor(
                              m['expiry_date']?.toString(),
                            );
                            final String mfr =
                                m['cartons']?['manufacturers']?['name']
                                    ?.toString() ??
                                'Unknown';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: expColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m['medicine_name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if ((m['generic_name'] ?? '')
                                                .isNotEmpty)
                                              Text(
                                                m['generic_name'],
                                                style: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            Text(
                                              '🏭 $mfr',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: qty > 0
                                              ? Colors.greenAccent.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.redAccent.withValues(
                                                  alpha: 0.15,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: qty > 0
                                                ? Colors.greenAccent.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : Colors.redAccent.withValues(
                                                    alpha: 0.5,
                                                  ),
                                          ),
                                        ),
                                        child: Text(
                                          qty > 0 ? '✅ In Stock' : '❌ Out',
                                          style: TextStyle(
                                            color: qty > 0
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _chip('📦 $qty boxes', Colors.blueAccent),
                                      _chip(
                                        '💊 ${qty * spb} strips',
                                        Colors.tealAccent,
                                      ),
                                      _chip(
                                        '🔢 ${m['batch_number'] ?? 'N/A'}',
                                        Colors.white54,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: expColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: expColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _expiryLabel(
                                        m['expiry_date']?.toString(),
                                      ),
                                      style: TextStyle(
                                        color: expColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ============================================================
// SellMedicineAndInventoryPage
// ============================================================
class SellMedicineAndInventoryPage extends StatefulWidget {
  final Map<String, dynamic>? preSelected;
  final bool openBarcode;

  const SellMedicineAndInventoryPage({
    super.key,
    this.preSelected,
    this.openBarcode = false,
  });

  @override
  State<SellMedicineAndInventoryPage> createState() =>
      _SellMedicineAndInventoryPageState();
}

class _SellMedicineAndInventoryPageState
    extends State<SellMedicineAndInventoryPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> filteredMedicines = [];
  bool loadingMedicines = true;
  final searchController = TextEditingController();

  List<Map<String, dynamic>> manufacturers = [];
  bool loadingManufacturers = true;

  final Map<String, int> _safeLimitsByKeyword = {
    'paracetamol': 5,
    'napa': 5,
    'sleeping': 2,
    'painkiller': 3,
    'antibiotic': 4,
  };
  static const int _defaultSafeLimit = 10;

  final List<String> _units = [
    'Tablets',
    'Syrup',
    'Powder',
    'Capsules',
    'Injection',
    'Custom',
  ];

  // Substitute tab state
  final _substituteController = TextEditingController();
  List<Map<String, dynamic>> _substituteResults = [];
  bool _searchingSubstitute = false;
  bool _substitutedSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadMedicines();
    _loadManufacturers();
    searchController.addListener(_filterMedicines);

    if (widget.preSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSellDialog(widget.preSelected!);
      });
    }

    if (widget.openBarcode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final code = await _scanBarcode();
        if (code != null && code.isNotEmpty) {
          searchController.text = code;
          _filterMedicines();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    _substituteController.dispose();
    super.dispose();
  }

  // =========================
  // LOAD MEDICINES
  // =========================
  Future<void> _loadMedicines() async {
    setState(() => loadingMedicines = true);
    try {
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('medicine_name');
      setState(() {
        allMedicines = List<Map<String, dynamic>>.from(res);
        filteredMedicines = allMedicines;
        loadingMedicines = false;
      });
    } catch (e) {
      _error('Failed to load medicines: $e');
      setState(() => loadingMedicines = false);
    }
  }

  // =========================
  // LOAD MANUFACTURERS
  // =========================
  Future<void> _loadManufacturers() async {
    setState(() => loadingManufacturers = true);
    try {
      final res = await supabase.from('manufacturers').select().order('name');
      setState(() {
        manufacturers = List<Map<String, dynamic>>.from(res);
        loadingManufacturers = false;
      });
    } catch (e) {
      setState(() => loadingManufacturers = false);
    }
  }

  // =========================
  // FILTER
  // =========================
  void _filterMedicines() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredMedicines = allMedicines.where((m) {
        final name = (m['medicine_name'] ?? '').toString().toLowerCase();
        final generic = (m['generic_name'] ?? '').toString().toLowerCase();
        final batch = (m['batch_number'] ?? '').toString().toLowerCase();
        final mfr = (m['cartons']?['manufacturers']?['name'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(q) ||
            generic.contains(q) ||
            batch.contains(q) ||
            mfr.contains(q);
      }).toList();
    });
  }

  // =========================
  // SAFE LIMIT
  // =========================
  int _getSafeLimit(String medicineName) {
    final name = medicineName.toLowerCase();
    for (final entry in _safeLimitsByKeyword.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return _defaultSafeLimit;
  }

  // =========================
  // BARCODE SCAN
  // =========================
  Future<String?> _scanBarcode() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Scan Barcode', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter batch number / barcode',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================
  // SELL DIALOG
  // =========================
  void _showSellDialog(Map<String, dynamic> medicine) {
    String saleType = 'strip';
    final qtyCtrl = TextEditingController(text: '1');
    final customerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final int stripsPerBox = (medicine['strips_per_box'] as int?) ?? 10;
    final double pricePerBox =
        double.tryParse(medicine['price'].toString()) ?? 0.0;
    final double pricePerStrip = medicine['price_per_strip'] != null
        ? double.tryParse(medicine['price_per_strip'].toString()) ??
              (pricePerBox / stripsPerBox)
        : pricePerBox / stripsPerBox;
    final int availableBoxes = (medicine['quantity'] as int?) ?? 0;

    final int cartonNum = (medicine['cartons']?['carton_number'] as int?) ?? 1;
    final int boxesPerCarton =
        (medicine['cartons']?['boxes_per_carton'] as int?) ?? 50;
    final String medicineName = medicine['medicine_name']?.toString() ?? '';
    final String genericName = medicine['generic_name']?.toString() ?? '';
    final String batchNumber = medicine['batch_number']?.toString() ?? '';
    final String mfr =
        medicine['cartons']?['manufacturers']?['name']?.toString() ?? 'Unknown';
    final String expiry = medicine['expiry_date']?.toString() ?? 'N/A';
    final int safeLimit = _getSafeLimit(medicineName);
    final int totalBoxesInCartons = boxesPerCarton * cartonNum;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) {
          double unitPrice;
          if (saleType == 'strip') {
            unitPrice = pricePerStrip;
          } else if (saleType == 'box') {
            unitPrice = pricePerBox;
          } else {
            unitPrice = pricePerBox * availableBoxes;
          }

          final int enteredQty = saleType == 'carton'
              ? 1
              : (int.tryParse(qtyCtrl.text) ?? 1);
          final double total = saleType == 'carton'
              ? unitPrice
              : unitPrice * enteredQty;

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (genericName.isNotEmpty)
                  Text(
                    genericName,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _infoRow('🏭 Manufacturer', mfr),
                        _infoRow('🔢 Batch', batchNumber),
                        _infoRow('📅 Expiry', expiry),
                        _infoRow('📦 Stock (Boxes)', '$availableBoxes'),
                        _infoRow(
                          '🏭 Carton Info',
                          '${boxesPerCarton}×$cartonNum = $totalBoxesInCartons boxes',
                        ),
                        _infoRow('💊 Strips/Box', '$stripsPerBox strips'),
                        _infoRow(
                          '💰 Price/Box',
                          'BDT ${pricePerBox.toStringAsFixed(2)}',
                        ),
                        _infoRow(
                          '💊 Price/Strip',
                          'BDT ${pricePerStrip.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sell as:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _saleTypeChip(
                        'strip',
                        '💊 Strip',
                        saleType,
                        (v) => setDs(() => saleType = v),
                      ),
                      const SizedBox(width: 8),
                      _saleTypeChip(
                        'box',
                        '📦 Box',
                        saleType,
                        (v) => setDs(() => saleType = v),
                      ),
                      const SizedBox(width: 8),
                      _saleTypeChip(
                        'carton',
                        '🏭 Carton',
                        saleType,
                        (v) => setDs(() => saleType = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (saleType != 'carton') ...[
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setDs(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.numbers,
                          color: Colors.white70,
                        ),
                        hintText: 'Quantity',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: customerCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Colors.white70,
                      ),
                      hintText: 'Customer name (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Colors.white70,
                      ),
                      hintText: 'Customer phone (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Safe limit: $safeLimit units. Selling more requires OTP.',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'BDT ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                ),
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.black,
                  size: 18,
                ),
                label: const Text(
                  'Sell',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  final int qty = saleType == 'carton'
                      ? 1
                      : (int.tryParse(qtyCtrl.text) ?? 1);
                  if (qty <= 0) {
                    _error('Quantity must be at least 1');
                    return;
                  }
                  final String customer = customerCtrl.text.trim();
                  final String phone = phoneCtrl.text.trim();
                  Navigator.pop(context);

                  if (qty > safeLimit) {
                    _showHighQtyWarning(
                      medicine: medicine,
                      qty: qty,
                      saleType: saleType,
                      unitPrice: unitPrice,
                      total: total,
                      customer: customer,
                      phone: phone,
                      medicineName: medicineName,
                      batchNumber: batchNumber,
                      availableBoxes: availableBoxes,
                      stripsPerBox: stripsPerBox,
                      safeLimit: safeLimit,
                    );
                  } else {
                    await _completeSale(
                      medicine: medicine,
                      saleType: saleType,
                      qty: qty,
                      unitPrice: unitPrice,
                      total: saleType == 'carton' ? unitPrice : unitPrice * qty,
                      customer: customer,
                      phone: phone,
                      medicineName: medicineName,
                      batchNumber: batchNumber,
                      availableBoxes: availableBoxes,
                      stripsPerBox: stripsPerBox,
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // HIGH QTY WARNING + OTP
  // =========================
  void _showHighQtyWarning({
    required Map<String, dynamic> medicine,
    required int qty,
    required String saleType,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required String medicineName,
    required String batchNumber,
    required int availableBoxes,
    required int stripsPerBox,
    required int safeLimit,
  }) {
    final nameCtrl = TextEditingController(text: customer);
    final phoneCtrl2 = TextEditingController(text: phone);
    final ageCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ High Quantity Detected!',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'You are selling $qty units of $medicineName.\n\nSafe limit is $safeLimit units.\n\nCustomer details required to proceed.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _dialogField(nameCtrl, 'Customer Full Name', Icons.person),
              const SizedBox(height: 10),
              _dialogField(
                phoneCtrl2,
                'Phone Number',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _dialogField(
                ageCtrl,
                'Age',
                Icons.cake,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _dialogField(reasonCtrl, 'Reason for Purchase', Icons.note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel Sale',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.lock_open, color: Colors.white, size: 16),
            label: const Text(
              'Send OTP',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final ph = phoneCtrl2.text.trim();
              final age = int.tryParse(ageCtrl.text.trim()) ?? 0;
              final reason = reasonCtrl.text.trim();
              if (name.isEmpty || ph.isEmpty || reason.isEmpty) {
                _error('Please fill all required fields');
                return;
              }
              Navigator.pop(context);
              _showOtpDialog(
                medicine: medicine,
                qty: qty,
                saleType: saleType,
                unitPrice: unitPrice,
                total: total,
                customerName: name,
                phone: ph,
                age: age,
                reason: reason,
                medicineName: medicineName,
                batchNumber: batchNumber,
                availableBoxes: availableBoxes,
                stripsPerBox: stripsPerBox,
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // OTP DIALOG
  // =========================
  void _showOtpDialog({
    required Map<String, dynamic> medicine,
    required int qty,
    required String saleType,
    required double unitPrice,
    required double total,
    required String customerName,
    required String phone,
    required int age,
    required String reason,
    required String medicineName,
    required String batchNumber,
    required int availableBoxes,
    required int stripsPerBox,
  }) {
    final String generatedOtp = (100000 + Random().nextInt(900000)).toString();
    final otpCtrl = TextEditingController();
    bool otpError = false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📱 Demo OTP: $generatedOtp',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 15),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'OTP Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.sms, color: Colors.blueAccent, size: 28),
                    const SizedBox(height: 8),
                    const Text(
                      'Demo OTP Sent',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      generatedOtp,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '(In real app sent via SMS)',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (_) => setDs(() => otpError = false),
                decoration: InputDecoration(
                  hintText: 'Enter OTP',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  counterStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (otpError)
                const Text(
                  '❌ Incorrect OTP. Try again.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.check, color: Colors.white, size: 16),
              label: const Text(
                'Verify & Sell',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (otpCtrl.text.trim() == generatedOtp) {
                  Navigator.pop(context);
                  await _saveSuspiciousLog(
                    medicineName: medicineName,
                    batchNumber: batchNumber,
                    qty: qty,
                    customerName: customerName,
                    phone: phone,
                    age: age,
                    reason: reason,
                  );
                  await _completeSale(
                    medicine: medicine,
                    saleType: saleType,
                    qty: qty,
                    unitPrice: unitPrice,
                    total: total,
                    customer: customerName,
                    phone: phone,
                    medicineName: medicineName,
                    batchNumber: batchNumber,
                    availableBoxes: availableBoxes,
                    stripsPerBox: stripsPerBox,
                  );
                } else {
                  setDs(() => otpError = true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // SAVE SUSPICIOUS LOG
  // =========================
  Future<void> _saveSuspiciousLog({
    required String medicineName,
    required String batchNumber,
    required int qty,
    required String customerName,
    required String phone,
    required int age,
    required String reason,
  }) async {
    try {
      await supabase.from('suspicious_logs').insert({
        'pharmacy_id': PharmacySession.pharmacyId,
        'pharmacy_name': PharmacySession.pharmacyName,
        'medicine_name': medicineName,
        'batch_number': batchNumber,
        'quantity': qty,
        'activity_type': 'high_quantity_purchase',
        'description':
            '$customerName (age $age, $phone) purchased $qty units of $medicineName. Reason: $reason',
        'flagged_by': 'system',
      });
    } catch (e) {
      debugPrint('Suspicious log error: $e');
    }
  }

  // =========================
  // COMPLETE SALE
  // =========================
  Future<void> _completeSale({
    required Map<String, dynamic> medicine,
    required String saleType,
    required int qty,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required String medicineName,
    required String batchNumber,
    required int availableBoxes,
    required int stripsPerBox,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;

      await supabase.from('sales').insert({
        'medicine_box_id': medicine['id'],
        'medicine_name': medicineName,
        'batch_number': batchNumber,
        'sale_type': saleType,
        'quantity_sold': qty,
        'unit_price': unitPrice,
        'total_amount': total,
        'customer_name': customer.isEmpty ? null : customer,
        'customer_phone': phone.isEmpty ? null : phone,
        'sold_by': userId,
        'pharmacy_id': PharmacySession.pharmacyId,
      });

      int newQty;
      if (saleType == 'carton') {
        newQty = 0;
      } else if (saleType == 'box') {
        newQty = (availableBoxes - qty).clamp(0, availableBoxes);
      } else {
        final int boxesUsed = (qty / stripsPerBox).ceil();
        newQty = (availableBoxes - boxesUsed).clamp(0, availableBoxes);
      }

      await supabase
          .from('medicine_boxes')
          .update({'quantity': newQty})
          .eq('id', medicine['id']);

      if (!mounted) return;

      _showReceipt(
        medicineName: medicineName,
        batchNumber: batchNumber,
        saleType: saleType,
        qty: qty,
        unitPrice: unitPrice,
        total: total,
        customer: customer,
        phone: phone,
      );

      _loadMedicines();
    } catch (e) {
      _error('Sale failed: $e');
    }
  }

  // =========================
  // RECEIPT
  // =========================
  void _showReceipt({
    required String medicineName,
    required String batchNumber,
    required String saleType,
    required int qty,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Sale Receipt',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_pharmacy_rounded,
                color: Colors.blueAccent,
                size: 36,
              ),
              const SizedBox(height: 6),
              Text(
                PharmacySession.pharmacyName ?? 'GuardianPharma',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                '$dateStr  •  $timeStr',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (customer.isNotEmpty)
                Text(
                  'Customer: $customer',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              if (phone.isNotEmpty)
                Text(
                  '📱 $phone',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              _infoRow('💊 Medicine', medicineName),
              _infoRow('🔢 Batch', batchNumber),
              _infoRow('📦 Type', saleType.toUpperCase()),
              _infoRow('🔢 Quantity', '$qty'),
              _infoRow('💰 Unit Price', 'BDT ${unitPrice.toStringAsFixed(2)}'),
              const Divider(color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'BDT ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '✅ Sale saved!',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Done', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ADD / EDIT MEDICINE BOX
  // =========================
  void _showMedicineBoxDialog(
    String cartonId,
    String manufacturerName, {
    Map<String, dynamic>? existing,
  }) {
    final nameCtrl = TextEditingController(
      text: existing?['medicine_name'] ?? '',
    );
    final genericCtrl = TextEditingController(
      text: existing?['generic_name'] ?? '',
    );
    final batchCtrl = TextEditingController(
      text: existing?['batch_number'] ?? '',
    );
    final expiryCtrl = TextEditingController(
      text: existing?['expiry_date'] ?? '',
    );
    final qtyCtrl = TextEditingController(
      text: existing?['quantity']?.toString() ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    final stripsCtrl = TextEditingController(
      text: existing?['strips_per_box']?.toString() ?? '10',
    );
    final stripPriceCtrl = TextEditingController(
      text: existing?['price_per_strip']?.toString() ?? '',
    );
    final customUnitCtrl = TextEditingController();

    String selectedUnit = existing?['unit'] ?? 'Tablets';
    bool isCustomUnit = !_units.contains(selectedUnit);
    if (isCustomUnit) {
      customUnitCtrl.text = selectedUnit;
      selectedUnit = 'Custom';
    }
    final bool isEditing = existing != null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Row(
            children: [
              const Icon(Icons.medication, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Edit Medicine Box' : 'Add Medicine Box',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.business,
                        color: Colors.greenAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        manufacturerName,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _dialogField(nameCtrl, 'Medicine Name *', Icons.medication),
                const SizedBox(height: 10),
                _dialogField(
                  genericCtrl,
                  'Generic Name (e.g. Atorvastatin)',
                  Icons.science_outlined,
                ),
                const SizedBox(height: 10),
                _dialogField(batchCtrl, 'Batch Number *', Icons.numbers),
                const SizedBox(height: 10),
                TextField(
                  controller: expiryCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                    ),
                    hintText: 'Expiry Date *',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      expiryCtrl.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                const SizedBox(height: 10),
                _dialogField(
                  qtyCtrl,
                  'Quantity (boxes) *',
                  Icons.inventory,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  stripsCtrl,
                  'Strips per Box',
                  Icons.view_module,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  priceCtrl,
                  'Price per Box (BDT) *',
                  Icons.attach_money,
                  isDecimal: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  stripPriceCtrl,
                  'Price per Strip (BDT)',
                  Icons.money,
                  isDecimal: true,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.category,
                      color: Colors.white70,
                    ),
                    hintText: 'Unit Type',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _units
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDs(() {
                    selectedUnit = v!;
                    isCustomUnit = v == 'Custom';
                  }),
                ),
                if (isCustomUnit) ...[
                  const SizedBox(height: 10),
                  _dialogField(customUnitCtrl, 'Custom Unit', Icons.edit),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final batch = batchCtrl.text.trim();
                final expiry = expiryCtrl.text.trim();
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final strips = int.tryParse(stripsCtrl.text.trim()) ?? 10;
                final stripPrice = double.tryParse(stripPriceCtrl.text.trim());
                final unit = isCustomUnit
                    ? customUnitCtrl.text.trim()
                    : selectedUnit;

                if (name.isEmpty || batch.isEmpty || expiry.isEmpty) {
                  _error('Fill all required fields (*)');
                  return;
                }

                try {
                  if (isEditing) {
                    await supabase
                        .from('medicine_boxes')
                        .update({
                          'medicine_name': name,
                          'generic_name': genericCtrl.text.trim().isEmpty
                              ? null
                              : genericCtrl.text.trim(),
                          'batch_number': batch,
                          'expiry_date': expiry,
                          'quantity': qty,
                          'strips_per_box': strips,
                          'unit': unit,
                          'price': price,
                          'price_per_strip': stripPrice,
                        })
                        .eq('id', existing!['id']);
                    _success('Medicine box updated!');
                  } else {
                    await supabase.from('medicine_boxes').insert({
                      'carton_id': cartonId,
                      'medicine_name': name,
                      'generic_name': genericCtrl.text.trim().isEmpty
                          ? null
                          : genericCtrl.text.trim(),
                      'batch_number': batch,
                      'expiry_date': expiry,
                      'quantity': qty,
                      'strips_per_box': strips,
                      'unit': unit,
                      'price': price,
                      'price_per_strip': stripPrice,
                      'created_by': supabase.auth.currentUser?.id,
                      'pharmacy_id': PharmacySession.pharmacyId,
                    });
                    _success('Medicine box added!');
                  }
                  if (mounted) Navigator.pop(context);
                  _loadMedicines();
                } catch (e) {
                  _error('Error: $e');
                }
              },
              child: Text(
                isEditing ? 'Update' : 'Add',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // ADD / EDIT MANUFACTURER
  // =========================
  void _showManufacturerDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final countryCtrl = TextEditingController(text: existing?['country'] ?? '');
    final cartonNumCtrl = TextEditingController(text: '1');
    final boxesPerCartonCtrl = TextEditingController(text: '50');
    final bool isEditing = existing != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          isEditing ? 'Edit Manufacturer' : 'Add Manufacturer',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'Manufacturer Name *', Icons.business),
              const SizedBox(height: 10),
              _dialogField(countryCtrl, 'Country', Icons.flag),
              if (!isEditing) ...[
                const SizedBox(height: 10),
                _dialogField(
                  cartonNumCtrl,
                  'Number of Cartons',
                  Icons.widgets,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesPerCartonCtrl,
                  'Boxes per Carton (default 50)',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blueAccent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Total boxes = Boxes per Carton × Number of Cartons',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                _error('Manufacturer name required');
                return;
              }
              try {
                if (isEditing) {
                  await supabase
                      .from('manufacturers')
                      .update({
                        'name': name,
                        'country': countryCtrl.text.trim().isEmpty
                            ? null
                            : countryCtrl.text.trim(),
                      })
                      .eq('id', existing!['id']);
                  _success('Manufacturer updated!');
                } else {
                  final cartonNum = int.tryParse(cartonNumCtrl.text) ?? 1;
                  final boxesPerCarton =
                      int.tryParse(boxesPerCartonCtrl.text) ?? 50;

                  final mfrRes = await supabase
                      .from('manufacturers')
                      .insert({
                        'name': name,
                        'country': countryCtrl.text.trim().isEmpty
                            ? null
                            : countryCtrl.text.trim(),
                      })
                      .select()
                      .single();

                  await supabase.from('cartons').insert({
                    'manufacturer_id': mfrRes['id'],
                    'carton_number': cartonNum,
                    'boxes_per_carton': boxesPerCarton,
                    'received_date': DateTime.now().toIso8601String().split(
                      'T',
                    )[0],
                    'created_by': supabase.auth.currentUser?.id,
                  });

                  _success(
                    'Manufacturer added! $cartonNum cartons × $boxesPerCarton boxes = ${cartonNum * boxesPerCarton} total boxes',
                  );
                }
                if (mounted) Navigator.pop(context);
                _loadManufacturers();
              } catch (e) {
                _error('Error: $e');
              }
            },
            child: Text(
              isEditing ? 'Update' : 'Add',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // VIEW MEDICINE BOXES
  // =========================
  void _viewMedicineBoxes(
    String manufacturerId,
    String manufacturerName,
  ) async {
    try {
      final cartonRes = await supabase
          .from('cartons')
          .select()
          .eq('manufacturer_id', manufacturerId)
          .maybeSingle();

      if (cartonRes == null) {
        _error('No carton found for this manufacturer');
        return;
      }

      final String cartonId = cartonRes['id'];
      final int cartonNum = (cartonRes['carton_number'] as int?) ?? 1;
      final int boxesPerCarton = (cartonRes['boxes_per_carton'] as int?) ?? 50;
      final int totalBoxes = cartonNum * boxesPerCarton;
      final String receivedDate =
          cartonRes['received_date']?.toString() ?? 'N/A';

      final boxes = await supabase
          .from('medicine_boxes')
          .select()
          .eq('carton_id', cartonId)
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('expiry_date');

      final List<Map<String, dynamic>> boxList =
          List<Map<String, dynamic>>.from(boxes);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            builder: (_, ctrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '🏭 $manufacturerName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showMedicineBoxDialog(
                                cartonId,
                                manufacturerName,
                              );
                            },
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text(
                              'Add Box',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _cartonStat('📦 Boxes', '$boxesPerCarton'),
                            const Text(
                              '×',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _cartonStat('🏭 Cartons', '$cartonNum'),
                            const Text(
                              '=',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _cartonStat(
                              '📊 Total',
                              '$totalBoxes',
                              color: Colors.greenAccent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📅 Received: $receivedDate',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                boxList.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text(
                            'No medicine boxes yet',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: boxList.length,
                          itemBuilder: (_, i) {
                            final box = boxList[i];
                            final expiry = DateTime.tryParse(
                              box['expiry_date'] ?? '',
                            );
                            final daysLeft = expiry
                                ?.difference(DateTime.now())
                                .inDays;
                            final bool isExpired =
                                daysLeft != null && daysLeft < 0;
                            final bool isExpiringSoon =
                                daysLeft != null &&
                                daysLeft <= 30 &&
                                daysLeft >= 0;
                            final int qty = (box['quantity'] as int?) ?? 0;
                            final int spb =
                                (box['strips_per_box'] as int?) ?? 10;

                            return Card(
                              color: isExpired
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : isExpiringSoon
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.08),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            box['medicine_name'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blueAccent,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showMedicineBoxDialog(
                                              cartonId,
                                              manufacturerName,
                                              existing: box,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          onPressed: () async {
                                            await supabase
                                                .from('medicine_boxes')
                                                .delete()
                                                .eq('id', box['id']);
                                            setSheet(
                                              () => boxList.removeWhere(
                                                (b) => b['id'] == box['id'],
                                              ),
                                            );
                                            _success('Deleted!');
                                            _loadMedicines();
                                          },
                                        ),
                                      ],
                                    ),
                                    if ((box['generic_name'] ?? '').isNotEmpty)
                                      Text(
                                        '🧬 ${box['generic_name']}',
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '📦 $qty boxes',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '💊 $spb strips/box',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Total: ${qty * spb}',
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isExpired
                                          ? '⛔ EXPIRED'
                                          : isExpiringSoon
                                          ? '⚠️ Expires in $daysLeft days'
                                          : '✅ Expires: ${box['expiry_date']}',
                                      style: TextStyle(
                                        color: isExpired
                                            ? Colors.redAccent
                                            : isExpiringSoon
                                            ? Colors.orange
                                            : Colors.greenAccent,
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
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _error('Error: $e');
    }
  }

  // =========================
  // FEFO STATUS
  // =========================
  ({String label, Color color, int days}) _fefoStatus(String? expiryStr) {
    if (expiryStr == null) {
      return (label: 'Unknown', color: Colors.grey, days: 0);
    }
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) {
      return (label: 'Unknown', color: Colors.grey, days: 0);
    }
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) {
      return (label: '⛔ EXPIRED', color: Colors.redAccent, days: days);
    } else if (days <= 7) {
      return (label: '🔴 Critical ($days days)', color: Colors.red, days: days);
    } else if (days <= 30) {
      return (
        label: '🟠 Expiring Soon ($days days)',
        color: Colors.orange,
        days: days,
      );
    } else if (days <= 90) {
      return (
        label: '🟡 Use Soon ($days days)',
        color: Colors.yellow,
        days: days,
      );
    }
    return (
      label: '✅ Good ($days days)',
      color: Colors.greenAccent,
      days: days,
    );
  }

  // =========================
  // HELPER WIDGETS
  // =========================
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleTypeChip(
    String value,
    String label,
    String selected,
    Function(String) onTap,
  ) {
    final bool isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool isDecimal = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType:
          keyboardType ??
          (isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : isNumber
              ? TextInputType.number
              : TextInputType.text),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _cartonStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _error(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _success(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(
                        Icons.local_pharmacy,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sell Medicine & Inventory',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              PharmacySession.pharmacyName ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          _loadMedicines();
                          _loadManufacturers();
                        },
                      ),
                    ],
                  ),
                ),

                // TAB BAR
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 11),
                    tabs: const [
                      Tab(text: '💊 Sell'),
                      Tab(text: '📦 Inventory'),
                      Tab(text: '📊 FEFO'),
                      Tab(text: '🔍 Substitute'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSellTab(),
                      _buildInventoryTab(),
                      _buildFefoTab(),
                      _buildSubstituteTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              heroTag: 'addManufacturer',
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Manufacturer',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _showManufacturerDialog,
            )
          : null,
    );
  }

  // =========================
  // TAB 1: SELL
  // =========================
  Widget _buildSellTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    hintText: 'Search name, generic, batch...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: () async {
                    final code = await _scanBarcode();
                    if (code != null && code.isNotEmpty) {
                      searchController.text = code;
                      _filterMedicines();
                    }
                  },
                  tooltip: 'Scan Barcode',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: loadingMedicines
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : filteredMedicines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.medication_outlined,
                        color: Colors.white24,
                        size: 60,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searchController.text.isEmpty
                            ? 'No medicines in stock'
                            : 'No results for "${searchController.text}"',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMedicines.length,
                  itemBuilder: (_, i) {
                    final m = filteredMedicines[i];
                    final status = _fefoStatus(m['expiry_date']?.toString());
                    final Color statusColor = status.color;
                    final bool isExpired = status.days < 0;
                    final int qty = (m['quantity'] as int?) ?? 0;
                    final int spb = (m['strips_per_box'] as int?) ?? 10;
                    final int cartonNum =
                        (m['cartons']?['carton_number'] as int?) ?? 1;
                    final int bpc =
                        (m['cartons']?['boxes_per_carton'] as int?) ?? 50;

                    return Card(
                      color: isExpired
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: isExpired ? null : () => _showSellDialog(m),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: statusColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    radius: 20,
                                    child: Icon(
                                      Icons.medication,
                                      color: statusColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['medicine_name']?.toString() ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if ((m['generic_name']?.toString() ??
                                                '')
                                            .isNotEmpty)
                                          Text(
                                            m['generic_name'],
                                            style: const TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  isExpired
                                      ? const Icon(
                                          Icons.block,
                                          color: Colors.redAccent,
                                        )
                                      : const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.white54,
                                          size: 14,
                                        ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _badge('📦 $qty boxes', Colors.blueAccent),
                                  _badge(
                                    '💊 ${qty * spb} strips',
                                    Colors.greenAccent,
                                  ),
                                  _badge(
                                    '🏭 ${bpc}×$cartonNum=${bpc * cartonNum}',
                                    Colors.orange,
                                  ),
                                  _badge(status.label, statusColor),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏭 ${m['cartons']?['manufacturers']?['name'] ?? 'Unknown'}  |  BDT ${m['price']}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================
  // TAB 2: INVENTORY
  // =========================
  Widget _buildInventoryTab() {
    return loadingManufacturers
        ? const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          )
        : manufacturers.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.business_outlined,
                  color: Colors.white24,
                  size: 60,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No manufacturers yet',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the + button below to add one',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: manufacturers.length,
            itemBuilder: (_, i) {
              final m = manufacturers[i];
              return Card(
                color: Colors.white.withValues(alpha: 0.10),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.business, color: Colors.white),
                  ),
                  title: Text(
                    m['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    m['country'] ?? 'Country N/A',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        onPressed: () => _showManufacturerDialog(existing: m),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () async {
                          await supabase
                              .from('manufacturers')
                              .delete()
                              .eq('id', m['id']);
                          _loadManufacturers();
                          _success('Deleted!');
                        },
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                  onTap: () => _viewMedicineBoxes(m['id'], m['name']),
                ),
              );
            },
          );
  }

  // =========================
  // TAB 3: FEFO
  // =========================
  Widget _buildFefoTab() {
    final sorted = [...allMedicines];
    sorted.sort((a, b) {
      final da =
          DateTime.tryParse(a['expiry_date']?.toString() ?? '') ??
          DateTime(2100);
      final db =
          DateTime.tryParse(b['expiry_date']?.toString() ?? '') ??
          DateTime(2100);
      return da.compareTo(db);
    });

    return loadingMedicines
        ? const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          )
        : sorted.isEmpty
        ? const Center(
            child: Text(
              'No medicines in stock',
              style: TextStyle(color: Colors.white54),
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.greenAccent,
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'FEFO — First Expiry First Out. Dispense from the top of this list first.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final m = sorted[i];
                    final status = _fefoStatus(m['expiry_date']?.toString());
                    final Color color = status.color;
                    final int qty = (m['quantity'] as int?) ?? 0;
                    final int spb = (m['strips_per_box'] as int?) ?? 10;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['medicine_name']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if ((m['generic_name']?.toString() ?? '')
                                    .isNotEmpty)
                                  Text(
                                    m['generic_name'],
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '📦 $qty boxes  |  💊 ${qty * spb} strips',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    status.label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  // =========================
  // TAB 4: SUBSTITUTE FINDER
  // =========================
  Widget _buildSubstituteTab() {
    return StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search by generic name to find substitute medicines in this pharmacy',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _substituteController,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) async {
                          final q = _substituteController.text.trim();
                          if (q.isEmpty) return;
                          setLocal(() => _searchingSubstitute = true);
                          try {
                            final res = await supabase
                                .from('medicine_boxes')
                                .select('*, cartons(*, manufacturers(name))')
                                .ilike('generic_name', '%$q%')
                                .eq(
                                  'pharmacy_id',
                                  PharmacySession.pharmacyId ?? '',
                                )
                                .order('medicine_name');
                            setLocal(() {
                              _substituteResults =
                                  List<Map<String, dynamic>>.from(res);
                              _searchingSubstitute = false;
                              _substitutedSearched = true;
                            });
                          } catch (e) {
                            setLocal(() => _searchingSubstitute = false);
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.science_outlined,
                            color: Colors.white70,
                          ),
                          hintText: 'Enter generic name (e.g. Atorvastatin)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: _searchingSubstitute
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search, color: Colors.white),
                        onPressed: _searchingSubstitute
                            ? null
                            : () async {
                                final q = _substituteController.text.trim();
                                if (q.isEmpty) return;
                                setLocal(() => _searchingSubstitute = true);
                                try {
                                  final res = await supabase
                                      .from('medicine_boxes')
                                      .select(
                                        '*, cartons(*, manufacturers(name))',
                                      )
                                      .ilike('generic_name', '%$q%')
                                      .eq(
                                        'pharmacy_id',
                                        PharmacySession.pharmacyId ?? '',
                                      )
                                      .order('medicine_name');
                                  setLocal(() {
                                    _substituteResults =
                                        List<Map<String, dynamic>>.from(res);
                                    _searchingSubstitute = false;
                                    _substitutedSearched = true;
                                  });
                                } catch (e) {
                                  setLocal(() => _searchingSubstitute = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: !_substitutedSearched
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, color: Colors.white24, size: 60),
                        SizedBox(height: 12),
                        Text(
                          'Search by generic name',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ],
                    ),
                  )
                : _substituteResults.isEmpty
                ? const Center(
                    child: Text(
                      'No substitutes found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _substituteResults.length,
                    itemBuilder: (_, i) {
                      final m = _substituteResults[i];
                      final int qty = (m['quantity'] as int?) ?? 0;
                      return Card(
                        color: Colors.white.withValues(alpha: 0.10),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.purple,
                            child: Icon(
                              Icons.medication,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            m['medicine_name']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🧬 ${m['generic_name'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '🏭 ${m['cartons']?['manufacturers']?['name'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '📦 $qty boxes  |  💰 BDT ${m['price']}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: qty > 0
                                  ? Colors.greenAccent
                                  : Colors.grey,
                            ),
                            onPressed: qty > 0
                                ? () => _showSellDialog(m)
                                : null,
                            child: const Text(
                              'Sell',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
