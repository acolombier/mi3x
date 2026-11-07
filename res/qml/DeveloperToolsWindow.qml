import "." as Skin
import Mixxx 1.0 as Mixxx
import QtQml.Models // DelegateChoice for Qt >= 6.9
import Qt.labs.qmlmodels // DelegateChooser
import QtQuick 2.12
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.12
import QtQuick.Window 2.12
import "Theme"

Window {
    id: root

    color: Theme.toolbarBackgroundColor
    title: "Developer Tools"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5

        Skin.TextField {
            id: searchField

            Layout.fillWidth: true
            focus: true
            placeholderText: "Search Term..."

            onTextChanged: controlModel.setFilterFixedString(text)
        }

        // FIXME: Header items currently get squeezed when the table is empty
        // (i.e. if a non-existing search term was entered).
        HorizontalHeaderView {
            id: horizontalHeader

            Layout.fillWidth: true
            syncView: tableView

            delegate: Item {
                id: headerDlgt

                required property int column
                required property string display

                implicitHeight: columnName.contentHeight + 5
                implicitWidth: columnName.contentWidth + 5
                visible: this.column < tableView.columnWidths.length

                BorderImage {
                    anchors.fill: parent
                    horizontalTileMode: BorderImage.Stretch
                    source: Theme.imgPopupBackground
                    verticalTileMode: BorderImage.Stretch

                    border {
                        bottom: 10
                        left: 20
                        right: 20
                        top: 10
                    }
                }
                Text {
                    id: columnName

                    anchors.fill: parent
                    anchors.margins: 5
                    color: Theme.buttonNormalColor
                    elide: Text.ElideRight
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.buttonFontPixelSize
                    horizontalAlignment: Text.AlignHCenter
                    text: headerDlgt.display
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    id: sortIndicator

                    anchors.fill: parent
                    anchors.margins: 5
                    color: Theme.buttonNormalColor
                    elide: Text.ElideRight
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.buttonFontPixelSize
                    horizontalAlignment: Text.AlignRight
                    text: controlModel.sortDescending ? "▲" : "▼"
                    verticalAlignment: Text.AlignVCenter
                    visible: controlModel.sortColumn == headerDlgt.column
                }
                TapHandler {
                    onTapped: controlModel.toggleSortColumn(headerDlgt.column)
                }
            }
        }
        TableView {
            id: tableView

            property var columnWidths: [0.2, 0.3, 0.15, 0.1]

            Layout.fillHeight: true
            Layout.fillWidth: true
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            columnSpacing: 1
            rowHeightProvider: _ => 24
            rowSpacing: 1

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOn
            }
            delegate: DelegateChooser {
                DelegateChoice {
                    column: 0

                    delegate: Rectangle {
                        id: groupDelegate

                        required property int column
                        required property string display

                        color: root.color
                        implicitHeight: groupName.contentHeight
                        implicitWidth: (root.width - 10) * tableView.columnWidths[groupDelegate.column]

                        Text {
                            id: groupName

                            anchors.fill: parent
                            color: Theme.deckTextColor
                            elide: Text.ElideRight
                            text: groupDelegate.display
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                DelegateChoice {
                    column: 1

                    delegate: Rectangle {
                        id: keyDelegate

                        required property int column
                        required property string display

                        color: root.color
                        implicitHeight: keyName.contentHeight
                        implicitWidth: (root.width - 10) * tableView.columnWidths[keyDelegate.column]

                        Text {
                            id: keyName

                            anchors.fill: parent
                            color: Theme.deckTextColor
                            elide: Text.ElideRight
                            text: keyDelegate.display
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                DelegateChoice {
                    column: 2

                    delegate: RowLayout {
                        id: valueDelegate

                        required property int column
                        required property string display
                        required property int row

                        implicitWidth: (root.width - 10) * tableView.columnWidths[valueDelegate.column]
                        spacing: 0

                        // color: root.color

                        Skin.TextField {
                            id: valueField

                            Layout.fillWidth: true
                            color: Theme.textColor
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            text: valueDelegate.display

                            background: Rectangle {
                                anchors.fill: parent
                                color: Theme.embeddedBackgroundColor
                                radius: 5
                            }
                            validator: DoubleValidator {
                            }

                            onEditingFinished: {
                                const idx = controlModel.index(valueDelegate.row, valueDelegate.column);
                                controlModel.setData(idx, parseFloat(text));
                            }
                        }
                        Skin.Button {
                            text: "Trigger"

                            onPressed: {
                                const idx = controlModel.index(valueDelegate.row, valueDelegate.column);
                                controlModel.setData(idx, !parseFloat(valueDelegate.display) ? 1.0 : 0.0);
                            }
                        }
                        Skin.Button {
                            checkable: true
                            checked: !!parseFloat(valueDelegate.display)
                            text: "Toggle"

                            onPressed: {
                                const idx = controlModel.index(valueDelegate.row, valueDelegate.column);
                                controlModel.setData(idx, !checked ? 1.0 : 0.0);
                            }
                        }
                    }
                }
                DelegateChoice {
                    column: 3

                    delegate: Rectangle {
                        id: parameterDelegate

                        required property int column
                        required property string display
                        required property int row

                        color: root.color
                        implicitHeight: 20
                        implicitWidth: (root.width - 10) * tableView.columnWidths[parameterDelegate.column]

                        Skin.TextField {
                            id: valueField

                            anchors.fill: parent
                            color: Theme.textColor
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            text: parameterDelegate.display

                            background: Rectangle {
                                anchors.fill: parent
                                color: Theme.embeddedBackgroundColor
                                radius: 5
                            }
                            validator: DoubleValidator {
                            }

                            onEditingFinished: {
                                const idx = controlModel.index(parameterDelegate.row, parameterDelegate.column);
                                controlModel.setData(idx, parseFloat(text));
                            }
                        }
                    }
                }
            }
            model: Mixxx.ControlSortFilterModel {
                id: controlModel

                function toggleSortColumn(column) {
                    const descending = (sortColumn == column) ? !sortDescending : false;
                    sortByColumn(column, descending);
                }

                Component.onCompleted: {
                    // First order by key, then by group.
                    sortByColumn(1, false);
                    sortByColumn(0, false);
                }
            }

            onWidthChanged: forceLayout()
        }
    }
}
