import QtQuick 2.2
import QtQuick.Controls 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import "../../code/config-utils.js" as ConfigUtils
import "../../code/model-utils.js" as ModelUtils

Item {
    id: resourcesConfigPage
    
    property double tableWidth: 550

    property string cfg_resources
    property alias cfg_warningTemperature: warningTemperatureSpinBox.value
    property alias cfg_meltdownTemperature: meltdownTemperatureSpinBox.value
    
    property var preparedSystemMonitorSources: []
    
    ListModel {
        id: resourcesModel
    }
    
    ListModel {
        id: comboboxModel
    }
    
    ListModel {
        id: checkboxesSourcesModel
    }
    
    Component.onCompleted: {
        
        systemmonitorDS.sources.forEach(function (source) {
            
            if ((source.indexOf('lmsensors/') === 0 || source.indexOf('acpi/Thermal_Zone/') === 0)
                && !source.match(/\/fan[0-9]*$/) ) {
                
                comboboxModel.append({
                    text: source,
                    val: source
                })
                
                print('source to combo: ' + source)
            }
        })
        
        var resources = ConfigUtils.getResourcesObjectArray()
        resources.forEach(function (resourceObj) {
            resourcesModel.append(resourceObj)
        })
    }
    
    function reloadComboboxModel(temperatureObj) {
        
        temperatureObj = temperatureObj || {}
        var childSourceObjects = temperatureObj.childSourceObjects || {}
        var childSourceObjectsEmpty = !temperatureObj.childSourceObjects
        
        checkboxesSourcesModel.clear()
        sourceCombo.currentIndex = 0
        
        print('sourceName to select: ' + temperatureObj.sourceName)
        
        if (temperatureObj.sourceName === 'virtual-group') {
            addResourceDialog.sourceTypeSwitch = 1
        } else {
            addResourceDialog.sourceTypeSwitch = 0
        }
        addResourceDialog.setVirtualSelected()
        
        for (var i = 0; i < comboboxModel.count; i++) {
            var source = comboboxModel.get(i).val
            
            if (source === temperatureObj.sourceName) {
                sourceCombo.currentIndex = i
            }
            
            checkboxesSourcesModel.append({
                text: source,
                val: source,
                checkboxChecked: childSourceObjectsEmpty || (source in childSourceObjects)
            })
        }
        
    }
    
    function resourcesModelChanged() {
        var newResourcesArray = []
        for (var i = 0; i < resourcesModel.count; i++) {
            var obj = resourcesModel.get(i)
            newResourcesArray.push({
                sourceName: obj.sourceName,
                alias: obj.alias,
                overrideLimitTemperatures: obj.overrideLimitTemperatures,
                warningTemperature: obj.warningTemperature,
                meltdownTemperature: obj.meltdownTemperature,
                virtual: obj.virtual,
                childSourceObjects: obj.childSourceObjects
            })
        }
        cfg_resources = JSON.stringify(newResourcesArray)
        print('resources: ' + cfg_resources)
    }
    
    
    function fillAddResourceDialogAndOpen(temperatureObj, editResourceIndex) {
        
        // set dialog title
        addResourceDialog.addResource = temperatureObj === null
        addResourceDialog.editResourceIndex = editResourceIndex
        
        temperatureObj = temperatureObj || {
            alias: '',
            overrideLimitTemperatures: false,
            meltdownTemperature: 90,
            warningTemperature: 70
        }
        
        // set combobox
        reloadComboboxModel(temperatureObj)
        
        // alias
        aliasTextfield.text = temperatureObj.alias
        
        // temperature overrides
        overrideLimitTemperatures.checked = temperatureObj.overrideLimitTemperatures
        warningTemperatureItem.value = temperatureObj.warningTemperature
        meltdownTemperatureItem.value = temperatureObj.meltdownTemperature
        
        // open dialog
        addResourceDialog.open()
        
    }
    
    
    Dialog {
        id: addResourceDialog
        
        property bool addResource: true
        property int editResourceIndex: -1
        
        title: addResource ? 'Add Resource' : 'Edit Resource'
        
        width: tableWidth
        
        property int tableIndex: 0
        property double fieldHeight: addResourceDialog.height / 5 - 3
        
        property bool virtualSelected: true
        
        standardButtons: StandardButton.Ok | StandardButton.Cancel
        
        property int sourceTypeSwitch: 0
            
        ExclusiveGroup {
            id: sourceTypeGroup
        }
        
        onSourceTypeSwitchChanged: {
            switch (sourceTypeSwitch) {
            case 0:
                sourceTypeGroup.current = singleSourceTypeRadio;
                break;
            case 1:
                sourceTypeGroup.current = multipleSourceTypeRadio;
                break;
            default:
            }
            setVirtualSelected()
        }
        
        function setVirtualSelected() {
            virtualSelected = sourceTypeSwitch === 1
            print('SET VIRTUAL SELECTED: ' + virtualSelected)
        }
        
        onAccepted: {
            if (!aliasTextfield.text) {
                aliasTextfield.text = '<UNKNOWN>'
            }
            
            var childSourceObjects = {}
            for (var i = 0; i < checkboxesSourcesModel.count; i++) {
                if (checkboxesSourcesListView.children[0].children[i].checked === true) {
                    var sourceName = checkboxesSourcesModel.get(i).val
                    print ('adding source to group: ' + sourceName)
                    childSourceObjects[checkboxesSourcesModel.get(i).val] = {
                        temperature: 0
                    }
                }
            }
            
            var newObject = {
                sourceName: virtualSelected ? 'virtual-group' : comboboxModel.get(sourceCombo.currentIndex).val,
                alias: aliasTextfield.text,
                overrideLimitTemperatures: overrideLimitTemperatures.checked,
                warningTemperature: warningTemperatureItem.value,
                meltdownTemperature: meltdownTemperatureItem.value,
                virtual: virtualSelected,
                childSourceObjects: childSourceObjects
            }
            
            if (addResourceDialog.addResource) {
                resourcesModel.append(newObject)
            } else {
                resourcesModel.set(addResourceDialog.editResourceIndex, newObject)
            }
            
            
            resourcesModelChanged()
            addResourceDialog.close()
        }
        
        GridLayout {
            columns: 2
            
            RadioButton {
                id: singleSourceTypeRadio
                exclusiveGroup: sourceTypeGroup
                text: i18n("Source")
                onCheckedChanged: {
                    if (checked) {
                        addResourceDialog.sourceTypeSwitch = 0
                    }
                    addResourceDialog.setVirtualSelected()
                }
                checked: true
            }
            ComboBox {
                id: sourceCombo
                Layout.preferredWidth: tableWidth/2
                model: comboboxModel
                enabled: !addResourceDialog.virtualSelected
            }
            
            RadioButton {
                id: multipleSourceTypeRadio
                exclusiveGroup: sourceTypeGroup
                text: i18n("Group of sources")
                onCheckedChanged: {
                    if (checked) {
                        addResourceDialog.sourceTypeSwitch = 1
                    }
                    addResourceDialog.setVirtualSelected()
                }
                Layout.alignment: Qt.AlignTop
            }
            ListView {
                id: checkboxesSourcesListView
                model: checkboxesSourcesModel
                delegate: CheckBox {
                    text: val
                    checked: checkboxChecked
                }
                enabled: addResourceDialog.virtualSelected
                Layout.preferredWidth: tableWidth/2
                Layout.preferredHeight: (theme.defaultFont.pointSize * 2) * checkboxesSourcesModel.count + 5
            }
            
            Item {
                Layout.columnSpan: 2
                width: 2
                height: 5
            }
            
            Label {
                text: i18n("NOTE: Group of sources shows the highest temperature of chosen sources.")
                Layout.columnSpan: 2
                enabled: addResourceDialog.virtualSelected
            }
            
            Item {
                Layout.columnSpan: 2
                width: 2
                height: 10
            }
            
            Label {
                text: i18n('Alias:')
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                id: aliasTextfield
                Layout.preferredWidth: tableWidth/2
            }
            
            Item {
                Layout.columnSpan: 2
                width: 2
                height: 10
            }
            
            CheckBox {
                id: overrideLimitTemperatures
                text: i18n("Override limit temperatures")
                Layout.columnSpan: 2
                checked: false
            }
            
            Label {
                text: i18n('Warning temperature:')
                Layout.alignment: Qt.AlignRight
            }
            SpinBox {
                id: warningTemperatureItem
                stepSize: 10
                minimumValue: 10
                enabled: overrideLimitTemperatures.checked
            }
            
            Label {
                text: i18n('Meltdown temperature:')
                Layout.alignment: Qt.AlignRight
            }
            SpinBox {
                id: meltdownTemperatureItem
                stepSize: 10
                minimumValue: 10
                enabled: overrideLimitTemperatures.checked
            }
            
        }
    }
    
    GridLayout {
        columns: 2
        
        Label {
            text: i18n('Resources')
            font.bold: true
            Layout.alignment: Qt.AlignLeft
        }
        
        Item {
            width: 2
            height: 2
        }
        
        TableView {
            
            headerVisible: true
            
            Text {
                text: i18n('Add resources by clicking "+" button.')
                color: theme.textColor
                anchors.centerIn: parent
                visible: resourcesModel.count === 0
            }
            
            TableViewColumn {
                role: 'sourceName'
                title: 'Source'
                width: tableWidth * 0.6
                delegate: MouseArea {
                    anchors.fill: parent
                    Text {
                        text: styleData.value
                        color: theme.textColor
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fillAddResourceDialogAndOpen(resourcesModel.get(styleData.row), styleData.row)
                    }
                }
            }
            
            TableViewColumn {
                role: 'alias'
                title: 'Alias'
                width: tableWidth * 0.2
                delegate: MouseArea {
                    anchors.fill: parent
                    Text {
                        text: styleData.value
                        color: theme.textColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fillAddResourceDialogAndOpen(resourcesModel.get(styleData.row), styleData.row)
                    }
                }
            }
            
            TableViewColumn {
                title: 'Action'
                width: tableWidth * 0.2 - 4
                
                delegate: Item {
                    
                    GridLayout {
                        columns: 3
                        
                        Button {
                            iconName: 'go-up'
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 20
                            onClicked: {
                                resourcesModel.move(styleData.row, styleData.row - 1, 1)
                                resourcesModelChanged()
                            }
                            enabled: styleData.row > 0
                        }
                        
                        Button {
                            iconName: 'go-down'
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 20
                            onClicked: {
                                resourcesModel.move(styleData.row, styleData.row + 1, 1)
                                resourcesModelChanged()
                            }
                            enabled: styleData.row < resourcesModel.count - 1
                        }
                        
                        Button {
                            iconName: 'list-remove'
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 20
                            onClicked: {
                                resourcesModel.remove(styleData.row)
                                resourcesModelChanged()
                            }
                        }
                    }
                }
            }
            
            model: resourcesModel
            
            Layout.preferredHeight: 150
            Layout.preferredWidth: tableWidth
            Layout.columnSpan: 2
        }
        Button {
            id: buttonAddResource
            iconName: 'list-add'
            Layout.preferredWidth: 100
            Layout.columnSpan: 2
            onClicked: {
                fillAddResourceDialogAndOpen(null, -1)
            }
        }
        
        Item {
            width: 2
            height: 20
            Layout.columnSpan: 2
        }
        
        Label {
            text: i18n('Notifications')
            font.bold: true
            Layout.alignment: Qt.AlignLeft
        }
        
        Item {
            width: 2
            height: 2
        }
        
        Label {
            text: i18n('Warning temperature [°C]:')
            Layout.alignment: Qt.AlignRight
        }
        SpinBox {
            id: warningTemperatureSpinBox
            decimals: 1
            stepSize: 1
            minimumValue: 10
            maximumValue: 200
        }
        
        Label {
            text: i18n('Meltdown temperature [°C]:')
            Layout.alignment: Qt.AlignRight
        }
        SpinBox {
            id: meltdownTemperatureSpinBox
            decimals: 1
            stepSize: 1
            minimumValue: 10
            maximumValue: 200
        }
        
    }
    
    PlasmaCore.DataSource {
        id: systemmonitorDS
        engine: 'systemmonitor'
    }
    
    PlasmaCore.DataSource {
        id: udisksDS
        engine: 'executable'
        
        connectedSources: [ ModelUtils.UDISKS_DEVICES_CMD ]
        
        onNewData: {
            connectedSources.length = 0
            
            if (data['exit code'] > 0) {
                print('New data incomming. Source: ' + sourceName + ', ERROR: ' + data.stderr);
                return
            }
            
            print('New data incomming. Source: ' + sourceName + ', data: ' + data.stdout);
            
            var pathsToCheck = ModelUtils.parseUdisksPaths(data.stdout)
            pathsToCheck.forEach(function (pathObj) {
                var cmd = ModelUtils.UDISKS_VIRTUAL_PATH_PREFIX + pathObj.name
                comboboxModel.append({
                    text: cmd,
                    val: cmd
                })
            })
            
        }
        
        interval: 500
    }
    
    PlasmaCore.DataSource {
        id: nvidiaDS
        engine: 'executable'
        
        connectedSources: [ 'nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader' ]
        
        property bool prepared: false
        
        onNewData: {
            nvidiaDS.connectedSources.length = 0
            
            if (data['exit code'] > 0) {
                prepared = true
                return
            }
            
            comboboxModel.append({
                text: 'nvidia-smi',
                val: 'nvidia-smi'
            })
            
            prepared = true
        }
        
        interval: 500
    }
    
}
