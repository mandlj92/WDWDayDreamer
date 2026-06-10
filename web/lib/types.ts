import type { Timestamp } from "firebase/firestore";

/**
 * Field names must stay identical to the iOS Firestore serialization
 * (see WDWDaydreams/Services/FirebaseDataService.swift).
 */

export const CATEGORIES = [
  "hotel",
  "park",
  "ride",
  "food",
  "beverage",
  "souvenir",
  "character",
  "event",
] as const;
export type Category = (typeof CATEGORIES)[number];

/** Document in /partnerships/{id}/stories/{storyId} */
export interface StoryDoc {
  date: Timestamp;
  authorId: string;
  authorName: string;
  items: Partial<Record<Category, string>>;
  text?: string;
  isFavorite?: boolean;
  version?: number;
}

/** Document in /partnerships/{id} */
export interface PartnershipDoc {
  user1Id: string;
  user2Id: string;
}

/** Document in /users/{id} (subset used by the web app) */
export interface UserProfileDoc {
  id: string;
  email: string;
  displayName: string;
  avatarURL?: string;
  bio?: string;
}

/** Document in /contentPacks/{id} */
export interface ContentPackDoc {
  id: string;
  name: string;
  description: string;
  isFree: boolean;
  version: number;
  categories: Partial<Record<Category, string[]>>;
}

export const CATEGORY_PREFIX: Record<Category, string> = {
  hotel: "Staying at",
  park: "Visiting",
  ride: "Riding",
  food: "Eating",
  beverage: "Drinking",
  souvenir: "Buying",
  character: "Meeting",
  event: "Attending",
};
