import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:desktop_window/desktop_window.dart';   // 新增


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeModel(),
      child: const App(),
    ),
  );
}

/* ================= 主题 ================= */
class ThemeModel with ChangeNotifier {
  bool _dark = false;
  bool get dark => _dark;
  void toggle() {
    _dark = !_dark;
    notifyListeners();
  }

  ThemeData theme(BuildContext context) => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
}

/* ================= 主 App ================= */
class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记事本',
      theme: context.watch<ThemeModel>().theme(context),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      home: const HomePage(),
    );
  }
}

/* ================= 数据 ================= */


class _Doc {
  String name;
  String content;
  _Doc(this.name, this.content);
}
/* ================= 主页 ================= */
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<_Doc> _docs = [_Doc('默认笔记', '')];
  int _index = 0;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  _Doc get doc => _docs[_index];

  /* -------- 基础操作 -------- */
  void _save() => doc.content = _ctrl.text;

  void _new() {
    _save();
    setState(() {
      _docs.add(_Doc('笔记 ${_docs.length + 1}', ''));
      _index = _docs.length - 1;
      _ctrl.text = '';
    });
    SmartDialog.showToast('已新建');
  }

  void _rename() async {
    final ctrl = TextEditingController(text: doc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => doc.name = name);
    SmartDialog.showToast('已重命名');
  }

  void _delete() async {
    if (_docs.length == 1) {
      SmartDialog.showToast('至少保留一篇');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除'),
        content: Text('确定删除「${doc.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _docs.removeAt(_index);
      _index = 0;
      _ctrl.text = _docs.first.content;
    });
    SmartDialog.showToast('已删除');
  }

  /* -------- 另存为 / 导出 -------- */
  void _saveAs() async {
    final ctrl = TextEditingController(text: '${doc.name}_副本');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('另存为'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    _save();
    setState(() {
      _docs.add(_Doc(name, doc.content));
      _index = _docs.length - 1;
    });
    SmartDialog.showToast('已另存');
  }

  void _exportFile() async {
    _save();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${doc.name}.txt');
      await file.writeAsString(doc.content);
      Share.shareXFiles([XFile(file.path)], text: '导出笔记：${doc.name}');
    } catch (e) {
      SmartDialog.showToast('导出失败：$e');
    }
  }

  /* -------- 切换文档 -------- */
  void _showDocList() async {
    _save();
    final idx = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => ListView(
        children: _docs.map((d) => ListTile(
              title: Text(d.name),
              leading: Icon(Icons.insert_drive_file,
                  color: d == doc ? Theme.of(context).colorScheme.primary : null),
              onTap: () => Navigator.pop(context, _docs.indexOf(d)),
            )).toList(),
      ),
    );
    if (idx == null) return;
    setState(() {
      _index = idx;
      _ctrl.text = doc.content;
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl.text = doc.content;
  }

  @override
  void dispose() {
    _save();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name),
        actions: [
          IconButton(icon: const Icon(Icons.save), tooltip: '保存', onPressed: () {_save(); SmartDialog.showToast('已保存');}),
          IconButton(icon: const Icon(Icons.add), tooltip: '新建', onPressed: _new),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'rename': _rename(); break;
                case 'saveAs': _saveAs(); break;
                case 'delete': _delete(); break;
                case 'export': _exportFile(); break;
                case 'theme': context.read<ThemeModel>().toggle(); break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              const PopupMenuItem(value: 'saveAs', child: Text('另存为')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
              const PopupMenuItem(value: 'export', child: Text('导出分享')),
              const PopupMenuItem(value: 'theme', child: Text('切换主题')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '文档列表',
        onPressed: _showDocList,
        child: const Icon(Icons.list),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(border: InputBorder.none, hintText: '开始输入…'),
          onChanged: (_) => _save(),
        ),
      ),
    );
  }
}