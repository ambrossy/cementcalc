import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';

// Importa la API unificada para web y móvil
import 'storage/storage_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const CementCalcApp());
}

class CementCalcApp extends StatelessWidget {
  const CementCalcApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cement Calc',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 22, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 20, color: Colors.white),
          bodySmall: TextStyle(fontSize: 18, color: Colors.white),
          titleMedium: TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // —— Estado de la UI ——
  String input = '';
  String buttonClicked = '';
  String selectedList = 'A';

  final Map<String, String> listNames = {
    for (var c in List.generate(9, (i) => String.fromCharCode(65 + i))) c: c,
  };
  final Map<String, List<int>> numbersMap = {
    for (var c in List.generate(9, (i) => String.fromCharCode(65 + i))) c: <int>[],
  };
  final Map<String, double> surfaceMap = {
    for (var c in List.generate(9, (i) => String.fromCharCode(65 + i))) c: 1.0,
  };
  final Map<String, double> weightMap = {
    for (var c in List.generate(9, (i) => String.fromCharCode(65 + i))) c: 1.8,
  };
  final Map<String, double> offsetMap = {
    for (var c in List.generate(9, (i) => String.fromCharCode(65 + i))) c: 0.0,
  };
  int? indexToDelete;
  List<int> deletedHistory = [];
  String digitMode = 'XX';

  // —— Getters de conveniencia ——
  List<int> get numbers => numbersMap[selectedList]!;
  double get surface => surfaceMap[selectedList]!;
  set surface(double v) => surfaceMap[selectedList] = v;
  double get weight => weightMap[selectedList]!;
  set weight(double v) => weightMap[selectedList] = v;
  double get avgOffset => offsetMap[selectedList]!;
  set avgOffset(double v) => offsetMap[selectedList] = v;

  double get avg => numbers.isEmpty ? 0.0 : numbers.reduce((a, b) => a + b) / numbers.length;
  double get adjustedAvg => avg - avgOffset;
  double get cement => adjustedAvg * surface * weight;

