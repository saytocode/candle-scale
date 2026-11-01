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
