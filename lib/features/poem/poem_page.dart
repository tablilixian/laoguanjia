import 'dart:convert';
import 'dart:math' hide log;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'poem_i18n.dart';
import 'poem_theme.dart';

typedef VoidCallback = void Function();

class PoemPage extends StatefulWidget {
  const PoemPage({super.key});

  @override
  State<PoemPage> createState() => PoemPageState();
}

class PoemPageState extends State<PoemPage> {
  Locale? lcl;
  final GlobalKey _one = GlobalKey();
  final GlobalKey _two = GlobalKey();
  final GlobalKey _three = GlobalKey();
  final GlobalKey _four = GlobalKey();
  final GlobalKey _five = GlobalKey();
  final GlobalKey _six = GlobalKey();
  final GlobalKey _seven = GlobalKey();
  final GlobalKey _body = GlobalKey();

  bool shownEn = false;
  bool showPinyin = false;
  List<bool> checkList = List.filled(13, false);
  bool simplifiedChinese = true;
  bool pinyinStyle1 = true;
  bool showAbout = false;
  dynamic poemJson;
  dynamic choosePoem;
  List<PCharacter> pickCharacters = [];
  List<List<PCharacter>> rowsCharacters = [];
  late Future<SharedPreferences> _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = SharedPreferences.getInstance();
    _loadPoems();
  }

  Future<void> _loadPoems() async {
    try {
      final String res = await rootBundle.loadString('assets/poem/chinese_poems.json');
      final decoded = jsonDecode(res);
      if (mounted) {
        setState(() {
          poemJson = decoded;
          _initPoem();
        });
      }
    } catch (e) {
      debugPrint('Error loading poems: $e');
    }
  }

  void _initPoem() {
    if (poemJson == null || poemJson.isEmpty) return;
    
    final random = Random();
    choosePoem = poemJson[random.nextInt(poemJson.length)];
    final paragraphsCns = choosePoem['paragraphs_cns'];
    final paragraphsCnt = choosePoem['paragraphs_cnt'];

    pickCharacters.clear();
    for (int i = 0; i < paragraphsCns.length; i++) {
      final krctCns = paragraphsCns[i].split("");
      final krctCnt = paragraphsCnt[i].split("");
      for (int idx = 0; idx < krctCns.length; idx++) {
        if (!isPunctuate(krctCns[idx])) {
          pickCharacters.add(PCharacter(krctCns[idx], krctCnt[idx], '', ''));
        }
      }
    }
    rowsCharacters = List.generate(paragraphsCns.length, (_) => []);
    pickCharacters.shuffle();

    _prefs.then((SharedPreferences prefs) {
      bool showcaseview = prefs.getBool('poem_showcaseview') ?? true;
      if (showcaseview && mounted) {
        prefs.setBool('poem_showcaseview', false);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ShowCaseWidget.of(context).startShowCase([_one, _two, _three, _four, _five, _six, _seven]),
        );
      }
    });
  }

  bool isPunctuate(String s) {
    return s == '，' || s == '。' || s == '？' || s == '！' || s == '；' || s == "：" || s == "、" || s == "·";
  }

  void changePoem() {
    setState(() {
      pickCharacters.clear();
      var checked = checkList.where((c) => c).toList();
      var candidates = poemJson;
      if (checked.isNotEmpty) {
        candidates = poemJson.where((e) {
          if (checkList[0]) {
            if (e['is300'] == 1) return true;
          }
          if (checkList[e['grade']]) return true;
          return false;
        }).toList();
      }
      if (candidates.isEmpty) candidates = poemJson;
      
      var poemNames = candidates.map((e) => e['title_cns'] ?? '未知').toList();
      debugPrint('=== 筛选后的古诗列表 (共${candidates.length}首) ===');
      debugPrint(poemNames.join(', '));
      
      choosePoem = candidates[Random().nextInt(candidates.length)];
      var paragraphsCns = choosePoem['paragraphs_cns'];
      var paragraphsCnt = choosePoem['paragraphs_cnt'];

      for (int i = 0; i < paragraphsCns.length; i++) {
        var krctCns = paragraphsCns[i].split("");
        var krctCnt = paragraphsCnt[i].split("");
        for (int idx = 0; idx < krctCns.length; idx++) {
          if (!isPunctuate(krctCns[idx])) {
            pickCharacters.add(PCharacter(krctCns[idx], krctCnt[idx], '', ''));
          }
        }
      }
      pickCharacters.shuffle();
      rowsCharacters = List.generate(paragraphsCns.length, (_) => []);
    });
  }

  void updateState(VoidCallback fn) {
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    lcl ??= const Locale('zh', '');
    
    return MaterialApp(
      locale: lcl,
      onGenerateTitle: (ctx) => PoemLocalizations.of(ctx).title,
      localizationsDelegates: const [
        PoemLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('zh', ''),
      ],
      theme: ThemeData(
        colorScheme: chineseStyle15,
        useMaterial3: true,
      ),
      home: Builder(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(PoemLocalizations.of(ctx).title),
            backgroundColor: Theme.of(ctx).colorScheme.inversePrimary,
            leading: Builder(
              builder: (leadingCtx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(leadingCtx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
          drawer: PoemDrawerWidget(state: this, ctx: ctx),
          body: ShowCaseWidget(
            onStart: (index, key) {},
            onComplete: (index, key) {
              if (index == 4) {
                SystemChrome.setSystemUIOverlayStyle(
                  SystemUiOverlayStyle.light.copyWith(
                    statusBarIconBrightness: Brightness.dark,
                    statusBarColor: Colors.white,
                  ),
                );
              }
            },
            blurValue: 1,
            builder: (showcaseCtx) => PoemGameWidget(state: this, ctx: showcaseCtx),
            autoPlayDelay: const Duration(seconds: 3),
          ),
        ),
      ),
    );
  }
}

class PoemGameWidget extends StatelessWidget {
  final PoemPageState state;
  final BuildContext ctx;

  const PoemGameWidget({super.key, required this.state, required this.ctx});

  @override
  Widget build(BuildContext context) {
    if (state.choosePoem == null) {
      return const Center(child: CircularProgressIndicator());
    }

    ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ctrler = ScrollController(initialScrollOffset: 0);

    return Scaffold(
      drawer: PoemDrawerWidget(state: state, ctx: ctx),
      body: Container(
        padding: const EdgeInsets.all(1),
        child: Stack(key: state._body, children: [
          Flex(
            direction: Axis.vertical,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTitle(colorScheme),
                    _buildAuthor(context, colorScheme),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Scrollbar(
                  controller: ctrler,
                  scrollbarOrientation: ScrollbarOrientation.right,
                  child: SingleChildScrollView(
                    controller: ctrler,
                    scrollDirection: Axis.vertical,
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(spacing: 5, children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [..._buildParagraphs(colorScheme)],
                      ),
                    ]),
                  ),
                ),
              ),
              _buildPickArea(colorScheme),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Showcase(
              key: state._seven,
              description: PoemLocalizations.of(ctx).change,
              disableDefaultTargetGestures: true,
              child: FloatingActionButton(
                mini: true,
                onPressed: () => state.changePoem(),
                child: const Icon(Icons.refresh),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTitle(ColorScheme colorScheme) {
    final titleCns = state.choosePoem['title_cns'].split("");
    final titleCnt = state.choosePoem['title_cnt'].split("");
    final titlePy1 = state.choosePoem['title_py1'].split(" ");
    final titlePy2 = state.choosePoem['title_py2'].split(" ");
    final titleEn = state.choosePoem['title_en'];
    
    List<Widget> krctList = [];
    for (int i = 0; i < titleCns.length; i++) {
      final c = PCharacter(titleCns[i], titleCnt[i], titlePy1[i], titlePy2[i]);
      c.isPunctuate = state.isPunctuate(c.txtCns);
      krctList.add(_buildCharacter(c, colorScheme));
    }
    
    return Row(children: [
      Expanded(
        child: Column(children: [
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: krctList,
            ),
          ),
          _buildEnRow(titleEn, colorScheme),
        ]),
      ),
    ]);
  }

  Widget _buildAuthor(BuildContext context, ColorScheme colorScheme) {
    final authorCns = state.choosePoem['author_cns'].split("");
    final authorCnt = state.choosePoem['author_cnt'].split("");
    final authorPy1 = state.choosePoem['author_py1'].split(" ");
    final authorPy2 = state.choosePoem['author_py2'].split(" ");
    final authorEn = state.choosePoem['author_en'];
    
    List<PCharacter> krctList = [];
    for (int i = 0; i < authorCns.length; i++) {
      krctList.add(PCharacter(authorCns[i], authorCnt[i], authorPy1[i], authorPy2[i]));
    }

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Expanded(
        child: Column(children: [
          FittedBox(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                height: 60,
                alignment: Alignment.bottomRight,
                child: Wrap(children: [
                  SizedBox.fromSize(size: Size(24, 24)),
                  Showcase(
                    key: state._one,
                    description: PoemLocalizations.of(ctx).english,
                    descriptionAlignment: TextAlign.center,
                    child: IconButton(
                      tooltip: PoemLocalizations.of(ctx).english,
                      icon: state.shownEn
                          ? Icon(Icons.explicit, color: colorScheme.tertiary)
                          : Icon(Icons.explicit_outlined, color: colorScheme.tertiary),
                      onPressed: () => state.updateState(() => state.shownEn = !state.shownEn),
                    ),
                  ),
                  Showcase(
                    key: state._two,
                    description: PoemLocalizations.of(ctx).pinyin,
                    disableDefaultTargetGestures: true,
                    child: IconButton(
                      tooltip: PoemLocalizations.of(ctx).pinyin,
                      icon: state.showPinyin
                          ? Icon(Icons.fiber_pin, color: colorScheme.error)
                          : Icon(Icons.fiber_pin_outlined, color: colorScheme.error),
                      onPressed: () => state.updateState(() => state.showPinyin = !state.showPinyin),
                    ),
                  ),
                ]),
              ),
              ...krctList.map((c) => _buildCharacter(c, colorScheme)),
              Container(
                height: 60,
                alignment: Alignment.bottomRight,
                child: Wrap(children: [
                  Showcase(
                    key: state._three,
                    description: PoemLocalizations.of(ctx).next,
                    disableDefaultTargetGestures: true,
                    child: IconButton(
                      tooltip: PoemLocalizations.of(ctx).next,
                      icon: const Icon(Icons.navigate_next),
                      onPressed: _showNextCharacter,
                    ),
                  ),
                  Showcase(
                    key: state._four,
                    description: PoemLocalizations.of(ctx).random,
                    disableDefaultTargetGestures: true,
                    child: IconButton(
                      tooltip: PoemLocalizations.of(ctx).random,
                      icon: const Icon(Icons.tune),
                      onPressed: _showRandomCharacters,
                    ),
                  ),
                  Showcase(
                    key: state._five,
                    description: PoemLocalizations.of(ctx).answer,
                    disableDefaultTargetGestures: true,
                    child: IconButton(
                      tooltip: PoemLocalizations.of(ctx).answer,
                      icon: Icon(Icons.lightbulb_circle, color: colorScheme.outline),
                      onPressed: _showAnswer,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          _buildEnRow(authorEn, colorScheme),
        ]),
      ),
    ]);
  }

  void _showNextCharacter() {
    state.updateState(() {
      for (int r = 0; r < state.rowsCharacters.length; r++) {
        for (int idx = 0; idx < state.rowsCharacters[r].length; idx++) {
          final rc = state.rowsCharacters[r][idx];
          if (!rc.visibable && !state.isPunctuate(rc.txtCns)) {
            rc.visibable = true;
            state.pickCharacters.removeWhere((element) => element.txtCns == rc.txtCns);
            return;
          }
        }
      }
    });
  }

  void _showRandomCharacters() {
    state.updateState(() {
      for (int r = 0; r < state.rowsCharacters.length; r++) {
        for (int idx = 0; idx < state.rowsCharacters[r].length; idx++) {
          final rc = state.rowsCharacters[r][idx];
          if (!rc.visibable && !state.isPunctuate(rc.txtCns)) {
            int r = Random().nextInt(5);
            if (r == 0) {
              rc.visibable = true;
              state.pickCharacters.removeWhere((element) => element.txtCns == rc.txtCns);
            }
          }
        }
      }
    });
  }

  void _showAnswer() {
    state.updateState(() {
      for (int r = 0; r < state.rowsCharacters.length; r++) {
        for (int idx = 0; idx < state.rowsCharacters[r].length; idx++) {
          if (!state.rowsCharacters[r][idx].visibable) {
            state.rowsCharacters[r][idx].visibable = true;
          }
        }
      }
      state.pickCharacters.clear();
    });
  }

  Widget _buildCharacter(PCharacter c, ColorScheme colorScheme) {
    return c.isPunctuate
        ? Container(
            width: 16,
            height: 50,
            alignment: Alignment.bottomCenter,
            child: Text(c.txtCns, style: const TextStyle(fontSize: 14)),
          )
        : Padding(
            padding: const EdgeInsets.all(4),
            child: Flex(
              direction: Axis.vertical,
              children: [
                Container(
                  width: 32,
                  height: 16,
                  alignment: Alignment.center,
                  child: Visibility(
                    visible: state.showPinyin,
                    child: Text(
                      state.pinyinStyle1 ? c.pinyin1 : c.pinyin2,
                      style: TextStyle(color: colorScheme.error, fontSize: 10),
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  color: colorScheme.secondary,
                  child: Text(
                    state.simplifiedChinese ? c.txtCns : c.txtCnt,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildEnRow(String enTxt, ColorScheme colorScheme) {
    return Row(children: [
      Expanded(
        child: Container(
          alignment: Alignment.center,
          child: Visibility(
            visible: state.shownEn,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                alignment: Alignment.center,
                width: 350,
                color: colorScheme.tertiary,
                child: Text(
                  enTxt,
                  style: TextStyle(fontSize: 13, color: colorScheme.secondary),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _buildParagraphs(ColorScheme colorScheme) {
    final paragraphsCns = state.choosePoem['paragraphs_cns'];
    final paragraphsCnt = state.choosePoem['paragraphs_cnt'];
    final paragraphsPy1 = state.choosePoem['paragraphs_py1'];
    final paragraphsPy2 = state.choosePoem['paragraphs_py2'];
    final paragraphsEn = state.choosePoem['paragraphs_en'];
    
    List<Widget> rows = [];
    for (int rowIdx = 0; rowIdx < paragraphsCns.length; rowIdx++) {
      rows.add(_buildParagraphRow(
        rowIdx,
        paragraphsCns[rowIdx],
        paragraphsCnt[rowIdx],
        paragraphsPy1[rowIdx],
        paragraphsPy2[rowIdx],
        paragraphsEn[rowIdx],
        colorScheme,
      ));
    }
    return rows;
  }

  Widget _buildParagraphRow(
    int rowIdx, String rowCns, String rowCnt, String rowPy1, String rowPy2, String rowEn, ColorScheme colorScheme) {
    final kractsCns = rowCns.split("");
    final kractsCnt = rowCnt.split("");
    final pinyin1 = rowPy1.split(" ");
    final pinyin2 = rowPy2.split(" ");
    
    List<PCharacter> krctList;
    if (state.rowsCharacters[rowIdx].isEmpty) {
      krctList = [];
      for (int i = 0; i < kractsCns.length; i++) {
        final c = PCharacter(kractsCns[i], kractsCnt[i], pinyin1[i], pinyin2[i]);
        c.isPunctuate = state.isPunctuate(c.txtCns);
        krctList.add(c);
      }
      state.rowsCharacters[rowIdx] = krctList;
    } else {
      krctList = state.rowsCharacters[rowIdx];
    }

    List<Widget> rowList = krctList.map((c) {
      if (c.isPunctuate) {
        return Container(
          width: 20,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: Text(c.txtCns),
        );
      }
      
      return Padding(
        padding: const EdgeInsets.all(5),
        child: Flex(
          direction: Axis.vertical,
          children: [
            Container(
              width: 40,
              height: 20,
              alignment: Alignment.center,
              child: Visibility(
                visible: state.showPinyin,
                child: FittedBox(
                  child: Text(
                    state.pinyinStyle1 ? c.pinyin1 : c.pinyin2,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ),
            ),
            DragTarget<String>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  color: colorScheme.secondary,
                  child: Visibility(
                    visible: c.visibable,
                    child: Text(
                      state.simplifiedChinese ? c.txtCns : c.txtCnt,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              },
              onWillAcceptWithDetails: (details) => details.data == c.txtCns || details.data == c.txtCnt,
              onAcceptWithDetails: (details) => _onCharacterDropped(c, details.data),
            ),
          ],
        ),
      );
    }).toList();

    return Row(children: [
      Expanded(
        child: Column(children: [
          FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: rowList,
            ),
          ),
          _buildEnRow(rowEn, colorScheme),
        ]),
      ),
    ]);
  }

  void _onCharacterDropped(PCharacter c, String s) {
    state.updateState(() {
      c.visibable = true;
      state.pickCharacters.removeWhere((element) => element.txtCns == s || element.txtCnt == s);
      
      bool allComplete = true;
      for (int r = 0; r < state.rowsCharacters.length; r++) {
        for (int idx = 0; idx < state.rowsCharacters[r].length; idx++) {
          if (!state.rowsCharacters[r][idx].isPunctuate && !state.rowsCharacters[r][idx].visibable) {
            allComplete = false;
            break;
          }
        }
      }
      
      if (allComplete) {
        showDialog(
          context: ctx,
          builder: (dialogContext) => AlertDialog(
            title: Text(PoemLocalizations.of(dialogContext).congratulations),
            content: Text(PoemLocalizations.of(dialogContext).succeed),
          ),
        );
      }
    });
  }

  Widget _buildPickArea(ColorScheme colorScheme) {
    List<Widget> dragList = [];
    for (int i = 0; i < state.pickCharacters.length; i++) {
      var c = state.simplifiedChinese
          ? state.pickCharacters[i].txtCns
          : state.pickCharacters[i].txtCnt;
      
      var drag = Draggable<String>(
        data: c,
        feedback: Container(
          width: 36,
          height: 36,
          color: const Color.fromARGB(255, 243, 239, 239).withValues(alpha: 0.5),
          alignment: Alignment.center,
          child: Text(c, style: const TextStyle(fontSize: 24)),
        ),
        child: GestureDetector(
          onDoubleTap: () => _onCharacterTapped(i, c),
          child: Container(
            width: 32,
            height: 32,
            color: const Color.fromARGB(255, 243, 239, 239),
            alignment: Alignment.topCenter,
            child: Text(c, style: const TextStyle(fontSize: 20)),
          ),
        ),
      );
      dragList.add(drag);
    }

    if (dragList.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> wrap1children = dragList.sublist(0, dragList.length ~/ 2);
    List<Widget> wrap2children = dragList.sublist(dragList.length ~/ 2);
    final ctrler = ScrollController(initialScrollOffset: 0);
    
    return Expanded(
      flex: 2,
      child: Scrollbar(
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thumbVisibility: true,
        controller: ctrler,
        child: SingleChildScrollView(
          controller: ctrler,
          scrollDirection: Axis.horizontal,
          child: Showcase(
            key: state._six,
            description: PoemLocalizations.of(ctx).pick,
            disableDefaultTargetGestures: true,
            child: GestureDetector(
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(1.0),
                      child: Wrap(spacing: 5, children: wrap1children),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Wrap(spacing: 5, children: wrap2children),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCharacterTapped(int index, String c) {
    state.updateState(() {
      for (int r = 0; r < state.rowsCharacters.length; r++) {
        for (int idx = 0; idx < state.rowsCharacters[r].length; idx++) {
          final rc = state.rowsCharacters[r][idx];
          if (rc.txtCns == c || rc.txtCnt == c) {
            if (!rc.visibable) {
              rc.visibable = true;
              state.pickCharacters.removeAt(index);
              return;
            }
          }
        }
      }
    });
  }
}

class PoemDrawerWidget extends StatelessWidget {
  final PoemPageState state;
  final BuildContext ctx;

  const PoemDrawerWidget({super.key, required this.state, required this.ctx});

  @override
  Widget build(BuildContext context) {
    var drawerHeader = UserAccountsDrawerHeader(
      accountName: const Text(""),
      accountEmail: const Text(""),
      currentAccountPicture: CircleAvatar(
        child: Image.asset("assets/poem/poem.png"),
      ),
      onDetailsPressed: () => state.updateState(() => state.showAbout = !state.showAbout),
    );

    var about = Column(children: [
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(2),
            alignment: Alignment.topCenter,
            child: Text(PoemLocalizations.of(context).about),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Text(PoemLocalizations.of(context).aboutLine1),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Text(PoemLocalizations.of(context).aboutLine2),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Text(PoemLocalizations.of(context).aboutLine3),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Text(PoemLocalizations.of(context).aboutLine4),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Text(PoemLocalizations.of(context).aboutLine5),
          ),
        ),
      ]),
    ]);

    var buttonRow = FittedBox(
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _press(context, 0),
            icon: const Icon(Icons.translate),
            label: Text(PoemLocalizations.of(context).language),
          ),
          TextButton.icon(
            onPressed: () => _press(context, 1),
            icon: const Icon(Icons.format_shapes),
            label: Text(
              state.simplifiedChinese
                  ? PoemLocalizations.of(context).traditional
                  : PoemLocalizations.of(context).simplified,
            ),
          ),
          TextButton.icon(
            onPressed: () => _press(context, 2),
            icon: state.pinyinStyle1
                ? const Icon(Icons.looks_one)
                : const Icon(Icons.looks_two),
            label: Text(PoemLocalizations.of(context).pinyinStyle),
          ),
        ],
      ),
    );

    List<Widget> tileList = [];
    for (int i = 0; i < 13; i++) {
      final tile = ListTile(
        title: Text(PoemLocalizations.of(context).getGrade(i)),
        leading: state.checkList[i]
            ? const Icon(Icons.check_circle)
            : const Icon(Icons.check_circle_outline),
        onTap: () => state.updateState(() => state.checkList[i] = !state.checkList[i]),
      );
      tileList.add(tile);
    }

    final drawerItems = state.showAbout
        ? ListView(children: [drawerHeader, about])
        : ListView(children: [drawerHeader, buttonRow, ...tileList]);

    return Drawer(child: drawerItems);
  }

  void _press(BuildContext context, int type) {
    if (type == 0) {
      String currentLanguageCode = PoemLocalizations.of(context).locale.languageCode;
      Locale newLocale;
      if ("zh" == currentLanguageCode) {
        newLocale = const Locale('en', '');
      } else {
        newLocale = const Locale('zh', '');
      }
      state.updateState(() => state.lcl = newLocale);
    } else if (type == 1) {
      state.updateState(() => state.simplifiedChinese = !state.simplifiedChinese);
    } else if (type == 2) {
      state.updateState(() => state.pinyinStyle1 = !state.pinyinStyle1);
    }
  }
}

class PCharacter {
  String txtCns;
  String txtCnt;
  String pinyin1;
  String pinyin2;
  bool visibable = false;
  bool isPunctuate = false;
  PCharacter(this.txtCns, this.txtCnt, this.pinyin1, this.pinyin2);
}
