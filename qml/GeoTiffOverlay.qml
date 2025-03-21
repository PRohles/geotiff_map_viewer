import QtQuick
import QtLocation
import QtPositioning
import geotiff_viewer

// A component for displaying a georeferenced GeoTIFF
MapPolygon {
    id: root
    
    property string imagePath: ""
    property alias opacity: imageItem.opacity
    
    // Set up initial polygon coordinates
    path: []
    
    // References to the corners of the image in world coordinates
    property var cornerCoordinates: []
    
    // Map reference to get the viewport projected rectangle
    property var map: null
    
    // The image item that contains the GeoTIFF
    ShaderEffectSource {
        id: effectSource
        sourceItem: Image {
            id: imageItem
            source: root.imagePath
            smooth: true
            visible: false
            cache: false
        }
        live: true
        hideSource: true
    }
    
    // Update the polygon path when corner coordinates change
    function updatePath() {
        if (cornerCoordinates.length != 4) return;
        
        var pathCoords = [];
        for (var i = 0; i < 4; i++) {
            var coord = cornerCoordinates[i];
            pathCoords.push(QtPositioning.coordinate(coord.y, coord.x));
        }
        
        path = pathCoords;
    }
    
    // Load a GeoTIFF at the given url
    function loadGeoTiff(url) {
        console.log("Loading GeoTIFF: " + url);
        imagePath = "image://geotiff/" + url;
        
        // Load the corner coordinates from the GeoTransformHandler
        var corners = GeoTransformHandler.getImageCornerCoordinates();
        cornerCoordinates = corners;
        
        // Update the polygon path
        updatePath();
    }
    
    // Custom material to apply the image to our polygon with correct transformation
    MapPolygon.MapPolygonMaterial {
        id: material
        texture: effectSource
        
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D qt_Texture0;
            uniform lowp float qt_Opacity;
            void main() {
                // Sample the texture using normalized coordinates
                gl_FragColor = texture2D(qt_Texture0, qt_TexCoord0) * qt_Opacity;
                if (gl_FragColor.a < 0.1) // Discard nearly transparent pixels
                    discard;
            }
        "
    }
    
    Component.onCompleted: {
        fillColor = Qt.rgba(1, 1, 1, 1) // White background
        material = material // Apply our custom material
    }
}