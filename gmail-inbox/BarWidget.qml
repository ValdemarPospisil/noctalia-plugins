import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property ShellScreen screen

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var accounts: mainInstance?.accounts || []
    readonly property int totalCount: mainInstance?.totalCount || 0

    implicitWidth: pill.width
    implicitHeight: pill.height

    function tooltip() {
        if (mainInstance?.error)
            return mainInstance.error;
        if (accounts.length === 0)
            return "Načítám...";
        return accounts.map(function (a) {
            return mainInstance.accountLabel(a.email) + ": " + (a.error ? "chyba" : a.count) + "  (" + a.email + ")";
        }).join("\n");
    }

    BarPill {
        id: pill
        autoHide: false
        icon: root.totalCount > 0 ? "mail" : "mail-opened"
        text: root.mainInstance?.error ? "!" : String(root.totalCount)
        tooltipText: root.tooltip()
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)

        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, this);
            }
        }
    }
}
