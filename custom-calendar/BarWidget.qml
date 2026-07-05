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
                
                var foundFirst = false;
                var tooltipLines = [];
                var todayDateStr = new Date().toISOString().split('T')[0];
                
                for (var i = 1; i < lines.length; i++) {
                    var parts = lines[i].split('\t');
                    if (parts.length >= 5) {
                        var startDate = parts[0].trim();
                        var startTime = parts[1].trim();
                        var endDate = parts[2].trim();
                        var title = parts[4].trim();
                        
                        if (startTime === "") {
                            var titleLower = title.toLowerCase();
                            if (titleLower.indexOf("(office)") !== -1 || titleLower.indexOf("home office") !== -1 || titleLower === "doma") {
                                continue;
                            }
                        }
                        
                        if (startDate === todayDateStr) {
                            if (startTime === "") {
                                tooltipLines.push("📅 Celý den: " + title);
                            } else {
                                tooltipLines.push("🕒 " + startTime + " - " + title);
                            }
                        }
                        
                        if (startTime === "") {
                            continue; // Pro widget na liště přeskočíme celodenní
                        }
                        
                        if (!foundFirst) {
                            var dtStr = startDate + "T" + startTime + ":00";
                            var eventDt = new Date(dtStr);
                            var now = new Date();
                            
                            var diffMs = eventDt - now;
                            var minutesLeft = Math.floor(diffMs / 60000);
                            
                            var timeLeftStr = "";
                            if (minutesLeft >= 1440) {
                                var days = Math.floor(minutesLeft / 1440);
                                var hours = Math.floor((minutesLeft % 1440) / 60);
                                timeLeftStr = days + "d " + hours + "h";
                            } else if (minutesLeft >= 60) {
                                var hours = Math.floor(minutesLeft / 60);
                                var mins = minutesLeft % 60;
                                timeLeftStr = hours + "h " + mins + "m";
                            } else {
                                timeLeftStr = minutesLeft + " min";
                            }
                            
                            if (minutesLeft > 0) {
                                root.widgetText = "📅 " + title + " (" + startTime + " - za " + timeLeftStr + ")";
                            } else {
                                root.widgetText = "📅 " + title + " (Nyní!)";
                            }
                            
                            var eventId = title + startDate + startTime;
                            
                            var disabledMap = pluginApi?.pluginSettings?.disabledNotifications || {};
                            var isDisabled = disabledMap[eventId];
                            
                            if (!isDisabled) {
                                if (minutesLeft >= 9 && minutesLeft <= 10) {
                                    if (!root.notifiedEvents[eventId + "_10"]) {
                                        sendNotification("Meeting za 10 minut!", title + " začíná v " + startTime);
                                        root.notifiedEvents[eventId + "_10"] = true;
                                    }
                                }
                                
                                if (minutesLeft >= 0 && minutesLeft <= 1) {
                                    if (!root.notifiedEvents[eventId + "_1"]) {
                                        sendNotification("Meeting začíná!", title + " právě začíná.");
                                        root.notifiedEvents[eventId + "_1"] = true;
                                    }
                                }
                            }
                            
                            foundFirst = true;
                        }
                    }
                }
                
                if (!foundFirst) {
                    root.widgetText = "Žádný meeting";
                }
                
                if (tooltipLines.length > 0) {
                    root.widgetTooltip = tooltipLines.join('\n');
                } else {
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

        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, this);
            }
        }
    }
}
