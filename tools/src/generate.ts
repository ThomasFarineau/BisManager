/**
 * GearManager Lua Generator
 *
 * Regenerates GeneratedBiS.lua from existing JSON files.
 *
 * Usage:
 *   npm run generate
 */

import { Command } from "commander";
import * as fs from "fs";
import * as cliProgress from "cli-progress";
import {
  DATA_DIR, LUA_OUT,
  ensureDir, loadAllJson,
  NestedData,
} from "./shared";

const program = new Command();

program
  .name("generate")
  .description("Regenerate GeneratedBiS.lua from existing JSON data")
  .action(() => {
    console.log("=== Generating Lua from JSON ===\n");

    // Count total presets for progress bar
    const allData = loadAllJson();
    let total = 0;
    for (const cls of Object.values(allData))
      for (const spec of Object.values(cls))
        total += Object.keys(spec).length;

    const bar = new cliProgress.SingleBar({
      format: "  Generating |{bar}| {value}/{total} presets ({percentage}%) — {className}/{specName}",
      barCompleteChar: "█",
      barIncompleteChar: "░",
      clearOnComplete: false,
      hideCursor: true,
    }, cliProgress.Presets.shades_classic);

    bar.start(total, 0, { className: "…", specName: "…" });

    // Re-implement generateLua with progress ticks
    const lua = generateLuaWithProgress(allData, (className, specName) => {
      bar.increment(1, { className, specName });
    });

    bar.stop();

    ensureDir(DATA_DIR);
    fs.writeFileSync(LUA_OUT, lua, "utf-8");
    console.log(`\n✅ ${LUA_OUT} — ${total} presets`);
  });

function generateLuaWithProgress(
  allData: NestedData,
  onPreset: (className: string, specName: string) => void,
): string {
  const lines = [
    "-- GeneratedBiS.lua",
    "-- Auto-generated from tools/generated/*.json",
    `-- Generated: ${new Date().toISOString()}`,
    "-- DO NOT EDIT — run 'npm run scrape' or 'npm run generate' in tools/",
    "", "GearManagerBiSDB = {",
  ];

  for (const className of Object.keys(allData).sort()) {
    lines.push(`    ["${className}"] = {`);
    for (const specName of Object.keys(allData[className]).sort()) {
      const presets = allData[className][specName];
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
        onPreset(className, specName);
      }
      lines.push("        },");
    }
    lines.push("    },");
  }

  lines.push("}", "");
  return lines.join("\n");
}

program.parse();
