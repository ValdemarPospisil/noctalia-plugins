import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property real contentPreferredHeight: 700 * Style.uiScaleRatio
    property real contentPreferredWidth: 520 * Style.uiScaleRatio

    readonly property var geometryPlaceholder: panelContainer

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var accounts: mainInstance?.accounts || []
    readonly property bool loading: (mainInstance?.loading ?? true) && accounts.length === 0

    // Flat list with an "account" key so NListView can group by it
    readonly property var listModel: {
        var list = [];
        for (var i = 0; i < accounts.length; i++) {
            var acc = accounts[i];
            var header = acc.email + (acc.error ? "  (chyba)" : "  (" + acc.count + ")");
            for (var j = 0; j < acc.messages.length; j++)
                list.push(Object.assign({ "account": header, "email": acc.email }, acc.messages[j]));
        }
        return list;
    }

    function relativeTime(ts) {
        var minutes = Math.floor((Date.now() / 1000 - ts) / 60);
        if (minutes < 1)
            return "teď";
        if (minutes < 60)
            return "před " + minutes + " min";
        if (minutes < 1440)
            return "před " + Math.floor(minutes / 60) + " h";
        var d = new Date(ts * 1000);
        return d.getDate() + ". " + (d.getMonth() + 1) + ".";
    }

    function openUrl(url) {
        Qt.openUrlExternally(url);
        pluginApi?.closePanel(pluginApi?.panelOpenScreen);
    }

    anchors.fill: parent

    Component.onCompleted: mainInstance?.refresh()

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
                        icon: "mail"
                        pointSize: Style.fontSizeXXL
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        NText {
                            Layout.fillWidth: true
                            color: Color.mOnSurface
                            font.weight: Style.fontWeightBold
                            pointSize: Style.fontSizeL
                            text: "Nepřečtené e-maily"
                        }
                    }
                    NIconButton {
                        icon: "refresh"
                        tooltipText: "Obnovit"
                        onClicked: root.mainInstance?.refresh()
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
                    id: listView
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    anchors.bottomMargin: Style.marginXXL
                    clip: true
                    model: root.listModel
                    spacing: Style.marginM
                    visible: !root.loading && root.listModel.length > 0

                    section.property: "account"
                    section.delegate: RowLayout {
                        width: ListView.view.width
                        NText {
                            Layout.fillWidth: true
                            text: section
                            font.weight: Font.Bold
                            color: Color.mPrimary
                            pointSize: Style.fontSizeM
                            elide: Text.ElideRight
                        }
                        NIconButton {
                            icon: "external-link"
                            tooltipText: "Otevřít schránku v Gmailu"
                            onClicked: root.openUrl("https://mail.google.com/mail/u/" + section.split("  ")[0] + "/")
                        }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: delegateLayout.implicitHeight + Style.margin2M
                        radius: Style.radiusM
                        color: rowMouse.containsMouse ? Color.mHover : Color.mSurface

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openUrl(modelData.url)
                        }

                        RowLayout {
                            id: delegateLayout
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginM

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginXXS

                                RowLayout {
                                    Layout.fillWidth: true
                                    NText {
                                        Layout.fillWidth: true
                                        text: modelData.from
                                        font.weight: Font.Bold
                                        pointSize: Style.fontSizeM
                                        color: Color.mOnSurface
                                        elide: Text.ElideRight
                                    }
                                    NText {
                                        text: root.relativeTime(modelData.date)
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnSurfaceVariant
                                    }
                                }
                                NText {
                                    Layout.fillWidth: true
                                    text: modelData.subject
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            NIconButton {
                                icon: "mail-check"
                                tooltipText: "Označit jako přečtené"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: root.mainInstance?.markRead(modelData.email, modelData.uid)
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }

                NText {
                    anchors.centerIn: parent
                    text: "Načítám e-maily..."
                    visible: root.loading
                    color: Color.mOnSurfaceVariant
                }

                NText {
                    anchors.centerIn: parent
                    width: parent.width - Style.margin2L
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.mainInstance?.error || "Žádné nepřečtené e-maily 🎉"
                    visible: !root.loading && root.listModel.length === 0
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
