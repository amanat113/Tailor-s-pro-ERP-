import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.bootstrap();
  runApp(TailorsErpApp(appState: appState));
}

class AppTheme {
  static const ink = Color(0xFF1E232B);
  static const navy = Color(0xFF203A5F);
  static const gold = Color(0xFFC49A5F);
  static const paper = Color(0xFFF7F2EA);
  static const card = Color(0xFFFFFCF7);
  static const border = Color(0xFFE5DDD0);
  static const muted = Color(0xFF667085);
  static const green = Color(0xFF2E7D65);
  static const red = Color(0xFFB42318);
  static const blue = Color(0xFF2376B7);

  static ThemeData theme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.light(
        primary: navy,
        secondary: gold,
        tertiary: green,
        surface: card,
        error: red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w700),
        hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: gold, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: red)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
    );
  }
}

class TailorsErpApp extends StatelessWidget {
  const TailorsErpApp({required this.appState, super.key});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: "Tailor's ERP",
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme(),
          home: RootShell(appState: appState),
        );
      },
    );
  }
}

enum UserRole { select, owner, manager, staff }

enum OrderStatus { pending, cutting, stitching, ready, delivered }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.select => 'Select Role',
        UserRole.owner => 'Owner',
        UserRole.manager => 'Manager',
        UserRole.staff => 'Staff',
      };
  String get value => name;
  Duration get maxInactive => this == UserRole.staff ? const Duration(hours: 24) : const Duration(minutes: 20);
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.cutting => 'Cutting',
        OrderStatus.stitching => 'Stitching',
        OrderStatus.ready => 'Ready',
        OrderStatus.delivered => 'Delivered',
      };
  Color get color => switch (this) {
        OrderStatus.pending => const Color(0xFFB7791F),
        OrderStatus.cutting => AppTheme.blue,
        OrderStatus.stitching => const Color(0xFF7C3AED),
        OrderStatus.ready => AppTheme.green,
        OrderStatus.delivered => const Color(0xFF475467),
      };
  static OrderStatus parse(String? raw) {
    return OrderStatus.values.firstWhere((e) => e.name == raw, orElse: () => OrderStatus.pending);
  }
}

class AppState extends ChangeNotifier {
  bool firebaseReady = false;
  String firebaseMessage = 'Starting...';
  bool busy = false;
  String mobile = '';
  String verificationId = '';
  bool otpSent = false;
  User? firebaseUser;
  UserRole role = UserRole.select;
  bool pinVerified = false;
  DateTime lastActiveAt = DateTime.now();
  Timer? _securityTimer;

  FirebaseFirestore get db => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;
  DocumentReference<Map<String, dynamic>> get shop => db.collection('shops').doc('default_shop');

  Future<void> bootstrap() async {
    try {
      await Firebase.initializeApp();
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
      firebaseReady = true;
      firebaseMessage = 'Firebase connected';
    } catch (e) {
      firebaseReady = false;
      firebaseMessage = 'Firebase config missing. Upload google-services.json and rebuild APK.';
    }
    firebaseUser = firebaseReady ? auth.currentUser : null;
    _securityTimer?.cancel();
    _securityTimer = Timer.periodic(const Duration(seconds: 30), (_) => validateSession());
    notifyListeners();
  }

  bool get loggedIn => firebaseReady && firebaseUser != null && pinVerified && role != UserRole.select;

  void touch() {
    lastActiveAt = DateTime.now();
  }

  Future<void> validateSession() async {
    if (!loggedIn) return;
    if (DateTime.now().difference(lastActiveAt) > role.maxInactive) {
      await logout();
    }
  }

  Future<void> logout() async {
    if (firebaseReady) await auth.signOut();
    firebaseUser = null;
    mobile = '';
    verificationId = '';
    otpSent = false;
    pinVerified = false;
    role = UserRole.select;
    notifyListeners();
  }

