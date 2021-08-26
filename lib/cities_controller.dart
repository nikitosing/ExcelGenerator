import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:excel_generator/affiliates_controller.dart';
import 'package:excel_generator/user_table.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:mailer/mailer.dart';
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
    var file = File('${tempDir.path}\\excel_generator_state6.json');
    file.writeAsStringSync(jsonEncode(cities));
  }

  Widget _tabCreator(var city, var index, var activeTabId) {
    return SizedBox(
        height: 60,
        width: 152,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
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
                      key: UniqueKey(),
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
      fileName = file.name.split(' ');
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
      citiesNames['${value.name}'] = key;
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

    cities.forEach((element) {
      var nameToAffiliate = {};
      element.affiliates.forEach((el) {
        nameToAffiliate[el.name] = el;
      });
      affiliatesNames[element.name] = nameToAffiliate;
    });

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
        affiliate.userDefinedColumns.add(table
            .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
            .value);
        affiliate.userDefinedColumnsTypes.add(Types.text);
        column++;
      }

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
          user.name = table
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value;
          var date = table
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value;
          user.dateStartOfEducation = date == null
              ? null
              : int.tryParse(date.toString()) == null
                  ? _getTime(date)
                  : DateTime.fromMicrosecondsSinceEpoch(
                      int.tryParse(date.toString())! * 1000);
          for (int column = 3;
              column < columns.length + affiliate.userDefinedColumns.length;
              ++column) {
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
                    ? propertyCell.value.formula
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
              bold: true, fontSize: 10, textWrapping: TextWrapping.WrapText);
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
              columnsForAffiliate[i],
              cellStyle: cellStyle);
        }

        int row = 1;
        var spacer = false;
        var _cellStyleEdited = CellStyle(backgroundColorHex: '#FFFF00');
        for (User user in users) {
          if (user.status != UserStatus.normal && !spacer) {
            row++;
            spacer = true;
            //does spacer between normal users and removed users
          }

          if (user.status == UserStatus.toEdit) {
            break;
          }

          var _cellStyle = CellStyle(
              backgroundColorHex:
                  user.status == UserStatus.normal ? '#ffffff' : '#FFFF00');

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
              row - (spacer ? 1 : 0),
              cellStyle: _cellStyle);

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
              user.name,
              cellStyle: user.isMemorized
                  ? user.name == user.initUser.name
                      ? _cellStyle
                      : _cellStyleEdited
                  : _cellStyle);

          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
              user.dateStartOfEducation == null
                  ? null
                  : formatter.format(user.dateStartOfEducation!),
              cellStyle: user.isMemorized
                  ? user.dateStartOfEducation ==
                          user.initUser.dateStartOfEducation
                      ? _cellStyle
                      : _cellStyleEdited
                  : _cellStyle);

          int column = 3;
          for (var i = 0; i < user.properties.length; ++i) {
            if (column == 13) {
              column++;
              continue;
            }
            var _style = _cellStyle;
            if (user.isMemorized) {
              if (i >= columns.length) {
                if (i < user.initUser.properties.length) {
                  _style = user.properties[i] == user.initUser.properties[i]
                      ? _cellStyle
                      : _cellStyleEdited;
                }
              } else {
                _style = i < user.initUser.properties.length
                    ? user.properties[i] == user.initUser.properties[i]
                        ? _cellStyle
                        : _cellStyleEdited
                    : _cellStyle;
              }
            }
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
                            ? Formula.custom(user.properties[i])
                            : user.properties[i]
                        : user.properties[i],
                cellStyle: _style);
            column++;
          }
          var rowForSum = row + 1;
          Formula formula =
              Formula.custom('=SUM(D$rowForSum:M$rowForSum)+O$rowForSum');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
              formula,
              cellStyle: _cellStyle);
          row++;
        }
        const String columnsForSum = 'DEFGHIJKLMNO';
        for (int i = 0; i < months.length; ++i) {
          Formula sumRowsFormula = Formula.custom(
              '=SUM(${columnsForSum[i]}2:${columnsForSum[i]}$row)');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: row),
              sumRowsFormula,
              cellStyle: CellStyle(backgroundColorHex: '#3792cb'));
        }

        row += 2;

        for (int i = row - 3 - (spacer ? 1 : 0); i < users.length; ++i) {
          var _cellStyle = CellStyle(backgroundColorHex: '#FF5722');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
              row - 2 - (spacer ? 1 : 0),
              cellStyle: _cellStyle);
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
              users[i].name,
              cellStyle: _cellStyle);
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
              users[i].dateStartOfEducation == null
                  ? null
                  : formatter.format(users[i].dateStartOfEducation!),
              cellStyle: _cellStyle);
          int column = 3;
          for (var property in users[i].properties) {
            if (column == 13) {
              column++;
              continue;
            }
            var _getNullValueForCustomType = () {
              if (column - 1 < months.length) {
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
                    ? column > columns.length
                        ? _getNullValueForCustomType()
                        : 0
                    : property,
                cellStyle: _cellStyle);
            column++;
          }
          var rowForSum = row + 1;
          Formula formula =
              Formula.custom('=SUM(D$rowForSum:M$rowForSum)+O$rowForSum');
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
              formula,
              cellStyle: _cellStyle);
          ++row;
        }
        sheet.setColAutoFit(1);
        sheet.setColWidth(2, 15);
        for (var col = 0; col < userDefinedColumns.length; ++col) {
          sheet.setColAutoFit(col + columns.length);
        }
        //sheet.setColAutoFit(2);
      }
    }
    excel.delete('Sheet1');
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd-HH-mm').format(now);
    final fileName =
        "Отчет ${cities.length > 1 ? citiesToSave.map((e) => e.name).join('_') : cities[0].name} $formattedDate.xlsx";
    final emailFileName =
        "Отчет ${cities.length > 1 ? citiesToSave.map((e) => e.name).join('_') : cities[0].name} $formattedDate";
    final data = Uint8List.fromList(excel.encode()!);
    if (Platform.isWindows) {
      var path =
          await getSavePath(suggestedName: fileName, acceptedTypeGroups: [
        XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls'])
      ]);
      const mimeType = 'application/vnd.ms-excel';
      final file = XFile.fromData(data, name: fileName);
      if (path!.substring(path.indexOf('.'), path.indexOf('.') + 4) != '.xls') {
        path += '.xlsx';
      }
      await file.saveTo(path);
      //_sendEmail(path, emailFileName);
    } else if (Platform.isAndroid) {
      final params = SaveFileDialogParams(data: data, fileName: fileName);
      final filePath = await FlutterFileDialog.saveFile(params: params);
      //_sendEmail(filePath, emailFileName);
    }
  }

  void _sendEmail(var path, var fileName) async {
    String username = 'excelgenerator@mail.ru';
    String password = SMTPpass;

    final smtpServer = SmtpServer('smtp.mail.ru',
        username: username,
        password: password,
        port: 465,
        ignoreBadCertificate: true,
        ssl: true);

    final message = Message()
      ..from = Address(username)
      ..recipients.add('chudoreportsbackup@mail.ru')
      ..recipients.add('chudoreports@mail.ru')
      ..subject = fileName
      ..attachments = [
        FileAttachment(File(path),
            contentType: 'application/vnd.ms-excel',
            fileName: Translit()
                .toTranslit(source: path.split(Platform.pathSeparator).last))
          ..location = Location.attachment
      ];

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
                            key: UniqueKey(),
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
        // PreferredSize(
        //     preferredSize: const Size.fromHeight(60.0),
        //     child: Align(
        //         alignment: Alignment.bottomLeft,
        //         child: Platform.isWindows
        //             ? Scrollbar(
        //             thickness: 5,
        //             interactive: true,
        //             isAlwaysShown: true,
        //             child: SingleChildScrollView(
        //                 scrollDirection: Axis.horizontal,
        //                 primary: true,
        //                 child: SizedBox(
        //                     width: 152.0 * affiliates.length,
        //                     child: _tabBar)))
        //             : _tabBar))),
        body: TabBarView(
          controller: _tabController,
          children: cities
              .map((e) => AffiliatesController(cities: cities, city: e))
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
