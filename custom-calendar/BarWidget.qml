import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Location
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

    readonly property var utils: pluginApi?.mainInstance || null

    implicitWidth: pill.width
    implicitHeight: pill.height

    Process {
        id: notifyProcess
        property string title: ""
        property string message: ""
        command: ["notify-send", "-a", "Kalendář", "-u", "critical", title, message]
    }

    function sendNotification(title, message) {
        notifyProcess.title = title;
        notifyProcess.message = message;
        notifyProcess.running = true;
    }

    function update() {
        if (!utils)
            return;
        if (!CalendarService.available) {
            root.widgetText = "Kalendář nedostupný";
            root.widgetTooltip = CalendarService.lastError || "Nainstaluj evolution-data-server a přidej Google účet v GNOME Online Accounts";
            return;
        }

        var showAllDay = pluginApi?.pluginSettings?.showAllDayEvents || false;
        var events = utils.upcoming(CalendarService.events, 7, showAllDay);
        var nowSec = Date.now() / 1000;
        var endOfToday = new Date();
        endOfToday.setHours(23, 59, 59, 999);

        var tooltipLines = [];
        var next = null;
        for (var i = 0; i < events.length; i++) {
            var ev = events[i];
            var allDay = utils.isAllDay(ev);
            if (ev.start * 1000 <= endOfToday.getTime()) {
                tooltipLines.push(allDay ? "📅 Celý den: " + ev.summary : "🕒 " + utils.formatTime(ev.start) + " - " + ev.summary);
            }
            if (!allDay && next === null) {
                next = ev;
            }
        }

        root.widgetTooltip = tooltipLines.length > 0 ? tooltipLines.join('\n') : "Máš volno";

        if (next === null) {
            root.widgetText = "Žádný meeting";
            return;
        }

        var startTime = utils.formatTime(next.start);
        var minutesLeft = Math.floor((next.start - nowSec) / 60);
        if (minutesLeft > 0) {
            root.widgetText = "📅 " + next.summary + " (" + startTime + " - za " + utils.formatCountdown(minutesLeft) + ")";
        } else {
            root.widgetText = "📅 " + next.summary + " (Nyní!)";
        }

        var eventId = utils.eventId(next);
        var disabledMap = pluginApi?.pluginSettings?.disabledNotifications || {};
        if (disabledMap[eventId]) {
            return;
        }
        if (minutesLeft >= 9 && minutesLeft <= 10 && !root.notifiedEvents[eventId + "_10"]) {
            sendNotification("Meeting za 10 minut!", next.summary + " začíná v " + startTime);
            root.notifiedEvents[eventId + "_10"] = true;
        }
        if (minutesLeft >= 0 && minutesLeft <= 1 && !root.notifiedEvents[eventId + "_1"]) {
            sendNotification("Meeting začíná!", next.summary + " právě začíná.");
            root.notifiedEvents[eventId + "_1"] = true;
        }
    }

    Connections {
        target: CalendarService
        function onEventsChanged() { root.update(); }
        function onAvailableChanged() { root.update(); }
    }

    // CalendarService refreshes events itself; this only keeps the countdown current
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    onUtilsChanged: root.update()
    Component.onCompleted: root.update()

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
