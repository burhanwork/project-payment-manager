const admin = require('firebase-admin');
const path = require('path');

let initialized = false;

function initFirebase() {
  if (initialized) return;

  // Place your downloaded service account JSON file at:
  // backend/config/firebase-service-account.json
  const serviceAccountPath = path.join(__dirname, 'firebase-service-account.json');

  try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    initialized = true;
    console.log('Firebase Admin initialized');
  } catch (err) {
    console.warn(
      'Firebase Admin not initialized — missing firebase-service-account.json. Push notifications disabled.',
      err.message
    );
  }
}

module.exports = { initFirebase, admin };
