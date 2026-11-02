// Simplified Australian coastline as [lon, lat] rings, plus a projection into
// the map's SVG viewBox. Self-contained so the app needs no map tiles or
// network access. Accurate to roughly 50 km — good enough to place stores.

export const MAINLAND: [number, number][] = [
  [142.5, -10.7], [143.6, -14.0], [145.3, -15.0], [145.5, -16.9], [146.3, -18.9],
  [148.8, -20.4], [149.6, -22.3], [150.8, -22.6], [151.3, -24.0], [153.1, -25.3],
  [153.2, -27.4], [153.6, -28.6], [153.0, -31.0], [152.5, -32.4], [151.3, -33.8],
  [150.8, -34.6], [150.0, -36.6], [149.9, -37.5], [148.2, -37.8], [146.4, -39.1],
  [145.0, -38.5], [144.4, -38.2], [143.5, -38.8], [141.6, -38.4], [140.6, -38.0],
  [139.8, -37.3], [139.6, -36.2], [138.4, -35.6], [138.5, -34.9], [138.0, -34.3],
  [137.8, -35.0], [137.0, -35.2], [137.5, -34.0], [137.8, -32.6], [136.6, -33.9],
  [135.9, -34.8], [135.2, -34.0], [134.2, -32.8], [132.5, -32.0], [131.0, -31.5],
  [129.0, -31.7], [126.0, -32.3], [124.0, -33.0], [123.6, -33.9], [121.9, -33.9],
  [119.0, -34.4], [117.9, -35.1], [116.0, -34.9], [115.0, -34.3], [115.6, -33.5],
  [115.7, -32.0], [115.0, -29.5], [114.6, -28.5], [114.0, -26.5], [113.6, -24.5],
  [113.8, -22.5], [114.6, -21.8], [116.7, -20.6], [118.8, -20.3], [121.0, -19.5],
  [122.2, -18.0], [123.6, -16.4], [125.0, -14.6], [126.9, -13.8], [128.2, -15.0],
  [129.6, -14.9], [130.2, -13.2], [130.8, -12.4], [132.6, -11.4], [134.4, -12.0],
  [136.0, -12.2], [136.9, -12.3], [136.0, -13.4], [135.9, -15.0], [137.6, -16.2],
  [139.3, -17.4], [140.8, -17.5], [141.5, -15.0], [141.6, -12.6],
];

export const TASMANIA: [number, number][] = [
  [144.7, -40.7], [146.6, -41.1], [148.3, -40.9], [148.3, -42.2], [147.9, -43.1],
  [147.0, -43.6], [146.0, -43.6], [145.2, -42.2], [144.7, -41.2],
];

/** Where each state's name is drawn on the map. */
export const STATE_LABELS: { state: string; lon: number; lat: number }[] = [
  { state: 'WA', lon: 121.5, lat: -25.5 },
  { state: 'NT', lon: 133.5, lat: -19.5 },
  { state: 'SA', lon: 134.8, lat: -29.0 },
  { state: 'QLD', lon: 144.5, lat: -22.0 },
  { state: 'NSW', lon: 146.2, lat: -31.8 },
  { state: 'VIC', lon: 143.6, lat: -36.9 },
  { state: 'TAS', lon: 146.5, lat: -42.1 },
];

const LON0 = 112;
const LAT0 = -9.5;
const SCALE = 26.5;
const COS = Math.cos((27 * Math.PI) / 180);

export const VIEW_W = Math.round((155 - LON0) * COS * SCALE);
export const VIEW_H = Math.round((45 + LAT0) * SCALE);

/** Equirectangular projection centred on Australia, into viewBox units. */
export function project(lon: number, lat: number): [number, number] {
  return [(lon - LON0) * COS * SCALE, (LAT0 - lat) * SCALE];
}

export function ringPath(ring: [number, number][]): string {
  return (
    ring
      .map(([lon, lat], i) => {
        const [x, y] = project(lon, lat);
        return `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join('') + 'Z'
  );
}
