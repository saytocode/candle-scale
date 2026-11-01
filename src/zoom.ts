import type { Domain } from './domain.js';

/** Zoom keeping the domain value under one anchor fraction fixed. factor > 1 zooms in, < 1 zooms out. */
export function zoomAround(domain: Domain, anchorFraction: number, factor: number): Domain {
  if (!Number.isFinite(factor) || factor <= 0) throw new RangeError(`factor must be > 0, got ${factor}`);
  const priceSpan = domain.priceHighMicro - domain.priceLowMicro;
  const timeSpan = domain.timeEnd - domain.timeStart;
  const pAnchor = domain.priceLowMicro + BigInt(Math.round(Number(priceSpan) * anchorFraction));
  const tAnchor = domain.timeStart + Math.round(timeSpan * anchorFraction);
  // in: divide span by factor. out: multiply. Exact in bigint for the price axis.
  const newPriceSpan = factor >= 1
    ? priceSpan / BigInt(Math.round(factor))
    : priceSpan * BigInt(Math.round(1 / factor));
  const newTimeSpan = Math.max(1, Math.round(timeSpan / factor));
  const pLow = pAnchor - BigInt(Math.round(Number(newPriceSpan) * anchorFraction));
  const tStart = tAnchor - Math.round(newTimeSpan * anchorFraction);
  return { ...domain, priceLowMicro: pLow, priceHighMicro: pLow + newPriceSpan, timeStart: tStart, timeEnd: tStart + newTimeSpan };
}

export function panBy(domain: Domain, priceMicro: bigint, timeMs: number): Domain {
  return { ...domain, priceLowMicro: domain.priceLowMicro + priceMicro, priceHighMicro: domain.priceHighMicro + priceMicro, timeStart: domain.timeStart + timeMs, timeEnd: domain.timeEnd + timeMs };
}
