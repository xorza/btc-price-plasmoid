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
    property int updateInterval: 30000 // ms (debug cadence; keep gentle for production)
    property int maxSamples: 2880
    property var samples: []
    property real minSample: 0
    property real maxSample: 0
    property real currentValue: 0
    property string lastUpdated: ""
    property bool loading: true

    // Visual constants
    property color accentColor: "#1de9b6"
    property color gridColor: "#5c6155"
    property color textColor: "#f4f5f0"
    property var gridStops: [1, 0.75, 0.5, 0.25, 0]

    Timer {
        id: fetchTimer
        interval: updateInterval
        repeat: true
        running: true
        onTriggered: fetchPrice()
    }

    Component.onCompleted: fetchPrice()

    function fetchPrice() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    var payload = data && data.data;
                    var amount = payload && payload.amount ? parseFloat(payload.amount) : NaN;
                    if (!amount || isNaN(amount)) {
                        console.warn("BTC API payload missing amount", xhr.responseText);
                        return;
                    }
                    currentValue = amount;
                    lastUpdated = payload && payload.time ? payload.time : new Date().toISOString();
                    pushSample(amount);
                    loading = false;
                } catch (e) {
                    console.warn("BTC API parse error", e);
                }
            } else {
                console.warn("BTC API request failed", xhr.status, xhr.responseText);
            }
        };
        xhr.send();
    }

    function pushSample(price) {
        var nextSamples = samples.slice(Math.max(0, samples.length - (maxSamples - 1)));
        nextSamples.push(price);
        samples = nextSamples;
        updateRange();
        chartCanvas.requestPaint();
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
                    ctx.lineWidth = 2;
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
