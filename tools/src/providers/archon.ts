/**
 * Archon.gg BiS Provider
 *
 * Uses the Next.js JSON data API to fetch gear data per spec:
 *   - /wow/builds/{spec}/{class}/mythic-plus/gear-and-tier-set/10/all-dungeons/this-week
 *   - /wow/builds/{spec}/{class}/raid/gear-and-tier-set/mythic/all-bosses
 */

import { type Browser } from "puppeteer";
import { BiSProvider, type BiSResult, type SlotItems, type SpecDef, resolveSlot } from "./provider";
import { type ArchonConfig, fillTemplate, providerConfig } from "../config";

const ARCHON_CONFIG = providerConfig<ArchonConfig>("archon");

/** Cache the buildId across calls */
let cachedBuildId: string | null = null;

async function fetchBuildId(): Promise<string> {
  if (cachedBuildId) return cachedBuildId;

  const res = await fetch(`${ARCHON_CONFIG.baseUrl}${ARCHON_CONFIG.routes.home}`, {
    headers: { "User-Agent": ARCHON_CONFIG.userAgent },
  });
  if (!res.ok) throw new Error(`archon buildId: HTTP ${res.status}`);

  const html = await res.text();

  // Extract buildId from __NEXT_DATA__ script
  const match = html.match(/"buildId"\s*:\s*"([^"]+)"/);
  if (match) {
    cachedBuildId = match[1];
    return cachedBuildId;
  }

  // Fallback: extract from _next/data/ links
  const linkMatch = html.match(/_next\/data\/([^/]+)\//);
  if (linkMatch) {
    cachedBuildId = linkMatch[1];
    return cachedBuildId;
  }

  throw new Error("Could not extract Archon buildId from page");
}

/**
 * Extract slot label from table header markup like:
 *   <ImageIcon ...>Main-Hand</ImageIcon>
 */
function extractSlotFromHeader(header: string): string | null {
  const m = header.match(/>([^<]+)<\//);
  if (m) return resolveSlot(m[1]);
  return resolveSlot(header);
}

/**
 * Extract percentage from popularity cell markup.
 * Looks for patterns like "29.5%" or ">29.5%"
 */
function extractPopularity(markup: string): number {
  const m = markup.match(/([\d.]+)\s*%/);
  return m ? parseFloat(m[1]) : 0;
}

/**
 * Extract all item IDs from an item cell markup like:
 *   <ItemIcon id={237846} ...>Blood Knight's Warblade</ItemIcon>
 */
function extractItemIds(markup: string): number[] {
  const ids: number[] = [];
  const re = /ItemIcon\s+id=\{(\d+)}/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(markup)) !== null) {
    const id = parseInt(m[1], 10);
    if (id > 0 && !ids.includes(id)) ids.push(id);
  }
  return ids;
}

interface ArchonTable {
  columns: {
    item?: { header: string };
    popularity?: { header: string };
  };
  data: Array<{ item: string; popularity?: string }>;
}

interface ArchonSection {
  component: string;
  props: {
    tables?: ArchonTable[];
    table?: ArchonTable;
  };
}

async function fetchArchonGear(buildId: string, spec: SpecDef, mode: "mythicplus" | "raid"): Promise<SlotItems> {
  const slots: SlotItems = {};
  const routeValues = { spec: spec.urlSpec, class: spec.urlClass };
  const pagePath = fillTemplate(ARCHON_CONFIG.routes[mode], routeValues);
  const params = fillTemplate(ARCHON_CONFIG.params[mode], routeValues);

  const url = `${ARCHON_CONFIG.baseUrl}/_next/data/${buildId}${pagePath}.json?${params}`;

  try {
    const res = await fetch(url, {
      headers: { "User-Agent": ARCHON_CONFIG.userAgent },
    });

    if (!res.ok) {
      throw new Error(`archon ${mode} ${spec.urlSpec}/${spec.urlClass}: HTTP ${res.status}`);
    }

    const json = await res.json() as {
      pageProps?: {
        page?: {
          sections?: ArchonSection[];
        };
      };
    };

    const sections = json?.pageProps?.page?.sections || [];

    for (const section of sections) {
      const tables = section.props?.tables || (section.props?.table ? [section.props.table] : []);

      for (const table of tables) {
        const header = table.columns?.item?.header || "";
        const slot = extractSlotFromHeader(header);
        if (!slot) continue;

        if (!slots[slot]) slots[slot] = [];

        for (const row of table.data || []) {
          const pop = extractPopularity(row.popularity || "");
          if (pop < ARCHON_CONFIG.minPopularity) continue;
          const itemIds = extractItemIds(row.item || "");
          for (const id of itemIds) {
            if (!slots[slot].includes(id)) slots[slot].push(id);
          }
        }
      }
    }
  } catch (err) {
    throw new Error(`archon ${mode} ${spec.urlSpec}/${spec.urlClass}: ${err}`);
  }

  return slots;
}

export class ArchonProvider extends BiSProvider {
  readonly name = "archon";

  async getBis(browser: Browser, spec: SpecDef): Promise<BiSResult> {
    const buildId = await fetchBuildId();

    const [raid, mythicplus] = await Promise.all([
      fetchArchonGear(buildId, spec, "raid"),
      fetchArchonGear(buildId, spec, "mythicplus"),
    ]);

    return {
      raid, mythicplus,
      raidUrl: `${ARCHON_CONFIG.baseUrl}${fillTemplate(ARCHON_CONFIG.routes.raid, { spec: spec.urlSpec, class: spec.urlClass })}`,
      mythicplusUrl: `${ARCHON_CONFIG.baseUrl}${fillTemplate(ARCHON_CONFIG.routes.mythicplus, { spec: spec.urlSpec, class: spec.urlClass })}`,
    };
  }
}

