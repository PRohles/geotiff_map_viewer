import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtLocation
import QtPositioning

import geotiff_viewer

ApplicationWindow {
    width: 1024
    height: 768
    visible: true
    title: qsTr("GeoTIFF Viewer")

        // Store current file URL for reloading when radio buttons change
    property string currentTiffUrl: ""

    function loadTiff(url) {
        // Store the URL for later use
        currentTiffUrl = url;
        console.log("Loading TIFF: " + url);
        
        // Load GeoTIFF metadata first to populate geotransform data
        GeoTiffHandler.loadMetadata(url)
        
        // Set the overlay mode based on radio button selection
        if (basicOverlayRadio.checked) {
            console.log("Using Basic overlay mode");
            
            // Hide other overlays
            basicTiffOverlay.visible = true
            transformedTiffOverlay.visible = false
            matrixTiffOverlay.visible = false
            
            // Set up basic overlay
            basicImage.source = "image://geotiff/" + url
            basicTiffOverlay.coordinate = QtPositioning.coordinate(
                parseFloat(GeoTiffHandler.boundsMaxY),
                parseFloat(GeoTiffHandler.boundsMinX)
            )
            basicTiffOverlay.zoomLevel = imgZoomLevelChoice.value/10
        } 
        else if (transformedOverlayRadio.checked) {
            console.log("Using Transformed overlay mode");
            
            // Hide other overlays
            basicTiffOverlay.visible = false
            transformedTiffOverlay.visible = true
            matrixTiffOverlay.visible = false
            
            // Set up transformed overlay
            transformedTiffOverlay.zoomLevel = imgZoomLevelChoice.value/10
            transformedTiffOverlay.loadGeoTiff(url)
        }
        else {
            console.log("Using Matrix overlay mode");
            
            // Hide other overlays
            basicTiffOverlay.visible = false
            transformedTiffOverlay.visible = false
            matrixTiffOverlay.visible = true
            
            // Set up matrix overlay
            matrixTiffOverlay.zoomLevel = imgZoomLevelChoice.value/10
            matrixTiffOverlay.loadGeoTiff(url)
        }
        
        // Center map on GeoTIFF
        mapBase.center = QtPositioning.coordinate(
            (parseFloat(GeoTiffHandler.boundsMaxY) + parseFloat(GeoTiffHandler.boundsMinY)) / 2.0,
            (parseFloat(GeoTiffHandler.boundsMaxX) + parseFloat(GeoTiffHandler.boundsMinX)) / 2.0
        )
        
        // Set an appropriate zoom level
        mapBase.zoomLevel = 15  // You may want to calculate this based on image bounds
    }

    // Button group for radio buttons
    ButtonGroup {
        id: overlayTypeGroup
        buttons: [basicOverlayRadio, transformedOverlayRadio, matrixOverlayRadio]
    }
    
    Component.onCompleted: {
        // Make sure the initial GeoTIFF path is properly formatted and exists
        // Use a path that's likely to exist on your system, for example in the application directory
        var initialTiffPath = "file:///tmp/test.tif";
        // Alternatively, you can set this to a relative path in your file system
        
        console.log("Initial GeoTIFF path: " + initialTiffPath);

        // For debugging - check which QML components are loaded
        console.log("Basic overlay is visible: " + basicTiffOverlay.visible);
        console.log("Transformed overlay is visible: " + transformedTiffOverlay.visible);
        console.log("Matrix overlay is visible: " + matrixTiffOverlay.visible);

        // Set the default overlay mode
        matrixOverlayRadio.checked = true;

        // Load the initial GeoTIFF - uncomment when you have a valid path
        // loadTiff(initialTiffPath);
        
        // For testing, tell the user to select a file
        fileDialog.open();
    }

    Plugin {
        id: mapPlugin
        name: "osm"
        PluginParameter {
            name: "osm.mapping.providersrepository.address"
            value: AppConfig.osmMappingProvidersRepositoryAddress
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        ToolBar {
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight + 10

            RowLayout {
                anchors.fill: parent
                Layout.alignment: Qt.AlignVCenter

                Button {
                    text: "Open GeoTIFF"
                    onClicked: fileDialog.open()
                }

                SpinBox {
                    id: mapChoice
                    from: 0
                    to: 6
                    value: 0
                    wrap: true
                    WheelHandler { onWheel: (wheel) => { if(wheel.angleDelta.y > 0) mapChoice.increase(); else mapChoice.decrease(); } }
                    hoverEnabled: true
                    ToolTip.text: "Choose between map tilesets"
                    ToolTip.visible: hovered
                    ToolTip.delay: Application.styleHints.mousePressAndHoldInterval
                }

                SpinBox {
                    id: imgOpacityChoice
                    from: 0
                    to: 100
                    value: 75
                    stepSize: 5
                    WheelHandler { onWheel: (wheel) => { if(wheel.angleDelta.y > 0) imgOpacityChoice.increase(); else imgOpacityChoice.decrease() } }
                    hoverEnabled: true
                    ToolTip.text: "Set opacity of image"
                    ToolTip.visible: hovered
                    ToolTip.delay: Application.styleHints.mousePressAndHoldInterval
                    
                    onValueChanged: {
                        // Update opacity on all overlays
                        basicTiffOverlay.opacity = value / 100.0;
                        transformedTiffOverlay.opacity = value / 100.0;
                        matrixTiffOverlay.opacity = value / 100.0;
                    }
                }

                SpinBox {
                    id: imgZoomLevelChoice
                    from: 10
                    to: 200
                    value: 140
                    // stepSize: 5
                    WheelHandler { onWheel: (wheel) => { if(wheel.angleDelta.y > 0) imgZoomLevelChoice.increase(); else imgZoomLevelChoice.decrease() } }
                    hoverEnabled: true
                    ToolTip.text: "Set the map zoomlevel at which the image is shown at 100% scale"
                    ToolTip.visible: hovered
                    ToolTip.delay: Application.styleHints.mousePressAndHoldInterval
                    
                    onValueChanged: {
                        // Update zoom level on all overlays
                        basicTiffOverlay.zoomLevel = value / 10.0;
                        transformedTiffOverlay.zoomLevel = value / 10.0;
                        matrixTiffOverlay.zoomLevel = value / 10.0;
                    }
                }
                
                // Overlay type selection
                RadioButton {
                    id: basicOverlayRadio
                    text: "Basic"
                    checked: false
                    onCheckedChanged: {
                        if (checked && currentTiffUrl) {
                            console.log("Switching to Basic Mode");
                            loadTiff(currentTiffUrl);
                        }
                    }
                }
                
                RadioButton {
                    id: transformedOverlayRadio
                    text: "Transformed"
                    checked: false
                    onCheckedChanged: {
                        if (checked && currentTiffUrl) {
                            console.log("Switching to Transformed Mode");
                            loadTiff(currentTiffUrl);
                        }
                    }
                }
                
                RadioButton {
                    id: matrixOverlayRadio
                    text: "Matrix"
                    checked: true
                    onCheckedChanged: {
                        if (checked && currentTiffUrl) {
                            console.log("Switching to Matrix Mode");
                            loadTiff(currentTiffUrl);
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: GeoTiffHandler.currentFile || "No file loaded"
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                    HoverHandler {
                        id: fileLabelHoverHandler
                    }
                    ToolTip.text: "path of GeoTIFF file that is showing"
                    ToolTip.visible: fileLabelHoverHandler.hovered
                    ToolTip.delay: Application.styleHints.mousePressAndHoldInterval
                }
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            Item {
                SplitView.preferredWidth: parent.width * 0.7
                SplitView.minimumWidth: 300
                SplitView.fillHeight: true

                Map {
                    id: mapBase
                    anchors.fill: parent

                    plugin: mapPlugin
                    center: QtPositioning.coordinate(52.9,22) // Austro-Hungary
                    zoomLevel: 10.5
                    activeMapType: supportedMapTypes[mapChoice.value]
                    property geoCoordinate startCentroid
                    property geoCoordinate cursorCoordinate;

                    HoverHandler {
                        onPointChanged: {
                            mapBase.cursorCoordinate = mapBase.toCoordinate(point.position, false);
                        }
                    }

                    PinchHandler {
                        id: pinch
                        target: null
                        onActiveChanged: if (active) {
                            mapBase.startCentroid = mapBase.toCoordinate(pinch.centroid.position, false)
                        }
                        onScaleChanged: (delta) => {
                            mapBase.zoomLevel += Math.log2(delta)
                            mapBase.alignCoordinateToPoint(mapBase.startCentroid, pinch.centroid.position)
                        }
                        onRotationChanged: (delta) => {
                            mapBase.bearing -= delta
                            mapBase.alignCoordinateToPoint(mapBase.startCentroid, pinch.centroid.position)
                        }
                        grabPermissions: PointerHandler.TakeOverForbidden
                    }
                    WheelHandler {
                        id: wheel
                        // workaround for QTBUG-87646 / QTBUG-112394 / QTBUG-112432:
                        // Magic Mouse pretends to be a trackpad but doesn't work with PinchHandler
                        // and we don't yet distinguish mice and trackpads on Wayland either
                        acceptedDevices: Qt.platform.pluginName === "cocoa" || Qt.platform.pluginName === "wayland"
                                         ? PointerDevice.Mouse | PointerDevice.TouchPad
                                         : PointerDevice.Mouse
                        rotationScale: 1/120
                        property: "zoomLevel"
                    }
                    DragHandler {
                        id: drag
                        target: null
                        onTranslationChanged: (delta) => mapBase.pan(-delta.x, -delta.y)
                    }
                    Shortcut {
                        enabled: mapBase.zoomLevel < mapBase.maximumZoomLevel
                        sequence: StandardKey.ZoomIn
                        onActivated: mapBase.zoomLevel = mapBase.zoomLevel + 0.05 //Math.round(mapBase.zoomLevel + 1)
                    }
                    Shortcut {
                        enabled: mapBase.zoomLevel > mapBase.minimumZoomLevel
                        sequence: StandardKey.ZoomOut
                        onActivated: mapBase.zoomLevel = mapBase.zoomLevel - 0.05 //Math.round(mapBase.zoomLevel - 1)
                    }
                }
                Map {
                    id: mapOverlay
                    anchors.fill: mapBase
                    plugin: Plugin { name: "itemsoverlay" }
                    center: mapBase.center
                    color: 'transparent' // Necessary to make this map transparent
                    minimumFieldOfView: mapBase.minimumFieldOfView
                    maximumFieldOfView: mapBase.maximumFieldOfView
                    minimumTilt: mapBase.minimumTilt
                    maximumTilt: mapBase.maximumTilt
                    minimumZoomLevel: mapBase.minimumZoomLevel
                    maximumZoomLevel: mapBase.maximumZoomLevel
                    zoomLevel: mapBase.zoomLevel
                    tilt: mapBase.tilt;
                    bearing: mapBase.bearing
                    fieldOfView: mapBase.fieldOfView
                    z: mapBase.z + 1

                    // Basic GeoTIFF overlay (legacy)
                    MapQuickItem {
                        id: basicTiffOverlay
                        visible: false
                        sourceItem: Image {
                            id: basicImage
                            cache: false
                        }
                        coordinate: QtPositioning.coordinate(0, 0)
                        anchorPoint: Qt.point(0, 0)
                        zoomLevel: imgZoomLevelChoice.value/10
                        opacity: (imgOpacityChoice.value*1.0)/100
                    }
                    
                    // Transformed overlay
                    TransformedGeoTiffOverlay {
                        id: transformedTiffOverlay
                        visible: false
                        map: mapBase
                        opacity: (imgOpacityChoice.value*1.0)/100
                    }
                    
                    // Matrix-transformed overlay (most accurate)
                    MatrixTransformedGeoTiffOverlay {
                        id: matrixTiffOverlay
                        visible: true
                        map: mapBase
                        opacity: (imgOpacityChoice.value*1.0)/100
                    }
                }
            }

            Flickable {
                id: flickable
                SplitView.preferredWidth: parent.width * 0.3
                SplitView.minimumWidth: 200
                SplitView.fillHeight: true
                contentWidth: width
                contentHeight: columnLayout.height
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                }

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 10

                    GroupBox {
                        Layout.fillWidth: true
                        title: "GeoTIFF Information"

                        ColumnLayout {
                            anchors.fill: parent

                            Label {
                                text: "<b>File:</b> " + (GeoTiffHandler.fileName || "None")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: "<b>Dimensions:</b> " + (GeoTiffHandler.dimensions || "Unknown")
                                visible: GeoTiffHandler.dimensions !== ""
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: "<b>Coordinate System:</b> " + (GeoTiffHandler.coordinateSystem || "Unknown")
                                visible: GeoTiffHandler.coordinateSystem !== ""
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: "<b>Projection:</b> " + (GeoTiffHandler.projection || "Unknown")
                                visible: GeoTiffHandler.projection !== ""
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    GroupBox {
                        Layout.fillWidth: true
                        title: "Geospatial Bounds"

                        GridLayout {
                            anchors.fill: parent
                            columns: 2

                            Label { text: "Min X:" }
                            TextField {
                                text: GeoTiffHandler.boundsMinX || "Unknown"
                                Layout.fillWidth: true
                                readOnly: true
                                background: Item {}
                            }

                            Label { text: "Min Y:" }
                            TextField {
                                text: GeoTiffHandler.boundsMinY || "Unknown"
                                Layout.fillWidth: true
                                readOnly: true
                                background: Item {}
                            }

                            Label { text: "Max X:" }
                            TextField {
                                text: GeoTiffHandler.boundsMaxX || "Unknown"
                                Layout.fillWidth: true
                                readOnly: true
                                background: Item {}
                            }

                            Label { text: "Max Y:" }
                            TextField {
                                text: GeoTiffHandler.boundsMaxY || "Unknown"
                                Layout.fillWidth: true
                                readOnly: true
                                background: Item {}
                            }
                        }
                    }

                    GroupBox {
                        Layout.fillWidth: true
                        title: "Georeferencing Mode"

                        ColumnLayout {
                            anchors.fill: parent

                            Label {
                                text: "<b>Current Mode:</b> " + (basicOverlayRadio.checked ? "Basic (Simple Overlay)" : 
                                                            transformedOverlayRadio.checked ? "Transformed (Affine Transform)" : 
                                                            "Matrix (Full Georeference)")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: "<b>Description:</b> " + (basicOverlayRadio.checked ? "Places image at top-left coordinate with manual zoom" : 
                                                           transformedOverlayRadio.checked ? "Applies transformation based on image corners" : 
                                                           "Applies full matrix transformation from GDAL geotransform")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                    
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: bandsInfoLV.height + implicitLabelHeight + verticalPadding
                        title: "Bands Information"

                        ListView {
                            id: bandsInfoLV
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: contentHeight

                            model: GeoTiffHandler.bandsModel
                            delegate: ItemDelegate {
                                width: parent.width
                                contentItem: Label {
                                    text: modelData
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            id: statusBar
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: GeoTiffHandler.statusMessage || "Ready"
                elide: Text.ElideRight
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Please choose a GeoTIFF file"
        currentFolder: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
        nameFilters: ["GeoTIFF files (*.tif *.tiff)", "All files (*)"]

        onAccepted: {
            console.log("FileDialog accepted: " + fileDialog.selectedFile);
            loadTiff(fileDialog.selectedFile);
        }
    }
}
