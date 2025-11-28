# BTC Price Plasmoid

This repository hosts an experimental KDE Plasma 6.5 plasmoid that displays the Bitcoin price as a compact line chart, inspired by the Plasma System Monitor widgets. The current state uses Qt 6.5 and fetches live price data from the Coindesk public API so you can iterate on the UI before adding more advanced data handling.

## Repository layout

- `plasmoid/metadata.json` – Plugin metadata consumed by Plasma Shell and `kpackagetool6`.
- `plasmoid/contents/ui/main.qml` – QML entry point that draws the card UI, polls the BTC/USD price from the Coindesk API, and plots samples on a small line chart.

## Getting started

1. Install the Plasma 6 SDK components if they are not already available (for example `plasma-sdk`, `kpackagetool6`, and `kirigami` from KDE 6.5 repos).
2. Make sure your session can reach `https://api.coindesk.com` (no API key required).
3. From the repository root, install the plasmoid locally:
   ```sh
   kpackagetool6 --type Plasma/Applet -i plasmoid
   ```
4. Add the widget to your Plasma desktop or panel, or run `plasmoidviewer -a plasmoid` to preview it.
5. Watch the chart update every ~30 seconds as new BTC/USD samples arrive.
6. To uninstall, run `kpackagetool6 --type Plasma/Applet -r org.example.btcplasmoid`.

## Data source

The widget queries [Coindesk's public price index API](https://api.coindesk.com/v1/bpi/currentprice/USD.json) on a 30‑second interval using a simple `XmlHttpRequest` from QML. Only the BTC/USD pair is enabled by default; you can change the `currency` and `currencySymbol` properties in `plasmoid/contents/ui/main.qml` (e.g., set `EUR`/`€`) to track a different fiat currency. Coindesk asks clients not to refresh more often than once per minute for production workloads, so consider increasing the `updateInterval` value if you want to be gentler on their infrastructure.

## Next steps

- Wire in a configuration module so users can select different exchanges, fiat currencies, sample depth, and polling intervals.
- Replace the custom canvas chart with Plasma's System Monitor datasource + charts for better consistency.
- Persist historic samples and handle offline states/caching so the graph survives plasma restarts.
- Harden the networking code (timeouts, exponential backoff, alternate APIs) for production use.
