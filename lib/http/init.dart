// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

// import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/utils/id_utils.dart';
import '../utils/storage.dart';
import '../utils/utils.dart';
import 'api.dart';
import 'constants.dart';
import 'interceptor.dart';

class Request {
  static final Request _instance = Request._internal();
  static late CookieManager cookieManager;
  static late final Dio dio;

  factory Request() => _instance;
  Box setting = GStrorage.setting;
  static Box localCache = GStrorage.localCache;
  late bool enableSystemProxy;
  late String systemProxyHost;
  late String systemProxyPort;
  static final RegExp spmPrefixExp = RegExp(r'<meta name="spm_prefix" content="([^"]+?)">');
  static String? buvid;

  /// 设置cookie
  static setCookie() async {
    Box userInfoCache = GStrorage.userInfo;
    Box setting = GStrorage.setting;
    final String cookiePath = await Utils.getCookiePath();
    final PersistCookieJar cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(cookiePath),
    );
    cookieManager = CookieManager(cookieJar);
    dio.interceptors.add(cookieManager);
    final List<Cookie> cookie = await cookieManager.cookieJar.loadForRequest(Uri.parse(HttpString.baseUrl));
    final userInfo = userInfoCache.get('userInfoCache');
    if (userInfo != null && userInfo.mid != null) {
      final List<Cookie> cookie2 = await cookieManager.cookieJar.loadForRequest(Uri.parse(HttpString.tUrl));
      if (cookie2.isEmpty) {
        try {
          await Request().get(HttpString.tUrl);
        } catch (e) {
          log("setCookie, ${e.toString()}");
        }
      }
    }
    setOptionsHeaders(userInfo, userInfo != null && userInfo.mid != null);
    String baseUrlType = 'default';
    if (setting.get(SettingBoxKey.enableGATMode, defaultValue: false)) {
      baseUrlType = 'bangumi';
    }
    setBaseUrl(type: baseUrlType);
    try {
      await buvidActivate();
    } catch (e) {
      log("setCookie, ${e.toString()}");
    }

    final String cookieString = cookie.map((Cookie cookie) => '${cookie.name}=${cookie.value}').join('; ');

    dio.options.headers['cookie'] = cookieString;

