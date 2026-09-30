import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:googleapis/sheets/v4.dart' as s;
import 'package:googleapis_auth/auth_io.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

String c(List r, int i) => i < r.length ? r[i].toString() : '';
double n(List r, int i) => double.tryParse(c(r, i)) ?? 0;

class Db {
  static late s.SheetsApi api;
  static late String id;
  static Future<void> init() async {
    final cfg = jsonDecode(await rootBundle.loadString('assets/config.json'));
    id = cfg['spreadsheet_id'];
    final cl = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson(cfg['credentials']),
        [s.SheetsApi.spreadsheetsScope]);
    api = s.SheetsApi(cl);
    final sp = await api.spreadsheets.get(id);
    final have = sp.sheets!.map((e) => e.properties!.title).toSet();
    final heads = {
      'Products': ['الباركود', 'الاسم', 'السعر'],
      'Sales': ['الاسم', 'الباركود', 'التاريخ', 'السعر', 'الكمية', 'ملاحظات']
    };
    for (final e in heads.entries) {
      if (!have.contains(e.key)) {
        await api.spreadsheets.batchUpdate(
            s.BatchUpdateSpreadsheetRequest(requests: [
              s.Request(
                  addSheet: s.AddSheetRequest(
                      properties: s.SheetProperties(title: e.key)))
            ]),
            id);
        await append(e.key, e.value);
      }
    }
  }

  static Future<void> append(String sheet, List<Object> row) =>
      api.spreadsheets.values.append(s.ValueRange(values: [row]), id, '$sheet!A1',
          valueInputOption: 'RAW', insertDataOption: 'INSERT_ROWS');

  static Future<List<List<dynamic>>> get(String range) async =>
      (await api.spreadsheets.values.get(id, range)).values ?? [];
}

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'الصيدلية',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: FutureBuilder(
            future: Db.init(),
            builder: (_, snap) {
              if (snap.hasError) {
                return Scaffold(
                    body: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('خطأ في الإعداد:\n${snap.error}'))));
              }
              if (snap.connectionState != ConnectionState.done) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              return const Home();
            }),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(i == 0 ? 'بيع' : 'التقارير')),
        body: i == 0 ? const SellPage() : ReportPage(key: UniqueKey()),
        bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'بيع'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'التقارير'),
            ]),
      );
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('امسح الباركود')),
        body: MobileScanner(onDetect: (cap) {
          final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
          if (v != null && !done) {
            done = true;
            Navigator.pop(context, v);
          }
        }),
      );
}

class SellPage extends StatefulWidget {
  const SellPage({super.key});
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final manual = TextEditingController();
  bool busy = false;

  void msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> scan() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScanPage()));
    if (code != null) handle(code);
  }

  Future<void> handle(String code) async {
    setState(() => busy = true);
    try {
      final rows = await Db.get('Products!A2:C');
      final r = rows.firstWhere((x) => c(x, 0) == code, orElse: () => []);
      if (!mounted) return;
      final name = TextEditingController(text: r.isEmpty ? '' : c(r, 1));
      final price = TextEditingController(text: r.isEmpty ? '' : c(r, 2));
      final qty = TextEditingController(text: '1');
      final note = TextEditingController();
      final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(r.isEmpty ? 'منتج جديد + بيع' : 'بيع'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(code),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الدواء')),
                  TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
                  TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظات')),
                ])),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
                ],
              ));
      if (ok != true) return;
      final p = double.tryParse(price.text) ?? 0;
      final q = double.tryParse(qty.text) ?? 1;
      if (r.isEmpty) await Db.append('Products', [code, name.text, p]);
      await Db.append('Sales', [
        name.text, code,
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), p, q, note.text
      ]);
      msg('تم الحفظ');
    } catch (e) {
      msg('خطأ: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          FilledButton.icon(
              onPressed: busy ? null : scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Padding(padding: EdgeInsets.all(16), child: Text('مسح وبيع', style: TextStyle(fontSize: 20)))),
          const SizedBox(height: 24),
          TextField(controller: manual, decoration: InputDecoration(
              labelText: 'أو اكتب الباركود يدوياً',
              suffixIcon: IconButton(icon: const Icon(Icons.check), onPressed: busy || manual.text.isEmpty ? null : () => handle(manual.text.trim())))),
          if (busy) const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ]),
      );
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String range = 'today';
  List<List<dynamic>> sales = [], prods = [];
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      sales = await Db.get('Sales!A2:F');
      prods = await Db.get('Products!A2:C');
    } catch (e) {
      err = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (err != null) return Center(child: Text(err!));
    final now = DateTime.now();
    final prefix = range == 'today'
        ? DateFormat('yyyy-MM-dd').format(now)
        : range == 'month' ? DateFormat('yyyy-MM').format(now) : '';
    final f = sales.where((r) => c(r, 2).startsWith(prefix)).toList();
    final qtyBy = <String, double>{};
    final sold = <String>{};
    double total = 0;
    for (final r in f) {
      qtyBy[c(r, 0)] = (qtyBy[c(r, 0)] ?? 0) + n(r, 4);
      sold.add(c(r, 1));
      total += n(r, 3) * n(r, 4);
    }
    final notSold = prods.where((p) => !sold.contains(c(p, 0))).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'today', label: Text('اليوم')),
            ButtonSegment(value: 'month', label: Text('الشهر')),
            ButtonSegment(value: 'all', label: Text('الكل')),
          ],
          selected: {range},
          onSelectionChanged: (v) => setState(() => range = v.first)),
      const SizedBox(height: 12),
      Card(child: ListTile(title: Text('عدد العمليات: ${f.length}'), subtitle: Text('إجمالي المبيعات: ${total.toStringAsFixed(2)}'))),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('المباع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      ...qtyBy.entries.map((e) => ListTile(dense: true, title: Text(e.key), trailing: Text('× ${e.value.toStringAsFixed(0)}'))),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('ما انباع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      ...notSold.map((p) => ListTile(dense: true, title: Text(c(p, 1)))),
      TextButton(onPressed: () { setState(() => loading = true); load(); }, child: const Text('تحديث')),
    ]);
  }
}
