import 'dart:collection';
import 'dart:convert';
import 'dart:io';

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

List<bool> toSum = [
  true,
  true,
  true,
  true,
  true,
  true,
  true,
  true,
  true,
  true,
  true,
  false,
  true
];

class UserTable extends StatefulWidget {
  final cities;
  final affiliate;

  const UserTable({Key? key, this.cities, this.affiliate}) : super(key: key);

  @override
  State<UserTable> createState() => _UserTableState();
}

class _UserTableState extends State<UserTable> with WidgetsBindingObserver {
  @override
  UserTable get widget => super.widget;

  double _nameColumnWidth = 250;
  int numberOfDeletedUsers = 0;
  var users = [];
  late List<City> cities;
  late Affiliate affiliate;

  @override
  initState() {

    super.initState();

    cities = widget.cities;
    affiliate = widget.affiliate;
    users = affiliate.users;

    for (var user in users) {
      if (user.status == UserStatus.toEdit) {
        ++numberOfDeletedUsers;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File('${tempDir.path}\\excel_generator_state5.json');
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
                DateTime(1337))) {
      users.add(User());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        _getBodyWidget(),
        Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: MediaQuery.of(context).size.width - 100,
                height: 104,
                child: FlutterSlider(
                  //key: Key('Slider ${affiliate.id}'),
                  trackBar: const FlutterSliderTrackBar(
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
                  handlerAnimation:
                      const FlutterSliderHandlerAnimation(scale: 1),
                  handler: FlutterSliderHandler(
                      foregroundDecoration:
                          BoxDecoration(color: Colors.grey[400]),
                      child: const SizedBox(
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
                  max: MediaQuery.of(context).size.width - 100,
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
      child: HorizontalDataTable(
          leftHandSideColBackgroundColor: const Color(0xFAFAFA),
          rightHandSideColBackgroundColor: const Color(0xFAFAFA),
          leftHandSideColumnWidth: _nameColumnWidth,
          rightHandSideColumnWidth: 1620,
          isFixedHeader: true,
          headerWidgets: _buildColumns(),
          leftSideChildren:
              users.map((user) => _generateFirstColumnRow(user)).toList(),
          rightSideChildren: users
              .map((user) => _generateRightHandSideColumnRow(user))
              .toList(),
          itemCount: users.length,
          horizontalScrollbarStyle: const ScrollbarStyle(
            isAlwaysShown: true,
            thickness: 5.0,
            radius: Radius.circular(5.0),
          )),
      height: MediaQuery.of(context).size.height,
    );
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
                  child: Text(months[i],
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
        child: const Text(''),
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
            key: UniqueKey(),
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
            onTap: () {
              if (Platform.isWindows) {
                _saveState();
              }
            },
          )),
      width: _nameColumnWidth,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
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

  Widget _generateRightHandSideColumnRow(user) {
    var _cells = LinkedHashMap<String, Widget>();
    _cells['date'] = Container(
      child: Focus(
          skipTraversal: true,
          autofocus: false,
          onFocusChange: (isFocused) {
            if (isFocused && user.status == UserStatus.normal) {
              showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2001),
                      lastDate: DateTime.now())
                  .then((date) => setState(() {
                        user.dateStartOfEducation = date;
                      }));
            }
            if (!isFocused && Platform.isWindows) {
              _saveState();
            }
          },
          child: TextFormField(
            autofocus: false,
            key: UniqueKey(),
            readOnly: true,
            initialValue: user.dateStartOfEducation == DateTime(1337) ||
                    user.dateStartOfEducation == null
                ? ''
                : '${user.dateStartOfEducation.day}/${user.dateStartOfEducation.month}/${user.dateStartOfEducation.year}',
            decoration: const InputDecoration(hintText: "Выберите дату"),
            keyboardType: TextInputType.datetime,
          )),
      width: 200,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );
    for (var i = 0; i < months.length; ++i) {
      _cells[months[i]] = Container(
        child: Focus(
            skipTraversal: true,
            onFocusChange: (isFocus) {
              if (!isFocus && Platform.isWindows) _saveState();
            },
            child: TextFormField(
                key: Key('${user.hashCode}Month$i'),
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
                onTap: () {
                  if (Platform.isWindows) {
                    _saveState();
                  }
                })),
        width: i == months.length - 3 ? 220 : 100,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft,
      );
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
  late String name;
  late DateTime? dateStartOfEducation;
  late List<dynamic> properties;
  late User initUser;
  late num result;
  UserStatus status = UserStatus.normal;
  late List<bool> toSum;
  bool isMemorized = false;

  void memorizeProperties() {
    initUser = User.allData(name, dateStartOfEducation, List.from(properties), result, status);
    isMemorized = true;
  }

  void calculateResult() {
    properties[properties.length - 2] = 0;
    result = 0;
    for (var el in properties) {
      result += el ?? 0;
    }
    properties[properties.length - 2] = result;
  }

  Map toJson() => {
        'name': name,
        'dateStartOfEducation': dateStartOfEducation.toString(),
        'properties': properties,
        'result': result,
        'status': status.index,
      };

  factory User.fromJson(dynamic json) {
    User temp = User.allData(
        json['name'] as String,
        json['dateStartOfEducation'] == "null"
            ? null
            : DateTime.parse(json['dateStartOfEducation']),
        json['properties'].cast<num>(),
        json['result'] as num,
        UserStatus.values[json['status']]);
    temp.memorizeProperties();
    return temp;
  }

  User() {
    result = 0;
    name = '';
    dateStartOfEducation = DateTime(1337);
    properties = List.filled(columns.length - 3, null);
  }

  User.byName(String name) {
    this.name = name;
    properties = List.filled(months.length, null);
  }

  User.allData(this.name, this.dateStartOfEducation, this.properties,
      this.result, this.status);
}
