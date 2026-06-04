String makeSongId(String title, String artist) {
  final base = '${title.trim()}--${artist.trim()}'.toLowerCase();
  return base.replaceAll(RegExp(r"[^a-z0-9_\-]"), '_');
}
