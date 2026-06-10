#!/usr/bin/env node
/**
 * Seeds content packs into Firestore.
 *
 * Usage:
 *   Emulator (default if FIRESTORE_EMULATOR_HOST is set, e.g. by `firebase emulators:exec`):
 *     FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed-content.mjs
 *
 *   Production (requires GOOGLE_APPLICATION_CREDENTIALS service account):
 *     node scripts/seed-content.mjs --production
 *
 * Each JSON file in scripts/content-packs/ becomes one document in /contentPacks/{id}.
 */
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PACKS_DIR = join(__dirname, "content-packs");
const PROJECT_ID = "wdwdaydreams-e4e4e";

const isProduction = process.argv.includes("--production");

if (!isProduction && !process.env.FIRESTORE_EMULATOR_HOST) {
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  console.log("No FIRESTORE_EMULATOR_HOST set — defaulting to 127.0.0.1:8080");
}

if (isProduction && process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("Refusing to run --production while FIRESTORE_EMULATOR_HOST is set.");
  process.exit(1);
}

initializeApp({
  projectId: PROJECT_ID,
  ...(isProduction ? { credential: applicationDefault() } : {}),
});

const db = getFirestore();

const files = readdirSync(PACKS_DIR).filter((f) => f.endsWith(".json"));
if (files.length === 0) {
  console.error(`No pack files found in ${PACKS_DIR}`);
  process.exit(1);
}

for (const file of files) {
  const pack = JSON.parse(readFileSync(join(PACKS_DIR, file), "utf8"));
  if (!pack.id || !pack.categories) {
    console.error(`Skipping ${file}: missing required "id" or "categories" field`);
    continue;
  }
  const itemCount = Object.values(pack.categories).reduce((n, list) => n + list.length, 0);
  await db.collection("contentPacks").doc(pack.id).set({
    ...pack,
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`Seeded contentPacks/${pack.id} (${itemCount} items, v${pack.version}) [${isProduction ? "PRODUCTION" : "emulator"}]`);
}

console.log("Done.");
