// Tea Estate Manager - main.dart
// Full single-file Flutter app (connect to Firebase per README).
// Includes: Auth, Employees, Fields, Production, Attendance, Sales, Dashboard.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TeaEstateApp());
}

class TeaEstateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tea Estate Manager',
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasData) return HomeScreen();
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget { @override _LoginScreenState createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  Future<void> _signIn() async {
    setState(()=>_loading=true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim());
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'))); }
    setState(()=>_loading=false);
  }
  Future<void> _register() async {
    setState(()=>_loading=true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim());
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': _email.text.trim(),
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Register failed: $e'))); }
    setState(()=>_loading=false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tea Estate Manager - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(controller: _email, decoration: InputDecoration(labelText: 'Email')),
          TextField(controller: _password, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
          SizedBox(height:12),
          if (_loading) CircularProgressIndicator(),
          if (!_loading) Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            ElevatedButton(onPressed: _signIn, child: Text('Sign in')),
            ElevatedButton(onPressed: _register, child: Text('Register')),
          ])
        ]),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;
  final _screens = [DashboardScreen(), ProductionScreen(), AttendanceScreen(), BillingScreen(), EmployeesScreen()];
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tea Estate Manager'),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: ()=>FirebaseAuth.instance.signOut())],
      ),
      body: _screens[_selected],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selected,
        onTap: (i)=>setState(()=>_selected=i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.agriculture), label: 'Production'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Billing'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Employees'),
        ],
      ),
    );
  }
}

// Dashboard
class DashboardScreen extends StatelessWidget {
  String _format(double v)=>NumberFormat.currency(symbol: '₹').format(v);
  Future<Map<String,dynamic>> _loadTotals() async {
    final sales = await FirebaseFirestore.instance.collection('sales').get();
    final prod = await FirebaseFirestore.instance.collection('production').get();
    final exp = await FirebaseFirestore.instance.collection('expenses').get();
    final emp = await FirebaseFirestore.instance.collection('employees').get();
    double totalSales=0, totalKg=0, totalExp=0, totalWagesPerKg=0, totalFixed=0;
    for(var s in sales.docs) totalSales += (s.data()['totalAmount'] ?? 0);
    for(var p in prod.docs) totalKg += (p.data()['kg'] ?? 0);
    for(var e in exp.docs) totalExp += (e.data()['amount'] ?? 0);
    for(var e in emp.docs) {
      final data = e.data();
      totalWagesPerKg += (data['wagePerKg'] ?? 0) * totalKg;
      totalFixed += (data['fixedMonthlyWage'] ?? 0);
    }
    double profit = totalSales - (totalWagesPerKg + totalFixed) - totalExp;
    return {'sales': totalSales, 'kg': totalKg, 'expenses': totalExp, 'wages': totalWagesPerKg, 'fixed': totalFixed, 'profit': profit};
  }
  @override Widget build(BuildContext context) {
    return FutureBuilder<Map<String,dynamic>>(future: _loadTotals(), builder: (c,s){
      if(!s.hasData) return Center(child: CircularProgressIndicator());
      final d=s.data!;
      return Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Totals', style: TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        SizedBox(height:8),
        Card(child: ListTile(title: Text('Total Sales'), trailing: Text(_format(d['sales'])))),
        Card(child: ListTile(title: Text('Total KG Collected'), trailing: Text(d['kg'].toString()))),
        Card(child: ListTile(title: Text('Total Expenses'), trailing: Text(_format(d['expenses'])))),
        Card(child: ListTile(title: Text('Estimated Wages'), trailing: Text(_format(d['wages'] + d['fixed'])))),
        Divider(),
        ListTile(title: Text('Estimated Profit', style: TextStyle(fontSize:16,fontWeight:FontWeight.bold)), trailing: Text(_format(d['profit']))),
      ]));
    });
  }
}

