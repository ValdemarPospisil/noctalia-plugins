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

    property var eventsList: []
    readonly property var utils: pluginApi?.mainInstance || null
    property bool loading: (utils?.loading ?? true) && (utils?.events?.length ?? 0) === 0

    function applyFilter() {
        if (!utils)
            return;
        var showAllDay = pluginApi?.pluginSettings?.showAllDayEvents || false;
        var events = utils.upcoming(utils.events, 7, showAllDay);
        var list = [];
        for (var i = 0; i < events.length; i++) {
            var ev = events[i];
            var allDay = utils.isAllDay(ev);
            list.push({
                "day": utils.formatDay(ev.start),
                "time": allDay ? "Celý den" : utils.formatTime(ev.start) + " – " + utils.formatTime(ev.end),
                "title": ev.summary,
                "location": ev.location || "",
                "calendar": ev.calendar || "",
                "id": utils.eventId(ev)
            });
        }
        root.eventsList = list;
    }

    anchors.fill: parent

    Connections {
        target: root.utils
        function onEventsChanged() { root.applyFilter(); }
    }

    onUtilsChanged: root.applyFilter()
    Component.onCompleted: root.applyFilter()

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
                            onClicked: root.utils?.loadEvents()
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

                    section.property: "day"
                    section.delegate: Item {
                        width: ListView.view.width
                        height: Style.fontSizeL + Style.margin2M
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
                                }
                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.time + (modelData.location ? "  |  " + modelData.location : "")
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                    elide: Text.ElideRight
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

                }

                NText {
                    anchors.centerIn: parent
                    text: "Načítám kalendář..."
                    visible: root.loading
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    text: "Žádné schůzky na nejbližší týden"
                    visible: (root.utils?.available ?? false) && !root.loading && root.eventsList.length === 0
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    width: parent.width - Style.margin2L
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Kalendář není dostupný.\nZkontroluj, že máš v GNOME Online Accounts Google účet se zapnutým kalendářem." + (root.utils?.lastError ? "\n\n" + root.utils.lastError : "")
                    visible: !root.loading && !(root.utils?.available ?? false)
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
