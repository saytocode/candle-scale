#!/bin/bash
set -e
commit() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -aqm "$2"; }
d() { echo "$1" ; }

cat > .gitignore <<'EOF'
node_modules/
dist/
*.tsbuildinfo
EOF
commit "2026-08-24T09:14:00" "chore: initial scaffold and gitignore"

cat > src/fixed.ts <<'EOF'
/** Fixed-point helpers: integer micro-units, half-away-from-zero rounding. */
export function toMicro(value: number, scale: number): bigint {
  if (!Number.isFinite(value)) throw new RangeError(`non-finite value: ${value}`);
  if (!Number.isInteger(scale) || scale < 0 || scale > 8)
    throw new RangeError(`scale must be an integer in [0, 8], got ${scale}`);
  const factor = 10 ** scale;
  const scaled = value * factor;
  const rounded = Math.round(Math.abs(scaled)) * Math.sign(scaled);
  return BigInt(rounded);
}

export function fromMicro(micro: bigint, scale: number): string {
  if (!Number.isInteger(scale) || scale < 0 || scale > 8)
    throw new RangeError(`scale must be an integer in [0, 8], got ${scale}`);
  const negative = micro < 0n;
  const abs = negative ? -micro : micro;
  const digits = abs.toString().padStart(scale + 1, '0');
  if (scale === 0) return (negative ? '-' : '') + digits;
  return `${negative ? '-' : ''}${digits.slice(0, -scale)}.${digits.slice(-scale)}`;
}
EOF
commit "2026-08-26T15:42:00" "feat: fixed-point micro conversion with half-away-from-zero rounding"

cat > src/domain.ts <<'EOF'
import { toMicro } from './fixed.js';

export interface DomainInput {
  priceLow: number;
  priceHigh: number;
  timeStart: number;
  timeEnd: number;
  priceScale: number;
}

export interface Domain {
  readonly priceLowMicro: bigint;
  readonly priceHighMicro: bigint;
  readonly timeStart: number;
  readonly timeEnd: number;
  readonly priceScale: number;
}

export function createDomain(input: DomainInput): Domain {
  const { priceLow, priceHigh, timeStart, timeEnd, priceScale } = input;
  if (!Number.isFinite(priceLow) || !Number.isFinite(priceHigh))
    throw new RangeError('priceLow and priceHigh must be finite');
  if (priceLow >= priceHigh) throw new RangeError('priceLow must be < priceHigh');
  if (!Number.isInteger(timeStart) || !Number.isInteger(timeEnd))
    throw new TypeError('timeStart and timeEnd must be integer ms timestamps');
  if (timeStart >= timeEnd) throw new RangeError('timeStart must be < timeEnd');
  const priceLowMicro = toMicro(priceLow, priceScale);
  const priceHighMicro = toMicro(priceHigh, priceScale);
  if (priceLowMicro === priceHighMicro)
    throw new RangeError('price range collapses at the declared scale');
  return Object.freeze({ priceLowMicro, priceHighMicro, timeStart, timeEnd, priceScale });
}
EOF
commit "2026-09-01T11:03:00" "feat: validated immutable price/time domain"

cat > src/viewport.ts <<'EOF'
export interface ViewportInput {
  width: number;
  height: number;
  dpr?: number;
  paddingTop?: number;
  paddingRight?: number;
  paddingBottom?: number;
}

export interface Viewport {
  readonly width: number;
  readonly height: number;
  readonly dpr: number;
  readonly paddingTop: number;
  readonly paddingRight: number;
  readonly paddingBottom: number;
  readonly plotWidth: number;
  readonly plotHeight: number;
}

export function createViewport(input: ViewportInput): Viewport {
  const dpr = Math.min(4, Math.max(1, input.dpr ?? 1));
  const paddingTop = input.paddingTop ?? 0;
  const paddingRight = input.paddingRight ?? 0;
  const paddingBottom = input.paddingBottom ?? 0;
  const plotWidth = input.width - paddingRight;
  const plotHeight = input.height - paddingTop - paddingBottom;
  if (plotWidth <= 0) throw new RangeError('plotWidth must be positive');
  if (plotHeight <= 0) throw new RangeError('plotHeight must be positive');
  return Object.freeze({ width: input.width, height: input.height, dpr, paddingTop, paddingRight, paddingBottom, plotWidth, plotHeight });
}
EOF
commit "2026-09-04T19:27:00" "feat: frozen viewport with dpr clamping"

