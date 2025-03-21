import QtQuick
import QtLocation
import QtPositioning
import geotiff_viewer

// A sophisticated GeoTIFF overlay that applies precise matrix transformation
MapQuickItem {
    id: root
    
    // The top-left coordinate of the GeoTIFF
    coordinate: QtPositioning.coordinate(0, 0)
    
    // Properties
    property string imagePath: ""
    property alias opacity: shaderEffect.opacity
    
    // This is the origin point in the image (top-left corner)
    anchorPoint: Qt.point(0, 0)
    
    // The map reference
    property var map: null
    
    // Source item that contains the transformed GeoTIFF
    sourceItem: Item {
        id: container
        width: imageItem.width
        height: imageItem.height
        
        // The original GeoTIFF image
        Image {
            id: imageItem
            source: root.imagePath
            visible: false
            cache: false
            
            // When the image loads, update the overlay
            onStatusChanged: {
                if (status === Image.Ready) {
                    updateOverlay();
                }
            }
        }
        
        // This applies the precise matrix transformation
        ShaderEffect {
            id: shaderEffect
            width: imageItem.width
            height: imageItem.height
            
            // The image source
            property variant source: imageItem
            
            // The transformation matrix from GeoTiffMatrix
            property matrix4x4 transformMatrix: GeoTiffMatrix.getTransformationMatrix()
            
            // Set up vertex shader for position
            vertexShader: "
                uniform highp mat4 qt_Matrix;
                attribute highp vec4 qt_Vertex;
                attribute highp vec2 qt_MultiTexCoord0;
                varying highp vec2 texCoord;
                
                void main() {
                    texCoord = qt_MultiTexCoord0;
                    gl_Position = qt_Matrix * qt_Vertex;
                }
            "
            
            // Use fragment shader for precise texture coordinate transformation
            fragmentShader: "
                varying highp vec2 texCoord;
                uniform sampler2D source;
                uniform lowp float qt_Opacity;
                uniform highp mat4 transformMatrix;
                
                void main() {
                    // Calculate transformed coordinates
                    highp vec3 texPos = vec3(texCoord, 1.0);
                    highp vec3 worldPos = transformMatrix * texPos;
                    
                    // Normalize the coordinates for the texture lookup
                    highp vec2 texCoordTransformed = worldPos.xy / worldPos.z;
                    
                    // Sample the texture at the transformed coordinates
                    gl_FragColor = texture2D(source, texCoord) * qt_Opacity;
                    
                    // Discard pixels outside the valid range
                    if (texCoordTransformed.x < 0.0 || texCoordTransformed.x > 1.0 ||
                        texCoordTransformed.y < 0.0 || texCoordTransformed.y > 1.0) {
                        discard;
                    }
                }
            "
        }
    }
    
    // Load a GeoTIFF at the given URL
    function loadGeoTiff(url) {
        console.log("Loading GeoTIFF with matrix transformation: " + url);
        imagePath = "image://geotiff/" + url;
        
        // Set the top-left coordinate from GeoTIFF bounds
        var bbox = GeoTiffMatrix.getBoundingBox();
        if (bbox.length === 4) {
            coordinate = QtPositioning.coordinate(bbox[3], bbox[0]); // maxLat, minLon
        }
    }
    
    // Update the overlay with the correct transformation
    function updateOverlay() {
        if (!imageItem.width || !imageItem.height) return;
        
        // Make sure the matrix is up to date
        shaderEffect.transformMatrix = GeoTiffMatrix.getTransformationMatrix();
        
        // Update the MapQuickItem placement
        var corners = GeoTiffMatrix.getImageCorners();
        if (corners.length === 4) {
            // Use the top-left corner as the coordinate
            coordinate = QtPositioning.coordinate(corners[0].y, corners[0].x);
        }
    }
}