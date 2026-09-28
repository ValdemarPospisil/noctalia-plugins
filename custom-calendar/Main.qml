import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Loads events and holds shared helpers for BarWidget and Panel (via pluginApi.mainInstance).
Item {
    id: root

    property var pluginApi: null

    property var events: []
    property bool available: false
    property bool loading: false
    property string lastError: ""

    readonly property string noctaliaEventsScript: Quickshell.shellDir + "/Scripts/python/src/calendar/calendar-events.py"

    function loadEvents() {
        if (eventsProcess.running || !pluginApi)
            return;
        var now = Math.floor(Date.now() / 1000);
        root.loading = true;
        eventsProcess.command = ["python3", pluginApi.pluginDir + "/calendar-events.py", root.noctaliaEventsScript,
                                 String(now - 86400), String(now + 8 * 86400)];
        eventsProcess.running = true;
    }

    Process {
        id: eventsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    root.events = JSON.parse(this.text.trim());
                    root.available = true;
                    root.lastError = "";
                } catch (e) {
                    root.available = false;
                    Logger.e("CustomCalendar", "Failed to parse events: " + e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // The Noctalia script logs progress to stderr, only the last traceback line matters
                var lines = this.text.trim().split("\n");
                var last = lines[lines.length - 1];
                if (last.indexOf("Error") !== -1)
                    root.lastError = last;
            }
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.loadEvents()
    }

    onPluginApiChanged: root.loadEvents()
    Component.onCompleted: root.loadEvents()

    // Events come from Noctalia's CalendarService (Evolution Data Server / khal):
    // { summary, calendar, start, end, location, description, uid } with start/end in unix seconds.

    function isAllDay(ev) {
        var start = new Date(ev.start * 1000);
        var duration = ev.end - ev.start;
        return duration > 0 && duration % 86400 === 0 && start.getHours() === 0 && start.getMinutes() === 0;
    }

    function isIgnored(ev) {
        if (!isAllDay(ev))
            return false;
        var title = (ev.summary || "").toLowerCase();
        return title.indexOf("(office)") !== -1 || title.indexOf("home office") !== -1 || title === "doma";
    }

    function eventId(ev) {
        return (ev.uid || ev.summary) + "@" + ev.start;
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function formatTime(ts) {
        var d = new Date(ts * 1000);
        return pad(d.getHours()) + ":" + pad(d.getMinutes());
    }

    function formatDay(ts) {
        var d = new Date(ts * 1000);
        var today = new Date();
        today.setHours(0, 0, 0, 0);
        var diffDays = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
        if (diffDays === 0)
            return "Dnes";
        if (diffDays === 1)
            return "Zítra";
        var names = ["Neděle", "Pondělí", "Úterý", "Středa", "Čtvrtek", "Pátek", "Sobota"];
        return names[d.getDay()] + " " + d.getDate() + ". " + (d.getMonth() + 1) + ".";
    }

    function formatCountdown(minutes) {
        if (minutes >= 1440)
            return Math.floor(minutes / 1440) + "d " + Math.floor((minutes % 1440) / 60) + "h";
        if (minutes >= 60)
            return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
        return minutes + " min";
    }

    // Events that haven't ended yet and start within `days`, sorted by start time
    function upcoming(events, days, showAllDay) {
        var now = Date.now() / 1000;
        var limit = now + days * 86400;
        var result = [];
        for (var i = 0; i < (events || []).length; i++) {
            var ev = events[i];
            if (ev.end <= now || ev.start > limit || isIgnored(ev))
                continue;
            if (isAllDay(ev) && !showAllDay)
                continue;
            result.push(ev);
        }
        result.sort(function (a, b) {
            return a.start - b.start;
        });
        return result;
    }
}
