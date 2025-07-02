import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/download/task.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

class DownloadService extends GetxService {
  static DownloadService get to => Get.find<DownloadService>();

  // 下载任务列表
  final RxList<DownloadTask> downloadTasks = <DownloadTask>[].obs;

  // 下载中的任务数量
  final RxInt downloadingCount = 0.obs;

  // 最大同时下载数量
  final RxInt maxConcurrentDownloads = 3.obs;

  // 下载目录
  final RxString downloadDirectory = ''.obs;

  // 是否仅在WiFi下下载
  final RxBool onlyDownloadOnWifi = true.obs;

  // 下载任务存储
  late Box<Map> downloadTaskBox;

  // 下载任务计时器
  Map<String, Timer> _downloadTimers = {};

  // 下载任务取消令牌
  Map<String, CancelToken> _cancelTokens = {};

  // 初始化服务
  Future<DownloadService> init() async {
    try {
      // 初始化下载任务存储
      downloadTaskBox = await Hive.openBox<Map>('downloadTasks');

      // 加载下载设置
      Box setting = GStrorage.setting;
      maxConcurrentDownloads.value =
          setting.get('maxConcurrentDownloads', defaultValue: 3);
      onlyDownloadOnWifi.value =
          setting.get('onlyDownloadOnWifi', defaultValue: true);

      // 获取下载目录
      await _initDownloadDirectory();

      // 加载已有下载任务
      _loadDownloadTasks();

      return this;
    } catch (e) {
      print('初始化下载服务失败: $e');
      return this;
    }
  }

  // 初始化下载目录
  Future<void> _initDownloadDirectory() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          // 创建PiliPala/Download目录
          String newPath = "${directory.path}/PiliPala/Download";
          directory = Directory(newPath);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
        // 创建PiliPala/Download目录
        String newPath = "${directory.path}/PiliPala/Download";
        directory = Directory(newPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }

