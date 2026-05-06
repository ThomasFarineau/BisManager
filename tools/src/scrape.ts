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
import { type Browser } from "puppeteer";
import { getProvider, getAvailableProviders, type BiSProvider, type BiSResult, type SpecDef } from "./providers";
import { scrapeConfig, scrapeProviderConfig } from "./config";
import {
  SPECS, JSON_DIR, DATA_DIR, LUA_OUT,
  ensureDir, saveJson,
  loadAllJson, generateLua,
} from "./shared";

function parseOptionalInt(value: unknown): number | undefined {
  if (typeof value !== "string") return undefined;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function wait(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function scrapeWithRetries(
  provider: BiSProvider,
  browser: Browser,
  spec: SpecDef,
  retries: number,
): Promise<BiSResult> {
  const key = `${spec.className}_${spec.specName}`;
  let lastError: unknown;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await provider.getBis(browser, spec);
    } catch (err) {
      lastError = err;
      if (attempt < retries) {
        console.error(`  [WARN] ${provider.name} ${key}: attempt ${attempt + 1}/${retries + 1} failed, retrying...`);
        await wait(scrapeConfig.batchDelayMs);
      }
    }
  }

  console.error(`  [ERROR] ${provider.name} ${key}: failed after ${retries + 1} attempt(s): ${lastError}`);
  return {};
}

const program = new Command();

program
  .name("scrape")
  .description("Scrape BiS lists from one or all providers and generate Lua")
  .option(
    "-p, --provider <names>",
    `Comma-separated providers to use (${getAvailableProviders().join(", ")}). Default: all`,
    "all",
  )
  .option("--parallel <n>", "Override number of parallel requests for every provider")
  .option("--retries <n>", "Override retry count for every provider")
  .action(async (opts) => {
    const all = getAvailableProviders();
    const providerNames = opts.provider === "all"
      ? all
      : opts.provider.split(",").map((s: string) => s.trim()).filter(Boolean);
    const parallelOverride = parseOptionalInt(opts.parallel);
    const retriesOverride = parseOptionalInt(opts.retries);

    console.log(`=== GearManager BiS Scraper ===`);
    console.log(`Providers: ${providerNames.join(", ")}`);
    console.log(`${SPECS.length} specs × ${providerNames.length} provider(s)\n`);

    const browser = await puppeteer.launch({
      headless: scrapeConfig.browser.headless,
      args: scrapeConfig.browser.args,
    });

    for (const providerName of providerNames) {
      const provider = getProvider(providerName);
      const providerScrapeConfig = scrapeProviderConfig(provider.name);
      const parallel = parallelOverride ?? providerScrapeConfig.parallel;
      const retries = retriesOverride ?? providerScrapeConfig.retries;
      console.log(`\n── Provider: ${provider.name} ──`);
      console.log(`  parallel: ${parallel}, retries: ${retries}`);

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
          const bis = await scrapeWithRetries(provider, browser, spec, retries);
          bar.increment(1, { spec: key, providerName: provider.name });
          return { key, bis };
        }));
        results.push(...batchResults);
        if (i + parallel < SPECS.length) await wait(scrapeConfig.batchDelayMs);
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
