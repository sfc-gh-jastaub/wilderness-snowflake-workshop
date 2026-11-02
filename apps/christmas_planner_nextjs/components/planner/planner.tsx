'use client';

import { AustraliaMap, radius } from '@/components/planner/australia-map';
import { KpiTiles, KpiTilesSkeleton } from '@/components/planner/kpi-tiles';
import { EmptyState } from '@/components/empty-state';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { PlanResponse, Store } from '@/lib/plan';
import { cn } from '@/lib/utils';
import { useQuery } from '@tanstack/react-query';
import { ArrowRight, Gift, RefreshCw, Sparkles, X } from 'lucide-react';
import type React from 'react';
import { useMemo, useState } from 'react';

const fmt = (n: number) => n.toLocaleString('en-AU');
const signed = (n: number) => `${n > 0 ? '+' : ''}${fmt(n)}`;
const short = (name: string) => name.replace(/^Wilderness /, '');

async function fetchPlan(): Promise<PlanResponse> {
  const r = await fetch('/api/plan');
  const json = await r.json();
  if (!r.ok) throw new Error(json.error ?? 'Failed to load plan');
  return json;
}

export function Planner() {
  const { data, error, isPending, isFetching, refetch, dataUpdatedAt } = useQuery({
    queryKey: ['plan'],
    queryFn: fetchPlan,
  });
  const [states, setStates] = useState<Set<string>>(new Set());
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [activeTransfer, setActiveTransfer] = useState<number | null>(null);
  const [showRoutes, setShowRoutes] = useState(true);

  const stores = data?.stores ?? [];
  const byId = useMemo(() => new Map(stores.map((s) => [s.storeId, s])), [stores]);
  const visible = (s: Store) => states.size === 0 || states.has(s.state);

  const stateGaps = useMemo(() => {
    const m = new Map<string, number>();
    for (const s of stores) m.set(s.state, (m.get(s.state) ?? 0) + s.gap);
    return [...m.entries()].sort((a, b) => a[1] - b[1]);
  }, [stores]);

  const toggleState = (st: string) =>
    setStates((prev) => {
      const next = new Set(prev);
      if (next.has(st)) next.delete(st);
      else next.add(st);
      return next;
    });

  const selectStore = (id: string | null) => {
    setSelectedId(id);
    setActiveTransfer(null);
    const s = id ? byId.get(id) : undefined;
    if (s && states.size > 0 && !states.has(s.state)) setStates(new Set([...states, s.state]));
  };

  const transfers = data?.transfers ?? [];
  const shownTransfers = transfers
    .map((t, i) => ({ t, i, from: byId.get(t.fromId)!, to: byId.get(t.toId)! }))
    .filter(({ from, to }) => from && to && (visible(from) || visible(to)));
  const movedShown = shownTransfers.reduce((n, x) => n + x.t.tents, 0);
  const kmShown = shownTransfers.reduce((n, x) => n + x.t.km * x.t.tents, 0);

  const ranked = stores.filter(visible).sort((a, b) => a.gap - b.gap);
  const selected = selectedId ? byId.get(selectedId) : undefined;

  if (error) {
    return (
      <EmptyState
        variant="error"
        title="Couldn't load the Christmas plan"
        description={error.message}
        action={
          <Button variant="outline" onClick={() => refetch()}>
            Try again
          </Button>
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      {/* Festive banner */}
      <section className="festive-banner relative overflow-hidden rounded-2xl px-6 py-6 text-white shadow-lg sm:px-8">
        <div className="relative z-10 flex flex-wrap items-end justify-between gap-4">
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-[0.25em] text-gold">Christmas 2026</p>
            <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-3xl">Tent Planner</h1>
            <p className="mt-1 max-w-xl text-sm text-white/75">
              Good tents (B26-07 excluded) against each store&apos;s forecast to 24 Dec. Click a store, a
              state or a sleigh route to explore.
            </p>
          </div>
          <div className="flex items-center gap-3 text-xs text-white/70">
            {dataUpdatedAt > 0 && <span>Loaded {new Date(dataUpdatedAt).toLocaleTimeString('en-AU')}</span>}
            <Button
              size="sm"
              variant="secondary"
              onClick={() => refetch()}
              disabled={isFetching}
              className="bg-white/15 text-white hover:bg-white/25"
            >
              <RefreshCw className={cn('h-3.5 w-3.5', isFetching && 'animate-spin')} />
              Refresh
            </Button>
          </div>
        </div>
      </section>

      {isPending ? <KpiTilesSkeleton /> : <KpiTiles kpis={data!.kpis} />}

      {/* State filter */}
      <div className="flex flex-wrap items-center gap-2">
        <span className="mr-1 text-sm font-medium text-muted-foreground">State</span>
        <Chip active={states.size === 0} onClick={() => setStates(new Set())}>
          All
        </Chip>
        {isPending
          ? [0, 1, 2, 3, 4, 5, 6].map((i) => <Skeleton key={i} className="h-8 w-20 rounded-full" />)
          : stateGaps.map(([st, gap]) => (
              <Chip key={st} active={states.has(st)} onClick={() => toggleState(st)}>
                {st}
                <span className={cn('tabular-nums text-xs', gap < 0 ? 'text-move-in' : 'text-move-out')}>
                  {signed(gap)}
                </span>
              </Chip>
            ))}
        <label className="ml-auto flex cursor-pointer items-center gap-2 text-sm text-muted-foreground">
          <input
            type="checkbox"
            className="h-4 w-4 accent-[var(--gold)]"
            checked={showRoutes}
            onChange={(e) => setShowRoutes(e.target.checked)}
          />
          Show sleigh routes
        </label>
      </div>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
        {/* Map */}
        <Card className="min-w-0 overflow-hidden">
          <CardHeader className="flex-row items-center justify-between space-y-0 pb-3">
            <div>
              <CardTitle>Stores by action</CardTitle>
              <CardDescription>Bubble size = size of the gap</CardDescription>
            </div>
            <div className="flex gap-3 text-xs">
              <Legend color="var(--move-in)" label="MOVE IN" />
              <Legend color="var(--move-out)" label="MOVE OUT" />
              <Legend color="var(--gold)" label="Sleigh route" line />
            </div>
          </CardHeader>
          <CardContent className="p-3 pt-0">
            {isPending ? (
              <Skeleton className="aspect-[4/3] w-full rounded-xl" />
            ) : stores.length === 0 ? (
              <EmptyState title="No stores in CHRISTMAS_PLAN" />
            ) : (
              <AustraliaMap
                stores={stores}
                transfers={transfers}
                visible={visible}
                hoverId={hoverId}
                selectedId={selectedId}
                activeTransfer={activeTransfer}
                showRoutes={showRoutes}
                onHover={setHoverId}
                onSelect={selectStore}
              />
            )}
          </CardContent>
        </Card>

        {/* Store detail or ranking */}
        <Card className="flex min-w-0 flex-col">
          {selected ? (
            <StoreDetail
              store={selected}
              reorder={data?.reorderByStore[selected.storeId] ?? 0}
              transfers={transfers}
              byId={byId}
              onClose={() => selectStore(null)}
              onPick={selectStore}
            />
          ) : (
            <>
              <CardHeader className="pb-3">
                <CardTitle>Stores, most short first</CardTitle>
                <CardDescription>
                  {ranked.length} stores · hover to find on the map, click for detail
                </CardDescription>
              </CardHeader>
              <CardContent className="min-h-0 flex-1 p-0">
                <ul className="max-h-[520px] divide-y overflow-y-auto">
                  {isPending
                    ? [0, 1, 2, 3, 4, 5].map((i) => (
                        <li key={i} className="px-6 py-3">
                          <Skeleton className="h-5 w-full" />
                        </li>
                      ))
                    : ranked.map((s) => (
                        <li key={s.storeId}>
                          <button
                            className={cn(
                              'flex w-full items-center gap-3 px-6 py-2.5 text-left text-sm transition-colors hover:bg-accent',
                              hoverId === s.storeId && 'bg-accent',
                            )}
                            onMouseEnter={() => setHoverId(s.storeId)}
                            onMouseLeave={() => setHoverId(null)}
                            onClick={() => selectStore(s.storeId)}
                          >
                            <span
                              className="shrink-0 rounded-full"
                              style={{
                                width: Math.min(18, radius(s.gap) * 0.7),
                                height: Math.min(18, radius(s.gap) * 0.7),
                                background: s.gap < 0 ? 'var(--move-in)' : 'var(--move-out)',
                              }}
                            />
                            <span className="min-w-0 flex-1 truncate">{short(s.storeName)}</span>
                            <span className="text-xs text-muted-foreground">{s.state}</span>
                            <span
                              className={cn(
                                'w-16 text-right font-semibold tabular-nums',
                                s.gap < 0 ? 'text-move-in' : 'text-move-out',
                              )}
                            >
                              {signed(s.gap)}
                            </span>
                          </button>
                        </li>
                      ))}
                </ul>
              </CardContent>
            </>
          )}
        </Card>
      </div>

      {/* Santa's sleigh transfer plan */}
      <Card className="overflow-hidden">
        <CardHeader className="flex-row flex-wrap items-center justify-between gap-3 space-y-0">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-gold" />
              Santa&apos;s sleigh transfer plan
            </CardTitle>
            <CardDescription>
              Each short store pulls tents from its nearest stores with spare, biggest shortfall first.
              Click a route to light it up.
            </CardDescription>
          </div>
          {!isPending && (
            <div className="flex gap-6 text-sm">
              <Stat label="Routes" value={fmt(shownTransfers.length)} />
              <Stat label="Tents moved" value={fmt(movedShown)} />
              <Stat
                label="Avg km / tent"
                value={movedShown ? fmt(Math.round(kmShown / movedShown)) : '—'}
              />
            </div>
          )}
        </CardHeader>
        <CardContent className="p-0">
          {isPending ? (
            <div className="space-y-2 px-6 pb-6">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : shownTransfers.length === 0 ? (
            <div className="px-6 pb-6">
              <EmptyState
                icon={Gift}
                title="No transfers for this selection"
                description="Stores in these states have no spare to give or need to fill."
              />
            </div>
          ) : (
            <ul className="grid max-h-[360px] gap-px overflow-y-auto bg-border sm:grid-cols-2 xl:grid-cols-3">
              {shownTransfers.map(({ t, i, from, to }) => (
                <li key={i} className="bg-card">
                  <button
                    className={cn(
                      'flex w-full items-center gap-2 px-5 py-3 text-left text-sm transition-colors hover:bg-gold/10',
                      activeTransfer === i && 'bg-gold/15',
                    )}
                    onClick={() => {
                      setSelectedId(null);
                      setActiveTransfer(activeTransfer === i ? null : i);
                      setShowRoutes(true);
                    }}
                  >
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-1.5 truncate">
                        <span className="truncate text-move-out">{short(from.storeName)}</span>
                        <ArrowRight className="h-3.5 w-3.5 shrink-0 text-gold" />
                        <span className="truncate text-move-in">{short(to.storeName)}</span>
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {from.state} → {to.state} · {fmt(t.km)} km
                      </span>
                    </span>
                    <span className="rounded-full bg-gold/20 px-2.5 py-0.5 text-xs font-semibold tabular-nums">
                      {fmt(t.tents)}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        'inline-flex h-8 items-center gap-2 rounded-full border px-3 text-sm font-medium transition-all',
        active
          ? 'border-transparent bg-primary text-primary-foreground shadow'
          : 'bg-card hover:border-primary/50 hover:bg-accent',
      )}
    >
      {children}
    </button>
  );
}

function Legend({ color, label, line }: { color: string; label: string; line?: boolean }) {
  return (
    <span className="flex items-center gap-1.5 text-muted-foreground">
      <span
        className={line ? 'h-0.5 w-4 rounded' : 'h-2.5 w-2.5 rounded-full'}
        style={{ background: color }}
      />
      <span className="hidden sm:inline">{label}</span>
    </span>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="text-right">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="font-semibold tabular-nums">{value}</p>
    </div>
  );
}

function StoreDetail({
  store,
  reorder,
  transfers,
  byId,
  onClose,
  onPick,
}: {
  store: Store;
  reorder: number;
  transfers: PlanResponse['transfers'];
  byId: Map<string, Store>;
  onClose: () => void;
  onPick: (id: string) => void;
}) {
  const inbound = transfers.filter((t) => t.toId === store.storeId);
  const outbound = transfers.filter((t) => t.fromId === store.storeId);
  const isIn = store.action === 'MOVE IN';
  const rows = [
    ['Tents on hand', store.tentsOnHand],
    ['B26-07 to send back', -store.b2607ToReturn],
    ['Good tents', store.goodTents],
    ['Forecast to 24 Dec', store.forecast],
  ] as const;

  return (
    <div className="flex h-full flex-col animate-in fade-in slide-in-from-right-2 duration-200 motion-reduce:animate-none">
      <CardHeader className="flex-row items-start justify-between space-y-0 pb-3">
        <div className="min-w-0">
          <CardTitle className="truncate">{short(store.storeName)}</CardTitle>
          <CardDescription>
            {store.state} · {store.storeId}
          </CardDescription>
        </div>
        <Button size="icon" variant="ghost" onClick={onClose} aria-label="Close store detail">
          <X className="h-4 w-4" />
        </Button>
      </CardHeader>
      <CardContent className="space-y-5 overflow-y-auto">
        <div
          className={cn(
            'rounded-xl p-4',
            isIn ? 'bg-move-in/10 text-move-in' : 'bg-move-out/10 text-move-out',
          )}
        >
          <p className="text-xs font-semibold uppercase tracking-wider">{store.action}</p>
          <p className="mt-1 text-3xl font-bold tabular-nums">{signed(store.gap)}</p>
          <p className="text-xs opacity-80">{isIn ? 'tents short of forecast' : 'tents spare after forecast'}</p>
        </div>

        <dl className="grid grid-cols-2 gap-y-2 text-sm tabular-nums">
          {rows.map(([k, v]) => (
            <div key={k} className="contents">
              <dt className="text-muted-foreground">{k}</dt>
              <dd className="text-right font-medium">{fmt(v)}</dd>
            </div>
          ))}
        </dl>

        {(inbound.length > 0 || outbound.length > 0) && (
          <div className="space-y-2">
            <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              {isIn ? 'Arriving by sleigh' : 'Sending by sleigh'}
            </p>
            {(isIn ? inbound : outbound).map((t) => {
              const other = byId.get(isIn ? t.fromId : t.toId)!;
              return (
                <button
                  key={`${t.fromId}-${t.toId}`}
                  onClick={() => onPick(other.storeId)}
                  className="flex w-full items-center justify-between rounded-lg border px-3 py-2 text-sm transition-colors hover:bg-gold/10"
                >
                  <span className="min-w-0 truncate">
                    {isIn ? 'from ' : 'to '}
                    {short(other.storeName)}{' '}
                    <span className="text-xs text-muted-foreground">
                      {other.state} · {fmt(t.km)} km
                    </span>
                  </span>
                  <span className="font-semibold tabular-nums">{fmt(t.tents)}</span>
                </button>
              );
            })}
          </div>
        )}

        {isIn && (
          <p className="rounded-lg border border-dashed px-3 py-2 text-sm">
            Still to reorder after transfers:{' '}
            <span className="font-semibold tabular-nums text-move-in">{fmt(reorder)}</span>
          </p>
        )}
      </CardContent>
    </div>
  );
}
