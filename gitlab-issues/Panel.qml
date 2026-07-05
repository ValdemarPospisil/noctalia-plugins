import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property real contentPreferredHeight: 800 * Style.uiScaleRatio
    property real contentPreferredWidth: 600 * Style.uiScaleRatio

    readonly property var geometryPlaceholder: panelContainer

    property var listModel: []
    property bool loading: true

    anchors.fill: parent

    Process {
        id: dataProcess
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
                
                var parsedList = [];
                
                // Process Issues
                for(var i=0; i<issues.length; i++) {
                    var issue = issues[i];
                    var category = "Ostatní Úkoly";
                    var labels = issue.labels || [];
                    if (labels.indexOf("In Progress") !== -1) category = "In Progress";
                    else if (labels.indexOf("Sprint") !== -1) category = "Sprint";
                    else if (labels.indexOf("Backlog") !== -1) category = "Backlog";
                    
                    var issueRef = issue.references && issue.references.full ? issue.references.full : "";
                    var issueProjectName = issueRef.split("#")[0].split("/").pop();
                    
                    parsedList.push({
                        type: "issue",
                        title: issue.title,
                        category: category,
                        url: issue.web_url,
                        idStr: "#" + issue.iid,
                        projectName: issueProjectName
                    });
                }
                
                // Process MRs
                for(var j=0; j<mrs.length; j++) {
                    var mr = mrs[j];
                    
                    var mrRef = mr.references && mr.references.full ? mr.references.full : "";
                    var mrProjectName = mrRef.split("!")[0].split("/").pop();
                    
                    parsedList.push({
                        type: "mr",
                        title: mr.title,
                        category: "Merge Requests",
                        url: mr.web_url,
                        idStr: "!" + mr.iid,
                        branch: mr.source_branch,
                        projectName: mrProjectName
                    });
                }
                
                // Sort so categories group together nicely
                var order = {"In Progress": 1, "Sprint": 2, "Backlog": 3, "Ostatní Úkoly": 4, "Merge Requests": 5};
                parsedList.sort(function(a, b) {
                    if (order[a.category] !== order[b.category]) return order[a.category] - order[b.category];
                    return a.title.localeCompare(b.title);
                });
                
                root.listModel = parsedList;
                root.loading = false;
            }
        }
    }

    Component.onCompleted: {
        dataProcess.running = true;
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginL

            NBox {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + Style.margin2M

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NIcon {
                        color: Color.mPrimary
                        icon: "brand-gitlab"
                        pointSize: Style.fontSizeXXL
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        NText {
                            Layout.fillWidth: true
                            color: Color.mOnSurface
                            font.weight: Style.fontWeightBold
                            pointSize: Style.fontSizeL
                            text: "GitLab Přehled"
                        }
                    }
                    NIconButton {
                        icon: "refresh"
                        tooltipText: "Obnovit"
                        onClicked: {
                            root.loading = true;
                            dataProcess.running = true;
                        }
                    }
                    NIconButton {
                        icon: "close"
                        tooltipText: "Zavřít"
                        onClicked: pluginApi?.closePanel(pluginApi?.panelOpenScreen)
                    }
                }
            }

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                NListView {
                    id: cView
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    anchors.bottomMargin: Style.marginXXL
                    clip: true
                    model: root.listModel
                    spacing: Style.marginM
                    visible: !root.loading && root.listModel.length > 0
                    
                    section.property: "category"
                    section.delegate: Rectangle {
                        width: ListView.view.width
                        height: Style.fontSizeL + Style.margin2M
                        color: "transparent"
                        NText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: section
                            font.weight: Font.Bold
                            color: Color.mPrimary
                            pointSize: Style.fontSizeL
                        }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: delegateLayout.implicitHeight + Style.margin2M
                        radius: Style.radiusM
                        color: Color.mSurface

                        RowLayout {
                            id: delegateLayout
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginM

                            NIcon {
                                icon: modelData.type === "mr" ? "git-merge" : "circle-dot"
                                color: modelData.type === "mr" ? Color.mSuccess : Color.mPrimary
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXXS

                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.weight: Font.Bold
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurface
                                    wrapMode: Text.Wrap
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: pluginApi?.openUrl(modelData.url)
                                    }
                                }
                                NText {
                                    Layout.fillWidth: true
                                    text: (modelData.projectName ? modelData.projectName + " " : "") + modelData.idStr + (modelData.branch ? " | " + modelData.branch : "")
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                }
                            }

                            NIconButton {
                                visible: modelData.type === "mr"
                                icon: "copy"
                                tooltipText: "Kopírovat větev do schránky"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: {
                                    copyProcess.textToCopy = modelData.branch;
                                    copyProcess.running = true;
                                    
                                    // Visual feedback
                                    icon = "check"
                                    color = Color.mSuccess
                                    resetIconTimer.start()
                                }
                                
                                Timer {
                                    id: resetIconTimer
                                    interval: 2000
                                    onTriggered: {
                                        parent.icon = "copy"
                                        parent.color = Color.mOnSurface
                                    }
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }

                NText {
                    anchors.centerIn: parent
                    text: "Načítám z GitLabu..."
                    visible: root.loading
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    text: "Žádné přidělené úkoly"
                    visible: !root.loading && root.listModel.length === 0
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }

    Process {
        id: copyProcess
        property string textToCopy: ""
        command: ["sh", "-c", "echo -n '" + textToCopy + "' | wl-copy"]
    }
}