  Future<void> sendOtp(String inputMobile) async {
    if (!firebaseReady) throw StateError(firebaseMessage);
    final number = normalizePhone(inputMobile);
    if (number.length < 13) throw StateError('Enter a valid 10 digit Indian mobile number.');
    busy = true;
    mobile = number;
    notifyListeners();
    final completer = Completer<void>();
    await auth.verifyPhoneNumber(
      phoneNumber: number,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await auth.signInWithCredential(credential);
        firebaseUser = auth.currentUser;
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(StateError(e.message ?? 'OTP failed.'));
      },
      codeSent: (id, token) {
        verificationId = id;
        otpSent = true;
        if (!completer.isCompleted) completer.complete();
        notifyListeners();
      },
      codeAutoRetrievalTimeout: (id) {
        verificationId = id;
        notifyListeners();
      },
    );
    await completer.future;
    busy = false;
    notifyListeners();
  }

  Future<void> verifyOtp(String otp) async {
    if (!firebaseReady) throw StateError(firebaseMessage);
    if (verificationId.isEmpty) throw StateError('OTP verification ID missing. Please resend OTP.');
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp.trim());
    final result = await auth.signInWithCredential(credential);
    firebaseUser = result.user;
    if (firebaseUser == null) throw StateError('Firebase login failed.');
    await audit('otp_login', {'mobile': mobile});
    notifyListeners();
  }

  Future<bool> hasPin() async {
    if (firebaseUser == null) return false;
    final snap = await shop.collection('users').doc(firebaseUser!.uid).get();
    return snap.exists && (snap.data()?['pinHash'] ?? '').toString().isNotEmpty;
  }

  Future<void> setupOrVerifyPin(String pin, {required bool setup}) async {
    if (firebaseUser == null) throw StateError('Login first.');
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) throw StateError('PIN must be 4 to 8 digits.');
    final userDoc = shop.collection('users').doc(firebaseUser!.uid);
    if (setup) {
      final salt = randomSalt();
      await userDoc.set({
        'uid': firebaseUser!.uid,
        'mobile': mobile,
        'pinSalt': salt,
        'pinHash': hashPin(mobile, pin, salt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      pinVerified = true;
      await audit('pin_setup', {'mobile': mobile});
      notifyListeners();
      return;
    }
    final snap = await userDoc.get();
    final data = snap.data();
    if (data == null) throw StateError('PIN is not set for this account.');
    final salt = '${data['pinSalt'] ?? ''}';
    final expected = '${data['pinHash'] ?? ''}';
    if (hashPin('${data['mobile'] ?? mobile}', pin, salt) != expected) throw StateError('Wrong PIN.');
    pinVerified = true;
    await audit('pin_verified', {'mobile': mobile});
    notifyListeners();
  }

  Future<void> selectRole(UserRole selected) async {
    if (selected == UserRole.select) throw StateError('Please select a role.');
    role = selected;
    lastActiveAt = DateTime.now();
    await shop.collection('users').doc(firebaseUser!.uid).set({
      'role': selected.value,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await audit('role_selected', {'role': selected.value});
    notifyListeners();
  }

  Future<void> audit(String action, Map<String, dynamic> payload) async {
    if (!firebaseReady || firebaseUser == null) return;
    await shop.collection('auditLogs').add({
      'action': action,
      'payload': payload,
      'uid': firebaseUser!.uid,
      'mobile': mobile,
      'role': role.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  if (raw.trim().startsWith('+')) return raw.trim();
  return '+91$digits';
}

String randomSalt() => List.generate(16, (_) => Random.secure().nextInt(255).toRadixString(16).padLeft(2, '0')).join();
String hashPin(String mobile, String pin, String salt) => sha256.convert(utf8.encode('$mobile|$pin|$salt')).toString();
String money(num value) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
DateTime asDate(dynamic v) => v is Timestamp ? v.toDate() : DateTime.tryParse('$v') ?? DateTime.now();

class RootShell extends StatefulWidget {
  const RootShell({required this.appState, super.key});
  final AppState appState;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    if (!app.firebaseReady) return SetupBlockedScreen(appState: app);
    if (app.firebaseUser == null) return LoginScreen(appState: app);
    if (!app.pinVerified) return PinGateScreen(appState: app);
    if (app.role == UserRole.select) return RoleScreen(appState: app);
    return GestureDetector(onTap: app.touch, onPanDown: (_) => app.touch(), child: HomeShell(appState: app));
  }
}

class SetupBlockedScreen extends StatelessWidget {
  const SetupBlockedScreen({required this.appState, super.key});
  final AppState appState;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppCard(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.cloud_off_rounded, size: 54, color: AppTheme.red),
                const SizedBox(height: 18),
                const Text('Firebase setup required', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(appState.firebaseMessage, style: const TextStyle(color: AppTheme.muted, height: 1.45)),
                const SizedBox(height: 16),
                const Text('This app has no demo OTP. Add google-services.json, enable Phone Auth, Firestore and Storage, then rebuild APK.', style: TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Retry Firebase', icon: Icons.refresh_rounded, onPressed: appState.bootstrap),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.appState, super.key});
  final AppState appState;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final mobile = TextEditingController();
  final otp = TextEditingController();
  bool loading = false;

  Future<void> run(Future<void> Function() job) async {
    setState(() => loading = true);
    try {
      await job();
      if (mounted) showOk(context, 'Success');
    } catch (e) {
      if (mounted) showErr(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpSent = widget.appState.otpSent;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 44),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: AppTheme.navy, borderRadius: BorderRadius.circular(24)),
              child: const Center(child: Text('TE', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 28),
            const Text("Tailor's ERP", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Real tailoring and garment management system', style: TextStyle(color: AppTheme.muted, fontSize: 16)),
            const SizedBox(height: 28),
            AppCard(child: Column(children: [
              TextField(controller: mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_rounded), hintText: '10 digit mobile')),
              const SizedBox(height: 14),
              if (otpSent) TextField(controller: otp, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'OTP Code', prefixIcon: Icon(Icons.verified_rounded), counterText: '')),
              const SizedBox(height: 14),
              PrimaryButton(
                loading: loading,
                label: otpSent ? 'Verify OTP' : 'Send Real OTP',
                icon: otpSent ? Icons.check_circle_rounded : Icons.sms_rounded,
                onPressed: () => run(() => otpSent ? widget.appState.verifyOtp(otp.text) : widget.appState.sendOtp(mobile.text)),
              ),
            ])),
          ]),
        ),
      ),
    );
  }
}

class PinGateScreen extends StatefulWidget {
  const PinGateScreen({required this.appState, super.key});
  final AppState appState;
  @override
  State<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends State<PinGateScreen> {
  final pin = TextEditingController();
  bool loading = true;
  bool setup = true;

  @override
  void initState() {
    super.initState();
    widget.appState.hasPin().then((exists) {
      if (mounted) setState(() { setup = !exists; loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: AppCard(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lock_rounded, color: AppTheme.gold, size: 48),
                const SizedBox(height: 16),
                Text(setup ? 'Create PIN' : 'Enter PIN', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(setup ? 'Create a secure 4-8 digit PIN.' : 'Use your saved PIN to continue.', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                TextField(controller: pin, keyboardType: TextInputType.number, obscureText: true, maxLength: 8, decoration: const InputDecoration(labelText: 'PIN', prefixIcon: Icon(Icons.password_rounded), counterText: '')),
                const SizedBox(height: 14),
                PrimaryButton(label: setup ? 'Save PIN' : 'Unlock', icon: Icons.lock_open_rounded, onPressed: () async {
                  try {
                    await widget.appState.setupOrVerifyPin(pin.text, setup: setup);
                  } catch (e) { if (context.mounted) showErr(context, e); }
                }),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleScreen extends StatefulWidget {
  const RoleScreen({required this.appState, super.key});
  final AppState appState;
  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  UserRole role = UserRole.select;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: AppCard(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.gold, size: 48),
                const SizedBox(height: 16),
                const Text('Select Role', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Role controls permissions inside the app.', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 18),
                DropdownButtonFormField<UserRole>(value: role, decoration: const InputDecoration(labelText: 'Role'), items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: (v) => setState(() => role = v ?? UserRole.select)),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: () async {
                  try { await widget.appState.selectRole(role); } catch (e) { if (context.mounted) showErr(context, e); }
                }),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({required this.appState, super.key});
  final AppState appState;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final screens = [DashboardPage(app: widget.appState), ProcessingPage(app: widget.appState), DeliveryPage(app: widget.appState), StaffPage(app: widget.appState), SettingsPage(app: widget.appState)];
    return Scaffold(
      drawer: AppDrawer(app: widget.appState, onSelect: (i) => setState(() => index = i)),
      body: Stack(children: [
        screens[index],
        Positioned(left: 18, right: 18, bottom: 18, child: FloatingNav(index: index, onChanged: (i) => setState(() => index = i), onAdd: () => showOrderSheet(context, widget.appState))),
      ]),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92),
        child: FloatingActionButton.small(backgroundColor: AppTheme.navy, foregroundColor: Colors.white, onPressed: () => showCalculator(context), child: const Icon(Icons.calculate_rounded)),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.app, required this.onSelect, super.key});
  final AppState app;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final items = [
      (0, Icons.home_rounded, 'Home'),
      (1, Icons.construction_rounded, 'Processing'),
      (2, Icons.local_shipping_rounded, 'Delivery'),
      (3, Icons.groups_rounded, 'Staff Ledger'),
      (4, Icons.settings_rounded, 'Settings'),
    ];
    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(20), child: Text("Tailor's ERP", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
          for (final it in items)
            ListTile(leading: Icon(it.$2), title: Text(it.$3), onTap: () { Navigator.pop(context); onSelect(it.$1); }),
          const Spacer(),
          ListTile(leading: const Icon(Icons.logout_rounded, color: AppTheme.red), title: const Text('Logout'), onTap: app.logout),
        ]),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.app, super.key});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final orders = app.shop.collection('orders').orderBy('createdAt', descending: true);
    return Scaffold(
      appBar: AppBar(title: const Text("Tailor's ERP"), leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openDrawer())), actions: [IconButton(onPressed: () => app.logout(), icon: const Icon(Icons.logout_rounded))]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: orders.snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final data = docs.map((d) => {'id': d.id, ...d.data()}).toList();
          final active = data.where((o) => o['status'] != 'delivered').toList();
          final totalClothes = active.fold<int>(0, (s, o) => s + ((o['clothQty'] ?? 0) as num).toInt());
          final pendingClothes = active.fold<int>(0, (s, o) => s + ((o['pendingQty'] ?? 0) as num).toInt());
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 120), children: [
              Row(children: [
                Expanded(child: MetricCard(title: 'Total Orders', value: '${data.length}', icon: Icons.receipt_long_rounded)),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(title: 'Active Orders', value: '${active.length}', icon: Icons.timelapse_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: MetricCard(title: 'Total Clothes', value: '$totalClothes', icon: Icons.checkroom_rounded)),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(title: 'Pending Clothes', value: '$pendingClothes', icon: Icons.cut_rounded)),
              ]),
              const SizedBox(height: 22),
              Row(children: [const Expanded(child: Text('Recent Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), TextButton(onPressed: () {}, child: const Text('View all'))]),
              if (docs.isEmpty) EmptyState(title: 'No orders yet', subtitle: 'Tap + New Order to create the first order.'),
              for (final order in data.take(12)) OrderCard(order: order, app: app),
            ]),
          );
        },
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({required this.title, required this.value, required this.icon, super.key});
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppTheme.gold, size: 28),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        Text(title, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({required this.order, required this.app, super.key});
  final Map<String, dynamic> order;
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final status = OrderStatusX.parse('${order['status']}');
    final due = ((order['due'] ?? 0) as num).toDouble();
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: AppTheme.navy.withOpacity(.09), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.receipt_rounded, color: AppTheme.navy)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${order['slip'] ?? ''}', style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.w900)),
          Text('${order['customerName'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Text('${order['mobile'] ?? ''}', style: const TextStyle(color: AppTheme.muted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusBadge(status: status),
          const SizedBox(height: 8),
          Text(due <= 0 ? 'Paid' : '${money(due)} due', style: TextStyle(fontWeight: FontWeight.w900, color: due <= 0 ? AppTheme.green : AppTheme.red)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => confirmCall(context, '${order['mobile'] ?? ''}'), icon: const Icon(Icons.phone_rounded)),
            IconButton(onPressed: () => showOrderSheet(context, app, existing: order), icon: const Icon(Icons.edit_rounded)),
          ]),
        ]),
      ]),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});
  final OrderStatus status;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: status.color.withOpacity(.11), borderRadius: BorderRadius.circular(30), border: Border.all(color: status.color.withOpacity(.45))), child: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w900)));
}

