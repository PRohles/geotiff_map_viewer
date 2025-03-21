# GeoTIFF Map Viewer

A Qt 6.5 application that properly georeferences GeoTIFF images onto a Qt Location map.

## Overview

This application demonstrates different approaches to accurately display georeferenced GeoTIFF images on top of a Qt Location map. It provides three levels of accuracy in the georeferencing implementation:

1. **Basic Mode** - Simple overlay at the top-left coordinate with manual zoom level
2. **Transformed Mode** - Uses affine transformation of the image corners
3. **Matrix Mode** - Uses the full GDAL geotransform matrix for accurate pixel-to-coordinate mapping

## Implementation Details

### GDAL Geotransform

The GDAL geotransform consists of six coefficients that define an affine transformation:

```
X_geo = GT(0) + X_pixel * GT(1) + Y_pixel * GT(2)
Y_geo = GT(3) + X_pixel * GT(4) + Y_pixel * GT(5)
```

Where:
- GT(0), GT(3) are the coordinates of the top-left pixel
- GT(1), GT(5) are the pixel width and height
- GT(2), GT(4) are the rotation terms (0 for north-up images)

### Georeferencing Classes

- **GeoTiffHandler**: Handles loading the GeoTIFF and extracting metadata
- **GeoTransformHandler**: Basic implementation of the geotransform
- **GeoTiffMatrix**: Advanced implementation with full matrix transformation

### QML Components

- **GeoTiffOverlay**: Simple polygon-based overlay
- **TransformedGeoTiffOverlay**: Uses basic transformation
- **MatrixTransformedGeoTiffOverlay**: Uses ShaderEffect with matrix transformation for pixel-perfect alignment

## Mathematical Relationship

The mathematical relationship between GeoTIFF coordinates and Qt Location map coordinates is implemented through the following steps:

1. Load the GDAL geotransform coefficients
2. Create transformation matrices for world-to-pixel and pixel-to-world conversion
3. Use ShaderEffect in QML to apply the transformation to the image
4. Position the MapQuickItem at the correct coordinate on the map

## Example Usage

```qml
// Initialize with matrix transformation (most accurate)
MatrixTransformedGeoTiffOverlay {
    id: geoTiffOverlay
    map: mapReference
    opacity: 0.7
}

// Load a GeoTIFF file
geoTiffOverlay.loadGeoTiff("path/to/file.tif")
```

## Requirements

- Qt 6.5 or higher
- GDAL library
- Qt Location module

## Building

1. Make sure GDAL is installed and available in your path
2. Configure the project: `cmake -DCMAKE_PREFIX_PATH=/path/to/qt6 .`
3. Build: `cmake --build .`

## License

[Include license information here]
