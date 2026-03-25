pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Kirigami.Units.gridUnit * 16

    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10

    // Data + API setup
    property string currency: "USD"
    property string currencySymbol: "$"
    property string apiUrl: "https://api.coinbase.com/v2/prices/spot?currency=" + currency
    property string historyUrl: "https://api.coinbase.com/v2/prices/BTC-" + currency + "/historic?period=day"
    property int sampleInterval: 300000 // ms (5 minutes)
    property int maxSamples: 24 * 60 * 60 * 1000 / sampleInterval
    property var samples: []
    property real minSample: 0
    property real maxSample: 0
    property real currentValue: 0
    property string lastUpdated: ""
    property bool loading: true
    property real failureStartTime: 0
    property bool historyRecoveryNeeded: false
    property int failureRecoveryInterval: 30 * 60 * 1000 // ms
    property bool historyFetchInProgress: false

    // Visual constants
    property color accentColor: Kirigami.Theme.highlightColor
    property color textColor: Kirigami.Theme.textColor
    property color gridLineColor: Kirigami.ColorUtils.linearInterpolation(
        Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
    property var gridStops: [0.9, 0.7, 0.5, 0.3, 0.1]
    property int historyRetryCount: 0
    property int maxHistoryRetries: 3

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    Timer {
        id: fetchTimer
        interval: sampleInterval
        repeat: true
        running: false
        onTriggered: fetchPrice()
    }

    Timer {
        id: historyRetryTimer
        interval: 10000
        repeat: false
        onTriggered: fetchHistory()
    }

    Component.onCompleted: {
        fetchHistory();
        fetchPrice();
        fetchTimer.start();
    }

    function fetchHistory(): void {
        historyFetchInProgress = true;
        let xhr = new XMLHttpRequest();
        xhr.open("GET", historyUrl);
        xhr.onerror = function (event) {
            console.error("BTC history network error", event && event.type ? event.type : event);
            historyFetchInProgress = false;
            retryHistoryFetch();
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            historyFetchInProgress = false;
            if (xhr.status === 200) {
                try {
                    let data = JSON.parse(xhr.responseText);
                    let prices = data && data.data && data.data.prices;
                    if (!prices || !prices.length) {
                        console.warn("BTC history payload empty", xhr.responseText);
                        return;
                    }
                    hydrateSamplesFromHistory(prices);
                } catch (e) {
                    console.warn("BTC history parse error", e);
                }
            } else {
                console.error("BTC history request failed", xhr.status, xhr.responseText);
                retryHistoryFetch();
            }
        };
        xhr.send();
    }

    function retryHistoryFetch(): void {
        if (historyRecoveryNeeded)
            return;
        if (historyRetryCount < maxHistoryRetries) {
            historyRetryCount++;
            historyRetryTimer.start();
        }
    }

    function fetchPrice(): void {
        let xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl);
        xhr.onerror = function (event) {
            handleSpotFailure("BTC API network error", event && event.type ? event.type : event);
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    let data = JSON.parse(xhr.responseText);
                    let payload = data && data.data;
                    let amount = payload && payload.amount !== undefined ? parseFloat(payload.amount) : NaN;
                    if (isNaN(amount)) {
                        handleSpotFailure("BTC API payload missing amount", xhr.responseText);
                        return;
                    }
                    currentValue = amount;
                    lastUpdated = payload && payload.time ? payload.time : new Date().toISOString();
                    pushSample(amount);
                    loading = false;
                    registerSpotSuccess();
                } catch (e) {
                    handleSpotFailure("BTC API parse error", e);
                }
            } else {
                handleSpotFailure("BTC API request failed", xhr.status, xhr.responseText);
            }
        };
        xhr.send();
    }

    function handleSpotFailure(message: string, detail: string): void {
        console.error(message, detail);
        registerSpotFailure();
    }

    function registerSpotSuccess(): void {
        failureStartTime = 0;
        attemptHistoryRecovery();
    }

    function registerSpotFailure(): void {
        let now = Date.now();
        if (!failureStartTime) {
            failureStartTime = now;
        }
        if (!historyRecoveryNeeded && now - failureStartTime >= failureRecoveryInterval) {
            historyRecoveryNeeded = true;
            console.warn("BTC API failures exceeded 30 minutes, requesting full history");
        }
        attemptHistoryRecovery();
    }

    function attemptHistoryRecovery(): void {
        if (!historyRecoveryNeeded || historyFetchInProgress)
            return;
        fetchHistory();
    }

    function pushSample(price: real): void {
        let nextSamples = samples.slice(Math.max(0, samples.length - (maxSamples - 1)));
        nextSamples.push(price);
        samples = nextSamples;
        updateRange();
        chartCanvas.requestPaint();
    }

    function hydrateSamplesFromHistory(historyEntries: var): void {
        let parsed = [];
        for (let i = 0; i < historyEntries.length; ++i) {
            let entry = historyEntries[i] || {};
            let rawPrice = entry.price || entry.amount || entry.spot_price;
            let price = rawPrice ? parseFloat(rawPrice) : NaN;
            let timestamp = parseHistoryTimestamp(entry.time);
            if (!isNaN(price) && !isNaN(timestamp)) {
                parsed.push({
                    time: timestamp,
                    price: price
                });
            }
        }
        if (parsed.length < 2) {
            console.warn("BTC history missing usable samples");
            return;
        }
        parsed.sort((a, b) => a.time - b.time);
        let interpolated = interpolateHistorySeries(parsed);

        if (!interpolated.length) {
            console.warn("BTC history interpolation failed");
            return;
        }
        historyRetryCount = 0;
        samples = interpolated;
        currentValue = interpolated[interpolated.length - 1];
        lastUpdated = new Date(parsed[parsed.length - 1].time).toISOString();
        updateRange();
        chartCanvas.requestPaint();
        loading = false;
        if (historyRecoveryNeeded) {
            historyRecoveryNeeded = false;
            failureStartTime = 0;
        }
    }

    function interpolateHistorySeries(points: var): list<real> {
        const desiredSamples = maxSamples;
        if (desiredSamples <= 0)
            return [];
        const interval = sampleInterval;
        const newestTime = points[points.length - 1].time;
        const oldestTime = newestTime - (desiredSamples - 1) * interval;
        const historyOldest = points[0].time;
        if (historyOldest > oldestTime) {
            console.warn("BTC history older gap", new Date(historyOldest).toISOString(), "target oldest", new Date(oldestTime).toISOString());
        }
        let result = new Array(desiredSamples);
        let segmentIndex = 0;
        for (let i = 0; i < desiredSamples; ++i) {
            let targetTime = oldestTime + i * interval;
            if (targetTime <= points[0].time) {
                result[i] = points[0].price;
                continue;
            }
            if (targetTime >= points[points.length - 1].time) {
                result[i] = points[points.length - 1].price;
                continue;
            }
            while (segmentIndex < points.length - 2 && targetTime > points[segmentIndex + 1].time) {
                segmentIndex++;
            }
            let left = points[segmentIndex];
            let right = points[segmentIndex + 1];
            let span = right.time - left.time;
            let ratio = span === 0 ? 0 : (targetTime - left.time) / span;
            result[i] = left.price + ratio * (right.price - left.price);
        }
        return result;
    }

    function parseHistoryTimestamp(raw: var): real {
        if (raw === undefined || raw === null)
            return NaN;
        if (typeof raw === "number")
            return normalizeEpoch(raw);
        if (typeof raw === "string" && raw.length && raw.match(/^\d+(\.\d+)?$/))
            return normalizeEpoch(parseFloat(raw));
        let parsed = Date.parse(raw);
        return isNaN(parsed) ? NaN : parsed;
    }

    function normalizeEpoch(value: real): real {
        if (!isFinite(value))
            return NaN;
        return value < 1e12 ? value * 1000 : value;
    }

    function updateRange(): void {
        if (!samples.length) {
            minSample = 0;
            maxSample = 0;
            return;
        }
        let lo = samples[0], hi = samples[0];
        for (let i = 1; i < samples.length; ++i) {
            if (samples[i] < lo) lo = samples[i];
            if (samples[i] > hi) hi = samples[i];
        }
        minSample = lo;
        maxSample = hi;
        let padding = (maxSample - minSample) * 0.05;
        if (padding === 0) {
            padding = 1;
        }
        minSample -= padding;
        maxSample += padding;
    }

    function normalizedValue(value: real): real {
        if (maxSample === minSample)
            return 0.5;
        return (value - minSample) / (maxSample - minSample);
    }

    function formattedPrice(value: real): string {
        if (isNaN(value))
            return "--";
        return currencySymbol + Qt.locale().toString(value, "f", 2);
    }

    function labelForStop(stop: real): string {
        if (maxSample === minSample)
            return formattedPrice(currentValue);
        let value = minSample + stop * (maxSample - minSample);
        return formattedPrice(value);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 2
            text: "BTC / " + currency
            color: textColor
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            id: chartArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3

            Canvas {
                id: chartCanvas
                anchors.fill: parent
                antialiasing: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    if (root.samples.length < 2) {
                        if (root.samples.length === 1) {
                            let singleRatio = root.normalizedValue(root.samples[0]);
                            let pointY = (1 - singleRatio) * height;
                            ctx.fillStyle = root.accentColor;
                            ctx.beginPath();
                            ctx.arc(width - 6, pointY, 3, 0, Math.PI * 2);
                            ctx.fill();
                        }
                        return;
                    }

                    // Build line path
                    ctx.beginPath();
                    for (let i = 0; i < root.samples.length; ++i) {
                        let ratio = root.normalizedValue(root.samples[i]);
                        let x = (i / (root.samples.length - 1)) * width;
                        let y = (1 - ratio) * height;
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }

                    // Stroke
                    ctx.strokeStyle = root.accentColor;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // Fill under the line
                    ctx.lineTo(width, height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(
                        root.accentColor.r,
                        root.accentColor.g,
                        root.accentColor.b, 0.1);
                    ctx.fill();
                }
            }

            // Grid lines + labels
            Repeater {
                model: root.gridStops.length
                delegate: Item {
                    id: gridDelegate
                    required property int index
                    property real stopValue: root.gridStops[index]

                    width: chartArea.width
                    height: 1
                    y: (1 - stopValue) * chartArea.height

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: root.gridLineColor
                    }

                    QQC2.Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 1
                        text: root.labelForStop(gridDelegate.stopValue)
                        color: root.textColor
                        opacity: 0.75
                        font: Kirigami.Theme.smallFont
                    }
                }
            }

            QQC2.BusyIndicator {
                anchors.centerIn: parent
                running: root.loading
                visible: root.loading
            }
        }

        // Legend row
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.6
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.6
                radius: width / 2
                color: accentColor
                Layout.alignment: Qt.AlignVCenter
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: loading ? "Fetching BTC price\u2026" : "BTC Price"
                color: textColor
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                QQC2.Label {
                    text: formattedPrice(currentValue)
                    color: textColor
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignRight
                }

                QQC2.Label {
                    text: lastUpdated ? Qt.formatDateTime(new Date(lastUpdated), Qt.DefaultLocaleShortDate) : "--"
                    color: textColor
                    opacity: 0.75
                    font: Kirigami.Theme.smallFont
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
