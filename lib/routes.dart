import 'package:climbing_notes/main.dart';
import 'package:climbing_notes/utility.dart';
import 'package:climbing_notes/add_ascent.dart';
import 'package:climbing_notes/add_route.dart';
import 'package:flutter/material.dart';
import 'ascents.dart';
import 'builders.dart';
import 'data_structures.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> with RouteAware {
  DBRoute queryInfo = DBRoute(0, "", "", null, null, null, null, null, null);
  List<GlobalKey<InputRowState>> inputRowKeys = [GlobalKey<InputRowState>(), GlobalKey<InputRowState>(), GlobalKey<InputRowState>()];
  GlobalKey<DropdownRowState> dropdownRowKey = GlobalKey<DropdownRowState>();
  List<DBRoute>? matchingRoutes;
  Map<int, bool>? finishedRoutes;

  _RoutesPageState();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppServices.of(context).robs.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {
    updateTableData();
    super.didPush();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didPopNext() {
    updateTableData();
    super.didPopNext();
  }

  void updateTableData() async {
    List<DBRoute>? r = await AppServices.of(context).dbs.queryRoutes(AppServices.of(context).settings.smallDateFormat, queryInfo);

    setState(() {
      matchingRoutes = r;
    });

    updateFinishes();
  }

  void updateFinishes() async {
    if (matchingRoutes == null) {
      return;
    }
    List<Map<String, Object?>>? r = await AppServices.of(context)
        .dbs
        .queryFinished(
            matchingRoutes?.map((route) => (route.id)).toList() ?? []);
    if (r == null) {
      return;
    }
    Map<int, bool> finishesMap = Map.fromEntries(r.map(
        (map) => (MapEntry(map["route"] as int, map["has_finished"] == 1))));
    setState(() {
      finishedRoutes = finishesMap;
    });
  }

  IconData? getFinishIcon(int routeId) {
    bool? fin = finishedRoutes?[routeId];
    if (fin == null) {
      return null;
    }
    return fin ? Icons.check : Icons.close;
  }

  TableRow buildRoutesTableRow(DBRoute data) {
    return TableRow(
      children: [
        buildRoutesTableCell(
            Text(data.rope.toString()), (context) => AscentsPage(route: data)),
        buildRoutesTableCell(Text(timeDisplayFromTimestamp(AppServices.of(context).settings.smallDateFormat, data.date)),
            (context) => AscentsPage(route: data)),
        buildRoutesTableCell(
            Text(RouteGrade.fromDBValues(data.grade_num, data.grade_let)
                .toString()),
            (context) => AscentsPage(route: data)),
        buildRoutesTableCell(
            Text(RouteColor.fromString(data.color ?? "").string),
            (context) => AscentsPage(route: data)),
        buildRoutesTableCell(Icon(getFinishIcon(data.id)),
            (context) => AscentsPage(route: data)),
        InkWell(
          onTap: () => (
            Navigator.push(
              context,
              cnPageTransition(AddAscentPage(route: data)),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ].map(padCell).toList(),
    );
  }

  Widget buildRoutesTableCell(
      Widget cellContents, Widget Function(BuildContext)? navBuilder) {
    return InkWell(
      child: cellContents,
      onTap: () => navBuilder == null
          ? () => ()
          : Navigator.push(
              context,
              MaterialPageRoute(builder: navBuilder),
            ),
    );
  }

  Table buildRoutesTable() {
    return Table(
      border: TableBorder.all(color: themeTextColor(context)),
      children: [
            TableRow(
                // header row
                children: <Widget>[
                  const Text("Rope #"),
                  const Text("Set date"),
                  const Text("Grade"),
                  const Text("Color"),
                  const Text("Finished"),
                  const Text("Ascent"),
                ].map(padCell).toList(),
                decoration: BoxDecoration(color: contrastingSurface(context))),
          ] +
          (matchingRoutes?.map(buildRoutesTableRow).toList() ?? []),
    );
  }

  void clearData() {
    setState(() {
      queryInfo.clear();
      for (var key in inputRowKeys) {
        key.currentState?.controller.clear();
      }
      dropdownRowKey.currentState?.controller.clear();
      updateTableData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClimbingNotesAppBar(pageTitle: "Route Search"),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            Column(
              children: <Widget>[
                InputRow(
                  key: inputRowKeys[0],
                  label: "Rope #:",
                  inputType: TextInputType.datetime,
                    onChanged: (String? value) {
                  setState(() {
                    queryInfo.rope = stringToInt(value);
                    updateTableData();
                  });
                }),
                InputRow(
                  key: inputRowKeys[1],
                  label: "Set date:",
                  inputType: TextInputType.datetime,
                    onChanged: (String? value) {
                  setState(() {
                    queryInfo.date = value;
                    updateTableData();
                  });
                }),
                InputRow(
                  key: inputRowKeys[2],
                  label: "Grade:",
                  inputType: TextInputType.text,
                    onChanged: (String? value) {
                  setState(() {
                    if (value == null) {
                      queryInfo.grade_num = null;
                      queryInfo.grade_let = null;
                    } else {
                      RegExpMatch? match = gradeExp.firstMatch(value);
                      queryInfo.grade_num =
                          stringToInt(match?.namedGroup("num"));
                      queryInfo.grade_let = match?.namedGroup("let");
                    }
                    updateTableData();
                  });
                }),
                DropdownRow(
                    key: dropdownRowKey,
                    initialValue: RouteColor.fromString(queryInfo.color ?? ""),
                    onSelected: (RouteColor? value) {
                      setState(() {
                        queryInfo.color =
                            value == RouteColor.nocolor ? null : value?.string;
                        updateTableData();
                      });
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    child: buildRoutesTable(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            FloatingActionButton(
              heroTag: "clearFloatBtn",
              onPressed: clearData,
              tooltip: 'Clear',
              child: const Icon(Icons.clear),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "addFloatBtn",
              onPressed: () => (
                Navigator.push(
                  context,
                  cnPageTransition(AddRoutePage(providedRoute: DBRoute.of(queryInfo))),
                ),
              ),
              tooltip: 'Add route',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      drawer: const ClimbingNotesDrawer(),
    );
  }
}
