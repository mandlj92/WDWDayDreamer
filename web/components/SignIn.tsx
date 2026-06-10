"use client";

import { signInWithPopup } from "firebase/auth";
import { auth, googleProvider } from "@/lib/firebase";
import { useState } from "react";

export function SignIn() {
  const [error, setError] = useState<string | null>(null);

  async function handleSignIn() {
    setError(null);
    try {
      await signInWithPopup(auth, googleProvider);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Sign-in failed");
    }
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-screen gap-6 px-4">
      <h1 className="text-4xl font-bold tracking-tight">Park Daydreams</h1>
      <p className="text-sm opacity-70 max-w-sm text-center">
        Daily park prompts, shared stories, and countdowns with your Pals.
      </p>
      <button
        onClick={handleSignIn}
        className="rounded-full bg-indigo-600 hover:bg-indigo-500 text-white px-6 py-3 text-sm font-semibold transition-colors"
      >
        Sign in with Google
      </button>
      {error && <p className="text-sm text-red-500 max-w-sm text-center">{error}</p>}
    </div>
  );
}
