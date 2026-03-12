class ScriptManager {
  static String getCommand({
    required String scriptType,
    required String inputPath,
    required String outputPath,
    double duration = 0.0,
    int origW = 0,
    int origH = 0,
    bool hasAudio = true, // 新增：动态声音侦测参数
  }) {
    if (scriptType.contains("莫比乌斯环")) {
      // 方案 1：莫比乌斯环
      int scaleW = ((origW * 1.13) / 2).round() * 2;
      int scaleH = ((origH * 1.13) / 2).round() * 2;
      double sTime = (duration - 2.0) < 0 ? 0 : (duration - 2.0);
      double eTime = duration;

      // 注意：在 split 之前加入了 format=yuv420p 强制统一色彩空间，解决硬件编码器报错
      String filter = "[0:v]scale=$scaleW:$scaleH,crop=$origW:$origH:(in_w-out_w)/2:165,eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,format=yuv420p,split[vbase1][vbase2];[vbase1]trim=${sTime.toStringAsFixed(3)}:${eTime.toStringAsFixed(3)},setpts=PTS-STARTPTS[v1];[vbase2]trim=0:${sTime.toStringAsFixed(3)},setpts=PTS-STARTPTS[v2];[v1][v2]concat=n=2:v=1:a=0[vout];[1:a]atrim=0:${eTime.toStringAsFixed(3)},asetpts=PTS-STARTPTS[aout]";

      return "-y -i \"$inputPath\" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -filter_complex \"$filter\" -map \"[vout]\" -map \"[aout]\" -c:v h264_videotoolbox -b:v 15M -c:a aac -b:a 128k -map_metadata -1 -movflags +faststart \"$outputPath\"";
      
    } else {
      // 方案 2：冷冽精钢
      if (hasAudio) {
        // 如果有原声，执行双重洗白
        String filter = "[0:v]eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,format=yuv420p[vout];[0:a]volume=0.97,bass=g=1.5,treble=g=1.5[aout]";
        return "-y -i \"$inputPath\" -filter_complex \"$filter\" -map \"[vout]\" -map \"[aout]\" -c:v h264_videotoolbox -b:v 15M -c:a aac -b:a 192k -map_metadata -1 -movflags +faststart \"$outputPath\"";
      } else {
        // 如果没有原声，智能抛弃音频处理，防止报错闪退
        String filter = "[0:v]eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,format=yuv420p[vout]";
        return "-y -i \"$inputPath\" -filter_complex \"$filter\" -map \"[vout]\" -c:v h264_videotoolbox -b:v 15M -map_metadata -1 -movflags +faststart \"$outputPath\"";
      }
    }
  }
}
