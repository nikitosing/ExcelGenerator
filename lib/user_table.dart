import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:excel/excel.dart';
import 'package:excel_generator/affiliates_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart'
    hide Column, Row, Alignment, Stack;

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
var regexp = RegExp(r'(?<=[A-Z])(?:-?(?:0|[1-9][0-9]*))');

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
  late Map<String, TextEditingController> formulaFieldsControllers;

  @override
  initState() {
    super.initState();

    formulaFieldsControllers = {};
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
    for (var controller in formulaFieldsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File(
        '${tempDir.path}${Platform.pathSeparator}excel_generator_state7.json');
    file.writeAsStringSync(jsonEncode(cities));
  }

  void _sortUsers() {
    users.sort((a, b) {
      return a.status.index - b.status.index;
    });
    users.asMap().forEach((index, element) {
      for (int i = 0; i < userDefinedColumnsTypes.length; ++i) {
        if (userDefinedColumnsTypes[i] == Types.formula) {
          num rowOfUser = index +
              2 +
              element.status.index +
              (element.status == UserStatus.toEdit ? 1 : 0);
          if (element.properties[i + months.length] != null) {
            var formulaReadyToEdit = element.properties[i + months.length]
                .split(regexp);
            if (formulaReadyToEdit != null) {
              element.properties[i + months.length] =
                  formulaReadyToEdit.join('$rowOfUser');
            }
          } else {
            if (userDefinedColumns[i].contains('=')) {
              var formulaReadyToEdit = userDefinedColumns[i]
                  .substring(userDefinedColumns[i].indexOf('='))
                  .split(regexp);
              element.properties[i + months.length] =
                  formulaReadyToEdit.join('$rowOfUser').toUpperCase();
            }
          }
        }
      }
    });
  }

  void _addUser() {
    if (users.length == numberOfDeletedUsers ||
        (users[users.length - 1 - numberOfDeletedUsers].name != '' &&
            users[users.length - 1 - numberOfDeletedUsers]
                    .dateStartOfEducation !=
                null)) {
      users.add(User.toPaint(userDefinedColumns.length));
      _sortUsers();
    }
  }

  String calculateFormulas(User user, int indexOfFormula, int indexOfUser) {
    String translatedFormula = user.properties[indexOfFormula + months.length];
    for (String frml in ruFormulasToEn.keys) {
      translatedFormula =
          translatedFormula.replaceAll(frml, ruFormulasToEn[frml]!);
    }
    translatedFormula =
        translatedFormula.split(regexp).join(('1'));
    Workbook wb = Workbook.withCulture('ru');
    Worksheet ws = wb.worksheets[0];
    ws.getRangeByName('A1').number = indexOfUser + 1;
    ws.getRangeByName('B1').text = user.name;
    ws.getRangeByName('C1').dateTime = user.dateStartOfEducation;
    int column = 3;
    for (var property in user.properties) {
      ++column;
      if (column - 1 < columns.length) {
        ws.getRangeByIndex(1, column).number =
            property == null ? 0 : property.toDouble();
        continue;
      }
      switch (affiliate.userDefinedColumnsTypes[column - columns.length - 1]) {
        case Types.number:
          ws.getRangeByIndex(1, column).number = property;
          break;
        case Types.text:
          ws.getRangeByIndex(1, column).text = property;
          break;
        case Types.formula:
          String translatedFormula = property;
          for (String frml in ruFormulasToEn.keys) {
            translatedFormula =
                translatedFormula.replaceAll(frml, ruFormulasToEn[frml]!);
          }
          translatedFormula = translatedFormula
              .split(regexp)
              .join(('1'));
          ws.getRangeByIndex(1, column).formula = translatedFormula;
          break;
      }
    }
    ws.enableSheetCalculations();
    String value = ws
        .getRangeByIndex(1, indexOfFormula + 1 + columns.length)
        .calculatedValue!;
    wb.dispose();
    return value;
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
    //bool isValidName
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
                      var property = null;
                      if (chosen == Types.formula && name.contains('=')) {
                        property =
                            name.substring(name.indexOf('=')).toUpperCase();
                        property =
                            property.split(regexp);
                      }
                      userDefinedColumns.add(name);
                      affiliate.userDefinedColumnsTypes.add(chosen);
                      users.asMap().forEach((index, element) {
                        element.properties.add(property !=
                                null // means that chosen is formula and has some formula in its name
                            ? property.join(
                                '${index + 2 + element.status.index + (element.status == UserStatus.toEdit ? 1 : 0)}')
                            : property);
                        element.toPaint.add(true);
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
                for (var element in users) {
                  element.properties.removeAt(months.length + index);
                  element.toPaint.removeAt(months.length + index + 2);
                }
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
                  handlerAnimation: const FlutterSliderHandlerAnimation(scale: 1),
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
          leftSideChildren: users
              .mapIndexed((index, user) => _generateFirstColumnRow(index, user))
              .toList(),
          rightSideChildren: users
              .mapIndexed(
                  (index, user) => _generateRightHandSideColumnRow(index, user))
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
              if (user.isMemorized) {
                user.toPaint[index + months.length] =
                    user.properties[index + months.length] !=
                        user.initUser.properties[index + months.length];
              }
            },
            decoration: const InputDecoration(counterText: ""),
            maxLength: 12,
          )),
      width: 200,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
      color: user.toPaint[index + 2 + months.length] ? Colors.teal[100] : null,
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
              initialValue: user.properties[index + months.length] ?? '',
              onChanged: (val) {
                user.properties[index + months.length] = val;
                if (user.isMemorized) {
                  user.toPaint[index + months.length] =
                      user.properties[index + months.length] !=
                          user.initUser.properties[index + months.length];
                }
                setState(() {});
              },
              decoration: const InputDecoration(counterText: ""),
              maxLength: 60,
            )),
        width: 200,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft,
        color:
            user.toPaint[index + 2 + months.length] ? Colors.teal[100] : null);
  }

  Container _getFormulaCell(User user, int index, int indexOfUser) {
    // CONTROLLERS
    TextEditingController controller;
    if (formulaFieldsControllers.containsKey('${user.id}$index')) {
      controller = formulaFieldsControllers['${user.id}$index']!;
    } else {
      formulaFieldsControllers['${user.id}$index'] = TextEditingController(
          text: user.properties[index + months.length] == null ||
                  user.properties[index + months.length] == ''
              ? ''
              : calculateFormulas(user, index, indexOfUser));
      controller = formulaFieldsControllers['${user.id}$index']!;
    }
    return Container(
        child: Focus(
            skipTraversal: true,
            onFocusChange: (isFocus) {
              if (isFocus) {
                controller.text = user.properties[index + months.length] ?? '';
              } else {
                controller.text =
                    user.properties[index + months.length] == null ||
                            user.properties[index + months.length] == ''
                        ? ''
                        : calculateFormulas(user, index, indexOfUser);
              }

              if (!isFocus && Platform.isWindows) _saveState();
            },
            child: TextFormField(
              controller: controller,
              inputFormatters: [UpperCaseTextFormatter()],
              key: Key('${user.id}UDDColumn$index'),
              autofocus: true,
              readOnly: user.status != UserStatus.normal,
              onChanged: (val) {
                user.properties[index + months.length] = val.toUpperCase();
                if (user.isMemorized) {
                  user.toPaint[index + months.length] =
                      user.properties[index + months.length] !=
                          user.initUser.properties[index + months.length];
                }
                //setState(() {});
              },
              decoration: const InputDecoration(counterText: ""),
              maxLength: 60,
            )),
        width: 200,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft,
        color:
            user.toPaint[index + 2 + months.length] ? Colors.teal[100] : null);
  }

  String _getLetterForColumn(int index) {
    if (index > 10) {
      return '${String.fromCharCode((index - 11) ~/ 26 + 65)}${String.fromCharCode((index - 11) % 26 + 65)}';
    } else {
      return String.fromCharCode(index + 80);
    }
  }

  List<Widget> _buildColumns() {
    const _columnTextStyle =
        TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    var _columns = <Widget>[];
    _columns.add(Container(
        child: Center(
            child: Column(children: const [
          Text('B'),
          Text('Ф.И.', style: _columnTextStyle, textAlign: TextAlign.center)
        ])),
        width: _nameColumnWidth,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.center));

    _columns.add(Container(
        child: Column(children: const [
          Text('C'),
          Text('Дата начала занятий',
              style: _columnTextStyle, textAlign: TextAlign.center)
        ]),
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
              Text(String.fromCharCode(i + 68)),
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
        child: const Text(''),
        width: 50,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    for (var i = 0; i < userDefinedColumns.length; ++i) {
      _columns.add(Container(
          child: Column(
            children: [
              Text(_getLetterForColumn(i)),
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
                    icon: const Icon(Icons.close))
              ]),
            ],
          ),
          width: 200,
          height: 104,
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          alignment: Alignment.center));
    }
    _columns.add(Container(
        child: IconButton(
            icon: const Icon(Icons.add),
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

  Widget _generateFirstColumnRow(int index, user) {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              '${index + 2 + user.status.index + (user.status == UserStatus.toEdit ? 1 : 0)}'),
          Focus(
              skipTraversal: true,
              onFocusChange: (isFocus) {
                if (!isFocus && Platform.isWindows) _saveState();
              },
              child: SizedBox.fromSize(
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
                    decoration: const InputDecoration(
                        hintText: "Введите Ф.И", counterText: ""),
                    keyboardType: TextInputType.text,
                    onChanged: (val) {
                      user.name = val;
                      if (user.isMemorized) {
                        user.toPaint[0] = user.name != user.initUser.name;
                      }
                      setState(() {});
                    },
                  ),
                  size: Size(_nameColumnWidth - 23, 52))),
        ],
      ),
      width: _nameColumnWidth,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 2, 0, 0),
      alignment: Alignment.bottomLeft,
      color: () {
        if (user.toPaint[0]) return Colors.teal[100];
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

  Widget _generateRightHandSideColumnRow(int index, user) {
    var _cells = LinkedHashMap<String, Widget>();

    _cells['date'] = Container(
        child: Focus(
            skipTraversal: true,
            onFocusChange: (isFocused) async {
              if (isFocused && user.status == UserStatus.normal) {
                await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2001),
                        lastDate: DateTime.now())
                    .then((date) => setState(() {
                          user.dateStartOfEducation = date;
                          if (user.isMemorized) {
                            user.toPaint[1] = user.dateStartOfEducation !=
                                user.initUser.dateStartOfEducation;
                          }
                        }));
                if (Platform.isWindows) _saveState();
              }
            },
            child: TextFormField(
              autofocus: false,
              key: Key(
                  '${user.id}${user.dateStartOfEducation.toString()}${Random().nextInt(1024)}'),
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
        color: user.toPaint[1] ? Colors.teal[100] : Colors.transparent);
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
                  if (user.isMemorized) {
                    user.toPaint[i + 2] =
                        user.properties[i] != user.initUser.properties[i];
                  }
                  user.calculateResult();
                  setState(() {});
                },
                decoration: const InputDecoration(counterText: ""),
                maxLength: 12,
              )),
          width: i == months.length - 3 ? 220 : 100,
          height: 52,
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          alignment: Alignment.centerLeft,
          color: user.toPaint[i + 2] ? Colors.teal[100] : Colors.transparent);
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
          _cells['$i UDColumn'] = _getNumCell(user, i);
          break;
        case Types.text:
          _cells['$i UDColumn'] = _getStringCell(user, i);
          break;
        case Types.formula:
          _cells['$i UDColumn'] = _getFormulaCell(user, i, index);
          break;
      }
    }

    _cells['spacer'] = Container(
      child: const Text(''),
      width: 50,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );

    return Container(
      child: Row(children: _cells.values.toList()),
      color: () {
        if (!user.toPaint.contains(false)) return Colors.teal[100];
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
    initUser = User.allData(name, dateStartOfEducation, List.from(properties),
        result, status, toPaint);
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
        'toPaint': toPaint
      };

  factory User.fromJson(dynamic json) {
    User temp = User.allData(
        json['name'] as String,
        json['dateStartOfEducation'] == "null"
            ? null
            : DateTime.parse(json['dateStartOfEducation']),
        json['properties'],
        json['result'] as num,
        UserStatus.values[json['status']],
        json['toPaint'].cast<bool>());
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

  User.byName(this.name) {
    properties = List.filled(months.length, null, growable: true);
    toPaint = List.filled(months.length + 2, false, growable: true);
  }

  User.allData(this.name, this.dateStartOfEducation, this.properties,
      this.result, this.status, this.toPaint);

  User.toPaint(int numberOfUDColumns) {
    result = 0;
    name = '';
    dateStartOfEducation = null;
    properties =
        List.filled(months.length + numberOfUDColumns, null, growable: true);
    toPaint = List.filled(months.length + 2 + numberOfUDColumns, true,
        growable: true);
  }
}
