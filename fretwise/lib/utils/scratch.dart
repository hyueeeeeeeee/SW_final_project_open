import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
void main() {
  tz.initializeTimeZones();
  print(tz.local.name);
  final now = DateTime.now();
  print(now);
  print(tz.TZDateTime.from(now, tz.local));
}
