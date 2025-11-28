# BTC Price Plasmoid

This repository hosts an experimental KDE Plasmoid that will display the Bitcoin price as a compact line chart, similar to the Plasma System Monitor widgets. The current state contains a minimal package skeleton so you can explore, build, and iterate on the user interface before wiring it up to a live data source.

## Repository layout

- `plasmoid/metadata.desktop` – Plugin metadata consumed by Plasma Shell and `plasmapkg2`.
- `plasmoid/contents/ui/main.qml` – QML entry point; today it just renders a placeholder chart area and status text.

## Getting started

1. Install the Plasma SDK components if they are not already available (for example `plasma-sdk`, `kdeclarative`, and `kirigami`).
2. From the repository root, install the plasmoid locally:
   ```sh
   plasmapkg2 --type plasmoid --install plasmoid
   ```
3. Run `kpackagetool6 --type Plasma/Applet -i plasmoid` instead if you are already on Plasma 6 tooling.
4. Add the widget to your Plasma desktop or panel and verify that the placeholder view loads.

## Next steps

- Hook the QML chart up to a data source (for instance, a background service fetching the BTC price every minute).
- Persist historic samples and feed them into a `PlasmaComponents3.ChartView` to mimic the System Monitor line chart.
- Add configuration UI for the update frequency, currency pairs, and colors.
