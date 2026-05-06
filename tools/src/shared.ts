/**
 * Shared constants, types, and helpers for scrape & generate commands.
 */

import * as fs from "fs";
import * as path from "path";
import { type BiSResult, type SlotItems, type SpecDef } from "./providers";

// ──────────────────────────────────────────────
// Paths
// ──────────────────────────────────────────────

export const DATA_DIR = path.resolve(__dirname, "../../Data");
export const JSON_DIR = path.join(__dirname, "../generated");
export const LUA_OUT = path.join(DATA_DIR, "GeneratedBiS.lua");

// ──────────────────────────────────────────────
// All specs
// ──────────────────────────────────────────────

export const SPECS: SpecDef[] = [
  { className: "DEATHKNIGHT", specName: "BLOOD",         urlClass: "death-knight", urlSpec: "blood" },
  { className: "DEATHKNIGHT", specName: "FROST",         urlClass: "death-knight", urlSpec: "frost" },
  { className: "DEATHKNIGHT", specName: "UNHOLY",        urlClass: "death-knight", urlSpec: "unholy" },
  { className: "DEMONHUNTER", specName: "HAVOC",         urlClass: "demon-hunter", urlSpec: "havoc" },
  { className: "DEMONHUNTER", specName: "VENGEANCE",     urlClass: "demon-hunter", urlSpec: "vengeance" },
  { className: "DEMONHUNTER", specName: "DEVOURER",      urlClass: "demon-hunter", urlSpec: "devourer" },
  { className: "DRUID",       specName: "BALANCE",       urlClass: "druid",        urlSpec: "balance" },
  { className: "DRUID",       specName: "FERAL",         urlClass: "druid",        urlSpec: "feral" },
  { className: "DRUID",       specName: "GUARDIAN",      urlClass: "druid",        urlSpec: "guardian" },
  { className: "DRUID",       specName: "RESTORATION",   urlClass: "druid",        urlSpec: "restoration" },
  { className: "EVOKER",      specName: "AUGMENTATION",  urlClass: "evoker",       urlSpec: "augmentation" },
  { className: "EVOKER",      specName: "DEVASTATION",   urlClass: "evoker",       urlSpec: "devastation" },
  { className: "EVOKER",      specName: "PRESERVATION",  urlClass: "evoker",       urlSpec: "preservation" },
  { className: "HUNTER",      specName: "BEASTMASTERY",  urlClass: "hunter",       urlSpec: "beast-mastery" },
  { className: "HUNTER",      specName: "MARKSMANSHIP",  urlClass: "hunter",       urlSpec: "marksmanship" },
  { className: "HUNTER",      specName: "SURVIVAL",      urlClass: "hunter",       urlSpec: "survival" },
  { className: "MAGE",        specName: "ARCANE",        urlClass: "mage",         urlSpec: "arcane" },
  { className: "MAGE",        specName: "FIRE",          urlClass: "mage",         urlSpec: "fire" },
  { className: "MAGE",        specName: "FROST",         urlClass: "mage",         urlSpec: "frost" },
  { className: "MONK",        specName: "BREWMASTER",    urlClass: "monk",         urlSpec: "brewmaster" },
  { className: "MONK",        specName: "MISTWEAVER",    urlClass: "monk",         urlSpec: "mistweaver" },
  { className: "MONK",        specName: "WINDWALKER",    urlClass: "monk",         urlSpec: "windwalker" },
  { className: "PALADIN",     specName: "HOLY",          urlClass: "paladin",      urlSpec: "holy" },
  { className: "PALADIN",     specName: "PROTECTION",    urlClass: "paladin",      urlSpec: "protection" },
  { className: "PALADIN",     specName: "RETRIBUTION",   urlClass: "paladin",      urlSpec: "retribution" },
  { className: "PRIEST",      specName: "DISCIPLINE",    urlClass: "priest",       urlSpec: "discipline" },
  { className: "PRIEST",      specName: "HOLY",          urlClass: "priest",       urlSpec: "holy" },
  { className: "PRIEST",      specName: "SHADOW",        urlClass: "priest",       urlSpec: "shadow" },
  { className: "ROGUE",       specName: "ASSASSINATION", urlClass: "rogue",        urlSpec: "assassination" },
  { className: "ROGUE",       specName: "OUTLAW",        urlClass: "rogue",        urlSpec: "outlaw" },
  { className: "ROGUE",       specName: "SUBTLETY",      urlClass: "rogue",        urlSpec: "subtlety" },
  { className: "SHAMAN",      specName: "ELEMENTAL",     urlClass: "shaman",       urlSpec: "elemental" },
  { className: "SHAMAN",      specName: "ENHANCEMENT",   urlClass: "shaman",       urlSpec: "enhancement" },
  { className: "SHAMAN",      specName: "RESTORATION",   urlClass: "shaman",       urlSpec: "restoration" },
  { className: "WARLOCK",     specName: "AFFLICTION",    urlClass: "warlock",      urlSpec: "affliction" },
  { className: "WARLOCK",     specName: "DEMONOLOGY",    urlClass: "warlock",      urlSpec: "demonology" },
  { className: "WARLOCK",     specName: "DESTRUCTION",   urlClass: "warlock",      urlSpec: "destruction" },
  { className: "WARRIOR",     specName: "ARMS",          urlClass: "warrior",      urlSpec: "arms" },
  { className: "WARRIOR",     specName: "FURY",          urlClass: "warrior",      urlSpec: "fury" },
  { className: "WARRIOR",     specName: "PROTECTION",    urlClass: "warrior",      urlSpec: "protection" },
];

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

