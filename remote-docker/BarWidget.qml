import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property ShellScreen screen

    property string widgetText: "Server..."
    property string widgetTooltip: "Načítám kontejnery..."
    property string host: pluginApi?.pluginSettings?.remoteHost || "valdemar@void"

    implicitWidth: pill.width
    implicitHeight: pill.height

    Process {
        id: countProcess
        command: ["ssh", "-o", "ConnectTimeout=2", root.host, "docker ps -q | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var count = parseInt(output);
                if (!isNaN(count)) {
                    root.widgetText = "D: " + count;
                    root.widgetTooltip = count + " běžících kontejnerů na " + root.host;
                } else {
                    root.widgetText = "D: Off";
                    root.widgetTooltip = "Server je nedostupný nebo chyba připojení";
                }
            }
        }
    }

    Timer {
        interval: 15000 // Každých 15 vteřin
        running: true
        repeat: true
        onTriggered: countProcess.running = true
    }

    Component.onCompleted: countProcess.running = true

    BarPill {
        id: pill
        autoHide: false
        icon: "server"
        text: root.widgetText
        tooltipText: root.widgetTooltip
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)

        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, this);
            }
        }
    }
}
