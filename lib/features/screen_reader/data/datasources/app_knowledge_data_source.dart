import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/app_info.dart';

/// App知识库数据源
/// 
/// 负责管理App的预置知识和缓存：
/// 1. 预置知识库（common_apps.json）：常用App的操作指引
/// 2. Hive本地缓存：AI解读结果的缓存
/// 3. 为AI解读提供上下文增强
class AppKnowledgeDataSource {
  Box? _cacheBox;
  Map<String, dynamic>? _preloadedKnowledge;

  static const _cacheBoxName = 'app_knowledge_cache';
  static const _cacheExpiry = Duration(hours: 24);

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    try {
      // 打开Hive缓存Box
      _cacheBox = await Hive.openBox(_cacheBoxName);

      // 预加载App知识库
      await _loadPresetKnowledge();

      AppLogger.info('App知识库初始化完成', tag: 'KnowledgeDS');
    } catch (e) {
      AppLogger.error('知识库初始化失败', tag: 'KnowledgeDS', error: e);
    }
  }

  /// 加载预置的App知识库
  Future<void> _loadPresetKnowledge() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/app_knowledge/common_apps.json',
      );
      _preloadedKnowledge = json.decode(jsonString);
      AppLogger.info(
        '预置知识库加载完成，共${(_preloadedKnowledge?['apps'] as List?)?.length ?? 0}个App',
        tag: 'KnowledgeDS',
      );
    } catch (e) {
      AppLogger.warning('预置知识库加载失败: $e', tag: 'KnowledgeDS');
      _preloadedKnowledge = {'apps': []};
    }
  }

  // ==================== 知识库查询 ====================

  /// 根据包名查询App知识
  Map<String, dynamic>? getAppKnowledge(String packageName) {
    if (_preloadedKnowledge == null) return null;

    final apps = _preloadedKnowledge!['apps'] as List?;
    if (apps == null) return null;

    for (final app in apps) {
      if (app['package_name'] == packageName) {
        return Map<String, dynamic>.from(app);
      }
    }
    return null;
  }

  /// 获取App的页面操作指引
  String? getPageGuide(String packageName, String? activityName) {
    final knowledge = getAppKnowledge(packageName);
    if (knowledge == null) return null;

    final pages = knowledge['pages'] as Map<String, dynamic>?;
    if (pages == null) return null;

    // 尝试匹配Activity名称到页面
    if (activityName != null) {
      final activityLower = activityName.toLowerCase();
      for (final entry in pages.entries) {
        if (activityLower.contains(entry.key)) {
          final page = entry.value as Map<String, dynamic>;
          return '${page['summary']}。${page['elements_guide'] ?? ''}';
        }
      }
    }

    // 默认返回主页面
    if (pages.containsKey('main')) {
      final main = pages['main'] as Map<String, dynamic>;
      return '${main['summary']}。${main['elements_guide'] ?? ''}';
    }

    return null;
  }

  /// 获取App常见操作步骤
  List<Map<String, String>> getCommonOperations(String packageName) {
    final knowledge = getAppKnowledge(packageName);
    if (knowledge == null) return [];

    final operations = knowledge['common_operations'] as List?;
    if (operations == null) return [];

    return operations.map((op) {
      return {
        'action': op['action']?.toString() ?? '',
        'steps': op['steps']?.toString() ?? '',
      };
    }).toList();
  }

  /// 根据App信息生成上下文描述
  String generateContextDescription(AppInfo appInfo) {
    final knowledge = getAppKnowledge(appInfo.packageName);
    if (knowledge != null) {
      final desc = knowledge['description'] ?? '';
      final guide = getPageGuide(appInfo.packageName, appInfo.currentActivity);
      return '当前App：${appInfo.appName}。$desc${guide != null ? "。当前页面：$guide" : ""}';
    }
    return '当前App：${appInfo.appName}（${appInfo.category?.label ?? '未分类'}应用）';
  }

  // ==================== 缓存管理 ====================

  /// 缓存AI解读结果
  Future<void> cacheScreenDescription({
    required String cacheKey,
    required String description,
  }) async {
    try {
      await _cacheBox?.put(cacheKey, {
        'description': description,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      AppLogger.warning('缓存写入失败', tag: 'KnowledgeDS');
    }
  }

  /// 获取缓存的解读结果
  String? getCachedDescription(String cacheKey) {
    try {
      final cached = _cacheBox?.get(cacheKey);
      if (cached == null) return null;

      final data = Map<String, dynamic>.from(cached);
      final timestamp = data['timestamp'] as int;
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // 检查缓存是否过期
      if (DateTime.now().difference(cachedTime) > _cacheExpiry) {
        _cacheBox?.delete(cacheKey);
        return null;
      }

      return data['description'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// 生成缓存key
  String generateCacheKey(String packageName, String? activity) {
    return '${packageName}_${activity ?? 'main'}';
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheBox?.clear();
    AppLogger.info('知识库缓存已清除', tag: 'KnowledgeDS');
  }

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    await _cacheBox?.close();
  }
}
