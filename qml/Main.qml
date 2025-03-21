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

    function loadTiff(url) {
        // Load GeoTIFF metadata first to populate geotransform data
        GeoTiffHandler.loadMetadata(url)
        
        // Set the overlay mode based on radio button selection
        if (basicOverlayRadio.checked) {
            // Legacy simple overlay
            basicTiffOverlay.visible = true
            transformedTiffOverlay.visible = false
            matrixTiffOverlay.visible = false
            
            basicImage.source = "image://geotiff/" + url
            basicTiffOverlay.coordinate = QtPositioning.coordinate(
                parseFloat(GeoTiffHandler.boundsMaxY),
                parseFloat(GeoTiffHandler.boundsMinX)
            )
            basicTiffOverlay.zoomLevel = imgZoomLevelChoice.value/10
        } 
        else if (transformedOverlayRadio.checked) {
            // Transformed overlay
            basicTiffOverlay.visible = false
            transformedTiffOverlay.visible = true
            matrixTiffOverlay.visible = false
            
            transformedTiffOverlay.loadGeoTiff(url)
        }
        else {
            // Matrix-transformed overlay (most accurate)
            basicTiffOverlay.visible = false
            transformedTiffOverlay.visible = false
            matrixTiffOverlay.visible = true
            
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

    Component.onCompleted: loadTiff("file:///home/kyzik/Build/l3h-insight/austro-hungarian-maps/sheets_geo/2868_000_geo.tif")

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
                }
                
                // Overlay type selection
                RadioButton {
                    id: basicOverlayRadio
                    text: "Basic"
                    checked: false
                }
                
                RadioButton {
                    id: transformedOverlayRadio
                    text: "Transformed"
                    checked: false
                }
                
                RadioButton {
                    id: matrixOverlayRadio
                    text: "Matrix"
                    checked: true
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
            loadTiff(fileDialog.selectedFile);
        }
    }
}
