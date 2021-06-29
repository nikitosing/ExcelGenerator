import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'affiliates_controller.dart';
import 'user_table.dart';

var affiliateCnt = 1;
var affiliates = {
  '0': {'name': '', 'users': []}
};
var cityName = '';

const _title = 'ExcelGenerator';

Future<void> main() async {
  runApp(const LoadingScreen());
  await getState();
  runApp(const MyApp());
}

Future<void> getState() async {
  Directory tempDir = await getApplicationSupportDirectory();
  var file = File('${tempDir.path}\\excel_generator_state4.json');
  if (file.existsSync()) {
    var json = jsonDecode(file.readAsStringSync());
    affiliates = {};
    cityName = json.containsKey('cityName') ? json['cityName'] : '';
    for (var entry in json['affiliates'].entries) {
      affiliateCnt = 0;
      affiliates[entry.key] = {
        'name': entry.value['name'],
        'users':
            entry.value['users'].map((user) => User.fromJson(user)).toList()
      };
    }
    affiliateCnt = int.parse(affiliates.keys.last);
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: _title,
        theme: ThemeData(
          primarySwatch: Colors.teal,
          primaryColor: Colors.grey,
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
        showSemanticsDebugger: false,
        debugShowCheckedModeBanner: true,
        title: _title,
        theme: ThemeData(
          primarySwatch: Colors.teal,
          primaryColor: Colors.grey,
        ),
        home: AffiliatesController(
            affiliates: affiliates,
            affiliatesCnt: affiliateCnt,
            cityName: cityName));
  }
}

//UserTable(users: affilates[affilates.keys.first].map((user) => User.fromJson(user)).toList(), name: affilates.keys.first),

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
