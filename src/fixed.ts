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
