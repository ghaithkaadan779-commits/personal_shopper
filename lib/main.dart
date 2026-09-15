import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  await AppSession.loadData();
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'التوصيل السريع',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Tahoma',
      ),
      home: const SplashScreen(),
    );
  }
}

class AppSession {
  static String? loggedInPhone;
  static String? loggedInRole;
  static String? loggedInVehicle;
  
  static Map<String, Map<String, String>> users = {};
  static List<Map<String, dynamic>> activeOrders = [];
  static List<Map<String, dynamic>> orderHistory = [];
  static List<String> validCaptainCodes = [];

  static final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static Future<void> saveDataToCloud() async {
    try {
      await _dbRef.child('activeOrders').set(activeOrders);
      await _dbRef.child('users').set(users);
      await _dbRef.child('orderHistory').set(orderHistory);
      await _dbRef.child('validCodes').set(validCaptainCodes);
    } catch (e) {
      debugPrint("Cloud save error: $e");
    }
  }

  static Future<void> loadData() async {
    try {
      DataSnapshot userSnap = await _dbRef.child('users').get();
      if (userSnap.value != null) {
        Map<dynamic, dynamic> decoded = userSnap.value as Map<dynamic, dynamic>;
        users = decoded.map((k, v) => MapEntry(k.toString(), Map<String, String>.from(v as Map)));
      }

      DataSnapshot orderSnap = await _dbRef.child('activeOrders').get();
      if (orderSnap.value != null) {
        try {
          List<dynamic> rawList = orderSnap.value as List<dynamic>;
          activeOrders = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {
          Map<dynamic, dynamic> data = orderSnap.value as Map<dynamic, dynamic>;
          activeOrders.clear();
          data.forEach((key, value) {
            activeOrders.add(Map<String, dynamic>.from(value));
          });
        }
      }

      DataSnapshot historySnap = await _dbRef.child('orderHistory').get();
      if (historySnap.value != null) {
        try {
          List<dynamic> rawList = historySnap.value as List<dynamic>;
          orderHistory = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }

      DataSnapshot codesSnap = await _dbRef.child('validCodes').get();
      if (codesSnap.value != null) {
        List<dynamic> rawList = codesSnap.value as List<dynamic>;
        validCaptainCodes = rawList.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint("Cloud load error: $e");
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    loggedInPhone = prefs.getString('phone');
    loggedInRole = prefs.getString('role');
    loggedInVehicle = prefs.getString('vehicle');
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (AppSession.loggedInPhone != null && AppSession.loggedInPhone!.isNotEmpty) {
        if (AppSession.loggedInRole == 'عميل') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClientHomeScreen()));
        } else if (AppSession.loggedInRole == 'إدارة') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CaptainHomeScreen()));
        }
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF311B92),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.delivery_dining, size: 90, color: Color(0xFF311B92)),
            ),
            const SizedBox(height: 25),
            const Text(
              'سرعة وثقة وأمان',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
              child: const Text(
                'خدمة 24/24 السحابية',
                style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();

  void _login() async {
    String p = _phone.text.trim();
    String pwd = _pass.text.trim();

    // جلب أحدث بيانات المستخدمين من السيرفر قبل التحقق
    await AppSession.loadData();

    if (p == '0930306060' && pwd == '20010') {
      _saveSessionAndNavigate(p, 'إدارة', null, const AdminHomeScreen());
      return;
    }

    if (AppSession.users.containsKey(p) && AppSession.users[p]!['pass'] == pwd) {
      String role = AppSession.users[p]!['role']!;
      String? vehicle = AppSession.users[p]!['vehicle'];
      
      if (role == 'عميل') {
        _saveSessionAndNavigate(p, role, vehicle, const ClientHomeScreen());
      } else {
        _saveSessionAndNavigate(p, role, vehicle, const CaptainHomeScreen());
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('البيانات غير صحيحة، يرجى التأكد أو إنشاء حساب')),
        );
      }
    }
  }

  void _saveSessionAndNavigate(String phone, String role, String? vehicle, Widget screen) async {
    AppSession.loggedInPhone = phone; 
    AppSession.loggedInRole = role; 
    AppSession.loggedInVehicle = vehicle;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
    await prefs.setString('role', role);
    if (vehicle != null) await prefs.setString('vehicle', vehicle);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(Icons.local_shipping, size: 70, color: Color(0xFF311B92)),
                  const SizedBox(height: 10),
                  const Text('تسجيل الدخول السحابي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف (مثل 09...)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF311B92),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('دخول', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 30),
                  const Divider(),
                  const Text('ليس لديك حساب؟', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ClientRegisterScreen()),
                          ),
                          child: const Text('حساب عميل جديد'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CaptainRegisterScreen()),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: const Text('تسجيل كابتن'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();

  void _register() async {
    String p = _phone.text.trim(); 
    String pwd = _pass.text.trim();
    if (p.isEmpty || pwd.isEmpty) return;
    
    await AppSession.loadData();
    AppSession.users[p] = {'pass': pwd, 'role': 'عميل'}; 
    await AppSession.saveDataToCloud();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الحساب سحابياً! قم بتسجيل الدخول')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حساب عميل جديد')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF311B92),
                foregroundColor: Colors.white,
              ),
              child: const Text('إنشاء الحساب'),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptainRegisterScreen extends StatefulWidget {
  const CaptainRegisterScreen({super.key});

  @override
  State<CaptainRegisterScreen> createState() => _CaptainRegisterScreenState();
}

