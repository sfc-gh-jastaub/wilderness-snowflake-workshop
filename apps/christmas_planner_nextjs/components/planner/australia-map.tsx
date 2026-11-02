'use client';

import { MAINLAND, STATE_LABELS, TASMANIA, VIEW_H, VIEW_W, project, ringPath } from '@/lib/australia';
import type { Store, Transfer } from '@/lib/plan';
import { cn } from '@/lib/utils';
import { useMemo } from 'react';

const COAST = [ringPath(MAINLAND), ringPath(TASMANIA)];

export function radius(gap: number) {
  return 5 + Math.sqrt(Math.abs(gap)) * 1.15;
}

function arc(a: [number, number], b: [number, number]) {
  const [x1, y1] = a;
  const [x2, y2] = b;
  const mx = (x1 + x2) / 2;
  const my = (y1 + y2) / 2;
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len = Math.hypot(dx, dy) || 1;
  const bend = Math.min(120, len * 0.25);
  // Bend "up" (north) so arcs read like a sleigh flight path.
  const cx = mx + (dy / len) * bend;
  const cy = my - Math.abs(dx / len) * bend - bend * 0.3;
  return `M${x1},${y1} Q${cx},${cy} ${x2},${y2}`;
}

export function AustraliaMap({
  stores,
  transfers,
  visible,
  hoverId,
  selectedId,
  activeTransfer,
  showRoutes,
  onHover,
  onSelect,
}: {
  stores: Store[];
  transfers: Transfer[];
  visible: (s: Store) => boolean;
  hoverId: string | null;
  selectedId: string | null;
  activeTransfer: number | null;
  showRoutes: boolean;
  onHover: (id: string | null) => void;
  onSelect: (id: string | null) => void;
}) {
  const byId = useMemo(() => new Map(stores.map((s) => [s.storeId, s])), [stores]);
  const pts = useMemo(
    () => new Map(stores.map((s) => [s.storeId, project(s.lon, s.lat)] as const)),
    [stores],
  );
  const focusId = hoverId ?? selectedId;
  const hover = hoverId ? byId.get(hoverId) : undefined;
  const maxTents = Math.max(1, ...transfers.map((t) => t.tents));

  // Biggest bubbles first so small ones stay clickable on top.
  const ordered = useMemo(
    () => [...stores].sort((a, b) => Math.abs(b.gap) - Math.abs(a.gap)),
    [stores],
  );

  return (
    <div className="relative w-full" style={{ aspectRatio: `${VIEW_W} / ${VIEW_H}` }}>
      <svg
        viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}
        className="absolute inset-0 h-full w-full select-none"
        role="img"
        aria-label="Map of Australia with each store coloured by action"
        onClick={() => onSelect(null)}
      >
        <defs>
          <radialGradient id="sea" cx="50%" cy="45%" r="70%">
            <stop offset="0%" stopColor="var(--map-sea-1)" />
            <stop offset="100%" stopColor="var(--map-sea-2)" />
          </radialGradient>
          <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="4" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        <rect width={VIEW_W} height={VIEW_H} fill="url(#sea)" rx="18" />

        {COAST.map((d, i) => (
          <path
            key={i}
            d={d}
            fill="var(--map-land)"
            stroke="var(--map-coast)"
            strokeWidth={2}
            strokeLinejoin="round"
          />
        ))}

        {STATE_LABELS.map(({ state, lon, lat }) => {
          const [x, y] = project(lon, lat);
          return (
            <text
              key={state}
              x={x}
              y={y}
              textAnchor="middle"
              className="fill-[var(--map-label)] text-[26px] font-semibold tracking-[0.2em]"
            >
              {state}
            </text>
          );
        })}

        {/* Sleigh routes */}
        {showRoutes &&
          transfers.map((t, i) => {
            const a = pts.get(t.fromId);
            const b = pts.get(t.toId);
            const from = byId.get(t.fromId);
            const to = byId.get(t.toId);
            if (!a || !b || !from || !to) return null;
            const inView = visible(from) || visible(to);
            const touchesFocus = focusId === t.fromId || focusId === t.toId;
            const active = activeTransfer === i || touchesFocus;
            const dim = (activeTransfer !== null || focusId) && !active;
            return (
              <path
                key={`${t.fromId}-${t.toId}`}
                d={arc(a, b)}
                fill="none"
                stroke="var(--gold)"
                strokeWidth={1.5 + (t.tents / maxTents) * 5}
                strokeLinecap="round"
                className={cn('sleigh-route transition-opacity duration-300', active && 'sleigh-route-active')}
                opacity={!inView ? 0.06 : dim ? 0.12 : active ? 1 : 0.7}
                filter={active ? 'url(#glow)' : undefined}
              />
            );
          })}

        {/* Stores */}
        {ordered.map((s) => {
          const [x, y] = pts.get(s.storeId)!;
          const r = radius(s.gap);
          const inView = visible(s);
          const focused = focusId === s.storeId;
          const color =
            s.action === 'MOVE IN'
              ? 'var(--move-in)'
              : s.action === 'MOVE OUT'
                ? 'var(--move-out)'
                : 'var(--muted-foreground)';
          return (
            <g
              key={s.storeId}
              className="cursor-pointer"
              opacity={inView ? 1 : 0.12}
              onMouseEnter={() => onHover(s.storeId)}
              onMouseLeave={() => onHover(null)}
              onClick={(e) => {
                e.stopPropagation();
                onSelect(s.storeId);
              }}
            >
              {focused && (
                <circle cx={x} cy={y} r={r + 6} fill="none" stroke={color} strokeWidth={3} className="pulse-ring" />
              )}
              <circle
                cx={x}
                cy={y}
                r={r}
                fill={color}
                fillOpacity={0.78}
                stroke="var(--map-dot-stroke)"
                strokeWidth={focused ? 3 : 1.5}
                className="transition-all duration-200"
              />
            </g>
          );
        })}
      </svg>

      {hover && (
        <div
          className="pointer-events-none absolute z-10 w-56 -translate-x-1/2 -translate-y-[calc(100%+14px)] rounded-lg border bg-popover/95 p-3 text-xs shadow-xl backdrop-blur animate-in fade-in zoom-in-95 duration-150"
          style={{
            left: `${(pts.get(hover.storeId)![0] / VIEW_W) * 100}%`,
            top: `${(pts.get(hover.storeId)![1] / VIEW_H) * 100}%`,
          }}
        >
          <div className="flex items-center justify-between gap-2">
            <span className="truncate font-semibold">{hover.storeName.replace(/^Wilderness /, '')}</span>
            <span className="text-muted-foreground">{hover.state}</span>
          </div>
          <div className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1 tabular-nums">
            <span className="text-muted-foreground">Good tents</span>
            <span className="text-right">{hover.goodTents.toLocaleString('en-AU')}</span>
            <span className="text-muted-foreground">Forecast</span>
            <span className="text-right">{hover.forecast.toLocaleString('en-AU')}</span>
            <span className="text-muted-foreground">Gap</span>
            <span
              className={cn('text-right font-semibold', hover.gap < 0 ? 'text-move-in' : 'text-move-out')}
            >
              {hover.gap > 0 ? '+' : ''}
              {hover.gap.toLocaleString('en-AU')}
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
