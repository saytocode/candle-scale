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
