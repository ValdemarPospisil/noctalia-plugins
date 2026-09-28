import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import qs.Widgets
import "CalendarUtils.js" as CalendarUtils

Item {
    id: root

    property var pluginApi: null
    property real contentPreferredHeight: 500 * Style.uiScaleRatio
    property real contentPreferredWidth: 440 * Style.uiScaleRatio

    readonly property var geometryPlaceholder: panelContainer

    property var eventsList: []
    property bool loading: CalendarService.loading && CalendarService.events.length === 0

    function applyFilter() {
        var showAllDay = pluginApi?.pluginSettings?.showAllDayEvents || false;
        var events = CalendarUtils.upcoming(CalendarService.events, 7, showAllDay);
        var list = [];
        for (var i = 0; i < events.length; i++) {
            var ev = events[i];
            var allDay = CalendarUtils.isAllDay(ev);
            list.push({
                "day": CalendarUtils.formatDay(ev.start),
                "time": allDay ? "Celý den" : CalendarUtils.formatTime(ev.start) + " – " + CalendarUtils.formatTime(ev.end),
                "title": ev.summary,
                "location": ev.location || "",
                "calendar": ev.calendar || "",
                "id": CalendarUtils.eventId(ev)
            });
        }
        root.eventsList = list;
    }

    anchors.fill: parent

    Connections {
        target: CalendarService
        function onEventsChanged() { root.applyFilter(); }
    }

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
                            onClicked: CalendarService.loadEvents()
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

                    ScrollBar.vertical: ScrollBar {}
                }

                NText {
                    anchors.centerIn: parent
                    text: "Načítám kalendář..."
                    visible: root.loading && CalendarService.available
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    text: "Žádné schůzky na nejbližší týden"
                    visible: CalendarService.available && !root.loading && root.eventsList.length === 0
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    width: parent.width - Style.margin2L
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Kalendář není dostupný.\nNainstaluj evolution-data-server a přidej Google účet v GNOME Online Accounts." + (CalendarService.lastError ? "\n\n" + CalendarService.lastError : "")
                    visible: !CalendarService.available
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
