#include "geotiffmatrix.h"
#include <QCoreApplication>
#include <QDebug>

GeoTiffMatrix::GeoTiffMatrix(QObject *parent)
    : QObject{parent}
    , m_width(0)
    , m_height(0)
{
    // Initialize the geotransform coefficients
    for (int i = 0; i < 6; ++i) {
        m_geoTransform[i] = 0.0;
    }
}

GeoTiffMatrix::~GeoTiffMatrix()
{
}

GeoTiffMatrix *GeoTiffMatrix::instance() {
    if (s_singletonInstance == nullptr)
        s_singletonInstance = new GeoTiffMatrix(qApp);
    return s_singletonInstance;
}

GeoTiffMatrix *GeoTiffMatrix::create(QQmlEngine *, QJSEngine *engine)
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

void GeoTiffMatrix::setGeoTransform(const QList<double> &coefficients, int width, int height)
{
    if (coefficients.size() != 6) {
        qWarning() << "GeoTiffMatrix: Expected 6 coefficients, got" << coefficients.size();
        return;
    }
    
    // Store the coefficients
    for (int i = 0; i < 6; ++i) {
        m_geoTransform[i] = coefficients[i];
    }
    
    // Store the image dimensions
    m_width = width;
    m_height = height;
    
    // Update the transformation matrices
    updateMatrices();
}

QMatrix4x4 GeoTiffMatrix::getTransformationMatrix() const
{
    return m_pixelToWorldMatrix;
}

QPointF GeoTiffMatrix::worldToPixel(double lon, double lat) const
{
    // Apply the inverse geotransform
    
    // Calculate determinant for inverse
    double det = m_geoTransform[1] * m_geoTransform[5] - m_geoTransform[2] * m_geoTransform[4];
    if (qAbs(det) < 1e-10) {
        qWarning() << "GeoTiffMatrix: Matrix is singular, cannot compute inverse";
        return QPointF(0, 0);
    }
    
    // Calculate the inverse transformation
    double invDet = 1.0 / det;
    
    // Calculate the pixel coordinates
    double x = m_geoTransform[5] * invDet * (lon - m_geoTransform[0]) - 
               m_geoTransform[2] * invDet * (lat - m_geoTransform[3]);
    
    double y = -m_geoTransform[4] * invDet * (lon - m_geoTransform[0]) + 
                m_geoTransform[1] * invDet * (lat - m_geoTransform[3]);
    
    return QPointF(x, y);
}

QPointF GeoTiffMatrix::pixelToWorld(int pixelX, int pixelY) const
{
    // Apply the geotransform
    double lon = m_geoTransform[0] + pixelX * m_geoTransform[1] + pixelY * m_geoTransform[2];
    double lat = m_geoTransform[3] + pixelX * m_geoTransform[4] + pixelY * m_geoTransform[5];
    
    return QPointF(lon, lat);
}

QList<QPointF> GeoTiffMatrix::getImageCorners() const
{
    QList<QPointF> corners;
    
    // Calculate the world coordinates of the four corners
    corners << pixelToWorld(0, 0);                  // Top-left
    corners << pixelToWorld(m_width, 0);            // Top-right
    corners << pixelToWorld(m_width, m_height);     // Bottom-right
    corners << pixelToWorld(0, m_height);           // Bottom-left
    
    return corners;
}

QList<double> GeoTiffMatrix::getBoundingBox() const
{
    QList<QPointF> corners = getImageCorners();
    
    if (corners.isEmpty()) {
        return QList<double>() << 0.0 << 0.0 << 0.0 << 0.0;
    }
    
    // Initialize with the first corner
    double minLon = corners[0].x();
    double minLat = corners[0].y();
    double maxLon = corners[0].x();
    double maxLat = corners[0].y();
    
    // Find the extremes
    for (int i = 1; i < corners.size(); ++i) {
        minLon = qMin(minLon, corners[i].x());
        minLat = qMin(minLat, corners[i].y());
        maxLon = qMax(maxLon, corners[i].x());
        maxLat = qMax(maxLat, corners[i].y());
    }
    
    return QList<double>() << minLon << minLat << maxLon << maxLat;
}

void GeoTiffMatrix::updateMatrices()
{
    // Create the world-to-pixel matrix
    m_worldToPixelMatrix.setToIdentity();
    
    // This is a simplification - for a more accurate transformation, 
    // we would need to implement the full affine transformation
    
    // Calculate determinant for inverse
    double det = m_geoTransform[1] * m_geoTransform[5] - m_geoTransform[2] * m_geoTransform[4];
    if (qAbs(det) < 1e-10) {
        qWarning() << "GeoTiffMatrix: Matrix is singular, cannot compute inverse";
        return;
    }
    
    // Calculate the inverse of the geotransform
    double invDet = 1.0 / det;
    
    double a = m_geoTransform[5] * invDet;
    double b = -m_geoTransform[2] * invDet;
    double c = (m_geoTransform[2] * m_geoTransform[3] - m_geoTransform[0] * m_geoTransform[5]) * invDet;
    
    double d = -m_geoTransform[4] * invDet;
    double e = m_geoTransform[1] * invDet;
    double f = (m_geoTransform[0] * m_geoTransform[4] - m_geoTransform[1] * m_geoTransform[3]) * invDet;
    
    // Set up the world-to-pixel matrix (3x3 as 4x4)
    m_worldToPixelMatrix(0, 0) = a;
    m_worldToPixelMatrix(0, 1) = b;
    m_worldToPixelMatrix(0, 3) = c;
    
    m_worldToPixelMatrix(1, 0) = d;
    m_worldToPixelMatrix(1, 1) = e;
    m_worldToPixelMatrix(1, 3) = f;
    
    m_worldToPixelMatrix(3, 3) = 1.0;
    
    // Create the pixel-to-world matrix
    m_pixelToWorldMatrix.setToIdentity();
    
    // Set up the pixel-to-world matrix (3x3 as 4x4)
    m_pixelToWorldMatrix(0, 0) = m_geoTransform[1];
    m_pixelToWorldMatrix(0, 1) = m_geoTransform[2];
    m_pixelToWorldMatrix(0, 3) = m_geoTransform[0];
    
    m_pixelToWorldMatrix(1, 0) = m_geoTransform[4];
    m_pixelToWorldMatrix(1, 1) = m_geoTransform[5];
    m_pixelToWorldMatrix(1, 3) = m_geoTransform[3];
    
    m_pixelToWorldMatrix(3, 3) = 1.0;
}