Future<void> showOrderSheet(BuildContext context, AppState app, {Map<String, dynamic>? existing}) async {
  await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => OrderForm(app: app, existing: existing));
}

class OrderForm extends StatefulWidget {
  const OrderForm({required this.app, this.existing, super.key});
  final AppState app;
  final Map<String, dynamic>? existing;
  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final slip = TextEditingController();
  final name = TextEditingController();
  final mobile = TextEditingController();
  final qty = TextEditingController(text: '1');
  final bill = TextEditingController(text: '0');
  final advance = TextEditingController(text: '0');
  final design = TextEditingController();
  final Map<String, TextEditingController> measures = {};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      slip.text = '${e['slip'] ?? ''}'; name.text = '${e['customerName'] ?? ''}'; mobile.text = '${e['mobile'] ?? ''}'; qty.text = '${e['clothQty'] ?? 1}'; bill.text = '${e['totalBill'] ?? 0}'; advance.text = '${e['advance'] ?? 0}'; design.text = '${e['designUrl'] ?? ''}';
      final m = Map<String, dynamic>.from(e['measurements'] ?? {});
      for (final entry in m.entries) { measures[entry.key] = TextEditingController(text: '${entry.value}'); }
    }
  }

  double get due => max(0, (double.tryParse(bill.text) ?? 0) - (double.tryParse(advance.text) ?? 0));

  Future<List<String>> loadMeasurementLabels() async {
    final snap = await widget.app.shop.collection('settings').doc('measurements').get();
    final labels = List<String>.from(snap.data()?['labels'] ?? ['Length', 'Chest', 'Waist', 'Shoulder', 'Sleeve']);
    for (final l in labels) { measures.putIfAbsent(l, () => TextEditingController()); }
    return labels;
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final s = slip.text.trim();
      if (s.isEmpty) throw StateError('Slip number required.');
      if (name.text.trim().isEmpty) throw StateError('Customer name required.');
      final normalized = normalizePhone(mobile.text);
      final clothQty = int.tryParse(qty.text) ?? 0;
      if (clothQty <= 0) throw StateError('Cloth quantity must be more than 0.');
      final doc = widget.app.shop.collection('orders').doc(s);
      if (widget.existing == null && (await doc.get()).exists) throw StateError('Duplicate slip number not allowed.');
      final totalBill = double.tryParse(bill.text) ?? 0;
      final adv = min(double.tryParse(advance.text) ?? 0, totalBill);
      final old = widget.existing;
      final currentDelivered = ((old?['deliveredQty'] ?? 0) as num?)?.toInt() ?? 0;
      final currentReady = ((old?['readyQty'] ?? 0) as num?)?.toInt() ?? 0;
      final measurements = {for (final e in measures.entries) e.key: e.value.text.trim()};
      await doc.set({
        'slip': s,
        'customerName': name.text.trim(),
        'mobile': normalized,
        'clothQty': clothQty,
        'pendingQty': max(0, clothQty - currentReady - currentDelivered),
        'cuttingQty': ((old?['cuttingQty'] ?? 0) as num?)?.toInt() ?? 0,
        'readyQty': currentReady,
        'deliveredQty': currentDelivered,
        'totalBill': totalBill,
        'advance': adv,
        'paid': (old?['paid'] ?? adv),
        'due': max(0, totalBill - (old?['paid'] ?? adv)),
        'designUrl': design.text.trim(),
        'measurements': measurements,
        'status': old?['status'] ?? OrderStatus.pending.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (old == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await widget.app.audit(old == null ? 'order_created' : 'order_updated', {'slip': s});
      if (old == null) await sendWhatsApp(normalized, 'Hello ${name.text.trim()}, your order (Slip: $s) has been placed. Total: ${money(totalBill)}, Advance: ${money(adv)}, Due: ${money(totalBill - adv)}. Thank you!');
      if (mounted) { Navigator.pop(context); showOk(context, 'Order saved'); }
    } catch (e) { if (mounted) showErr(context, e); } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> slipPdf() async {
    final bytes = await buildSlipPdf(shopName: "Tailor's ERP", slip: slip.text, name: name.text, mobile: mobile.text, measurements: {for (final e in measures.entries) e.key: e.value.text}, total: double.tryParse(bill.text) ?? 0, advance: double.tryParse(advance.text) ?? 0);
    await Printing.sharePdf(bytes: bytes, filename: 'slip_${slip.text}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(initialChildSize: .9, maxChildSize: .96, minChildSize: .55, builder: (context, scroll) {
      return Container(
        decoration: const BoxDecoration(color: AppTheme.paper, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: FutureBuilder<List<String>>(
          future: loadMeasurementLabels(),
          builder: (context, labelsSnap) {
            final labels = labelsSnap.data ?? [];
            return ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
              Row(children: [Expanded(child: Text(widget.existing == null ? 'New Order' : 'Edit Order', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
              TextField(controller: slip, enabled: widget.existing == null, decoration: const InputDecoration(labelText: 'Manual Slip Number')),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer Name')),
              const SizedBox(height: 12),
              TextField(controller: mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number')),
              const SizedBox(height: 12),
              TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cloth Quantity')),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [for (final l in labels) SizedBox(width: MediaQuery.of(context).size.width / 2 - 26, child: TextField(controller: measures[l], decoration: InputDecoration(labelText: l)))]),
              const SizedBox(height: 12),
              TextField(controller: bill, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Bill')),
              const SizedBox(height: 12),
              TextField(controller: advance, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advance Payment')),
              const SizedBox(height: 10),
              Text('Due: ${money(due)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.red)),
              const SizedBox(height: 12),
              TextField(controller: design, decoration: const InputDecoration(labelText: 'Design Image URL / Reference Link')),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save Order', icon: Icons.save_rounded, loading: saving, onPressed: save),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: slipPdf, icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Generate PDF Slip')),
            ]);
          },
        ),
      );
    });
  }
}

class ProcessingPage extends StatefulWidget {
  const ProcessingPage({required this.app, super.key});
  final AppState app;
  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  final search = TextEditingController();
  Map<String, dynamic>? order;
  Future<void> load() async {
    final doc = await widget.app.shop.collection('orders').doc(search.text.trim()).get();
    setState(() => order = doc.exists ? {'id': doc.id, ...doc.data()!} : null);
    if (order == null && mounted) showErr(context, 'Order not found.');
  }

  Future<void> updateQty(String field, int delta, OrderStatus newStatus, String messageKind) async {
    final o = order!;
    final slip = '${o['slip']}';
    final ref = widget.app.shop.collection('orders').doc(slip);
    final pending = ((o['pendingQty'] ?? 0) as num).toInt();
    final cutting = ((o['cuttingQty'] ?? 0) as num).toInt();
    final ready = ((o['readyQty'] ?? 0) as num).toInt();
    if (field == 'cuttingQty' && pending <= 0) throw StateError('No pending cloth available.');
    if (field == 'readyQty' && cutting <= 0) throw StateError('No cutting cloth available.');
    final update = <String, dynamic>{'status': newStatus.name, 'updatedAt': FieldValue.serverTimestamp()};
    if (field == 'cuttingQty') { update['pendingQty'] = pending - delta; update['cuttingQty'] = cutting + delta; }
    if (field == 'readyQty') { update['cuttingQty'] = cutting - delta; update['readyQty'] = ready + delta; }
    await ref.update(update);
    await widget.app.audit('process_update', {'slip': slip, 'field': field});
    await load();
    final fresh = order!;
    if (messageKind == 'cutting' && ((fresh['pendingQty'] ?? 0) as num).toInt() == 0) await sendWhatsApp('${fresh['mobile']}', 'Hello ${fresh['customerName']}, cutting for your order (Slip: $slip) is complete and stitching has begun.');
    if (messageKind == 'ready' && ((fresh['cuttingQty'] ?? 0) as num).toInt() == 0 && ((fresh['readyQty'] ?? 0) as num).toInt() > 0) await sendWhatsApp('${fresh['mobile']}', 'Good news ${fresh['customerName']}! Your clothes (Slip: $slip) are ready for delivery.');
  }

  @override
  Widget build(BuildContext context) {
    return StandardPage(title: 'Processing', child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 120), children: [
      Row(children: [Expanded(child: TextField(controller: search, decoration: const InputDecoration(labelText: 'Search Slip Number'))), const SizedBox(width: 10), SizedBox(height: 54, child: FilledButton(onPressed: load, child: const Icon(Icons.search_rounded)))]),
      const SizedBox(height: 16),
      if (order != null) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('#${order!['slip']} - ${order!['customerName']}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Pending: ${order!['pendingQty']}  |  Cutting: ${order!['cuttingQty']}  |  Ready: ${order!['readyQty']}  |  Delivered: ${order!['deliveredQty']}', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Move 1 Pending to Cutting', icon: Icons.cut_rounded, onPressed: () async { try { await updateQty('cuttingQty', 1, OrderStatus.cutting, 'cutting'); } catch(e){ if(context.mounted) showErr(context,e); } }),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Move 1 Cutting to Ready', icon: Icons.check_rounded, onPressed: () async { try { await updateQty('readyQty', 1, OrderStatus.ready, 'ready'); } catch(e){ if(context.mounted) showErr(context,e); } }),
      ])),
    ]));
  }
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({required this.app, super.key});
  final AppState app;
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final search = TextEditingController();
  final deliverQty = TextEditingController(text: '1');
  final paid = TextEditingController(text: '0');
  Map<String, dynamic>? order;
  Future<void> load() async {
    final doc = await widget.app.shop.collection('orders').doc(search.text.trim()).get();
    setState(() => order = doc.exists ? {'id': doc.id, ...doc.data()!} : null);
    if (order == null && mounted) showErr(context, 'Order not found.');
  }

  Future<void> deliver() async {
    final o = order!;
    final qty = int.tryParse(deliverQty.text) ?? 0;
    final ready = ((o['readyQty'] ?? 0) as num).toInt();
    if (qty <= 0 || qty > ready) throw StateError('Delivery quantity must be between 1 and ready quantity.');
    final payment = double.tryParse(paid.text) ?? 0;
    final totalPaid = ((o['paid'] ?? o['advance'] ?? 0) as num).toDouble() + payment;
    final totalBill = ((o['totalBill'] ?? 0) as num).toDouble();
    final delivered = ((o['deliveredQty'] ?? 0) as num).toInt() + qty;
    final clothQty = ((o['clothQty'] ?? 0) as num).toInt();
    final status = delivered >= clothQty ? OrderStatus.delivered : OrderStatus.ready;
    await widget.app.shop.collection('orders').doc('${o['slip']}').update({
      'readyQty': ready - qty,
      'deliveredQty': delivered,
      'paid': min(totalPaid, totalBill),
      'due': max(0, totalBill - totalPaid),
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == OrderStatus.delivered) 'deliveredAt': FieldValue.serverTimestamp(),
    });
    await widget.app.shop.collection('deliveryLedger').add({'slip': o['slip'], 'qty': qty, 'payment': payment, 'createdAt': FieldValue.serverTimestamp()});
    await widget.app.audit('delivery_confirmed', {'slip': o['slip'], 'qty': qty, 'payment': payment});
    await sendWhatsApp('${o['mobile']}', 'Thank you ${o['customerName']}! Your order (Slip: ${o['slip']}) has been successfully delivered.');
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return StandardPage(title: 'Delivery', child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 120), children: [
      Row(children: [Expanded(child: TextField(controller: search, decoration: const InputDecoration(labelText: 'Search Slip Number'))), const SizedBox(width: 10), SizedBox(height: 54, child: FilledButton(onPressed: load, child: const Icon(Icons.search_rounded)))]),
      const SizedBox(height: 16),
      if (order != null) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('#${order!['slip']} - ${order!['customerName']}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Ready: ${order!['readyQty']} | Delivered: ${order!['deliveredQty']} | Due: ${money(order!['due'] ?? 0)}', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(controller: deliverQty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Deliver Quantity Now')),
        const SizedBox(height: 12),
        TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Payment Received Now')),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Confirm Delivery', icon: Icons.local_shipping_rounded, onPressed: () async { try { await deliver(); if(context.mounted) showOk(context, 'Delivery saved'); } catch(e){ if(context.mounted) showErr(context,e); } }),
      ])),
    ]));
  }
}

