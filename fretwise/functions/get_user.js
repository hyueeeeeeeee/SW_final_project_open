const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function run() {
  const db = admin.firestore();
  // Get the first user document to check its fields
  const snapshot = await db.collection("users").limit(1).get();
  if (snapshot.empty) {
    console.log("No users found.");
    return;
  }
  snapshot.forEach(doc => {
    console.log("User ID:", doc.id);
    console.log("Data:", JSON.stringify(doc.data(), null, 2));
  });
}
run();
