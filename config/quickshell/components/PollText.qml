import QtQuick
import Quickshell.Io

Item {
    id: root

    property var command: []
    property int interval: 5000
    property string value: ""
    property bool running: process.running

    function poll() {
        if (command.length === 0 || process.running)
            return;

        process.exec(command);
    }

    Component.onCompleted: poll()

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.poll()
    }

    Process {
        id: process

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.value = text.trim()
        }
    }
}
