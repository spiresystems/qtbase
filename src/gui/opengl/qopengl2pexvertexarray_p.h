/****************************************************************************
**
** Copyright (C) 2012 Nokia Corporation and/or its subsidiary(-ies).
** All rights reserved.
** Contact: Nokia Corporation (qt-info@nokia.com)
**
** This file is part of the QtGui module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** GNU Lesser General Public License Usage
** This file may be used under the terms of the GNU Lesser General Public
** License version 2.1 as published by the Free Software Foundation and
** appearing in the file LICENSE.LGPL included in the packaging of this
** file. Please review the following information to ensure the GNU Lesser
** General Public License version 2.1 requirements will be met:
** http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Nokia gives you certain additional
** rights. These rights are described in the Nokia Qt LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU General
** Public License version 3.0 as published by the Free Software Foundation
** and appearing in the file LICENSE.GPL included in the packaging of this
** file. Please review the following information to ensure the GNU General
** Public License version 3.0 requirements will be met:
** http://www.gnu.org/copyleft/gpl.html.
**
** Other Usage
** Alternatively, this file may be used in accordance with the terms and
** conditions contained in a signed written agreement between you and Nokia.
**
**
**
**
**
** $QT_END_LICENSE$
**
****************************************************************************/

//
//  W A R N I N G
//  -------------
//
// This file is not part of the Qt API.  It exists purely as an
// implementation detail.  This header file may change from version to
// version without notice, or even be removed.
//
// We mean it.
//

#ifndef QOPENGL2PEXVERTEXARRAY_P_H
#define QOPENGL2PEXVERTEXARRAY_P_H

#include <QRectF>

#include <private/qdatabuffer_p.h>
#include <private/qvectorpath_p.h>
#include <private/qopenglcontext_p.h>

QT_BEGIN_NAMESPACE

class QOpenGLPoint
{
public:
    QOpenGLPoint(GLfloat new_x, GLfloat new_y) :
        x(new_x), y(new_y) {};

    QOpenGLPoint(const QPointF &p) :
        x(p.x()), y(p.y()) {};

    QOpenGLPoint(const QPointF* p) :
        x(p->x()), y(p->y()) {};

    GLfloat x;
    GLfloat y;

    operator QPointF() {return QPointF(x,y);}
    operator QPointF() const {return QPointF(x,y);}
};

struct QOpenGLRect
{
    QOpenGLRect(const QRectF &r)
        :  left(r.left()), top(r.top()), right(r.right()), bottom(r.bottom()) {}

    QOpenGLRect(GLfloat l, GLfloat t, GLfloat r, GLfloat b)
        : left(l), top(t), right(r), bottom(b) {}

    GLfloat left;
    GLfloat top;
    GLfloat right;
    GLfloat bottom;

    operator QRectF() const {return QRectF(left, top, right-left, bottom-top);}
};

class QOpenGL2PEXVertexArray
{
public:
    QOpenGL2PEXVertexArray() :
        vertexArray(0), vertexArrayStops(0),
        maxX(-2e10), maxY(-2e10), minX(2e10), minY(2e10),
        boundingRectDirty(true)
    { }
    
    inline void addRect(const QRectF &rect)
    {
        qreal top = rect.top();
        qreal left = rect.left();
        qreal bottom = rect.bottom();
        qreal right = rect.right();
    
        vertexArray << QOpenGLPoint(left, top)
                    << QOpenGLPoint(right, top)
                    << QOpenGLPoint(right, bottom)
                    << QOpenGLPoint(right, bottom)
                    << QOpenGLPoint(left, bottom)
                    << QOpenGLPoint(left, top);        
    }

    inline void addQuad(const QRectF &rect)
    {
        qreal top = rect.top();
        qreal left = rect.left();
        qreal bottom = rect.bottom();
        qreal right = rect.right();

        vertexArray << QOpenGLPoint(left, top)
                    << QOpenGLPoint(right, top)
                    << QOpenGLPoint(left, bottom)
                    << QOpenGLPoint(right, bottom);

    }

    inline void addVertex(const GLfloat x, const GLfloat y)
    {
        vertexArray.add(QOpenGLPoint(x, y));
    }

    void addPath(const QVectorPath &path, GLfloat curveInverseScale, bool outline = true);
    void clear();

    QOpenGLPoint*        data() {return vertexArray.data();}
    int *stops() const { return vertexArrayStops.data(); }
    int stopCount() const { return vertexArrayStops.size(); }
    QOpenGLRect         boundingRect() const;

    int vertexCount() const { return vertexArray.size(); }

    void lineToArray(const GLfloat x, const GLfloat y);

private:
    QDataBuffer<QOpenGLPoint> vertexArray;
    QDataBuffer<int>      vertexArrayStops;

    GLfloat     maxX;
    GLfloat     maxY;
    GLfloat     minX;
    GLfloat     minY;
    bool        boundingRectDirty;
    void addClosingLine(int index);
    void addCentroid(const QVectorPath &path, int subPathIndex);
};

QT_END_NAMESPACE

#endif
