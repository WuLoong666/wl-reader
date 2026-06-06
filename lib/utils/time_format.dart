String formatDuration(int seconds) {
  if (seconds <= 0) {
    return '0 分钟';
  }

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;

  if (hours > 0) {
    if (minutes > 0) {
      return '$hours 小时 $minutes 分';
    }
    return '$hours 小时';
  }

  if (minutes > 0) {
    if (remainingSeconds > 0) {
      return '$minutes 分 $remainingSeconds 秒';
    }
    return '$minutes 分';
  }

  return '$remainingSeconds 秒';
}

String formatCompactDuration(int seconds) {
  if (seconds <= 0) {
    return '';
  }

  final hours = seconds ~/ 3600;
  if (hours > 0) {
    return '${hours}h';
  }

  final minutes = seconds ~/ 60;
  if (minutes > 0) {
    return '${minutes}m';
  }

  return '${seconds}s';
}
