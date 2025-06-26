import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/download/task.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/pages/download/controller.dart';
import 'package:pilipala/utils/utils.dart';

class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onTap;

  const DownloadItem({
    Key? key,
    required this.task,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildCover(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(),
                  const SizedBox(height: 4),
                  _buildInfo(),
                  if (_shouldShowProgress())
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildProgressBar(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  // 构建封面
  Widget _buildCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 80,
        height: 50,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              task.cover,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                );
              },
            ),
            if (task.status == DownloadStatus.paused)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Icon(
                  Icons.pause,
                  color: Colors.white,
                ),
              ),
            if (task.status == DownloadStatus.failed)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                ),
              ),
            if (task.status == DownloadStatus.completed)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建标题
  Widget _buildTitle() {
    return Text(
      task.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 构建信息
  Widget _buildInfo() {
    String info = '';

    // 视频质量
    info += task.videoQuality.description;

    // 文件大小
    if (task.totalBytes > 0) {
      info += ' · ${Utils.formatBytes(task.totalBytes)}';
    }

    // 下载状态
    info += ' · ${_getStatusText()}';

    // 下载速度（仅在下载中显示）
    if (task.status == DownloadStatus.downloading && task.speed > 0) {
      info += ' · ${Utils.formatBytes(task.speed)}/s';
    }

    return Text(
      info,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }

  // 构建进度条
  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: task.progress,
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 4),
        Text(
          '${(task.progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 构建操作按钮
  Widget _buildActionButton() {
    final DownloadController controller = Get.find<DownloadController>();

    if (task.status == DownloadStatus.downloading) {
      return IconButton(
        icon: const Icon(Icons.pause),
        onPressed: () {
          controller.pauseDownload(task.id);
        },
      );
    } else if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.failed) {
      return IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () {
          controller.resumeDownload(task.id);
        },
      );
    } else if (task.status == DownloadStatus.pending) {
      return IconButton(
        icon: const Icon(Icons.cancel),
        onPressed: () {
          controller.cancelDownload(task.id);
        },
      );
    } else if (task.status == DownloadStatus.completed) {
      return IconButton(
        icon: const Icon(Icons.folder_open),
        onPressed: () {
          controller.openDownloadedFile(task.id);
        },
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: onTap,
      );
    }
  }

  // 获取状态文本
  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '下载失败';
      case DownloadStatus.canceled:
        return '已取消';
    }
  }

  // 是否显示进度条
  bool _shouldShowProgress() {
    return task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.pending;
  }
}
