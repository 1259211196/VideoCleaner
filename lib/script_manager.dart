class ScriptManager {
  // ==========================================
  // 🛡️ 方案 1：莫比乌斯环 (113%构图重塑 + 冷冽精钢 + 动态噪点 + 静音拼贴)
  // ==========================================
  static const String mobiusLoop = 
      "-y -i {input} -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -filter_complex \"[0:v]scale={scaleW}:{scaleH},crop={origW}:{origH}:(in_w-out_w)/2:165,eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,split[vbase1][vbase2];[vbase1]trim={sTime}:{eTime},setpts=PTS-STARTPTS[v1];[vbase2]trim=0:{sTime},setpts=PTS-STARTPTS[v2];[v1][v2]concat=n=2:v=1:a=0[vout];[1:a]atrim=0:{eTime},asetpts=PTS-STARTPTS[aout]\" -map \"[vout]\" -map \"[aout]\" -c:v h264_videotoolbox -b:v 15M -c:a aac -b:a 128k -map_metadata -1 -movflags +faststart {output}";

  // ==========================================
  // ⚔️ 方案 2：冷冽精钢版 (原画幅视觉强化 + 隐形声纹洗白)
  // ==========================================
  static const String steelArmor = 
      "-y -i {input} -filter_complex \"[0:v]eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t[vout];[0:a]volume=0.97,bass=g=1.5,treble=g=1.5[aout]\" -map \"[vout]\" -map \"[aout]\" -c:v h264_videotoolbox -b:v 15M -c:a aac -b:a 192k -map_metadata -1 -movflags +faststart {output}";

  // ==========================================
  // 🧠 核心指令调度中枢
  // ==========================================
  static String getCommand({
    required String scriptType,
    required String inputPath,
    required String outputPath,
    // 以下三个参数专为方案 1 的精准计算准备
    double duration = 0.0,
    int origW = 0,
    int origH = 0,
  }) {
    if (scriptType == "莫比乌斯环 (重构/静音)") {
      // 在 Dart 内部复现你 .bat 里的 PowerShell 数学计算逻辑
      int scaleW = ((origW * 1.13) / 2).round() * 2;
      int scaleH = ((origH * 1.13) / 2).round() * 2;
      double sTime = (duration - 2.0) < 0 ? 0 : (duration - 2.0); // 截取最后2秒
      double eTime = duration;

      // 组装并注入所有参数
      return mobiusLoop
          .replaceAll("{input}", "\"$inputPath\"")
          .replaceAll("{output}", "\"$outputPath\"")
          .replaceAll("{scaleW}", scaleW.toString())
          .replaceAll("{scaleH}", scaleH.toString())
          .replaceAll("{origW}", origW.toString())
          .replaceAll("{origH}", origH.toString())
          .replaceAll("{sTime}", sTime.toStringAsFixed(3))
          .replaceAll("{eTime}", eTime.toStringAsFixed(3));
          
    } else {
      // 方案 2 极其暴力简单，直接替换出入路径即可
      return steelArmor
          .replaceAll("{input}", "\"$inputPath\"")
          .replaceAll("{output}", "\"$outputPath\"");
    }
  }
}