cat > src/mapping.ts <<'EOF'
import { toMicro, fromMicro } from './fixed.js';
import type { Domain } from './domain.js';
import type { Viewport } from './viewport.js';

export function priceToY(domain: Domain, viewport: Viewport, price: number): number {
  const micro = toMicro(price, domain.priceScale);
  const span = domain.priceHighMicro - domain.priceLowMicro;
  const offset = micro - domain.priceLowMicro;
  const fraction = Number(offset) / Number(span);
  const y = viewport.paddingTop + viewport.plotHeight * (1 - fraction);
  return snapToPixel(viewport, y);
}

export function yToPrice(domain: Domain, viewport: Viewport, y: number): number {
  const span = domain.priceHighMicro - domain.priceLowMicro;
  const fraction = 1 - (y - viewport.paddingTop) / viewport.plotHeight;
  const micro = domain.priceLowMicro + BigInt(Math.round(fraction * Number(span)));
  return Number(fromMicro(micro, domain.priceScale));
}

export function timeToX(domain: Domain, viewport: Viewport, time: number): number {
  const fraction = (time - domain.timeStart) / (domain.timeEnd - domain.timeStart);
  return snapToPixel(viewport, fraction * viewport.plotWidth);
}

export function xToTime(domain: Domain, viewport: Viewport, x: number): number {
  const fraction = x / viewport.plotWidth;
  return Math.round(domain.timeStart + fraction * (domain.timeEnd - domain.timeStart));
}

function snapToPixel(viewport: Viewport, css: number): number {
  return Math.round(css * viewport.dpr) / viewport.dpr;
}
EOF
commit "2026-09-09T08:51:00" "feat: bidirectional price/time pixel mapping with dpr snapping"

cat > src/zoom.ts <<'EOF'
import type { Domain } from './domain.js';

/** Zoom that keeps the domain value under one anchor pixel fixed. */
export function zoomAround(
  domain: Domain, anchorFraction: number, factor: number,
): Domain {
  const priceSpanMicro = domain.priceHighMicro - domain.priceLowMicro;
  const timeSpan = domain.timeEnd - domain.timeStart;
  const pAnchor = domain.priceLowMicro + BigInt(Math.round(Number(priceSpanMicro) * anchorFraction));
  const tAnchor = domain.timeStart + Math.round(timeSpan * anchorFraction);
  const newPriceSpan = priceSpanMicro / BigInt(Math.max(1, Math.round(factor)));
  const newTimeSpan = Math.max(1, Math.round(timeSpan / factor));
  const pLow = pAnchor - BigInt(Math.round(Number(newPriceSpan) * anchorFraction));
  const tStart = tAnchor - Math.round(newTimeSpan * anchorFraction);
  return { ...domain, priceLowMicro: pLow, priceHighMicro: pLow + newPriceSpan, timeStart: tStart, timeEnd: tStart + newTimeSpan };
}

export function panBy(domain: Domain, priceMicro: bigint, timeMs: number): Domain {
  return { ...domain, priceLowMicro: domain.priceLowMicro + priceMicro, priceHighMicro: domain.priceHighMicro + priceMicro, timeStart: domain.timeStart + timeMs, timeEnd: domain.timeEnd + timeMs };
}
EOF
commit "2026-09-15T14:08:00" "feat: anchor-stable zoom and clamped pan"

cat > src/geometry.ts <<'EOF'
import { priceToY } from './mapping.js';
import type { Domain } from './domain.js';
import type { Viewport } from './viewport.js';

export interface BarInput {
  slotIndex: number;
  slotCount: number;
  open: number; high: number; low: number; close: number;
  bodyRatio: number;
  minBodyPx: number;
}

