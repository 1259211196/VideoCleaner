class ScriptManager {
  static String getCommand({
    required String scriptType,
    required String inputPath,
    required String outputPath,
    double duration = 0.0,
    int origW = 0,
    int origH = 0,
    bool hasAudio = true,
  }) {
    if (scriptType.contains("莫比乌斯环")) {
      // 方案 1：莫比乌斯环
      int scaleW = ((origW * 1.13) / 2).round() * 2;
      int scaleH = ((origH * 1.13) / 2).round() * 2;
      double sTime = (duration - 2.0) < 0 ? 0 : (duration - 2.0);
      double eTime = duration;

      String filter = "[0:v]scale=$scaleW:$scaleH,crop=$origW:$origH:(in_w-out_w)/2:165,eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,format=yuv420p,split[vbase1][vbase2];[vbase1]trim=${sTime.toStringAsFixed(3)}:${eTime.toStringAsFixed(3)},setpts=PTS-STARTPTS[v1];[vbase2]trim=0:${sTime.toStringAsFixed(3)},setpts=PTS-STARTPTS[v2];[v1][v2]concat=n=2:v=1:a=0[vout];[1:a]atrim=0:${eTime.toStringAsFixed(3)},asetpts=PTS-STARTPTS[aout]";

      // 核心替换：使用 libx264 配合 -preset fast 软解引擎
      return "-y -i \"$inputPath\" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -filter_complex \"$filter\" -map \"[vout]\" -map \"[aout]\" -c:v libx264 -b:v 15M -preset fast -c:a aac -b:a 128k -map_metadata -1 -movflags +faststart \"$outputPath\"";
      
    } else {
      // 方案 2：冷冽精钢
      if (hasAudio) {
        String filter = "[0:v]eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,format=yuv420p[vout];[0:a]volume=0.97,bass=g=1.5,treble=g=1.5[aout]";
        
        // 核心替换：使用 libx264 配合 -preset fast 软解引擎
        return "-y -i \"$inputPath\" -filter_complex \"$filter\" -map \"[vout]\" -map \"[aout]\" -c:v libx264 -b:v 15M -preset fast -c:a aac -b:a 192k -map_metadata -1 -movflags +faststart \"$outputPath\"";
      } else {
        String filter = "[0:v]eq=contrast=1.08:brightness=-0.02:saturation=1.02:gamma=0.95,unsharp=5:5:0.8:3:3:0.4,noise=alls=1:allf=t,format=yuv420p[vout]";
        
        // 核心替换：使用 libx264 配合 -preset fast 软解引擎
        return "-y -i \"$inputPath\" -filter_complex \"$filter\" -map \"[vout]\" -c:v libx264 -b:v 15M -preset fast -map_metadata -1 -movflags +faststart \"$outputPath\"";
      }
    }
  }
}