// Production
class ProductionScreen extends StatefulWidget { @override _ProductionScreenState createState()=>_ProductionScreenState(); }
class _ProductionScreenState extends State<ProductionScreen> {
  final _kgCtrl = TextEditingController();
  String? _selEmp, _selField;
  Future<List<Map<String,dynamic>>> _emps() async {
    final s = await FirebaseFirestore.instance.collection('employees').get();
    return s.docs.map((d)=>{...d.data(), 'id': d.id}).toList();
  }
  Future<List<Map<String,dynamic>>> _fields() async {
    final s = await FirebaseFirestore.instance.collection('fields').get();
    return s.docs.map((d)=>{...d.data(), 'id': d.id}).toList();
  }
  Future<void> _save() async {
    final kg = double.tryParse(_kgCtrl.text.trim()) ?? 0;
    if(_selEmp==null || _selField==null || kg<=0){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select employee, field and enter kg'))); return; }
    await FirebaseFirestore.instance.collection('production').add({
      'employeeId': _selEmp, 'fieldId': _selField, 'kg': kg, 'date': DateTime.now(), 'timestamp': FieldValue.serverTimestamp()
    });
    _kgCtrl.clear(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved')));
  }
  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
      FutureBuilder(future: _emps(), builder: (c,s){ if(!s.hasData) return CircularProgressIndicator(); final list=s.data as List; return DropdownButton<String>(value: _selEmp, hint: Text('Select employee'), items: list.map((e)=>DropdownMenuItem(value: e['id'], child: Text(e['name'] ?? ''))).toList(), onChanged: (v)=>setState(()=>_selEmp=v)); }),
      FutureBuilder(future: _fields(), builder: (c,s){ if(!s.hasData) return SizedBox(); final list=s.data as List; return DropdownButton<String>(value: _selField, hint: Text('Select field'), items: list.map((f)=>DropdownMenuItem(value: f['id'], child: Text(f['name'] ?? ''))).toList(), onChanged: (v)=>setState(()=>_selField=v)); }),
      TextField(controller: _kgCtrl, decoration: InputDecoration(labelText: 'KG collected'), keyboardType: TextInputType.number),
      SizedBox(height:8),
      ElevatedButton(onPressed: _save, child: Text('Save Production')),
      SizedBox(height:12),
      Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection('production').orderBy('timestamp', descending: true).limit(50).snapshots(), builder: (c,s){ if(!s.hasData) return Center(child: CircularProgressIndicator()); final docs = s.data!.docs; return ListView.builder(itemCount: docs.length, itemBuilder: (context,i){ final d = docs[i].data() as Map<String,dynamic>; final kg=d['kg']??0; final emp=d['employeeId']??''; final field=d['fieldId']??''; final date=(d['date'] as Timestamp?)?.toDate() ?? DateTime.now(); return ListTile(title: Text('$kg kg'), subtitle: Text('Emp: $emp • Field: $field'), trailing: Text(DateFormat.yMd().format(date))); }); }))
    ]));
  }
}

// Attendance
class AttendanceScreen extends StatefulWidget { @override _AttendanceScreenState createState()=>_AttendanceScreenState(); }
class _AttendanceScreenState extends State<AttendanceScreen> {
  String? _selEmp; String _status='present';
  Future<List<Map<String,dynamic>>> _emps() async { final s = await FirebaseFirestore.instance.collection('employees').get(); return s.docs.map((d)=>{...d.data(),'id':d.id}).toList(); }
  Future<void> _mark() async { if(_selEmp==null){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select employee'))); return; } await FirebaseFirestore.instance.collection('attendance').add({'employeeId':_selEmp,'status':_status,'date':DateTime.now(),'timestamp':FieldValue.serverTimestamp()}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked'))); }
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
    FutureBuilder(future:_emps(), builder:(c,s){ if(!s.hasData) return CircularProgressIndicator(); final list=s.data as List; return DropdownButton<String>(value: _selEmp, hint: Text('Select employee'), items: list.map((e)=>DropdownMenuItem(value: e['id'], child: Text(e['name'] ?? ''))).toList(), onChanged:(v)=>setState(()=>_selEmp=v)); }),
    Row(children:[ Expanded(child: RadioListTile(value:'present',groupValue:_status,title:Text('Present'),onChanged:(v)=>setState(()=>_status=v!))), Expanded(child: RadioListTile(value:'absent',groupValue:_status,title:Text('Absent'),onChanged:(v)=>setState(()=>_status=v!))) ]),
    ElevatedButton(onPressed:_mark, child: Text('Mark Attendance')),
    SizedBox(height:12),
    Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection('attendance').orderBy('timestamp', descending: true).limit(50).snapshots(), builder:(c,s){ if(!s.hasData) return Center(child:CircularProgressIndicator()); final docs=s.data!.docs; return ListView.builder(itemCount:docs.length,itemBuilder:(context,i){ final d=docs[i].data() as Map<String,dynamic>; final status=d['status']??''; final emp=d['employeeId']??''; final date=(d['date'] as Timestamp?)?.toDate()??DateTime.now(); return ListTile(title:Text(emp), subtitle:Text(status), trailing:Text(DateFormat.yMd().format(date))); }); }))
  ])); }
}

