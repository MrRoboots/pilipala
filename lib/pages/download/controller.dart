import 'dart:io';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:pilipala/models/download/task.dart';
import 'package:pilipala/services/download_service.dart';

class DownloadController extends GetxController {
  final DownloadService _downloadService = DownloadService.to;

  // 所有下载任务
  RxList<DownloadTask> get allTasks => _downloadService.downloadTasks;

  // 下载中的任务
  List<DownloadTask> get downloadingTasks =>
      _downloadService.getDownloadingTasks();

  // 等待中的任务
  List<DownloadTask> get pendingTasks => _downloadService.getPendingTasks();

  // 已完成的任务
  List<DownloadTask> get completedTasks => _downloadService.getCompletedTasks();

  // 失败的任务
  List<DownloadTask> get failedTasks => _downloadService.getFailedTasks();

  // 已暂停的任务
  List<DownloadTask> get pausedTasks => _downloadService.getPausedTasks();

  // 已取消的任务
  List<DownloadTask> get canceledTasks => _downloadService.getCanceledTasks();

  // 下载目录
  RxString get downloadDirectory => _downloadService.downloadDirectory;

  // 最大同时下载数量
  RxInt get maxConcurrentDownloads => _downloadService.maxConcurrentDownloads;

  // 是否仅在WiFi下下载
  RxBool get onlyDownloadOnWifi => _downloadService.onlyDownloadOnWifi;

  // 暂停下载
  Future<void> pauseDownload(String taskId) async {
    await _downloadService.pauseDownload(taskId);
  }

  // 恢复下载
  Future<void> resumeDownload(String taskId) async {
    await _downloadService.resumeDownload(taskId);
  }

  // 取消下载
  Future<void> cancelDownload(String taskId) async {
    await _downloadService.cancelDownload(taskId);
  }

  // 删除下载
  Future<void> deleteDownload(String taskId, {bool deleteFile = false}) async {
    await _downloadService.deleteDownload(taskId, deleteFile: deleteFile);
  }

  // 设置最大同时下载数量
  Future<void> setMaxConcurrentDownloads(int count) async {
    await _downloadService.setMaxConcurrentDownloads(count);
  }

  // 设置是否仅在WiFi下下载
  Future<void> setOnlyDownloadOnWifi(bool value) async {
    await _downloadService.setOnlyDownloadOnWifi(value);
  }

  // 打开已下载的文件
  Future<void> openDownloadedFile(String taskId) async {
    try {
      final task = _downloadService.getDownloadTask(taskId);
      if (task == null || task.filePath == null) {
        SmartDialog.showToast('找不到文件');
        return;
      }

      final file = File(task.filePath!);
      if (!await file.exists()) {
        SmartDialog.showToast('文件不存在');
        return;
      }

      final result = await OpenFile.open(task.filePath!);
      if (result.type != ResultType.done) {
        SmartDialog.showToast('无法打开文件: ${result.message}');
      }
    } catch (e) {
      SmartDialog.showToast('打开文件失败: $e');
    }
  }
}
