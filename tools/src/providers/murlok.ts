/**
 * Murlok.io BiS Provider
 *
 * Uses the public JSON API: https://murlok.io/api/guides/{class}/{spec}/{activity}
 * Aggregates equipment from top-rated players to build BiS lists.
 * No browser/Puppeteer needed.
 */

import { type Browser } from "puppeteer";
import { BiSProvider, type BiSResult, type SlotItems, type SpecDef } from "./provider";

const API_BASE = "https://murlok.io/api/guides";

/** Map Murlok API slot names to our internal slot keys */
const MURLOK_SLOT_MAP: Record<string, string> = {
  head: "HEAD",
  neck: "NECK",
  shoulders: "SHOULDER",
  chest: "CHEST",
  waist: "WAIST",
  legs: "LEGS",
  feet: "FEET",
  wrist: "WRIST",
  hands: "HANDS",
  "ring-1": "FINGER",
  "ring-2": "FINGER",
  "trinket-1": "TRINKET",
  "trinket-2": "TRINKET",
  back: "BACK",
  "main-hand": "MAINHAND",
  "off-hand": "OFFHAND",
};

interface MurlokItem {
  ItemID: number;
  Slot: string;
  Name?: string;
}

interface MurlokCharacter {
  Equipment?: {
    Items?: MurlokItem[];
  };
}

interface MurlokResponse {
  Characters?: MurlokCharacter[];
}

const MIN_POPULARITY = 10; // Only keep items used by > 10% of top players

/**
 * Fetch BiS items from the Murlok API for a given activity (raid or m+).
 * Only keeps items equipped by more than MIN_POPULARITY% of top players.
 */
async function fetchMurlokBis(spec: SpecDef, activity: "raid" | "m+"): Promise<SlotItems> {
  const url = `${API_BASE}/${spec.urlClass}/${spec.urlSpec}/${encodeURIComponent(activity)}`;
  const slots: SlotItems = {};

  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "GearManager-Scraper/1.0" },
    });

    if (!res.ok) {
      console.error(`  [WARN] murlok ${url}: HTTP ${res.status}`);
      return slots;
    }

    const data = await res.json() as MurlokResponse;
    const characters = data.Characters || [];
    if (characters.length === 0) return slots;

    // Count occurrences of each itemID per slot
    const counts: Record<string, Record<number, number>> = {};

    for (const char of characters) {
      const items = char.Equipment?.Items || [];
      for (const item of items) {
        if (!item.ItemID || item.ItemID <= 0) continue;
        const slot = MURLOK_SLOT_MAP[item.Slot];
        if (!slot) continue;
        if (!counts[slot]) counts[slot] = {};
        counts[slot][item.ItemID] = (counts[slot][item.ItemID] || 0) + 1;
      }
    }

    const total = characters.length;
    for (const [slot, itemCounts] of Object.entries(counts)) {
      for (const [itemIdStr, count] of Object.entries(itemCounts)) {
        const popularity = (count / total) * 100;
        if (popularity > MIN_POPULARITY) {
          if (!slots[slot]) slots[slot] = [];
          slots[slot].push(parseInt(itemIdStr, 10));
        }
      }
    }
  } catch (err) {
    console.error(`  [ERROR] murlok ${url}: ${err}`);
  }

  return slots;
}

export class MurlokProvider extends BiSProvider {
  readonly name = "murlok";

  async getBis(_browser: Browser, spec: SpecDef): Promise<BiSResult> {
    const mythicplus = await fetchMurlokBis(spec, "m+");

    return {
      mythicplus,
      mythicplusUrl: `https://murlok.io/${spec.urlClass}/${spec.urlSpec}/m+`,
    };
  }
}
