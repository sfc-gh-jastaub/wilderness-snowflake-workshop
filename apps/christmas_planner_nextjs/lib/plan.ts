// Pure planning logic shared by the /api/plan route and its tests:
// network-wide KPIs and the nearest-store transfer plan ("sleigh routes").

export type Action = 'MOVE IN' | 'MOVE OUT' | 'BALANCED';

export interface Store {
  storeId: string;
  storeName: string;
  state: string;
  lat: number;
  lon: number;
  tentsOnHand: number;
  b2607ToReturn: number;
  goodTents: number;
  forecast: number;
  /** good tents minus forecast: > 0 spare, < 0 short */
  gap: number;
  action: Action;
}

export interface Transfer {
  fromId: string;
  toId: string;
  tents: number;
  km: number;
}

export interface Kpis {
  sendBack: number;
  toMove: number;
  toReorder: number;
  spare: number;
  short: number;
  storesShort: number;
  stores: number;
}

export interface PlanResponse {
  stores: Store[];
  kpis: Kpis;
  transfers: Transfer[];
  /** shortfall left at each store after transfers (store id -> tents to reorder) */
  reorderByStore: Record<string, number>;
}

export function computeKpis(stores: Store[]): Kpis {
  let spare = 0;
  let short = 0;
  let sendBack = 0;
  let storesShort = 0;
  for (const s of stores) {
    if (s.gap > 0) spare += s.gap;
    if (s.gap < 0) short -= s.gap;
    sendBack += s.b2607ToReturn;
    if (s.action === 'MOVE IN') storesShort += 1;
  }
  return {
    sendBack,
    toMove: Math.min(spare, short),
    toReorder: Math.max(0, short - spare),
    spare,
    short,
    storesShort,
    stores: stores.length,
  };
}

/** Great-circle distance in km. */
export function haversineKm(aLat: number, aLon: number, bLat: number, bLon: number): number {
  const rad = Math.PI / 180;
  const dLat = (bLat - aLat) * rad;
  const dLon = (bLon - aLon) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(aLat * rad) * Math.cos(bLat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

/**
 * Greedy nearest-store plan: the biggest shortfalls go first, and each one
 * takes tents from the closest stores that still have spare, until either its
 * need or the network's spare runs out. Whatever is still short is a reorder.
 */
export function planTransfers(stores: Store[]): {
  transfers: Transfer[];
  reorderByStore: Record<string, number>;
} {
  const spare = new Map(stores.filter((s) => s.gap > 0).map((s) => [s.storeId, s.gap]));
  const donors = stores.filter((s) => s.gap > 0);
  const needy = stores.filter((s) => s.gap < 0).sort((a, b) => a.gap - b.gap);
  const transfers: Transfer[] = [];
  const reorderByStore: Record<string, number> = {};

  for (const to of needy) {
    let need = -to.gap;
    const nearest = donors
      .map((d) => ({ d, km: haversineKm(to.lat, to.lon, d.lat, d.lon) }))
      .sort((a, b) => a.km - b.km);
    for (const { d, km } of nearest) {
      if (need === 0) break;
      const left = spare.get(d.storeId) ?? 0;
      if (left === 0) continue;
      const tents = Math.min(left, need);
      spare.set(d.storeId, left - tents);
      need -= tents;
      transfers.push({ fromId: d.storeId, toId: to.storeId, tents, km: Math.round(km) });
    }
    if (need > 0) reorderByStore[to.storeId] = need;
  }
  return { transfers, reorderByStore };
}