      if (directory != null) {
        downloadDirectory.value = directory.path;
      } else {
        throw Exception('无法获取下载目录');
      }
    } catch (e) {
      print('初始化下载目录失败: $e');
      SmartDialog.showToast('初始化下载目录失败: $e');
    }
  }

  // 加载已有下载任务
  void _loadDownloadTasks() {
    try {
      final tasks = downloadTaskBox.values.toList();
      for (var taskMap in tasks) {
        try {
          final task =
              DownloadTask.fromJson(Map<String, dynamic>.from(taskMap));
          downloadTasks.add(task);

          // 恢复未完成的下载任务状态为暂停
          if (task.status == DownloadStatus.downloading) {
            task.status = DownloadStatus.paused;
          }
          // 如果文件不存在，则将任务状态设置为失败
          if (task.filePath != null && !File(task.filePath!).existsSync()) {
            task.status = DownloadStatus.failed;
            task.errorMessage = '文件不存在';
          }
        } catch (e) {
          print('加载下载任务失败: $e');
        }
      }

      // 更新下载中任务数量
      _updateDownloadingCount();
    } catch (e) {
      print('加载下载任务列表失败: $e');
    }
  }

  // 更新下载中任务数量
  void _updateDownloadingCount() {
    downloadingCount.value = downloadTasks
        .where((task) => task.status == DownloadStatus.downloading)
        .length;
  }

  // 保存下载任务
  Future<void> _saveDownloadTask(DownloadTask task) async {
    try {
      await downloadTaskBox.put(task.id, task.toJson());
    } catch (e) {
      print('保存下载任务失败: $e');
    }
  }

  // 删除下载任务
  Future<void> _deleteDownloadTask(String taskId) async {
    try {
      await downloadTaskBox.delete(taskId);
    } catch (e) {
      print('删除下载任务失败: $e');
    }
  }

  // 创建下载任务
  Future<DownloadTask?> createDownloadTask({
    required String bvid,
    required int cid,
    required String title,
    required String cover,
    required VideoQuality videoQuality,
    AudioQuality? audioQuality,
  }) async {
    try {
      // 检查权限
      if (!await _checkStoragePermission()) {
        return null;
      }

      // 获取视频URL
      final videoUrlResult =
          await VideoHttp.videoUrl(bvid: bvid, cid: cid, qn: videoQuality.code);
      if (!videoUrlResult['status']) {
        SmartDialog.showToast('获取视频URL失败: ${videoUrlResult['msg']}');
        return null;
      }

      final PlayUrlModel playUrlModel = videoUrlResult['data'];

      // 创建下载任务ID
      final String taskId = const Uuid().v4();

      // 创建下载任务
      DownloadTask task;

      if (playUrlModel.dash != null) {
        // Dash格式，需要分别下载视频和音频
        final List<VideoItem> videoList = playUrlModel.dash!.video!
            .where((i) => i.id == videoQuality.code)
            .toList();

        if (videoList.isEmpty) {
          SmartDialog.showToast('未找到指定质量的视频');
          return null;
        }

        final VideoItem videoItem = videoList.first;

        // 获取音频URL
        AudioItem? audioItem;
        if (playUrlModel.dash!.audio != null &&
            playUrlModel.dash!.audio!.isNotEmpty) {
          audioItem = playUrlModel.dash!.audio!.firstWhere(
              (i) => i.id == audioQuality?.code,
              orElse: () => playUrlModel.dash!.audio!.first);
        }
        String videoUrl = videoItem.baseUrl!;

        // 获取音频URL
        String? audioUrl;
        if (audioQuality != null && playUrlModel.dash!.audio != null) {
          final AudioItem audioItem = playUrlModel.dash!.audio!.firstWhere(
            (i) => i.id == audioQuality.code,
            orElse: () => playUrlModel.dash!.audio!.first,
          );
          audioUrl = audioItem.baseUrl;
        }

        task = DownloadTask(
          id: taskId,
          bvid: bvid,
          cid: cid,
          title: title,
          cover: cover,
          videoUrl: videoUrl,
          audioUrl: audioItem?.baseUrl, // 添加音频URL
          videoQuality: videoQuality,
          audioQuality: audioQuality, // 添加音频质量
          createTime: DateTime.now(),
          status: DownloadStatus.pending,
        );
      } else if (playUrlModel.durl != null && playUrlModel.durl!.isNotEmpty) {
        // Durl格式，直接下载完整视频
        final String videoUrl = playUrlModel.durl!.first.url!;

        task = DownloadTask(
          id: taskId,
          bvid: bvid,
          cid: cid,
          title: title,
          cover: cover,
          videoUrl: videoUrl,
          videoQuality: videoQuality,
          createTime: DateTime.now(),
          status: DownloadStatus.pending,
        );
      } else {
        SmartDialog.showToast('不支持的视频格式');
        return null;
      }

      // 添加到下载任务列表
      downloadTasks.add(task);

      // 保存下载任务
      await _saveDownloadTask(task);

      // 开始下载
      startDownload(task.id);

      return task;
    } catch (e) {
      print('创建下载任务失败: $e');
      SmartDialog.showToast('创建下载任务失败: $e');
      return null;
    }
  }

  // 检查权限
  /// 检查存储权限
  Future<bool> _checkStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        bool isGranted = false;

        // 根据Android SDK版本请求不同的权限
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 32) {
          // Android 12及以下使用storage权限
          isGranted = await Permission.storage.request().isGranted;
        } else {
          // Android 13及以上使用photos权限
          isGranted = await Permission.photos.request().isGranted;
        }

        if (!isGranted) {
          SmartDialog.showToast('需要存储权限才能下载视频');
          return false;
        }
      }
      return true;
    } catch (e) {
      SmartDialog.showToast('检查权限失败: $e');
      return false;
    }
  }

  // 开始下载任务
  Future<void> startDownload(String taskId) async {
    try {
      // 查找任务
      final taskIndex = downloadTasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) {
        return;
      }

      final task = downloadTasks[taskIndex];

      // 检查是否已经在下载中
      if (task.status == DownloadStatus.downloading) {
        return;
      }

      // 检查是否达到最大同时下载数
      if (downloadingCount.value >= maxConcurrentDownloads.value) {
        // 将任务状态设置为等待
        task.status = DownloadStatus.pending;
        downloadTasks[taskIndex] = task;
        await _saveDownloadTask(task);
        return;
      }

      // 更新任务状态
      task.status = DownloadStatus.downloading;
      downloadTasks[taskIndex] = task;
      await _saveDownloadTask(task);

      // 更新下载中任务数量
      _updateDownloadingCount();

      // 创建下载目录
      final String videoFileName =
          '${task.title}_${task.bvid}_${task.cid}_${task.videoQuality.code}.mp4';
      final String videoFilePath = '${downloadDirectory.value}/$videoFileName';

      // 创建取消令牌
      final CancelToken cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      // 创建计时器，用于更新下载速度
      int lastDownloadedBytes = task.downloadedBytes;
      _downloadTimers[taskId] =
          Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentTask =
            downloadTasks.firstWhere((t) => t.id == taskId, orElse: () => task);
        final int bytesDownloaded =
            currentTask.downloadedBytes - lastDownloadedBytes;
        lastDownloadedBytes = currentTask.downloadedBytes;

        // 更新下载速度
        final updatedTask = currentTask..speed = bytesDownloaded;
        final taskIndex = downloadTasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          downloadTasks[taskIndex] = updatedTask;
        }
      });

      try {
        // 开始下载视频
        await Dio().download(
          task.videoUrl,
          videoFilePath,
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'user-agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
              'referer': 'https://www.bilibili.com'
            },
            responseType: ResponseType.stream,
          ),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              // 更新下载进度
              final progress = received / total;
              final updatedTask = task
                ..progress = progress
                ..totalBytes = total
                ..downloadedBytes = received;

              final taskIndex = downloadTasks.indexWhere((t) => t.id == taskId);
              if (taskIndex != -1) {
                downloadTasks[taskIndex] = updatedTask;
              }

              // 保存下载任务
              _saveDownloadTask(updatedTask);
            }
          },
        );

        // 如果有音频URL，下载音频并合并
        if (task.audioUrl != null) {
          final String audioFileName =
              '${task.title}_${task.bvid}_${task.cid}_${task.audioQuality!.code}.m4a';
          final String audioFilePath =
              '${downloadDirectory.value}/$audioFileName';

          // 下载音频
          await Dio().download(
            task.audioUrl!,
            audioFilePath,
            cancelToken: cancelToken,
            options: Options(
              headers: {
                'user-agent':
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
                'referer': 'https://www.bilibili.com'
              },
              responseType: ResponseType.stream,
            ),
          );

          // 合并视频和音频
          final String outputFileName =
              '${task.title}_${task.bvid}_${task.cid}_${task.videoQuality.code}_merged.mp4';
          final String outputFilePath =
              '${downloadDirectory.value}/$outputFileName';

          final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
          final int rc = await _flutterFFmpeg.execute(
              "-i \"$videoFilePath\" -i \"$audioFilePath\" -c:v copy -c:a aac -strict experimental \"$outputFilePath\"");
          if (rc == 0) {
            print('FFmpeg process completed successfully.');
            // 删除原始视频和音频文件
            await File(videoFilePath).delete();
            await File(audioFilePath).delete();
            // 更新任务文件路径为合并后的文件
            task.filePath = outputFilePath;
          } else {
            print('FFmpeg process failed with exit code $rc');
            throw Exception('视频音频合并失败');
          }
        } else {
          task.filePath = videoFilePath;
        }

        // 下载完成，更新任务状态
        final completedTask = task
          ..status = DownloadStatus.completed
          ..progress = 1.0
          ..completeTime = DateTime.now()
          ..filePath = task.filePath;

        final taskIndex = downloadTasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          downloadTasks[taskIndex] = completedTask;
        }

        // 保存下载任务
        await _saveDownloadTask(completedTask);

        // 清理计时器和取消令牌
        _cleanupDownloadResources(taskId);

        // 更新下载中任务数量
        _updateDownloadingCount();

        // 检查是否有等待中的任务可以开始下载
        _startPendingDownloads();

        // 显示下载完成通知
        SmartDialog.showToast('${task.title} 下载完成');
      } catch (e) {
        // 检查是否是用户取消的下载
        if (cancelToken.isCancelled) {
          return;
        }

        // 下载失败，更新任务状态
        final failedTask = task
          ..status = DownloadStatus.failed
          ..errorMessage = e.toString();

        final taskIndex = downloadTasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          downloadTasks[taskIndex] = failedTask;
        }

        // 保存下载任务
        await _saveDownloadTask(failedTask);

        // 清理计时器和取消令牌
        _cleanupDownloadResources(taskId);

        // 更新下载中任务数量
        _updateDownloadingCount();

        // 检查是否有等待中的任务可以开始下载
        _startPendingDownloads();

        // 显示下载失败通知
        SmartDialog.showToast('${task.title} 下载失败: $e');
      }
    } catch (e) {
      print('开始下载任务失败: $e');
      SmartDialog.showToast('开始下载任务失败: $e');
    }
  }

  // 清理下载资源
  void _cleanupDownloadResources(String taskId) {
    // 取消计时器
    _downloadTimers[taskId]?.cancel();
    _downloadTimers.remove(taskId);

    // 移除取消令牌
    _cancelTokens.remove(taskId);
  }

  // 开始等待中的下载任务
  void _startPendingDownloads() {
    // 检查是否有等待中的任务
    final pendingTasks = downloadTasks
        .where((task) => task.status == DownloadStatus.pending)
        .toList();

    // 计算可以开始的任务数量
    final availableSlots =
        maxConcurrentDownloads.value - downloadingCount.value;

    // 开始下载等待中的任务
    for (int i = 0; i < availableSlots && i < pendingTasks.length; i++) {
      startDownload(pendingTasks[i].id);
    }
  }

  // 暂停下载任务
  Future<void> pauseDownload(String taskId) async {
    try {
      // 查找任务
      final taskIndex = downloadTasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) {
        return;
      }

      final task = downloadTasks[taskIndex];

      // 检查是否正在下载中
      if (task.status != DownloadStatus.downloading) {
        return;
      }

      // 取消下载
      _cancelTokens[taskId]?.cancel('用户暂停下载');

      // 清理计时器和取消令牌
      _cleanupDownloadResources(taskId);

      // 更新任务状态
      task.status = DownloadStatus.paused;
      downloadTasks[taskIndex] = task;

      // 保存下载任务
      await _saveDownloadTask(task);

      // 更新下载中任务数量
      _updateDownloadingCount();

      // 检查是否有等待中的任务可以开始下载
      _startPendingDownloads();
    } catch (e) {
      print('暂停下载任务失败: $e');
      SmartDialog.showToast('暂停下载任务失败: $e');
    }
  }

  // 恢复下载任务
  Future<void> resumeDownload(String taskId) async {
    try {
      // 查找任务
      final taskIndex = downloadTasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) {
        return;
      }

      final task = downloadTasks[taskIndex];

      // 检查是否已暂停
      if (task.status != DownloadStatus.paused &&
          task.status != DownloadStatus.failed) {
        return;
      }

      // 将任务状态设置为等待
      task.status = DownloadStatus.pending;
      downloadTasks[taskIndex] = task;

      // 保存下载任务
      await _saveDownloadTask(task);

      // 开始下载
      startDownload(taskId);
    } catch (e) {
      print('恢复下载任务失败: $e');
      SmartDialog.showToast('恢复下载任务失败: $e');
    }
  }

  // 取消下载任务
  Future<void> cancelDownload(String taskId) async {
    try {
      // 查找任务
      final taskIndex = downloadTasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) {
        return;
      }

      final task = downloadTasks[taskIndex];

      // 取消下载
      _cancelTokens[taskId]?.cancel('用户取消下载');

      // 清理计时器和取消令牌
      _cleanupDownloadResources(taskId);

      // 更新任务状态
      task.status = DownloadStatus.canceled;
      downloadTasks[taskIndex] = task;

      // 保存下载任务
      await _saveDownloadTask(task);

      // 更新下载中任务数量
      _updateDownloadingCount();

      // 检查是否有等待中的任务可以开始下载
      _startPendingDownloads();
    } catch (e) {
      print('取消下载任务失败: $e');
      SmartDialog.showToast('取消下载任务失败: $e');
    }
  }

  // 删除下载任务
  Future<void> deleteDownload(String taskId, {bool deleteFile = false}) async {
    try {
      // 查找任务
      final taskIndex = downloadTasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) {
        return;
      }

      final task = downloadTasks[taskIndex];

      // 如果任务正在下载中，先取消下载
      if (task.status == DownloadStatus.downloading) {
        await cancelDownload(taskId);
      }

      // 如果需要删除文件
      if (deleteFile && task.filePath != null) {
        final file = File(task.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // 从列表中移除任务
      downloadTasks.removeAt(taskIndex);

      // 从存储中删除任务
      await _deleteDownloadTask(taskId);
    } catch (e) {
      print('删除下载任务失败: $e');
      SmartDialog.showToast('删除下载任务失败: $e');
    }
  }

  // 设置最大同时下载数量
  Future<void> setMaxConcurrentDownloads(int count) async {
    try {
      maxConcurrentDownloads.value = count;

      // 保存设置
      Box setting = GStrorage.setting;
      await setting.put('maxConcurrentDownloads', count);

      // 检查是否有等待中的任务可以开始下载
      _startPendingDownloads();
    } catch (e) {
      print('设置最大同时下载数量失败: $e');
    }
  }

  // 设置是否仅在WiFi下下载
  Future<void> setOnlyDownloadOnWifi(bool value) async {
    try {
      onlyDownloadOnWifi.value = value;

      // 保存设置
      Box setting = GStrorage.setting;
      await setting.put('onlyDownloadOnWifi', value);
    } catch (e) {
      print('设置是否仅在WiFi下下载失败: $e');
    }
  }

  // 获取下载任务
  DownloadTask? getDownloadTask(String taskId) {
    try {
      return downloadTasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }

  // 获取所有下载任务
  List<DownloadTask> getAllDownloadTasks() {
    return downloadTasks.toList();
  }

  // 获取下载中的任务
  List<DownloadTask> getDownloadingTasks() {
    return downloadTasks
        .where((task) => task.status == DownloadStatus.downloading)
        .toList();
  }

  // 获取等待中的任务
  List<DownloadTask> getPendingTasks() {
    return downloadTasks
        .where((task) => task.status == DownloadStatus.pending)
        .toList();
  }

  // 获取已完成的任务
  List<DownloadTask> getCompletedTasks() {
    return downloadTasks
        .where((task) => task.status == DownloadStatus.completed)
        .toList();
  }

  // 获取失败的任务
  List<DownloadTask> getFailedTasks() {
    return downloadTasks
        .where((task) => task.status == DownloadStatus.failed)
        .toList();
  }

  // 获取已暂停的任务
  List<DownloadTask> getPausedTasks() {
    return downloadTasks
        .where((task) => task.status == DownloadStatus.paused)
        .toList();
  }

  // 获取已取消的任务
  List<DownloadTask> getCanceledTasks() {
    return downloadTasks
        .where((task) => task.status == DownloadStatus.canceled)
        .toList();
  }

  // 清理服务资源
  @override
  void onClose() {
    // 取消所有计时器
    for (final timer in _downloadTimers.values) {
      timer.cancel();
    }
    _downloadTimers.clear();

    // 取消所有下载
    for (final cancelToken in _cancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('服务关闭');
      }
    }
    _cancelTokens.clear();

    super.onClose();
  }
}
