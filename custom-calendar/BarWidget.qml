import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets
import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    
    property string widgetText: "Načítám..."
    property string widgetTooltip: "Načítám z kalendáře..."

    property var notifiedEvents: ({})

    implicitWidth: pill.width
    implicitHeight: pill.height

    Process {
        id: notifyProcess
        property string title: ""
        property string message: ""
        command: ["notify-send", "-a", "Google Kalendář", "-u", "critical", title, message]
    }

    function sendNotification(title, message) {
        notifyProcess.title = title;
        notifyProcess.message = message;
        notifyProcess.running = true;
    }

    Process {
        id: gcalcliProcess
        command: ["gcalcli", "agenda", "--tsv", "--nostarted"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                if (output === "") {
                    root.widgetText = "Chyba kalendáře";
                    return;
                }
                
                var lines = output.split('\n');
                if (lines.length <= 1) {
                    root.widgetText = "Žádný meeting";
                    root.widgetTooltip = "Máš volno";
                    return;
                }
                
                var found = false;
                for (var i = 1; i < lines.length; i++) {
                    var parts = lines[i].split('\t');
                    if (parts.length >= 5) {
                        var startDate = parts[0].trim();
                        var startTime = parts[1].trim();
                        var title = parts[4].trim();
                        
                        if (startTime === "") continue; // Celodenní událost
                        
                        // Parsujeme datum a čas v JS
                        var dtStr = startDate + "T" + startTime + ":00";
                        var eventDt = new Date(dtStr);
                        var now = new Date();
                        
                        var diffMs = eventDt - now;
                        var minutesLeft = Math.floor(diffMs / 60000);
                        
                        if (minutesLeft > 0) {
                            root.widgetText = "📅 " + title + " (" + startTime + " - za " + minutesLeft + " min)";
                        } else {
                            root.widgetText = "📅 " + title + " (Nyní!)";
                        }
                        root.widgetTooltip = title;
                        
                        var eventId = title + startDate + startTime;
                        
                        // 10 minut notifikace
                        if (minutesLeft >= 9 && minutesLeft <= 10) {
                            if (!root.notifiedEvents[eventId + "_10"]) {
                                sendNotification("Meeting za 10 minut!", title + " začíná v " + startTime);
                                root.notifiedEvents[eventId + "_10"] = true;
                            }
                        }
                        
                        // 1 minuta notifikace
                        if (minutesLeft >= 0 && minutesLeft <= 1) {
                            if (!root.notifiedEvents[eventId + "_1"]) {
                                sendNotification("Meeting začíná!", title + " právě začíná.");
                                root.notifiedEvents[eventId + "_1"] = true;
                            }
                        }
                        
                        found = true;
                        break;
                    }
                }
                
                if (!found) {
                    root.widgetText = "Žádný meeting";
                    root.widgetTooltip = "Máš volno";
                }
            }
        }
    }

    Timer {
        interval: 60000 // Aktualizace každou minutu
        running: true
        repeat: true
        onTriggered: {
            gcalcliProcess.running = true;
        }
    }

    Component.onCompleted: {
        gcalcliProcess.running = true;
    }

    BarPill {
        id: pill
        autoHide: false
        icon: "calendar-event"
        text: root.widgetText
        tooltipText: root.widgetTooltip
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
    }
}
