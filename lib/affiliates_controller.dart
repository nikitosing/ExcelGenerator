import 'dart:convert';
import 'dart:io';

import 'user_table.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'cities_controller.dart';
import 'common.dart';

class AffiliatesController extends StatefulWidget {
  final cities;
  final city;

  const AffiliatesController({Key? key, this.cities, this.city})
      : super(key: key);

  @override
  State<AffiliatesController> createState() => _AffiliateControllerState();
}

class _AffiliateControllerState extends State<AffiliatesController>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  @override
  AffiliatesController get widget => super.widget;

  var affiliates = [];
  late City city;
  late TabController _tabController;
  late ScrollController _scrollController;
  late List<City> _cities;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    city = widget.city;
    _cities = widget.cities;
    affiliates = city.affiliates;
    _scrollController = ScrollController();
    _tabController = TabController(length: affiliates.length, vsync: this);
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
    super.dispose();
  }

  void _recreateTabController() {
    var oldIndex = _tabController.index;
    _tabController.dispose();
    _tabController = TabController(
        length: affiliates.length,
        vsync: this,
        initialIndex: () {
          if (affiliates.isEmpty) return 0;
          if (affiliates.length == oldIndex) return --oldIndex;
          return oldIndex;
        }());
    _tabController.addListener(() {
      setState(() {});
    });
  }

  void _addAffiliate() {
    affiliates.add(Affiliate());
    _recreateTabController();
    setState(() {});
    if (Platform.isWindows) _saveState();
  }

  Future<void> _removeDialog(var affiliate) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтвердите'),
          content: SingleChildScrollView(
            child: Column(
              children: const [Text('Вы точно хотите удалить филиал?')],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Да'),
              onPressed: () {
                _removeAffiliate(affiliate);
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

  void _removeAffiliate(var affiliate) {
    affiliates.remove(affiliate);
    _recreateTabController();
    setState(() {});
    if (Platform.isWindows) _saveState();
  }

  void _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File(
        '${tempDir.path}${Platform.pathSeparator}excel_generator_state8.json');
    file.writeAsStringSync(jsonEncode(_cities));
  }

  Widget _tabCreator(var affiliate, var index, var activeTabId) {
    return Container(
        //key: UniqueKey(),
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
                      key: Key('${affiliate.id}name'),
                      enabled: index == activeTabId,
                      initialValue: affiliate.name,
                      onChanged: (val) {
                        affiliate.name = val;
                      },
                    ))),
            GestureDetector(
              onTap: () {
                setState(() {
                  _removeDialog(affiliate);
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
        for (int i = 0; i < affiliates.length; ++i) {
          tabs.add(_tabCreator(affiliates[i], i, activeTabId));
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
                    setState(() {
                      _addAffiliate();
                    });
                  },
                  icon: const Icon(Icons.add))
            ],
            title: SizedBox(
                width: MediaQuery.of(context).size.width - 100,
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
                                    width: 152.0 * affiliates.length,
                                    child: _tabBar)))
                        : _tabBar))),
        body: TabBarView(
          controller: _tabController,
          children: affiliates
              .map((entry) => UserTable(
                  key: Key(entry.id), cities: _cities, affiliate: entry))
              .toList(),
        ));
  }
}

class Affiliate {
  String id = UniqueKey().hashCode.toString();
  late String name;
  late List<User> users;
  List<Types> userDefinedColumnsTypes = [];
  List<String> userDefinedColumns = [];

  var columnsBigWidth = <String, int>{
    'Дата начала занятий': 200,
    'Сентябрь': 100,
    'Октябрь': 100,
    'Ноябрь': 100,
    'Декабрь': 100,
    'Январь': 100,
    'Февраль': 100,
    'Март': 100,
    'Апрель': 100,
    'Май': 100,
    'Сентябрь следующего года': 220,
    'Итого': 100,
    'Доп. оплаты': 100
  };

  var columnsWidth = <String, int>{
    'Дата начала занятий': 200,
    'Сентябрь': 100,
    'Октябрь': 100,
    'Ноябрь': 100,
    'Декабрь': 100,
    'Январь': 100,
    'Февраль': 100,
    'Март': 100,
    'Апрель': 100,
    'Май': 100,
    'Сентябрь следующего года': 220,
    'Итого': 100,
    'Доп. оплаты': 100
  };

  Affiliate() {
    name = '';
    users = [User.toPaint(userDefinedColumns.length)];
  }

  Map toJson() => {
        'id': id,
        'name': name,
        'users': users.map((e) => e.toJson()).toList(),
        'userDefinedColumns': userDefinedColumns,
        'userDefinedColumnsTypes':
            userDefinedColumnsTypes.map((e) => e.index).toList(),
    'columnsWidth': columnsWidth,
    'columnsBigWidth': columnsBigWidth
      };

  Affiliate.allData(this.name, this.users);

  Affiliate.allWithColumns(this.name, this.users, this.userDefinedColumns,
      this.userDefinedColumnsTypes, this.columnsWidth, this.columnsBigWidth);

  factory Affiliate.fromJson(dynamic json) {
    return Affiliate.allWithColumns(
        json['name'],
        json['users'].map((e) => User.fromJson(e)).toList().cast<User>(),
        json['userDefinedColumns'].cast<String>(),
        json['userDefinedColumnsTypes']
            .map((e) => Types.values[e])
            .toList()
            .cast<Types>(),
    json['columnsWidth'].cast<String, int>(),
    json['columnsBigWidth'].cast<String, int>());
  }
}
