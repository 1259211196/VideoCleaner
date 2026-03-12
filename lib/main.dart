import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

// 引入我们的武器库
import 'script_manager.dart';

void main() {
  runApp(const VideoCleanerApp());
}

class VideoCleanerApp extends StatelessWidget {
  const VideoCleanerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '洗白脚本',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // 极简纯黑背景
        primarySwatch: Colors.grey,
      ),
      home: const CleanerHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CleanerHome extends StatefulWidget {
  const CleanerHome({Key? key}) : super(key: key);

  @override
  State<CleanerHome> createState() => _CleanerHomeState();
}

class _CleanerHomeState extends State<CleanerHome> {
  // 核心状态变量
  final List<String> _scripts = ["莫比乌斯环 (重构/静音)", "冷冽精钢版 (原画幅视觉强化 + 隐形声纹洗白)"];
  String _selectedScript = "莫比乌斯环 (重构/静音)";
  
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusText = "准备就绪";

  final ImagePicker _picker = ImagePicker();

  // 请求权限
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.storage,
    ].request();
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  // 核心洗白流水线
  Future<void> _startCleaning() async {
    if (!await _requestPermissions()) {
      setState(() => _statusText = "❌ 缺少相册权限，请在设置中开启");
      return;
    }

    // 1. 从相册提取原视频
    final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusText = "🔍 正在扫描视频底层结构...";
    });

    final String inputPath = pickedFile.path;
    
    // 2. 使用 FFprobe 探针提取视频的元数据（时长、宽高）
    double duration = 0.0;
    int width = 0;
    int height = 0;
    
    final mediaInfoSession = await FFprobeKit.getMediaInformation(inputPath);
    final mediaInfo = mediaInfoSession.getMediaInformation();
    
    if (mediaInfo != null) {
      duration = double.tryParse(mediaInfo.getDuration() ?? "0") ?? 0.0;
      final streams = mediaInfo.getStreams();
      for (var stream in streams) {
        if (stream.getType() == "video") {
          width = stream.getWidth() ?? 0;
          height = stream.getHeight() ?? 0;
          break;
        }
      }
    }

    if (duration <= 3.0 && _selectedScript.contains("莫比乌斯环")) {
      setState(() {
        _isProcessing = false;
        _statusText = "❌ 视频短于3秒，无法使用莫比乌斯环，请更换方案";
      });
      return;
    }

    // 3. 准备临时输出车间
    final Directory extDir = await getTemporaryDirectory();
    final String outputPath = '${extDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 4. 从武器库获取纯正 FFmpeg 指令
    final String command = ScriptManager.getCommand(
      scriptType: _selectedScript,
      inputPath: inputPath,
      outputPath: outputPath,
      duration: duration,
      origW: width,
      origH: height,
    );

    setState(() => _statusText = "🔥 引擎轰鸣中，正在进行底层重构...");

    // 5. 唤醒 FFmpeg 硬件加速引擎开始处理
    await FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          // 6. 处理成功，保存回相册
          setState(() => _statusText = "📥 正在安全写入相册...");
          await Gal.putVideo(outputPath);
          
          // 擦除缓存垃圾
          try {
            File(outputPath).deleteSync();
            File(inputPath).deleteSync(); // 删除ImagePicker产生的缓存拷贝
          } catch (e) {}

          setState(() {
            _isProcessing = false;
            _progress = 1.0;
            _statusText = "✅ 洗白完成，完美隐身！";
          });

          // 7. 弹窗提示清理原相册视频
          _showDeletePrompt();

        } else {
          setState(() {
            _isProcessing = false;
            _statusText = "❌ 处理失败，视频格式可能不兼容";
          });
        }
      },
      (log) {
        // 可以在这里打印底层执行日志
      },
      (statistics) {
        // 毫秒级进度条更新
        if (duration > 0) {
          double currentTime = statistics.getTime() / 1000.0;
          double currentProgress = (currentTime / duration).clamp(0.0, 1.0);
          setState(() {
            _progress = currentProgress;
            _statusText = "⚙️ 正在洗白: ${(currentProgress * 100).toStringAsFixed(1)}%";
          });
        }
      },
    );
  }

  // 完工后的安全清理提示
  void _showDeletePrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("洗白成功", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "无损防风控视频已保存至您的系统相册。\n\n⚠️ 为了彻底防止连坐封号，请立刻前往 iPhone 相册，手动【删除原视频】并清空【最近删除】！",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("我知道了，去删除", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 极简标志：白点
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 60),

              // 下拉选择武器箱
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedScript,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF111111),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: _isProcessing ? null : (String? newValue) {
                      setState(() {
                        _selectedScript = newValue!;
                      });
                    },
                    items: _scripts.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // 执行按钮
              GestureDetector(
                onTap: _isProcessing ? null : _startCleaning,
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    color: _isProcessing ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _isProcessing ? "执行中..." : "选择视频并洗白",
                      style: TextStyle(
                        color: _isProcessing ? Colors.grey[400] : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 进度条与状态显示
              if (_isProcessing || _progress == 1.0) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
