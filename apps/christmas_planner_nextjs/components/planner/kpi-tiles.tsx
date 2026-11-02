'use client';

import { CountUp } from '@/components/planner/count-up';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { Kpis } from '@/lib/plan';
import { cn } from '@/lib/utils';
import { PackageX, ShoppingCart, Truck, type LucideIcon } from 'lucide-react';

function Tile({
  label,
  value,
  hint,
  how,
  icon: Icon,
  tone,
}: {
  label: string;
  value: number;
  hint: string;
  how: string;
  icon: LucideIcon;
  tone: 'gold' | 'green' | 'red';
}) {
  const toneCls = {
    gold: 'bg-gold/15 text-gold-foreground',
    green: 'bg-move-out/15 text-move-out',
    red: 'bg-move-in/15 text-move-in',
  }[tone];
  return (
    <Card
      className="group relative overflow-hidden p-5 transition-all hover:-translate-y-0.5 hover:shadow-lg motion-reduce:transition-none"
      title={how}
    >
      <div
        className={cn(
          'absolute inset-x-0 top-0 h-1',
          tone === 'gold' && 'bg-gold',
          tone === 'green' && 'bg-move-out',
          tone === 'red' && 'bg-move-in',
        )}
      />
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm font-medium text-muted-foreground">{label}</p>
        <span className={cn('flex h-9 w-9 items-center justify-center rounded-lg', toneCls)}>
          <Icon className="h-4 w-4" />
        </span>
      </div>
      <p className="mt-2 text-3xl font-semibold tracking-tight tabular-nums">
        <CountUp value={value} />
      </p>
      <p className="mt-1 text-xs text-muted-foreground">{hint}</p>
      <p className="mt-3 max-h-0 overflow-hidden text-xs text-muted-foreground opacity-0 transition-all duration-300 group-hover:max-h-12 group-hover:opacity-100">
        {how}
      </p>
    </Card>
  );
}

export function KpiTiles({ kpis }: { kpis: Kpis }) {
  return (
    <div className="grid gap-4 sm:grid-cols-3">
      <Tile
        label="Tents to send back"
        value={kpis.sendBack}
        hint="Faulty batch B26-07 across all stores"
        how="Sum of B26-07 tents on hand. These leave the network before Christmas."
        icon={PackageX}
        tone="gold"
      />
      <Tile
        label="Tents to move between stores"
        value={kpis.toMove}
        hint={`${kpis.spare.toLocaleString('en-AU')} spare vs ${kpis.short.toLocaleString('en-AU')} short`}
        how="The smaller of total spare (positive gaps) and total shortfall (negative gaps)."
        icon={Truck}
        tone="green"
      />
      <Tile
        label="Tents to reorder by 13 Nov"
        value={kpis.toReorder}
        hint={`${kpis.storesShort} of ${kpis.stores} stores are short`}
        how="Total shortfall minus total spare, floored at zero — what transfers can't cover."
        icon={ShoppingCart}
        tone="red"
      />
    </div>
  );
}

export function KpiTilesSkeleton() {
  return (
    <div className="grid gap-4 sm:grid-cols-3">
      {[0, 1, 2].map((i) => (
        <Card key={i} className="p-5">
          <Skeleton className="h-4 w-40" />
          <Skeleton className="mt-3 h-8 w-24" />
          <Skeleton className="mt-2 h-3 w-32" />
        </Card>
      ))}
    </div>
  );
}
