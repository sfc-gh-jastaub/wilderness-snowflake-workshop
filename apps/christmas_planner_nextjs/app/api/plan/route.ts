// Christmas plan for every store, straight from the CHRISTMAS_PLAN dynamic table that
// 91_catch_up_lab2.sql builds (refreshed hourly), joined to DIM_STORE for coordinates.
// KPIs and the transfer plan are derived here so every viewer sees the same numbers.

import { computeKpis, planTransfers, type Action, type PlanResponse, type Store } from '@/lib/plan';
import { querySnowflake } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';

const PLAN_SQL = `
SELECT p.STORE_ID, p.STORE_NAME, p.STATE, s.LATITUDE, s.LONGITUDE,
       p.TENTS_ON_HAND, p.TENTS_TO_SEND_BACK, p.TENTS_ON_HAND - p.TENTS_TO_SEND_BACK AS GOOD_TENTS,
       p.FORECAST_TO_XMAS, p.GAP, p.ACTION
FROM WILDERNESS_HOL.LAB2_ANALYTICS.CHRISTMAS_PLAN p
JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = p.STORE_ID
ORDER BY p.GAP`;

const num = (v: unknown) => Number(v ?? 0);

export async function GET() {
  try {
    const rows = await querySnowflake(PLAN_SQL);
    const stores: Store[] = rows.map((r) => ({
      storeId: String(r.STORE_ID),
      storeName: String(r.STORE_NAME),
      state: String(r.STATE),
      lat: num(r.LATITUDE),
      lon: num(r.LONGITUDE),
      tentsOnHand: num(r.TENTS_ON_HAND),
      b2607ToReturn: num(r.TENTS_TO_SEND_BACK),
      goodTents: num(r.GOOD_TENTS),
      forecast: num(r.FORECAST_TO_XMAS),
      gap: num(r.GAP),
      action: String(r.ACTION) as Action,
    }));
    const { transfers, reorderByStore } = planTransfers(stores);
    const body: PlanResponse = { stores, kpis: computeKpis(stores), transfers, reorderByStore };
    return Response.json(body);
  } catch (e) {
    console.error(new Date().toISOString(), 'Failed to load Christmas plan', e);
    return Response.json(
      { error: e instanceof Error ? e.message : 'Failed to load Christmas plan' },
      { status: 500 },
    );
  }
}
