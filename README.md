# candle-scale
Dependency-free, fixed-point-safe coordinate and geometry math for candlestick chart renderers. Zoom anchors, DPR snapping, bar geometry.
# candle-scale

[![CI](https://github.com/saytocode/candle-scale/actions/workflows/ci.yml/badge.svg)](https://github.com/saytocode/candle-scale/actions/workflows/ci.yml)
[![npm version](https://img.shields.io/npm/v/candle-scale.svg)](https://www.npmjs.com/package/candle-scale)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.6-blue.svg)](https://www.typescriptlang.org/)

Small, dependency-free, fixed-point-safe scale math for candlestick and financial chart renderers.

`candle-scale` does one job: turn domain values (price, timestamp, quantity) into pixel
coordinates and back without the classic bugs that ruin hand-rolled chart code — float drift,
zoom anchor jumps, pan overshoot, off-by-one bar widths, and retina blur.

It is renderer-agnostic. Works with Canvas 2D, SVG, WebGL, or plain DOM. Ships zero styles.

---

## Why

Every chart library re-implements the same coordinate math, and most get it wrong:

- **Float drift** — `price / (max - min) * height` accumulates error across thousands of bars,
  so wicks land a half-pixel off and 4-decimal instruments render as shimmer.
- **Zoom anchor jumps** — naive zoom scales the whole range, so the point under the cursor
  slides away. Users notice instantly.
- **Pan overshoot** — clamping after scaling leaves dead zones at the edges.
- **Retina blur** — odd device-pixel-ratio scaling makes 1px rules become 2px smears.
- **Body/wick mismatch** — bar width computed independently from the wick produces gaps.

`candle-scale` centralises this in one tested place: an immutable domain, an immutable
viewport, and pure functions between them.

## Install

```bash
npm install candle-scale
