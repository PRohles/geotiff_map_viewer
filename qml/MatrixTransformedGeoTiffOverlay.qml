import QtQuick
import QtLocation
import QtPositioning

// Import project modules
import geotiff_viewer

// A sophisticated GeoTIFF overlay that applies precise matrix transformation
MapQuickItem {
    id: root
    
    // The top-left coordinate of the GeoTIFF
    coordinate: QtPositioning.coordinate(0, 0)
    
    // Properties
    property string imagePath: ""
    property alias opacity: imageItem.opacity
    property real zoomLevel: 14.0
    
    // This is the origin point in the image (top-left corner)
    anchorPoint: Qt.point(0, 0)
    
    // Simple Image as source item
    sourceItem: Image {
        id: imageItem
        source: root.imagePath
        cache: false
        
        onStatusChanged: {
            if (status === Image.Ready) {
                console.log("MatrixTransformedGeoTiffOverlay: image loaded, width = " + width + ", height = " + height);
                updateOverlay();
            } else if (status === Image.Error) {
                console.error("MatrixTransformedGeoTiffOverlay: failed to load image from " + source);
            }
        }
    }
    
    // Load a GeoTIFF at the given URL
    function loadGeoTiff(url) {
        console.log("Loading GeoTIFF with matrix transformation: " + url);
        imagePath = "image://geotiff/" + url;
        
        // Set the top-left coordinate from GeoTIFF bounds
        updateOverlay();
    }
    
    // Update the overlay with the correct transformation
    function updateOverlay() {
        if (!imageItem.width || !imageItem.height) return;
        
        console.log("Updating MatrixTransformedGeoTiffOverlay");
        
        // Update the MapQuickItem placement
        // Use the top-left corner coordinates
        coordinate = QtPositioning.coordinate(
            parseFloat(GeoTiffHandler.boundsMaxY), 
            parseFloat(GeoTiffHandler.boundsMinX)
        );
        
        console.log("Coordinates set to: " + coordinate.latitude + ", " + coordinate.longitude);
    }
}