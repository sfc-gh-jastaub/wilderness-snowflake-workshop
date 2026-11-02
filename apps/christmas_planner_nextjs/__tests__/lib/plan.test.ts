import { describe, expect, it } from 'vitest';
import { computeKpis, planTransfers, type Store } from '../../lib/plan';

const store = (id: string, gap: number, lat: number, lon: number): Store => ({
  storeId: id,
  storeName: `Wilderness ${id}`,
  state: 'NSW',
  lat,
  lon,
  tentsOnHand: 100,
  b2607ToReturn: 10,
  goodTents: 90,
  forecast: 90 - gap,
  gap,
  action: gap > 0 ? 'MOVE OUT' : gap < 0 ? 'MOVE IN' : 'BALANCED',
});

describe('computeKpis', () => {
  it('derives send back, move and reorder', () => {
    const k = computeKpis([store('A', 30, 0, 0), store('B', -50, 0, 1), store('C', 0, 0, 2)]);
    expect(k).toMatchObject({ sendBack: 30, spare: 30, short: 50, toMove: 30, toReorder: 20, storesShort: 1 });
  });

  it('floors reorder at zero when spare exceeds shortfall', () => {
    expect(computeKpis([store('A', 80, 0, 0), store('B', -20, 0, 1)]).toReorder).toBe(0);
  });
});

describe('planTransfers', () => {
  it('fills from the nearest donor first and reorders the remainder', () => {
    const near = store('NEAR', 10, -33.9, 151.2);
    const far = store('FAR', 40, -31.9, 115.9);
    const needy = store('NEEDY', -60, -33.8, 151.0);
    const { transfers, reorderByStore } = planTransfers([near, far, needy]);
    expect(transfers.map((t) => [t.fromId, t.tents])).toEqual([
      ['NEAR', 10],
      ['FAR', 40],
    ]);
    expect(reorderByStore).toEqual({ NEEDY: 10 });
  });

  it('moves exactly min(spare, short) in total', () => {
    const stores = [store('A', 25, 0, 0), store('B', -10, 0, 1), store('C', -30, 0, 3)];
    const moved = planTransfers(stores).transfers.reduce((n, t) => n + t.tents, 0);
    expect(moved).toBe(computeKpis(stores).toMove);
  });
});
