//
//  TwoTouchFit.cpp
//  FiftyThreeSdk
//
//  Created by matt on 9/10/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//

#include "TwoTouchFit.h"

using namespace Eigen;

namespace fiftythree
{
namespace sdk
{

float TwoTouchFit::Fit(Stroke & Z, Stroke & W, int maxPoints, bool isPinch)
{
    int zCount = std::min((int) Z.Size(), maxPoints);
    int wCount = std::min((int) W.Size(), maxPoints);
    
    int M      =  zCount + wCount;
    
    MatrixXf A(M, 3);
    MatrixXf b(M, 2);

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
    
        tZ = Vector2f(Z.X(iz), Z.Y(iz));
        tW = Vector2f(W.X(0), W.Y(0));
    }
    else
    {
        int iw = W.IndexClosestToTime(Z.FirstAbsoluteTimestamp());
        
        tZ = Vector2f(Z.X(0), Z.Y(0));
        tW = Vector2f(W.X(iw), W.Y(iw));
    }
    
    // we assume Z and W are basically symmetric about some line.
    // use the line joining the endpoints...

    Vector2f v   = Z.XY(0) - W.XY(0);
    v          = Vector2f(-v.y(), v.x()).normalized();
    
    Matrix2f R;
    
    // Eigen doesn't have built-in reflections?
    R(0,0) = v.x() * v.x() - v.y() * v.y();
    R(1,1) = - R(0,0);
    R(0,1) = 2.0f * v.x() * v.y();
    R(1,0) = R(0,1);
    
    
    // assemble our matrix A of evaluation times.  rank of A is uncertain
    // and probably contains all sorts of duplication in most cases of interest.
    // and RHS matrix b.  b(:,1) is x-coords, b(:,2) is y-coords.
    int m = 0;
    for(int j=0; j<zCount; j++)
    {
        float t = Z.RelativeTimestamp(j);
        
        A(m, 0) = t * t;
        A(m, 1) = t;
        A(m, 2) = 1;
        
        b(m, 0) = Z.X(j) - tZ.x();
        b(m, 1) = Z.Y(j) - tZ.y();
        
        ++m;
    }
    
    for(int k=0; k<wCount; k++)
    {
        float t = W.RelativeTimestamp(k);
        
        A(m, 0) = t * t;
        A(m, 1) = t;
        A(m, 2) = 1;
        
        Vector2f bw = W.XY(k) - tW;
        if(isPinch)
        {
            bw = R*bw;
        }
        
        b(m, 0) = bw.x();
        b(m, 1) = bw.y();
        
        ++m;
    }
    
    MatrixXf coeff = A.colPivHouseholderQr().solve(b);
    
    float dZ = (Z.XY(zCount-1) - Z.XY(0)).norm();
    float dW = (W.XY(zCount-1) - W.XY(0)).norm();
    
    float norm = dZ + dW;
    
    float residualSquared = (A * coeff - b).squaredNorm() / (norm * norm);

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
    
    float kt  = (xp * ypp - yp * xpp) / (speed * speed * speed);
    
    if(Z.Size() >= maxPoints && W.Size() >= maxPoints)
    {
        std::cerr << "\n" << M << ": residual = " << std::sqrt(residualSquared) << ", kappa = " << kt;
    }
    return residualSquared;
    
    
}
    

}
}

