import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:my_money/cards/card_tagihan.dart';
import 'package:my_money/cards/card_uangku.dart';
import 'package:my_money/models/model_tagihan.dart';
import 'package:my_money/models/model_uangku.dart';
import 'package:my_money/utils/rupiah_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context){



    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Keuangan',
      home: const KeuanganPage(),
    );
  }
}

class KeuanganPage extends StatefulWidget {
  const KeuanganPage({super.key});

  @override
  State<KeuanganPage> createState() => _KeuanganPageState();
}

class _KeuanganPageState extends State<KeuanganPage> {

  List<Tagihan> tagihanList = [];
  List<Uangku> uangkuList = [];
  DateTime? lastUpdated;
  DateTime? targetDate;
  int targetTabungan = 0;

  int get sisaTarget {
    final sisa = targetTabungan - danaAman;
    return sisa < 0 ? 0 : sisa; // biar ga minus
  }

  int get sisaHari {
    if (targetDate == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      targetDate!.year,
      targetDate!.month,
      targetDate!.day,
    );

    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  int get tabunganPerHari {
    if (sisaHari == 0) return 0;
    return (sisaTarget / sisaHari).ceil(); // dibulatkan ke atas
  }

  int get totalTagihan =>
      tagihanList.fold<int>(0, (sum, e) => sum + e.jumlah);

  int get totalUangku =>
      uangkuList.fold<int>(0, (sum, e) => sum + e.jumlah);

  int get danaAman => totalUangku - totalTagihan;


  String formatTanggal(DateTime date) {
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final jam = date.hour.toString().padLeft(2, '0');
    final menit = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${bulan[date.month - 1]} ${date.year} • $jam:$menit';
  }


  @override
  void initState() {
    super.initState();
    _loadTagihan();
    _loadUangku();
    _loadTarget();
  }

  Future<void> _loadTagihan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tagihan') ?? [];

    setState(() {
      tagihanList = data
          .map((e) => Tagihan.fromJson(jsonDecode(e)))
          .toList();
      lastUpdated = DateTime.now();
    });
  }

  Future<void> _loadUangku() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('uangku') ?? [];

    setState(() {
      uangkuList = data
          .map((e) => Uangku.fromJson(jsonDecode(e)))
          .toList();
      lastUpdated = DateTime.now();
    });
  }

  Future<void> _loadTarget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final dateMillis = prefs.getInt('target_date');
      targetDate =
      dateMillis != null ? DateTime.fromMillisecondsSinceEpoch(dateMillis) : null;
      targetTabungan = prefs.getInt('target_amount') ?? 0;
    });
  }

  Future<void> _saveTarget() async {
    final prefs = await SharedPreferences.getInstance();
    if (targetDate != null) {
      await prefs.setInt(
        'target_date',
        targetDate!.millisecondsSinceEpoch,
      );
    }
    await prefs.setInt('target_amount', targetTabungan);
  }

  void showEditTarget() {
    final targetCtrl = TextEditingController(
      text: targetTabungan == 0
          ? ''
          : RupiahFormatter.format(targetTabungan),
    );


    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Edit Target',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: targetDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => targetDate = picked);
                }
              },
              child: Text(
                targetDate == null
                    ? 'Pilih Deadline'
                    : formatTanggal(targetDate!),
                style: GoogleFonts.poppins(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: targetCtrl,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: 'Target Tabungan',
                hintStyle: GoogleFonts.poppins()
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF63B967),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final cleanValue =
                targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

                setState(() {
                  targetTabungan = int.tryParse(cleanValue) ?? 0;
                });

                _saveTarget();
                Navigator.pop(context);
              },
              child: Text(
                'Simpan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5E35B1),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black, // <- beda warna
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Keuangan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,

          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastUpdated == null
                  ? 'Belum pernah diperbarui'
                  : 'Diperbarui : ${formatTanggal(lastUpdated!)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),

            InfoCardTagihan(
              title: 'Tagihanku',
              amount: tagihanList
                  .fold<int>(0, (sum, e) => sum + e.jumlah)
                  .toString(),
              items: tagihanList
                  .map((e) => {
                'name': e.nama,
                'amount': e.jumlah.toString(),
              })
                  .toList(),
              onChanged: _loadTagihan,
            ),

            const SizedBox(height: 16),

            InfoCardUangku(
              title: 'Uangku',
              amount: uangkuList
                  .fold<int>(0, (sum, e) => sum + e.jumlah)
                  .toString(),
              items: tagihanList
                  .map((e) => {
                'name': e.nama,
                'amount': e.jumlah.toString(),
              })
                  .toList(),
              onChanged: _loadUangku,
            ),



            const SizedBox(height: 16),

            Text(
              'Dana Aman : ${RupiahFormatter.format(danaAman)}',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),


            const Divider(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  targetDate == null
                      ? 'Target belum ditentukan'
                      : 'Target ${formatTanggal(targetDate!)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 28),
                  onPressed: showEditTarget,
                ),
              ],
            ),

            Text(
              targetTabungan == 0
                  ? '0'
                  : RupiahFormatter.format(targetTabungan),
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.w600,
              ),
            ),



            const SizedBox(height: 18),

            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 14,
                  child: Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  RupiahFormatter.format(sisaTarget),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),


            const SizedBox(height: 12),

            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 14,
                  child: Icon(
                    Icons.attach_money,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  RupiahFormatter.format(tabunganPerHari),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }


}