  // —— Persistencia: JSON móvil, localStorage web ——
  Future<File> get _localFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cement_data.json');
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (kIsWeb) {
      final s = getFromLocalStorage('appData');
      if (s != null) {
        final data = json.decode(s) as Map<String, dynamic>;
        setState(() {
          listNames.updateAll((k, _) => data['listNames'][k] as String);
          numbersMap.updateAll((k, _) => List<int>.from(data['numbersMap'][k]));
          surfaceMap.updateAll((k, _) => (data['surfaceMap'][k] as num).toDouble());
          weightMap.updateAll((k, _) => (data['weightMap'][k] as num).toDouble());
          offsetMap.updateAll((k, _) => (data['offsetMap'][k] as num).toDouble());
          deletedHistory = List<int>.from(data['deletedHistory'] as List);
          digitMode = data['digitMode'] as String;
          selectedList = data['selectedList'] as String;
        });
      }
    } else {
      try {
        final file = await _localFile;
        if (await file.exists()) {
          final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
          setState(() {
            listNames.updateAll((k, _) => data['listNames'][k] as String);
            numbersMap.updateAll((k, _) => List<int>.from(data['numbersMap'][k]));
            surfaceMap.updateAll((k, _) => (data['surfaceMap'][k] as num).toDouble());
            weightMap.updateAll((k, _) => (data['weightMap'][k] as num).toDouble());
            offsetMap.updateAll((k, _) => (data['offsetMap'][k] as num).toDouble());
            deletedHistory = List<int>.from(data['deletedHistory'] as List);
            digitMode = data['digitMode'] as String;
            selectedList = data['selectedList'] as String;
          });
        }
      } catch (_) {
        // Si falla, seguimos con valores por defecto
      }
    }
  }

  Future<void> _saveData() async {
    final map = {
      'listNames': listNames,
      'numbersMap': numbersMap,
      'surfaceMap': surfaceMap,
      'weightMap': weightMap,
      'offsetMap': offsetMap,
      'deletedHistory': deletedHistory,
      'digitMode': digitMode,
      'selectedList': selectedList,
    };
    final s = json.encode(map);
    if (kIsWeb) {
      saveToLocalStorage('appData', s);
    } else {
      final file = await _localFile;
      await file.writeAsString(s);
    }
  }

  Future<void> _wipeAllStorage() async {
    if (kIsWeb) {
      clearLocalStorage();
    } else {
      final file = await _localFile;
      if (await file.exists()) await file.delete();
    }
  }

  // —— Manejadores de UI (añadiendo _saveData tras cada cambio) ——
  void _addValueFromInput() {
    final parsed = int.tryParse(input);
    if (parsed != null) {
      setState(() {
        numbers.insert(0, parsed);
        input = '';
        buttonClicked = 'add';
      });
      _saveData();
      Future.delayed(const Duration(milliseconds: 100), () => setState(() => buttonClicked = ''));
    }
  }


  int get _digitCount => input.startsWith('-') ? input.length - 1 : input.length;

  void _handleMinus() {
    setState(() {
      if (input.isEmpty) {
        input = '-';
      } else if (input == '-') {
        input = '';
      } else if (input.startsWith('-')) {
        input = input.substring(1);
      } else {
        input = '-$input';
      }
      buttonClicked = '-';
    });

    Future.delayed(const Duration(milliseconds: 100), () => setState(() => buttonClicked = ''));
  }


  void _handleNumberClick(String value) {
    final limit = digitMode == 'X' ? 1 : (digitMode == 'XX' ? 2 : 3);

    if (_digitCount < limit) {
      setState(() {
        input += value;
        buttonClicked = value.toLowerCase();
      });

      if (_digitCount == limit) _addValueFromInput();

      Future.delayed(const Duration(milliseconds: 100), () => setState(() => buttonClicked = ''));
    }
  }

  void _handleDelete() {
    setState(() {
      input = input.isNotEmpty ? input.substring(0, input.length - 1) : '';
      buttonClicked = 'del';
    });
    Future.delayed(const Duration(milliseconds: 100), () => setState(() => buttonClicked = ''));
  }

  void _handleAdd() {
    if (input.isEmpty || input == '-') return;
    _addValueFromInput();
  }

  void _setDigitMode(String mode) {
    setState(() {
      digitMode = mode;
      input = '';
      buttonClicked = 'mode';
    });
    _saveData();
    Future.delayed(const Duration(milliseconds: 100), () => setState(() => buttonClicked = ''));
  }

  void _handleUndo() {
    if (deletedHistory.isNotEmpty) {
      setState(() {
        numbers.insert(0, deletedHistory.removeAt(0));
      });
      _saveData();
    }
  }

  Future<void> _wipeList() async {
    setState(() {
      numbers.clear();
      surface = 1.0;
      weight = 1.8;
      avgOffset = 0.0;
      deletedHistory.clear();
      digitMode = 'XX';
      input = '';
      listNames[selectedList] = selectedList;
    });
    await _saveData();
  }

  void _confirmDelete(int index) {
    setState(() => indexToDelete = index);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete value?', style: TextStyle(color: Colors.red)),
        content: Text('Are you sure you want to delete ${numbers[index]}?',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() {
                deletedHistory.insert(0, numbers.removeAt(indexToDelete!));
              });
              _saveData();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _openConfigDialog() {
    final sC = TextEditingController(text: surface.toString());
    final wC = TextEditingController(text: weight.toString());
    final oC = TextEditingController(text: avgOffset.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Settings', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sC,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Surface (m²)', labelStyle: TextStyle(color: Colors.white)),
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: wC,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Specific Weight', labelStyle: TextStyle(color: Colors.white)),
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: oC,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Average Offset', labelStyle: TextStyle(color: Colors.white)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // WIPE APP
                  TextButton(
                    onPressed: () async {
                      final c1 = await showDialog<bool>(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text('Confirm WIPE APP', style: TextStyle(color: Colors.red)),
                          content: const Text('Erase ALL lists & settings?', style: TextStyle(color: Colors.white)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                          ],
                        ),
                      );
                      if (c1 == true) {
                        final c2 = await showDialog<bool>(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: const Text('ARE YOU SURE?', style: TextStyle(color: Colors.red)),
                            content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, WIPE APP')),
                            ],
                          ),
                        );
                        if (c2 == true) {
                          await _wipeAllStorage();
                          setState(() {
                            listNames.updateAll((k, _) => k);
                            numbersMap.forEach((k, v) => v.clear());
                            surfaceMap.updateAll((_, __) => 1.0);
                            weightMap.updateAll((_, __) => 1.8);
                            offsetMap.updateAll((_, __) => 0.0);
                            selectedList = 'A';
                            input = '';
                            deletedHistory.clear();
                            digitMode = 'XX';
                          });
                        }
                      }
                      Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(backgroundColor: Colors.red.shade700),
                    child: const Text('WIPE APP', style: TextStyle(color: Colors.white)),
                  ),
                  // WIPE LIST
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text('Confirm WIPE LIST', style: TextStyle(color: Colors.red)),
                          content: const Text('Erase this list?', style: TextStyle(color: Colors.white)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _wipeList();
                        Navigator.pop(ctx);
                      }
                    },
                    style: TextButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('WIPE LIST', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                setState(() {
                  surface = double.tryParse(sC.text.replaceAll(',', '.')) ?? surface;
                  weight = double.tryParse(wC.text.replaceAll(',', '.')) ?? weight;
                  avgOffset = double.tryParse(oC.text.replaceAll(',', '.')) ?? avgOffset;
                });
                _saveData();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showListSelector() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.grey[900],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (r) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (c) {
                  final key = String.fromCharCode(65 + r * 3 + c);
                  return GestureDetector(
                    onLongPress: () => _renameListDialog(key, setD),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => selectedList = key);
                        _saveData();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: Text(listNames[key]!),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _renameListDialog(String key, void Function(void Function()) refresh) {
    final ctrl = TextEditingController(text: listNames[key]);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Rename list', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          inputFormatters: [LengthLimitingTextInputFormatter(12)],
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'New name',
            helperText: 'Max 12 characters',
            labelStyle: TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && !listNames.values.contains(newName)) {
                setState(() => listNames[key] = newName);
                _saveData();
                refresh(() {});
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridButton(String label, {bool isDel = false, Color? color, VoidCallback? onPressed}) {
    final clicked = buttonClicked.toLowerCase() == label.toLowerCase();
    return GestureDetector(
      onTap: onPressed ?? () => _handleNumberClick(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isDel
              ? (clicked ? Colors.red.shade700 : Colors.red.shade500)
              : (color != null
                  ? (clicked ? color.withOpacity(0.8) : color)
                  : (clicked ? Colors.blue.shade700 : Colors.blue.shade900)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MODE: $digitMode',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: _showListSelector,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                        ),
                        child: Text(listNames[selectedList]!,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: _handleUndo,
                      icon: SvgPicture.asset('assets/undo.svg', width: 24, height: 24)),
                  IconButton(onPressed: _openConfigDialog,
                      icon: SvgPicture.asset('assets/settings.svg', width: 24, height: 24)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 60,
                    child: _buildGridButton('-', color: Colors.blueGrey, onPressed: _handleMinus),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 60,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.centerRight,
                      child: Text(
                        input.isEmpty ? '0' : input,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2,
                children: [
                  ...List.generate(9, (i) => _buildGridButton((i + 1).toString())),
                  _buildGridButton('0'),
                  _buildGridButton('Del', isDel: true, onPressed: _handleDelete),
                  _buildGridButton('Add', color: Colors.green, onPressed: _handleAdd),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildGridButton('X', color: Colors.orange, onPressed: () => _setDigitMode('X'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildGridButton('XX', color: Colors.orange, onPressed: () => _setDigitMode('XX'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildGridButton('XXX', color: Colors.orange, onPressed: () => _setDigitMode('XXX'))),
                ],
              ),
              const Divider(color: Colors.white24, height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('AVERAGE', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${adjustedAvg.toStringAsFixed(2)} mm',
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ]),
                  Text('${numbers.length}', style: const TextStyle(color: Colors.red, fontSize: 16)),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('CEMENT', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${cement.toStringAsFixed(2)} Kg',
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ]),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 2.5),
                  itemCount: numbers.length,
                  itemBuilder: (context, idx) => GestureDetector(
                    onTap: () => _confirmDelete(idx),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                      child: Text(numbers[idx].toString(), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}