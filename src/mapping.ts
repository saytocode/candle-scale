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
