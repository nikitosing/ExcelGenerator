import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:excel_generator/user_table.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'common.dart';

class AffiliatesController extends StatefulWidget {
  final affiliates;
  final affiliatesCnt;
  final cityName;

  const AffiliatesController(
      {Key? key, this.affiliates, required this.affiliatesCnt, this.cityName})
      : super(key: key);

  @override
  State<AffiliatesController> createState() => _AffiliateControllerState();
}

class _AffiliateControllerState extends State<AffiliatesController>
    with WidgetsBindingObserver {
  @override
  AffiliatesController get widget => super.widget;

  var affiliates = {};
  int affiliateCnt = 0;
  var cityName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    affiliates = widget.affiliates;
    affiliateCnt = widget.affiliatesCnt;
    cityName = widget.cityName;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      saveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  void addAffiliate() {
    affiliates['${++affiliateCnt}'] = {'name': '', 'users': []};
    if (Platform.isWindows) saveState();
  }

  void removeAffiliate(var id) {
    affiliates.remove(id);
    if (Platform.isWindows) saveState();
  }

  Future<void> saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File('${tempDir.path}\\excel_generator_state4.json');
    file.writeAsStringSync(
        jsonEncode({'cityName': cityName, 'affiliates': affiliates}));
  }

  Widget tabCreator(var id) {
    return SizedBox(
        height: 60,
        width: 152,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
                width: 100,
                height: 35,
                child: TextFormField(
                  key: Key(id),
                  initialValue: affiliates[id]['name'],
                  onChanged: (val) {
                    affiliates[id]['name'] = val;
                  },
                  onTap: () {
                    if (Platform.isWindows) saveState();
                  },
                )),
            GestureDetector(
              onTap: () {
                setState(() {
                  removeAffiliate(id);
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

  Future<void> xlsxSave() async {
    if (Platform.isWindows) saveState();
    var excel = Excel.createExcel();
    for (var value in affiliates.values) {
      var name = value['name'];
      var users = value['users'];
      var sheet = excel[name == '' ? ' ' : name];
      for (int i = 0; i < columns.length; ++i) {
        var cellStyle = CellStyle(
            bold: true, fontSize: 10, textWrapping: TextWrapping.WrapText);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), columns[i],
            cellStyle: cellStyle);
      }
      int row = 1;
      for (User user in users) {
        if (user.status == UserStatus.toEdit) {
          break;
        }
        var _cellStyle = CellStyle(
            backgroundColorHex:
                user.status == UserStatus.normal ? '#ffffff' : '#FFFF00');
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), row,
            cellStyle: _cellStyle);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
            user.name,
            cellStyle: _cellStyle);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
            user.dateStartOfEducation == DateTime(1337)
                ? ''
                : '${user.dateStartOfEducation.day}/${user.dateStartOfEducation.month}/${user.dateStartOfEducation.year}',
            cellStyle: _cellStyle);
        int column = 3;
        for (var paid in user.paid) {
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
              paid ?? '',
              cellStyle: _cellStyle);
          column++;
        }
        row++;
      }
      for (int i = 0; i < months.length; ++i) {
        num value = 0;
        for (var user in users) {
          if (user.status == UserStatus.toEdit) {
            break;
          }
          value += user.paid[i] ?? 0;
        }
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: row),
            value,
            cellStyle: CellStyle(backgroundColorHex: '#3792cb'));
      }
      row += 2;
      for (var i = row - 3; i < users.length; ++i) {
        var _cellStyle = CellStyle(backgroundColorHex: '#FF5722');
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), row - 2,
            cellStyle: _cellStyle);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
            users[i].name,
            cellStyle: _cellStyle);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
            users[i].dateStartOfEducation == DateTime(1337)
                ? ''
                : '${users[i].dateStartOfEducation.day}/${users[i].dateStartOfEducation.month}/${users[i].dateStartOfEducation.year}',
            cellStyle: _cellStyle);
        int column = 3;
        for (var paid in users[i].paid) {
          sheet.updateCell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
              paid ?? '',
              cellStyle: _cellStyle);
          column++;
        }
        row++;
      }
    }
    excel.delete('Sheet1');
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd-HH-mm').format(now);
    final fileName = "Отчет $cityName $formattedDate.xls";
    final data = Uint8List.fromList(excel.encode()!);
    if (Platform.isWindows) {
      var path =
          await getSavePath(suggestedName: fileName, acceptedTypeGroups: [
        XTypeGroup(label: 'Excel', extensions: ['xlsx', 'xls'])
      ]);
      const mimeType = "application/vnd.ms-excel";
      final file = XFile.fromData(data, name: fileName, mimeType: mimeType);
      if (!(path!.substring(path.runes.length - 4) == '.xls' ||
          path.substring(path.runes.length - 5) == '.xlsx')) {
        path += '.xls';
      }
      await file.saveTo(path);
    } else if (Platform.isAndroid) {
      final params = SaveFileDialogParams(data: data, fileName: fileName);
      final filePath = await FlutterFileDialog.saveFile(params: params);
    }
  }

  void debugDeleteAll() {
    affiliates = {};
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var _tabBar = TabBar(
      isScrollable: Platform.isAndroid,
      tabs: affiliates.keys.map((id) => tabCreator(id)).toList(),
    );
    return DefaultTabController(
      length: affiliates.length,
      child: Scaffold(
        appBar: AppBar(
            title: SafeArea(
                child: TextFormField(
              key: Key(cityName),
              initialValue: cityName,
              onChanged: (val) {
                cityName = val;
              },
              onTap: () {
                if (Platform.isWindows) saveState();
              },
            )),
            actions: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      addAffiliate();
                    });
                  },
                  icon: const Icon(Icons.add)),
              IconButton(onPressed: xlsxSave, icon: const Icon(Icons.save)),
              IconButton(
                  onPressed: debugDeleteAll,
                  icon: const Icon(Icons.highlight_remove_outlined))
            ],
            bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60.0),
                child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                        width: MediaQuery.of(context).size.width - 130,
                        child: Platform.isWindows
                            ? Scrollbar(
                                thickness: 5,
                                interactive: true,
                                isAlwaysShown: true,
                                child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    primary: true,
                                    child: SizedBox(
                                        width: 200.0 * affiliates.length,
                                        child: _tabBar)))
                            : _tabBar)))),
        body: TabBarView(
            children: affiliates.entries
                .map((entry) => UserTable(
                    users: entry.value['users'], affiliateId: entry.key))
                .toList()),
      ),
    );
  }
}
