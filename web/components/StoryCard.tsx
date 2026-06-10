"use client";

import type { StoryDoc, Category } from "@/lib/types";
import { CATEGORY_PREFIX } from "@/lib/types";

export function StoryCard({
  story,
  isOwn,
}: {
  story: StoryDoc;
  isOwn: boolean;
}) {
  const date = story.date?.toDate();
  const promptParts = Object.entries(story.items ?? {}) as [Category, string][];
  const written = !!story.text?.trim();

  return (
    <article className="rounded-2xl border border-black/10 dark:border-white/10 p-4 space-y-3">
      <header className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 text-sm">
          <span className="font-semibold">{story.authorName}</span>
          {isOwn && (
            <span className="rounded-full bg-indigo-600/10 text-indigo-600 dark:text-indigo-400 px-2 py-0.5 text-xs font-medium">
              you
            </span>
          )}
        </div>
        <time className="text-xs opacity-60">
          {date?.toLocaleDateString(undefined, {
            month: "short",
            day: "numeric",
            year: "numeric",
          })}
        </time>
      </header>

      <div className="flex flex-wrap gap-1.5">
        {promptParts.map(([category, value]) => (
          <span
            key={category}
            className="rounded-full bg-black/5 dark:bg-white/10 px-2.5 py-1 text-xs"
          >
            <span className="opacity-60">{CATEGORY_PREFIX[category] ?? category}</span>{" "}
            {value}
          </span>
        ))}
      </div>

      {written ? (
        <p className="text-sm leading-relaxed whitespace-pre-wrap">{story.text}</p>
      ) : (
        <p className="text-sm italic opacity-50">Not written yet…</p>
      )}

      {story.isFavorite && <p className="text-xs">⭐ Favorited</p>}
    </article>
  );
}
