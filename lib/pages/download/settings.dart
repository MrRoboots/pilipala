import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/pages/download/controller.dart';

class DownloadSettingsPage extends StatelessWidget {
  DownloadSettingsPage({Key? key}) : super(key: key);

  final DownloadController controller = Get.find<DownloadController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载设置'),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          _buildDownloadDirectorySection(),
          const Divider(),
          _buildNetworkSection(),
          const Divider(),
          _buildConcurrentDownloadsSection(),
        ],
      ),
    );
  }

  // 下载目录设置区域
  Widget _buildDownloadDirectorySection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '下载目录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            return Text(
              controller.downloadDirectory.value,
              style: const TextStyle(color: Colors.grey),
            );
          }),
          const SizedBox(height: 8),
          const Text(
            '注意：下载目录不可更改，视频将保存在应用专属目录下，卸载应用后将会被清除。',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // 网络设置区域
  Widget _buildNetworkSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '网络设置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            return SwitchListTile(
              title: const Text('仅在WiFi下下载'),
              subtitle: const Text('开启后，只有在WiFi网络下才会下载视频'),
              value: controller.onlyDownloadOnWifi.value,
              onChanged: (value) {
                controller.setOnlyDownloadOnWifi(value);
              },
            );
          }),
        ],
      ),
    );
  }

  // 同时下载数量设置区域
  Widget _buildConcurrentDownloadsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '同时下载数量',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            return Column(
              children: [
                Slider(
                  value: controller.maxConcurrentDownloads.value.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: controller.maxConcurrentDownloads.value.toString(),
                  onChanged: (value) {
                    controller.setMaxConcurrentDownloads(value.toInt());
                  },
                ),
                Text(
                  '同时下载任务数量: ${controller.maxConcurrentDownloads.value}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  '同时下载的任务数量越多，每个任务的下载速度可能会变慢。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
