// Christmas Tent Planner — one interactive page. Data comes client-side from
// /api/plan (CHRISTMAS_PLAN joined to DIM_STORE) via React Query.

import { Planner } from '@/components/planner/planner';

// Required: Snowflake is not reachable during docker build.
export const dynamic = 'force-dynamic';

export default function Home() {
  return (
    <main
      id="top"
      className="mx-auto w-full max-w-7xl space-y-6 px-4 py-6 sm:px-6 sm:py-10 lg:px-8 animate-in fade-in slide-in-from-bottom-2 duration-500 motion-reduce:animate-none"
    >
      <Planner />
    </main>
  );
}
