"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  or,
  orderBy,
  onSnapshot,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { PartnershipDoc, StoryDoc } from "@/lib/types";
import { StoryCard } from "@/components/StoryCard";

interface Partnership extends PartnershipDoc {
  id: string;
}

interface Story extends StoryDoc {
  id: string;
}

export function StoryHistory({ uid }: { uid: string }) {
  const [partnerships, setPartnerships] = useState<Partnership[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [stories, setStories] = useState<Story[]>([]);
  const [loading, setLoading] = useState(true);

  // Live partnership list (mirrors iOS userPartnerships listener)
  useEffect(() => {
    const q = query(
      collection(db, "partnerships"),
      or(where("user1Id", "==", uid), where("user2Id", "==", uid))
    );
    return onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({ id: d.id, ...(d.data() as PartnershipDoc) }));
      setPartnerships(list);
      setSelectedId((prev) => prev ?? list[0]?.id ?? null);
      setLoading(false);
    });
  }, [uid]);

  // Live story feed for the selected partnership
  useEffect(() => {
    if (!selectedId) {
      setStories([]);
      return;
    }
    const q = query(
      collection(db, "partnerships", selectedId, "stories"),
      orderBy("date", "desc")
    );
    return onSnapshot(q, (snap) => {
      setStories(snap.docs.map((d) => ({ id: d.id, ...(d.data() as StoryDoc) })));
    });
  }, [selectedId]);

  if (loading) {
    return <p className="text-sm opacity-60">Loading partnerships…</p>;
  }

  if (partnerships.length === 0) {
    return (
      <div className="rounded-2xl border border-black/10 dark:border-white/10 p-6 text-center">
        <p className="font-medium">No Pal connections yet</p>
        <p className="text-sm opacity-60 mt-1">
          Connect with a Pal in the iOS app to start sharing daily daydreams.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {partnerships.length > 1 && (
        <select
          value={selectedId ?? ""}
          onChange={(e) => setSelectedId(e.target.value)}
          className="rounded-lg border border-black/10 dark:border-white/10 bg-transparent px-3 py-2 text-sm"
        >
          {partnerships.map((p) => (
            <option key={p.id} value={p.id}>
              Partnership {p.id.slice(0, 12)}…
            </option>
          ))}
        </select>
      )}

      {stories.length === 0 ? (
        <p className="text-sm opacity-60">No stories in this partnership yet.</p>
      ) : (
        <ul className="space-y-3">
          {stories.map((s) => (
            <li key={s.id}>
              <StoryCard story={s} isOwn={s.authorId === uid} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