    // dio.options.headers['cookie'] = '''
// buvid3=BEADE875-57D1-531B-3125-8B4D265A699205287infoc; b_nut=1735796105; _uuid=E9F63D64-D6E7-D1F9-6710F-E73B10BE6C10E505755infoc; buvid4=81AFAF8D-497A-F740-6935-906951E6629306223-025010205-YNA0SA7FbKrIm6CTaUz%2Byw%3D%3D; buvid_fp=65a5ab4ac948ab3d5434717bc294e4b6; rpdid=|(J|)R~Ru|l|0J'u~Jl~mYu|~; header_theme_version=CLOSE; enable_web_push=DISABLE; enable_feed_channel=DISABLE; home_feed_column=5; browser_resolution=1920-824; CURRENT_FNVAL=4048; DedeUserID=301445971; DedeUserID__ckMd5=0609a411e34457a6; CURRENT_QUALITY=116; b_lsid=1D7F1010510_197C9FF189F; bili_ticket=eyJhbGciOiJIUzI1NiIsImtpZCI6InMwMyIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTE3MDAxMTIsImlhdCI6MTc1MTQ0MDg1MiwicGx0IjotMX0.0vr0SP8GrJc-vad7ZqRI3tOuH0XbS9Gfvzx23Usw-bw; bili_ticket_expires=1751700052; SESSDATA=863a8538%2C1766992912%2C01fde%2A72CjCIifWQbseU1Zx8zYO_Kvh1t9Nu9TlhXBxhSIp-IKmQ47NMTnLAutBFEifmeCDWsYESVk04OWQxN1ZvVlFPSnhiMWk1c3lzQVBkV3VzZmpvRmFrZWdIVV81X3FhTG5YRXg3eWl1V29Eel9IQUdQNUI3MHVWV18yaDI4MElUalFDbEg2VDBxRnB3IIEC; bili_jct=c4b1a79d15964b278084536e6b8dfef0; sid=hqek7gga''';
    String csrf = await getCsrf();
    print('csrf: $csrf');
  }

  // 从cookie中获取 csrf token
  static Future<String> getCsrf() async {
    List<Cookie> cookies = await cookieManager.cookieJar.loadForRequest(Uri.parse(HttpString.apiBaseUrl));
    String token = '';
    if (cookies.where((e) => e.name == 'bili_jct').isNotEmpty) {
      token = cookies.firstWhere((e) => e.name == 'bili_jct').value;
    }
    return token;
  }

  static Future<String> getBuvid() async {
    if (buvid != null) {
      return buvid!;
    }

    final List<Cookie> cookies = await cookieManager.cookieJar.loadForRequest(Uri.parse(HttpString.baseUrl));
    buvid = cookies.firstWhere((cookie) => cookie.name == 'buvid3').value;
    if (buvid == null) {
      try {
        var result = await Request().get(
          "${HttpString.apiBaseUrl}/x/frontend/finger/spi",
        );
        buvid = result["data"]["b_3"].toString();
      } catch (e) {
        // 处理请求错误
        buvid = '';
        print("Error fetching buvid: $e");
      }
    }

    return buvid!;
  }

  static setOptionsHeaders(userInfo, bool status) {
    if (status) {
      dio.options.headers['x-bili-mid'] = userInfo.mid.toString();
      dio.options.headers['x-bili-aurora-eid'] = IdUtils.genAuroraEid(userInfo.mid);
    }
    dio.options.headers['env'] = 'prod';
    dio.options.headers['app-key'] = 'android64';
    dio.options.headers['x-bili-aurora-zone'] = 'sh001';
    dio.options.headers['referer'] = 'https://www.bilibili.com/';
  }

  static Future buvidActivate() async {
    var html = await Request().get(Api.dynamicSpmPrefix);
    String spmPrefix = spmPrefixExp.firstMatch(html.data)!.group(1)!;
    Random rand = Random();
    String rand_png_end = base64.encode(List<int>.generate(32, (_) => rand.nextInt(256)) +
        List<int>.filled(4, 0) +
        [73, 69, 78, 68] +
        List<int>.generate(4, (_) => rand.nextInt(256)));

    String jsonData = json.encode({
      '3064': 1,
      '39c8': '${spmPrefix}.fp.risk',
      '3c43': {
        'adca': 'Linux',
        'bfe9': rand_png_end.substring(rand_png_end.length - 50),
      },
    });

    await Request().post(Api.activateBuvidApi, data: {'payload': jsonData}, options: Options(contentType: 'application/json'));
  }

  /*
   * config it and create
   */
  Request._internal() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: HttpString.apiBaseUrl,
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: const Duration(milliseconds: 12000),
      //响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: const Duration(milliseconds: 12000),
      //Http请求头.
      headers: {},
    );

    enableSystemProxy = setting.get(SettingBoxKey.enableSystemProxy, defaultValue: false) as bool;
    systemProxyHost = localCache.get(LocalCacheKey.systemProxyHost, defaultValue: '');
    systemProxyPort = localCache.get(LocalCacheKey.systemProxyPort, defaultValue: '');

    dio = Dio(options);

    /// fix 第三方登录 302重定向 跟iOS代理问题冲突
    // ..httpClientAdapter = Http2Adapter(
    //   ConnectionManager(
    //     idleTimeout: const Duration(milliseconds: 10000),
    //     onClientCreate: (_, ClientSetting config) =>
    //         config.onBadCertificate = (_) => true,
    //   ),
    // );

    /// 设置代理
    if (enableSystemProxy) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient client = HttpClient();
          // Config the client.
          client.findProxy = (Uri uri) {
            // return 'PROXY host:port';
            return 'PROXY $systemProxyHost:$systemProxyPort';
          };
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

    //添加拦截器
    dio.interceptors.add(ApiInterceptor());

    // 日志拦截器 输出请求、响应内容
    dio.interceptors.add(LogInterceptor(
      request: false,
      requestHeader: false,
      responseHeader: false,
    ));

    dio.transformer = BackgroundTransformer();
    dio.options.validateStatus = (int? status) {
      return status! >= 200 && status < 300 || HttpString.validateStatusCodes.contains(status);
    };
  }

  /*
   * get请求
   */
  get(url, {data, options, cancelToken, extra}) async {
    Response response;
    final Options options = Options();
    ResponseType resType = ResponseType.json;
    if (extra != null) {
      resType = extra!['resType'] ?? ResponseType.json;
      if (extra['ua'] != null) {
        options.headers = {'user-agent': headerUa(type: extra['ua'])};
      }
    }
    options.responseType = resType;
    try {
      response = await dio.get(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      Response errResponse = Response(
        data: {'message': await ApiInterceptor.dioError(e)}, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  /*
   * post请求
   */
  post(url, {data, queryParameters, options, cancelToken, extra}) async {
    // print('post-data: $data');
    Response response;
    try {
      response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options ?? Options(contentType: Headers.formUrlEncodedContentType),
        cancelToken: cancelToken,
      );
      // print('post success: ${response.data}');
      return response;
    } on DioException catch (e) {
      Response errResponse = Response(
        data: {'message': await ApiInterceptor.dioError(e)}, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  /*
   * 下载文件
   */
  downloadFile(urlPath, savePath) async {
    Response response;
    try {
      response = await dio.download(urlPath, savePath, onReceiveProgress: (int count, int total) {
        //进度
        // print("$count $total");
      });
      print('downloadFile success: ${response.data}');

      return response.data;
    } on DioException catch (e) {
      print('downloadFile error: $e');
      return Future.error(ApiInterceptor.dioError(e));
    }
  }

  /*
   * 取消请求
   *
   * 同一个cancel token 可以用于多个请求，当一个cancel token取消时，所有使用该cancel token的请求都会被取消。
   * 所以参数可选
   */
  void cancelRequests(CancelToken token) {
    token.cancel("cancelled");
  }

  String headerUa({type = 'mob'}) {
    String headerUa = '';
    if (type == 'mob') {
      if (Platform.isIOS) {
        headerUa =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 14_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1 Mobile/15E148 Safari/604.1';
      } else {
        headerUa =
            'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36';
      }
    } else {
      headerUa = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';
    }
    return headerUa;
  }

  static setBaseUrl({String type = 'default'}) {
    switch (type) {
      case 'default':
        dio.options.baseUrl = HttpString.apiBaseUrl;
        break;
      case 'bangumi':
        dio.options.baseUrl = HttpString.bangumiBaseUrl;
        break;
      default:
        dio.options.baseUrl = HttpString.apiBaseUrl;
    }
  }
}
