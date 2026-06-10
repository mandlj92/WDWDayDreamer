"use client";

import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { useAuth } from "@/components/AuthProvider";
import { SignIn } from "@/components/SignIn";
import { StoryHistory } from "@/components/StoryHistory";

export default function Home() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <main className="flex items-center justify-center min-h-screen">
        <p className="text-sm opacity-60">Loading…</p>
      </main>
    );
  }

  if (!user) {
    return <SignIn />;
  }

  return (
    <main className="mx-auto max-w-2xl px-4 py-8 space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Park Daydreams</h1>
          <p className="text-sm opacity-60">{user.displayName ?? user.email}</p>
        </div>
        <button
          onClick={() => signOut(auth)}
          className="text-sm opacity-60 hover:opacity-100 transition-opacity"
        >
          Sign out
        </button>
      </header>

      <StoryHistory uid={user.uid} />
    </main>
  );
}
