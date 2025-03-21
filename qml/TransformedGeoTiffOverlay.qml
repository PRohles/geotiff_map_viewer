import QtQuick
import QtLocation
import QtPositioning

// Import project modules
import geotiff_viewer

// A more advanced GeoTIFF overlay using a MapQuickItem with a transformed image
MapQuickItem {
    id: root
    
    // This will be the top-left coordinate of the GeoTIFF
    coordinate: QtPositioning.coordinate(0, 0)
    
    // GeoTIFF properties
    property string imagePath: ""
    property alias opacity: imageItem.opacity
    property real zoomLevel: 14.0
    
    // This is the origin point in the image (top-left corner)
    anchorPoint: Qt.point(0, 0)
    
    // The actual source item with the transformed GeoTIFF image
    sourceItem: Image {
        id: imageItem
        source: root.imagePath
        cache: false
        
        onStatusChanged: {
            if (status === Image.Ready) {
                console.log("TransformedGeoTiffOverlay: image loaded, width = " + width + ", height = " + height);
                updateTransform();
            } else if (status === Image.Error) {
                console.error("TransformedGeoTiffOverlay: failed to load image from " + source);
            }
        }
    }
    
    // Load a GeoTIFF at the given URL
    function loadGeoTiff(url) {
        console.log("Loading GeoTIFF with transformation: " + url);
        imagePath = "image://geotiff/" + url;
        
        // Set the top-left coordinate from GeoTIFF bounds
        coordinate = QtPositioning.coordinate(
            parseFloat(GeoTiffHandler.boundsMaxY), 
            parseFloat(GeoTiffHandler.boundsMinX)
        );
    }
    
    // Update the transformation based on the GeoTIFF metadata
    function updateTransform() {
        if (!imageItem.width || !imageItem.height) return;
        
        console.log("Updating TransformedGeoTiffOverlay transformation");
        
        // Update the coordinate to the top-left corner of the GeoTIFF
        coordinate = QtPositioning.coordinate(
            parseFloat(GeoTiffHandler.boundsMaxY), 
            parseFloat(GeoTiffHandler.boundsMinX)
        );
        
        console.log("Coordinates set to: " + coordinate.latitude + ", " + coordinate.longitude);
    }
}