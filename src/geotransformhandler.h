#ifndef GEOTRANSFORMHANDLER_H
#define GEOTRANSFORMHANDLER_H

#include <QObject>
#include <QQmlEngine>
#include <QPointF>
#include <QPolygonF>
#include <QGeoCoordinate>

class GeoTransformHandler : public QObject
{
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT

public:
    explicit GeoTransformHandler(QObject *parent = nullptr);
    ~GeoTransformHandler();

    static GeoTransformHandler *create(QQmlEngine *, QJSEngine *engine);
    static GeoTransformHandler *instance();

    Q_INVOKABLE QPointF worldToPixel(double lon, double lat) const;
    Q_INVOKABLE QGeoCoordinate pixelToWorld(int pixelX, int pixelY) const;
    Q_INVOKABLE QPolygonF getImageCornerCoordinates() const;
    
    Q_INVOKABLE void updateTransform(
        double topLeftLon, double topLeftLat,
        double topRightLon, double topRightLat,
        double bottomLeftLon, double bottomLeftLat,
        double bottomRightLon, double bottomRightLat,
        int imageWidth, int imageHeight);

    Q_INVOKABLE void updateTransformFromGDAL(
        double originX, double originY,
        double pixelWidth, double pixelHeight, 
        double rotationX, double rotationY,
        int imageWidth, int imageHeight);

private:
    void calculateInverseTransform();

private:
    // GDAL Geotransform coefficients (6 coefficients)
    double m_geoTransform[6];
    
    // Inverse transform coefficients for pixel to world conversion
    double m_inverseTransform[6];
    
    // Image dimensions
    int m_imageWidth;
    int m_imageHeight;
    
    // Image corner coordinates in world space
    QPolygonF m_imageCorners;

    inline static GeoTransformHandler * s_singletonInstance = nullptr;
    inline static QJSEngine *s_engine = nullptr;
};

#endif // GEOTRANSFORMHANDLER_H