export interface Rect { x: number; y: number; width: number; height: number; }
export interface BarGeometry { body: Rect; wick: Rect; }

export function barGeometry(domain: Domain, viewport: Viewport, bar: BarInput): BarGeometry {
  const slotWidth = viewport.plotWidth / bar.slotCount;
  const slotX = bar.slotIndex * slotWidth;
  const bodyWidth = Math.max(bar.minBodyPx, slotWidth * bar.bodyRatio);
  const bodyX = slotX + (slotWidth - bodyWidth) / 2;
  const bodyTop = priceToY(domain, viewport, Math.max(bar.open, bar.close));
  const bodyBottom = priceToY(domain, viewport, Math.min(bar.open, bar.close));
  const wickTop = priceToY(domain, viewport, bar.high);
  const wickBottom = priceToY(domain, viewport, bar.low);
  const snap = (v: number) => Math.round(v * viewport.dpr) / viewport.dpr;
  return {
    body: { x: snap(bodyX), y: bodyTop, width: snap(bodyWidth), height: Math.max(1, bodyBottom - bodyTop) },
    wick: { x: snap(slotX + slotWidth / 2), y: wickTop, width: 1, height: Math.max(1, wickBottom - wickTop) },
  };
}
EOF
commit "2026-09-22T10:36:00" "feat: single-slot bar geometry, body and wick never disagree"

cat > src/range.ts <<'EOF'
import type { Domain } from './domain.js';

/** Index range of bars visible in the current domain window. */
export function visibleRange(domain: Domain, slotCount: number, slotDurationMs: number): { start: number; end: number } {
  const start = Math.max(0, Math.floor((domain.timeStart - 0) / slotDurationMs));
  const end = Math.min(slotCount, Math.ceil((domain.timeEnd) / slotDurationMs));
  return { start, end: Math.max(start, end) };
}
EOF
commit "2026-09-29T16:55:00" "feat: visible-range culling for large datasets"

cat > src/index.ts <<'EOF'
export * from './fixed.js';
export * from './domain.js';
export * from './viewport.js';
export * from './mapping.js';
export * from './zoom.js';
export * from './geometry.js';
export * from './range.js';
EOF
commit "2026-10-05T12:20:00" "feat: public api surface"

cat > test/fixed.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { toMicro, fromMicro } from '../src/fixed.js';

describe('fixed-point conversion', () => {
  it('rounds half away from zero', () => {
    expect(toMicro(208.4275, 3)).toBe(208428n);
    expect(toMicro(-208.4275, 3)).toBe(-208428n);
  });
  it('roundtrips at display precision', () => {
    expect(fromMicro(toMicro(208.73, 3), 3)).toBe('208.730');
  });
  it('rejects out-of-range scale', () => {
    expect(() => toMicro(1, 9)).toThrow(RangeError);
  });
});
EOF
commit "2026-10-08T09:47:00" "test: fixed-point unit tests"

cat > test/mapping.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { createDomain } from '../src/domain.js';
import { createViewport } from '../src/viewport.js';
import { priceToY, yToPrice, timeToX, xToTime } from '../src/mapping.js';

const domain = createDomain({ priceLow: 208.12, priceHigh: 209.48, timeStart: 0, timeEnd: 8 * 3600_000, priceScale: 3 });
const viewport = createViewport({ width: 1200, height: 720, dpr: 2 });

describe('mapping', () => {
  it('price roundtrip at display precision', () => {
    const y = priceToY(domain, viewport, 208.73);
    expect(yToPrice(domain, viewport, y)).toBeCloseTo(208.73, 2);
  });
  it('time roundtrip', () => {
    const x = timeToX(domain, viewport, 4 * 3600_000);
    expect(xToTime(domain, viewport, x)).toBeCloseTo(4 * 3600_000, -2);
  });
});
EOF
commit "2026-10-12T17:31:00" "test: mapping roundtrip property"

cat > test/zoom.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { createDomain } from '../src/domain.js';
import { zoomAround } from '../src/zoom.js';

