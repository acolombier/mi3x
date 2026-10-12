import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Mixxx 1.0 as Mixxx
import ".." as Skin
import "." as SettingComponents
import "../Theme"

Category {
    id: root

    property bool dirty: false
    property var profiles: []

    // Currently edited profile; identified by its stable uid (not object
    // identity), mirrors root.selectedController from Controller.qml. The
    // Repeater model collapses to only the selected profile while one is
    // focused.
    readonly property var selectedProfile: profiles.find(profile => profile.uid === root.selectedProfileId) ?? null
    property string selectedProfileId: ""

    function addProfile() {
        let role = 1;
        const names = profiles.map(profile => profile.name);
        while (names.indexOf(`Broadcast profile ${role}`) != -1) {
            role++;
        }
        const profile = makeDefaultProfile();
        profile.uid = root.nextUid();
        profile.name = `Broadcast profile ${role}`;
        root.profiles = profiles.concat([profile]);
        root.dirty = true;
        root.selectedProfileId = profile.uid;
        console.log("[Broadcast] addProfile:", profile.uid, profile.name); // TEMP probe
    }
    function load() {
        const profile = root.makeDefaultProfile();
        profile.uid = "1";
        root.profiles = [profile];
        root.dirty = false;
        root.selectedProfileId = "";
        errorMessage.text = "";
    }

    // TODO(XXX): mock backend. While no broadcast QML proxy is available
    // (e.g. a QmlBroadcastManagerProxy), profiles are kept in memory.
    // The C++ BroadcastSettingsModel / broadcastprofile classes will back
    // this later; keep the load()/save() contract when wiring them.
    function makeDefaultProfile() {
        return {
            name: "Broadcast profile 1",
            enabled: false,
            status: "DISCONNECTED",
            serverType: "Icecast 2",
            host: "",
            port: 8000,
            mount: "",
            login: "source",
            password: "",
            passwordInKeychain: "off",
            reconnect: "on",
            reconnectPeriod: 5.0,
            limitRetries: "on",
            maxRetries: 10,
            bitrate: 128,
            format: "MP3",
            channels: "Stereo",
            publicStream: "off",
            streamName: "Mixxx",
            website: "https://www.mixxx.org",
            description: "Live DJ mixing",
            genre: "Live Mix",
            irc: "",
            aim: "",
            icq: "",
            metadataFormat: "$artist - $title",
            staticMetadata: "off",
            staticArtist: "",
            staticTitle: "",
            oggDynamicUpdate: "off",
            utf8Metadata: "on"
        };
    }
    function nextUid() {
        let uid = 1;
        while (profiles.some(profile => profile.uid === String(uid))) {
            uid++;
        }
        return String(uid);
    }
    function removeSelected() {
        if (!root.selectedProfileId) {
            return;
        }
        profiles = profiles.filter(x => x.uid !== root.selectedProfileId);
        root.dirty = true;
        root.selectedProfileId = "";
    }
    function reset() {
        load();
    }
    function save() {
        console.log("Save broadcast profiles:", JSON.stringify(root.profiles));
        root.dirty = false;
        root.selectedProfileId = "";
    }
    function setProfileValue(profile, field, value) {
        if (!profile || profile[field] === value) {
            return;
        }
        profile[field] = value;
        root.dirty = true;
    }

    label: "Broadcast"

    Component.onCompleted: {
        root.load();
    }

    ScrollView {
        id: scrollView

        anchors.bottom: pageActions.top
        anchors.bottomMargin: 18
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        ColumnLayout {
            spacing: 0
            width: scrollView.width

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                columnSpacing: 24
                columns: parseInt(scrollView.width / 1000) + 1

                Repeater {
                    id: profilesRepeater

                    model: root.selectedProfileId ? [root.selectedProfileId] : profiles

                    delegate: ProfileCard {
                        id: card

                        required property var modelData

                        focused: root.selectedProfileId === modelData
                        profile: profiles.find(profile => profile.uid === modelData) ?? modelData
                        profilesCount: root.profiles.length

                        onClose: root.selectedProfileId = ""
                        onModified: root.dirty = true
                        onRemove: root.removeSelected()
                        onSelect: {
                            console.log("[Broadcast] select:", modelData); // TEMP probe
                            if (String(modelData) == root.selectedProfileId) {
                                root.selectedProfileId = null;
                            } else {
                                root.selectedProfileId = String(modelData);
                            }
                        }
                    }
                }
                // "Add profile" stand-in tile, positioned after the
                // profile cards like the unknown device rows on the
                // Controllers page.
                Rectangle {
                    id: addProfileTile

                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    color: 'transparent'
                    implicitHeight: 110
                    objectName: "addProfile"
                    visible: root.selectedProfileId === ""

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        border.color: Theme.midGray
                        border.width: 1
                        color: 'transparent'
                        radius: 22

                        Text {
                            anchors.centerIn: parent
                            color: Theme.white
                            horizontalAlignment: Text.AlignHCenter
                            text: "Add profile"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onPressed: root.addProfile()
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    visible: root.selectedProfileId === ""
                }
            }
        }
    }
    RowLayout {
        id: pageActions

        anchors.bottom: root.bottom
        anchors.bottomMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14

        Mixxx.SettingParameter {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.maximumWidth: 460
            label: "Turn on broadcasting when applying these settings"

            Text {
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                color: Theme.white
                elide: Text.ElideRight
                font.pixelSize: 14
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignLeft
                text: parent.label
                verticalAlignment: Text.AlignVCenter
            }
        }
        RatioChoice {
            inactiveColor: Theme.darkGray4
            maxWidth: 100
            objectName: "turnOnWhenApplying"
            options: ["on", "off"]
            selected: "off"

            onSelectedChanged: root.dirty = true
        }
        Item {
            Layout.fillWidth: true
        }
        Skin.FormButton {
            activeColor: "#999999"
            backgroundColor: "#7D3B3B"
            objectName: "reset"
            opacity: enabled ? 1.0 : 0.5
            text: "Reset"

            onPressed: root.reset()
        }
        Text {
            id: errorMessage

            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 16
            color: "#7D3B3B"
            objectName: "errorMessage"
            text: ""
        }
        Skin.FormButton {
            activeColor: "#999999"
            backgroundColor: "#3F3F3F"
            objectName: "cancel"
            opacity: enabled ? 1.0 : 0.5
            text: "Cancel"
            visible: root.dirty

            onPressed: root.load()
        }
        Skin.FormButton {
            activeColor: "#999999"
            backgroundColor: root.dirty ? "#3a60be" : "#3F3F3F"
            enabled: pressed || root.dirty
            objectName: "save"
            opacity: enabled ? 1.0 : 0.5
            text: "Save"

            onPressed: {
                errorMessage.text = "";
                root.save();
            }
        }
    }

    component ProfileCard: Item {
        id: cardRoot

        property bool focused
        property var profile: null
        property int profilesCount: 1
        // TODO(XXX): the status comes from the profile's connection state
        // in BroadcastManager, not from the stored configuration.
        readonly property string statusText: cardRoot.profile?.status === "ON AIR" ? "ON AIR" : "DISCONNECTED"
        readonly property string summaryText: {
            if (!cardRoot.profile?.host) {
                return "(no server configured)";
            }
            return `${cardRoot.profile.host}:${cardRoot.profile.port}${cardRoot.profile.mount} · ${cardRoot.profile.format} ${cardRoot.profile.bitrate} kbps · ${cardRoot.profile.channels}`;
        }

        signal close
        signal modified
        signal remove
        signal select

        Layout.alignment: Qt.AlignTop
        Layout.fillWidth: true
        // Mirrors ControllerCard's height accounting: header area up to
        // the settings item plus the settings item's laid-out height,
        // plus the card's 16 px vertical margins.
        Layout.preferredHeight: cardRoot.focused ? settingsItem.y + settingsItem.height + 46 : 130

        // Card names are namespaced by profile so the tree-local child
        // names (name, status, gear, settings, ...) resolve unambiguously.
        // '/' is the Spix path separator, so mirror AudioEntity and strip it.
        objectName: "profile_" + (cardRoot.profile?.name ?? "").replace("/", "")

        Component.onCompleted: {
            console.log("[Broadcast] profile card:", profile?.uid, "focused:", focused, "preferredHeight:", Layout.preferredHeight); // TEMP probe
        }

        Mixxx.SettingParameter {
            label: cardRoot.profile?.name ?? ""
        }
        Rectangle {
            id: content

            anchors.fill: parent
            anchors.margins: 8
            color: '#181818'
            radius: cardRoot.focused ? 18 : 22

            layer.effect: MultiEffect {
                shadowBlur: 0.1
                shadowColor: "#000000"
                shadowEnabled: !cardRoot.focused
            }

            // Selecting a tile folds the page down to this card and
            // unfolds its profile settings underneath the separator.
            TapHandler {
                enabled: !cardRoot.focused

                onTapped: {
                    cardRoot.select();
                }
            }
            Text {
                id: profileName

                anchors.left: content.left
                anchors.leftMargin: 22
                anchors.top: content.top
                anchors.topMargin: cardRoot.focused ? 20 : 17
                color: Theme.white
                font.pixelSize: 16
                font.weight: Font.DemiBold
                objectName: "name"
                text: cardRoot.profile?.name ?? "Unnamed profile"
                visible: !cardRoot.focused

                TapHandler {
                    cursorShape: Qt.PointingHandCursor

                    onTapped: {
                        if (!cardRoot.focused) {
                            cardRoot.select();
                        }
                    }
                }
            }
            Skin.InputField {
                anchors.left: content.left
                anchors.leftMargin: 22
                anchors.right: serverType.left
                anchors.rightMargin: 10
                anchors.verticalCenter: profileName.verticalCenter
                height: 26
                input.text: cardRoot.profile?.name ?? "New profile"
                objectName: "profileName"
                visible: cardRoot.focused

                input.onAccepted: {
                    root.setProfileValue(cardRoot.profile, "name", input.text);
                    input.focus = false;
                }
            }
            Rectangle {
                id: statusBadge

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: profileName.verticalCenter
                color: "#393939"
                implicitHeight: statusLabelText.implicitHeight + 8
                implicitWidth: statusLabelText.implicitWidth + 16
                radius: 4

                Text {
                    id: statusLabelText

                    anchors.centerIn: parent
                    color: Theme.white
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    objectName: "status"
                    text: cardRoot.statusText
                }
            }
            Text {
                id: summaryLabel

                anchors.left: content.left
                anchors.leftMargin: 22
                anchors.top: profileName.bottom
                anchors.topMargin: 8
                color: Theme.midGray
                font.pixelSize: 12
                objectName: "summary"
                text: cardRoot.summaryText
                visible: !cardRoot.focused
            }
            RatioChoice {
                id: serverType

                anchors.right: statusBadge.left
                anchors.rightMargin: 12
                anchors.verticalCenter: profileName.verticalCenter
                objectName: "serverType"
                options: ["Icecast 2", "Shoutcast 1", "Icecast 1"]
                selected: cardRoot.profile?.serverType
                visible: cardRoot.focused

                onSelectedChanged: root.setProfileValue(cardRoot.profile, "serverType", selected)
            }
            Skin.Button {
                id: enabledBtn

                anchors.bottom: content.bottom
                anchors.bottomMargin: 16
                anchors.right: gearButton.left
                anchors.rightMargin: 10
                checkable: true
                objectName: "enabled"
                text: checked ? "On" : "Off"

                Component.onCompleted: {
                    if (cardRoot.profile) {
                        checked = cardRoot.profile.enabled;
                    }
                }
                onCheckedChanged: {
                    if (cardRoot.profile) {
                        root.setProfileValue(cardRoot.profile, "enabled", checked);
                    }
                }
            }
            Skin.Button {
                id: gearButton

                activeColor: Theme.white
                anchors.bottom: content.bottom
                anchors.bottomMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 12
                checkable: true
                checked: cardRoot.focused
                icon.height: 16
                icon.source: "images/gear.svg"
                icon.width: 16
                implicitWidth: implicitHeight
                objectName: "gear"

                onPressed: {
                    cardRoot.select();
                }
            }
            Rectangle {
                id: horizontalRow

                anchors.left: content.left
                anchors.right: content.right
                anchors.top: summaryLabel.bottom
                anchors.topMargin: 15
                color: Theme.midGray
                implicitHeight: 1
                visible: cardRoot.focused
            }
            Item {
                id: settingsItem

                anchors.left: content.left
                anchors.leftMargin: 20
                anchors.right: content.right
                anchors.rightMargin: 20
                anchors.top: horizontalRow.bottom
                anchors.topMargin: 14
                clip: true
                height: cardRoot.focused ? settingsColumn.implicitHeight : 0
                objectName: "settings"
                visible: cardRoot.focused

                ColumnLayout {
                    id: settingsColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 10

                    // --- Server -------------------------------------------
                    Text {
                        color: Theme.white
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        text: "Server"
                    }
                    Mixxx.SettingGroup {
                        id: serverGroup

                        Layout.bottomMargin: 6
                        Layout.fillWidth: true
                        implicitHeight: serverPane.implicitHeight + 20
                        label: "Server"
                        objectName: "server"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            color: Qt.alpha('#676767', 0.21)
                            implicitHeight: serverPane.implicitHeight + 20

                            GridLayout {
                                id: serverPane

                                anchors.bottomMargin: 10
                                anchors.fill: parent
                                anchors.leftMargin: 17
                                anchors.rightMargin: 17
                                anchors.topMargin: 10
                                columnSpacing: 48
                                columns: serverPane.width < 900 ? 1 : 2
                                objectName: "grid"
                                rowSpacing: 15
                                uniformCellWidths: true

                                RowLayout {
                                    Mixxx.SettingParameter {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.minimumWidth: hostLabel.implicitWidth
                                        label: "Host"

                                        Text {
                                            id: hostLabel

                                            anchors.bottom: parent.bottom
                                            anchors.top: parent.top
                                            color: Theme.white
                                            elide: Text.ElideRight
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignLeft
                                            text: parent.label
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Skin.InputField {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 26
                                        input.text: cardRoot.profile?.host ?? ""
                                        objectName: "host"

                                        input.onAccepted: {
                                            root.setProfileValue(cardRoot.profile, "host", input.text);
                                            input.focus = false;
                                        }
                                    }
                                }
                                RowLayout {
                                    Mixxx.SettingParameter {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.minimumWidth: portLabel.implicitWidth
                                        label: "Port"

                                        Text {
                                            id: portLabel

                                            anchors.bottom: parent.bottom
                                            anchors.top: parent.top
                                            color: Theme.white
                                            elide: Text.ElideRight
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignLeft
                                            text: parent.label
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Skin.InputField {
                                        Layout.minimumHeight: 26
                                        Layout.preferredWidth: 120
                                        input.text: cardRoot.profile?.port ?? ""
                                        objectName: "port"

                                        input.onAccepted: {
                                            root.setProfileValue(cardRoot.profile, "port", parseInt(input.text));
                                            input.focus = false;
                                        }
                                    }
                                }
                                RowLayout {
                                    Mixxx.SettingParameter {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.minimumWidth: loginLabel.implicitWidth
                                        label: "Login"

                                        Text {
                                            id: loginLabel

                                            anchors.bottom: parent.bottom
                                            anchors.top: parent.top
                                            color: Theme.white
                                            elide: Text.ElideRight
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignLeft
                                            text: parent.label
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    Skin.InputField {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 26
                                        input.text: cardRoot.profile?.login ?? ""
                                        objectName: "login"

                                        input.onAccepted: {
                                            root.setProfileValue(cardRoot.profile, "login", input.text);
                                            input.focus = false;
                                        }
                                    }
                                }
                                RowLayout {
                                    Mixxx.SettingParameter {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.minimumWidth: passwordLabel.implicitWidth
                                        label: "Password"

                                        Text {
                                            id: passwordLabel

                                            anchors.bottom: parent.bottom
                                            anchors.top: parent.top
                                            color: Theme.white
                                            elide: Text.ElideRight
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignLeft
                                            text: parent.label
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Skin.InputField {
                                            Layout.fillWidth: true
                                            Layout.minimumHeight: 26
                                            input.echoMode: TextInput.Password
                                            input.text: cardRoot.profile?.password ?? ""
                                            objectName: "password"

                                            input.onAccepted: {
                                                root.setProfileValue(cardRoot.profile, "password", input.text);
                                                input.focus = false;
                                            }
                                        }
                                        // Small lock toggle instead of the legacy
                                        // "Plain text / OS keychain" radio pair.
                                        Skin.Button {
                                            activeColor: Theme.white
                                            checkable: true
                                            objectName: "passwordInKeychain"
                                            text: checked ? "keychain" : "plain text"

                                            Component.onCompleted: {
                                                checked = cardRoot.profile?.passwordInKeychain === "on";
                                            }
                                            onCheckedChanged: {
                                                root.setProfileValue(cardRoot.profile, "passwordInKeychain", checked ? "on" : "off");
                                            }
                                        }
                                    }
                                }
                                RowLayout {
                                    Mixxx.SettingParameter {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.minimumWidth: reconnectLabel.implicitWidth
                                        label: "Auto reconnect"

                                        Text {
                                            id: reconnectLabel

                                            anchors.bottom: parent.bottom
                                            anchors.top: parent.top
                                            color: Theme.white
                                            elide: Text.ElideRight
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignLeft
                                            text: parent.label
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    RowLayout {
                                        RatioChoice {
                                            inactiveColor: Theme.darkGray4
                                            maxWidth: reconnectPeriodBox.width + 120
                                            objectName: "reconnect"
                                            options: ["on", "off"]
                                            selected: cardRoot.profile?.reconnect ?? "on"

                                            onSelectedChanged: root.setProfileValue(cardRoot.profile, "reconnect", selected)
                                        }
                                        SettingComponents.SpinBox {
                                            id: reconnectPeriodBox

                                            enabled: cardRoot.profile?.reconnect === "on"
                                            max: 3600
                                            min: 0
                                            objectName: "reconnectPeriod"
                                            suffix: " s"

                                            // Internal SpinBox value scale is
                                            // decimalFactor-aware (decimals: 1).
                                            value: Math.round((cardRoot.profile?.reconnectPeriod ?? 5.0) * decimalFactor)

                                            onValueChanged: {
                                                root.setProfileValue(cardRoot.profile, "reconnectPeriod", value / decimalFactor);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- Stream -------------------------------------------
                    Text {
                        color: Theme.white
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        text: "Stream"
                    }
                    Mixxx.SettingGroup {
                        id: streamGroup

                        Layout.bottomMargin: 6
                        Layout.fillWidth: true
                        implicitHeight: streamPane.implicitHeight + 20
                        label: "Stream"
                        objectName: "stream"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            color: Qt.alpha('#676767', 0.21)
                            implicitHeight: streamPane.implicitHeight + 20

                            GridLayout {
                                id: streamPane

                                anchors.bottomMargin: 10
                                anchors.fill: parent
                                anchors.leftMargin: 17
                                anchors.rightMargin: 17
                                anchors.topMargin: 10
                                columnSpacing: 48
                                columns: streamPane.width < 900 ? 4 : 6
                                objectName: "grid"
                                rowSpacing: 15

                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: streamNameLabel.implicitWidth
                                    label: "Name"

                                    Text {
                                        id: streamNameLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.columnSpan: 3
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.streamName ?? ""
                                    objectName: "name"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "streamName", input.text);
                                        input.focus = false;
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: streamTypeLabel.implicitWidth
                                    label: "Type"

                                    Text {
                                        id: streamTypeLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: streamPane.width * 0.5
                                    objectName: "public"
                                    options: ["Public", "Private"]

                                    Component.onCompleted: {
                                        selected = cardRoot.profile?.publicStream === "on" ? "Public" : "Private";
                                    }
                                    onSelectedChanged: {
                                        if (selected) {
                                            root.setProfileValue(cardRoot.profile, "publicStream", selected === "Public" ? "on" : "off");
                                        }
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: streamFormatLabel.implicitWidth
                                    label: "Format"

                                    Text {
                                        id: streamFormatLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.ComboBox {
                                    Layout.alignment: Qt.AlignRight
                                    Layout.minimumWidth: 100
                                    currentIndex: model.indexOf(cardRoot.profile?.format)
                                    model: ["MP3", "Ogg Vorbis", "Opus", "AAC", "HE-AAC", "HE-AACv2"]
                                    objectName: "format"

                                    onActivated: function (index) {
                                        root.setProfileValue(cardRoot.profile, "format", currentText);
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: streamChannelsLabel.implicitWidth
                                    label: "Channels"

                                    Text {
                                        id: streamChannelsLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    Layout.alignment: Qt.AlignRight
                                    Layout.minimumWidth: 100
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: streamPane.width * 0.5
                                    objectName: "channels"
                                    options: ["Automatic", "Mono", "Stereo"]
                                    selected: cardRoot.profile?.channels

                                    onSelectedChanged: {
                                        root.setProfileValue(cardRoot.profile, "channels", selected);
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: streamBitrateLabel.implicitWidth
                                    label: "Bitrate"

                                    Text {
                                        id: streamBitrateLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.ComboBox {
                                    Layout.alignment: Qt.AlignRight
                                    Layout.minimumWidth: 100
                                    currentIndex: model.indexOf(cardRoot.profile?.bitrate)
                                    model: [320, 256, 224, 192, 160, 128, 112, 96, 80, 64, 48, 32]
                                    objectName: "bitrate"

                                    onActivated: function (index) {
                                        root.setProfileValue(cardRoot.profile, "bitrate", parseInt(currentText));
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: mountLabel.implicitWidth
                                    label: "Mount"

                                    Text {
                                        id: mountLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.columnSpan: 3
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.mount ?? ""
                                    objectName: "mount"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "mount", input.text);
                                        input.focus = false;
                                    }
                                }
                            }
                        }
                    }

                    // --- Properties ---------------------------------------
                    Text {
                        color: Theme.white
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        text: "Properties"
                    }
                    Mixxx.SettingGroup {
                        id: propertiesGroup

                        Layout.bottomMargin: 6
                        Layout.fillWidth: true
                        implicitHeight: propertiesPane.implicitHeight + 20
                        label: "Properties"
                        objectName: "properties"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            color: Qt.alpha('#676767', 0.21)
                            implicitHeight: propertiesPane.implicitHeight + 20

                            GridLayout {
                                id: propertiesPane

                                anchors.bottomMargin: 10
                                anchors.fill: parent
                                anchors.leftMargin: 17
                                anchors.rightMargin: 17
                                anchors.topMargin: 10
                                columnSpacing: 48
                                columns: propertiesPane.width < 900 ? 2 : 4
                                objectName: "grid"
                                rowSpacing: 15

                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: websiteLabel.implicitWidth
                                    label: "Website"

                                    Text {
                                        id: websiteLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.website ?? ""
                                    objectName: "website"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "website", input.text);
                                        input.focus = false;
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: descriptionLabel.implicitWidth
                                    label: "Description"

                                    Text {
                                        id: descriptionLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.description ?? ""
                                    objectName: "description"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "description", input.text);
                                        input.focus = false;
                                    }
                                }
                                // IRC / AIM / ICQ are legacy metadata
                                // fields; they are collapsed behind a
                                // disclosure by default.
                                // Skin.FormButton {
                                //     id: moreStreamInfo

                                //     activeColor: "#999999"
                                //     backgroundColor: "#3F3F3F"
                                //     checkable: true
                                //     objectName: "broadcastMoreStreamInfo"
                                //     text: checked ? "Less..." : "More..."
                                // }

                                // Mixxx.SettingParameter {
                                //     visible: moreStreamInfo.checked
                                //     Layout.alignment: Qt.AlignVCenter
                                //     Layout.minimumWidth: ircLabel.implicitWidth
                                //     label: "IRC"

                                //     Text {
                                //         id: ircLabel

                                //         anchors.bottom: parent.bottom
                                //         anchors.top: parent.top
                                //         color: Theme.white
                                //         elide: Text.ElideRight
                                //         font.pixelSize: 14
                                //         font.weight: Font.Medium
                                //         horizontalAlignment: Text.AlignLeft
                                //         text: parent.label
                                //         verticalAlignment: Text.AlignVCenter
                                //     }
                                // }
                                // Skin.InputField {
                                //     visible: moreStreamInfo.checked
                                //     Layout.minimumHeight: 26
                                //     input.text: cardRoot.profile?.irc ?? ""
                                //     objectName: "broadcastIrc"

                                //     input.onAccepted: {
                                //         root.setProfileValue(cardRoot.profile, "irc", input.text);
                                //         input.focus = false;
                                //     }
                                // }
                                // Mixxx.SettingParameter {
                                //     visible: moreStreamInfo.checked
                                //     label: "AIM"

                                //     Text {
                                //         anchors.bottom: parent.bottom
                                //         anchors.top: parent.top
                                //         color: Theme.white
                                //         font.pixelSize: 14
                                //         font.weight: Font.Medium
                                //         horizontalAlignment: Text.AlignHCenter
                                //         text: parent.label
                                //         verticalAlignment: Text.AlignVCenter
                                //     }
                                // }
                                // Skin.InputField {
                                //     visible: moreStreamInfo.checked
                                //     Layout.minimumHeight: 26
                                //     input.text: cardRoot.profile?.aim ?? ""
                                //     objectName: "broadcastAim"

                                //     input.onAccepted: {
                                //         root.setProfileValue(cardRoot.profile, "aim", input.text);
                                //         input.focus = false;
                                //     }
                                // }
                                // Mixxx.SettingParameter {
                                //     label: "ICQ"

                                //     Text {
                                //         anchors.bottom: parent.bottom
                                //         anchors.top: parent.top
                                //         color: Theme.white
                                //         font.pixelSize: 14
                                //         font.weight: Font.Medium
                                //         horizontalAlignment: Text.AlignHCenter
                                //         text: parent.label
                                //         verticalAlignment: Text.AlignVCenter
                                //     }
                                // }
                                // Skin.InputField {
                                //     Layout.minimumHeight: 26
                                //     input.text: cardRoot.profile?.icq ?? ""
                                //     objectName: "broadcastIcq"

                                //     input.onAccepted: {
                                //         root.setProfileValue(cardRoot.profile, "icq", input.text);
                                //         input.focus = false;
                                //     }
                                // }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: metadataFormatLabel.implicitWidth
                                    label: "Format"

                                    Text {
                                        id: metadataFormatLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.metadataFormat ?? ""
                                    objectName: "metadataFormat"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "metadataFormat", input.text);
                                        input.focus = false;
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: genreLabel.implicitWidth
                                    label: "Genre"

                                    Text {
                                        id: genreLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.genre ?? ""
                                    objectName: "genre"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "genre", input.text);
                                        input.focus = false;
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: oggDynamicUpdateLabel.implicitWidth
                                    label: "Dynamically update metadata"

                                    Text {
                                        id: oggDynamicUpdateLabel

                                        ToolTip.text: "Only available when the encoding format is Ogg Vorbis"
                                        ToolTip.visible: oggDynamicUpdateHoverHandler.hovered
                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        enabled: cardRoot.profile?.format === "Ogg Vorbis"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter

                                        HoverHandler {
                                            id: oggDynamicUpdateHoverHandler

                                            enabled: cardRoot.profile?.format !== "Ogg Vorbis"
                                        }
                                    }
                                }
                                RatioChoice {
                                    Layout.alignment: Qt.AlignRight
                                    enabled: cardRoot.profile?.format === "Ogg Vorbis"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: propertiesPane.width * 0.5
                                    objectName: "oggDynamicUpdate"
                                    options: ["on", "off"]
                                    // selected: cardRoot.profile?.staticMetadata ?? "off"

                                    // onSelectedChanged: root.setProfileValue(cardRoot.profile, "staticMetadata", selected)
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: utf8MetadataLabel.implicitWidth
                                    label: "Use UTF-8"

                                    Text {
                                        id: utf8MetadataLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    Layout.alignment: Qt.AlignRight
                                    enabled: cardRoot.profile?.format === "Ogg Vorbis"
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: propertiesPane.width * 0.5
                                    objectName: "utf8Metadata"
                                    options: ["on", "off"]
                                    // selected: cardRoot.profile?.staticMetadata ?? "off"

                                    // onSelectedChanged: root.setProfileValue(cardRoot.profile, "staticMetadata", selected)
                                }
                                Mixxx.SettingParameter {
                                    Layout.minimumWidth: staticMetadataLabel.implicitWidth
                                    label: "Use static metadata"

                                    Text {
                                        id: staticMetadataLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RatioChoice {
                                    id: broadcastStaticMetadata

                                    Layout.alignment: Qt.AlignRight
                                    inactiveColor: Theme.darkGray4
                                    maxWidth: propertiesPane.width * 0.5
                                    objectName: "metadata"
                                    options: ["on", "off"]
                                    selected: cardRoot.profile?.staticMetadata ?? "off"

                                    onSelectedChanged: root.setProfileValue(cardRoot.profile, "staticMetadata", selected)
                                }
                                Item {
                                    Layout.columnSpan: 2
                                    visible: parent.columns == 4
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: staticArtistLabel.implicitWidth
                                    label: "Static artist"
                                    visible: broadcastStaticMetadata.selected === "on"

                                    Text {
                                        id: staticArtistLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.staticArtist ?? ""
                                    objectName: "artist"
                                    visible: broadcastStaticMetadata.selected === "on"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "staticArtist", input.text);
                                        input.focus = false;
                                    }
                                }
                                Mixxx.SettingParameter {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.minimumWidth: staticTitleLabel.implicitWidth
                                    label: "Static title"
                                    visible: broadcastStaticMetadata.selected === "on"

                                    Text {
                                        id: staticTitleLabel

                                        anchors.bottom: parent.bottom
                                        anchors.top: parent.top
                                        color: Theme.white
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignLeft
                                        text: parent.label
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                Skin.InputField {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 26
                                    input.text: cardRoot.profile?.staticTitle ?? ""
                                    objectName: "title"
                                    visible: broadcastStaticMetadata.selected === "on"

                                    input.onAccepted: {
                                        root.setProfileValue(cardRoot.profile, "staticTitle", input.text);
                                        input.focus = false;
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Skin.FormButton {
                            Layout.alignment: Qt.AlignRight
                            activeColor: "#999999"
                            backgroundColor: "#7D3B3B"
                            objectName: "remove"
                            text: "Remove profile"

                            onPressed: cardRoot.remove()
                        }
                    }
                }
            }
        }
    }
}
