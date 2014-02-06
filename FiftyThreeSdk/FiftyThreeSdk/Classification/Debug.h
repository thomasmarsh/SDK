//
//  Debug.h
//  Classification
//
//  Created by Akil Narayan on 2013/10/23.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//
//  All the methods here are only invoked for debugging in the constructor for
//  ClassificationProxy. This can be safely removed so long as those
//  invocations are removed.

#pragma once

#include <iostream>
#include "IsolatedStrokes.h"
#include "LinAlgHelpers.h"
#include "LineFitting.h"

using namespace fiftythree::classification;

namespace fiftythree {
namespace classification {
namespace debug {

    Eigen::VectorXd StrokeT(int);
    Eigen::VectorXf StrokeX(int);
    Eigen::VectorXf StrokeY(int);
    Eigen::VectorXf StrokeScores(int);

    //void FDTest();

    //void FDStencil();
    //void StencilStorage();

    void PrintVector(std::vector<int>);

    void EtaModelTest(IsolatedStrokesClassifier*);
    void WeakScoreTest(TouchLogger*, IsolatedStrokesClassifier*);
    void ChosenWeakScoreTest(TouchLogger*, IsolatedStrokesClassifier*);
    void LogLikelihoodsTest(TouchLogger*, IsolatedStrokesClassifier*);
    void ScoreOutput(TouchLogger*, IsolatedStrokesClassifier*);

    ////////////////////////////////////////////////////////////////
    //           Debugging for LinAlgHelpers                      //
    ////////////////////////////////////////////////////////////////

    void VectorComparison(Eigen::VectorXf v, Eigen::VectorXf w);
    
    Eigen::MatrixXf LeastSquaresMatrixData(int testId);
    Eigen::VectorXf LeastSquaresRHSData(int testId);
    Eigen::VectorXf LeastSquaresWeights(int testId);
    Eigen::VectorXf LeastSquaresSolution(int testId);
    Eigen::VectorXf WeightedLeastSquaresSolution(int testId);
   
    // Verifies LS solution of A*x = b
    void LeastSquaresTest();
    // Verifies weighted LS solution of A*x = b
    void WeightedLeastSquaresTest();

    Eigen::MatrixX2f LineFitData(int testId);
    Eigen::VectorXf LineFitParameterData(int testId);

    Eigen::Matrix<float, 3, 1> GeometricLineFitSolution(int testId);
    float                      GeometricLineFitResidual(int testId);
    Eigen::Matrix<float, 3, 1> LinearParamLineFitSolution(int testId);
    float                      LinearParamLineFitResidual(int testId);

    // Verifies line-fitting
    void GeometricLineFitTest();
    void LinearParameterizationLineFitTest();

}
}
}
