/**
 * BiS Provider abstraction
 *
 * Each provider implements scraping logic for a specific site.
 * The scraper uses whichever provider is selected via CLI arg.
 */

import { type Browser } from "puppeteer";

// ──────────────────────────────────────────────
// Shared types
// ──────────────────────────────────────────────

export type SlotItems = Record<string, number[]>;

export interface BiSResult {
  raid?: SlotItems;
  mythicplus?: SlotItems;
  overall?: SlotItems;
  presets?: Record<string, SlotItems>;
  raidUrl?: string;
  mythicplusUrl?: string;
  overallUrl?: string;
  presetUrls?: Record<string, string>;
}

export interface SpecDef {
  className: string;
  specName: string;
  urlClass: string;
  urlSpec: string;
}

// ──────────────────────────────────────────────
// Slot mapping (shared across providers)
// ──────────────────────────────────────────────

export const SLOT_MAP: Record<string, string> = {
  head: "HEAD", helm: "HEAD", helmet: "HEAD",
  neck: "NECK", necklace: "NECK", amulet: "NECK",
  shoulder: "SHOULDER", shoulders: "SHOULDER",
  chest: "CHEST", robe: "CHEST",
  waist: "WAIST", belt: "WAIST",
  legs: "LEGS", leg: "LEGS",
  feet: "FEET", boots: "FEET", foot: "FEET",
  hands: "HANDS", hand: "HANDS", gloves: "HANDS",
  wrist: "WRIST", wrists: "WRIST", bracer: "WRIST", bracers: "WRIST",
  finger: "FINGER", fingers: "FINGER", ring: "FINGER", rings: "FINGER",
  "ring 1": "FINGER", "ring 2": "FINGER",
  "finger 1": "FINGER", "finger 2": "FINGER",
  trinket: "TRINKET", trinkets: "TRINKET",
  "trinket 1": "TRINKET", "trinket 2": "TRINKET",
  back: "BACK", cape: "BACK", cloak: "BACK",
  weapon: "MAINHAND", weapons: "MAINHAND",
  "main hand": "MAINHAND", "main-hand": "MAINHAND", mainhand: "MAINHAND",
  "main hand weapon": "MAINHAND",
  "two-hand": "MAINHAND", "2h weapon": "MAINHAND", "two-hand weapon": "MAINHAND",
  "off hand": "OFFHAND", "off-hand": "OFFHAND", offhand: "OFFHAND",
  "off hand weapon": "OFFHAND",
  shield: "OFFHAND",
};

export function resolveSlot(text: string): string | null {
  const lower = text.toLowerCase().trim();
  if (SLOT_MAP[lower]) return SLOT_MAP[lower];
  for (const [key, slot] of Object.entries(SLOT_MAP)) {
    if (lower.includes(key)) return slot;
  }
  return null;
}

// ──────────────────────────────────────────────
// Provider interface
// ──────────────────────────────────────────────

export abstract class BiSProvider {
  abstract readonly name: string;

  /**
   * Scrape BiS for a given class/spec.
   * Returns raid + m+ item lists organized by slot.
   */
  abstract getBis(browser: Browser, spec: SpecDef): Promise<BiSResult>;

  /** Extract item IDs from a page using common selectors */
  protected extractItemIds(elements: { href?: string; dataWowhead?: string }[]): number[] {
    const ids: number[] = [];
    for (const el of elements) {
      let id: number | null = null;
      const href = el.href || "";
      const wh = el.dataWowhead || "";
      let m = href.match(/item[=/](\d+)/);
      if (!m) m = wh.match(/item=(\d+)/);
      if (m) id = parseInt(m[1], 10);
      if (id && id > 0 && !ids.includes(id)) ids.push(id);
    }
    return ids;
  }
}

