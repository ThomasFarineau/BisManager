export { BiSProvider, type BiSResult, type SlotItems, type SpecDef, resolveSlot, SLOT_MAP } from "./provider";
export { WowheadProvider } from "./wowhead";
export { ArchonProvider } from "./archon";
export { MurlokProvider } from "./murlok";
export { MethodProvider } from "./method";
export { IcyVeinsProvider } from "./icyveins";

import { type BiSProvider } from "./provider";
import { WowheadProvider } from "./wowhead";
import { ArchonProvider } from "./archon";
import { MurlokProvider } from "./murlok";
import { MethodProvider } from "./method";
import { IcyVeinsProvider } from "./icyveins";

const PROVIDERS: Record<string, () => BiSProvider> = {
  wowhead: () => new WowheadProvider(),
  archon: () => new ArchonProvider(),
  murlok: () => new MurlokProvider(),
  method: () => new MethodProvider(),
  icyveins: () => new IcyVeinsProvider(),
};

export function getProvider(name: string): BiSProvider {
  const factory = PROVIDERS[name.toLowerCase()];
  if (!factory) {
    const available = Object.keys(PROVIDERS).join(", ");
    throw new Error(`Unknown provider "${name}". Available: ${available}`);
  }
  return factory();
}

export function getAvailableProviders(): string[] {
  return Object.keys(PROVIDERS);
}

