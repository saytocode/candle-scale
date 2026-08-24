/**
 * Fixed-point helpers. All authoritative price math happens in integer
 * micro-units (bigint) so floating-point drift cannot compound across
 * thousands of bars or zoom operations.
 */

/** Convert a decimal number to integer micro-units at the given scale (half away from zero). */
export function toMicro(value: number, scale: number): bigint {
  if (!Number.isFinite(value)) throw new RangeError(`non-finite value: ${value}`);
  if (!Number.isInteger(scale) || scale < 0 || scale > 8) {
    throw new RangeError(`scale must be an integer in [0, 8], got ${scale}`);
  }
  const factor = 10 ** scale;
  const scaled = value * factor;
  // Round half away from zero — the display convention for financial prices.
  const rounded = Math.round(Math.abs(scaled)) * Math.sign(scaled);
  return BigInt(rounded);
}

/** Convert integer micro-units back to a decimal string at the given scale. */
export function fromMicro(micro: bigint, scale: number): string {
  if (!Number.isInteger(scale) || scale < 0 || scale > 8) {
    throw new RangeError(`scale must be an integer in [0, 8], got ${scale}`);
  }
  const negative = micro < 0n;
  const abs = negative ? -micro : micro;
  const digits = abs.toString().padStart(scale + 1, '0');
  if (scale === 0) return (negative ? '-' : '') + digits;
  const head = digits.slice(0, -scale);
  const tail = digits.slice(-scale);
  return `${negative ? '-' : ''}${head}.${tail}`;
}

/** Multiply two micro-unit values, returning micro-units (exact). */
export function mulMicro(a: bigint, b: bigint, scale: number): bigint {
  return (a * b) / 10n ** BigInt(scale);
}

/** Linear interpolation between two micro values, exact at both endpoints. */
export function lerpMicro(a: bigint, b: bigint, t: number, scale: number): bigint {
  if (t <= 0) return a;
  if (t >= 1) return b;
  const factor = 10n ** BigInt(scale);
  const ts = BigInt(Math.round(t * Number(factor)));
  return a + ((b - a) * ts) / factor;
}

