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

    property var allEventsList: []
    property var eventsList: []
    property bool loading: true

    function applyFilter() {
        var showAllDay = pluginApi?.pluginSettings?.showAllDayEvents || false;
        var filtered = [];
        for (var i = 0; i < allEventsList.length; i++) {
            var ev = allEventsList[i];
            if (ev.time === "Celý den" && !showAllDay) {
                continue;
            }
            filtered.push(ev);
        }
        root.eventsList = filtered;
    }

    anchors.fill: parent

    Process {
        id: agendaProcess
        command: ["gcalcli", "agenda", "00:00", "+7d", "--tsv", "--nostarted"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var lines = output.split('\n');
                var parsedEvents = [];
                if (lines.length > 1) {
                    for (var i = 1; i < lines.length; i++) {
                        var parts = lines[i].split('\t');
                        if (parts.length >= 5) {
                            var startDate = parts[0].trim();
                            var startTime = parts[1].trim();
                            var title = parts[4].trim();
                            
                            if (startTime === "") {
                                var titleLower = title.toLowerCase();
                                if (titleLower.indexOf("(office)") !== -1 || titleLower.indexOf("home office") !== -1 || titleLower === "doma") {
                                    continue;
                                }
                            }
                            
                            var eventId = title + startDate + startTime;
                            parsedEvents.push({
                                "date": startDate,
                                "time": startTime === "" ? "Celý den" : startTime,
                                "title": title,
                                "id": eventId
                            });
                        }
                    }
                }
                root.allEventsList = parsedEvents;
                root.applyFilter();
                root.loading = false;
            }
        }
    }

    Component.onCompleted: {
        agendaProcess.running = true;
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
                implicitHeight: headerColumn.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: headerColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIcon {
                            color: Color.mPrimary
                            icon: "calendar-event"
                            pointSize: Style.fontSizeXXL
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            NText {
                                Layout.fillWidth: true
                                color: Color.mOnSurface
                                font.weight: Style.fontWeightBold
                                pointSize: Style.fontSizeL
                                text: "Týdenní přehled schůzek"
                            }
                        }
                        NIconButton {
                            icon: "refresh"
                            tooltipText: "Obnovit"
                            onClicked: {
                                root.loading = true;
                                agendaProcess.running = true;
                            }
                        }
                        NIconButton {
                            icon: "close"
                            tooltipText: "Zavřít"
                            onClicked: pluginApi?.closePanel(pluginApi?.panelOpenScreen)
                        }
                    }

                    NDivider {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NText {
                            text: "Zobrazovat celodenní události"
                            color: Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                            Layout.fillWidth: true
                        }
                        Switch {
                            checked: pluginApi?.pluginSettings?.showAllDayEvents || false
                            onCheckedChanged: {
                                var s = pluginApi.pluginSettings || {};
                                s.showAllDayEvents = checked;
                                pluginApi.pluginSettings = s;
                                pluginApi.saveSettings();
                                root.applyFilter();
                            }
                        }
                    }
                }
            }

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                NListView {
                    id: eventsView
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    clip: true
                    model: root.eventsList
                    spacing: Style.marginM
                    visible: !root.loading && root.eventsList.length > 0

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

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXXS

                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.weight: Font.Bold
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurface
                                }
                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.date + " " + modelData.time
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                }
                            }

                            Switch {
                                id: notifSwitch
                                checked: !(pluginApi?.pluginSettings?.disabledNotifications?.[modelData.id])
                                onCheckedChanged: {
                                    var disabledMap = pluginApi?.pluginSettings?.disabledNotifications || {};
                                    if (!checked) {
                                        disabledMap[modelData.id] = true;
                                    } else {
                                        delete disabledMap[modelData.id];
                                    }
                                    pluginApi.pluginSettings.disabledNotifications = disabledMap;
                                    pluginApi.saveSettings();
                                }
                            }
                            NIcon {
                                icon: notifSwitch.checked ? "bell" : "bell-off"
                                color: notifSwitch.checked ? Color.mPrimary : Color.mOnSurfaceVariant
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }

                NText {
                    anchors.centerIn: parent
                    text: "Načítám z Googlu..."
                    visible: root.loading
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    text: "Žádné schůzky na nejbližší týden"
                    visible: !root.loading && root.eventsList.length === 0
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
