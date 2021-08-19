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
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'common.dart';

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
  late TabController _tabController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    cities = widget.cities!;
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
    var file = File('${tempDir.path}\\excel_generator_state5.json');
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
    var name = fileName.join(' ');
    name = name.trim();

    late City city;

    if (citiesNames.containsKey(name)) {
      city = cities[citiesNames['name']];
    } else {
      city = City.allData(name, []);
      cities.add(city);
    }

    var affiliatesNames = {};

    city.affiliates.asMap().forEach((key, value) {
      affiliatesNames['${value.name}'] = key;
    });

    for (var affiliateName in excel.tables.keys) {
      late Affiliate affiliate;
      if (affiliatesNames.containsKey(affiliateName)) {
        affiliate = city.affiliates[affiliatesNames[affiliateName]];
        affiliate.users = [];
      } else {
        affiliate = Affiliate.allData(affiliateName, []);
        city.affiliates.add(affiliate);
      }

      var table = excel.tables[affiliate.name];
      int row = 1;

      for (int i = 1; i < 4; ++i) {
        while (table!
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
                .value !=
            null) {
          var user = User();
          user.name = table
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value;
          var date = table
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value;
          user.dateStartOfEducation = int.tryParse(date.toString()) == null
              ? _getTime(date)
              : DateTime.fromMicrosecondsSinceEpoch(
                  int.tryParse(date.toString())! * 1000);
          for (int column = 3; column < months.length + 3; ++column) {
            var paid = table
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: column, rowIndex: row))
                .value;
            user.properties[column - 3] = paid == '' ? 0 : paid;
          }
          user.calculateResult();
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

  // List<City> _getCitiesToSave() {
  //
  // }

  Future<void> _xlsxSave() async {
    if (Platform.isWindows) _saveState();
    var excel = Excel.createExcel();
    final DateFormat formatter = DateFormat('dd.MM.yyyy');
    for (var affiliate
        in cities.expand((element) => element.affiliates.toList())) {
      var name = affiliate.name;
      var users = affiliate.users;
      var sheet = excel[name == '' ? ' ' : name];
      for (int i = 0; i < columns.length; ++i) {
        var cellStyle = CellStyle(
            bold: true, fontSize: 10, textWrapping: TextWrapping.WrapText);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), columns[i],
            cellStyle: cellStyle);
      }
      int row = 1;
      var spacer = false;
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
            cellStyle: _cellStyle);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
            user.dateStartOfEducation == null
                ? ''
                : formatter.format(user.dateStartOfEducation!),
            cellStyle: _cellStyle);
        int column = 3;
        for (var paid in user.properties) {
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
              paid ?? 0,
              cellStyle: _cellStyle);
          column++;
        }
        var rowForSum = row + 1;
        Formula formula =
            Formula.custom('=SUM(D$rowForSum:M$rowForSum)+O$rowForSum');
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row), formula,
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
                ? ''
                : formatter.format(users[i].dateStartOfEducation!),
            cellStyle: _cellStyle);
        int column = 3;
        for (var paid in users[i].properties) {
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
              paid ?? 0,
              cellStyle: _cellStyle);
          column++;
        }
        var rowForSum = row + 1;
        Formula formula =
            Formula.custom('=SUM(D$rowForSum:M$rowForSum)+O$rowForSum');
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row),
            formula);
        ++row;
      }
      sheet.setColAutoFit(1);
      sheet.setColWidth(2, 15);
      //sheet.setColAutoFit(2);
    }
    excel.delete('Sheet1');
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd-HH-mm').format(now);
    final fileName = "Отчет ${cities.length > 0 ? cities[0].name : " "} $formattedDate.xlsx";
    final data = Uint8List.fromList(excel.encode()!);
    if (Platform.isWindows) {
      var path =
          await getSavePath(suggestedName: fileName, acceptedTypeGroups: [
        XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls'])
      ]);
      const mimeType = "application/vnd.ms-excel";
      final file = XFile.fromData(data, name: fileName, mimeType: mimeType);
      if (path!.substring(path.indexOf('.'), path.indexOf('.') + 4) != '.xls') {
        path += '.xlsx';
      }
      await file.saveTo(path);
    } else if (Platform.isAndroid) {
      final params = SaveFileDialogParams(data: data, fileName: fileName);
      final filePath = await FlutterFileDialog.saveFile(params: params);
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
              IconButton(onPressed: _xlsxSave, icon: const Icon(Icons.save)),
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
