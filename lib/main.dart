import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SmartHR風デザインで使用する色・余白・角丸をまとめた定数クラス。
///
/// 入力:
/// - なし
///
/// 出力:
/// - アプリ全体で再利用するデザイントークン
class SmartHrTokens {
  const SmartHrTokens._();

  static const Color brandBlue = Color(0xFF00C4CC);
  static const Color productMain = Color(0xFF0077C7);
  static const Color link = Color(0xFF0071C1);
  static const Color danger = Color(0xFFE01E5A);
  static const Color warning = Color(0xFFFFCC17);
  static const Color orangeAccent = Color(0xFFFF9900);

  static const Color textBlack = Color(0xFF23221E);
  static const Color textGrey = Color(0xFF706D65);
  static const Color textDisabled = Color(0xFFC1BDB7);

  static const Color stone01 = Color(0xFFF8F7F6);
  static const Color stone02 = Color(0xFFEDEBE8);
  static const Color stone03 = Color(0xFFAAA69F);
  static const Color stone04 = Color(0xFF4E4C49);

  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD6D3D0);
  static const Color overBackground = Color(0xFFF2F1F0);
  static const Color actionBackground = Color(0xFFD6D3D0);

  static const double spacingXs = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXl = 32;

  static const double radiusS = 6;
  static const double radiusM = 10;
  static const double radiusL = 14;

  static const double minTouchTarget = 44;
}

