import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

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

String currentName = '';

var _users = <User>[User()];
var numberOfDeletedUsers = 0;
const _title = 'ExcelGenerator';

Future<void> main() async {
  runApp(const LoadingScreen());
  await getState();
  runApp(const MyApp());
}

Future<void> getState() async {
  Directory tempDir = await getApplicationSupportDirectory();
  var file = File('${tempDir.path}\\excel_generator_state.json');
  if (file.existsSync()) {
    var json = jsonDecode(file.readAsStringSync());
    _users =
        (json['users'] as List).map((user) => User.fromJson(user)).toList();
    currentName = json['name'];
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: _title,
        theme: ThemeData(
          primarySwatch: Colors.cyan,
        ),
        home: Scaffold(
            appBar: AppBar(
              title: const Text(_title),
              actions: [
                IconButton(icon: const Icon(Icons.save), onPressed: () {}),
              ],
            ),
            body: const Center(
              child: ScaffoldMessenger(child: Text('Loading...')),
            )));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      theme: ThemeData(
        primarySwatch: Colors.cyan,
      ),
      home: const MyHomePage(title: _title),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _saveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  Future<void> _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File('${tempDir.path}\\excel_generator_state.json');
    var json = jsonEncode({'name': currentName, 'users': _users});
    file.writeAsString(json);
  }

  void _addUser() {
    if (_users[_users.length - 1 - numberOfDeletedUsers].name != '' &&
        _users[_users.length - 1 - numberOfDeletedUsers].dateStartOfEducation !=
            '') {
      setState(() {
        _users.add(User());
        _users.sort((a, b) {
          if (a.toRemove == b.toRemove) return 0;
          if (!a.toRemove) return -1;
          return 1;
        });
      });
    }
  }

  void _removeUser(User user) {
    if (!user.toRemove) {
      ++numberOfDeletedUsers;
      setState(() {
        user.changeRemove();
        _users.remove(user);
        _users.add(user);
      });
    }
  }

  Future<void> _pushSave() async {
    _saveState();
    var excel = Excel.createExcel();
    excel.rename('Sheet1', currentName);
    var sheet = excel[currentName];
    for (int i = 0; i < columns.length; ++i) {
      var cellStyle = CellStyle(
          bold: true, fontSize: 10, textWrapping: TextWrapping.WrapText);
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), columns[i],
          cellStyle: cellStyle);
    }
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
    for (int i = 0; i < months.length; ++i) {
      num value = 0;
      for (var user in _users) {
        value += user.paid[i] ?? 0;
      }
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: row),
          value.toInt(),
          cellStyle: CellStyle(backgroundColorHex: '#3792cb'));
    }
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    //saveExcel(excel, 'D:\\excelGenerator\\Отчет ' + formattedDate + '.xlsx');
    final name = "Отчет $currentName $formattedDate.xlsx";
    final data = Uint8List.fromList(excel.encode()!);
    if (Platform.isWindows) {
      final path = await getSavePath(suggestedName: name, acceptedTypeGroups: [
        XTypeGroup(label: 'Excel', extensions: ['xlsx'])
      ]);
      const mimeType = "application/vnd.ms-excel";
      final file = XFile.fromData(data, name: name, mimeType: mimeType);
      await file.saveTo(path);
    } else if (Platform.isAndroid) {
      final params = SaveFileDialogParams(data: data, fileName: name);
      final filePath = await FlutterFileDialog.saveFile(params: params);
    }
  }

  DataRow _mapUserToTable(User user) {
    var _cells = LinkedHashMap<String, DataCell>();
    _cells['name'] = (DataCell(TextFormField(
      readOnly: user.toRemove,
      initialValue: user.name,
      decoration: const InputDecoration(hintText: "Введите Ф.И"),
      keyboardType: TextInputType.text,
      onChanged: (val) {
        user.name = val;
      },
      onTap: () {
        if (Platform.isWindows) {
          _saveState();
        }
      },
    )));
    _cells['date'] = (DataCell(TextFormField(
      readOnly: user.toRemove,
      initialValue: user.dateStartOfEducation,
      decoration:
          const InputDecoration(hintText: "Введите дату начала обучения"),
      keyboardType: TextInputType.datetime,
      onChanged: (val) {
        user.dateStartOfEducation = val;
      },
      onTap: () {
        if (Platform.isWindows) {
          _saveState();
        }
      },
    )));
    for (var i = 0; i < months.length; ++i) {
      _cells[months[i]] = (DataCell(TextFormField(
        readOnly: user.toRemove,
        keyboardType: TextInputType.number,
        initialValue: user.paid[i] == null ? '' : user.paid[i].toString(),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp("[0-9]+"))],
        onChanged: (val) {
          user.paid[i] = val == '' ? 0 : int.parse(val);
          user.calculateResult();
          setState(() {});
        },
        onTap: () {
          if (Platform.isWindows) {
            _saveState();
          }
        },
      )));
    }
    _cells['Итого'] = DataCell(Text(user.result.toString()));
    _cells['remove'] = (DataCell(
        const Icon(
          Icons.delete,
          size: 20,
        ), onTap: () {
      if (Platform.isWindows) _saveState();
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

  void _debugDeleteAll() {
    _users = <User>[User()];
    _users[0].name = 'asd';
    _users[0].dateStartOfEducation = 'asd';
    numberOfDeletedUsers = 0;
    setState(() {});
    //_saveState();
    print(_users[0].name);
  }

  List<DataColumn> _buildColumns() {
    const _textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    var _columns = <DataColumn>[];
    _columns.add(const DataColumn(label: Text('Ф.И.', style: _textStyle)));
    _columns.add(const DataColumn(
        label: Text('Дата начала занятий', style: _textStyle)));
    for (var i = 0; i < months.length; i++) {
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
          IconButton(
              onPressed: _debugDeleteAll,
              icon: const Icon(Icons.delete_forever_outlined)),
          IconButton(onPressed: _pushSave, icon: const Icon(Icons.save))
        ],
      ),
      body: Center(
        child: Scrollbar(
            showTrackOnHover: true,
            interactive: true,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextFormField(
                    initialValue: currentName,
                    decoration: const InputDecoration(
                        hintText: "Введите название филиала"),
                    onChanged: (val) {
                      currentName = val;
                    },
                    onTap: () {
                      if (Platform.isWindows) {
                        _saveState();
                      }
                    },
                  )),
              Expanded(
                child: SingleChildScrollView(
                  primary: true,
                  scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columns: _buildColumns(),
                          rows: (_users
                              .map((user) => _mapUserToTable(user))
                              .toList()),
                        ))),
              )
            ])),
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
  late List<dynamic> paid;
  late num result;
  bool toRemove = false;

  void calculateResult() {
    paid[paid.length - 2] = 0;
    result = 0;
    for (var el in paid) {
      result += el ?? 0;
    }
    paid[paid.length - 2] = result;
  }

  void changeRemove() {
    toRemove = !toRemove;
  }

  Map toJson() => {
        'name': name,
        'dateStartOfEducation': dateStartOfEducation,
        'paid': paid,
        'result': result,
        'toRemove': toRemove
      };

  factory User.fromJson(dynamic json) {
    return User.allData(
        json['name'] as String,
        json['dateStartOfEducation'] as String,
        json['paid'].cast<int>(),
        json['result'] as int,
        json['toRemove'] as bool);
  }

  User() {
    result = 0;
    name = '';
    dateStartOfEducation = '';
    paid = List.filled(months.length, null, growable: false);
  }

  User.byName(String name) {
    this.name = name;
    paid = List.filled(months.length, null, growable: false);
  }

  User.allData(this.name, this.dateStartOfEducation, this.paid, this.result,
      this.toRemove);
}

// TODO:
// 1. сделать кнопку сохранить для строки или автоматом как-нибудь все это дело чтобы сохранялось              - done
// 1.1 разобраться с сабмитом этих форм которые в строке                                                       - done
// 2. экспорт xlsx:                                                                                            - done
// 2.1. базовый экспорт: разобраться с либой, выводить просто строчки                                          - done
// 2.2. разобраться со стилями, чтобы все красиво +- как в примере выводилось                                  - done
// 3. добавить автоподсчет ИТОГО                                                                               - done
// 4. настроить логику удаления (как в скринах) (чтобы падала вниз и раскрашивалась строчка)                   - done
// 5. если делать будет нечего, то заняться тем, чтобы убрать хардкод в моменте наполненния колонок для строки - done
// 6. добавить ввод для названия филиала                                                                       - done
// 7. добавить сохранение текущего стейта, чтобы данные не терялись при закрытии                               - done (можно попытаться ловить закрытие на винде)
// 8. сохранение xlsx на андроиде                                                                              - done
