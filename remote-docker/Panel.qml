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
    property real contentPreferredHeight: 500 * Style.uiScaleRatio
    property real contentPreferredWidth: 440 * Style.uiScaleRatio

    readonly property var geometryPlaceholder: panelContainer

    property string host: pluginApi?.pluginSettings?.remoteHost || "valdemar@void"
    property var containers: []
    property bool loading: true

    anchors.fill: parent

    Process {
        id: psProcess
        command: ["ssh", "-o", "ConnectTimeout=2", root.host, "docker ps -a --format '{{json .}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var lines = output.split('\n');
                var parsed = [];
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i] === "") continue;
                    try {
                        var c = JSON.parse(lines[i]);
                        parsed.push(c);
                    } catch (e) {
                        console.log("Parse error: " + e);
                    }
                }
                root.containers = parsed;
                root.loading = false;
            }
        }
    }

    Component.onCompleted: {
        psProcess.running = true;
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
                        icon: "brand-docker"
                        pointSize: Style.fontSizeXXL
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        NText {
                            Layout.fillWidth: true
                            color: Color.mOnSurface
                            font.weight: Style.fontWeightBold
                            pointSize: Style.fontSizeL
                            text: "Server Kontejnery"
                        }
                        NText {
                            Layout.fillWidth: true
                            color: Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeXS
                            text: root.host
                        }
                    }
                    NIconButton {
                        icon: "refresh"
                        tooltipText: "Obnovit"
                        onClicked: {
                            root.loading = true;
                            psProcess.running = true;
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
                    clip: true
                    model: root.containers
                    spacing: Style.marginM
                    visible: !root.loading && root.containers.length > 0

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
                                icon: modelData.State === "running" ? "player-play" : "player-stop"
                                color: modelData.State === "running" ? Color.mSuccess : Color.mOnSurfaceVariant
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXXS

                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.Names
                                    font.weight: Font.Bold
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurface
                                }
                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.Status
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                }
                            }

                            NIconButton {
                                icon: modelData.State === "running" ? "player-pause" : "player-play"
                                tooltipText: modelData.State === "running" ? "Zastavit" : "Spustit"
                                onClicked: {
                                    root.loading = true;
                                    var action = modelData.State === "running" ? "stop" : "start";
                                    actionProcess.action = action;
                                    actionProcess.containerName = modelData.Names;
                                    actionProcess.running = true;
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }

                NText {
                    anchors.centerIn: parent
                    text: "Načítám..."
                    visible: root.loading
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    text: "Žádné kontejnery"
                    visible: !root.loading && root.containers.length === 0
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }

    Process {
        id: actionProcess
        property string action: "restart"
        property string containerName: ""
        command: ["ssh", root.host, "docker", action, containerName]
        onRunningChanged: {
            if (!running) {
                // Po dokončení akce aktualizujeme seznam
                psProcess.running = true;
            }
        }
    }
}