// Billing (sales)
class BillingScreen extends StatefulWidget { @override _BillingScreenState createState()=>_BillingScreenState(); }
class _BillingScreenState extends State<BillingScreen> {
  final _buyer=TextEditingController(); final _kg=TextEditingController(); final _rate=TextEditingController();
  Future<void> _save() async {
    final buyer=_buyer.text.trim(); final kg=double.tryParse(_kg.text.trim())??0; final rate=double.tryParse(_rate.text.trim())??0;
    if(buyer.isEmpty||kg<=0){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter buyer and kg'))); return; }
    final total=kg*rate; final id=Uuid().v4();
    await FirebaseFirestore.instance.collection('sales').add({'buyerName':buyer,'kg':kg,'ratePerKg':rate,'totalAmount':total,'date':DateTime.now(),'invoiceId':id,'timestamp':FieldValue.serverTimestamp()});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale saved. Invoice id: $id')));
    _buyer.clear(); _kg.clear(); _rate.clear();
  }
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
    TextField(controller:_buyer, decoration: InputDecoration(labelText:'Buyer name')),
    TextField(controller:_kg, decoration: InputDecoration(labelText:'KG'), keyboardType: TextInputType.number),
    TextField(controller:_rate, decoration: InputDecoration(labelText:'Rate per KG'), keyboardType: TextInputType.number),
    SizedBox(height:8),
    ElevatedButton(onPressed:_save, child: Text('Save Sale')),
    SizedBox(height:12),
    Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection('sales').orderBy('timestamp', descending: true).limit(50).snapshots(), builder:(c,s){ if(!s.hasData) return Center(child:CircularProgressIndicator()); final docs=s.data!.docs; return ListView.builder(itemCount:docs.length,itemBuilder:(context,i){ final d=docs[i].data() as Map<String,dynamic>; final buyer=d['buyerName']??''; final total=d['totalAmount']??0; final date=(d['date'] as Timestamp?)?.toDate()??DateTime.now(); return ListTile(title:Text(buyer), subtitle:Text('₹$total'), trailing:Text(DateFormat.yMd().format(date))); }); }))
  ])); }
}

// Employees
class EmployeesScreen extends StatefulWidget { @override _EmployeesScreenState createState()=>_EmployeesScreenState(); }
class _EmployeesScreenState extends State<EmployeesScreen> {
  final _name=TextEditingController(); final _wage=TextEditingController(); final _fixed=TextEditingController();
  Future<void> _add() async {
    final name=_name.text.trim(); final wage=double.tryParse(_wage.text.trim())??0; final fixed=double.tryParse(_fixed.text.trim())??0;
    if(name.isEmpty) return;
    await FirebaseFirestore.instance.collection('employees').add({'name':name,'wagePerKg':wage,'fixedMonthlyWage':fixed,'createdAt':FieldValue.serverTimestamp()});
    _name.clear(); _wage.clear(); _fixed.clear(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added')));
  }
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
    TextField(controller:_name, decoration: InputDecoration(labelText:'Name')),
    TextField(controller:_wage, decoration: InputDecoration(labelText:'Wage per KG'), keyboardType: TextInputType.number),
    TextField(controller:_fixed, decoration: InputDecoration(labelText:'Fixed monthly wage'), keyboardType: TextInputType.number),
    SizedBox(height:8),
    ElevatedButton(onPressed:_add, child: Text('Add Employee')),
    SizedBox(height:12),
    Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection('employees').orderBy('createdAt', descending: true).snapshots(), builder:(c,s){ if(!s.hasData) return Center(child:CircularProgressIndicator()); final docs=s.data!.docs; return ListView.builder(itemCount:docs.length,itemBuilder:(context,i){ final d=docs[i].data() as Map<String,dynamic>; final id=docs[i].id; return ListTile(title:Text(d['name']??''), subtitle:Text('Wage/kg: ${d['wagePerKg'] ?? 0} • Fixed: ${d['fixedMonthlyWage'] ?? 0}'), trailing: IconButton(icon: Icon(Icons.delete), onPressed: ()=>FirebaseFirestore.instance.collection('employees').doc(id).delete())); }); }))
  ])); }
}