class StaffPage extends StatefulWidget {
  const StaffPage({required this.app, super.key});
  final AppState app;
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final staffName = TextEditingController();
  final spec = TextEditingController();
  final type = TextEditingController();
  final rate = TextEditingController();
  final qty = TextEditingController(text: '1');
  final paid = TextEditingController(text: '0');
  String? selectedStaff;
  String? selectedType;

  Future<void> addStaff() async {
    if (staffName.text.trim().isEmpty) throw StateError('Staff name required.');
    await widget.app.shop.collection('staff').add({'name': staffName.text.trim(), 'specialization': spec.text.trim(), 'createdAt': FieldValue.serverTimestamp()});
    staffName.clear(); spec.clear();
  }

  Future<void> addRate() async {
    if (type.text.trim().isEmpty) throw StateError('Type required.');
    await widget.app.shop.collection('stitchRates').doc(type.text.trim()).set({'type': type.text.trim(), 'rate': double.tryParse(rate.text) ?? 0});
    type.clear(); rate.clear();
  }

  Future<void> saveWork() async {
    if (selectedStaff == null || selectedType == null) throw StateError('Select staff and stitch type.');
    final rateDoc = await widget.app.shop.collection('stitchRates').doc(selectedType!).get();
    final r = ((rateDoc.data()?['rate'] ?? 0) as num).toDouble();
    final q = int.tryParse(qty.text) ?? 0;
    final earning = r * q;
    final p = double.tryParse(paid.text) ?? 0;
    await widget.app.shop.collection('staffLedger').add({'staffId': selectedStaff, 'type': selectedType, 'rate': r, 'qty': q, 'earning': earning, 'paid': p, 'balance': earning - p, 'createdAt': FieldValue.serverTimestamp()});
    await widget.app.audit('staff_work_saved', {'staffId': selectedStaff, 'type': selectedType, 'earning': earning, 'paid': p});
  }

