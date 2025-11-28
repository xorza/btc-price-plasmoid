import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.1 as PlasmaCore

Item {
    id: root
    implicitWidth: PlasmaCore.Units.gridUnit * 12
    implicitHeight: PlasmaCore.Units.gridUnit * 6

    property int sampleCount: 32
    property var samples: []

    function initSamples() {
        var points = []
        for (var i = 0; i < sampleCount; ++i) {
            points.push(Math.random())
        }
        samples = points
        chartCanvas.requestPaint()
    }

    function addSample() {
        if (samples.length === 0)
            return
        var next = samples.slice(1)
        next.push(Math.random())
        samples = next
        chartCanvas.requestPaint()
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: addSample()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: PlasmaCore.Units.smallSpacing
        spacing: PlasmaCore.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: "BTC Price"
            font.pixelSize: PlasmaCore.Theme.defaultFont.pixelSize * 1.1
        }

        Item {
            id: chartContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                radius: PlasmaCore.Units.smallSpacing
                color: PlasmaCore.Theme.backgroundColor
                border.color: PlasmaCore.Theme.highlightColor
                border.width: 1
            }

            Canvas {
                id: chartCanvas
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    if (samples.length === 0)
                        return

                    ctx.strokeStyle = PlasmaCore.Theme.highlightColor
                    ctx.lineWidth = 2
                    ctx.beginPath()

                    for (var i = 0; i < samples.length; ++i) {
                        var x = (i / (samples.length - 1)) * width
                        var y = height - (samples[i] * height)
                        if (i === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }

                    ctx.stroke()
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: "Placeholder data – hook up real BTC prices next"
            font.pixelSize: PlasmaCore.Theme.smallestFont.pixelSize
            color: PlasmaCore.Theme.disabledTextColor
            horizontalAlignment: Text.AlignLeft
        }
    }

    Component.onCompleted: initSamples()
}
