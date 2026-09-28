import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    readonly property string script: (pluginApi?.pluginDir || "") + "/mail-check.py"
    readonly property var settings: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property var accounts: []
    property int totalCount: 0
    property bool loading: false
    property string error: ""

    // Message ids already seen; the first fetch only fills this so startup doesn't spam notifications
    property var knownIds: ({})
    property bool initialized: false

    function accountLabel(address) {
        return /@(gmail|googlemail)\.com$/.test(address) ? "Osobní" : "Pracovní";
    }

    function setting(key) {
        return settings[key] !== undefined ? settings[key] : defaults[key];
    }

    function refresh() {
        if (fetchProcess.running || !pluginApi)
            return;
        root.loading = true;
        fetchProcess.command = ["python3", root.script, "fetch", JSON.stringify({
            "defaultQuery": setting("defaultQuery"),
            "accountQueries": setting("accountQueries") || {},
            "maxMessages": setting("maxMessages")
        })];
        fetchProcess.running = true;
    }

    function markRead(address, uid) {
        // Optimistic update so the panel reacts immediately
        var updated = [];
        for (var i = 0; i < accounts.length; i++) {
            var acc = Object.assign({}, accounts[i]);
            if (acc.email === address) {
                acc.messages = acc.messages.filter(function (m) { return m.uid !== uid; });
                acc.count = Math.max(0, acc.count - 1);
            }
            updated.push(acc);
        }
        setAccounts(updated);
        Quickshell.execDetached(["python3", root.script, "mark-read", address, String(uid)]);
    }

    function setAccounts(list) {
        var total = 0;
        for (var i = 0; i < list.length; i++)
            total += list[i].count;
        root.accounts = list;
        root.totalCount = total;
    }

    function notify(title, body, url) {
        // Clicking "Otevřít" in the notification opens the thread in the browser
        Quickshell.execDetached(["sh", "-c",
            'a=$(notify-send -a Gmail -i mail-unread -A open=Otevřít --wait "$1" "$2"); [ "$a" = open ] && xdg-open "$3"',
            "sh", title, body, url]);
    }

    function handleNewMessages(list) {
        var fresh = [];
        var ids = {};
        for (var i = 0; i < list.length; i++) {
            for (var j = 0; j < list[i].messages.length; j++) {
                var msg = list[i].messages[j];
                ids[msg.id] = true;
                if (root.initialized && !root.knownIds[msg.id])
                    fresh.push({ "account": list[i].email, "msg": msg });
            }
        }
        root.knownIds = Object.assign(root.knownIds, ids);
        root.initialized = true;

        if (!setting("notifications") || fresh.length === 0)
            return;
        if (fresh.length > 3) {
            notify(fresh.length + " nových e-mailů", fresh.slice(0, 3).map(function (f) { return f.msg.from + ": " + f.msg.subject; }).join("\n"),
                   "https://mail.google.com/mail/u/" + fresh[0].account + "/");
            return;
        }
        for (var k = 0; k < fresh.length; k++)
            notify(fresh[k].msg.from, fresh[k].msg.subject + "\n" + fresh[k].account, fresh[k].msg.url);
    }

    Process {
        id: fetchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    var list = JSON.parse(this.text.trim()).accounts || [];
                    // Work accounts first
                    list.sort(function (a, b) {
                        return (root.accountLabel(a.email) === "Osobní") - (root.accountLabel(b.email) === "Osobní");
                    });
                    root.error = list.length === 0 ? "V GNOME Online Accounts není žádný Google účet se zapnutým mailem" : "";
                    root.setAccounts(list);
                    root.handleNewMessages(list);
                } catch (e) {
                    Logger.e("GmailInbox", "Failed to parse output: " + e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "") {
                    root.loading = false;
                    root.error = this.text.trim().split("\n").pop();
                    Logger.e("GmailInbox", this.text.trim());
                }
            }
        }
    }

    Timer {
        interval: Math.max(30, root.setting("refreshInterval") || 60) * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    onPluginApiChanged: root.refresh()
    Component.onCompleted: root.refresh()
}
