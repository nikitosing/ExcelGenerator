import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:excel_generator/affiliates_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:path_provider/path_provider.dart';

import 'cities_controller.dart';
import 'common.dart';
import 'decimal_text_input_formatter.dart';

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

class UserTable extends StatefulWidget {
  final cities;
  final affiliate;

  const UserTable({Key? key, this.cities, this.affiliate}) : super(key: key);

  @override
  State<UserTable> createState() => _UserTableState();
}

class _UserTableState extends State<UserTable> {
  @override
  UserTable get widget => super.widget;

  double _nameColumnWidth = 250;
  int numberOfDeletedUsers = 0;
  var users = [];
  late List<City> cities;
  late Affiliate affiliate;
  late List<String> userDefinedColumns;
  late List<Types> userDefinedColumnsTypes;

  @override
  initState() {
    super.initState();

    cities = widget.cities;
    affiliate = widget.affiliate;
    userDefinedColumns = affiliate.userDefinedColumns;
    userDefinedColumnsTypes = affiliate.userDefinedColumnsTypes;
    users = affiliate.users;

    for (var user in users) {
      if (user.status == UserStatus.toEdit) {
        ++numberOfDeletedUsers;
      }
    }
  }

  @override
  void dispose() {
    //WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  Future<void> _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File(
        '${tempDir.path}${Platform.pathSeparator}excel_generator_state6.json');
    file.writeAsStringSync(jsonEncode(cities));
  }

  void _sortUsers() {
    users.sort((a, b) {
      return a.status.index - b.status.index;
    });
  }

  void _addUser() {
    if (users.length == numberOfDeletedUsers ||
        (users[users.length - 1 - numberOfDeletedUsers].name != '' &&
            users[users.length - 1 - numberOfDeletedUsers]
                    .dateStartOfEducation !=
                null)) {
      users.add(User(userDefinedColumns.length));
      _sortUsers();
    }
  }

  Future<void> _editDialog(user) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтвердите'),
          content: SingleChildScrollView(
            child: Column(
              children: const [
                Text(
                    'Вы точно хотите пометить человека как неверную информацию?'),
                Text('После этого вы никак не сможете редактировать его.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Да'),
              onPressed: () {
                user.status = UserStatus.toEdit;
                ++numberOfDeletedUsers;
                _sortUsers();
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Нет'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeDialog(user) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтвердите'),
          content: SingleChildScrollView(
            child: Column(
              children: const [
                Text('Вы точно хотите пометить человека как выбывшего?'),
                Text(
                    'После этого вы никак не сможете редактировать информацию о нем.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Да'),
              onPressed: () {
                user.status = UserStatus.toRemove;
                ++numberOfDeletedUsers;
                _sortUsers();
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Нет'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addColumn() {
    var types = <Types, String>{
      Types.text: 'Текст',
      Types.formula: 'Формула',
      Types.number: 'Число'
    };
    Types chosen = Types.number;
    String name = '';
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Создание столбца'),
                content: Scrollbar(
                  isAlwaysShown: true,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                            TextField(
                              autofocus: true,
                              onChanged: (val) {
                                name = val;
                              },
                            )
                          ].cast<Widget>() +
                          types.keys
                              .map((type) => RadioListTile<Types>(
                                    title: Text(types[type]!),
                                    value: type,
                                    onChanged: (newVal) {
                                      setState(() {
                                        chosen = newVal!;
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    groupValue: chosen,
                                  ))
                              .toList()
                              .cast<Widget>(),
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Добавить'),
                    onPressed: () {
                      userDefinedColumns.add(name);
                      affiliate.userDefinedColumnsTypes.add(chosen);
                      users.forEach((element) {
                        element.properties.add(null);
                        element.toPaint.add(false);
                      });
                      Navigator.of(context).pop();
                      if (Platform.isWindows) _saveState();
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  Future<void> _removeColumn(var index) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтвердите'),
          content: SingleChildScrollView(
            child: Column(
              children: const [Text('Вы точно хотите удалить столбец?')],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Да'),
              onPressed: () {
                userDefinedColumns.removeAt(index);
                userDefinedColumnsTypes.removeAt(index);
                users.forEach((element) {
                  element.properties.removeAt(months.length + index);
                  element.toPaint.removeAt(months.length + index + 2);
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Нет'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        _getBodyWidget(),
        Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: min(MediaQuery.of(context).size.width - 150, 500),
                height: 104,
                child: FlutterSlider(
                  trackBar: FlutterSliderTrackBar(
                    inactiveTrackBar: BoxDecoration(
                      color: Colors.transparent,
                    ),
                    activeTrackBar: BoxDecoration(
                      color: Colors.transparent,
                    ),
                    activeDisabledTrackBarColor: Colors.transparent,
                    inactiveDisabledTrackBarColor: Colors.transparent,
                  ),
                  handlerWidth: 5,
                  handlerAnimation: FlutterSliderHandlerAnimation(scale: 1),
                  handler: FlutterSliderHandler(
                      foregroundDecoration:
                          BoxDecoration(color: Colors.grey[400]),
                      child: SizedBox(
                          width: 9,
                          height: double.infinity,
                          child: MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn))),
                  handlerHeight: double.infinity,
                  touchSize: 10,
                  visibleTouchArea: false,
                  selectByTap: false,
                  jump: false,
                  values: [_nameColumnWidth],
                  tooltip: FlutterSliderTooltip(
                    disabled: true,
                  ),
                  max: min(MediaQuery.of(context).size.width - 150, 500),
                  min: 0,
                  onDragging: (handlerIndex, lowerValue, upperValue) {
                    _nameColumnWidth = lowerValue < 45 ? 45 : lowerValue;
                    setState(() {});
                  },
                )))
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _addUser();
          });
        },
        tooltip: 'Добавить пользователя',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getBodyWidget() {
    return SizedBox(
      //key: UniqueKey(),
      child: HorizontalDataTable(
          leftHandSideColBackgroundColor: const Color(0xFAFAFA),
          rightHandSideColBackgroundColor: const Color(0xFAFAFA),
          leftHandSideColumnWidth: _nameColumnWidth,
          rightHandSideColumnWidth:
              1670 + affiliate.userDefinedColumns.length * 200,
          isFixedHeader: true,
          headerWidgets: _buildColumns(),
          leftSideChildren:
              users.map((user) => _generateFirstColumnRow(user)).toList(),
          rightSideChildren: users
              .map((user) => _generateRightHandSideColumnRow(user))
              .toList(),
          itemCount: users.length,
          horizontalScrollbarStyle: ScrollbarStyle(
            isAlwaysShown: true,
            thickness: 5.0,
            radius: Radius.circular(5.0),
          )),
      height: MediaQuery.of(context).size.height,
    );
  }

  Container _getNumCell(User user, int index) {
    return Container(
      child: Focus(
          skipTraversal: true,
          onFocusChange: (isFocus) {
            if (!isFocus && Platform.isWindows) _saveState();
          },
          child: TextFormField(
            key: Key('${user.id}UDDColumn$index'),
            autofocus: true,
            readOnly: user.status != UserStatus.normal,
            keyboardType: TextInputType.number,
            initialValue: user.properties[index + months.length] == null
                ? ''
                : user.properties[index + months.length].toStringAsFixed(2),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("^\\d*\\.?\\d*")),
              DecimalTextInputFormatter(decimalRange: 2)
            ],
            onChanged: (val) {
              user.properties[index + months.length] =
                  val == '' ? 0 : num.parse(val);
            },
            decoration: const InputDecoration(counterText: ""),
            maxLength: 12,
          )),
      width: 200,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
      color:
          user.toPaint[index + 2 + months.length] ? Colors.yellowAccent : null,
    );
  }

  Container _getStringCell(User user, int index) {
    return Container(
        child: Focus(
            skipTraversal: true,
            onFocusChange: (isFocus) {
              if (!isFocus && Platform.isWindows) _saveState();
            },
            child: TextFormField(
              key: Key('${user.id}UDDColumn$index'),
              autofocus: true,
              readOnly: user.status != UserStatus.normal,
              initialValue: user.properties[index + months.length] == null
                  ? ''
                  : user.properties[index + months.length],
              onChanged: (val) {
                user.properties[index + months.length] = val;
                setState(() {});
              },
              decoration: const InputDecoration(counterText: ""),
              maxLength: 60,
            )),
        width: 200,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft,
        color: user.toPaint[index + 2 + months.length]
            ? Colors.yellowAccent
            : null);
  }

  List<Widget> _buildColumns() {
    const _columnTextStyle =
        TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    var _columns = <Widget>[];
    _columns.add(Container(
        child: const Center(
            child: Text('Ф.И.',
                style: _columnTextStyle, textAlign: TextAlign.center)),
        width: _nameColumnWidth,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.center));

    _columns.add(Container(
        child: const Text('Дата начала занятий',
            style: _columnTextStyle, textAlign: TextAlign.center),
        width: 200,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.center));
    for (var i = 0; i < months.length; i++) {
      num _sum = 0;
      for (var user in users) {
        if (user.status == UserStatus.toEdit) break;
        _sum += user.properties[i] ?? 0;
      }
      _columns.add(Container(
          child: Column(
            children: [
              Expanded(
                  child: Text(columns[i + 3],
                      style: _columnTextStyle, textAlign: TextAlign.center)),
              Expanded(
                  child: Text(_sum.toStringAsFixed(2),
                      textAlign: TextAlign.center, style: _columnTextStyle))
            ],
          ),
          width: i == months.length - 3 ? 220 : 100,
          height: 104,
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          alignment: Alignment.center));
    }
    _columns.add(Container(
        child: const Text(''),
        width: 50,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    _columns.add(Container(
        child: Text(''),
        width: 50,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    for (var i = 0; i < userDefinedColumns.length; ++i) {
      _columns.add(Container(
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            SizedBox(
                child: Text(userDefinedColumns[i],
                    style: _columnTextStyle, textAlign: TextAlign.center),
                width: 147),
            IconButton(
                iconSize: 20,
                onPressed: () async {
                  await _removeColumn(i);
                  setState(() {});
                },
                icon: Icon(Icons.close))
          ]),
          width: 200,
          height: 104,
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          alignment: Alignment.center));
    }
    _columns.add(Container(
        child: IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              await _addColumn();
              setState(() {});
            }),
        width: 50,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    return _columns;
  }

  Widget _generateFirstColumnRow(user) {
    return Container(
      child: Focus(
          skipTraversal: true,
          onFocusChange: (isFocus) {
            if (!isFocus && Platform.isWindows) _saveState();
          },
          child: TextFormField(
            key: Key('${user.id}name'),
            readOnly: user.status == UserStatus.toRemove,
            initialValue: user.name,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp("[0-9]+"))
            ],
            // ^(\d*\.)?\d+$
            autofocus: true,
            maxLength: 60,
            decoration:
                const InputDecoration(hintText: "Введите Ф.И", counterText: ""),
            keyboardType: TextInputType.text,
            onChanged: (val) {
              user.name = val;
            },
            // onTap: () {
            //   if (Platform.isWindows) {
            //     _saveState();
            //   }
            //},
          )),
      width: _nameColumnWidth,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
      color: () {
        if (user.toPaint[0]) return Colors.yellowAccent;
        switch (user.status) {
          case UserStatus.normal:
            return Colors.transparent;
          case UserStatus.toEdit:
            return Colors.deepOrange;
          case UserStatus.toRemove:
            return Colors.yellowAccent;
        }
      }(),
    );
  }

  Widget _generateRightHandSideColumnRow(user) {
    var _cells = LinkedHashMap<String, Widget>();

    _cells['date'] = Container(
        child: Focus(
            skipTraversal: true,
            //autofocus: true,
            onFocusChange: (isFocused) async {
              if (isFocused && user.status == UserStatus.normal) {
                await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2001),
                        lastDate: DateTime.now())
                    .then((date) => setState(() {
                          user.dateStartOfEducation = date;
                        }));
              }
            },
            child: TextFormField(
              autofocus: false,
              key: Key('${user.id}${user.dateStartOfEducation.toString()}'),
              readOnly: true,
              initialValue: user.dateStartOfEducation == null
                  ? ''
                  : '${user.dateStartOfEducation.day}/${user.dateStartOfEducation.month}/${user.dateStartOfEducation.year}',
              decoration: const InputDecoration(hintText: "Выберите дату"),
              keyboardType: null,
            )),
        width: 200,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft,
        color: user.toPaint[1] ? Colors.yellowAccent : null);
    for (var i = 0; i < months.length; ++i) {
      _cells[months[i]] = Container(
          child: Focus(
              skipTraversal: true,
              onFocusChange: (isFocus) {
                if (!isFocus && Platform.isWindows) _saveState();
              },
              child: TextFormField(
                key: Key('${user.id}Month$i'),
                autofocus: true,
                readOnly: user.status != UserStatus.normal,
                keyboardType: TextInputType.number,
                initialValue: user.properties[i] == null
                    ? ''
                    : user.properties[i].toStringAsFixed(2),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp("^\\d*\\.?\\d*")),
                  DecimalTextInputFormatter(decimalRange: 2)
                ],
                onChanged: (val) {
                  user.properties[i] = val == '' ? 0 : num.parse(val);
                  user.calculateResult();
                  setState(() {});
                },
                decoration: const InputDecoration(counterText: ""),
                maxLength: 12,
                // onTap: () {
                //   if (Platform.isWindows) {
                //     _saveState();
                //   }
                // }
              )),
          width: i == months.length - 3 ? 220 : 100,
          height: 52,
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          alignment: Alignment.centerLeft,
          color: user.toPaint[i + 2] ? Colors.yellowAccent : null);
    }

    _cells['Итого'] = Container(
      child: Text(user.result.toStringAsFixed(2)),
      width: 100,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );

    _cells['remove'] = Container(
      child: IconButton(
          onPressed: () {
            if (user.status == UserStatus.normal) {
              _removeDialog(user);
              //setState(() {}); done in function above
              if (Platform.isWindows) _saveState();
            }
          },
          icon: const Icon(Icons.delete, size: 20)),
      width: 50,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );

    _cells['edit'] = Container(
      child: IconButton(
          onPressed: () {
            if (user.status == UserStatus.normal) {
              _editDialog(user);
              //setState(() {}); done in function above
              if (Platform.isWindows) _saveState();
            }
          },
          icon: const Icon(Icons.edit, size: 20)),
      width: 50,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );

    for (var i = 0; i < userDefinedColumns.length; ++i) {
      switch (affiliate.userDefinedColumnsTypes[i]) {
        case Types.number:
          _cells[userDefinedColumns[i]] = _getNumCell(user, i);
          break;
        case Types.text:
        case Types.formula:
          _cells[userDefinedColumns[i]] = _getStringCell(user, i);
          break;
      }
    }

    _cells['spacer'] = Container(
      child: Text(''),
      width: 50,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );

    return Container(
      child: Row(children: _cells.values.toList()),
      color: () {
        switch (user.status) {
          case UserStatus.normal:
            return Colors.transparent;
          case UserStatus.toEdit:
            return Colors.deepOrange;
          case UserStatus.toRemove:
            return Colors.yellowAccent;
        }
      }(),
    );
  }
}

class User {
  String id = UniqueKey().hashCode.toString();
  late String name;
  late DateTime? dateStartOfEducation;
  late List<dynamic> properties;
  List<bool> toPaint = List.filled(months.length + 2, false, growable: true);
  late User initUser;
  late num result;
  UserStatus status = UserStatus.normal;
  late List<bool> toSum;
  bool isMemorized = false;

  void memorizeProperties() {
    initUser = User.allData(
        name, dateStartOfEducation, List.from(properties), result, status);
    isMemorized = true;
  }

  void calculateResult() {
    properties[10] = 0;
    result = 0;
    for (var el in properties.sublist(0, months.length)) {
      result += el ?? 0;
    }
    properties[10] = result;
  }

  Map toJson() => {
        'name': name,
        'dateStartOfEducation': dateStartOfEducation.toString(),
        'properties':
            properties.map((e) => e is Formula ? e.formula : e).toList(),
        'result': result,
        'status': status.index,
      };

  factory User.fromJson(dynamic json) {
    User temp = User.allData(
        json['name'] as String,
        json['dateStartOfEducation'] == "null"
            ? null
            : DateTime.parse(json['dateStartOfEducation']),
        json['properties'],
        json['result'] as num,
        UserStatus.values[json['status']]);
    temp.memorizeProperties();
    return temp;
  }

  User(int numberOfUDColumns) {
    result = 0;
    name = '';
    dateStartOfEducation = null;
    properties =
        List.filled(months.length + numberOfUDColumns, null, growable: true);
    toPaint = List.filled(months.length + 2 + numberOfUDColumns, false,
        growable: true);
  }

  User.byName(String name) {
    this.name = name;
    properties = List.filled(months.length, null, growable: true);
    toPaint = List.filled(months.length + 2, false, growable: true);
  }

  User.allData(this.name, this.dateStartOfEducation, this.properties,
      this.result, this.status) {
    toPaint = List.filled(properties.length + 2, false, growable: true);
  }
}