  @override
  Widget build(BuildContext context) {
    return StandardPage(title: 'Staff Ledger', child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 120), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add Staff', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(controller: staffName, decoration: const InputDecoration(labelText: 'Staff Name')),
        const SizedBox(height: 10),
        TextField(controller: spec, decoration: const InputDecoration(labelText: 'Specialization')),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Add Staff', icon: Icons.person_add_rounded, onPressed: () async { try { await addStaff(); if(context.mounted) showOk(context, 'Staff added'); } catch(e){ if(context.mounted) showErr(context,e); } }),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Clothing Type & Piece Rate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: type, decoration: const InputDecoration(labelText: 'Type'))), const SizedBox(width: 10), Expanded(child: TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate')))]),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Set Rate', icon: Icons.price_check_rounded, onPressed: () async { try { await addRate(); if(context.mounted) showOk(context, 'Rate saved'); } catch(e){ if(context.mounted) showErr(context,e); } }),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily Work Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: widget.app.shop.collection('staff').snapshots(), builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          return DropdownButtonFormField<String>(value: selectedStaff, decoration: const InputDecoration(labelText: 'Select Staff'), items: docs.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.data()['name']}'))).toList(), onChanged: (v) => setState(() => selectedStaff = v));
        }),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: widget.app.shop.collection('stitchRates').snapshots(), builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          return DropdownButtonFormField<String>(value: selectedType, decoration: const InputDecoration(labelText: 'Select Stitch Type'), items: docs.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.data()['type']} - ${money(d.data()['rate'] ?? 0)}'))).toList(), onChanged: (v) => setState(() => selectedType = v));
        }),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: DropdownButtonFormField<int>(value: int.tryParse(qty.text) ?? 1, decoration: const InputDecoration(labelText: 'Qty'), items: List.generate(10, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) => qty.text = '${v ?? 1}')), const SizedBox(width: 10), Expanded(child: TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Paid Today')))]),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Save Work', icon: Icons.save_rounded, onPressed: () async { try { await saveWork(); if(context.mounted) showOk(context, 'Work saved'); } catch(e){ if(context.mounted) showErr(context,e); } }),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('All Time Staff Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: widget.app.shop.collection('staffLedger').orderBy('createdAt', descending: true).limit(50).snapshots(), builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Text('No staff work yet.', style: TextStyle(color: AppTheme.muted));
          final earning = docs.fold<double>(0, (s, d) => s + ((d.data()['earning'] ?? 0) as num).toDouble());
          final paidTotal = docs.fold<double>(0, (s, d) => s + ((d.data()['paid'] ?? 0) as num).toDouble());
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Work: ${money(earning)} | Paid: ${money(paidTotal)} | Balance: ${money(earning - paidTotal)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const Divider(),
            for (final d in docs.take(12)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${d.data()['type']} × ${d.data()['qty']}'), subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(asDate(d.data()['createdAt']))), trailing: Text(money(d.data()['balance'] ?? 0))),
          ]);
        }),
      ])),
    ]));
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.app, super.key});
  final AppState app;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final shopName = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final measurement = TextEditingController();
  final resetText = TextEditingController();
  final resetPin = TextEditingController();

  Future<void> saveShop() async {
    await widget.app.shop.collection('settings').doc('shopInfo').set({'shopName': shopName.text.trim(), 'address': address.text.trim(), 'phone': phone.text.trim(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> addMeasurement() async {
    final label = measurement.text.trim();
    if (label.isEmpty) return;
    await widget.app.shop.collection('settings').doc('measurements').set({'labels': FieldValue.arrayUnion([label])}, SetOptions(merge: true));
    measurement.clear();
  }

  Future<void> resetData() async {
    if (widget.app.role != UserRole.owner) throw StateError('Only owner can reset data.');
    if (resetText.text.trim() != 'CONFIRM') throw StateError('Type CONFIRM to reset.');
    await widget.app.setupOrVerifyPin(resetPin.text, setup: false);
    final collections = ['orders', 'staff', 'staffLedger', 'stitchRates', 'deliveryLedger', 'auditLogs'];
    for (final c in collections) {
      final snap = await widget.app.shop.collection(c).limit(300).get();
      for (final d in snap.docs) { await d.reference.delete(); }
    }
    await widget.app.audit('data_reset', {'collections': collections});
  }

  Future<void> backup() async {
    final data = <String, dynamic>{};
    for (final c in ['orders', 'staff', 'staffLedger', 'stitchRates', 'deliveryLedger']) {
      final snap = await widget.app.shop.collection(c).get();
      data[c] = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    if (mounted) showOk(context, 'Backup JSON copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return StandardPage(title: 'Settings', child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 120), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Shop Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(controller: shopName, decoration: const InputDecoration(labelText: 'Shop Name')),
        const SizedBox(height: 10),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
        const SizedBox(height: 10),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Save Shop Info', icon: Icons.store_rounded, onPressed: () async { await saveShop(); if(context.mounted) showOk(context, 'Shop info saved'); }),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dynamic Measurements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: measurement, decoration: const InputDecoration(labelText: 'Measurement Label'))), const SizedBox(width: 10), SizedBox(height: 54, child: FilledButton(onPressed: addMeasurement, child: const Icon(Icons.add_rounded)))]),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: widget.app.shop.collection('settings').doc('measurements').snapshots(), builder: (context, snap) {
          final labels = List<String>.from(snap.data?.data()?['labels'] ?? ['Length', 'Chest', 'Waist', 'Shoulder', 'Sleeve']);
          return Wrap(spacing: 8, runSpacing: 8, children: [for (final l in labels) Chip(label: Text(l), onDeleted: () => widget.app.shop.collection('settings').doc('measurements').set({'labels': FieldValue.arrayRemove([l])}, SetOptions(merge: true)))]);
        }),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Backup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Copy Backup JSON', icon: Icons.backup_rounded, onPressed: backup),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PIN Protected Data Reset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.red)),
        const SizedBox(height: 12),
        TextField(controller: resetText, decoration: const InputDecoration(labelText: 'Type CONFIRM')),
        const SizedBox(height: 10),
        TextField(controller: resetPin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Owner PIN')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async { try { await resetData(); if(context.mounted) showOk(context, 'Data reset done'); } catch(e){ if(context.mounted) showErr(context,e); } }, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Reset Data')),
      ])),
    ]));
  }
}

