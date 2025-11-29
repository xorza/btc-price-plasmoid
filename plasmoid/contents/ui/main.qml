import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0 as Plasmoid

Plasmoid.PlasmoidItem {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Kirigami.Units.gridUnit * 16

    // Data + API setup
    property string currency: "USD"
    property string currencySymbol: "$"
    property string apiBaseUrl: "https://api.coinbase.com/v2/prices/spot?currency="
    property string apiUrl: apiBaseUrl + currency
    property string currencyPair: "BTC-" + currency
    property string historyBaseUrl: "https://api.coinbase.com/v2/prices/"
    property string historyUrl: historyBaseUrl + currencyPair + "/historic?period=day"
    property int sampleInterval: 300000 // ms (debug cadence; keep gentle for production)
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
    property color accentColor: "#1de9b6"
    property color gridColor: "#5c6155"
    property color textColor: "#f4f5f0"
    property var gridStops: [1, 0.75, 0.5, 0.25, 0]

    Timer {
        id: fetchTimer
        interval: sampleInterval
        repeat: true
        running: true
        onTriggered: fetchPrice()
    }

    Component.onCompleted: {
        fetchHistory();
        fetchPrice();
    }

    function fetchHistory() {
        historyFetchInProgress = true;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", historyUrl);
        xhr.onerror = function (event) {
            console.error("BTC history network error", event && event.type ? event.type : event);
            historyFetchInProgress = false;
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            historyFetchInProgress = false;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    var prices = data && data.data && data.data.prices;
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
            }
        };
        xhr.send();
    }

    function fetchPrice() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl);
        xhr.onerror = function (event) {
            handleSpotFailure("BTC API network error", event && event.type ? event.type : event);
        };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    var payload = data && data.data;
                    var amount = payload && payload.amount ? parseFloat(payload.amount) : NaN;
                    if (!amount || isNaN(amount)) {
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

    function handleSpotFailure(message, detail) {
        console.error(message, detail);
        registerSpotFailure();
    }

    function registerSpotSuccess() {
        failureStartTime = 0;
        attemptHistoryRecovery();
    }

    function registerSpotFailure() {
        var now = Date.now();
        if (!failureStartTime) {
            failureStartTime = now;
        }
        if (!historyRecoveryNeeded && now - failureStartTime >= failureRecoveryInterval) {
            historyRecoveryNeeded = true;
            console.warn("BTC API failures exceeded 30 minutes, requesting full history");
        }
        attemptHistoryRecovery();
    }

    function attemptHistoryRecovery() {
        if (!historyRecoveryNeeded || historyFetchInProgress)
            return;
        fetchHistory();
    }

    function pushSample(price) {
        var nextSamples = samples.slice(Math.max(0, samples.length - (maxSamples - 1)));
        nextSamples.push(price);
        samples = nextSamples;
        updateRange();
        chartCanvas.requestPaint();
    }

    function hydrateSamplesFromHistory(historyEntries) {
        var parsed = [];
        for (var i = 0; i < historyEntries.length; ++i) {
            var entry = historyEntries[i] || {};
            var rawPrice = entry.price || entry.amount || entry.spot_price;
            var price = rawPrice ? parseFloat(rawPrice) : NaN;
            var timestamp = parseHistoryTimestamp(entry.time);
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
        parsed.sort(function (a, b) {
            return a.time - b.time;
        });
        var interpolated = interpolateHistorySeries(parsed);

        if (!interpolated.length) {
            console.warn("BTC history interpolation failed");
            return;
        }
        console.log("BTC history hydrated", parsed.length, "entries ->", interpolated.length, "samples", "source range", new Date(parsed[0].time).toISOString(), "to", new Date(parsed[parsed.length - 1].time).toISOString());
        console.log("BTC history preview", interpolated.slice(0, 5), "...", interpolated.slice(Math.max(0, interpolated.length - 5)));
        samples = interpolated;
        currentValue = interpolated[interpolated.length - 1];
        lastUpdated = new Date(parsed[parsed.length - 1].time).toISOString();
        updateRange();
        chartCanvas.requestPaint();
        loading = false;
        if (historyRecoveryNeeded) {
            historyRecoveryNeeded = false;
            failureStartTime = Date.now();
        }
    }

    function interpolateHistorySeries(points) {
        var desiredSamples = maxSamples;
        if (desiredSamples <= 0)
            return [];
        var interval = sampleInterval;
        var newestTime = points[points.length - 1].time;
        var oldestTime = newestTime - (desiredSamples - 1) * interval;
        var historyOldest = points[0].time;
        if (historyOldest > oldestTime) {
            console.warn("BTC history older gap", new Date(historyOldest).toISOString(), "target oldest", new Date(oldestTime).toISOString());
        }
        var result = new Array(desiredSamples);
        var segmentIndex = 0;
        for (var i = 0; i < desiredSamples; ++i) {
            var targetTime = oldestTime + i * interval;
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
            var left = points[segmentIndex];
            var right = points[segmentIndex + 1];
            var span = right.time - left.time;
            var ratio = span === 0 ? 0 : (targetTime - left.time) / span;
            result[i] = left.price + ratio * (right.price - left.price);
        }
        return result;
    }

    function parseHistoryTimestamp(raw) {
        if (raw === undefined || raw === null)
            return NaN;
        if (typeof raw === "number")
            return normalizeEpoch(raw);
        if (typeof raw === "string" && raw.length && raw.match(/^\d+(\.\d+)?$/))
            return normalizeEpoch(parseFloat(raw));
        var parsed = Date.parse(raw);
        return isNaN(parsed) ? NaN : parsed;
    }

    function normalizeEpoch(value) {
        if (!isFinite(value))
            return NaN;
        return value < 1e12 ? value * 1000 : value;
    }

    function updateRange() {
        if (!samples.length) {
            minSample = 0;
            maxSample = 0;
            return;
        }
        minSample = Math.min.apply(Math, samples);
        maxSample = Math.max.apply(Math, samples);
        var padding = (maxSample - minSample) * 0.05;
        if (padding === 0) {
            padding = 1;
        }
        minSample -= padding;
        maxSample += padding;
    }

    function normalizedValue(value) {
        if (maxSample === minSample)
            return 0.5;
        return (value - minSample) / (maxSample - minSample);
    }

    function formattedPrice(value) {
        if (value === undefined || value === null || value !== value)
            return "--";
        return currencySymbol + Qt.locale().toString(value, "f", 2);
    }

    function labelForStop(stop) {
        if (maxSample === minSample)
            return formattedPrice(currentValue);
        var value = minSample + stop * (maxSample - minSample);
        return formattedPrice(value);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "BTC / " + currency
            color: textColor
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.3
        }

        Item {
            id: chartArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: gridStops.length
                delegate: Item {
                    width: chartArea.width
                    height: 1
                    y: (1 - gridStops[index]) * chartArea.height

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: gridColor
                        opacity: 0.45
                    }

                    QQC2.Label {
                        LayoutMirroring.enabled: true
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: labelForStop(gridStops[index])
                        color: textColor
                        opacity: 0.8
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                    }
                }
            }

            Canvas {
                id: chartCanvas
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);

                    if (samples.length < 2) {
                        if (samples.length === 1) {
                            var singleRatio = normalizedValue(samples[0]);
                            var pointY = (1 - singleRatio) * height;
                            ctx.fillStyle = accentColor;
                            ctx.beginPath();
                            ctx.arc(width - 6, pointY, 3, 0, Math.PI * 2);
                            ctx.fill();
                        }
                        return;
                    }

                    ctx.strokeStyle = accentColor;
                    ctx.lineWidth = 1;
                    ctx.beginPath();

                    for (var i = 0; i < samples.length; ++i) {
                        var ratio = normalizedValue(samples[i]);
                        var x = (i / (samples.length - 1)) * width;
                        var y = (1 - ratio) * height;
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }

                    ctx.stroke();
                }
            }

            QQC2.BusyIndicator {
                anchors.centerIn: parent
                running: loading
                visible: loading
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.3
                Layout.preferredHeight: Kirigami.Units.gridUnit
                radius: 0
                color: accentColor
                Layout.alignment: Qt.AlignBottom
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: loading ? "Fetching BTC price" : "BTC Price"
                color: textColor
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                Layout.alignment: Qt.AlignBottom
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignBottom

                QQC2.Label {
                    text: formattedPrice(currentValue)
                    color: textColor
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                    Layout.alignment: Qt.AlignRight
                }

                QQC2.Label {
                    text: lastUpdated ? Qt.formatDateTime(new Date(lastUpdated), Qt.DefaultLocaleShortDate) : "--"
                    color: textColor
                    opacity: 0.7
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
