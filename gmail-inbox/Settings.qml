import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property var accounts: pluginApi?.mainInstance?.accounts || []

    property int editRefreshInterval: pluginApi?.pluginSettings?.refreshInterval || defaults.refreshInterval || 60
    property bool editNotifications: pluginApi?.pluginSettings?.notifications ?? defaults.notifications ?? true
    property string editDefaultQuery: pluginApi?.pluginSettings?.defaultQuery || defaults.defaultQuery || ""
    property var editAccountQueries: Object.assign({}, pluginApi?.pluginSettings?.accountQueries || {})

    spacing: Style.marginL

    NToggle {
        Layout.fillWidth: true
        label: "Notifikace"
        description: "Upozornit na nový e-mail"
        checked: root.editNotifications
        onToggled: checked => root.editNotifications = checked
    }

    NSpinBox {
        Layout.fillWidth: true
        label: "Interval kontroly"
        description: "Jak často se ptát Gmailu na nové e-maily"
        from: 30
        to: 3600
        stepSize: 30
        suffix: " s"
        value: root.editRefreshInterval
        onValueChanged: root.editRefreshInterval = value
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Výchozí vyhledávání"
        description: "Gmail dotaz pro účty bez vlastního nastavení"
        placeholderText: "is:unread in:inbox newer_than:7d"
        text: root.editDefaultQuery
        onTextChanged: root.editDefaultQuery = text
    }

    NLabel {
        label: "Vyhledávání podle účtu"
        description: "Např. \"is:unread category:primary\" pro jen hlavní kartu. Prázdné = výchozí."
    }

    Repeater {
        model: root.accounts

        NTextInput {
            Layout.fillWidth: true
            label: modelData.email
            placeholderText: root.editDefaultQuery
            text: root.editAccountQueries[modelData.email] || ""
            onTextChanged: {
                var queries = root.editAccountQueries;
                if (text.trim() === "")
                    delete queries[modelData.email];
                else
                    queries[modelData.email] = text.trim();
                root.editAccountQueries = queries;
            }
        }
    }

    function saveSettings() {
        if (!pluginApi)
            return;
        pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval;
        pluginApi.pluginSettings.notifications = root.editNotifications;
        pluginApi.pluginSettings.defaultQuery = root.editDefaultQuery;
        pluginApi.pluginSettings.accountQueries = root.editAccountQueries;
        pluginApi.saveSettings();
        pluginApi.mainInstance?.refresh();
    }
}
