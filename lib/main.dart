import 'dart:collection';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';

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

var columns = ['Кол. Чел', 'Ф. И.', 'Дата начала занятий'] + months;

String currentName = 'Краснодар Губерния';

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

  void _addUser() {
    setState(() {
      _users.add(User());
      _users.sort((a, b) {
        if (a.toRemove == b.toRemove) return 0;
        if (!a.toRemove) return -1;
        return 1;
      });
    });
  }

  void _removeUser(User user) {
    setState(() {
      user.changeRemove();
      _users.remove(user);
      _users.add(user);
    });
  }

  void _pushSave() {
    var excel = Excel.createExcel();
    excel.rename('Sheet1', currentName);
    var sheet = excel[currentName];
    sheet.insertRowIterables(columns, 0);
    int row = 1;
    for (User user in _users) {
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), row);
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), user.name);
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
          user.dateStartOfEducation);
      int column = 3;
      for (int paid in user.paid) {
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            paid);
        column++;
      }
      row++;
    }
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    saveExcel(excel, 'E:\\work\\130k\\Отчет ' + formattedDate + '.xlsx');
  }

  void saveExcel(Excel excel, String filePath) {
    var tmp = excel.encode();
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(tmp!);
  }

  DataRow _mapUserToTable(User user) {
    var _controllers = {};
    _controllers['name'] = TextEditingController();
    _controllers['name'].value = TextEditingValue(
      text: user.name,
      selection: TextSelection.collapsed(offset: user.name.length),
    );
    var _cells = LinkedHashMap<String, DataCell>();
    _cells['name'] = (DataCell(Focus(
        skipTraversal: true,
        onFocusChange: (focus) => {
              if (focus)
                {
                  _controllers['name'].selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controllers['name'].text.length,
                  )
                }
            },
        child: TextFormField(
          controller: _controllers['name'],
          decoration: const InputDecoration(hintText: "Введите Ф.И"),
          keyboardType: TextInputType.text,
          onChanged: (val) {
            user.name = val;
            user.calculateResult();
            setState(() {});
          },
        ))));
    _controllers['date'] = TextEditingController();
    _controllers['date'].value = TextEditingValue(
      text: user.dateStartOfEducation,
      selection:
          TextSelection.collapsed(offset: user.dateStartOfEducation.length),
    );
    _cells['date'] = (DataCell(Focus(
        skipTraversal: true,
        onFocusChange: (focus) {
          if (focus) {
            _controllers['date'].selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controllers['date'].text.length,
            );
          }
        },
        child: TextFormField(
          controller: _controllers['date'],
          decoration:
              const InputDecoration(hintText: "Введите дату начала обучения"),
          keyboardType: TextInputType.datetime,
          onChanged: (val) {
            user.dateStartOfEducation = val;
            setState(() {});
          },
        ))));
    for (var i = 0; i < months.length; ++i) {
      _controllers[months[i]] =
          TextEditingController(text: user.paid[i].toString());
      _controllers[months[i]].value = TextEditingValue(
        text: user.paid[i].toString(),
        selection:
            TextSelection.collapsed(offset: user.paid[i].toString().length),
      );
      _cells[months[i]] = (DataCell(Focus(
          skipTraversal: true,
          onFocusChange: (focus) {
            if (focus) {
              _controllers[months[i]].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllers[months[i]].text.length,
              );
            }
          },
          child: TextFormField(
            keyboardType: TextInputType.text,
            controller: _controllers[months[i]],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("[0-9]+"))
            ],
            onChanged: (val) {
              user.paid[i] = int.parse(val);
              user.calculateResult();
              setState(() {});
            },
          ))));
    }
    _cells['Итого'] = DataCell(Text(user.result.toString()));
    _cells['remove'] = (DataCell(
        const Icon(
          Icons.delete,
          size: 20,
        ), onTap: () {
      _removeUser(user);
    }));
    return DataRow(
        cells: _cells.values.toList(),
        color: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
          if (user.toRemove) {
            return Colors.deepOrange;
          }
          return Colors.transparent; // Use the default value.
        }));
  }

  List<DataColumn> _buildColumns() {
    const _textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    var _columns = <DataColumn>[];
    _columns.add(const DataColumn(label: Text('Ф.И.', style: _textStyle)));
    _columns.add(const DataColumn(
        label: Text('Дата начала занятий', style: _textStyle)));
    for (var i = 0; i < months.length; i++) {
      //const DataColumn(label: Text(months[i], style: _textStyle))
      _columns.add(DataColumn(label: Text(months[i], style: _textStyle)));
    }
    _columns.add(const DataColumn(label: Text('', style: _textStyle)));
    return _columns;
  }

  @override
  Widget build(BuildContext context) {
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
                  columns: _buildColumns(),
                  rows: (_users.map((user) => _mapUserToTable(user)).toList()),
                ))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        tooltip: 'Добавить пользователя',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class User {
  late String name;
  late String dateStartOfEducation;
  late List<int> paid;
  late int result;
  bool toRemove = false;

  void calculateResult() {
    paid[paid.length - 2] = 0;
    result = paid.reduce((value, element) => value + element);
    paid[paid.length - 2] = result;
  }

  void changeRemove() {
    toRemove = !toRemove;
  }

  User() {
    result = 0;
    name = '';
    dateStartOfEducation = '';
    paid = List.filled(months.length, 0,
        growable: false); //TODO Replace it on new List(months.length)
    //     null safety issue
  }

  User.byName(String name) {
    this.name = name;
    paid = List.filled(months.length, 0, growable: false);
  }
}

// TODO:
// 1. сделать кнопку сохранить для строки или автоматом как-нибудь все это дело чтобы сохранялось              - done
// 1.1 разобраться с сабмитом этих форм которые в строке                                                       - done
// 2. экспорт xlsx:                                                                                            - pending
// 2.1. базовый экспорт: разобраться с либой, выводить просто строчки                                          - done
// 2.2. разобраться со стилями, чтобы все красиво +- как в примере выводилось                                  - pending
// 3. добавить автоподсчет ИТОГО                                                                               - done
// 4. настроить логику удаления (как в скринах) (чтобы падала вниз и раскрашивалась строчка)                   - done
// 5. если делать будет нечего, то заняться тем, чтобы убрать хардкод в моменте наполненния колонок для строки - done
// 6. добавить ввод для названия филиала                                                                       - pending
// 7. добавить сохранение текущего стейта, чтобы данные не терялись при закрытии                               - pending