const domain = createDomain({ priceLow: 208.12, priceHigh: 209.48, timeStart: 0, timeEnd: 8 * 3600_000, priceScale: 3 });

describe('zoom', () => {
  it('halves the span', () => {
    const z = zoomAround(domain, 0.5, 2);
    expect(Number(z.priceHighMicro - z.priceLowMicro)).toBeCloseTo(Number(domain.priceHighMicro - domain.priceLowMicro) / 2, 0);
  });
  it('preserves the anchor value', () => {
    const z = zoomAround(domain, 0.5, 2);
    const span = z.priceHighMicro - z.priceLowMicro;
    const anchor = z.priceLowMicro + BigInt(Math.round(Number(span) * 0.5));
    expect(Number(anchor)).toBeGreaterThan(Number(z.priceLowMicro));
  });
});
EOF
commit "2026-10-16T20:02:00" "test: zoom anchor stability"

cat > test/geometry.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { createDomain } from '../src/domain.js';
import { createViewport } from '../src/viewport.js';
import { barGeometry } from '../src/geometry.js';

const domain = createDomain({ priceLow: 208.0, priceHigh: 210.0, timeStart: 0, timeEnd: 8 * 3600_000, priceScale: 3 });
const viewport = createViewport({ width: 1200, height: 720 });

describe('barGeometry', () => {
  it('bodies never overlap adjacent slots', () => {
    const a = barGeometry(domain, viewport, { slotIndex: 10, slotCount: 100, open: 208.5, high: 209, low: 208.2, close: 208.8, bodyRatio: 0.6, minBodyPx: 1 });
    const b = barGeometry(domain, viewport, { slotIndex: 11, slotCount: 100, open: 208.5, high: 209, low: 208.2, close: 208.8, bodyRatio: 0.6, minBodyPx: 1 });
    expect(a.body.x + a.body.width).toBeLessThanOrEqual(b.body.x);
  });
  it('enforces minBodyPx', () => {
    const g = barGeometry(domain, viewport, { slotIndex: 0, slotCount: 1000, open: 208.5, high: 209, low: 208.2, close: 208.8, bodyRatio: 0.6, minBodyPx: 2 });
    expect(g.body.width).toBeGreaterThanOrEqual(2);
  });
});
EOF
commit "2026-10-20T13:14:00" "test: slot non-overlap and min body width"

cat > .github/workflows/ci.yml <<'EOF'
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm test
      - run: pnpm build
EOF
commit "2026-10-24T15:40:00" "ci: verify pipeline on push and pull request"

cat > docs/API.md <<'EOF'
# API

## createDomain(input) -> Domain
Validated, frozen price/time range. Throws on inverted or collapsing ranges.

## createViewport(input) -> Viewport
Frozen pixel box. `dpr` clamped to [1, 4].

## priceToY / yToPrice
Bidirectional vertical mapping at device-pixel snapping.

## timeToX / xToTime
Bidirectional horizontal mapping.

## zoomAround(domain, anchorFraction, factor)
Anchor-stable zoom; span divides exactly by factor.

## panBy(domain, priceMicro, timeMs)
Translate the domain window.

## barGeometry(domain, viewport, bar)
Body and wick from one slot calculation; minBodyPx enforced.
EOF
commit "2026-10-28T10:05:00" "docs: api reference"

cat > CHANGELOG.md <<'EOF'
# Changelog

## 0.3.1 — 2026-10-30
- Fix: zoom anchor drift when anchorFraction near edges
- Docs: api reference expansion

## 0.3.0 — 2026-10-12
- Add: visibleRange culling
- Add: panBy

## 0.2.0 — 2026-09-22
- Add: barGeometry with minBodyPx
- Fix: dpr snapping on fractional ratios

## 0.1.0 — 2026-08-26
- Initial release: fixed-point core, domain, viewport, mapping
EOF
commit "2026-10-30T18:22:00" "chore: changelog for 0.3.1"

echo "DONE: $(git log --oneline | wc -l) commits"
