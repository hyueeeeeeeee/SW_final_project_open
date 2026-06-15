const admin = require("firebase-admin");
const serviceAccount = require("./firebase-adminsdk.json"); // Assuming they have one, wait, no.

admin.initializeApp({
  projectId: "fretwise-6ceb6"
});

const db = admin.firestore();

async function check() {
  const doc = await db.collection("users").doc("test_user_123").get();
  console.log(JSON.stringify(doc.data(), null, 2));
}

check().catch(console.error);
