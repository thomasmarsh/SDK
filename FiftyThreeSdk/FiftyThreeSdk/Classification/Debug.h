//
//  Debug.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "FiftyThreeSdk/Classification/IsolatedStrokes.h"
#include "FiftyThreeSdk/Classification/LinAlgHelpers.h"
#include "FiftyThreeSdk/Classification/LineFitting.h"

namespace fiftythree
{
namespace sdk
{
namespace debug
{
Eigen::VectorXd StrokeT(int);
Eigen::VectorXf StrokeX(int);
Eigen::VectorXf StrokeY(int);
Eigen::VectorXf StrokeScores(int);

void PrintVector(std::vector<int>);

void EtaModelTest(IsolatedStrokesClassifier*);
void WeakScoreTest(TouchLogger*, IsolatedStrokesClassifier*);
void ChosenWeakScoreTest(TouchLogger*, IsolatedStrokesClassifier*);
void LogLikelihoodsTest(TouchLogger*, IsolatedStrokesClassifier*);
void ScoreOutput(TouchLogger*, IsolatedStrokesClassifier*);

//
//           Debugging for LinAlgHelpers                      //
//

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