class _CaptainRegisterScreenState extends State<CaptainRegisterScreen> {
  final _code = TextEditingController(); 
  final _phone = TextEditingController(); 
  final _pass = TextEditingController();
  String _vehicle = 'دراجة نارية';

  void _openWhatsapp(BuildContext context) async {
    final nameController = TextEditingController();
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text('طلب كود الكابتن'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'الاسم الكامل'),
        ),
        actions: [
          TextButton(
            onPressed: () async { 
              if (nameController.text.isEmpty) return; 
              String msg = "أنا السيد ${nameController.text} أريد فتح حساب كابتن في التطبيق"; 
              Uri url = Uri.parse('https://wa.me/963982841351?text=${Uri.encodeComponent(msg)}'); 
              await launchUrl(url, mode: LaunchMode.externalApplication); 
              if (mounted) Navigator.pop(context); 
            }, 
            child: const Text('إرسال للإدارة', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _activate() async {
    await AppSession.loadData();
    String enteredCode = _code.text.trim();
    if (!AppSession.validCaptainCodes.contains(enteredCode)) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كود التفعيل خاطئ أو مستخدم مسبقاً!')),
        );
      } 
      return; 
    }
    String p = _phone.text.trim(); 
    String pwd = _pass.text.trim();
    if (p.isEmpty || pwd.isEmpty) return;
    AppSession.validCaptainCodes.remove(enteredCode);
    AppSession.users[p] = {'pass': pwd, 'role': 'كابتن', 'vehicle': _vehicle}; 
    await AppSession.saveDataToCloud();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل الحساب سحابياً! قم بتسجيل الدخول')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل حساب كابتن')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('اضغط هنا لطلب الكود عبر الواتساب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => _openWhatsapp(context),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'كود التفعيل (من الإدارة)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _vehicle,
              decoration: const InputDecoration(labelText: 'نوع وسيلة النقل', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'دراجة نارية', child: Text('دراجة نارية')),
                DropdownMenuItem(value: 'سيارة عادية', child: Text('سيارة عادية')),
                DropdownMenuItem(value: 'سوزوكي', child: Text('سوزوكي (نقل)')),
              ],
              onChanged: (val) => setState(() => _vehicle = val!),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _activate,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('تفعيل الحساب'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _newCodeController = TextEditingController();

  void _generateCode() async { 
    if (_newCodeController.text.isNotEmpty) { 
      await AppSession.loadData();
      setState(() { 
        AppSession.validCaptainCodes.add(_newCodeController.text.trim()); 
        AppSession.saveDataToCloud(); 
        _newCodeController.clear(); 
      }); 
    } 
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم السحابية'),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async { 
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                AppSession.loggedInPhone = null; 
                AppSession.loggedInRole = null;
                if (mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                } 
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'إحصائيات'),
              Tab(icon: Icon(Icons.vpn_key), text: 'أكواد'),
              Tab(icon: Icon(Icons.people), text: 'مستخدمين'),
              Tab(icon: Icon(Icons.list_alt), text: 'طلبات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ListTile(tileColor: Colors.blue.shade50, title: const Text('إجمالي المستخدمين'), trailing: Text('${AppSession.users.length}')),
                  const SizedBox(height: 10),
                  ListTile(tileColor: Colors.orange.shade50, title: const Text('الطلبات النشطة'), trailing: Text('${AppSession.activeOrders.length}')),
                  const SizedBox(height: 10),
                  ListTile(tileColor: Colors.green.shade50, title: const Text('الطلبات المكتملة'), trailing: Text('${AppSession.orderHistory.length}')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _newCodeController, decoration: const InputDecoration(labelText: 'تأليف كود جديد', border: OutlineInputBorder()))),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _generateCode,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.amber),
                        child: const Text('إضافة'),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  Expanded(
                    child: ListView.builder(
                      itemCount: AppSession.validCaptainCodes.length,
                      itemBuilder: (context, i) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.key, color: Colors.amber),
                          title: Text(AppSession.validCaptainCodes[i]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async { 
                              await AppSession.loadData();
                              setState(() { 
                                AppSession.validCaptainCodes.removeAt(i); 
                                AppSession.saveDataToCloud(); 
                              }); 
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              itemCount: AppSession.users.length,
              itemBuilder: (context, i) { 
                String phone = AppSession.users.keys.elementAt(i); 
                var data = AppSession.users[phone]!; 
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(data['role'] == 'عميل' ? Icons.person : Icons.sports_motorsports),
                    title: Text('هاتف: $phone'),
                    subtitle: Text('الدور: ${data['role']} ${data['vehicle'] ?? ''} \nكلمة السر: ${data['pass']}'),
                  ),
                ); 
              },
            ),
            ListView(
              padding: const EdgeInsets.all(10),
              children: [
                const Text('النشطة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ...AppSession.activeOrders.map((o) => Card(color: Colors.orange.shade50, child: ListTile(title: Text('${o['category']}'), subtitle: Text('الحالة: ${o['status']} | كابتن: ${o['targetCaptain']}')))),
                const Divider(height: 30),
                const Text('المكتملة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ...AppSession.orderHistory.map((o) => Card(color: Colors.green.shade50, child: ListTile(title: Text('${o['category']}'), subtitle: Text('العميل: ${o['clientPhone']} | الكابتن: ${o['captainPhone']}')))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // تحديث دوري لجلب أحدث حالة الطلبات من السيرفر السحابي
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      await AppSession.loadData();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() { 
    _refreshTimer?.cancel(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    String myPhone = AppSession.loggedInPhone ?? '';
    var myOrder = AppSession.activeOrders.firstWhere((o) => o['clientPhone'] == myPhone, orElse: () => {});
    return Scaffold(
      appBar: AppBar(title: const Text('تطبيق التوصيل السحابي'), backgroundColor: const Color(0xFF311B92), foregroundColor: Colors.white),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('العميل'),
              accountEmail: Text(myPhone),
              decoration: const BoxDecoration(color: Color(0xFF311B92)),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.blue),
              title: const Text('سجل طلباتي'),
              onTap: () { 
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrderHistoryScreen())); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.headset_mic, color: Colors.green),
              title: const Text('خدمة العملاء'),
              onTap: () async { 
                await launchUrl(Uri.parse('https://wa.me/963982841351'), mode: LaunchMode.externalApplication); 
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('خروج'),
              onTap: () async { 
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                AppSession.loggedInPhone = null; 
                AppSession.loggedInRole = null;
                if (mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                } 
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (myOrder.isNotEmpty) ...[
              if (myOrder['status'] == 'failed') ...[
                Card(
                  color: Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        const Text('تعذر إيجاد كابتن متاح حالياً، حاول مرة أخرى', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () async { 
                            await AppSession.loadData();
                            setState(() { 
                              AppSession.activeOrders.removeWhere((o) => o['clientPhone'] == myPhone); 
                              AppSession.saveDataToCloud(); 
                            }); 
                          },
                          child: const Text('حسناً، إغلاق'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Card(
                  color: myOrder['status'] == 'accepted' ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Text(
                          myOrder['status'] == 'priced' 
                            ? 'عرض السعر من الكابتن: ${myOrder['price']} ل.س' 
                            : (myOrder['status'] == 'accepted' ? 'تمت الموافقة! الكابتن بطريقه إليك' : 'جاري البحث عن كابتن...'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (myOrder['status'] == 'accepted') ...[
                          const SizedBox(height: 6),
                          Text('رقم الكابتن: ${myOrder['captainPhone']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                        if (myOrder['status'] == 'priced') ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () async { 
                                  await AppSession.loadData();
                                  setState(() { myOrder['status'] = 'accepted'; }); 
                                  AppSession.saveDataToCloud(); 
                                },
                                child: const Text('موافقة'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () async { 
                                  await AppSession.loadData();
                                  setState(() { AppSession.activeOrders.removeWhere((o) => o['clientPhone'] == myPhone); }); 
                                  AppSession.saveDataToCloud(); 
                                },
                                child: const Text('إلغاء'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
            ],
            const Text('اختر القسم لطلب التوصيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildCat('طعام ومطاعم', Icons.restaurant, Colors.deepOrange),
                  _buildCat('أغراض ومشتريات', Icons.shopping_basket, Colors.blue),
                  _buildCat('أدوية وصيدلية', Icons.medication, Colors.green),
                  _buildCat('طرد ونقل', Icons.inventory_2, Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCat(String name, IconData icon, Color color) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewOrderScreen(category: name))),
      child: Card(
        elevation: 3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class ClientOrderHistoryScreen extends StatelessWidget {
  const ClientOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String myPhone = AppSession.loggedInPhone ?? '';
    var myHistory = AppSession.orderHistory.where((o) => o['clientPhone'] == myPhone).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('سجل طلباتي')),
      body: myHistory.isEmpty 
        ? const Center(child: Text('لم تقم بأي طلبات مكتملة')) 
        : ListView.builder(
            itemCount: myHistory.length,
            itemBuilder: (context, i) { 
              var o = myHistory[i]; 
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('${o['category']} - السعر: ${o['price']}'),
                  subtitle: Text('من: ${o['from']} إلى: ${o['to']} \nمع الكابتن: ${o['captainPhone']}'),
                ),
              ); 
            },
          ),
    );
  }
}

class NewOrderScreen extends StatefulWidget {
  final String category;
  const NewOrderScreen({super.key, required this.category});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _from = TextEditingController(); 
  final _to = TextEditingController(); 
  final _details = TextEditingController();
  String _vehicle = 'دراجة نارية';

  void _sendOrder() async {
    if (_from.text.isEmpty || _to.text.isEmpty) return;
    
    await AppSession.loadData();
    List<String> availableCaptains = [];
    AppSession.users.forEach((phone, data) {
      if (data['role'] == 'كابتن' && data['vehicle'] == _vehicle) availableCaptains.add(phone);
    });

    if (availableCaptains.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، لا يوجد كباتن متاحين بهذه الوسيلة حالياً')),
        );
      }
      return;
    }

    AppSession.activeOrders.add({
      'category': widget.category, 
      'clientPhone': AppSession.loggedInPhone, 
      'from': _from.text, 
      'to': _to.text, 
      'details': _details.text, 
      'vehicle': _vehicle,
      'status': 'pending', 
      'price': '', 
      'captainPhone': '',
      'targetCaptain': availableCaptains[0], 
    });
    
    await AppSession.saveDataToCloud();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلب ${widget.category}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _from, decoration: const InputDecoration(labelText: 'مكان الاستلام', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _to, decoration: const InputDecoration(labelText: 'مكان التسليم', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _vehicle,
              decoration: const InputDecoration(labelText: 'وسيلة النقل', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'دراجة نارية', child: Text('دراجة نارية')),
                DropdownMenuItem(value: 'سيارة عادية', child: Text('سيارة عادية')),
                DropdownMenuItem(value: 'سوزوكي', child: Text('سوزوكي')),
              ],
              onChanged: (val) => setState(() => _vehicle = val!),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _sendOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF311B92),
                foregroundColor: Colors.white,
              ),
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen> {
  final Map<String, TextEditingController> _prices = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // تحديث دوري لجلب الطلبات الموجهة للكابتن من السيرفر فوراً
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      await AppSession.loadData();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() { 
    _refreshTimer?.cancel(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    String myPhone = AppSession.loggedInPhone ?? '';
    var myAccepted = AppSession.activeOrders.where((o) => o['status'] == 'accepted' && o['captainPhone'] == myPhone).toList();
    var pendingOrders = AppSession.activeOrders.where((o) => o['status'] == 'pending' && o['targetCaptain'] == myPhone).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الكابتن السحابية'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async { 
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              AppSession.loggedInPhone = null; 
              AppSession.loggedInRole = null;
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
              } 
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (myAccepted.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text('🔔 تمت الموافقة على طلبك من قِبل العميل!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            ...myAccepted.map((ord) => Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('القسم: ${ord['category']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.green),
                        const SizedBox(width: 8),
                        SelectableText('رقم العميل: ${ord['clientPhone']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('من: ${ord['from']}  إلى: ${ord['to']}'),
                    Text('السعر المتفق عليه: ${ord['price']} ل.س'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      onPressed: () async { 
                        await AppSession.loadData();
                        setState(() { 
                          AppSession.orderHistory.add(ord); 
                          AppSession.activeOrders.remove(ord); 
                        }); 
                        await AppSession.saveDataToCloud(); 
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التسليم وإنهاء الطلب')));
                        } 
                      },
                      child: const Text('تم التسليم وإنهاء الطلب'),
                    ),
                  ],
                ),
              ),
            )),
            const Divider(height: 30),
          ],
          const Text('الطلبات المتاحة الموجهة لك:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 10),
          pendingOrders.isEmpty 
            ? const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text('لا توجد طلبات جديدة حالياً', style: TextStyle(color: Colors.grey, fontSize: 16))),
              )
            : Column(
                children: pendingOrders.map((ord) {
                  String id = ord['clientPhone'];
                  if (!_prices.containsKey(id)) _prices[id] = TextEditingController();
                  
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('القسم: ${ord['category']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('من: ${ord['from']}'),
                          Text('إلى: ${ord['to']}'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _prices[id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'سعر التوصيل المقترح (ل.س)', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                  onPressed: () async { 
                                    if (_prices[id]!.text.isEmpty) return; 
                                    await AppSession.loadData();
                                    setState(() { 
                                      ord['price'] = _prices[id]!.text; 
                                      ord['captainPhone'] = myPhone; 
                                      ord['status'] = 'priced'; 
                                    }); 
                                    await AppSession.saveDataToCloud(); 
                                  },
                                  child: const Text('إرسال السعر'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () async { 
                                  await AppSession.loadData();
                                  setState(() { AppSession.activeOrders.remove(ord); }); 
                                  await AppSession.saveDataToCloud(); 
                                },
                                child: const Text('رفض'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
        ],
      ),
    );
  }
}
