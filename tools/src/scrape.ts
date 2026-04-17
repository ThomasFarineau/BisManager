/**
 * GearManager BiS Scraper
 *
 * Scrapes BiS lists from one or all providers for every class/spec,
 * stores results as JSON, then generates Lua.
 *
 * Usage:
 *   npm run scrape                          — scrape all providers
 *   npm run scrape -- --provider archon     — scrape a single provider
 *   npm run scrape -- --provider archon,murlok  — scrape multiple providers
 */

import { Command } from "commander";
import puppeteer from "puppeteer";
import * as fs from "fs";
import * as cliProgress from "cli-progress";
import { getProvider, getAvailableProviders } from "./providers";
import {
  SPECS, JSON_DIR, DATA_DIR, LUA_OUT,
  ensureDir, saveJson,
  loadAllJson, generateLua,
} from "./shared";

const PARALLEL = 10;

const program = new Command();

program
  .name("scrape")
  .description("Scrape BiS lists from one or all providers and generate Lua")
  .option(
    "-p, --provider <names>",
    `Comma-separated providers to use (${getAvailableProviders().join(", ")}). Default: all`,
    "all",
  )
  .option("--parallel <n>", "Number of parallel requests per provider", String(PARALLEL))
  .action(async (opts) => {
    const all = getAvailableProviders();
    const providerNames = opts.provider === "all"
      ? all
      : opts.provider.split(",").map((s: string) => s.trim()).filter(Boolean);
    const parallel = parseInt(opts.parallel, 10) || PARALLEL;

    console.log(`=== GearManager BiS Scraper ===`);
    console.log(`Providers: ${providerNames.join(", ")}`);
    console.log(`${SPECS.length} specs × ${providerNames.length} provider(s), ${parallel} parallel\n`);

    const browser = await puppeteer.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    for (const providerName of providerNames) {
      const provider = getProvider(providerName);
      console.log(`\n── Provider: ${provider.name} ──`);

      const bar = new cliProgress.SingleBar({
        format: `  [{providerName}] |{bar}| {value}/{total} specs ({percentage}%) — {spec}`,
        barCompleteChar: "█",
        barIncompleteChar: "░",
        clearOnComplete: false,
        hideCursor: true,
      }, cliProgress.Presets.shades_classic);

      bar.start(SPECS.length, 0, { spec: "…", providerName: provider.name });

      const results: { key: string; bis: Awaited<ReturnType<typeof provider.getBis>> }[] = [];

      for (let i = 0; i < SPECS.length; i += parallel) {
        const batch = SPECS.slice(i, i + parallel);
        const batchResults = await Promise.all(batch.map(async (spec) => {
          const key = `${spec.className}_${spec.specName}`;
          const bis = await provider.getBis(browser, spec);
          bar.increment(1, { spec: key, providerName: provider.name });
          return { key, bis };
        }));
        results.push(...batchResults);
        if (i + parallel < SPECS.length) await new Promise(r => setTimeout(r, 1_000));
      }

      bar.stop();

      ensureDir(JSON_DIR);
      for (const { key, bis } of results) saveJson(key, providerName, bis);
      console.log(`✅ ${results.length} specs saved for provider "${provider.name}"`);
    }

    await browser.close();

    // Generate Lua
    console.log("\n=== Generating Lua from JSON ===");
    const allData = loadAllJson();
    ensureDir(DATA_DIR);
    fs.writeFileSync(LUA_OUT, generateLua(allData), "utf-8");
    let count = 0;
    for (const cls of Object.values(allData))
      for (const spec of Object.values(cls))
        count += Object.keys(spec).length;
    console.log(`✅ ${LUA_OUT} — ${count} presets`);
  });

program.parse();
