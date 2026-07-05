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

    property string widgetText: "GitLab..."
    property string widgetTooltip: "Načítám..."
    property int issuesCount: 0
    property int mrsCount: 0

    implicitWidth: pill.width
    implicitHeight: pill.height

    Process {
        id: countProcess
        command: ["sh", "-c", "glab api 'issues?state=opened&scope=assigned_to_me' && echo '---SPLIT---' && glab api 'merge_requests?state=opened&scope=assigned_to_me'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var parts = output.split('---SPLIT---');
                var issues = [];
                var mrs = [];
                try {
                    if (parts[0]) issues = JSON.parse(parts[0]);
                    if (parts[1]) mrs = JSON.parse(parts[1]);
                } catch(e) {}
                
                root.issuesCount = issues.length || 0;
                root.mrsCount = mrs.length || 0;
                root.widgetText = "GL: " + (root.issuesCount + root.mrsCount);
                root.widgetTooltip = root.issuesCount + " Úkolů, " + root.mrsCount + " MRs";
            }
        }
    }

    Timer {
        interval: 60000 // Každou minutu
        running: true
        repeat: true
        onTriggered: countProcess.running = true
    }

    Component.onCompleted: countProcess.running = true

    BarPill {
        id: pill
        autoHide: false
        icon: "brand-gitlab"
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
