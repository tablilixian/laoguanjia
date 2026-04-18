import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// 每日一句页面 - 三种模式切换
/// 
/// 支持：古诗词、励志语录、毒鸡汤
class DailyQuotePage extends StatefulWidget {
  const DailyQuotePage({super.key});

  @override
  State<DailyQuotePage> createState() => _DailyQuotePageState();
}

class _DailyQuotePageState extends State<DailyQuotePage> {
  // 当前模式: poetry(古诗词), inspiration(励志语录), soup(毒鸡汤)
  String _currentMode = 'poetry';
  
  // 当前内容
  String _currentQuote = '';
  String _currentAuthor = '';
  
  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;
  
  // 复制按钮文本
  String _copyBtnText = '复制内容';
  
  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }
  
  /// 获取句子
  Future<void> _fetchQuote() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      String url;
      http.Response response;
      
      switch (_currentMode) {
        case 'poetry':
          // 古诗词 - 今日诗词API
          url = 'https://v1.jinrishici.com/all.json';
          response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            _currentQuote = data['content'] ?? '';
            _currentAuthor = '${data['author']}《${data['origin']}》';
          }
          break;
          
        case 'inspiration':
          // 励志语录 - Hitokoto
          url = 'https://v1.hitokoto.cn/?c=d&c=e&c=k';
          response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            _currentQuote = data['hitokoto'] ?? '';
            final fromWho = data['from_who'];
            final from = data['from'];
            _currentAuthor = fromWho != null && fromWho.isNotEmpty 
                ? '$fromWho《$from》' 
                : from ?? '';
          }
          break;
          
        case 'soup':
          // 毒鸡汤
          url = 'https://api.vvhan.com/api/text/djt';
          response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            _currentQuote = data['data']['content'] ?? '';
            _currentAuthor = '毒鸡汤';
          }
          break;
          
        default:
          throw Exception('未知模式');
      }
      
      if (response.statusCode != 200) {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = '获取失败，请检查网络后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// 切换模式
  void _switchMode(String mode) {
    if (mode == _currentMode) return;
    setState(() {
      _currentMode = mode;
    });
    _fetchQuote();
  }
  
  /// 复制内容
  Future<void> _copyContent() async {
    if (_currentQuote.isEmpty) return;
    
    final textToCopy = '"$_currentQuote" —— $_currentAuthor';
    
    try {
      await Clipboard.setData(ClipboardData(text: textToCopy));
      setState(() {
        _copyBtnText = '已复制 ✓';
      });
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copyBtnText = '复制内容';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('复制失败，请手动复制')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 主题色
    const primaryColor = Color(0xFF667EEA);
    const gradient = LinearGradient(
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    );
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // 顶部背景
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: BoxDecoration(
              gradient: gradient,
            ),
            child: Column(
              children: [
                Text(
                  '✨ 每日一句 ✨',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点亮你的每一天',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          // 模式切换 Tab
          Container(
            color: const Color(0xFFF8F9FA),
            child: Row(
              children: [
                _ModeTab(
                  label: '📜 古诗词',
                  isActive: _currentMode == 'poetry',
                  onTap: () => _switchMode('poetry'),
                ),
                _ModeTab(
                  label: '💪 励志语录',
                  isActive: _currentMode == 'inspiration',
                  onTap: () => _switchMode('inspiration'),
                ),
                _ModeTab(
                  label: '😈 毒鸡汤',
                  isActive: _currentMode == 'soup',
                  onTap: () => _switchMode('soup'),
                ),
              ],
            ),
          ),
          
          // 内容区域
          Expanded(
            child: _buildContent(theme),
          ),
          
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // 刷新按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _fetchQuote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isLoading ? '加载中...' : '换一条',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 复制按钮
                OutlinedButton(
                  onPressed: _currentQuote.isEmpty ? null : _copyContent,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    _copyBtnText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 底部说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Text(
              '数据来源：今日诗词 | Hitokoto一言 | 毒鸡汤API',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建内容区域
  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '😢',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 名言内容
          Text(
            '"$_currentQuote"',
            style: theme.textTheme.titleLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // 作者
          Text(
            '—— $_currentAuthor',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

/// 模式切换 Tab
class _ModeTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  
  const _ModeTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryColor = Color(0xFF667EEA);
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
            color: isActive ? Colors.white : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isActive ? primaryColor : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
    );
  }
}