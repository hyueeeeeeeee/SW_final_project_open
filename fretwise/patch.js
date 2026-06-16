const fs = require('fs');
let code = fs.readFileSync('functions/index.js', 'utf8');

code = code.replace(
  'preferredDayAndTime: userData.preferredDayAndTime || profile.preferredDayAndTime || null,',
  'preferredDayAndTime: userData.preferredDayAndTime || userData.preferedPracticeTime || userData.preferredPracticeTime || profile.preferredDayAndTime || null,'
);

code = code.replace(
  'dayAndTimeRule: userData.DayAndTimeRule || null,',
  'dayAndTimeRule: userData.DayAndTimeRule || userData.dayAndTimeRule || null,'
);

code = code.replace(
  "1. DO NOT schedule ANY practice on days that conflict heavily with the 'externalCalendar' events. If a day has many busy events on 'preferredDayAndTime', CANCEL the practice for that day completely (schedule 0 minutes).",
  "1. DO NOT schedule ANY practice on dates that appear in the 'externalCalendar'. If a date has EVEN ONE external event, you MUST CANCEL the practice for that ENTIRE DAY (schedule 0 minutes)."
);

fs.writeFileSync('functions/index.js', code);
console.log("Patched index.js");
