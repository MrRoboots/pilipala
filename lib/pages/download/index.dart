import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/download/task.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/pages/download/controller.dart';
import 'package:pilipala/pages/download/widgets/download_item.dart';
import 'package:pilipala/utils/utils.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin {
  final DownloadController controller = Get.put(DownloadController());
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '下载中'),
            Tab(text: '已完成'),
            Tab(text: '全部'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Get.toNamed('/download/settings');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDownloadingList(),
          _buildCompletedList(),
          _buildAllList(),
        ],
      ),
    );
  }

  // 构建下载中列表（包括等待中、下载中、暂停的任务）
  Widget _buildDownloadingList() {
    return Obx(() {
      final downloadingTasks = controller.downloadingTasks;
      final pendingTasks = controller.pendingTasks;
      final pausedTasks = controller.pausedTasks;

      final allTasks = [...downloadingTasks, ...pendingTasks, ...pausedTasks];

      if (allTasks.isEmpty) {
        return _buildEmptyView('没有正在下载的任务');
      }

      return ListView.builder(
        itemCount: allTasks.length,
        itemBuilder: (context, index) {
          return DownloadItem(
            task: allTasks[index],
            onTap: () => _showTaskDetail(allTasks[index]),
          );
        },
      );
    });
  }

  // 构建已完成列表（包括已完成和已取消的任务）
  Widget _buildCompletedList() {
    return Obx(() {
      final completedTasks = controller.completedTasks;
      final canceledTasks = controller.canceledTasks;

      final allTasks = [...completedTasks, ...canceledTasks];

      if (allTasks.isEmpty) {
        return _buildEmptyView('没有已完成的下载任务');
      }

      return ListView.builder(
        itemCount: allTasks.length,
        itemBuilder: (context, index) {
          return DownloadItem(
            task: allTasks[index],
            onTap: () => _showTaskDetail(allTasks[index]),
          );
        },
      );
    });
  }

  // 构建全部列表
  Widget _buildAllList() {
    return Obx(() {
      final allTasks = controller.allTasks;

      if (allTasks.isEmpty) {
        return _buildEmptyView('没有下载任务');
      }

      return ListView.builder(
        itemCount: allTasks.length,
        itemBuilder: (context, index) {
          return DownloadItem(
            task: allTasks[index],
            onTap: () => _showTaskDetail(allTasks[index]),
          );
        },
      );
    });
  }

  // 构建空视图
  Widget _buildEmptyView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.download_done_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 显示任务详情
  void _showTaskDetail(DownloadTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTaskInfo(task),
              const SizedBox(height: 16),
              _buildTaskActions(task),
            ],
          ),
        );
      },
    );
  }

  // 构建任务信息
  Widget _buildTaskInfo(DownloadTask task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem('BV号', task.bvid),
        _buildInfoItem('创建时间', Utils.formatTime2(task.createTime)),
        if (task.completeTime != null)
          _buildInfoItem('完成时间', Utils.formatTime2(task.completeTime!)),
        _buildInfoItem('视频质量', task.videoQuality.description),
        if (task.audioQuality != null)
          _buildInfoItem('音频质量', task.audioQuality!.description),
        _buildInfoItem('状态', _getStatusText(task.status)),
        if (task.totalBytes > 0)
          _buildInfoItem(
              '大小', '${Utils.formatBytes(task.totalBytes, decimals: 2)}'),
        if (task.filePath != null && task.status == DownloadStatus.completed)
          _buildInfoItem('保存路径', task.filePath!),
        if (task.errorMessage != null && task.status == DownloadStatus.failed)
          _buildInfoItem('错误信息', task.errorMessage!),
      ],
    );
  }

  // 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 构建任务操作按钮
  Widget _buildTaskActions(DownloadTask task) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (task.status == DownloadStatus.downloading)
          _buildActionButton(
            icon: Icons.pause,
            label: '暂停',
            onPressed: () {
              controller.pauseDownload(task.id);
              Navigator.pop(context);
            },
          ),
        if (task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.failed)
          _buildActionButton(
            icon: Icons.play_arrow,
            label: '继续',
            onPressed: () {
              controller.resumeDownload(task.id);
              Navigator.pop(context);
            },
          ),
        if (task.status == DownloadStatus.pending)
          _buildActionButton(
            icon: Icons.cancel,
            label: '取消',
            onPressed: () {
              controller.cancelDownload(task.id);
              Navigator.pop(context);
            },
          ),
        if (task.status == DownloadStatus.completed)
          _buildActionButton(
            icon: Icons.folder_open,
            label: '打开',
            onPressed: () {
              controller.openDownloadedFile(task.id);
              Navigator.pop(context);
            },
          ),
        _buildActionButton(
          icon: Icons.delete,
          label: '删除',
          onPressed: () {
            _showDeleteConfirmDialog(task);
          },
        ),
      ],
    );
  }

  // 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteConfirmDialog(DownloadTask task) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除下载任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除「${task.title}」吗？'),
              if (task.status == DownloadStatus.completed)
                const SizedBox(
                  height: 16,
                  child: CheckboxListTile(
                    title: Text('同时删除文件'),
                    value: true,
                    onChanged: null,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                controller.deleteDownload(task.id, deleteFile: true);
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // 获取状态文本
  String _getStatusText(DownloadStatus status) {
    switch (status) {
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
      case DownloadStatus.merging:
        return '合并中';
    }
  }
}
