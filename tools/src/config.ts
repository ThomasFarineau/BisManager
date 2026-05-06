import config = require("config");

type ProviderName = "archon" | "icyveins" | "method" | "murlok" | "wowhead";

export interface ScrapeProviderConfig {
  parallel?: number;
  retries?: number;
}

export interface ScrapeConfig {
  parallel: number;
  retries: number;
  batchDelayMs: number;
  browser: {
    headless: boolean;
    args: string[];
  };
  providers?: Partial<Record<ProviderName, ScrapeProviderConfig>>;
}

export interface ArchonConfig {
  baseUrl: string;
  userAgent: string;
  minPopularity: number;
  routes: Record<"home" | "raid" | "mythicplus", string>;
  params: Record<"raid" | "mythicplus", string>;
}

export interface MethodConfig {
  baseUrl: string;
  userAgent: string;
  guidePath: string;
  selectors: Record<"raid" | "mythicplus" | "overall", string>;
}

export interface MurlokConfig {
  apiBaseUrl: string;
  siteBaseUrl: string;
  userAgent: string;
  minPopularity: number;
  activities: Record<"mythicplus", string>;
}

export interface IcyVeinsConfig {
  baseUrl: string;
  userAgent: string;
  guidePath: string;
  firstItemOnly: boolean;
  presetPrefix: string;
  tabContentSelector: string;
  roleBySpecName: Record<string, string>;
}

export interface WowheadConfig {
  baseUrl: string;
  userAgent: string;
  pageTimeoutMs: number;
  tableTimeoutMs: number;
  guidePath: string;
  overallAnchor: string;
  tableSelector: string;
  panelSelector: string;
  blockedResourceTypes: string[];
}

export const scrapeConfig = config.get<ScrapeConfig>("scrape");

export function scrapeProviderConfig(provider: string): Required<ScrapeProviderConfig> {
  const providerOverrides = scrapeConfig.providers?.[provider.toLowerCase() as ProviderName] ?? {};
  return {
    parallel: providerOverrides.parallel ?? scrapeConfig.parallel,
    retries: providerOverrides.retries ?? scrapeConfig.retries,
  };
}

export function providerConfig<T>(provider: ProviderName): T {
  return config.get<T>(`providers.${provider}`);
}

export function fillTemplate(template: string, values: Record<string, string>): string {
  return template.replace(/\{(\w+)}/g, (_match, key: string) => values[key] ?? "");
}