/// Todoデータを表すモデル。
///
/// 入力:
/// - id: SQLiteで自動採番されるID
/// - title: Todoの内容
/// - isDone: 完了状態
/// - createdAt: 作成日時
///
/// 出力:
/// - Todo画面やDB保存に使う1件分のTodoデータ
class Todo {
  const Todo({
    this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final bool isDone;
  final DateTime createdAt;

  /// SQLiteから取得したMapをTodo型へ変換する。
  ///
  /// 入力:
  /// - map: SQLiteから取得した1行分のデータ
  ///
  /// 出力:
  /// - Todoインスタンス
  factory Todo.fromMap(Map<String, Object?> map) {
    final Object? idValue = map['id'];
    final Object? titleValue = map['title'];
    final Object? isDoneValue = map['is_done'];
    final Object? createdAtValue = map['created_at'];

    if (idValue is! int) {
      throw const FormatException('idが不正です。');
    }

    if (titleValue is! String) {
      throw const FormatException('titleが不正です。');
    }

    if (isDoneValue is! int) {
      throw const FormatException('is_doneが不正です。');
    }

    if (createdAtValue is! String) {
      throw const FormatException('created_atが不正です。');
    }

    return Todo(
      id: idValue,
      title: titleValue,
      isDone: isDoneValue == 1,
      createdAt: DateTime.parse(createdAtValue),
    );
  }

  /// 新規作成時にSQLiteへ保存するMapへ変換する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - insert用のMap
  Map<String, Object?> toInsertMap() {
    return <String, Object?>{
      'title': title,
      'is_done': isDone ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 更新時にSQLiteへ保存するMapへ変換する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - update用のMap
  Map<String, Object?> toUpdateMap() {
    return <String, Object?>{
      'title': title,
      'is_done': isDone ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Todoの一部だけを変更した新しいTodoを作る。
  ///
  /// 入力:
  /// - title: 変更後のタイトル
  /// - isDone: 変更後の完了状態
  ///
  /// 出力:
  /// - 変更後のTodoインスタンス
  Todo copyWith({String? title, bool? isDone}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }
}

/// SQLiteの操作をまとめるクラス。
///
/// 入力:
/// - Todoデータ
///
/// 出力:
/// - Todoの作成・取得・更新・削除結果
class TodoDatabase {
  TodoDatabase._internal();

  static final TodoDatabase instance = TodoDatabase._internal();

  static const String _databaseName = 'simple_todo.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'todos';

  Database? _database;

  /// SQLiteデータベースを取得する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - Databaseインスタンス
  Future<Database> get database async {
    final Database? currentDatabase = _database;

    if (currentDatabase != null) {
      return currentDatabase;
    }

    final Database openedDatabase = await _openDatabase();
    _database = openedDatabase;

    return openedDatabase;
  }

  /// SQLiteデータベースを開く。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 初期化済みDatabaseインスタンス
  Future<Database> _openDatabase() async {
    final String databaseDirectoryPath = await getDatabasesPath();
    final String databasePath = p.join(databaseDirectoryPath, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _createDatabase,
    );
  }

  /// 初回起動時にtodosテーブルを作成する。
  ///
  /// 入力:
  /// - db: 作成対象のDatabase
  /// - version: DBバージョン
  ///
  /// 出力:
  /// - なし
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        is_done INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Todoを新規作成する。
  ///
  /// 入力:
  /// - title: Todoの内容
  ///
  /// 出力:
  /// - 作成されたTodo
  Future<Todo> createTodo(String title) async {
    final Database db = await database;

    final Todo todo = Todo(
      title: title,
      isDone: false,
      createdAt: DateTime.now(),
    );

    final int id = await db.insert(
      _tableName,
      todo.toInsertMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return Todo(
      id: id,
      title: todo.title,
      isDone: todo.isDone,
      createdAt: todo.createdAt,
    );
  }

  /// Todo一覧を取得する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - Todoの一覧
  Future<List<Todo>> readTodos() async {
    final Database db = await database;

    final List<Map<String, Object?>> maps = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );

    return maps.map(Todo.fromMap).toList();
  }

  /// Todoを更新する。
  ///
  /// 入力:
  /// - todo: 更新したいTodo
  ///
  /// 出力:
  /// - 更新された件数
  Future<int> updateTodo(Todo todo) async {
    final int? todoId = todo.id;

    if (todoId == null) {
      throw ArgumentError('更新するTodoにはidが必要です。');
    }

    final Database db = await database;

    return db.update(
      _tableName,
      todo.toUpdateMap(),
      where: 'id = ?',
      whereArgs: <Object?>[todoId],
    );
  }

  /// Todoを削除する。
  ///
  /// 入力:
  /// - id: 削除したいTodoのID
  ///
  /// 出力:
  /// - 削除された件数
  Future<int> deleteTodo(int id) async {
    final Database db = await database;

    return db.delete(_tableName, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// データベースを閉じる。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - なし
  Future<void> close() async {
    final Database? currentDatabase = _database;

    if (currentDatabase != null) {
      await currentDatabase.close();
      _database = null;
    }
  }
}

/// アプリの起動処理。
///
/// 入力:
/// - なし
///
/// 出力:
/// - Flutterアプリを起動する
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const TodoApp());
}

/// アプリ全体の設定を行うWidget。
///
/// 入力:
/// - なし
///
/// 出力:
/// - MaterialApp
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  /// アプリ全体のUIを作成する。
  ///
  /// 入力:
  /// - context: BuildContext
  ///
  /// 出力:
  /// - SmartHR風のMaterialApp
  @override
  Widget build(BuildContext context) {
    const TextStyle baseTextStyle = TextStyle(
      color: SmartHrTokens.textBlack,
      fontFamilyFallback: <String>[
        'Yu Gothic',
        'YuGothic',
        'Hiragino Sans',
        'sans-serif',
      ],
      height: 1.5,
      letterSpacing: 0,
    );

    return MaterialApp(
      title: 'SmartHR Style Todo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SmartHrTokens.stone01,
        colorScheme: const ColorScheme.light(
          primary: SmartHrTokens.productMain,
          secondary: SmartHrTokens.brandBlue,
          error: SmartHrTokens.danger,
          surface: SmartHrTokens.white,
          onPrimary: SmartHrTokens.white,
          onSurface: SmartHrTokens.textBlack,
        ),
        textTheme: const TextTheme(
          displayLarge: baseTextStyle,
          displayMedium: baseTextStyle,
          displaySmall: baseTextStyle,
          headlineLarge: TextStyle(
            color: SmartHrTokens.textBlack,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.25,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
          headlineMedium: TextStyle(
            color: SmartHrTokens.textBlack,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
          titleLarge: TextStyle(
            color: SmartHrTokens.textBlack,
            fontSize: 19.2,
            fontWeight: FontWeight.w700,
            height: 1.5,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
          titleMedium: TextStyle(
            color: SmartHrTokens.textBlack,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.5,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
          bodyLarge: baseTextStyle,
          bodyMedium: TextStyle(
            color: SmartHrTokens.textBlack,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
          bodySmall: TextStyle(
            color: SmartHrTokens.textGrey,
            fontSize: 13.7,
            fontWeight: FontWeight.w400,
            height: 1.5,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
          labelSmall: TextStyle(
            color: SmartHrTokens.textGrey,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
            fontFamilyFallback: <String>[
              'Yu Gothic',
              'YuGothic',
              'Hiragino Sans',
              'sans-serif',
            ],
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SmartHrTokens.stone01,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SmartHrTokens.spacingM,
            vertical: SmartHrTokens.spacingS,
          ),
          labelStyle: const TextStyle(
            color: SmartHrTokens.textGrey,
            fontSize: 13.7,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: const TextStyle(
            color: SmartHrTokens.textDisabled,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const TodoPage(),
    );
  }
}

/// Todo一覧画面。
///
/// 入力:
/// - なし
///
/// 出力:
/// - TodoのCRUD画面
class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  /// TodoPageの状態を作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - TodoPageState
  @override
  State<TodoPage> createState() => TodoPageState();
}

/// Todo画面の状態管理。
///
/// 入力:
/// - ユーザー操作
///
/// 出力:
/// - Todo一覧の表示更新
class TodoPageState extends State<TodoPage> {
  final TextEditingController _textController = TextEditingController();

  List<Todo> _todos = <Todo>[];
  bool _isLoading = true;

  /// 画面初期化時にTodo一覧を読み込む。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - Todo一覧の初期表示
  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  /// 使用しているControllerを破棄する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - メモリリークを防ぐ
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// SQLiteからTodo一覧を読み込む。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 画面上のTodo一覧を更新する
  Future<void> _loadTodos() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final List<Todo> todos = await TodoDatabase.instance.readTodos();

    if (!mounted) {
      return;
    }

    setState(() {
      _todos = todos;
      _isLoading = false;
    });
  }

  /// 入力されたTodoを追加する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - Todo追加後に一覧を再読み込みする
  Future<void> _addTodo() async {
    final String title = _textController.text.trim();

    if (title.isEmpty) {
      return;
    }

    await TodoDatabase.instance.createTodo(title);
    _textController.clear();

    await _loadTodos();
  }

  /// Todoの完了状態を切り替える。
  ///
  /// 入力:
  /// - todo: 対象Todo
  ///
  /// 出力:
  /// - 完了状態を更新して一覧を再読み込みする
  Future<void> _toggleTodo(Todo todo) async {
    final Todo updatedTodo = todo.copyWith(isDone: !todo.isDone);

    await TodoDatabase.instance.updateTodo(updatedTodo);
    await _loadTodos();
  }

  /// Todoのタイトルを更新する。
  ///
  /// 入力:
  /// - todo: 対象Todo
  /// - newTitle: 新しいタイトル
  ///
  /// 出力:
  /// - タイトルを更新して一覧を再読み込みする
  Future<void> _updateTodoTitle(Todo todo, String newTitle) async {
    final String trimmedTitle = newTitle.trim();

    if (trimmedTitle.isEmpty) {
      return;
    }

    final Todo updatedTodo = todo.copyWith(title: trimmedTitle);

    await TodoDatabase.instance.updateTodo(updatedTodo);
    await _loadTodos();
  }

  /// Todoを削除する。
  ///
  /// 入力:
  /// - todo: 削除対象Todo
  ///
  /// 出力:
  /// - Todo削除後に一覧を再読み込みする
  Future<void> _deleteTodo(Todo todo) async {
    final int? todoId = todo.id;

    if (todoId == null) {
      return;
    }

    await TodoDatabase.instance.deleteTodo(todoId);
    await _loadTodos();
  }

  /// Todo編集用のダイアログを表示する。
  ///
  /// 入力:
  /// - todo: 編集対象Todo
  ///
  /// 出力:
  /// - ユーザー入力に応じてTodoを更新する
  Future<void> _showEditDialog(Todo todo) async {
    final TextEditingController editController = TextEditingController(
      text: todo.title,
    );

    final String? editedTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: SmartHrTokens.white,
          surfaceTintColor: SmartHrTokens.white,
          title: const Text(
            'Todoを編集',
            style: TextStyle(
              color: SmartHrTokens.textBlack,
              fontSize: 19.2,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Todo',
              hintText: '内容を入力してください',
            ),
            onSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            SmartHrTokens.spacingM,
            0,
            SmartHrTokens.spacingM,
            SmartHrTokens.spacingM,
          ),
          actions: <Widget>[
            SizedBox(
              height: SmartHrTokens.minTouchTarget,
              child: TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: SmartHrTokens.link,
                ),
                child: const Text('キャンセル'),
              ),
            ),
            SizedBox(
              height: SmartHrTokens.minTouchTarget,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(editController.text);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: SmartHrTokens.productMain,
                  foregroundColor: SmartHrTokens.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
                  ),
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );

    editController.dispose();

    if (editedTitle == null) {
      return;
    }

    await _updateTodoTitle(todo, editedTitle);
  }

  /// 未完了Todoの件数を取得する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 未完了のTodo件数
  int get _activeTodoCount {
    return _todos.where((Todo todo) => !todo.isDone).length;
  }

  /// 完了済みTodoの件数を取得する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 完了済みのTodo件数
  int get _doneTodoCount {
    return _todos.where((Todo todo) => todo.isDone).length;
  }

  /// Todo画面全体を作成する。
  ///
  /// 入力:
  /// - context: BuildContext
  ///
  /// 出力:
  /// - スマホ向けSmartHR風Todo画面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartHrTokens.stone01,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildMobileHeader(),
            Expanded(
              child: RefreshIndicator(
                color: SmartHrTokens.productMain,
                onRefresh: _loadTodos,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SmartHrTokens.spacingM,
                    SmartHrTokens.spacingM,
                    SmartHrTokens.spacingM,
                    SmartHrTokens.spacingXl,
                  ),
                  children: <Widget>[
                    _buildSummaryCard(),
                    const SizedBox(height: SmartHrTokens.spacingM),
                    _buildInputCard(),
                    const SizedBox(height: SmartHrTokens.spacingM),
                    _buildSectionTitle(),
                    const SizedBox(height: SmartHrTokens.spacingS),
                    _buildTodoList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// スマホ向けヘッダーを作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 上部固定のヘッダーWidget
  Widget _buildMobileHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: SmartHrTokens.white),
      padding: const EdgeInsets.fromLTRB(
        SmartHrTokens.spacingM,
        SmartHrTokens.spacingS,
        SmartHrTokens.spacingM,
        SmartHrTokens.spacingS,
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: SmartHrTokens.spacingS),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Todo管理',
                  style: TextStyle(
                    color: SmartHrTokens.textBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: SmartHrTokens.minTouchTarget,
            height: SmartHrTokens.minTouchTarget,
            child: IconButton(
              tooltip: '再読み込み',
              onPressed: _loadTodos,
              icon: const Icon(
                Icons.refresh,
                color: SmartHrTokens.stone04,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Todo件数のサマリーカードを作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 合計・未完了・完了数を表示するカード
  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: SmartHrTokens.white,
        borderRadius: BorderRadius.circular(SmartHrTokens.radiusM),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(SmartHrTokens.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '本日のタスク',
            style: TextStyle(
              color: SmartHrTokens.textBlack,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: SmartHrTokens.spacingXs),
          const Text(
            '追加・編集・完了・削除の基本操作を確認できます。',
            style: TextStyle(
              color: SmartHrTokens.textGrey,
              fontSize: 13.7,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: SmartHrTokens.spacingM),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricTile(
                  label: '合計',
                  value: _todos.length.toString(),
                  color: SmartHrTokens.productMain,
                ),
              ),
              const SizedBox(width: SmartHrTokens.spacingS),
              Expanded(
                child: _buildMetricTile(
                  label: '未完了',
                  value: _activeTodoCount.toString(),
                  color: SmartHrTokens.orangeAccent,
                ),
              ),
              const SizedBox(width: SmartHrTokens.spacingS),
              Expanded(
                child: _buildMetricTile(
                  label: '完了',
                  value: _doneTodoCount.toString(),
                  color: SmartHrTokens.brandBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// サマリー内の数値表示を作成する。
  ///
  /// 入力:
  /// - label: 表示ラベル
  /// - value: 表示数値
  /// - color: 強調色
  ///
  /// 出力:
  /// - 1つ分の数値タイル
  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SmartHrTokens.spacingS,
        vertical: SmartHrTokens.spacingS,
      ),
      decoration: BoxDecoration(
        color: SmartHrTokens.stone01,
        borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: SmartHrTokens.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Todo入力カードを作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 入力欄と追加ボタンを持つカード
  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: SmartHrTokens.white,
        borderRadius: BorderRadius.circular(SmartHrTokens.radiusM),
      ),
      padding: const EdgeInsets.all(SmartHrTokens.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '新しいTodoを追加',
            style: TextStyle(
              color: SmartHrTokens.textBlack,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: SmartHrTokens.spacingS),
          TextField(
            controller: _textController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Todo',
              hintText: '例：授業資料を確認する',
            ),
            onSubmitted: (_) => _addTodo(),
          ),
          const SizedBox(height: SmartHrTokens.spacingM),
          SizedBox(
            width: double.infinity,
            height: SmartHrTokens.minTouchTarget,
            child: FilledButton.icon(
              onPressed: _addTodo,
              style: FilledButton.styleFrom(
                backgroundColor: SmartHrTokens.productMain,
                foregroundColor: SmartHrTokens.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: SmartHrTokens.spacingM,
                  vertical: SmartHrTokens.spacingS,
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                '追加する',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Todo一覧の見出しを作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - セクションタイトルWidget
  Widget _buildSectionTitle() {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Todo一覧',
            style: TextStyle(
              color: SmartHrTokens.textBlack,
              fontSize: 19.2,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SmartHrTokens.spacingS,
            vertical: SmartHrTokens.spacingXs,
          ),
          decoration: BoxDecoration(
            color: SmartHrTokens.stone02,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_todos.length}件',
            style: const TextStyle(
              color: SmartHrTokens.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Todo一覧部分を作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 読み込み中、空表示、Todoカード一覧のいずれか
  Widget _buildTodoList() {
    if (_isLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: SmartHrTokens.white,
          borderRadius: BorderRadius.circular(SmartHrTokens.radiusM),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: SmartHrTokens.productMain),
        ),
      );
    }

    if (_todos.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: _todos.map((Todo todo) {
        return Padding(
          padding: const EdgeInsets.only(bottom: SmartHrTokens.spacingS),
          child: _buildTodoCard(todo),
        );
      }).toList(),
    );
  }

  /// Todoが存在しない場合の空状態を作成する。
  ///
  /// 入力:
  /// - なし
  ///
  /// 出力:
  /// - 空状態を説明するカード
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SmartHrTokens.white,
        borderRadius: BorderRadius.circular(SmartHrTokens.radiusM),
      ),
      padding: const EdgeInsets.all(SmartHrTokens.spacingL),
      child: const Column(
        children: <Widget>[
          Icon(Icons.inbox_outlined, color: SmartHrTokens.stone03, size: 40),
          SizedBox(height: SmartHrTokens.spacingS),
          Text(
            'Todoはまだありません',
            style: TextStyle(
              color: SmartHrTokens.textBlack,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          SizedBox(height: SmartHrTokens.spacingXs),
          Text(
            '上の入力欄から最初のTodoを追加してください。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SmartHrTokens.textGrey,
              fontSize: 13.7,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 1件分のTodoカードを作成する。
  ///
  /// 入力:
  /// - todo: 表示対象のTodo
  ///
  /// 出力:
  /// - スマホ向けTodoカード
  Widget _buildTodoCard(Todo todo) {
    final Color statusColor = todo.isDone
        ? SmartHrTokens.brandBlue
        : SmartHrTokens.orangeAccent;

    final String statusText = todo.isDone ? '完了' : '未完了';

    return Container(
      decoration: BoxDecoration(
        color: SmartHrTokens.white,
        borderRadius: BorderRadius.circular(SmartHrTokens.radiusM),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SmartHrTokens.radiusM),
          onTap: () => _toggleTodo(todo),
          child: Padding(
            padding: const EdgeInsets.all(SmartHrTokens.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: SmartHrTokens.minTouchTarget,
                      height: SmartHrTokens.minTouchTarget,
                      child: Checkbox(
                        value: todo.isDone,
                        activeColor: SmartHrTokens.productMain,
                        side: const BorderSide(
                          color: SmartHrTokens.border,
                          width: 1.5,
                        ),
                        onChanged: (_) => _toggleTodo(todo),
                      ),
                    ),
                    const SizedBox(width: SmartHrTokens.spacingS),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          todo.title,
                          style: TextStyle(
                            color: todo.isDone
                                ? SmartHrTokens.textGrey
                                : SmartHrTokens.textBlack,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SmartHrTokens.spacingS),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SmartHrTokens.spacingS,
                        vertical: SmartHrTokens.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor == SmartHrTokens.brandBlue
                              ? SmartHrTokens.productMain
                              : SmartHrTokens.stone04,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: SmartHrTokens.spacingS),
                    Expanded(
                      child: Text(
                        _formatCreatedAt(todo.createdAt),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SmartHrTokens.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SmartHrTokens.spacingS),
                Container(
                  decoration: BoxDecoration(
                    color: SmartHrTokens.stone01,
                    borderRadius: BorderRadius.circular(SmartHrTokens.radiusS),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SmartHrTokens.spacingS,
                    vertical: SmartHrTokens.spacingXs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          height: SmartHrTokens.minTouchTarget,
                          child: TextButton.icon(
                            onPressed: () => _showEditDialog(todo),
                            style: TextButton.styleFrom(
                              foregroundColor: SmartHrTokens.link,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  SmartHrTokens.radiusS,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text(
                              '編集',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: SmartHrTokens.spacingS),
                      Expanded(
                        child: SizedBox(
                          height: SmartHrTokens.minTouchTarget,
                          child: TextButton.icon(
                            onPressed: () => _deleteTodo(todo),
                            style: TextButton.styleFrom(
                              foregroundColor: SmartHrTokens.danger,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  SmartHrTokens.radiusS,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text(
                              '削除',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 作成日時をスマホ表示向けの文字列に変換する。
  ///
  /// 入力:
  /// - createdAt: Todoの作成日時
  ///
  /// 出力:
  /// - yyyy/mm/dd hh:mm 形式の文字列
  String _formatCreatedAt(DateTime createdAt) {
    final DateTime localDateTime = createdAt.toLocal();

    final String year = localDateTime.year.toString();
    final String month = localDateTime.month.toString().padLeft(2, '0');
    final String day = localDateTime.day.toString().padLeft(2, '0');
    final String hour = localDateTime.hour.toString().padLeft(2, '0');
    final String minute = localDateTime.minute.toString().padLeft(2, '0');

    return '作成日時 $year/$month/$day $hour:$minute';
  }
}
