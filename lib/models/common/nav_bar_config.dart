import 'package:flutter/material.dart';

import '../../pages/dynamics/index.dart';
import '../../pages/download/index.dart';
import '../../pages/home/index.dart';
import '../../pages/media/index.dart';
import '../../pages/rank/index.dart';

List defaultNavigationBars = [
  {
    'id': 0,
    'icon': const Icon(
      Icons.home_outlined,
      size: 21,
    ),
    'selectIcon': const Icon(
      Icons.home,
      size: 21,
    ),
    'label': "首页",
    'count': 0,
    'page': const HomePage(),
  },
  {
    'id': 1,
    'icon': const Icon(
      Icons.trending_up,
      size: 21,
    ),
    'selectIcon': const Icon(
      Icons.trending_up_outlined,
      size: 21,
    ),
    'label': "排行榜",
    'count': 0,
    'page': const RankPage(),
  },
  {
    'id': 2,
    'icon': const Icon(
      Icons.motion_photos_on_outlined,
      size: 21,
    ),
    'selectIcon': const Icon(
      Icons.motion_photos_on,
      size: 21,
    ),
    'label': "动态",
    'count': 0,
    'page': const DynamicsPage(),
  },
  {
    'id': 3,
    'icon': const Icon(
      Icons.video_collection_outlined,
      size: 20,
    ),
    'selectIcon': const Icon(
      Icons.video_collection,
      size: 21,
    ),
    'label': "媒体库",
    'count': 0,
    'page': const MediaPage(),
  },
  {
    'id': 4,
    'icon': const Icon(
      Icons.download_outlined,
      size: 20,
    ),
    'selectIcon': const Icon(
      Icons.download,
      size: 21,
    ),
    'label': "下载",
    'count': 0,
    'page': const DownloadPage(),
  }
];
