/**
 * Icy Veins BiS Provider
 *
 * Fetches the Icy Veins Gear and Best in Slot guide page and parses the static
 * BiS tables. Most pages expose tabbed table sections for overall, raid, and
 * Mythic+ gear.
 */

import { type Browser } from "puppeteer";
import { parse, type HTMLElement } from "node-html-parser";
import { type IcyVeinsConfig, fillTemplate, providerConfig } from "../config";
import { BiSProvider, type BiSResult, type SlotItems, type SpecDef, resolveSlot } from "./provider";

const ICYVEINS_CONFIG = providerConfig<IcyVeinsConfig>("icyveins");

function icyVeinsUrl(spec: SpecDef): string {
  const role = ICYVEINS_CONFIG.roleBySpecName[spec.specName] ?? "dps";
  return `${ICYVEINS_CONFIG.baseUrl}${fillTemplate(ICYVEINS_CONFIG.guidePath, {
    class: spec.urlClass,
    role,
    spec: spec.urlSpec,
  })}`;
}

function normalizeText(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function presetName(label: string): string {
  return `${ICYVEINS_CONFIG.presetPrefix}${normalizeText(label)}`;
}

function tableHasBisColumns(table: HTMLElement): boolean {
  const headerText = normalizeText(table.querySelectorAll("th").map(th => th.textContent).join(" ")).toLowerCase();
  return headerText.includes("slot") && headerText.includes("item");
}

function extractItemIds(itemCell: HTMLElement): number[] {
  const ids: number[] = [];
  const candidates = [
    ...itemCell.querySelectorAll("[data-wowhead]").map(el => el.getAttribute("data-wowhead") || ""),
    ...itemCell.querySelectorAll("a[href]").map(el => el.getAttribute("href") || ""),
  ];

  for (const candidate of candidates) {
    const match = candidate.match(/(?:item=|\/item\/)(\d+)/);
    if (!match) continue;

    const id = parseInt(match[1], 10);
    if (id > 0 && !ids.includes(id)) ids.push(id);
    if (ICYVEINS_CONFIG.firstItemOnly && ids.length > 0) break;
  }

  return ids;
}

function addTableItems(target: SlotItems, table: HTMLElement) {
  for (const tr of table.querySelectorAll("tr")) {
    const cells = tr.querySelectorAll("td");
    if (cells.length < 2) continue;

    const slot = resolveSlot(cells[0].textContent);
    if (!slot) continue;

    const itemIds = extractItemIds(cells[1]);
    if (itemIds.length === 0) continue;

    if (!target[slot]) target[slot] = [];
    for (const id of itemIds) {
      if (!target[slot].includes(id)) target[slot].push(id);
    }
  }
}

function parseIcyVeinsBis(htmlText: string, url: string): Pick<BiSResult, "presets" | "presetUrls"> {
  const html = parse(htmlText);
  const presets: Record<string, SlotItems> = {};
  const presetUrls: Record<string, string> = {};

  const tabContents = html.querySelectorAll(ICYVEINS_CONFIG.tabContentSelector);
  if (tabContents.length > 0) {
    for (const content of tabContents) {
      const id = content.getAttribute("id") || "";
      const buttonLabel = html.querySelector(`#${id}_button`)?.textContent || content.textContent.slice(0, 120);
      const name = presetName(buttonLabel);
      const target: SlotItems = {};

      for (const table of content.querySelectorAll("table")) {
        if (tableHasBisColumns(table)) addTableItems(target, table);
      }

      if (Object.keys(target).length > 0) {
        presets[name] = target;
        presetUrls[name] = `${url}#${id}`;
      }
    }
  } else {
    const name = presetName("Gear and Best in Slot");
    const target: SlotItems = {};
    for (const table of html.querySelectorAll("table")) {
      if (tableHasBisColumns(table)) addTableItems(target, table);
    }
    if (Object.keys(target).length > 0) {
      presets[name] = target;
      presetUrls[name] = url;
    }
  }

  return { presets, presetUrls };
}

export class IcyVeinsProvider extends BiSProvider {
  readonly name = "icyveins";

  async getBis(_browser: Browser, spec: SpecDef): Promise<BiSResult> {
    const url = icyVeinsUrl(spec);

    try {
      const res = await fetch(url, {
        headers: { "User-Agent": ICYVEINS_CONFIG.userAgent },
      });

      if (!res.ok) {
        throw new Error(`icyveins ${spec.className}_${spec.specName}: HTTP ${res.status}`);
      }

      const result = parseIcyVeinsBis(await res.text(), url);
      return {
        ...result,
      };
    } catch (err) {
      throw new Error(`icyveins ${spec.className}_${spec.specName}: ${err}`);
    }
  }
}
