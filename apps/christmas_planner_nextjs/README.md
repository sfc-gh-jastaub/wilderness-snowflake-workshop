# Christmas Tent Planner

**Workshop sample for Lab 2 Step 7.** It reads `CHRISTMAS_PLAN` as `setup/91_catch_up_lab2.sql` builds it (columns `TENTS_ON_HAND`, `TENTS_TO_SEND_BACK`, `FORECAST_TO_XMAS`, `GAP`, `ACTION`), so run that script first if your own plan has different columns.

A Snowflake App (Next.js on Snowflake App Runtime) that shows which stores will have too many tents this Christmas and which won't have enough.

## What it shows

- **Three tiles for the whole network:**
  - **Tents to send back:** B26-07 tents.
  - **Tents to move between stores:** the smaller of total spare and total shortfall.
  - **Tents to reorder by 13 Nov:** shortfall minus spare, floored at zero.
- **State filter:** chips showing each state's net gap. The filter fades out stores and routes in other states.
- **Map of Australia:** every store is a bubble, red for `MOVE IN` and green for `MOVE OUT`, sized by its gap. Hover a store for its numbers; click it for detail.
- **Santa's sleigh transfer plan:** each short store pulls tents from its nearest stores with spare, biggest shortfall first. The routes are drawn as animated gold arcs, and clicking a route highlights it. Any shortfall left over is what needs reordering, and those per-store figures add up to the reorder tile.

## Data

| Source | Use |
|---|---|
| `WILDERNESS_HOL.LAB2_ANALYTICS.CHRISTMAS_PLAN` (dynamic table, hourly) | Good tents, B26-07, forecast, gap and action per store |
| `WILDERNESS_HOL.RAW.DIM_STORE` | Store latitude and longitude |

The KPIs and transfers are worked out in `lib/plan.ts`, served by `GET /api/plan` with owner's rights.

## Key files

- `app/api/plan/route.ts`: the Snowflake query, KPIs and transfer plan.
- `lib/plan.ts`: KPI and nearest-store transfer logic, tested in `__tests__/lib/plan.test.ts`.
- `lib/australia.ts`: a simplified coastline and projection, so the app needs no map tiles or network access.
- `components/planner/`: the map, tiles, count-up and planner page.

## Run and deploy

- **In a Snowsight workspace:** click **Preview** to run it, then **Deploy**.
- **From the CLI:** run `npm install && npm run dev` locally, then `snow app deploy`.

The deployment settings are in `app.yml` (version 2): `WILDERNESS_HOL.LAB2_ANALYTICS`, warehouse `WILDERNESS_WH`, app name `CHRISTMAS_PLANNER`.

## Pitfalls

- Keep the `turbopack.root` / `outputFileTracingRoot` pin in `next.config.mjs`.
- Use `next dev` / `next start` for local preview, not `node .next/standalone/server.js`.
- The app reads the dynamic table directly. If `CHRISTMAS_PLAN` is dropped or suspended, the page shows an error.
