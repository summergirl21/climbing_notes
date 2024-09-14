// ignore: unused_import
import 'dart:developer';
import 'package:climbing_notes/add_ascent.dart';
import 'package:climbing_notes/ascent.dart';
import 'package:climbing_notes/main.dart';
import 'package:flutter/material.dart';
import 'builders.dart';
import 'data_structures.dart';
import 'package:climbing_notes/utility.dart';

class AscentsPage extends StatefulWidget {
  const AscentsPage({super.key, required this.route});

  final DBRoute route;

  @override
  State<AscentsPage> createState() => _AscentsPageState(route);
}

class _AscentsPageState extends State<AscentsPage> with RouteAware {
  DBRoute route;
  List<DBAscent>? tableData;
  bool lockInputs = true;
  List<GlobalKey<InputRowState>> inputRowKeys = [
    GlobalKey<InputRowState>(),
    GlobalKey<InputRowState>(),
    GlobalKey<InputRowState>(),
    GlobalKey<InputRowState>(),
  ];
  GlobalKey<DropdownRowState> dropdownRowKey = GlobalKey<DropdownRowState>();

  _AscentsPageState(this.route);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppServices.of(context).robs.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {
    getTableData();
    super.didPush();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didPopNext() {
    getTableData();
    super.didPopNext();
  }

  void getTableData() async {
    List<DBAscent>? r1 =
        await AppServices.of(context).dbs.queryAscents(route.id);
    setState(() {
      tableData = r1;
    });
  }

  TableRow buildAscentsTableRow(DBAscent data) {
    return TableRow(
      children: [
        buildAscentsTableCell(
            Text(timeDisplayFromTimestamp(
                AppServices.of(context).settings.smallDateFormat, data.date)),
            (context) => (AscentPage(providedRoute: route, providedAscent:  data))),
        buildAscentsTableCell(
            Icon(intToBool(data.finished) ?? false ? Icons.check : Icons.close),
            (context) => (AscentPage(providedRoute: route, providedAscent:  data))),
        buildAscentsTableCell(
            Icon(intToBool(data.rested) ?? false ? Icons.check : Icons.close),
            (context) => (AscentPage(providedRoute: route, providedAscent:  data))),
        buildAscentsTableCell(Text(data.notes ?? ""), (context) => (AscentPage(providedRoute: route, providedAscent:  data))),
        InkWell(
          onTap: () => (deleteAscentDialog(data)),
          child: const Icon(Icons.clear),
        )
      ].map(padCell).toList(),
    );
  }

  Widget buildAscentsTableCell(
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

  Table buildAscentsTable() {
    return Table(
      border: TableBorder.all(color: themeTextColor(context)),
      children: [
            TableRow(
                // header row
                children: <Widget>[
                  const Text("Date"),
                  const Text("Finished"),
                  const Text("Rested"),
                  const Text("Notes"),
                  const Text("Delete"),
                ].map(padCell).toList(),
                decoration: BoxDecoration(color: contrastingSurface(context))),
          ] +
          (tableData?.map(buildAscentsTableRow).toList() ?? []),
    );
  }

  void updateRoute() async {
    if (!lockInputs) {
      DateTime? likelySetDate;
      String? canBePromoted = route.date;
      if (canBePromoted == null) {
        errorPopup("Date is not set.");
        return;
      }
      likelySetDate = likelyTimeFromTimeDisplay(
          AppServices.of(context).settings.smallDateFormat, canBePromoted);
      if (likelySetDate == null) {
        errorPopup("Invalid date.");
        return;
      }

      if (likelySetDate.isAfter(DateTime.now())) {
        errorPopup("Date cannot be in the future.");
        return;
      }

      route.date = likelySetDate.toUtc().toIso8601String();

      int? res = await AppServices.of(context).dbs.routeUpdate(route);
      if (res == null || res == 0) {
        errorPopup("Update unsuccessful");
      } else if (res == -1) {
        errorPopup("Nothing to update");
      }
      else {
        errorPopup("Updated");
      }
    }

    setState(() {
      lockInputs = !lockInputs;
      for (var key in inputRowKeys) {
        key.currentState
            ?.setState(() => (key.currentState?.locked = lockInputs));
      }
      dropdownRowKey.currentState
          ?.setState(() => (dropdownRowKey.currentState?.locked = lockInputs));
      getTableData();
    });
  }

  void cancelUpdate() {}

  Future<bool> deleteRoute() async {
    int? res = await AppServices.of(context).dbs.deleteRoute(route.id);
    if (res == null || res < 1) {
      return false;
    }
    return true;
  }

  Future<bool> deleteAscent(DBAscent ascent) async {
    int? res = await AppServices.of(context).dbs.deleteAscents([ascent.id]);
    if (res == null || res < 1) {
      return false;
    }
    return true;
  }

  void errorPopup(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> deleteAscentDialog(DBAscent ascent) async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Delete Ascent"),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Are you sure?'),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                child: const Icon(Icons.check),
                onPressed: () async {
                  bool res = await deleteAscent(ascent);
                  Navigator.of(context).pop();
                  if (res) {
                    errorPopup("Ascent deleted");
                  } else {
                    errorPopup("Error deleting ascent");
                  }
                  getTableData();
                },
              ),
              OutlinedButton(
                child: const Icon(Icons.clear),
                onPressed: () => (Navigator.of(context).pop()),
              ),
            ],
          );
        });
  }

  Future<void> deleteRouteDialog() async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Delete Route"),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                      'Deleting this route will also delete associated ascents.'),
                  Text('Are you sure?'),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                child: const Icon(Icons.check),
                onPressed: () async {
                  bool res = await deleteRoute();
                  Navigator.of(context).pop();
                  if (res) {
                    errorPopup("Route deleted");
                    Navigator.of(context).pop();
                  } else {
                    errorPopup("Error deleting route");
                  }
                },
              ),
              OutlinedButton(
                child: const Icon(Icons.clear),
                onPressed: () => (Navigator.of(context).pop()),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClimbingNotesAppBar(pageTitle: "Route Info"),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            Column(
              children: <Widget>[
                InputRow(
                  key: inputRowKeys[0],
                  label: "Rope #:",
                  initialValue: route.rope.toString(),
                  locked: lockInputs,
                  onChanged: (String? value) {
                    setState(() {
                      route.rope = stringToInt(value);
                    });
                  },
                ),
                InputRow(
                  key: inputRowKeys[1],
                  label: "Set date:",
                  initialValue: timeDisplayFromTimestampSafe(AppServices.of(context).settings.smallDateFormat, route.date),
                  locked: lockInputs,
                  onChanged: (String? value) {
                    setState(() {
                      route.date = value;
                    });
                  },
                ),
                InputRow(
                  key: inputRowKeys[2],
                  label: "Grade:",
                  initialValue:
                      RouteGrade.fromDBValues(route.grade_num, route.grade_let)
                          .toString(),
                  locked: lockInputs,
                  onChanged: (String? value) {
                    setState(() {
                      if (value == null) {
                        route.grade_num = null;
                        route.grade_let = null;
                      } else {
                        RegExpMatch? match = gradeExp.firstMatch(value);
                        route.grade_num = stringToInt(match?.namedGroup("num"));
                        route.grade_let = match?.namedGroup("let");
                      }
                    });
                  },
                ),
                DropdownRow(
                  key: dropdownRowKey,
                  initialValue: RouteColor.fromString(route.color ?? ""),
                  locked: lockInputs,
                  onSelected: (RouteColor? value) {
                    setState(() {
                      route.color =
                          value == RouteColor.nocolor ? null : value?.string;
                    });
                  },
                ),
                const ClimbingNotesLabel("Notes:"),
                InputRow(
                  key: inputRowKeys[3],
                  initialValue: route.notes,
                  locked: lockInputs,
                  onChanged: (String? value) {
                    setState(() {
                      route.notes = value;
                      getTableData();
                    });
                  }
                ),
                Row(
                  children: [
                    OutlinedButton(
                      child: Icon(lockInputs ? Icons.edit : Icons.check),
                      onPressed: updateRoute,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      child: const Icon(Icons.close),
                      onPressed: lockInputs ? null : cancelUpdate,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      child: const Icon(Icons.delete),
                      onPressed: lockInputs ? deleteRouteDialog : null,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    child: buildAscentsTable(),
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
              heroTag: "backFloatBtn",
              onPressed: () => {
                Navigator.pop(context),
              },
              tooltip: 'Back',
              child: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "addFloatBtn",
              onPressed: () => (
                Navigator.push(
                  context,
                  cnPageTransition(AddAscentPage(route: route)),
                ),
              ),
              tooltip: 'Add ascent',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      drawer: const ClimbingNotesDrawer(),
    );
  }
}
