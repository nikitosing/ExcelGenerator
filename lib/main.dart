import 'dart:convert';
import 'dart:io';

import 'cities_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

List<City> cities = [];
const _title = 'NADiP';
final theme = ThemeData(primaryColor: Colors.grey, primarySwatch: Colors.teal);

Future<void> main() async {
  runApp(const LoadingScreen());
  await getState();
  runApp(const MyApp());
}

Future<void> getState() async {
  Directory tempDir = await getApplicationSupportDirectory();
  var file = File('${tempDir.path}${Platform.pathSeparator}excel_generator_state7.json');
  if (file.existsSync()) {
    var json = jsonDecode(file.readAsStringSync());
    cities = json == null
        ? []
        : json.map((e) => City.fromJson(e)).toList().cast<City>();
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        //key: UniqueKey(),
        title: _title,
        theme: theme,
        home: Scaffold(
            //key: UniqueKey(),
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
        //key: UniqueKey(),
      //debugShowMaterialGrid: true,

        //showSemanticsDebugger: true,
        debugShowCheckedModeBanner: true,
        title: _title,
        theme: theme,
        home: CitiesController(key: UniqueKey(), cities: cities));
  }
}
