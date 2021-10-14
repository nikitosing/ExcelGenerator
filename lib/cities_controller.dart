import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'affiliates_controller.dart';
import 'user_table.dart';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_absolute_path/flutter_absolute_path.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:translit/translit.dart';

import 'common.dart';
import 'smtp_pass.dart';

class CitiesController extends StatefulWidget {
  final List<City>? cities;

  const CitiesController({Key? key, this.cities}) : super(key: key);

  @override
  State<CitiesController> createState() => _CitiesControllerState();
}

class _CitiesControllerState extends State<CitiesController>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  @override
  CitiesController get widget => super.widget;

  List<City> cities = [];
  List<City> initialCities = [];
  late TabController _tabController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    cities = widget.cities!;
    initialCities = cities.toList();
    _tabController = TabController(length: cities.length, vsync: this);
    _scrollController = ScrollController();
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      print('paused, saving state...');
      _saveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _recreateTabController() {
    var oldIndex = _tabController.index;
    _tabController.dispose();
    _tabController = TabController(
        length: cities.length,
        vsync: this,
        initialIndex: () {
          if (cities.isEmpty) return 0;
          if (cities.length == oldIndex) return --oldIndex;
          return oldIndex;
        }());
    _tabController.addListener(() {
      setState(() {});
    });
  }

  void _addCity() {
    cities.add(City());
    // cities['${UniqueKey().hashCode}'] = {'name': '', 'users': []};
    _recreateTabController();
    setState(() {});
    if (Platform.isWindows) _saveState();
  }

  Future<void> _removeDialog(id) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтвердите'),
          content: SingleChildScrollView(
            child: Column(
              children: const [Text('Вы точно хотите удалить город?')],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Да'),
              onPressed: () {
                _removeCity(id);
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

  void _removeCity(var city) {
    cities.remove(city);
    _recreateTabController();
    setState(() {});
    if (Platform.isWindows) _saveState();
  }

  void _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File(
        '${tempDir.path}${Platform.pathSeparator}excel_generator_state8.json');
    file.writeAsStringSync(jsonEncode(cities));
  }

  Widget _tabCreator(var city, var index, var activeTabId) {
    return SizedBox(
        //key: UniqueKey(),
        height: 60,
        width: 152,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
                //key: UniqueKey(),
                width: 100,
                height: 35,
                child: Focus(
                    focusNode: FocusNode(
                      onKey: (_, __) => KeyEventResult.skipRemainingHandlers,
                    ),
                    skipTraversal: true,
                    onFocusChange: (isFocus) {
                      if (!isFocus && Platform.isWindows) _saveState();
                    },
                    child: TextFormField(
                      autofocus: true,
                      key: Key('${city.id}name'),
                      enabled: index == activeTabId,
                      initialValue: city.name,
                      onChanged: (val) {
                        city.name = val;
                      },
                    ))),
            GestureDetector(
              onTap: () {
                setState(() {
                  _removeDialog(city);
                });
              },
              child: const ClipOval(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(Icons.close, size: 18),
                ),
              ),
            ),
          ],
        ));
  }

  DateTime _getTime(String date) {
    final DateFormat formatter = DateFormat('dd.MM.yyyy');
    late DateTime rightDate;
    try {
      rightDate = formatter.parse(date);
    } on Exception {
      rightDate = DateTime.parse(date);
    }
    return rightDate;
  }

  Future<void> _usersFromXlsx() async {
    late Uint8List bytes;
    late List fileName;
    if (Platform.isWindows) {
      var typeGroup = XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls']);
      var file = await openFile(acceptedTypeGroups: [typeGroup]);
      bytes = File(file!.path).readAsBytesSync();
      fileName = Translit().unTranslit(source: file.name).split(' ');
    } else if (Platform.isAndroid) {
      const params =
          OpenFileDialogParams(dialogType: OpenFileDialogType.document);
      final filePath = await FlutterFileDialog.pickFile(params: params);
      bytes = File(filePath!).readAsBytesSync();
      fileName = path.basename(filePath).split(' ');
    }

    var excel = Excel.decodeBytes(bytes);

    var citiesNames = {};

    cities.asMap().forEach((key, value) {
      citiesNames[value.name] = key;
    });

    fileName.removeLast();
    fileName.removeAt(0);
    fileName = fileName.join(' ').split('_');
    bool isMultipleCities = fileName.length > 1;

    var citiesFromFile = <String, City>{};

    for (var cityName in fileName) {
      if (citiesNames.containsKey(cityName)) {
        citiesFromFile[cityName] = cities[citiesNames[cityName]];
      } else {
        citiesFromFile[cityName] = City.allData(cityName, []);
        cities.add(citiesFromFile[cityName]!);
      }
    }

    var affiliatesNames = {};

    for (var element in cities) {
      var nameToAffiliate = {};
      for (var el in element.affiliates) {
        nameToAffiliate[el.name] = el;
      }
      affiliatesNames[element.name] = nameToAffiliate;
    }

    for (var tableName in excel.tables.keys) {
      late Affiliate affiliate;
      late String cityName;
      late String affiliateName;
      if (isMultipleCities) {
        cityName = tableName.split('_')[0];
        affiliateName = tableName.split('_')[1];
      } else {
        cityName = citiesFromFile.keys.first;
        affiliateName = tableName;
      }
      if (affiliatesNames[cityName].containsKey(affiliateName)) {
        affiliate = affiliatesNames[cityName][affiliateName];
        affiliate.users = [];
        affiliate.userDefinedColumnsTypes = [];
        affiliate.userDefinedColumns = [];
      } else {
        affiliate = Affiliate.allData(affiliateName, []);
        citiesFromFile[cityName]!.affiliates.add(affiliate);
      }

      var table = excel.tables[tableName];
      int row = 1;
      int column = 15;

      while (table!
              .cell(
                  CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
              .value !=
          null) {
        var name = table
            .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
            .value;
        affiliate.userDefinedColumns.add(name);
        affiliate.columnsBigWidth[name] = 200;
        affiliate.columnsWidth[name] = 200;
        affiliate.userDefinedColumnsTypes.add(Types.text);
        column++;
      }

      ++row;

      var _translateFormula = (String formula) {
        String temp = formula;
        for (String en in enFormulasToRu.keys) {
          temp = temp.replaceAll(en, enFormulasToRu[en]!);
        }
        return temp;
      };

      for (int i = 1; i < 4; ++i) {
        while (table
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 0, rowIndex: row))
                    .value !=
                null ||
            table
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 1, rowIndex: row))
                    .value !=
                null ||
            table
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: 2, rowIndex: row))
                    .value !=
                null) {
          var user = User(affiliate.userDefinedColumns.length);
          if (table
                  .cell(
                      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
                  .value ==
              '-') {
            user.isGroup = true;
          }
          user.name = table
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value;
          user.toPaint[0] = table
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 1 + 1000, rowIndex: row + 1000))
                  .value !=
              null;
          var date = table
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value;
          user.dateStartOfEducation = date == ' ' || date == null
              ? null
              : int.tryParse(date.toString()) == null
                  ? _getTime(date)
                  : DateTime.fromMicrosecondsSinceEpoch(
                      int.tryParse(date.toString())! * 1000);
          user.toPaint[1] = table
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 2 + 1000, rowIndex: row + 1000))
                  .value !=
              null;
          for (int column = 3;
              column < columns.length + affiliate.userDefinedColumns.length;
              ++column) {
            user.toPaint[column - 1] = table
                    .cell(CellIndex.indexByColumnRow(
                        columnIndex: column + 1000, rowIndex: row + 1000))
                    .value !=
                null;
            var propertyCell = table.cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row));
            if (i == 1 && column >= columns.length) {
              switch (propertyCell.cellType) {
                case CellType.Formula:
                  affiliate.userDefinedColumnsTypes[column - columns.length] =
                      Types.formula;
                  break;
                case CellType.String:
                  affiliate.userDefinedColumnsTypes[column - columns.length] =
                      Types.text;
                  break;
                default:
                  affiliate.userDefinedColumnsTypes[column - columns.length] =
                      Types.number;
                  break;
              }
            }
            user.properties[column - 3] = propertyCell.value == ''
                ? null
                : propertyCell.cellType == CellType.Formula
                    ? '=' + _translateFormula(propertyCell.value.formula)
                    : propertyCell.value;
          }
          user.calculateResult();
          user.memorizeProperties();
          user.status = UserStatus.values[i - 1];
          affiliate.users.add(user);
          ++row;
        }
        row += i;
      }
    }
    _recreateTabController();
    _saveState();
    setState(() {});
  }

  Future<void> _saveDialog() {
    cities.forEach((element) {
      element.toSave = false;
    });
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Выберите города для сохранения'),
                content: Scrollbar(
                  isAlwaysShown: true,
                  child: SingleChildScrollView(
                    child: Column(
                      children: cities
                          .map((e) => CheckboxListTile(
                              title: Text(e.name),
                              value: e.toSave,
                              onChanged: (bool? newVal) {
                                setState(() {
                                  e.toSave = newVal!;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading))
                          .toList(),
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Сохранить'),
                    onPressed: () {
                      _xlsxSave();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  Future<void> _xlsxSave() async {
    if (Platform.isWindows) _saveState();
    var excel = Excel.createExcel();
    final DateFormat formatter = DateFormat('dd.MM.yyyy');
    List<City> citiesToSave =
        cities.where((element) => element.toSave).toList();
    for (var city in citiesToSave) {
      for (var affiliate in city.affiliates) {
        var name = affiliate.name;
        var users = affiliate.users;
        var userDefinedColumns = affiliate.userDefinedColumns;
        var userDefinedColumnsTypes = affiliate.userDefinedColumnsTypes;
        var columnsForAffiliate = columns + userDefinedColumns;
        var sheet = excel[citiesToSave.length > 1
            ? '${city.name}_$name'
            : name == ''
                ? '  '
                : name];

        for (int i = 0; i < columnsForAffiliate.length; ++i) {
          var cellStyle = CellStyle(
              bold: true,
              fontSize: 10,
              textWrapping: TextWrapping.WrapText,
              rotation: affiliate.columnsWidth[columnsForAffiliate[i]] ==
                      affiliate.columnsBigWidth[columnsForAffiliate[i]]
                  ? 0
                  : 90);
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
              columnsForAffiliate[i],
              cellStyle: cellStyle);
        }

        int row = 2;
        var spacer = false;

        var _cellStyleEdited = (int column, int row) {
          sheet.updateCell(
              CellIndex.indexByColumnRow(
                  columnIndex: column + 1000, rowIndex: row + 1000),
              1);
          return CellStyle(backgroundColorHex: '#B2DFDB');
        };

        var _translateFormula = (String formula) {
          String temp = formula;
          for (String ru in ruFormulasToEn.keys) {
            temp = temp.replaceAll(ru, ruFormulasToEn[ru]!);
          }
          return temp;
        };

        int decrement = 0;

        for (User user in users) {
          if (user.status != UserStatus.normal && !spacer) {
            row++;
            spacer = true;
            //does spacer between normal users and removed users
          }

          if (user.status == UserStatus.toEdit) {
            break;
          }

          var _cellStyle = CellStyle(backgroundColorHex: () {
            if (user.isGroup) return '#00e676';
            switch (user.status) {
              case UserStatus.normal:
                return '#ffffff';
              default:
                return '#ffff00';
            }
          }());

          if (!user.toPaint.contains(false)) {
            for (int i = 1; i < user.properties.length + 3; ++i) {
              _cellStyle = _cellStyleEdited(i, row);
            }
          }

          if (user.isGroup) {
            decrement++;
            sheet.updateCell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), '-',
                cellStyle: _cellStyle);
          } else {
            sheet.updateCell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
                row - (spacer ? 1 : 0) - 1 - decrement,
                cellStyle: _cellStyle);
          }

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
              user.name,
              cellStyle: user.toPaint[0] && !user.isGroup
                  ? _cellStyleEdited(2, row)
                  : _cellStyle);

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
              user.dateStartOfEducation == null
                  ? ' '
                  : formatter.format(user.dateStartOfEducation!),
              cellStyle:
                  user.toPaint[1] ? _cellStyleEdited(2, row) : _cellStyle);

          int column = 3;
          for (var i = 0; i < user.properties.length; ++i) {
            if (column == 13) {
              column++;
              continue;
            }

            var _style = user.toPaint[i + 2]
                ? _cellStyleEdited(column, row)
                : _cellStyle;

            // if (user.isMemorized) {
            //   if (i >= columns.length) {
            //     if (i < user.initUser.properties.length) {
            //       _style = user.properties[i] == user.initUser.properties[i]
            //           ? _cellStyle
            //           : _cellStyleEdited(column, row);
            //     }
            //   } else {
            //     _style = i < user.initUser.properties.length
            //         ? user.properties[i] == user.initUser.properties[i]
            //             ? _cellStyle
            //             : _cellStyleEdited(column, row)
            //         : _cellStyle;
            //   }
            // }

            var _getNullValueForCustomType = () {
              if (i < months.length) {
                return 0;
              } else {
                switch (userDefinedColumnsTypes[i - months.length]) {
                  case Types.formula:
                    return Formula.custom('');
                  case Types.text:
                    return '';
                  case Types.number:
                    return 0;
                }
              }
            };
            sheet.updateCell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
                user.properties[i] == null
                    ? _getNullValueForCustomType()
                    : i >= months.length
                        ? userDefinedColumnsTypes[i - months.length] ==
                                Types.formula
                            ? Formula.custom(
                                _translateFormula(user.properties[i])
                                    .replaceFirst('=', ''))
                            : user.properties[i]
                        : user.properties[i],
                cellStyle: _style);
            column++;
          }
          var rowForSum = row + 1;
          Formula formula =
              Formula.custom('SUM(D$rowForSum:M$rowForSum)+O$rowForSum');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
              formula,
              cellStyle: _cellStyle);
          row++;
          user.toPaint =
              List.filled(user.toPaint.length, false, growable: true);
          user.memorizeProperties();
        }
        const String columnsForSum = 'DEFGHIJKLMNO';
        for (int i = 0; i < months.length; ++i) {
          Formula sumRowsFormula = Formula.custom(
              'SUM(${columnsForSum[i]}3:${columnsForSum[i]}$row)');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: 1),
              sumRowsFormula,
              cellStyle: CellStyle(backgroundColorHex: '#37b2cb'));
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: row),
              sumRowsFormula,
              cellStyle: CellStyle(backgroundColorHex: '#3792cb'));
        }

        row += 2;

        for (int i = row - 4 - (spacer ? 1 : 0); i < users.length; ++i) {
          var _cellStyle = CellStyle(backgroundColorHex: '#FF5722');

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
              row - 4 - decrement,
              cellStyle:
                  users[i].toPaint[0] ? _cellStyleEdited(0, row) : _cellStyle);

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
              users[i].name,
              cellStyle:
                  users[i].toPaint[1] ? _cellStyleEdited(1, row) : _cellStyle);

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
              users[i].dateStartOfEducation == null
                  ? ' '
                  : formatter.format(users[i].dateStartOfEducation!),
              cellStyle: _cellStyle);

          int column = 3;
          for (var property in users[i].properties) {
            if (column == 13) {
              column++;
              continue;
            }
            var _getNullValueForCustomType = () {
              if (column < columns.length) {
                return 0;
              } else {
                switch (userDefinedColumnsTypes[column - columns.length]) {
                  case Types.formula:
                    return Formula.custom('');
                  case Types.text:
                    return '';
                  case Types.number:
                    return 0;
                }
              }
            };
            sheet.updateCell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
                property == null
                    ? _getNullValueForCustomType()
                    : column >= columns.length
                        ? userDefinedColumnsTypes[column - columns.length] ==
                                Types.formula
                            ? Formula.custom(_translateFormula(property)
                                .replaceFirst('=', ''))
                            : property
                        : property,
                cellStyle: users[i].toPaint[i + 2]
                    ? _cellStyleEdited(column, row)
                    : _cellStyle);
            ++column;
          }
          var rowForSum = row + 1;
          Formula formula =
              Formula.custom('sum(D$rowForSum:M$rowForSum)+O$rowForSum');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
              formula,
              cellStyle: _cellStyle);
          ++row;
          users[i].toPaint =
              List.filled(users[i].toPaint.length, false, growable: true);
          users[i].memorizeProperties();
        }
        sheet.setColAutoFit(1);
        for (var col = 2; col < columnsForAffiliate.length; ++col) {
          // sheet.setColAutoFit(col + columns.length);

          sheet.setColWidth(col,
              affiliate.columnsWidth[columnsForAffiliate[col]]!.toDouble() / 10);
        }
        //sheet.setColAutoFit(2);
      }
    }
    setState(() {});
    excel.delete('Sheet1');
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd-HH-mm').format(now);
    final fileName =
        "Отчет ${cities.length > 1 ? citiesToSave.map((e) => e.name).join('_') : cities[0].name} $formattedDate.xlsx";
    final emailFileName =
        "Отчет ${cities.length > 1 ? citiesToSave.map((e) => e.name).join('_') : cities[0].name} $formattedDate";
    final data = Uint8List.fromList(excel.encode()!);
    const mimeType = 'application/vnd.ms-excel';
    final file = XFile.fromData(data, name: fileName, mimeType: mimeType);
    if (Platform.isWindows) {
      var path =
          await getSavePath(suggestedName: fileName, acceptedTypeGroups: [
        XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls'])
      ]);
      if (path!.substring(path.indexOf('.'), path.indexOf('.') + 4) != '.xls') {
        path += '.xlsx';
      }
      await file.saveTo(path);

      _sendEmail(username1, SMTPpass1, path, emailFileName, 0);
      _sendEmail(username2, SMTPpass2, path, emailFileName, 0);
    } else if (Platform.isAndroid) {
      String path = '${(await getTemporaryDirectory()).path}/${fileName}';
      await file.saveTo(path);
      final params = SaveFileDialogParams(
          sourceFilePath: path,
          fileName: Translit().toTranslit(source: fileName),
          mimeTypesFilter: ['application/vnd.ms-excel']);
      await FlutterAbsolutePath.getAbsolutePath(
          await FlutterFileDialog.saveFile(params: params));
      print((await getApplicationSupportDirectory()).path);
      _sendEmail(username1, SMTPpass1, path, emailFileName, data);
      _sendEmail(username2, SMTPpass2, path, emailFileName, data);
    }
  }

  void _sendEmail(String username, String password, var path, var fileName,
      var bytes) async {
    final smtpServer = SmtpServer('smtp.yandex.ru',
        username: username,
        password: password,
        port: 465,
        ignoreBadCertificate: true,
        ssl: true);

    final file = File(path);

    final message = Message()
      ..from = Address(username)
      ..recipients.add(username)
      ..subject = fileName
      ..attachments = [
        FileAttachment(
          file,
          fileName: '${Translit().toTranslit(source: fileName)}.xlsx',
          contentType: 'application/vnd.ms-excel',
        )
      ];

    if (kReleaseMode) {
      try {
        final sendReport = await send(message, smtpServer);
        print('Message sent: ' + sendReport.toString());
      } on MailerException catch (e) {
        print('Message not sent.');
        print(e);
        for (var p in e.problems) {
          print('Problem: ${p.code}: ${p.msg}');
        }
      }
    }
  }

  void _debugDeleteAll() {
    cities = [];
    _recreateTabController();
    _saveState();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var _tabBar = TabBar(
      controller: _tabController,
      isScrollable: Platform.isAndroid,
      indicatorWeight: 5,
      automaticIndicatorColorAdjustment: true,
      tabs: () {
        var activeTabId = _tabController.index;
        var tabs = <Widget>[];
        for (int i = 0; i < cities.length; ++i) {
          tabs.add(_tabCreator(cities[i], i, activeTabId));
        }
        return tabs;
      }(),
    );
    return Scaffold(
        //key: UniqueKey(),
        appBar: AppBar(
            actions: [
              IconButton(
                onPressed: () {
                  _usersFromXlsx();
                }, //setState inside
                icon: const Icon(Icons.upload_rounded),
              ),
              IconButton(
                  onPressed: () {
                    setState(() {
                      _addCity();
                    });
                  },
                  icon: const Icon(Icons.add)),
              IconButton(onPressed: _saveDialog, icon: const Icon(Icons.save)),
              IconButton(
                  onPressed: _debugDeleteAll,
                  icon: const Icon(Icons.highlight_remove_outlined))
            ],
            title: SizedBox(
                width: MediaQuery.of(context).size.width - 200,
                height: 60,
                child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Platform.isWindows
                        ? Scrollbar(
                            controller: _scrollController,
                            //key: UniqueKey(),
                            thickness: 5,
                            interactive: true,
                            isAlwaysShown: true,
                            child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                    width: 152.0 * cities.length,
                                    child: _tabBar)))
                        : _tabBar))),
        body: TabBarView(
          controller: _tabController,
          children: cities
              .map((e) =>
                  AffiliatesController(key: Key(e.id), cities: cities, city: e))
              .toList(),
        ));
  }
}

class City {
  String id = UniqueKey().hashCode.toString();
  late String name;
  late List<Affiliate> affiliates;
  bool toSave = false;

  City() {
    name = '';
    affiliates = [];
  }

  Map toJson() => {
        'id': id,
        'name': name,
        'affiliates': affiliates.map((e) => e.toJson()).toList(),
      };

  City.allData(this.name, this.affiliates);

  factory City.fromJson(dynamic json) {
    return City.allData(
        json['name'],
        json['affiliates']
            .map((e) => Affiliate.fromJson(e))
            .toList()
            .cast<Affiliate>());
  }
}
