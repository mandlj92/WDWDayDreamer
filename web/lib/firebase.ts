import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth, connectAuthEmulator, GoogleAuthProvider } from "firebase/auth";
import {
  initializeFirestore,
  connectFirestoreEmulator,
  persistentLocalCache,
  persistentMultipleTabManager,
} from "firebase/firestore";

const useEmulators = process.env.NEXT_PUBLIC_USE_EMULATORS === "true";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "demo-api-key",
  authDomain:
    process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ||
    "wdwdaydreams-e4e4e.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "wdwdaydreams-e4e4e",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "demo-app-id",
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

// Mirrors the iOS app's Firestore offline persistence (WDWDaydreamsApp.swift),
// using IndexedDB with multi-tab coordination on web.
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
});

export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();

if (useEmulators && typeof window !== "undefined") {
  // Guard against double-connection across Fast Refresh.
  const g = globalThis as { __emulatorsConnected?: boolean };
  if (!g.__emulatorsConnected) {
    connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
    connectFirestoreEmulator(db, "127.0.0.1", 8080);
    g.__emulatorsConnected = true;
  }
}
