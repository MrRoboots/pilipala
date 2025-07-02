import 'package:pilipala/models/video/play/quality.dart';

enum DownloadStatus {
  pending, // 等待下载
  downloading, // 下载中
  paused, // 暂停
  completed, // 完成
  failed, // 失败
  canceled, // 取消
  merging // 合并中
}

enum DownloadType {
  video, // 视频
  audio, // 音频
  combined // 合并后的视频
}

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.videoUrl,
    this.audioUrl,
    required this.videoQuality,
    this.audioQuality,
    required this.createTime,
    this.completeTime,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.filePath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.speed = 0,
    this.errorMessage,
  });

  String id; // 下载任务ID
  String bvid; // 视频BV号
  int cid; // 视频分P的ID
  String title; // 视频标题
  String cover; // 视频封面
  String videoUrl; // 视频URL
  String? audioUrl; // 音频URL（dash格式需要）
  VideoQuality videoQuality; // 视频质量
  AudioQuality? audioQuality; // 音频质量
  DateTime createTime; // 创建时间
  DateTime? completeTime; // 完成时间
  double progress; // 下载进度（0.0-1.0）
  DownloadStatus status; // 下载状态
  String? filePath; // 保存路径
  int totalBytes; // 总字节数
  int downloadedBytes; // 已下载字节数
  int speed; // 下载速度（字节/秒）
  String? errorMessage; // 错误信息

  // 从JSON创建下载任务
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      bvid: json['bvid'],
      cid: json['cid'],
      title: json['title'],
      cover: json['cover'],
      videoUrl: json['videoUrl'],
      audioUrl: json['audioUrl'],
      videoQuality: VideoQualityCode.fromCode(json['videoQuality']) ??
          VideoQuality.high720,
      audioQuality: json['audioQuality'] != null
          ? AudioQualityCode.fromCode(json['audioQuality'])
          : null,
      createTime: DateTime.parse(json['createTime']),
      completeTime: json['completeTime'] != null
          ? DateTime.parse(json['completeTime'])
          : null,
      progress: json['progress'],
      status: DownloadStatus.values[json['status']],
      filePath: json['filePath'],
      totalBytes: json['totalBytes'],
      downloadedBytes: json['downloadedBytes'],
      speed: json['speed'],
      errorMessage: json['errorMessage'],
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bvid': bvid,
      'cid': cid,
      'title': title,
      'cover': cover,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'videoQuality': videoQuality.code,
      'audioQuality': audioQuality?.code,
      'createTime': createTime.toIso8601String(),
      'completeTime': completeTime?.toIso8601String(),
      'progress': progress,
      'status': status.index,
      'filePath': filePath,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'speed': speed,
      'errorMessage': errorMessage,
    };
  }
}
