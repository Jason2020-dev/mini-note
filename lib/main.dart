import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:desktop_window/desktop_window.dart';   // 新增
import 'package:file_picker/file_picker.dart';

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
  String extension; // Add file extension property
  _Doc(this.name, this.content, [this.extension = 'txt']);

  Map<String, dynamic> toJson() => {
        'name': name,
        'content': content,
        'extension': extension,
      };

  static _Doc fromJson(Map<String, dynamic> json) => _Doc(
        json['name'],
        json['content'],
        json['extension'] ?? 'txt',
      );
}
/* ================= 主页 ================= */
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<_Doc> _docs = [];
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
    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = '${dir.path}/${doc.name}_副本.${doc.extension}';
    final ctrl = TextEditingController(text: defaultPath);

    final path = await showDialog<String>(
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

    if (path == null || path.isEmpty) return;

    try {
      _save();
      final file = File(path);
      await file.writeAsString(doc.content);
      SmartDialog.showToast('已另存到 $path');
    } catch (e) {
      SmartDialog.showToast('另存失败：$e');
    }
  }

  void _changeExtension() async {
    final ctrl = TextEditingController(text: doc.extension);
    final ext = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('更改文件后缀'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (ext == null || ext.isEmpty) return;
    setState(() => doc.extension = ext);
    SmartDialog.showToast('后缀已更改');
  }

  void _exportFile() async {
    _save();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${doc.name}.${doc.extension}');
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
              title: Text('${d.name}.${d.extension}'), // 显示文件名和后缀
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

  void _loadDocs() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/docs.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      setState(() {
        _docs.addAll((data as List).map((e) => _Doc.fromJson(e)));
      });
    }
  }

  void _saveDocs() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/docs.json');
    await file.writeAsString(jsonEncode(_docs));
  }

  void _openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'json'], // 限制可打开的文件类型
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final name = file.uri.pathSegments.last.split('.').first;
      final extension = file.uri.pathSegments.last.split('.').last;

      setState(() {
        _docs.add(_Doc(name, content, extension));
        _index = _docs.length - 1;
        _ctrl.text = content;
      });

      SmartDialog.showToast('已打开文件：${file.uri.pathSegments.last}');
    } catch (e) {
      SmartDialog.showToast('打开文件失败：$e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDocs(); // Load saved documents on app start
    if (_docs.isEmpty) {
      _docs.add(_Doc('默认笔记', ''));
    }
    _ctrl.text = doc.content;
  }

  @override
  void dispose() {
    _save();
    _saveDocs(); // Save documents on app close
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
          IconButton(icon: const Icon(Icons.folder_open), tooltip: '打开', onPressed: _openFile), // 添加“打开”按钮
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'rename': _rename(); break;
                case 'saveAs': _saveAs(); break;
                case 'delete': _delete(); break;
                case 'export': _exportFile(); break;
                case 'theme': context.read<ThemeModel>().toggle(); break;
                case 'changeExtension': _changeExtension(); break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              const PopupMenuItem(value: 'saveAs', child: Text('另存为')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
              const PopupMenuItem(value: 'export', child: Text('导出分享')),
              const PopupMenuItem(value: 'theme', child: Text('切换主题')),
              const PopupMenuItem(value: 'changeExtension', child: Text('更改文件后缀')), // Add menu item
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