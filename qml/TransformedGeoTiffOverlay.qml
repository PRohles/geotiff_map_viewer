import QtQuick
import QtLocation
import QtPositioning
import geotiff_viewer

// A more advanced GeoTIFF overlay using a MapQuickItem with a transformed image
MapQuickItem {
    id: root
    
    // This will be the top-left coordinate of the GeoTIFF
    coordinate: QtPositioning.coordinate(0, 0)
    
    // GeoTIFF properties
    property string imagePath: ""
    property alias opacity: imageTransform.opacity
    
    // This is the origin point in the image (top-left corner)
    anchorPoint: Qt.point(0, 0)
    
    // Reference to the parent map
    property var map: null
    
    // The actual source item with the transformed GeoTIFF image
    sourceItem: Item {
        id: container
        width: imageItem.width
        height: imageItem.height
        
        Image {
            id: imageItem
            source: root.imagePath
            visible: false
            cache: false
            
            // When the image loads, update the transformation
            onStatusChanged: {
                if (status === Image.Ready) {
                    updateTransform();
                }
            }
        }
        
        // This will contain our transformed image
        ShaderEffect {
            id: imageTransform
            width: imageItem.width
            height: imageItem.height
            
            // Use the GeoTIFF image as the source
            property variant source: imageItem
            
            // Transformation matrix (3x3 provided as 4x4)
            property matrix4x4 transformMatrix
            
            vertexShader: "
                uniform highp mat4 qt_Matrix;
                uniform highp mat4 transformMatrix;
                attribute highp vec4 qt_Vertex;
                attribute highp vec2 qt_MultiTexCoord0;
                varying highp vec2 coord;
                
                void main() {
                    // Apply our geotransform to the texture coordinates
                    coord = qt_MultiTexCoord0;
                    
                    // Pass the standard vertex position
                    gl_Position = qt_Matrix * qt_Vertex;
                }
            "
            
            fragmentShader: "
                varying highp vec2 coord;
                uniform sampler2D source;
                uniform lowp float qt_Opacity;
                uniform highp mat4 transformMatrix;
                
                void main() {
                    // Apply the geotransformation matrix to the texture coordinates
                    // We use the 3x3 portion of the 4x4 matrix
                    highp vec3 texCoord = vec3(coord, 1.0) * mat3(
                        transformMatrix[0][0], transformMatrix[0][1], transformMatrix[0][2],
                        transformMatrix[1][0], transformMatrix[1][1], transformMatrix[1][2],
                        transformMatrix[2][0], transformMatrix[2][1], transformMatrix[2][2]
                    );
                    
                    // Divide by w component for perspective correction
                    highp vec2 finalCoord = texCoord.xy / texCoord.z;
                    
                    // Check if the coordinates are within the valid range [0,1]
                    if (finalCoord.x < 0.0 || finalCoord.x > 1.0 || 
                        finalCoord.y < 0.0 || finalCoord.y > 1.0) {
                        discard; // Outside of texture bounds
                    } else {
                        gl_FragColor = texture2D(source, finalCoord) * qt_Opacity;
                    }
                }
            "
        }
    }
    
    // Load a GeoTIFF at the given URL
    function loadGeoTiff(url) {
        console.log("Loading GeoTIFF: " + url);
        imagePath = "image://geotiff/" + url;
        
        // Set the top-left coordinate from GeoTIFF bounds
        coordinate = QtPositioning.coordinate(
            parseFloat(GeoTiffHandler.boundsMaxY), 
            parseFloat(GeoTiffHandler.boundsMinX)
        );
        
        // The rest of the transformation happens in updateTransform
    }
    
    // Update the transformation matrix based on the GeoTIFF geotransform data
    function updateTransform() {
        if (!imageItem.width || !imageItem.height) return;
        
        // Calculate the transformation matrix based on the GeoTIFF metadata
        // Here, we create a transformation that maps pixel coordinates to
        // normalized texture coordinates [0,1] based on the geotransform
        
        // The transformation matrix should account for:
        // 1. Rotation/skew from the geotransform
        // 2. Scale differences between the image size and projected size
        
        // Get the corners of the image in normalized coordinates
        var topLeft = GeoTransformHandler.worldToPixel(
            parseFloat(GeoTiffHandler.boundsMinX),
            parseFloat(GeoTiffHandler.boundsMaxY)
        );
        var topRight = GeoTransformHandler.worldToPixel(
            parseFloat(GeoTiffHandler.boundsMaxX),
            parseFloat(GeoTiffHandler.boundsMaxY)
        );
        var bottomLeft = GeoTransformHandler.worldToPixel(
            parseFloat(GeoTiffHandler.boundsMinX),
            parseFloat(GeoTiffHandler.boundsMinY)
        );
        var bottomRight = GeoTransformHandler.worldToPixel(
            parseFloat(GeoTiffHandler.boundsMaxX),
            parseFloat(GeoTiffHandler.boundsMinY)
        );
        
        // Calculate the transformation matrix
        // This is a simplified affine transformation
        var matrix = Qt.matrix4x4();
        
        // Apply the scale and rotation based on the GDAL geotransform
        var scaleX = imageItem.width / parseFloat(topRight.x - topLeft.x);
        var scaleY = imageItem.height / parseFloat(bottomLeft.y - topLeft.y);
        
        matrix.translate(-topLeft.x * scaleX, -topLeft.y * scaleY);
        matrix.scale(scaleX, scaleY);
        
        // Set the transformation matrix
        imageTransform.transformMatrix = matrix;
    }
}