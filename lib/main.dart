import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.loadData();
  AppSession.startOrderManager(); 
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

  static void startOrderManager() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      bool needsSave = false;
      for (var o in activeOrders) {
        if (o['status'] == 'pending') {
          o['timeAtCurrentCaptain'] = (o['timeAtCurrentCaptain'] as int? ?? 0) + 1;
          if ((o['timeAtCurrentCaptain'] as int) >= 5) {
            List<String> queue = List<String>.from(o['captainQueue'] ?? <String>[]);
            if (queue.isNotEmpty) queue.removeAt(0);
            o['captainQueue'] = queue;
            
            if (queue.isEmpty) {
              o['status'] = 'failed';
            } else {
              o['targetCaptain'] = queue[0];
              o['timeAtCurrentCaptain'] = 0;
            }
            needsSave = true;
          }
        }
      }
      if (needsSave) saveData();
    });
  }

  static Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', jsonEncode(users));
    await prefs.setString('activeOrders', jsonEncode(activeOrders));
    await prefs.setString('orderHistory', jsonEncode(orderHistory));
    await prefs.setString('validCodes', jsonEncode(validCaptainCodes));
  }

  static Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    loggedInPhone = prefs.getString('phone');
    loggedInRole = prefs.getString('role');
    loggedInVehicle = prefs.getString('vehicle');
    
    if (prefs.containsKey('users')) {
      Map<String, dynamic> decoded = jsonDecode(prefs.getString('users')!);
      users = decoded.map((k, v) => MapEntry(k, Map<String, String>.from(v)));
    }
    if (prefs.containsKey('activeOrders')) {
      List<dynamic> rawList = jsonDecode(prefs.getString('activeOrders')!);
      activeOrders = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (prefs.containsKey('orderHistory')) {
      List<dynamic> rawList = jsonDecode(prefs.getString('orderHistory')!);
      orderHistory = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (prefs.containsKey('validCodes')) {
      List<dynamic> rawList = jsonDecode(prefs.getString('validCodes')!);
      validCaptainCodes = rawList.map((e) => e.toString()).toList();
    }
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
      if (AppSession.loggedInPhone != null) {
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
                'خدمة 24/24',
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
          const SnackBar(content: Text('البيانات غير صحيحة، يرجى إنشاء حساب')),
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
                  const Text('تسجيل الدخول', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
    AppSession.users[p] = {'pass': pwd, 'role': 'عميل'}; 
    await AppSession.saveData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الحساب! قم بتسجيل الدخول')),
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
    await AppSession.saveData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل الحساب! قم بتسجيل الدخول')),
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

  void _generateCode() { 
    if (_newCodeController.text.isNotEmpty) { 
      setState(() { 
        AppSession.validCaptainCodes.add(_newCodeController.text.trim()); 
        AppSession.saveData(); 
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
          title: const Text('لوحة التحكم'),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async { 
                await (await SharedPreferences.getInstance()).clear(); 
                AppSession.loggedInPhone = null; 
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
                            onPressed: () { 
                              setState(() { 
                                AppSession.validCaptainCodes.removeAt(i); 
                                AppSession.saveData(); 
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
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (t) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { 
    _uiTimer?.cancel(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    String myPhone = AppSession.loggedInPhone ?? '';
    var myOrder = AppSession.activeOrders.firstWhere((o) => o['clientPhone'] == myPhone, orElse: () => {});
    return Scaffold(
      appBar: AppBar(title: const Text('تطبيق التوصيل'), backgroundColor: const Color(0xFF311B92), foregroundColor: Colors.white),
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
                await (await SharedPreferences.getInstance()).clear(); 
                AppSession.loggedInPhone = null; 
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
                          onPressed: () { 
                            setState(() { 
                              AppSession.activeOrders.remove(myOrder); 
                              AppSession.saveData(); 
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
                            : (myOrder['status'] == 'accepted' ? 'تمت الموافقة! الكابتن بطريقه إليك' : 'جاري البحث عن كابتن... (${myOrder['timeAtCurrentCaptain']}ث)'),
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
                                onPressed: () { 
                                  setState(() { myOrder['status'] = 'accepted'; }); 
                                  AppSession.saveData(); 
                                },
                                child: const Text('موافقة'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () { 
                                  setState(() { AppSession.activeOrders.remove(myOrder); }); 
                                  AppSession.saveData(); 
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
    
    availableCaptains.shuffle();

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
      'captainQueue': availableCaptains, 
      'targetCaptain': availableCaptains[0], 
      'timeAtCurrentCaptain': 0,
    });
    await AppSession.saveData();
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
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _ringTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {}); 
      var pending = AppSession.activeOrders.where((o) => o['status'] == 'pending' && o['targetCaptain'] == AppSession.loggedInPhone).toList();
      if (pending.isNotEmpty) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.vibrate();
      }
    });
  }

  @override
  void dispose() { 
    _ringTimer?.cancel(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    String myPhone = AppSession.loggedInPhone ?? '';
    var myAccepted = AppSession.activeOrders.where((o) => o['status'] == 'accepted' && o['captainPhone'] == myPhone).toList();
    var pendingOrders = AppSession.activeOrders.where((o) => o['status'] == 'pending' && o['targetCaptain'] == myPhone).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الكابتن'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async { 
              await (await SharedPreferences.getInstance()).clear(); 
              AppSession.loggedInPhone = null; 
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
                        setState(() { 
                          AppSession.orderHistory.add(ord); 
                          AppSession.activeOrders.remove(ord); 
                        }); 
                        await AppSession.saveData(); 
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
          const Text('طلبات موجهة لك (باقي لها 5 ثوانٍ):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 10),
          ...pendingOrders.map((ord) {
            String id = ord['clientPhone'];
            if (!_prices.containsKey(id)) _prices[id] = TextEditingController();
            int secondsLeft = 5 - (ord['timeAtCurrentCaptain'] as int? ?? 0);
            
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('ينتهي بعد: $secondsLeft ثانية', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
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
                              setState(() { 
                                ord['price'] = _prices[id]!.text; 
                                ord['captainPhone'] = myPhone; 
                                ord['status'] = 'priced'; 
                              }); 
                              await AppSession.saveData(); 
                            },
                            child: const Text('إرسال السعر'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () async { 
                            setState(() { ord['timeAtCurrentCaptain'] = 5; }); 
                            await AppSession.saveData(); 
                          },
                          child: const Text('رفض'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
