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

float TwoTouchFit::Fit(Stroke & Z, Stroke & W, int minPoints, int maxPoints, bool isPinch)
{
    if(Z.Size() < minPoints || W.Size() < minPoints)
    {
        return 0.0f;
    }
    
    // both have at least minPoints
    int zCount = std::min((int) Z.Size(), maxPoints);
    int wCount = std::min((int) W.Size(), maxPoints);
    
    int M      =  zCount + wCount;
    
    MatrixXf A(M, 3);
    MatrixXf b(M, 2);
    MatrixXf weight = MatrixXf::Identity(M, M);

    Vector2f tZ;
    Vector2f tW;
    
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
    
    // we assume Z and W are basically symmetric about some line.
    // use the line joining the furthest endpoints for now.
    // we could solve for the optimal reflection as well.

    Vector2f v0       = Z.XY(0) - W.XY(0);
    Vector2f vN       = Z.LastPoint() - W.LastPoint();
    
    Vector2f vEndpoints;
    float scale = 1.0f;
    if(v0.norm() > 0.0f)
    {
        scale = vN.norm() / (.0001 + v0.norm());
    }
    
    
    if(scale > 1.0f)
    {
        vEndpoints = vN;
    }
    else
    {
        vEndpoints = v0;
    }
    vEndpoints.normalize();
    
    Vector2f dZ = (Z.XY(zCount-1) - Z.XY(0)).normalized();
    Vector2f dW = (W.XY(wCount-1) - W.XY(0)).normalized();

    // reflect about the line of symmetry that bisects the angle made by the two average direction vectors
    Vector2f dSymmetry   = (dZ - dW).normalized();
    dSymmetry            = Vector2f(-dSymmetry.y(), dSymmetry.x());
    
    Matrix2f R;
    
    Vector2f v = dSymmetry;
    // Eigen doesn't have built-in reflections?
    R(0,0) = v.x() * v.x() - v.y() * v.y();
    R(1,1) = - R(0,0);
    R(0,1) = 2.0f * v.x() * v.y();
    R(1,0) = R(0,1);

    // this will make a copy so we don't mess with the underlying vectors when we subtract
    MatrixX2f xyZ = Z.XYMatrixMap(zCount - 1);
    MatrixX2f xyW = W.XYMatrixMap(wCount - 1);
    
    xyZ -= tZ.transpose().replicate(zCount, 1);
    xyW -= tW.transpose().replicate(wCount, 1);
    
    
    // assemble our matrix A of evaluation times,
    // and RHS matrix b.  b(:,1) is x-coords, b(:,2) is y-coords.
    int m = 0;
    for(int j=0; j<zCount; j++)
    {
        float t = Z.RelativeTimestamp(j);
        
        A(m, 0) = t * t;
        A(m, 1) = t;
        A(m, 2) = 1;
        
        b(m, 0) = xyZ(j,0);
        b(m, 1) = xyZ(j,1);
        
        ++m;
    }

    // give less weight to the first point on each stroke since there's a lot of noise
    // in the first sample.  Calling it crap is an insult to fertilizer.
    weight(0,0) = .25f;
    weight(zCount,zCount) = .25f;
    
    float tOffsetW = W.FirstAbsoluteTimestamp() - Z.FirstAbsoluteTimestamp();
    for(int k=0; k<wCount; k++)
    {
        float t = W.RelativeTimestamp(k) + tOffsetW;
        
        A(m, 0) = t * t;
        A(m, 1) = t;
        A(m, 2) = 1;
        
        Vector2f bw = xyW.row(k);
        if(isPinch)
        {
            bw = R*bw;
        }
        
        b(m, 0) = bw.x();
        b(m, 1) = bw.y();
        
        ++m;
    }
    
    MatrixXf coeff = (weight*A).colPivHouseholderQr().solve(weight*b);
    
    float varZ = (weight.block(0, 0, zCount, zCount) * xyZ).squaredNorm();
    float varW = (weight.block(zCount, zCount, wCount, wCount) * xyW).squaredNorm();

    float varTotal = varZ + varW;
    float residual = (weight * A * coeff - weight * b).squaredNorm();
    
    float rSquared = 0.0f;
    if(varTotal > 0.0f)
    {
        rSquared = 1.0f - residual / varTotal;
    }
    
    Vector2f vZ = Z.XY(zCount-1) - Z.XY(0);
    Vector2f vW = W.XY(wCount-1) - W.XY(0);
    
    float score;
    float dirGoodness;
    if (isPinch)
    {
        // we want motion in opposite directions, orthogonal to the line of symmetry
        Vector2f vTarget = vEndpoints;
        //Vector2f vTarget(-dSymmetry.y(), dSymmetry.x());


        float    dotZ     = vZ.dot(vTarget) / vZ.norm();
        float    dotW     = vW.dot(vTarget) / vW.norm();

        // pinch in and out seem to be very different WRT typical angles.
        // pinches which start big are nearly diametrically opposed.
        // pinches which start small tend to make a shallower angle.
        // TODO: learn this distribution, if it actually helps to do so.
        // but consider that we might do better if we are stricter.

        dirGoodness = std::max(0.0f, -dotZ * dotW);
        dirGoodness = std::sqrt(dirGoodness);
        float targetDot = .75f;
        if(scale < 1.0f)
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
        
        dirGoodness = 1.0f - std::abs(dirError);
        
        score = dirGoodness * rSquared;
    }
    else
    {
        // we want motion in the same direction, we don't really care about the relative touch locations
        float dot = vZ.dot(vW) / (vZ.norm() * vW.norm());
        
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

    float tEval = .5f * (W.RelativeTimestamp(wCount-1) + Z.RelativeTimestamp(zCount-1));
    
    float xp = 2.0f * _ax * tEval + _bx;
    float yp = 2.0f * _ay * tEval + _by;
    
    float xpp = 2.0f * _ax;
    float ypp = 2.0f * _ay;
    
    float speed = std::sqrt(xp*xp + yp*yp);
    
    // TODO: consider scale-invariant quantities (or not)
    // multiplying by size is one way to get a unitless quantity, but there may be better
    // ways to use this information.  especially at small sizes where there's a lot of noise.
    //float size = std::sqrt(vZ.norm() * vW.norm());
    float kt   = (xp * ypp - yp * xpp) / (speed * speed * speed);
    
    int minSize = (int) std::min(Z.Size(), W.Size());
    int maxSize = (int) std::max(Z.Size(), W.Size());

    if(minSize >= 3 && maxSize >= 3 && maxSize <= 4)
    {
        std::cerr << std::setprecision(3);
        std::cerr << "\n" << M << ": score = " << score << ", r2 = " << rSquared << ", dir = " << dirGoodness << ", kappa = " << kt  << ", scale = " << scale << ", |vZ| = " << vZ.norm() << ", |vW| = " << vW.norm();
    }
    return score;
    
    
}
    

}
}

