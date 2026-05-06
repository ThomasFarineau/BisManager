/**
 * Method.gg BiS Provider
 *
 * Fetches https://www.method.gg/guides/{spec}-{class}/gearing (SSR page)
 * and parses the HTML directly — no Puppeteer needed.
 * - #raid_table    → raid BiS
 * - #dungeon_table → M+ BiS
 */

import { type Browser } from "puppeteer";
import { parse } from "node-html-parser";
import { BiSProvider, type BiSResult, type SpecDef, resolveSlot } from "./provider";
import { type MethodConfig, fillTemplate, providerConfig } from "../config";

const METHOD_CONFIG = providerConfig<MethodConfig>("method");

function methodUrl(spec: SpecDef): string {
  return `${METHOD_CONFIG.baseUrl}${fillTemplate(METHOD_CONFIG.guidePath, { spec: spec.urlSpec, class: spec.urlClass })}`;
}

function parseTable(html: ReturnType<typeof parse>, selector: string): { slot: string; itemIds: number[] }[] {
  const rows: { slot: string; itemIds: number[] }[] = [];
  const container = html.querySelector(selector);
  if (!container) return rows;

  for (const tr of container.querySelectorAll("tr")) {
    const cells = tr.querySelectorAll("td");
    if (cells.length < 2) continue;

    const slotText = cells[0].textContent.trim();
    if (!slotText || slotText === "Slot") continue;

    const ids: number[] = [];
    for (const a of cells[1].querySelectorAll("a[href]")) {
      const m = (a.getAttribute("href") || "").match(/\/item=(\d+)/);
      if (m) {
        const id = parseInt(m[1], 10);
        if (id > 0 && !ids.includes(id)) ids.push(id);
      }
    }

    if (ids.length > 0) rows.push({ slot: slotText, itemIds: ids });
  }

  return rows;
}

export class MethodProvider extends BiSProvider {
  readonly name = "method";

  async getBis(_browser: Browser, spec: SpecDef): Promise<BiSResult> {
    const url = methodUrl(spec);
    const result: BiSResult = { raid: {}, mythicplus: {}, raidUrl: url + '#raid_table', mythicplusUrl: url + '#dungeon_table', overallUrl: url + '#overall_table' };

    try {
      const res = await fetch(url, {
        headers: { "User-Agent": METHOD_CONFIG.userAgent },
      });

      if (!res.ok) {
        throw new Error(`method ${spec.className}_${spec.specName}: HTTP ${res.status}`);
      }

      const html = parse(await res.text());

      const sections: { section: "raid" | "mythicplus" | "overall"; selector: string }[] = [
        { section: "raid",       selector: METHOD_CONFIG.selectors.raid },
        { section: "mythicplus", selector: METHOD_CONFIG.selectors.mythicplus },
        { section: "overall",    selector: METHOD_CONFIG.selectors.overall },
      ];

      for (const { section, selector } of sections) {
        const target = section === "mythicplus" ? result.mythicplus! : section === "overall" ? (result.overall ??= {}) : result.raid!;
        for (const { slot, itemIds } of parseTable(html, selector)) {
          const key = resolveSlot(slot);
          if (!key) continue;
          if (!target[key]) target[key] = [];
          for (const id of itemIds) if (!target[key].includes(id)) target[key].push(id);
        }
      }
    } catch (err) {
      throw new Error(`method ${spec.className}_${spec.specName}: ${err}`);
    }

    return result;
  }
}