class StandardPage extends StatelessWidget {
  const StandardPage({required this.title, required this.child, super.key});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title), leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openDrawer()))), body: child);
  }
}

class FloatingNav extends StatelessWidget {
  const FloatingNav({required this.index, required this.onChanged, required this.onAdd, super.key});
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final items = [(0, Icons.home_rounded, 'Home'), (1, Icons.construction_rounded, 'Progress'), (2, Icons.local_shipping_rounded, 'Delivery'), (3, Icons.groups_rounded, 'Staff'), (4, Icons.more_horiz_rounded, 'More')];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 26, offset: const Offset(0, 12))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i == 2) GestureDetector(onTap: onAdd, child: Container(width: 58, height: 58, decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(29)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 34))),
          NavItem(icon: items[i].$2, label: items[i].$3, active: index == items[i].$1, onTap: () => onChanged(items[i].$1)),
        ]
      ]),
    );
  }
}

class NavItem extends StatelessWidget {
  const NavItem({required this.icon, required this.label, required this.active, required this.onTap, super.key});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: SizedBox(width: 54, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? AppTheme.navy : AppTheme.muted), Text(label, maxLines: 1, style: TextStyle(fontSize: 11, color: active ? AppTheme.navy : AppTheme.muted, fontWeight: FontWeight.w800))])));
}

