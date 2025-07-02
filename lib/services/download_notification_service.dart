import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pilipala/models/download/task.dart';

/// 下载通知服务
/// 负责处理下载相关的通知显示和管理
class DownloadNotificationService {
  // 单例实例
  static final DownloadNotificationService _instance = DownloadNotificationService._internal();
  
  // 工厂构造函数
  factory DownloadNotificationService() => _instance;
  
  // 内部构造函数
  DownloadNotificationService._internal();
  
  // 本地通知插件
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
  // 通知ID映射
  final Map<String, int> _notificationIds = {};
  
  // 是否已初始化
  bool _isInitialized = false;
  
  /// 初始化通知服务
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // 初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: false,
        requestBadgePermission: false,
        requestAlertPermission: false,
      );
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      // 初始化通知插件
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );
      
      // 请求通知权限
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      
      _isInitialized = true;
    } catch (e) {
      print('初始化下载通知服务失败: $e');
    }
  }
  
  /// 显示下载通知
  Future<void> showDownloadNotification(DownloadTask task) async {
    if (!_isInitialized) await init();
    
    // 获取或创建通知ID
    int notificationId = _notificationIds[task.id] ?? task.id.hashCode % 32767;
    _notificationIds[task.id] = notificationId;
    
    // 创建通知详情
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      '下载通知',
      channelDescription: '显示视频下载进度',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: (task.progress * 100).round(),
    );
    
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // 根据任务状态显示不同的通知
    String title = '下载: ${task.title}';
    String body = '';
    
    switch (task.status) {
      case DownloadStatus.downloading:
        // 计算下载速度
        String speedText = '0 KB/s';
        if (task.speed > 0) {
          if (task.speed < 1024) {
            speedText = '${task.speed} B/s';
          } else if (task.speed < 1024 * 1024) {
            speedText = '${(task.speed / 1024).toStringAsFixed(1)} KB/s';
          } else {
            speedText = '${(task.speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
          }
        }
        
        // 计算已下载大小和总大小
        String downloadedText = '0 KB';
        String totalText = '未知';
        
        if (task.downloadedBytes > 0) {
          if (task.downloadedBytes < 1024 * 1024) {
            downloadedText = '${(task.downloadedBytes / 1024).toStringAsFixed(1)} KB';
          } else {
            downloadedText = '${(task.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        }
        
        if (task.totalBytes > 0) {
          if (task.totalBytes < 1024 * 1024) {
            totalText = '${(task.totalBytes / 1024).toStringAsFixed(1)} KB';
          } else {
            totalText = '${(task.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        }
        
        body = '${(task.progress * 100).toStringAsFixed(1)}% | $speedText | $downloadedText/$totalText';
        break;
      case DownloadStatus.paused:
        body = '已暂停 - ${(task.progress * 100).toStringAsFixed(1)}%';
        break;
      case DownloadStatus.completed:
        body = '下载完成';
        break;
      case DownloadStatus.failed:
        body = '下载失败: ${task.errorMessage ?? "未知错误"}';
        break;
      case DownloadStatus.merging:
        body = '正在合并音视频...';
        break;
      default:
        body = '准备下载...';
        break;
    }
    
    // 显示通知
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
    );
  }
  
  /// 取消通知
  Future<void> cancelNotification(String taskId) async {
    final notificationId = _notificationIds[taskId];
    if (notificationId != null) {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      _notificationIds.remove(taskId);
    }
  }
  
  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    _notificationIds.clear();
  }
}