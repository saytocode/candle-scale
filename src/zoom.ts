import type { Domain } from './domain.js';

/** Zoom keeping the domain value under one anchor fraction fixed. */
export function zoomAround(domain: Domain, anchorFraction: number, factor: number): Domain {
  const priceSpan = domain.priceHighMicro - domain.priceLowMicro;
  const timeSpan = domain.timeEnd - domain.timeStart;
  const step = BigInt(Math.max(1, Math.round(factor)));
  const newPriceSpan = priceSpan / step;
  const newTimeSpan = Math.max(1, Math.round(timeSpan / factor));
  const pAnchor = domain.priceLowMicro + BigInt(Math.round(Number(priceSpan) * anchorFraction));
  const tAnchor = domain.timeStart + Math.round(timeSpan * anchorFraction);
  const pLow = pAnchor - BigInt(Math.round(Number(newPriceSpan) * anchorFraction));
  const tStart = tAnchor - Math.round(newTimeSpan * anchorFraction);
  return { ...domain, priceLowMicro: pLow, priceHighMicro: pLow + newPriceSpan, timeStart: tStart, timeEnd: tStart + newTimeSpan };
}

export function panBy(domain: Domain, priceMicro: bigint, timeMs: number): Domain {
  return { ...domain, priceLowMicro: domain.priceLowMicro + priceMicro, priceHighMicro: domain.priceHighMicro + priceMicro, timeStart: domain.timeStart + timeMs, timeEnd: domain.timeEnd + timeMs };
}