class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.margin, super.key});
  final Widget child;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => Container(margin: margin ?? const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 18, offset: const Offset(0, 8))]), child: child);
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.label, required this.icon, required this.onPressed, this.loading = false, super.key});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppTheme.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: loading ? null : onPressed, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900))));
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => AppCard(child: Column(children: [const Icon(Icons.inbox_rounded, size: 48, color: AppTheme.gold), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted))]));
}

void showErr(BuildContext context, Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppTheme.red, content: Text('$e'.replaceFirst('Bad state: ', ''))));
void showOk(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> confirmCall(BuildContext context, String phone) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Call Customer?'), content: Text(phone), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Call'))]));
  if (ok == true) await launchUrl(Uri.parse('tel:$phone'));
}

Future<void> sendWhatsApp(String phone, String text) async {
  final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final url = Uri.parse('https://api.whatsapp.com/send?phone=$clean&text=${Uri.encodeComponent(text)}');
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

Future<Uint8List> buildSlipPdf({required String shopName, required String slip, required String name, required String mobile, required Map<String, String> measurements, required double total, required double advance}) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (context) {
    return pw.Padding(padding: const pw.EdgeInsets.all(24), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(shopName, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
      pw.Text('Digital Tailoring Slip', style: const pw.TextStyle(fontSize: 14)),
      pw.Divider(),
      pw.Text('Slip: $slip'), pw.Text('Customer: $name'), pw.Text('Mobile: $mobile'), pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}'),
      pw.SizedBox(height: 16), pw.Text('Measurements', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      for (final e in measurements.entries) pw.Text('${e.key}: ${e.value}'),
      pw.SizedBox(height: 16), pw.Text('Billing', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('Total: ${money(total)}'), pw.Text('Advance: ${money(advance)}'), pw.Text('Due: ${money(max(0, total - advance))}'),
    ]));
  }));
  return doc.save();
}

