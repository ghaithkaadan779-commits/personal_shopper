import 'package:flutter/material.dart';

void main() {
  runApp(const SyriaCashApp());
}

class SyriaCashApp extends StatelessWidget {
  const SyriaCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ديون سوريا كاش',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F5),
      ),
      home: const HomeScreen(),
    );
  }
}

class Customer {
  String name;
  double balance; // موجب = عليه، سالب = له
  List<Transaction> transactions;

  Customer({required this.name, required this.balance, required this.transactions});
}

class Transaction {
  final String type; // 'تحويل رصيد' أو 'دفعة قبض'
  final double amount;
  final DateTime date;

  Transaction({required this.type, required this.amount, required this.date});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Customer> _customers = [
    Customer(name: 'احمد بغجاتي', balance: 10000.0, transactions: []),
    Customer(name: 'انس النوري', balance: 40000.0, transactions: []),
  ];

  double get _totalDebt {
    double total = 0;
    for (var c in _customers) {
      if (c.balance > 0) total += c.balance;
    }
    return total;
  }

  void _showAddTransactionDialog(Customer customer) {
    final TextEditingController amountController = TextEditingController();
    bool isAddingDebt = true; // true = تحويل رصيد، false = دفعة قبض

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('حركة للزبون: ${customer.name}', textAlign: TextAlign.right),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'قيمة المبلغ',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // التعديل الأخير للأزرار داخل المربع بشكل متناسق تماماً
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('تحويل رصيد')),
                          selected: isAddingDebt,
                          onSelected: (selected) {
                            setStateDialog(() => isAddingDebt = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('دفعة قبض')),
                          selected: !isAddingDebt,
                          onSelected: (selected) {
                            setStateDialog(() => isAddingDebt = false);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount > 0) {
                      setState(() {
                        if (isAddingDebt) {
                          customer.balance += amount;
                        } else {
                          customer.balance -= amount;
                        }
                        customer.transactions.add(Transaction(
                          type: isAddingDebt ? 'تحويل رصيد' : 'دفعة قبض',
                          amount: amount,
                          date: DateTime.now(),
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('تحديث الحساب'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addNewCustomer() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة زبون جديد', textAlign: TextAlign.right),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم الزبون'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _customers.add(Customer(
                      name: nameController.text,
                      balance: 0.0,
                      transactions: [],
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ديون سوريا كاش'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // إجمالي الديون
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي الديون:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$_totalDebt', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ),
          // قائمة الزبائن
          Expanded(
            child: ListView.builder(
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الحساب الحالي: ${customer.balance}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                      onPressed: () => _showAddTransactionDialog(customer),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewCustomer,
        label: const Text('إضافة زبون جديد'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}
