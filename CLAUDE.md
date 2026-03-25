# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

KDE Plasma 6 widget (plasmoid) that displays Bitcoin price as a line chart. Pure QML/JavaScript — no build system, no compiled code. Single source file at `plasmoid/contents/ui/main.qml`.

Plugin ID: `com.cssodessa.btcplasmoid`

## Commands

```bash
# Install / update / uninstall
kpackagetool6 --type Plasma/Applet -i plasmoid
kpackagetool6 --type Plasma/Applet -u plasmoid
kpackagetool6 --type Plasma/Applet -r com.cssodessa.btcplasmoid

# Preview without installing to desktop
plasmoidviewer -a plasmoid

# Restart Plasma shell (picks up changes after -u)
kquitapp6 plasmashell && kstart plasmashell

# Package for distribution
zip -r btc-price.plasmoid plasmoid
```

There are no tests, linters, or CI pipelines.

## Architecture

Everything lives in `plasmoid/contents/ui/main.qml` (~420 lines). The widget is a `PlasmoidItem` containing:

- **Data layer** — `samples` array (max 288 entries = 24h at 5-min intervals), min/max tracking, failure state.
- **fetchPrice()** — Polls Coinbase spot price API every `sampleInterval` (5 min) via XMLHttpRequest. On success, pushes to `samples` and repaints the chart.
- **fetchHistory()** — Loads 24h of historical data from Coinbase on startup, interpolated to the sample interval grid via `interpolateHistorySeries()`.
- **Failure recovery** — If spot price fails for 30+ minutes, triggers a full history reload to fill gaps.
- **Canvas chart** — `onPaint` handler draws a normalized line chart with horizontal grid lines. Repaints on sample changes.

Data flow: `Component.onCompleted` → `fetchHistory()` + `fetchPrice()` → Timer repeats `fetchPrice()` → `pushSample()` → `updateRange()` → `chartCanvas.requestPaint()`.

## API

Coinbase public API, no key required:
- Spot: `https://api.coinbase.com/v2/prices/spot?currency=USD`
- History: `https://api.coinbase.com/v2/prices/BTC-USD/historic?period=day`

## QML/Qt Dependencies

Qt 6.5, KDE Frameworks 6.x: `org.kde.plasma.plasmoid 2.0`, `org.kde.kirigami`, `QtQuick.Controls`, `QtQuick.Layouts`.
