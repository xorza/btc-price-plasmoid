# BTC Price Plasmoid

This repository hosts an experimental KDE Plasma 6.5 plasmoid that will display the Bitcoin price as a compact line chart, similar to the Plasma System Monitor widgets. The current state contains a minimal package skeleton based on the Qt 6.5 stack so you can explore, build, and iterate on the user interface before wiring it up to a live data source.

## Repository layout

- `plasmoid/metadata.json` – Plugin metadata consumed by Plasma Shell and `kpackagetool6`.
- `plasmoid/contents/ui/main.qml` – QML entry point; today it just renders a placeholder chart area and status text.

## Getting started

1. Install the Plasma 6 SDK components if they are not already available (for example `plasma-sdk`, `kpackagetool6`, and `kirigami` from KDE 6.5 repos).
2. From the repository root, install the plasmoid locally:
   ```sh
   kpackagetool6 --type Plasma/Applet -i plasmoid
   ```
3. Add the widget to your Plasma desktop or panel and verify that the placeholder view loads.

## Next steps

- Hook the QML chart up to a data source (for instance, a background service fetching the BTC price every minute).
- Persist historic samples and feed them into a QtQuick chart component (or Plasma's system monitor datasource) to mimic the System Monitor line chart.
- Add configuration UI for the update frequency, currency pairs, and colors.
