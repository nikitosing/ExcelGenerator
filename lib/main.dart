import 'package:flutter/material.dart';
import 'package:excel/excel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.cyan,
      ),
      home: const MyHomePage(title: 'Flutter Demo Hyi page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  final _users = <User>[User("asd", 100)];

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _pushAddingUser() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _paidController = TextEditingController();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // NEW lines from here...
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Create User'),
            ),
            body: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                    // The validator receives the text that the user has entered.
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter some text';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _paidController,
                    decoration: const InputDecoration(
                      labelText: 'Paid',
                    ),
                    // The validator receives the text that the user has entered.
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return 'Please enter some number';
                      }
                      return null;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Validate returns true if the form is valid, or false otherwise.
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            _users.add(User(_nameController.text,
                                int.parse(_paidController.text)));
                          });
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }, // ...to here.
      ),
    );
  }

  void _pushEditUser(User user) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: user.name);
    final _paidController = TextEditingController(text: user.paid.toString());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // NEW lines from here...
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Create User'),
            ),
            body: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                    // The validator receives the text that the user has entered.
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter some text';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _paidController,
                    decoration: const InputDecoration(
                      labelText: 'Paid',
                    ),
                    // The validator receives the text that the user has entered.
                    validator: (value) {
                      if (value == null || double.tryParse(value) == null) {
                        return 'Please enter some number';
                      }
                      return null;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Validate returns true if the form is valid, or false otherwise.
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            _users[_users.indexOf(user)] = User(
                                _nameController.text,
                                int.parse(_paidController.text));
                          });
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }, // ...to here.
      ),
    );
  }

  void _removeUser(User user) {
    setState(() {
      _users.remove(user);
    });
  }

  void _pushSave() {}

  @override
  Widget build(BuildContext context) {
    const _textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    int i = 0;
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _pushSave),
        ],
      ),
      body: Center(
          child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                    // ignore: prefer_const_literals_to_create_immutables
                    columns: [
                      const DataColumn(label: Text('name', style: _textStyle)),
                      const DataColumn(label: Text('paid', style: _textStyle)),
                      const DataColumn(label: Text('')),
                      const DataColumn(label: Text('')),
                    ],
                    rows: (_users)
                        .map((user) => DataRow(cells: [
                              DataCell(Text(user.name)),
                              DataCell(Text(user.paid.toString())),
                              DataCell(
                                  const Icon(
                                    Icons.edit,
                                    size: 20,
                                  ), onTap: () {
                                setState(() {
                                  _pushEditUser(user);
                                });
                              }),
                              DataCell(
                                  const Icon(
                                    Icons.delete,
                                    size: 20,
                                  ), onTap: () {
                                setState(() {
                                  _removeUser(user);
                                });
                              })
                            ]))
                        .toList()),
              ))),
      floatingActionButton: FloatingActionButton(
        onPressed: _pushAddingUser,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Table extends StatefulWidget {
  //const Table({Key key}) : super(key: key);

  @override
  _TableState createState() => _TableState();
}

class _TableState extends State<Table> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class User {
  late String name;
  late int paid;
  late Object something;

  User(this.name, this.paid);
}
