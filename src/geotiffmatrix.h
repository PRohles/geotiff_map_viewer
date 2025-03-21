#ifndef GEOTIFFMATRIX_H
#define GEOTIFFMATRIX_H

#include <QObject>
#include <QQmlEngine>
#include <QMatrix4x4>
#include <QPointF>

class GeoTiffMatrix : public QObject
{
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT

public:
    explicit GeoTiffMatrix(QObject *parent = nullptr);
    ~GeoTiffMatrix();

    static GeoTiffMatrix *create(QQmlEngine *, QJSEngine *engine);
    static GeoTiffMatrix *instance();

    // Set the geotransform coefficients directly from GDAL
    Q_INVOKABLE void setGeoTransform(const QList<double> &coefficients, int width, int height);
    
    // Get the transformation matrix for use in QML
    Q_INVOKABLE QMatrix4x4 getTransformationMatrix() const;
    
    // Calculate pixel coordinates from world coordinates
    Q_INVOKABLE QPointF worldToPixel(double lon, double lat) const;
    
    // Calculate world coordinates from pixel coordinates
    Q_INVOKABLE QPointF pixelToWorld(int pixelX, int pixelY) const;
    
    // Calculate the corner points of the image in world coordinates
    Q_INVOKABLE QList<QPointF> getImageCorners() const;
    
    // Calculate the bounding box of the image in world coordinates
    Q_INVOKABLE QList<double> getBoundingBox() const; // returns [minLon, minLat, maxLon, maxLat]

private:
    void updateMatrices();

private:
    // The 6 GDAL geotransform coefficients
    double m_geoTransform[6];
    
    // The image dimensions
    int m_width;
    int m_height;
    
    // The transformation matrices
    QMatrix4x4 m_pixelToWorldMatrix;
    QMatrix4x4 m_worldToPixelMatrix;

    inline static GeoTiffMatrix * s_singletonInstance = nullptr;
    inline static QJSEngine *s_engine = nullptr;
};

#endif // GEOTIFFMATRIX_H