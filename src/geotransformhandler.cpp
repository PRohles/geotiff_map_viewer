#include "geotransformhandler.h"
#include <QCoreApplication>
#include <QDebug>
#include <cmath>

GeoTransformHandler::GeoTransformHandler(QObject *parent)
    : QObject{parent}
    , m_imageWidth(0)
    , m_imageHeight(0)
{
    // Initialize transform matrices
    for (int i = 0; i < 6; ++i) {
        m_geoTransform[i] = 0.0;
        m_inverseTransform[i] = 0.0;
    }
}

GeoTransformHandler::~GeoTransformHandler()
{
}

GeoTransformHandler *GeoTransformHandler::instance() {
    if (s_singletonInstance == nullptr)
        s_singletonInstance = new GeoTransformHandler(qApp);
    return s_singletonInstance;
}

GeoTransformHandler *GeoTransformHandler::create(QQmlEngine *, QJSEngine *engine)
{
    Q_ASSERT(s_singletonInstance);
    Q_ASSERT(engine->thread() == s_singletonInstance->thread());
    if (s_engine)
        Q_ASSERT(engine == s_engine);
    else
        s_engine = engine;

    QJSEngine::setObjectOwnership(s_singletonInstance, QJSEngine::CppOwnership);
    return s_singletonInstance;
}

QPointF GeoTransformHandler::worldToPixel(double lon, double lat) const
{
    // Pixel X = Ax + By + C
    // Pixel Y = Dx + Ey + F
    // where x = lon, y = lat
    
    // These equations come from the inverse of the GDAL geotransform
    double pixelX = m_inverseTransform[0] * lon + m_inverseTransform[1] * lat + m_inverseTransform[2];
    double pixelY = m_inverseTransform[3] * lon + m_inverseTransform[4] * lat + m_inverseTransform[5];
    
    return QPointF(pixelX, pixelY);
}

QGeoCoordinate GeoTransformHandler::pixelToWorld(int pixelX, int pixelY) const
{
    // World X = a*P(x) + b*P(y) + c
    // World Y = d*P(x) + e*P(y) + f
    // where P(x) = pixel column, P(y) = pixel row
    
    // This is the standard GDAL geotransform equation:
    // Xgeo = GT(0) + P(x)*GT(1) + P(y)*GT(2)
    // Ygeo = GT(3) + P(x)*GT(4) + P(y)*GT(5)
    
    double worldX = m_geoTransform[0] + pixelX * m_geoTransform[1] + pixelY * m_geoTransform[2];
    double worldY = m_geoTransform[3] + pixelX * m_geoTransform[4] + pixelY * m_geoTransform[5];
    
    return QGeoCoordinate(worldY, worldX); // Note: GeoCoordinate takes (lat, lon)
}

QPolygonF GeoTransformHandler::getImageCornerCoordinates() const
{
    return m_imageCorners;
}

void GeoTransformHandler::updateTransform(
    double topLeftLon, double topLeftLat,
    double topRightLon, double topRightLat,
    double bottomLeftLon, double bottomLeftLat,
    double bottomRightLon, double bottomRightLat,
    int imageWidth, int imageHeight)
{
    // Store image dimensions
    m_imageWidth = imageWidth;
    m_imageHeight = imageHeight;
    
    // Store corner coordinates
    m_imageCorners.clear();
    m_imageCorners << QPointF(topLeftLon, topLeftLat)
                  << QPointF(topRightLon, topRightLat)
                  << QPointF(bottomRightLon, bottomRightLat)
                  << QPointF(bottomLeftLon, bottomLeftLat);
    
    // Calculate affine transform coefficients
    // This is simplified and assumes rectangular images in world coordinates
    
    // GT(0) - top left x coordinate
    m_geoTransform[0] = topLeftLon;
    
    // GT(1) - pixel width in x direction
    m_geoTransform[1] = (topRightLon - topLeftLon) / imageWidth;
    
    // GT(2) - row rotation (typically 0 for north-up images)
    // For skewed images, this handles the x component of the y-axis
    m_geoTransform[2] = (bottomLeftLon - topLeftLon) / imageHeight;
    
    // GT(3) - top left y coordinate
    m_geoTransform[3] = topLeftLat;
    
    // GT(4) - column rotation (typically 0 for north-up images)
    // For skewed images, this handles the y component of the x-axis
    m_geoTransform[4] = (topRightLat - topLeftLat) / imageWidth;
    
    // GT(5) - pixel height in y direction (negative for north-up images)
    m_geoTransform[5] = (bottomLeftLat - topLeftLat) / imageHeight;
    
    // Calculate the inverse transform for worldToPixel conversions
    calculateInverseTransform();
}

