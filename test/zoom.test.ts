import { describe, it, expect } from 'vitest';
import { createDomain } from '../src/domain.js';
import { zoomAround, panBy } from '../src/zoom.js';

const base = createDomain({ priceLow: 208.12, priceHigh: 209.48, timeStart: 0, timeEnd: 8 * 3600_000, priceScale: 3 });

describe('zoom/pan invariants', () => {
  it('halves and doubles the span exactly', () => {
    const halved = zoomAround(base, 0.5, 2);
    const doubled = zoomAround(halved, 0.5, 0.5);
    expect(Number(doubled.priceHighMicro - doubled.priceLowMicro))
      .toBe(Number(base.priceHighMicro - base.priceLowMicro));
  });
  it('panBy shifts both edges equally', () => {
    const p = panBy(base, 10n, 60_000);
    expect(p.priceHighMicro - p.priceLowMicro).toBe(base.priceHighMicro - base.priceLowMicro);
  });
});
