/**
 * Wowhead BiS Provider
 *
 * Scrapes https://www.wowhead.com/guide/classes/{class}/{spec}/bis-gear
 * Extracts the Overall BiS table from #tab-bis-items-overall-bis (JS-rendered).
 */

import { type Browser } from "puppeteer";
import { BiSProvider, type BiSResult, type SpecDef, resolveSlot } from "./provider";

const PAGE_TIMEOUT = 60_000;

export class WowheadProvider extends BiSProvider {
  readonly name = "wowhead";

  async getBis(browser: Browser, spec: SpecDef): Promise<BiSResult> {
    const url = `https://www.wowhead.com/guide/classes/${spec.urlClass}/${spec.urlSpec}/bis-gear`;
    const result: BiSResult = { overall: {}, overallUrl: url + '#tab-bis-items-overall-bis' };

    const page = await browser.newPage();
    try {
      await page.setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0.0.0 Safari/537.36");
      await page.setRequestInterception(true);
      page.on("request", r => ["image", "font", "media"].includes(r.resourceType()) ? r.abort() : r.continue());

      await page.goto(url, { waitUntil: "networkidle2", timeout: PAGE_TIMEOUT });

      // Wait for any bis-items tab panel with a table to be rendered
      try {
        await page.waitForSelector('[id^="tab-bis-items-"] table', { timeout: 20_000 });
      } catch {
        console.error(`  [WARN] wowhead ${spec.className}_${spec.specName}: BiS table not found`);
        return result;
      }

      const rows = await page.evaluate(() => {
        const out: { slot: string; itemIds: number[] }[] = [];
        // Target any tab panel that starts with "tab-bis-items-"
        const panels = document.querySelectorAll('[id^="tab-bis-items-"]');
        const panel = panels[0];
        if (!panel) return out;

        const trs = panel.querySelectorAll("table tr");
        for (const tr of trs) {
          const cells = tr.querySelectorAll("td");
          if (cells.length < 2) continue;

          const slotText = (cells[0].textContent || "").trim();
          if (!slotText || slotText === "Slot") continue;

          const ids: number[] = [];
          cells[1].querySelectorAll("a[href]").forEach((a: Element) => {
            const m = ((a as HTMLAnchorElement).getAttribute("href") || "").match(/\/item=(\d+)/);
            if (m) {
              const id = parseInt(m[1], 10);
              if (id > 0 && !ids.includes(id)) ids.push(id);
            }
          });

          if (ids.length > 0) out.push({ slot: slotText, itemIds: ids });
        }
        return out;
      });

      for (const { slot, itemIds } of rows) {
        const key = resolveSlot(slot);
        if (!key) continue;
        if (!result.overall![key]) result.overall![key] = [];
        for (const id of itemIds) if (!result.overall![key].includes(id)) result.overall![key].push(id);
      }
    } catch (err) {
      console.error(`  [ERROR] wowhead ${spec.className}_${spec.specName}: ${err}`);
    } finally {
      await page.close();
    }

    return result;
  }
}
