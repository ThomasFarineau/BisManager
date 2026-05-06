/**
 * Wowhead BiS Provider
 *
 * Scrapes https://www.wowhead.com/guide/classes/{class}/{spec}/bis-gear
 * Extracts the Overall BiS table from #tab-bis-items-overall-bis (JS-rendered).
 */

import { type Browser } from "puppeteer";
import { BiSProvider, type BiSResult, type SpecDef, resolveSlot } from "./provider";
import { type WowheadConfig, fillTemplate, providerConfig } from "../config";

const WOWHEAD_CONFIG = providerConfig<WowheadConfig>("wowhead");

export class WowheadProvider extends BiSProvider {
  readonly name = "wowhead";

  async getBis(browser: Browser, spec: SpecDef): Promise<BiSResult> {
    const url = `${WOWHEAD_CONFIG.baseUrl}${fillTemplate(WOWHEAD_CONFIG.guidePath, { class: spec.urlClass, spec: spec.urlSpec })}`;
    const result: BiSResult = { overall: {}, overallUrl: url + WOWHEAD_CONFIG.overallAnchor };

    const page = await browser.newPage();
    try {
      await page.setUserAgent(WOWHEAD_CONFIG.userAgent);
      await page.setRequestInterception(true);
      page.on("request", r => WOWHEAD_CONFIG.blockedResourceTypes.includes(r.resourceType()) ? r.abort() : r.continue());

      await page.goto(url, { waitUntil: "networkidle2", timeout: WOWHEAD_CONFIG.pageTimeoutMs });

      // Wait for any bis-items tab panel with a table to be rendered
      try {
        await page.waitForSelector(WOWHEAD_CONFIG.tableSelector, { timeout: WOWHEAD_CONFIG.tableTimeoutMs });
      } catch {
        throw new Error(`wowhead ${spec.className}_${spec.specName}: BiS table not found`);
      }

      const rows = await page.evaluate((panelSelector) => {
        const out: { slot: string; itemIds: number[] }[] = [];
        // Target any tab panel that starts with "tab-bis-items-"
        const panels = document.querySelectorAll(panelSelector);
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
      }, WOWHEAD_CONFIG.panelSelector);

      for (const { slot, itemIds } of rows) {
        const key = resolveSlot(slot);
        if (!key) continue;
        if (!result.overall![key]) result.overall![key] = [];
        for (const id of itemIds) if (!result.overall![key].includes(id)) result.overall![key].push(id);
      }
    } catch (err) {
      throw new Error(`wowhead ${spec.className}_${spec.specName}: ${err}`);
    } finally {
      await page.close();
    }

    return result;
  }
}