void showCalculator(BuildContext context) {
  showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => const CalculatorSheet());
}

class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key});
  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String display = '0';
  double? first;
  String? op;
  void press(String key) {
    setState(() {
      if (RegExp(r'^\d$').hasMatch(key)) { display = display == '0' ? key : display + key; return; }
      if (key == 'C') { display = '0'; first = null; op = null; return; }
      if (['+', '-', '×', '÷'].contains(key)) { first = double.tryParse(display) ?? 0; op = key; display = '0'; return; }
      if (key == '=') { final second = double.tryParse(display) ?? 0; if (op == '+') display = '${(first ?? 0) + second}'; if (op == '-') display = '${(first ?? 0) - second}'; if (op == '×') display = '${(first ?? 0) * second}'; if (op == '÷') display = second == 0 ? 'Error' : '${(first ?? 0) / second}'; }
    });
  }
  @override
  Widget build(BuildContext context) {
    final keys = ['7','8','9','÷','4','5','6','×','1','2','3','-','C','0','=','+'];
    return Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: AppTheme.paper, borderRadius: BorderRadius.vertical(top: Radius.circular(28))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Align(alignment: Alignment.centerRight, child: Text(display, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900))),
      const SizedBox(height: 12),
      GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, children: [for (final k in keys) FilledButton(onPressed: () => press(k), child: Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))]),
    ]));
  }
}
