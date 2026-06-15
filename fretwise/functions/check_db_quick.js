const admin = require("firebase-admin");
admin.initializeApp({ projectId: "fretwise-6ceb6" });
const db = admin.firestore();
async function run() {
  const userDocs = await db.collection("users").get();
  userDocs.forEach(doc => {
    console.log("User:", doc.id);
    const data = doc.data();
    console.log("profile:", JSON.stringify(data.profile, null, 2));
    console.log("preferredDayAndTime:", data.preferredDayAndTime);
    console.log("DayAndTimeRule:", data.DayAndTimeRule);
  });
}
run().catch(console.error);
