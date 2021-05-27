import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';

var months = [
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Сентябрь следующего года',
  'Итого',
  'Доп. оплаты'
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExcelGenerator',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
      ),
      home: const MyHomePage(title: 'ExcelGenerator_1'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _users = <User>[User()];

  void _pushAddingUser() {
    setState(() {
      _users.add(User());
    });
    // final _formKey = GlobalKey<FormState>();
    // final _nameController = TextEditingController();
    // final _paidController = TextEditingController();
    // Navigator.of(context).push(
    //   MaterialPageRoute<void>(
    //     builder: (BuildContext context) {
    //       return Scaffold(
    //         appBar: AppBar(
    //           title: const Text('Create User'),
    //         ),
    //         body: Form(
    //           key: _formKey,
    //           child: Column(
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: <Widget>[
    //               TextFormField(
    //                 controller: _nameController,
    //                 decoration: const InputDecoration(
    //                   labelText: 'Name',
    //                 ),
    //                 validator: (value) {
    //                   if (value == null || value.isEmpty) {
    //                     return 'Please enter some text';
    //                   }
    //                   return null;
    //                 },
    //               ),
    //               TextFormField(
    //                 controller: _paidController,
    //                 decoration: const InputDecoration(
    //                   labelText: 'Paid',
    //                 ),
    //                 // The validator receives the text that the user has entered.
    //                 validator: (value) {
    //                   if (value == null || double.tryParse(value) == null) {
    //                     return 'Please enter some number';
    //                   }
    //                   return null;
    //                 },
    //               ),
    //               Padding(
    //                 padding: const EdgeInsets.symmetric(vertical: 16.0),
    //                 child: ElevatedButton(
    //                   onPressed: () {
    //                     if (_formKey.currentState!.validate()) {
    //                       setState(() {
    //                         _users.add(User());
    //                       });
    //                       Navigator.of(context).pop();
    //                     }
    //                   },
    //                   child: Text('Add'),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       );
    //     }, // ...to here.
    //   ),
    // );
  }

  void _removeUser(User user) {
    setState(() {
      _users.remove(user);
    });
  }

  void _saveUser(User user, List<TextEditingController> controllers) {
    if (controllers.isNotEmpty) {
      user.name = controllers[0].text;
    }
    if (controllers.length > 1) {
      user.dateStartOfEducation = controllers[1].text;
    }
    for (var i = 2; i < controllers.length; ++i) {
      user.paid[i - 2] = int.parse(controllers[i].text);
    }
  }

  void _pushSave() {}

  DataRow _mapUserToTable(User user) {
    var _controllers = <TextEditingController>[];
    var _cells = <DataCell>[];
    _controllers.add(TextEditingController(text: user.name));
    _cells.add(DataCell(TextFormField(
        keyboardType: TextInputType.text,
        validator: (value) {
          if (value == null) {
            return 'Введите Ф.И';
          }
          return null;
        },
        controller: _controllers[0],
        onFieldSubmitted: (val) {
          _saveUser(user, _controllers);
        })));
    _controllers.add(TextEditingController(text: user.dateStartOfEducation));
    _cells.add(DataCell(TextFormField(
        keyboardType: TextInputType.datetime,
        validator: (value) {
          if (value == null) {
            return 'Введите дату';
          }
          return null;
        },
        controller: _controllers[1],
        onFieldSubmitted: (val) {
          _saveUser(user, _controllers);
        })));
    for (var i = 0; i < months.length; ++i) {
      _controllers.add(TextEditingController(text: user.paid[i].toString()));
      _cells.add(DataCell(TextFormField(
          keyboardType: TextInputType.text,
          validator: (value) {
            if (value == null || double.tryParse(value) == null) {
              return 'Введите число';
            }
            return null;
          },
          controller: _controllers.last,
          onFieldSubmitted: (val) {
            _saveUser(user, _controllers);
          })));
    }
    _cells.add(DataCell(
        const Icon(
          Icons.delete,
          size: 20,
        ), onTap: () {
      setState(() {
        _removeUser(user);
      });
    }));
    return DataRow(cells: _cells);
  }

  @override
  Widget build(BuildContext context) {
    final _monthControllers = <TextEditingController>[];
    const _textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    var columns_ = <DataColumn>[];
    columns_.add(const DataColumn(label: Text('Ф.И.', style: _textStyle)));
    columns_.add(const DataColumn(
        label: Text('Дата начала занятий', style: _textStyle)));
    for (var i = 0; i < months.length; i++) {
      //const DataColumn(label: Text(months[i], style: _textStyle))
      columns_.add(DataColumn(label: Text(months[i], style: _textStyle)));
    }
    columns_.add(const DataColumn(label: Text('', style: _textStyle)));
    return Scaffold(
      appBar: AppBar(
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
                    columns: columns_,
                    rows:
                        (_users).map((user) => _mapUserToTable(user)).toList()),
              ))),
      floatingActionButton: FloatingActionButton(
        onPressed: _pushAddingUser,
        tooltip: 'Добавить пользователя',
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
  late String dateStartOfEducation;
  late List<int> paid;
  late int result;

  void calculateResult() {
    this.result = paid.reduce((value, element) => value + element);
  }

  User() {
    result = 0;
    this.name = '';
    this.dateStartOfEducation = '';
    this.paid = new List.filled(months.length, 0,
        growable: false); //TODO Replace it on new List(months.length)
    //     null safety issue
  }

  User.ByName(String name) {
    this.name = name;
    paid = List.filled(months.length, 0, growable: false);
  }
}

// TODO:
// 1. сделать кнопку сохранить для строки или автоматом как-нибудь все это дело чтобы сохранялось              - pending
// 1.1 разобраться с сабмитом этих форм которые в строке                                                       - pending
// 2. экспорт xlsx:                                                                                            - pending
// 2.1. базовый экспорт: разобраться с либой, выводить просто строчки                                          - pending
// 2.2. разобраться со стилями, чтобы все красиво +- как в примере выводилось                                  - pending
// 3. добавить автоподсчет ИТОГО                                                                               - done
// 4. настроить логику удаления (как в скринах) (чтобы падала вниз и раскрашивалась строчка)                   - pending
// 5. если делать будет нечего, то заняться тем, чтобы убрать хардкод в моменте наполненния колонок для строки - pending
