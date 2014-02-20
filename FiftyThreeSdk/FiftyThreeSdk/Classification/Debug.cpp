//
//  Debug.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <ctime>

#include "FiftyThreeSdk/Classification//EigenLAB.h"
#include "FiftyThreeSdk/Classification//Stroke.h"
#include "FiftyThreeSdk/Classification/Debug.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"

using fiftythree::common::TouchId;

namespace fiftythree {
namespace sdk {
namespace debug {

Eigen::VectorXd StrokeT(int strokeId) {

    Eigen::VectorXd output;

    switch(strokeId) {
        case 1: {
            output.resize(6);
            output << 902695.13605475,
                      902695.152537001,
                      902695.168736208,
                      902695.185594126,
                      902695.202385958,
                      902695.219172295;
            break;
        }

        case 2: {
            // Stroke data: q = 1, qq = 266
            output.resize(19);
            output << 92284.330490208,
                      92284.3475750003,
                      92284.3633808333,
                      92284.3802717503,
                      92284.3973774973,
                      92284.4301572505,
                      92284.4471505794,
                      92284.4636286262,
                      92284.4802723292,
                      92284.4972089145,
                      92284.5134505394,
                      92284.5302231226,
                      92284.5472081664,
                      92284.5636889103,
                      92284.5803465012,
                      92284.5972803894,
                      92284.6134936574,
                      92284.6303959552,
                      92284.6464960042;
            break;
        }

        case 3: {
            output.resize(7);
            output << 605707.356568541,
                      605707.372637791,
                      605707.388609375,
                      605707.405950375,
                      605707.421909082,
                      605707.437931958,
                      605707.454811331;
            break;
        }
        default:
            DebugAssert(false);
    }

    return output;

}

Eigen::VectorXf StrokeX(int strokeId) {
    Eigen::VectorXf output;

    switch(strokeId) {
        case 1:  {
            output.resize(6);
            output <<
                           632,
                         634.5,
                         634.5,
                         635.5,
                         636.5,
                         638.5;
            break;
        }

        case 2:  {
            output.resize(19);
            output <<
                           614,
                           612,
                           615,
                         614.5,
                         612.5,
                           613,
                         612.5,
                           612,
                         604.5,
                         602.5,
                           607,
                         609.5,
                         614.5,
                           616,
                           617,
                           618,
                         619.5,
                           629,
                           629;
            break;
         }

        case 3: {
            output.resize(7);
            output <<
                   463,
                   461,
                   460,
                   459,
                   459,
                   461,
                   463;
            break;
                }
        default:
            DebugAssert(false);
    }

    return output;

}

Eigen::VectorXf StrokeY(int strokeId) {

    Eigen::VectorXf output;

    switch(strokeId) {
        case 1: {
            output.resize(6);
            output <<
                        383.5,
                         376.5,
                           368,
                           360,
                         344.5,
                         330.5;
            break;
        }

        case 2: {
            output.resize(19);
            output <<
                           552,
                         552.5,
                           554,
                           554,
                           554,
                         552.5,
                           553,
                         553.5,
                           549,
                         548.5,
                           558,
                           560,
                           564,
                         564.5,
                         566.5,
                           567,
                         568.5,
                         577.5,
                         577.5;
            break;
        }

        case 3: {
            output.resize(7);
            output <<
                   226,
                   237,
                   273,
                   317,
                   353,
                   368,
                   370;
            break;
        }

        default:
            DebugAssert(false);
    }

    return output;

}

Eigen::VectorXf StrokeScores(int strokeId) {

    Eigen::VectorXf output;
    output.resize(10);

    switch(strokeId) {
        case 1: {
            output <<
                   17.9739,
                  -10.4239,
                   16.3904,
                   -0.3116,
                  -14.2552,
                  -20.1366,
                   -4.0102,
                    1.9522,
                    7.1496,
                   -3.0518;
        }

        case 2: {
            output <<
                       19.8879,
                       -8.1278,
                       18.0543,
                        4.1902,
                      -11.9602,
                      -16.2204,
                       -3.1246,
                        5.1137,
                        9.6527,
                       -2.4928;
            break;
        }

        case 3: {
            output <<
                   18.0270,
                  -12.3064,
                   14.9966,
                    0.2632,
                  -13.9540,
                  -23.6318,
                   -4.6429,
                    2.5542,
                    6.9941,
                   -4.3824;
            break;
        }
        default:
            DebugAssert(false);
    }

    return output;

}

void EtaModelTest(IsolatedStrokesClassifier* isolatedStrokesClassifier) {

    float alpha = 0.02;
    float etas[] = {
           -2.608,
           -2.392,
           -2.332,
           -2.439,
           -2.234,
           -2.392,
           -2.025,
           -2.158,
           -1.982,
           -1.551,
           -2.383,
           -1.327
    };

    std::cout << "The computed vs real etas are:\n";
    for (int i = 0; i < 12; ++i) {
        std::cout << isolatedStrokesClassifier->EtaEvaluation(alpha, i) << "        vs        " << etas[i] << std::endl;
    }

}

void WeakScoreTest(TouchLogger* touchLog, IsolatedStrokesClassifier* isolatedStrokesClassifier) {

    TouchId touchId = static_cast<TouchId>(1);
    Eigen::VectorXd t = StrokeT(2);
    Eigen::VectorXf x = StrokeX(2);
    Eigen::VectorXf y = StrokeY(2);

    touchLog->InsertStroke(touchId, t, x, y);
    //isolatedStrokesClassifier->UpdateIsolatedScores(touchId);
    Stroke::Ptr stroke = touchLog->Stroke(touchId);

    Eigen::VectorXf scores = isolatedStrokesClassifier->ScoresForId(touchId);

    std::cout << "The weak chosen scores are:\n";
    for (int i =0; i < scores.size(); ++i) {
        std::cout << scores(i) << std::endl;
    }

    touchLog->DeleteTouchId(touchId);
}

void ChosenWeakScoreTest(TouchLogger* touchLog, IsolatedStrokesClassifier* isolatedStrokesClassifier) {

    TouchId touchId = static_cast<TouchId>(1);
    Eigen::VectorXd t = StrokeT(2);
    Eigen::VectorXf x = StrokeX(2);
    Eigen::VectorXf y = StrokeY(2);

    touchLog->InsertStroke(touchId, t, x, y);
    Stroke::Ptr stroke = touchLog->Stroke(touchId);

    Eigen::VectorXf scores = isolatedStrokesClassifier->ScoresForId(touchId);

    Eigen::VectorXf exactScores = StrokeScores(2);

    std::cout << "Chosen weak score, log-scaled and normalized test" << std::endl;
    VectorComparison(exactScores, scores);

    Eigen::VectorXf t2 = touchLog->Stroke(touchId)->RelativeTimestampMap();
    std::cout << "Value of t(0) is " << t2(0) << std::endl;
    t2(0) = 35.0;
    std::cout << "Value of t(0) is " << t2(0) << std::endl;

    touchLog->DeleteTouchId(touchId);
}

void LogLikelihoodsTest(TouchLogger* touchLog, IsolatedStrokesClassifier* isolatedStrokesClassifier) {

    TouchId touchId = static_cast<TouchId>(1);
    Eigen::VectorXd t = StrokeT(2);
    Eigen::VectorXf x = StrokeX(2);
    Eigen::VectorXf y = StrokeY(2);

    touchLog->InsertStroke(touchId, t, x, y);
    //touchLog->UpdateIsolatedData(touchId);

    Eigen::MatrixXf ll = isolatedStrokesClassifier->StrokeLogLikelihoods(touchId);
    ll = isolatedStrokesClassifier->StrokeLogLikelihoods(touchId);
    std::cout << "Log-likelihoods: " << ll << std::endl;

    touchLog->DeleteTouchId(touchId);
}

//void FDTest() {
//    Eigen::VectorXd t = StrokeT(2);
//    Eigen::VectorXf x = StrokeX(2);
//    Eigen::VectorXf y = StrokeY(2);
//
//    Eigen::MatrixX2f xy;
//    xy.resize(x.rows(), 2);
//    xy.block(0,0,x.rows(),1) = x;
//    xy.block(0,1,x.rows(),1) = y;
//
//    Eigen::MatrixX2f dxy;
//    Eigen::MatrixX2f dxy2;
//    Eigen::MatrixX2f oldDxy;
//
//    std::clock_t start;
//    double duration;
//    start = std::clock();
//
//    for (int i = 0; i < 500; ++i) {
//        dxy = Eigen::MatrixXf::Zero(x.rows(), 2);
//        dxy.resize(x.rows(), 2);
//        Derivative(t, xy, dxy, 3);
//    }
//
//    duration = ( std::clock() - start ) / (500 * (double) CLOCKS_PER_SEC);
//
//    std::clock_t start2;
//    double duration2;
//    start2 = std::clock();
//
//    for (int i = 0; i < 500; ++i) {
//        dxy2 = xy;
//        IncrementalDerivative(t, dxy2, 0, 1);
//        IncrementalDerivative(t, dxy2, 1, 2);
//        IncrementalDerivative(t, dxy2, 2, 3);
//    }
//
//    duration2 = ( std::clock() - start2 ) / (500 * (double) CLOCKS_PER_SEC);
//
//
//    std::clock_t startOld;
//    double durationOld;
//    startOld = std::clock();
//
//    for (int i = 0; i < 500; ++i) {
//        oldDxy = NthDerivative(t, xy, 3);
//    }
//
//    durationOld = ( std::clock() - startOld ) / (500 * (double) CLOCKS_PER_SEC);
//
//    std::cout << "Error is " << std::sqrt((oldDxy - dxy).array().square().sum())/std::sqrt(oldDxy.array().square().sum()) << std::endl;
//    std::cout << "Error2 is " << std::sqrt((oldDxy - dxy2).array().square().sum())/std::sqrt(oldDxy.array().square().sum()) << std::endl;
//
//    std::cout << "Elapsed time is " << duration << " and elapsed time 2 is " << duration2 << " and elapsed old time is " << durationOld << std::endl;
//}

//void FDStencil() {
//
//    std::vector<int> stencil;
//    stencil.push_back(-2);
//    stencil.push_back(1);
//    stencil.push_back(-1);
//    stencil.push_back(0);
//
//    BoundaryStencil bdstencil = GhostPointStencils(stencil);
//
//    int location;
//    std::vector<int> localStencil;
//
//    std::cout << "For stencil ";
//    for (int i = 0; i < stencil.size(); ++i) {
//        std::cout << stencil[i] << " ";
//    }
//    std::cout << std::endl;
//
//    for (int i = 0; i < bdstencil.size(); ++i) {
//        location = bdstencil[i].first;
//        localStencil = bdstencil[i].second;
//
//        std::cout << "At location " << location << " stencil is \n";
//        for (int ii = 0; ii < localStencil.size(); ++ii){
//            std::cout << localStencil[ii] << std::endl;
//        }
//    }
//
//    ////////// New stencil
//
//    stencil.pop_back();
//    stencil[0] = 1;
//    stencil[1] = -1;
//    stencil[2] = 0;
//
//    bdstencil = GhostPointStencils(stencil);
//
//    std::cout << "For stencil ";
//    for (int i = 0; i < stencil.size(); ++i) {
//        std::cout << stencil[i] << " ";
//    }
//    std::cout << std::endl;
//
//    for (int i = 0; i < bdstencil.size(); ++i) {
//        location = bdstencil[i].first;
//        localStencil = bdstencil[i].second;
//
//        std::cout << "At location " << location << " stencil is \n";
//        for (int ii = 0; ii < localStencil.size(); ++ii){
//            std::cout << localStencil[ii] << std::endl;
//        }
//    }
//
//}

void PrintVector(std::vector<int> vec) {
    for (int i = 0; i < vec.size(); ++i) {
        std::cout << vec[i] << ", ";
    }
    std::cout << std::endl;
}

//void StencilStorage() {
//
//    InitializeDifferenceStencils();
//
//    std::vector<int> stencil = DividedDifferenceStencil(3);
//    std::cout << "stencil for order 3:\n";
//    PrintVector(stencil);
//
//    int location;
//    std::vector<int> localStencil;
//
//    BoundaryStencil bdstencil = GhostPointStencils(stencil);
//    for (int i = 0; i < bdstencil.size(); ++i) {
//        location = bdstencil[i].first;
//        localStencil = bdstencil[i].second;
//
//        std::cout << "At location " << location << " stencil is \n";
//        PrintVector(localStencil);
//    }
//}

void ScoreOutput(TouchLogger* touchLog, IsolatedStrokesClassifier* isolatedStrokesClassifier) {
    TouchId touchId = static_cast<TouchId>(1);
    Eigen::VectorXd t = StrokeT(2);
    Eigen::VectorXf x = StrokeX(2);
    Eigen::VectorXf y = StrokeY(2);

    touchLog->InsertStroke(touchId, t, x, y);
    Stroke::Ptr stroke = touchLog->Stroke(touchId);

    Eigen::MatrixX2f ll = isolatedStrokesClassifier->StrokeLogLikelihoods(touchId);
    Eigen::VectorXf scores = isolatedStrokesClassifier->ScoresForId(touchId);
    float NPScore = isolatedStrokesClassifier->NPVoteScore(touchId);
    float BayesScore = isolatedStrokesClassifier->BayesLikelihoodScore(touchId);
    float AdaScore = isolatedStrokesClassifier->AdaboostScore(touchId);

    float finalScore = isolatedStrokesClassifier->ConvexScore(touchId);

    //TouchType result = isolatedStrokesClassifier->NPLikelihoodTest(touchId);
    std::cout << "The scores are " << scores << std::endl;
    std::cout << "The likelihoods are " << ll << std::endl;
    std::cout << "The NP score is " << NPScore << std::endl;
    std::cout << "The Bayes score is " << BayesScore << std::endl;
    std::cout << "The Adaboost score is " << AdaScore << std::endl;
    std::cout << "The Final score is " << finalScore << std::endl;

    touchLog->DeleteTouchId(touchId);
}

Eigen::MatrixXf LeastSquaresMatrixData(int testId) {

    assert(testId > 0);

    Eigen::MatrixXf output;

    switch(testId) {
        case 1: {
            output.resize(10,5);
            output <<   0.6715,    0.8884,   -0.1022,   -0.8637,   -1.0891,
                       -1.2075,   -1.1471,   -0.2414,    0.0774,    0.0326,
                        0.7172,   -1.0689,    0.3192,   -1.2141,    0.5525,
                        1.6302,   -0.8095,    0.3129,   -1.1135,    1.1006,
                        0.4889,   -2.9443,   -0.8649,   -0.0068,    1.5442,
                        1.0347,    1.4384,   -0.0301,    1.5326,    0.0859,
                        0.7269,    0.3252,   -0.1649,   -0.7697,   -1.4916,
                       -0.3034,   -0.7549,    0.6277,    0.3714,   -0.7423,
                        0.2939,    1.3703,    1.0933,   -0.2256,   -1.0616,
                       -0.7873,   -1.7115,    1.1093,    1.1174,    2.3505;

            break;
        }
        default: {
            assert(false);
        }
    }

    return output;
}

Eigen::VectorXf LeastSquaresRHSData(int testId) {

    assert(testId > 0);

    Eigen::VectorXf output;

    switch(testId) {
        case 1: {
            output.resize(10);
            output << -1.4023,
                      -1.4224,
                       0.4882,
                      -0.1774,
                      -0.1961,
                       1.4193,
                       0.2916,
                       0.1978,
                       1.5877,
                      -0.8045;

            break;
        }
        default: {
            assert(false);
        }
    }

    return output;

}

Eigen::VectorXf LeastSquaresWeights(int testId) {

    assert(testId > 0);

    Eigen::VectorXf output;

    switch(testId) {
        case 1: {
            output.resize(10);
            output <<  0.7572,
                       0.7537,
                       0.3804,
                       0.5678,
                       0.0759,
                       0.0540,
                       0.5308,
                       0.7792,
                       0.9340,
                       0.1299;

            break;
        }
        default: {
            assert(false);
        }
    }

    return output;

}

Eigen::VectorXf LeastSquaresSolution(int testId) {

    assert(testId > 0);

    Eigen::VectorXf output;

    switch(testId) {
        case 1: {
            output.resize(5);
            output <<  0.6665,
                       0.0359,
                       0.4172,
                       0.5299,
                      -0.2472;

            break;
        }
        default: {
            assert(false);
        }
    }

    return output;

}

Eigen::VectorXf WeightedLeastSquaresSolution(int testId) {

    assert(testId > 0);

    Eigen::VectorXf output;

    switch(testId) {
        case 1: {
            output.resize(5);
            output << 0.5968,
                      0.2220,
                      0.8872,
                      0.7401,
                      0.0001;

            break;
        }
        default: {
            assert(false);
        }
    }

    return output;

}

void VectorComparison(Eigen::VectorXf v, Eigen::VectorXf w) {

    assert(v.rows() == w.rows());

    size_t N = v.rows();
    Eigen::MatrixX2f vectors;
    vectors.resize(N, 2);
    vectors.block(0,0,N,1) = v;
    vectors.block(0,1,N,1) = w;

    std::cout << "Exact: left. Computed: right" << std::endl;
    std::cout << vectors << std::endl;

    std::cout << "l2 Error is " << std::sqrt((v - w).squaredNorm()) << std::endl;

}

void LeastSquaresTest() {

    int testId = 1;
    Eigen::MatrixXf A = LeastSquaresMatrixData(testId);
    Eigen::VectorXf b = LeastSquaresRHSData(testId);
    Eigen::VectorXf x = LeastSquaresSolution(testId);

    // Is templated, so you might have to hold its hand, e.g.
    // LinearLeastSquaresSolve<Atype,Btype>(A,b);
    Eigen::VectorXf computedX = LinearLeastSquaresSolve(A,b);

    std::cout << "Standard least-squares test" << std::endl;
    VectorComparison(x, computedX);
}

void WeightedLeastSquaresTest() {

    int testId = 1;
    Eigen::MatrixXf A = LeastSquaresMatrixData(testId);
    Eigen::VectorXf b = LeastSquaresRHSData(testId);
    Eigen::VectorXf w = LeastSquaresWeights(testId);
    Eigen::VectorXf x = WeightedLeastSquaresSolution(testId);

    Eigen::VectorXf computedX;
    computedX.resize(5);
    computedX = LinearLeastSquaresSolve(A,b,w);

    std::cout << "Weighted least-squares test" << std::endl;
    VectorComparison(x, computedX);
}

Eigen::Matrix<float, 3, 1> GeometricLineFitSolution(int testId) {

    Eigen::Matrix<float, 3, 1> output;

    switch (testId) {
        case 1: {
            output << -0.811342537990713,
                       0.58457102737545,
                       171.476109527494;

            break;
        }

        case 2: {
            output <<   0.278846389094017,
                        0.960335718011794,
                        -1.17270161561708;
            break;
        }
        default:
            DebugAssert(false);
    }

    return output;
}

float GeometricLineFitResidual(int testId) {

    float output;

    switch (testId) {

        case 2: {
            output = 0.0439823534914935;
            break;
        }
        default:
            DebugAssert(false);
    }

    return output;

}

Eigen::Matrix<float, 3, 1> LinearParamLineFitSolution(int testId) {

    Eigen::Matrix<float, 3, 1> output;

    switch (testId) {
        case 2: {
            output <<   1.90993861054037,
                        4.2078795485272,
                        -0.000677265481327231;

            break;
        }
        default:
            DebugAssert(false);
    }

    return output;
}

float LinearParamLineFitResidual(int testId) {

    float output;

    switch (testId) {

        case 2: {
            output = 0.0766383689681639;
            break;
        }
        default:
            DebugAssert(false);
    }

    return output;

}

Eigen::MatrixX2f LineFitData(int testId)
{

    Eigen::MatrixX2f output;

    switch (testId) {
        case 1: {

            Eigen::VectorXf X = StrokeX(2);
            output.resize(X.rows(), 2);
            output.block(0, 0, X.rows(), 1) = X;
            X = StrokeY(2);
            output.block(0, 1, X.rows(), 1) = X;

            break;
        }

        case 2: {

            output.resize(20, 2);
            output << 6.0437,   -0.5214,
                  5.8452,   -0.4762,
                  5.6359,   -0.4141,
                  5.4516,   -0.3606,
                  5.2663,   -0.3143,
                  5.1057,   -0.2517,
                  4.9045,   -0.2060,
                  4.6703,   -0.1326,
                  4.5211,   -0.0964,
                  4.3050,   -0.0390,
                  4.1040,    0.0202,
                  3.9188,    0.0555,
                  3.7165,    0.1559,
                  3.5243,    0.2013,
                  3.3474,    0.2471,
                  3.1536,    0.3250,
                  2.9606,    0.3508,
                  2.7601,    0.4235,
                  2.5483,    0.4787,
                  2.3745,    0.5409;

            break;
        }

        default:
            DebugAssert(false);
    }

    return output;

}

Eigen::VectorXf LineFitParameterData(int testId)
{

    Eigen::VectorXf t;

    switch (testId) {

        case 2: {

            t.resize(20, 1);
            t <<    -1.0000,
                    -0.8947,
                    -0.7895,
                    -0.6842,
                    -0.5789,
                    -0.4737,
                    -0.3684,
                    -0.2632,
                    -0.1579,
                    -0.0526,
                     0.0526,
                     0.1579,
                     0.2632,
                     0.3684,
                     0.4737,
                     0.5789,
                     0.6842,
                     0.7895,
                     0.8947,
                     1.0000;
            break;
        }

        default:
            DebugAssert(false);
    }

    return t;

}

void GeometricLineFitTest() {

    int testId = 1;
    Eigen::MatrixX2f XY = LineFitData(testId);

    Geometric2DLine<float> line = GeometricLeastSquaresLineFit(XY);
    Eigen::Matrix<float, 3, 1> abc;
    abc(0) = line.Orientation()(0);
    abc(1) = line.Orientation()(1);
    abc(2) = line.OffsetParameter();
    Eigen::Matrix<float, 3, 1> exactAbc = GeometricLineFitSolution(testId);

    std::cout << "Geometric line fitting test" << std::endl;
    VectorComparison(exactAbc, abc);

    std::cout << "Evaluating the line at x = 607.832 yields " << line.EvaluateAtX(607.832f) << std::endl;
    std::cout << "Evaluating the line at y = 556.555 yields " << line.EvaluateAtY(556.555f) << std::endl;

}

void LinearParameterizationLineFitTest() {

    /*
     * Matt: effectively do the following:
     *
     * Eigen::MatrixX2f XY = XY data
     * Eigen::VectorXf  t  = time data
     * float residual = 0.0f; // storage for residual
     * LinearlyParameterized2DLine<float> paramLine = LeastSquaresLinearlyParameterizedLine(t, XY, residual);
     *
     * Now "residual" is the sqrt(sum-of-squares) error between the samples and
     * points on the parametric line with the same time parameter
     * and the object paramLine is a 2D line. Things like
     * paramLine.Direction() give you a 1 x 2 unit vector
     * paramLine.Speed() gives you a positive scalar that's the speed
     * You can
     * paramLine.Evaluate(time-float-or-VectorXf)
     * which returns a MatrixX2f evaluation on the line.
     *
     * You have to hold the compiler's hand by forcing the template <float> for
     * the line object. (Or whatever other data type.)
     */

    // Setting up data
    int testId = 2;
    Eigen::MatrixX2f XY = LineFitData(testId);
    Eigen::VectorXf  t  = LineFitParameterData(testId);

    // This does non-parametric line fitting -- can ignore, just for checking
    float exactResidual = GeometricLineFitResidual(testId);
    float residual = 0.0f;
    Geometric2DLine<float> line = GeometricLeastSquaresLineFit(XY, residual);
    Eigen::Matrix<float, 3, 1> abc;
    abc(0) = line.Orientation()(0);
    abc(1) = line.Orientation()(1);
    abc(2) = line.OffsetParameter();
    Eigen::Matrix<float, 3, 1> exactAbc = GeometricLineFitSolution(testId);

    std::cout << "Linear parameterization line fitting test" << std::endl;
    std::cout << "Standard geometric fit" << std::endl;
    VectorComparison(exactAbc, abc);
    std::cout << "Exact residual: " << exactResidual << std::endl << "Computed residual: " << residual << std::endl;

    // This calls the method for parameterization fitting
    exactResidual = LinearParamLineFitResidual(testId);
    LinearlyParameterized2DLine<float> paramLine = LeastSquaresLinearlyParameterizedLine(t, XY, residual);

    // Error metrics
    Eigen::Matrix<float, 3, 1> paramStuff;
    paramStuff(0) = paramLine.Speed();
    paramStuff(1) = paramLine.AnchorPoint()(0);
    paramStuff(2) = paramLine.AnchorPoint()(1);

    Eigen::Matrix<float, 3, 1> exactParamStuff = LinearParamLineFitSolution(testId);

    std::cout << "Least squares linear parameterization fit" << std::endl;
    VectorComparison(exactParamStuff, paramStuff);
    std::cout << "Exact residual: " << exactResidual << std::endl << "Computed residual: " << residual << std::endl;
}

}
}
}
