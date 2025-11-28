import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0 as Plasmoid

Plasmoid.PlasmoidItem {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Kirigami.Units.gridUnit * 6

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
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: "BTC Price"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
        }

        Item {
            id: chartContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.highlightColor
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

                    ctx.strokeStyle = Kirigami.Theme.highlightColor
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
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignLeft
        }
    }

    Component.onCompleted: initSamples()
}
