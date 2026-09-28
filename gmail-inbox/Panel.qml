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

    property int currentTab: 0
    readonly property var currentAccount: accounts.length > 0 ? accounts[Math.min(currentTab, accounts.length - 1)] : null
    readonly property var listModel: {
        if (!currentAccount)
            return [];
        var email = currentAccount.email;
        return currentAccount.messages.map(function (m) { return Object.assign({ "email": email }, m); });
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

            NTabBar {
                id: tabBar
                Layout.fillWidth: true
                visible: root.accounts.length > 1
                distributeEvenly: true
                currentIndex: root.currentTab
                onCurrentIndexChanged: root.currentTab = currentIndex

                Repeater {
                    model: root.accounts
                    NTabButton {
                        text: root.mainInstance.accountLabel(modelData.email) + (modelData.error ? " (!)" : " (" + modelData.count + ")")
                        tooltipText: modelData.email
                        tabIndex: index
                        checked: tabBar.currentIndex === index
                        onClicked: tabBar.currentIndex = index
                    }
                }
            }

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    id: accountRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Style.marginM
                    visible: root.currentAccount !== null

                    NText {
                        Layout.fillWidth: true
                        text: root.currentAccount ? root.currentAccount.email : ""
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        elide: Text.ElideRight
                    }
                    NIconButton {
                        icon: "external-link"
                        tooltipText: "Otevřít schránku v Gmailu"
                        onClicked: root.openUrl("https://mail.google.com/mail/u/" + root.currentAccount.email + "/")
                    }
                }

                NListView {
                    id: listView
                    anchors.top: accountRow.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.marginS
                    anchors.bottomMargin: Style.marginXXL
                    clip: true
                    model: root.listModel
                    spacing: Style.marginM
                    visible: !root.loading && root.listModel.length > 0

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
                    text: root.currentAccount?.error ? "Chyba účtu: " + root.currentAccount.error : (root.mainInstance?.error || "Žádné nepřečtené e-maily 🎉")
                    visible: !root.loading && root.listModel.length === 0
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }
}