export function ensureDir(dir: string) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

export async function parallelBatch<T, R>(items: T[], size: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = [];
  for (let i = 0; i < items.length; i += size) {
    const batch = items.slice(i, i + size);
    console.log(`\n── Batch ${Math.floor(i / size) + 1}/${Math.ceil(items.length / size)} (${batch.length} specs) ──`);
    results.push(...await Promise.all(batch.map(fn)));
    if (i + size < items.length) await new Promise(r => setTimeout(r, 1_000));
  }
  return results;
}

// ──────────────────────────────────────────────
// JSON persistence
// ──────────────────────────────────────────────

export interface ProviderData {
  raid: SlotItems;
  mythicplus: SlotItems;
  overall?: SlotItems;
  presets?: Record<string, SlotItems>;
  raidUrl?: string;
  mythicplusUrl?: string;
  overallUrl?: string;
  presetUrls?: Record<string, string>;
  scrapedAt: string;
}

export interface ClassJson {
  key: string;
  specs: Record<string, Record<string, ProviderData>>;
}

export function saveJson(key: string, provider: string, bis: BiSResult) {
  ensureDir(JSON_DIR);
  const [className, specName] = key.split("_", 2);
  const filePath = path.join(JSON_DIR, `${className}.json`);

  let existing: ClassJson = { key: className, specs: {} };
  if (fs.existsSync(filePath)) {
    try {
      existing = JSON.parse(fs.readFileSync(filePath, "utf-8"));
      if (!existing.specs) existing.specs = {};
    } catch { /* ignore parse errors, overwrite */ }
  }

  existing.key = className;
  if (!existing.specs[specName]) existing.specs[specName] = {};

  existing.specs[specName][provider] = {
    raid: bis.raid ?? {},
    mythicplus: bis.mythicplus ?? {},
    ...(bis.overall !== undefined ? { overall: bis.overall } : {}),
    ...(bis.presets !== undefined ? { presets: bis.presets } : {}),
    raidUrl: bis.raidUrl,
    mythicplusUrl: bis.mythicplusUrl,
    overallUrl: bis.overallUrl,
    presetUrls: bis.presetUrls,
    scrapedAt: new Date().toISOString(),
  };

  fs.writeFileSync(filePath, JSON.stringify(existing, null, 2), "utf-8");
}

// ──────────────────────────────────────────────
// Lua generation helpers
// ──────────────────────────────────────────────

