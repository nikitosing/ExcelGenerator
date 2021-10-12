import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:collection/collection.dart';
import 'package:excel/excel.dart';
import 'affiliates_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart'
    hide Column, Row, Alignment, Stack, Border;

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
  var columnsBigWidth = <String, int>{};
  var columnsWidth = <String, int>{};
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
    columnsBigWidth = affiliate.columnsBigWidth;
    columnsWidth = affiliate.columnsWidth;

    for (var user in users) {
      if (user.status == UserStatus.toEdit ||
          user.status == UserStatus.toRemove) {
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
        '${tempDir.path}${Platform.pathSeparator}excel_generator_state8.json');
    file.writeAsStringSync(jsonEncode(cities));
  }

  int numberOfRowInExcel(int index, User user) {
    int numberOfRowInExcel = index +
        3 +
        user.status.index +
        (user.status == UserStatus.toEdit ? 1 : 0);
    return numberOfRowInExcel;
  }

  void wrapColumn(String name) {
    if (columnsWidth[name] == columnsBigWidth[name]) {
      columnsWidth[name] = 50;
    } else {
      columnsWidth[name] = columnsBigWidth[name]!;
    }
  }

  void _sortUsers() {
    users.sort((a, b) {
      return (a.status.index % 3) - (b.status.index % 3);
    });
    users.asMap().forEach((index, element) {
      for (int i = 0; i < userDefinedColumnsTypes.length; ++i) {
        if (userDefinedColumnsTypes[i] == Types.formula) {
          int rowOfUser = numberOfRowInExcel(index, element);
          if (element.properties[i + months.length] != null) {
            var formulaReadyToEdit =
                element.properties[i + months.length].split(regexp);
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

  void _moveToPrevGroup(int usrIndex) {
    while (usrIndex > 0 && !users[usrIndex - 1].isGroup && _moveUp(usrIndex--));
    _moveUp(usrIndex);
  }

  bool _moveUp(int usrIndex) {
    if (usrIndex > 0) {
      var temp = users[usrIndex];
      users[usrIndex] = users[usrIndex - 1];
      users[usrIndex - 1] = temp;
      for (int index in [usrIndex - 1, usrIndex]) {
        for (int i = 0; i < userDefinedColumnsTypes.length; ++i) {
          if (userDefinedColumnsTypes[i] == Types.formula) {
            int rowOfUser = numberOfRowInExcel(index, users[index]);
            if (users[index].properties[i + months.length] != null) {
              var formulaReadyToEdit =
                  users[index].properties[i + months.length].split(regexp);
              if (formulaReadyToEdit != null) {
                users[index].properties[i + months.length] =
                    formulaReadyToEdit.join('$rowOfUser');
              }
            }
          }
        }
      }
      return true;
    }
    return false;
  }

  bool _moveDown(int usrIndex) {
    if (usrIndex < users.length &&
        users[usrIndex + 1].status == UserStatus.normal) {
      var temp = users[usrIndex];
      users[usrIndex] = users[usrIndex + 1];
      users[usrIndex + 1] = temp;
      for (int index in [usrIndex + 1, usrIndex]) {
        for (int i = 0; i < userDefinedColumnsTypes.length; ++i) {
          if (userDefinedColumnsTypes[i] == Types.formula) {
            int rowOfUser = numberOfRowInExcel(index, users[index]);
            if (users[index].properties[i + months.length] != null) {
              var formulaReadyToEdit =
              users[index].properties[i + months.length].split(regexp);
              if (formulaReadyToEdit != null) {
                users[index].properties[i + months.length] =
                    formulaReadyToEdit.join('$rowOfUser');
              }
            }
          }
        }
      }
      return true;
    }
    return false;
  }

  void _moveToNextGroup(int usrIndex) {
    while (usrIndex < users.length &&
        !users[usrIndex + 1].isGroup &&
        _moveDown(usrIndex++));
    _moveDown(usrIndex);
  }

  void _addUser() {
    if (users.length == numberOfDeletedUsers ||
        users[users.length - 1 - numberOfDeletedUsers].isGroup ||
        (users[users.length - 1 - numberOfDeletedUsers].name != '' &&
            users[users.length - 1 - numberOfDeletedUsers]
                    .dateStartOfEducation !=
                null)) {
      users.add(User.toPaint(userDefinedColumns.length));
      _sortUsers();
    }
    if (Platform.isWindows) _saveState();
  }

  void _addGroup() {
    User group = User(userDefinedColumns.length);
    group.isGroup = true;
    users.add(group);
    _sortUsers();
    if (Platform.isWindows) _saveState();
  }

  String calculateFormulas(User user, int indexOfFormula, int indexOfUser) {
    String translatedFormula = user.properties[indexOfFormula + months.length];
    for (String frml in ruFormulasToEn.keys) {
      translatedFormula =
          translatedFormula.replaceAll(frml, ruFormulasToEn[frml]!);
    }
    translatedFormula = translatedFormula.split(regexp).join(('1'));
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
          ws.getRangeByIndex(1, column).number =
              property == null ? 0 : property.toDouble();
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
          translatedFormula = translatedFormula.split(regexp).join(('1'));
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
                        property = property.split(regexp);
                      }
                      userDefinedColumns.add(name);
                      affiliate.columnsBigWidth[name] = 200;
                      affiliate.columnsWidth[name] = 200;
                      affiliate.userDefinedColumnsTypes.add(chosen);
                      users.asMap().forEach((index, element) {
                        element.properties.add(property !=
                                null // means that chosen is formula and has some formula in its name
                            ? property.join(
                                '${index + 3 + element.status.index + (element.status == UserStatus.toEdit ? 1 : 0)}')
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
                columnsWidth.remove(userDefinedColumns[index]);
                columnsBigWidth.remove(userDefinedColumns[index]);
                userDefinedColumns.removeAt(index);
                userDefinedColumnsTypes.removeAt(index);
                for (var element in users) {
                  element.properties.removeAt(months.length + index);
                  element.toPaint.removeAt(months.length + index + 2);
                }
                if (Platform.isWindows) _saveState();
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
        Container(
            height: 104,
            alignment: Alignment.bottomLeft,
            child: Container(
                width: min(MediaQuery.of(context).size.width - 150, 500),
                height: 85,
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
                  max: min(MediaQuery.of(context).size.width - 150, 500),
                  min: 0,
                  onDragging: (handlerIndex, lowerValue, upperValue) {
                    _nameColumnWidth = lowerValue < 45 ? 45 : lowerValue;
                    setState(() {});
                  },
                )))
      ]),
      floatingActionButton: SpeedDial(
        //Speed dial menu
        icon: Icons.add,
        //icon on Floating action button
        activeIcon: Icons.close,
        //icon when menu is expanded on button
        renderOverlay: true,
        closeManually: false,
        spaceBetweenChildren: 10,
        shape: CircleBorder(),
        //shape of button
        children: [
          SpeedDialChild(
            //speed dial child
            child: Icon(Icons.person),
            //backgroundColor: Colors.red,
            //foregroundColor: Colors.white,
            label: 'Добавить ученика',
            labelStyle: TextStyle(fontSize: 15.0),
            onTap: () {
              setState(() {
                _addUser();
              });
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.group),
            //backgroundColor: Colors.blue,
            //foregroundColor: Colors.white,
            label: 'Добавить группу',
            labelStyle: TextStyle(fontSize: 15.0),
            onTap: () {
              setState(() {
                _addGroup();
              });
            },
          ),
        ],
      ),
    );
  }

  double _getWidthOfRhsTable() {
    return columnsWidth.values.sum + 200;
  }

  Widget _getBodyWidget() {
    return SizedBox(
      //key: UniqueKey(),
      child: HorizontalDataTable(
          leftHandSideColBackgroundColor: const Color(0xFAFAFA),
          rightHandSideColBackgroundColor: const Color(0xFAFAFA),
          leftHandSideColumnWidth: _nameColumnWidth,
          rightHandSideColumnWidth: _getWidthOfRhsTable(),
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

  Container _getNumCell(User user, int index, double width) {
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
                  user.toPaint[index + months.length + 2] =
                      user.properties[index + months.length] !=
                          user.initUser.properties[index + months.length];
                }
                setState(() {});
              },
              maxLength: 12,
              textAlignVertical: TextAlignVertical.bottom,
              decoration: user.toPaint[index + 2 + months.length]
                  ? InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 42, minWidth: 10),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 10,
                      ),
                      counterText: "")
                  : InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 0, minWidth: 0),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 0,
                      ),
                      counterText: ""))),
      width: width,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
      alignment: Alignment.bottomLeft,
    );
  }

  Container _getStringCell(User user, int index, double width) {
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
              initialValue:
                  (user.properties[index + months.length] ?? '').toString(),
              onChanged: (val) {
                user.properties[index + months.length] = val;
                if (user.isMemorized) {
                  if (index + months.length >=
                      user.initUser.properties.length) {
                    user.toPaint[index + months.length + 2] = true;
                  } else {
                    user.toPaint[index + months.length + 2] =
                        user.properties[index + months.length] !=
                            user.initUser.properties[index + months.length];
                  }
                }
                setState(() {});
              },
              maxLength: 60,
              textAlignVertical: TextAlignVertical.bottom,
              decoration: user.toPaint[index + 2 + months.length]
                  ? InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 42, minWidth: 10),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 10,
                      ),
                      counterText: "")
                  : InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 0, minWidth: 0),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 0,
                      ),
                      counterText: ""))),
      width: width,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
      alignment: Alignment.bottomLeft,
    );
  }

  Container _getFormulaCell(
      User user, int index, int indexOfUser, double width) {
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
                  user.toPaint[index + months.length + 2] =
                      user.properties[index + months.length] !=
                          user.initUser.properties[index + months.length];
                }
                setState(() {});
              },
              maxLength: 60,
              textAlignVertical: TextAlignVertical.bottom,
              decoration: user.toPaint[index + 2 + months.length]
                  ? InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 42, minWidth: 10),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 10,
                      ),
                      counterText: "")
                  : InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 0, minWidth: 0),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 0,
                      ),
                      counterText: ""))),
      width: width,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
      alignment: Alignment.bottomLeft,
    );
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
        child: Column(children: [
          Stack(children: [
            Align(alignment: Alignment.topCenter, child: Text('C')),
            Align(
                alignment: Alignment.topRight,
                child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    width: 20,
                    height: 20,
                    child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: () {
                          wrapColumn('Дата начала занятий');
                          setState(() {});
                        },
                        child: Icon(
                          columnsWidth['Дата начала занятий'] ==
                                  columnsBigWidth['Дата начала занятий']
                              ? Icons.remove
                              : Icons.add,
                          size: 18,
                        ))))
          ]),
          Text('Дата начала занятий',
              overflow: TextOverflow.clip,
              maxLines: 3,
              style: _columnTextStyle,
              textAlign: TextAlign.center)
        ]),
        width: columnsWidth['Дата начала занятий']!.toDouble(),
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
              Stack(children: [
                Align(
                    alignment: Alignment.topCenter,
                    child: Text(String.fromCharCode(i + 68))),
                Align(
                    alignment: Alignment.topRight,
                    child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        width: 20,
                        height: 20,
                        child: InkWell(
                            customBorder: CircleBorder(),
                            onTap: () {
                              wrapColumn(columns[i + 3]);
                              setState(() {});
                            },
                            child: Icon(
                              columnsWidth[columns[i + 3]] ==
                                      columnsBigWidth[columns[i + 3]]
                                  ? Icons.remove
                                  : Icons.add,
                              size: 18,
                            ))))
              ]),
              Expanded(
                  child: Text(columns[i + 3],
                      style: _columnTextStyle, textAlign: TextAlign.center)),
              Expanded(
                  child: Text(_sum.toStringAsFixed(2),
                      textAlign: TextAlign.center, style: _columnTextStyle))
            ],
          ),
          width: columnsWidth[columns[i + 3]]!.toDouble(),
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
    _columns.add(Container(
        child: const Text(''),
        width: 50,
        height: 104,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    for (var i = 0; i < userDefinedColumns.length; ++i) {
      _columns.add(Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(children: [
                Align(
                    alignment: Alignment.topCenter,
                    child: Text(_getLetterForColumn(i))),
                Align(
                    alignment: Alignment.topRight,
                    child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        width: 20,
                        height: 20,
                        child: InkWell(
                            customBorder: CircleBorder(),
                            onTap: () {
                              wrapColumn(userDefinedColumns[i]);
                              setState(() {});
                            },
                            child: Icon(
                              columnsWidth[userDefinedColumns[i]] ==
                                      columnsBigWidth[userDefinedColumns[i]]
                                  ? Icons.remove
                                  : Icons.add,
                              size: 18,
                            ))))
              ]),
              Stack(children: [
                Align(
                    alignment: columnsWidth[userDefinedColumns[i]] ==
                            columnsBigWidth[userDefinedColumns[i]]
                        ? Alignment.topCenter
                        : Alignment.center,
                    heightFactor: 2.5,
                    child: Text(userDefinedColumns[i],
                        maxLines: 1,
                        style: _columnTextStyle,
                        textAlign: TextAlign.center)),
                Align(
                    alignment: Alignment.topRight,
                    child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        width: 30,
                        height: 30,
                        child: InkWell(
                            customBorder: CircleBorder(),
                            onTap: () async {
                              await _removeColumn(i);
                              setState(() {});
                            },
                            child: Icon(
                              Icons.close,
                              size: 24,
                            ))))
              ]),
            ],
          ),
          width: columnsWidth[userDefinedColumns[i]]!.toDouble(),
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
          Text(numberOfRowInExcel(index, user).toString()),
          Focus(
              skipTraversal: true,
              onFocusChange: (isFocus) {
                if (!isFocus && Platform.isWindows) _saveState();
              },
              child: Container(
                child: TextFormField(
                  key: Key('${user.id}name'),
                  readOnly: user.status == UserStatus.toRemove ||
                      user.status == UserStatus.toEdit,
                  initialValue: user.name,
                  inputFormatters: !user.isGroup
                      ? [FilteringTextInputFormatter.deny(RegExp("[0-9]+"))]
                      : [],
                  // ^(\d*\.)?\d+$
                  autofocus: true,
                  maxLength: 60,
                  keyboardType: TextInputType.text,
                  onChanged: (val) {
                    user.name = val;
                    if (user.isMemorized) {
                      user.toPaint[0] = user.name != user.initUser.name;
                    }
                    setState(() {});
                  },
                  textAlignVertical: TextAlignVertical.bottom,
                  decoration: user.toPaint[0]
                      ? InputDecoration(
                          hintText: "Введите Ф.И",
                          isDense: true,
                          suffixIconConstraints:
                              BoxConstraints(minHeight: 42, minWidth: 10),
                          suffixIcon: Icon(
                            Icons.brightness_1_rounded,
                            size: 10,
                          ),
                          counterText: "")
                      : InputDecoration(
                          hintText:
                              user.isGroup ? "Название группы" : "Введите Ф.И",
                          isDense: true,
                          suffixIconConstraints:
                              BoxConstraints(minHeight: 0, minWidth: 0),
                          suffixIcon: Icon(
                            Icons.brightness_1_rounded,
                            size: 0,
                          ),
                          counterText: ""),
                ),
                width: _nameColumnWidth - 23,
                height: 52,
                alignment: Alignment.bottomLeft,
              ))
        ],
      ),
      width: _nameColumnWidth,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
      alignment: Alignment.bottomLeft,
      color: () {
        if (user.isGroup) return Colors.greenAccent[400];
        switch (user.status) {
          case UserStatus.normal:
            return Colors.transparent;
          case UserStatus.toEdit:
            return Colors.deepOrange[400];
          case UserStatus.toRemove:
            return Colors.yellow[400];
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
            textAlignVertical: TextAlignVertical.bottom,
            decoration: user.toPaint[1]
                ? InputDecoration(
                    hintText: "Выберите дату",
                    isDense: true,
                    suffixIconConstraints:
                        BoxConstraints(minHeight: 42, minWidth: 10),
                    suffixIcon: Icon(
                      Icons.brightness_1_rounded,
                      size: 10,
                    ),
                    counterText: "")
                : InputDecoration(
                    hintText: "Выберите дату",
                    isDense: true,
                    suffixIconConstraints:
                        BoxConstraints(minHeight: 0, minWidth: 0),
                    suffixIcon: Icon(
                      Icons.brightness_1_rounded,
                      size: 0,
                    ),
                    counterText: ""),
            keyboardType: null,
          )),
      width: columnsWidth['Дата начала занятий']!.toDouble(),
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
      alignment: Alignment.bottomLeft,
    );

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
              maxLength: 12,
              textAlignVertical: TextAlignVertical.bottom,
              decoration: user.toPaint[i + 2]
                  ? InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 42, minWidth: 10),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 10,
                      ),
                      counterText: "")
                  : InputDecoration(
                      isDense: true,
                      suffixIconConstraints:
                          BoxConstraints(minHeight: 0, minWidth: 0),
                      suffixIcon: Icon(
                        Icons.brightness_1_rounded,
                        size: 0,
                      ),
                      counterText: ""),
            )),
        width: columnsWidth[months[i]]!.toDouble(),
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
        alignment: Alignment.bottomLeft,
      );
    }

    _cells['Итого'] = Container(
      child: Text(user.result.toStringAsFixed(2)),
      width: columnsWidth['Итого']!.toDouble(),
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );

    _cells['moving'] = Container(
      child: Column(
        children: [
          GestureDetector(
            onSecondaryTap: () {
              if (user.status == UserStatus.normal) {
                setState(() {
                  _moveToPrevGroup(index);
                });
                if (Platform.isWindows) _saveState();
              }
            },
            onLongPress: () {
              if (user.status == UserStatus.normal) {
                setState(() {
                  _moveToPrevGroup(index);
                });
                if (Platform.isWindows) _saveState();
              }
            },
            child: ClipOval(
              child: SizedBox(
                width: 50,
                height: 26,
                child: IconButton(
                  icon: Icon(Icons.keyboard_arrow_up, size: 18),
                  splashRadius: 20,
                  onPressed: () {
                    if (user.status == UserStatus.normal) {
                      setState(() {
                        _moveUp(index);
                      });
                      if (Platform.isWindows) _saveState();
                    }
                  },
                ),
              ),
            ),
          ),
          GestureDetector(
            onSecondaryTap: () {
              if (user.status == UserStatus.normal) {
                setState(() {
                  _moveToNextGroup(index);
                });
                if (Platform.isWindows) _saveState();
              }
            },
            onLongPress: () {
              if (user.status == UserStatus.normal) {
                setState(() {
                  _moveToNextGroup(index);
                });
                if (Platform.isWindows) _saveState();
              }
            },
            child: ClipOval(
              child: SizedBox(
                width: 50,
                height: 26,
                child: IconButton(
                  icon: Icon(Icons.keyboard_arrow_down, size: 18),
                  splashRadius: 20,
                  onPressed: () {
                    if (user.status == UserStatus.normal) {
                      setState(() {
                        _moveDown(index);
                      });
                      if (Platform.isWindows) _saveState();
                    }
                  },
                  disabledColor: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      width: 50,
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
          _cells['$i UDColumn'] = _getNumCell(
              user, i, columnsWidth[userDefinedColumns[i]]!.toDouble());
          break;
        case Types.text:
          _cells['$i UDColumn'] = _getStringCell(
              user, i, columnsWidth[userDefinedColumns[i]]!.toDouble());
          break;
        case Types.formula:
          _cells['$i UDColumn'] = _getFormulaCell(
              user, i, index, columnsWidth[userDefinedColumns[i]]!.toDouble());
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

    return user.isGroup
        ? Container(
            height: 52,
            width: _getWidthOfRhsTable(),
            color: Colors.greenAccent[400])
        : Container(
            child: Row(children: _cells.values.toList()),
            color: () {
              switch (user.status) {
                case UserStatus.normal:
                  return Colors.transparent;
                case UserStatus.toEdit:
                  return Colors.deepOrange[400];
                case UserStatus.toRemove:
                  return Colors.yellow[400];
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
  bool isGroup = false;

  void memorizeProperties() {
    initUser = User.allData(name, dateStartOfEducation, List.from(properties),
        result, status, toPaint, isGroup);
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
        'toPaint': toPaint,
        'isGroup': isGroup
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
        json['toPaint'].cast<bool>(),
        json['isGroup']);
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
      this.result, this.status, this.toPaint, this.isGroup);

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
