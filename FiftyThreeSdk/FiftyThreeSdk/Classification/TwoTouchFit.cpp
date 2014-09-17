//
//  TwoTouchFit.cpp
//  FiftyThreeSdk
//
//  Created by matt on 9/10/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//

#include <iomanip>

#include "TwoTouchFit.h"

using namespace Eigen;

namespace fiftythree
{
namespace sdk
{

    
float TwoTouchFit::FitPinch(Stroke & zIn, Stroke & wIn, int minPoints, int maxPoints)
{
    return Fit(zIn, wIn, minPoints, maxPoints, true);
}


float TwoTouchFit::FitPan(Stroke & zIn, Stroke & wIn, int minPoints, int maxPoints)
{
    return Fit(zIn, wIn, minPoints, maxPoints, false);
}

    
float TwoTouchFit::Fit(Stroke & zIn, Stroke & wIn, int minPoints, int maxPoints, bool isPinch)
{
    _sizeOKFlag = false;
    if(zIn.Size() < minPoints || wIn.Size() < minPoints)
    {
        return 0.0f;
    }
    _sizeOKFlag = true;
    
    // both have at least minPoints
    int zCount = std::min((int) zIn.Size(), maxPoints);
    int wCount = std::min((int) wIn.Size(), maxPoints);
    
    // make copies, since we're going to mess with the leading point
    Stroke Z = zIn.SubStroke(Interval(0, zCount));
    Stroke W = wIn.SubStroke(Interval(0, wCount));
    
    // the first point is pretty much garbage, so our measurements can get dominated by noise,
    // especially in the motivating case which is very early gesture detection.
    if(isPinch)
    {
        Z.DenoiseFirstPoint(1.0f);
        W.DenoiseFirstPoint(1.0f);
    }
    
    ConstructProblem(Z, W, zCount, wCount, isPinch);
    
    MatrixXf coeff = (_weight*_A).jacobiSvd(ComputeThinU | ComputeThinV).solve(_weight*_b);
    
    float varZ = (_weight.block(0, 0, zCount, zCount) * _b.block(0, 0, zCount, 2)).squaredNorm();
    float varW = (_weight.block(zCount, zCount, wCount, wCount) * _b.block(zCount, 0, wCount, 2)).squaredNorm();

    float varTotal = varZ + varW;
    float residual = (_weight * _A * coeff - _weight * _b).squaredNorm();
    
    float rSquared = 0.0f;
    if(varTotal > 0.0f)
    {
        float sampleSize = zCount + wCount;
        float adjustment = (sampleSize - 1.0f) / (sampleSize - 2.0f);
        rSquared = 1.0f - adjustment * residual / varTotal;
    }

    Vector2f vZ = Z.LastPoint() - Z.FirstPoint();
    Vector2f vW = W.LastPoint() - W.FirstPoint();

    Vector2f dZ = vZ.normalized();
    Vector2f dW = vW.normalized();

    
    float score;
    float dirGoodness;
    if (isPinch)
    {
        
        
        // we want motion in opposite directions, orthogonal to the line of symmetry
        float    dotZ     = dZ.dot(_targetDirection);
        float    dotW     = dW.dot(_targetDirection);

        // pinch in and out seem to be very different WRT typical angles.
        // pinches which start big are nearly diametrically opposed.
        // pinches which start small tend to make a shallower angle.
        // TODO: learn this distribution, if it actually helps to do so.
        // but consider that we might do better if we are stricter.

        dirGoodness = std::max(0.0f, -dotZ * dotW);
        dirGoodness = std::sqrt(dirGoodness);
        float targetDot = .75f;
        if(_scale < 1.0f)
        {
            targetDot = .95f;
        }
        else
        {
            targetDot = .75f;
        }
        
        float dirError = dirGoodness - targetDot;
        if (dirError < 0.0f)
        {
            // ensure we go to zero when dots are actually zero, i.e. orthogonal motion.
            dirError /= targetDot;
        }
        else
        {
            // don't penalize for being closer to ideal opposite motion
            dirError = 0.0f;
        }
        
        dirGoodness = 1.0f - std::abs(dirError);
        
        score = dirGoodness * rSquared;
    }
    else
    {
        // we want motion in the same direction, we don't really care about the relative touch locations
        float dot = dZ.dot(dW);
        
        // we want dotZ * dotW to be close to 1 if we have our target motion.
        // dirGoodness will be 1 in the best case and drops to zero by the time the motion is 90-degrees.
        dirGoodness = std::max(0.0f, dot);
        
        score = dirGoodness * rSquared;
    }

    // and a regularization -- very short strokes are unstable.  we get lousy measurements.
    // ignore strokes shorter than 1 points entirely, and then ramp up until we have length 3
    float zLengthReg = std::max(0.0f, std::min(1.0f, (vZ.norm() - 1.0f) / 2.0f));
    float wLengthReg = std::max(0.0f, std::min(1.0f, (vW.norm() - 1.0f) / 2.0f));
    
    score *= zLengthReg * wLengthReg;
    
    
    _ax = coeff(0,0);
    _bx = coeff(1,0);
    _cx = coeff(2,0);

    _ay = coeff(0,1);
    _by = coeff(1,1);
    _cy = coeff(2,1);

    float tOffsetW  = _A(zCount, 1);
    float tW1       = W.RelativeTimestamp(wCount-1) + tOffsetW;
    float tZ1       = Z.RelativeTimestamp(zCount-1);
    
    float tMin  = std::min(0.0f, tOffsetW);
    float tEval = .5f * (tW1 + tZ1);
    float tMax  = std::max(tW1, tZ1);
    
    float dtMax = 0.0f;
    for(int j=1; j<zCount; j++)
    {
        float dt = Z.RelativeTimestamp(j) - Z.RelativeTimestamp(j-1);
        if(dt > dtMax)
        {
            dtMax = dt;
        }
    }

    for(int j=1; j<wCount; j++)
    {
        float dt = W.RelativeTimestamp(j) - W.RelativeTimestamp(j-1);
        if(dt > dtMax)
        {
            dtMax = dt;
        }
    }

    
    float kt    = std::max(std::max(std::abs(Curvature(tMin)), std::abs(Curvature(tEval))), std::abs(Curvature(tMax)));
    
    int minSize = (int) std::min(Z.Size(), W.Size());
    int maxSize = (int) std::max(Z.Size(), W.Size());

    if(true) //minSize >= 3 && maxSize >= 3 && maxSize <= 4)
    {
        std::cerr << std::setprecision(3);
        std::cerr << "\nscore = " << score << ": (" << zCount << ", " << wCount << "), r2 = " << rSquared << ", dir = " << dirGoodness << ", varRatio = " << std::log(varW / varZ)  << ", scale = " << _scale << ", |vZ| = " << vZ.norm() << ", |vW| = " << vW.norm() << ", dt = " << dtMax;
    }
    
    _score = score;
    
    return _score;
    
    
}
    
void TwoTouchFit::ConstructProblem(Stroke & Z, Stroke & W, int zCount, int wCount, bool doReflection)
{
    
    int M      =  zCount + wCount;
    
    _A.resize(M, 3);
    _b.resize(M, 2);
    
    
    _weight = MatrixXf::Identity(M, M);
    
    // we'll use a smallish weight on the ell^2 error.  use more weight on the derivatives.
    // todo: investigate using delta-t in addition to simply finite differences.
    // this is the sort of thing we really need training data to tune in.
    
    float d1weight = 0.0f;
    float d2weight = 0.0f;
    
    if(doReflection)
    {
        d1weight = 1.0f;
        d2weight = .25f;
        
        _weight *= .25;
    }
    else
    {
        d2weight = 1.0f;
        d1weight = 1.0f;
    }

    
    Vector2f tZ;
    Vector2f tW;
    
    //
    // Align matching points so the first time-aligned point on each curve goes to (0,0).
    //
    // if W's first timestamp happened after Z began, assume that W_0 happened while
    // Z was still being rendered, and we'll do our fit normalized so W_0 and the corresponding
    // point on Z are normalized to zero.  and vice-versa.
    // if the two strokes don't overlap in time, this degenerates and the fit will likely
    // be awful, which is probably what we want.
    if(W.FirstAbsoluteTimestamp() > Z.FirstAbsoluteTimestamp())
    {
        
        int iz = Z.IndexClosestToTime(W.FirstAbsoluteTimestamp());
        tZ = Z.XY(iz);
        tW = W.XY(0);
    }
    else
    {
        int iw = W.IndexClosestToTime(Z.FirstAbsoluteTimestamp());
        
        tZ = Z.XY(0);
        tW = W.XY(iw);
    }

    if(doReflection)
    {
        //tZ = Z.XY(0);
        //tW = W.XY(0);
    }
    
    
    
    // this will make a copy so we don't mess with the underlying vectors when we subtract
    MatrixX2f xyZ = Z.XYMatrixMap(zCount - 1);
    MatrixX2f xyW = W.XYMatrixMap(wCount - 1);
    
    xyZ -= tZ.transpose().replicate(zCount, 1);
    xyW -= tW.transpose().replicate(wCount, 1);
    
    Vector2f v0       = Z.XY(0) - W.XY(0);
    Vector2f vN       = Z.LastPoint() - W.LastPoint();
    
    Vector2f vEndpoints;
    _scale = 1.0f;
    if(v0.norm() > 0.0f)
    {
        _scale = vN.norm() / v0.norm();
    }
    
    if(_scale > 1.0f)
    {
        vEndpoints = vN;
    }
    else
    {
        vEndpoints = v0;
    }
    vEndpoints.normalize();
    
    
    // normalize W so the last point has the same norm as the last point on Z.
    // accounts for changes in length, which can be dramatically unstable for pinches.
    // does not seem to be necessary for pan.
    float scale = 1.0f;
    
    if(doReflection)
    {
        scale = xyZ.row(zCount-1).norm() / xyW.row(wCount-1).norm();
    }
    
    Matrix2f T = Matrix2f::Identity() * scale;
    
    if(doReflection)
    {
        
        // we assume Z and W are basically symmetric about some line.
        // use the line joining the furthest endpoints for now.
        // we could solve for the optimal reflection as well, but this likely will do worse since
        // it'll let lousy data look better than it should.
        
        // reflect about the perp to the endpoints
        _targetDirection   = vEndpoints;
        _axisOfSymmetry    = Vector2f(-_targetDirection.y(), _targetDirection.x()).normalized();
        
        Matrix2f R;
        
        Vector2f v = _axisOfSymmetry;
        // Eigen doesn't have built-in reflections?
        R(0,0) = v.x() * v.x() - v.y() * v.y();
        R(1,1) = - R(0,0);
        R(0,1) = 2.0f * v.x() * v.y();
        R(1,0) = R(0,1);
        
        T = R * T;
        
    }
    
    
    
    // assemble our matrix A of evaluation times,
    // and RHS matrix b.  b(:,1) is x-coords, b(:,2) is y-coords.
    int m = 0;
    for(int j=0; j<zCount; j++)
    {
        float t = Z.RelativeTimestamp(j);
        
        _A(m, 0) = t * t;
        _A(m, 1) = t;
        _A(m, 2) = 1;
        
        _b(m, 0) = xyZ(j,0);
        _b(m, 1) = xyZ(j,1);
        
        if(j>0)
        {
            _weight(m,m-1) += -d1weight;
            _weight(m,m)   +=  d1weight;
        }
        
        if(j>1)
        {
            _weight(m,m-2)   +=  d2weight;
            _weight(m,m-1)   += -2.0f * d2weight;
            _weight(m,m)     +=  d2weight;
        }
        
        ++m;
    }
    
    // the touches probably didn't begin at the same time, so we need to compute the offset
    // so we fit the curve at the correct relative timestamps.
    float tOffsetW = W.FirstAbsoluteTimestamp() - Z.FirstAbsoluteTimestamp();
    for(int k=0; k<wCount; k++)
    {
        float t = W.RelativeTimestamp(k) + tOffsetW;
        
        _A(m, 0) = t * t;
        _A(m, 1) = t;
        _A(m, 2) = 1;
        
        Vector2f bw = T * xyW.row(k).transpose();
        
        _b(m, 0) = bw.x();
        _b(m, 1) = bw.y();

        if(k>0)
        {
            _weight(m,m-1) += -d1weight;
            _weight(m,m)   +=  d1weight;
        }
        
        if(k>1)
        {
            _weight(m,m-2)   +=  d2weight;
            _weight(m,m-1)   += -2.0f * d2weight;
            _weight(m,m)     +=  d2weight;
        }

        ++m;
    }
}
    

float TwoTouchFit::Curvature(float relativeTimestamp)
{
    // curvature of a parametric plane curve (x(t), y(t)) is given by
    //
    // x'*y'' - y'*x'' / (speed ^ 3)
    //
    // where speed is sqrt(x'^2 + y'^2)
    //
    // we have
    //
    // x = at^2 + bt + c
    //
    // hence we have:

    float t  = relativeTimestamp;
    
    float xp = 2.0f * _ax * t + _bx;
    float yp = 2.0f * _ay * t + _by;
    
    float xpp = 2.0f * _ax;
    float ypp = 2.0f * _ay;
    
    float speed = std::sqrt(xp*xp + yp*yp);
    
    float kt   = (xp * ypp - yp * xpp) / (speed * speed * speed);
    
    return kt;
}
    

}
}