void GeoTransformHandler::updateTransformFromGDAL(
    double originX, double originY,
    double pixelWidth, double pixelHeight, 
    double rotationX, double rotationY,
    int imageWidth, int imageHeight)
{
    // Store image dimensions
    m_imageWidth = imageWidth;
    m_imageHeight = imageHeight;
    
    // Set geotransform coefficients directly from GDAL parameters
    m_geoTransform[0] = originX;        // top left x
    m_geoTransform[1] = pixelWidth;     // w-e pixel resolution
    m_geoTransform[2] = rotationX;      // row rotation (typically 0)
    m_geoTransform[3] = originY;        // top left y
    m_geoTransform[4] = rotationY;      // column rotation (typically 0)
    m_geoTransform[5] = pixelHeight;    // n-s pixel resolution (negative for north-up)
    
    // Calculate corner coordinates
    QGeoCoordinate topLeft = pixelToWorld(0, 0);
    QGeoCoordinate topRight = pixelToWorld(imageWidth, 0);
    QGeoCoordinate bottomLeft = pixelToWorld(0, imageHeight);
    QGeoCoordinate bottomRight = pixelToWorld(imageWidth, imageHeight);
    
    // Store corner coordinates
    m_imageCorners.clear();
    m_imageCorners << QPointF(topLeft.longitude(), topLeft.latitude())
                  << QPointF(topRight.longitude(), topRight.latitude())
                  << QPointF(bottomRight.longitude(), bottomRight.latitude())
                  << QPointF(bottomLeft.longitude(), bottomLeft.latitude());
    
    // Calculate the inverse transform for worldToPixel conversions
    calculateInverseTransform();
}

void GeoTransformHandler::calculateInverseTransform()
{
    // For the transformation:
    // Xgeo = GT(0) + P(x)*GT(1) + P(y)*GT(2)
    // Ygeo = GT(3) + P(x)*GT(4) + P(y)*GT(5)
    
    // The inverse transformation is:
    // P(x) = inv(0)*Xgeo + inv(1)*Ygeo + inv(2)
    // P(y) = inv(3)*Xgeo + inv(4)*Ygeo + inv(5)
    
    // Calculate determinant of the transformation matrix
    double det = m_geoTransform[1] * m_geoTransform[5] - m_geoTransform[2] * m_geoTransform[4];
    
    if (std::abs(det) < 1e-10) {
        qWarning() << "GeoTransformHandler: Transform matrix is singular, cannot invert";
        return;
    }
    
    // Calculate inverse coefficients
    double invDet = 1.0 / det;
    
    m_inverseTransform[0] = m_geoTransform[5] * invDet;        // a11
    m_inverseTransform[1] = -m_geoTransform[2] * invDet;       // a12
    m_inverseTransform[3] = -m_geoTransform[4] * invDet;       // a21
    m_inverseTransform[4] = m_geoTransform[1] * invDet;        // a22
    
    // Calculate the translation components
    m_inverseTransform[2] = (-m_geoTransform[0] * m_inverseTransform[0] - 
                           m_geoTransform[3] * m_inverseTransform[1]);  // b1
    m_inverseTransform[5] = (-m_geoTransform[0] * m_inverseTransform[3] - 
                           m_geoTransform[3] * m_inverseTransform[4]);  // b2
}