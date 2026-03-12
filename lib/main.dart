import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

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
        scaffoldBackgroundColor: const Color(0xFF121212),
        primarySwatch: Colors.blueGrey,
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
  final List<String> _scripts = ["莫比乌斯环 (重构/静音)", "冷冽精钢版 (原画幅视觉强化 + 隐形声纹洗白)"];
  String _selectedScript = "莫比乌斯环 (重构/静音)";
  
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusText = "等待执行";

  final ImagePicker _picker = ImagePicker();

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // 新增：极客专用的错误诊断弹窗
  void _showErrorDialog(String? logs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("⚠️ 底层诊断日志", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(
            logs ?? "无日志输出",
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: "Courier"),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("关闭", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startCleaning() async {
    try {
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _statusText = "正在唤醒系统相册...";
      });

      final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null) {
        setState(() {
          _isProcessing = false;
          _statusText = "已取消选择";
        });
        return;
      }

      setState(() => _statusText = "🔍 正在扫描视频底层结构...");

      final String inputPath = pickedFile.path;
      double duration = 0.0;
      int width = 0;
      int height = 0;
      bool hasAudio = false; // 新增：音频轨道探测器
      
      final mediaInfoSession = await FFprobeKit.getMediaInformation(inputPath);
      final mediaInfo = mediaInfoSession.getMediaInformation();
      
      if (mediaInfo != null) {
        duration = double.tryParse(mediaInfo.getDuration() ?? "0") ?? 0.0;
        final streams = mediaInfo.getStreams();
        for (var stream in streams) {
          if (stream.getType() == "video") {
            width = stream.getWidth() ?? 0;
            height = stream.getHeight() ?? 0;
          }
          if (stream.getType() == "audio") {
            hasAudio = true; // 发现音轨！
          }
        }
      }

      if (duration <= 3.0 && _selectedScript.contains("莫比乌斯环")) {
        setState(() {
          _isProcessing = false;
          _statusText = "⚠️ 视频太短，无法使用莫比乌斯环";
        });
        _showToast("视频必须大于3秒");
        return;
      }

      final Directory extDir = await getTemporaryDirectory();
      final String outputPath = '${extDir.path}/out_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final String command = ScriptManager.getCommand(
        scriptType: _selectedScript,
        inputPath: inputPath,
        outputPath: outputPath,
        duration: duration,
        origW: width,
        origH: height,
        hasAudio: hasAudio, // 将探测结果传给武器库
      );

      setState(() => _statusText = "🔥 硬件加速重构中...");

      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            setState(() => _statusText = "📥 正在安全写入相册...");
            
            await Gal.putVideo(outputPath);
            
            try {
              File(outputPath).deleteSync();
              File(inputPath).deleteSync();
            } catch (_) {}

            setState(() {
              _isProcessing = false;
              _progress = 1.0;
              _statusText = "✅ 洗白完成，已存入相册！";
            });

            _showDeletePrompt();

          } else {
            // 核心变动：抓取报错日志并强制弹窗展示
            final failLogs = await session.getLogsAsString();
            setState(() {
              _isProcessing = false;
              _statusText = "❌ 处理失败，请查看日志";
            });
            _showErrorDialog(failLogs);
          }
        },
        (log) {},
        (statistics) {
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
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = "❌ 发生致命异常";
      });
      _showErrorDialog(e.toString());
    }
  }

  void _showDeletePrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("洗白成功", style: TextStyle(color: Colors.white)),
        content: const Text(
          "请前往 iPhone 相册，手动【删除原视频】并清空【最近删除】！",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("我知道了", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("矩阵物理洗白引擎", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("选择防御装甲", style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedScript,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E1E),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: _isProcessing ? null : (String? newValue) {
                      setState(() => _selectedScript = newValue!);
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

              GestureDetector(
                onTap: _isProcessing ? null : _startCleaning,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isProcessing ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _isProcessing ? "执行中..." : "选择视频并洗白",
                      style: TextStyle(
                        color: _isProcessing ? Colors.grey[400] : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              if (_isProcessing || _progress == 1.0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