/** Provider name → display labels for raid and m+ */
export const PROVIDER_LABELS: Record<string, { raid?: string; mythicplus?: string; overall?: string }> = {
  archon:  { raid: "Archon - Raid",  mythicplus: "Archon - M+" },
  wowhead: { overall: "Wowhead - Overall" },
  murlok:  { mythicplus: "Murlok - M+" },
  method:  { raid: "Method - Raid",  mythicplus: "Method - M+", overall: "Method - Overall" },
  icyveins: { raid: "Icy Veins - Raid", mythicplus: "Icy Veins - M+", overall: "Icy Veins - Overall" },
};

interface PresetEntry { slots: SlotItems; sourceUrl?: string; }
export type NestedData = Record<string, Record<string, Record<string, PresetEntry>>>;

export function loadAllJson(): NestedData {
  const all: NestedData = {};
  if (!fs.existsSync(JSON_DIR)) return all;
  const clean = (s: SlotItems) => {
    const o: SlotItems = {};
    for (const [k, v] of Object.entries(s)) if (k !== "_RAW" && v.length > 0) o[k] = v;
    return o;
  };

  for (const file of fs.readdirSync(JSON_DIR).filter(f => f.endsWith(".json"))) {
    const d: ClassJson = JSON.parse(fs.readFileSync(path.join(JSON_DIR, file), "utf-8"));
    const className = d.key;

    for (const [specName, providers] of Object.entries(d.specs || {})) {
      for (const [provider, data] of Object.entries(providers)) {
        const labels = PROVIDER_LABELS[provider.toLowerCase()] || {
          raid: `${provider} - Raid`,
          mythicplus: `${provider} - M+`,
          overall: `${provider} - Overall`,
        };

        if (!all[className]) all[className] = {};
        if (!all[className][specName]) all[className][specName] = {};

        if(data.raid && labels.raid) {
          const r = clean(data.raid || {});
          if (Object.keys(r).length > 0) {
            all[className][specName][labels.raid] = {slots: r, sourceUrl: data.raidUrl};
          }
        }
        if(data.mythicplus && labels.mythicplus) {
          const m = clean(data.mythicplus || {});
          if (Object.keys(m).length > 0) {
            all[className][specName][labels.mythicplus] = { slots: m, sourceUrl: data.mythicplusUrl };
          }
        }
        if (data.overall && labels.overall) {
          const o = clean(data.overall);
          if (Object.keys(o).length > 0) {
            all[className][specName][labels.overall] = { slots: o, sourceUrl: data.overallUrl };
          }
        }
        if (data.presets) {
          for (const [presetName, slots] of Object.entries(data.presets)) {
            const p = clean(slots);
            if (Object.keys(p).length > 0) {
              all[className][specName][presetName] = {
                slots: p,
                sourceUrl: data.presetUrls?.[presetName] || data.overallUrl || data.raidUrl || data.mythicplusUrl,
              };
            }
          }
        }
      }
    }
  }
  return all;
}

export function generateLua(allData: NestedData): string {
  const lines = [
    "-- GeneratedBiS.lua",
    "-- Auto-generated from tools/generated/*.json",
    `-- Generated: ${new Date().toISOString()}`,
    "-- DO NOT EDIT — run 'npm run scrape' or 'npm run generate' in tools/",
    "", "GearManagerBiSDB = {",
  ];

  for (const className of Object.keys(allData).sort()) {
    const specs = allData[className];
    lines.push(`    ["${className}"] = {`);
    for (const specName of Object.keys(specs).sort()) {
      const presets = specs[specName];
      lines.push(`        ["${specName}"] = {`);
      for (const presetLabel of Object.keys(presets).sort()) {
        const entry = presets[presetLabel];
        const sks = Object.keys(entry.slots).sort();
        if (sks.length === 0) continue;
        lines.push(`            ["${presetLabel}"] = {`);
        if (entry.sourceUrl) {
          lines.push(`                _sourceUrl = "${entry.sourceUrl}",`);
        }
        for (const sk of sks) {
          if (entry.slots[sk].length > 0) {
            lines.push(`                ${sk} = { ${entry.slots[sk].join(", ")} },`);
          }
        }
        lines.push("            },");
      }
      lines.push("        },");
    }
    lines.push("    },");
  }

  lines.push("}", "");
  return lines.join("\n");
}

