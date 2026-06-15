const profile = { skillLevel: "beginner", preferredSessionMinutes: 20 };
const userData = {};

const aiInput = {
  profile: {
    skillLevel: profile.skillLevel || "beginner",
    preferredSessionMinutes: profile.preferredSessionMinutes || 20,
    preferredDayAndTime: userData.preferredDayAndTime || profile.preferredDayAndTime || null,
    dayAndTimeRule: userData.DayAndTimeRule || null,
  }
};
console.log(JSON.stringify(aiInput, null, 2));
