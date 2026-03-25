# BTC Price Plasmoid

A KDE Plasma 6 widget that displays the Bitcoin price as a compact line chart with 24 hours of history. Built with Qt 6.5 and QML, it fetches live price data from the Coinbase public API.

## Repository layout

- `plasmoid/metadata.json` – Plugin metadata consumed by Plasma Shell and `kpackagetool6`.
- `plasmoid/contents/ui/main.qml` – QML entry point that draws the card UI, polls the BTC/USD price, and plots samples on a line chart.

## Getting started

1. Install the Plasma 6 SDK components if they are not already available (for example `plasma-sdk`, `kpackagetool6`, and `kirigami` from KDE 6 repos).
2. Make sure your session can reach `https://api.coinbase.com` (no API key required).
3. From the repository root, install the plasmoid locally:
   ```sh
   kpackagetool6 --type Plasma/Applet -i plasmoid
   ```
4. Add the widget to your Plasma desktop or panel, or run `plasmoidviewer -a plasmoid` to preview it.
5. To update after making changes:
   ```sh
   kpackagetool6 --type Plasma/Applet -u plasmoid
   kquitapp6 plasmashell && kstart plasmashell
   ```
6. To uninstall:
   ```sh
   kpackagetool6 --type Plasma/Applet -r com.cssodessa.btcplasmoid
   ```

## Data source

The widget queries [Coinbase's spot price API](https://api.coinbase.com/v2/prices/spot?currency=USD) every 5 minutes via `XMLHttpRequest`. On startup, it also loads 24 hours of historical data from the Coinbase historic price endpoint and interpolates it to fill the chart.

Only the BTC/USD pair is enabled by default; you can change the `currency` and `currencySymbol` properties in `main.qml` to track a different fiat currency. Coinbase enforces rate limits, so adjust `sampleInterval` if you need to poll less aggressively.
