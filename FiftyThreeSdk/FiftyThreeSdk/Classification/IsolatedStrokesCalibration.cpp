//
//  IsolatedStrokesCalibration.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Eigen.h"
#include "FiftyThreeSdk/Classification/IsolatedStrokes.h"

using namespace Eigen;

namespace fiftythree {
namespace sdk {

void IsolatedStrokesClassifier::InitializeLikelihoods() {

    // The following abbreviations are used for scores:
    // 'complex-valued' entities are real (horizontal x-value) plus imaginary (vertical y-value)
    //   They are C++ implemented as MatrixX2f's
    // abs of a quantity indicates its complex mod
    // trapezoid_rule of something is the integral of the quantity using the trapezoid rule
    // if a complex-valued object z1 is 'orthogonalized' against another complex z2,
    //   it means consider each as a 2D vector and compute the component of z1 orthogonal to z2
    // z: complex-valued samples
    // t: timestamps
    // s: arclength parameter, same size as t and z
    // vt: first derivative of z wrt t
    // at: second derivative of z wrt t
    // jt: third derivative of z wrt t
    // at_ov: at orthogonalized against vt
    // jt_ov: jt orthogonalized against vt
    // jt_oa: jt orthogonalized aginst at
    // pwlinear_t_deviation: essentially a renormalized at. Computes the pointwise error
    //   between a sample and the linear interpolant formed by 2 surrounding (t,z) points
    // pwquad_t_deviation: essentially a renormalized jt. Computes the pointwise error
    //   between a sample and the quadratic interpolant formed by 3 surrounding (t,z) points
    // vs: first derivative of z wrt s
    // as: second derivative of z wrt s
    // js: third derivative of z wrt s
    // as_ov: as orthogonalized against vs
    // js_ov: js orthogonalized against vs
    // js_oa: js orthogonalized aginst as
    // pwlinear_s_deviation: essentially a renormalized as. Computes the pointwise error
    //   between a sample and the linear interpolant formed by 2 surrounding (s,z) points
    // pwquad_s_deviation: essentially a renormalized js. Computes the pointwise error
    //   between a sample and the quadratic interpolant formed by 3 surrounding (s,z) points
    // vst: first derivative of s wrt t
    // ast: second derivative of s wrt t
    // jst: third derivative of s wrt t
    // var(diff(t)): variance of the first differences of t
    // var(diff(s)): variance of the first differences of s

    Eigen::VectorXf coeffs(7);

    _scoreData->_statScoreCount = 40;

    _scoreData->_chosenScoreCount = 10;

    _scoreData->_chosenScoreIndices = Eigen::VectorXi::Zero(_scoreData->_chosenScoreCount);
    _scoreData->_chosenScoreIndices << 5, 29, 9, 3, 39, 31, 1, 35, 7, 28;
    ////  Score  0, vector index  5  trapezoid_rule(t, abs(jt).^2)
    ////  Score  1, vector index 29  trapezoid_rule(s, abs(pwlinear_s_deviation).^2)
    ////  Score  2, vector index  9  trapezoid_rule(t, abs(jt_ov).^2)
    ////  Score  3, vector index  3  trapezoid_rule(t, abs(at).^2)
    ////  Score  4, vector index 39  var(diff(s))
    ////  Score  5, vector index 31  trapezoid_rule(s, abs(pwquad_s_deviation).^2)
    ////  Score  6, vector index  1  trapezoid_rule(t, abs(vt).^2)
    ////  Score  7, vector index 35  trapezoid_rule(t, abs(ast).^2)
    ////  Score  8, vector index  7  trapezoid_rule(t, abs(at_ov).^2)
    ////  Score  9, vector index 28  max(abs(pwlinear_s_deviation))

    _scoreData->_LExponents = Eigen::VectorXf::Zero(_scoreData->_chosenScoreCount);
    _scoreData->_LExponents << -2, -3, -2, -3, -3, -5, -3, -3, -2, -1;

    _scoreData->_TExponents = Eigen::VectorXf::Zero(_scoreData->_chosenScoreCount);
    _scoreData->_TExponents << 0, 1, 0, 2, 2, 2, 1, 1, 0, 0;

    ////  Score 0: trapezoid_rule(t, abs(jt).^2)
    coeffs << -1.032956,
               0.763032,
              -4.101505,
              -4.211043,
               0.931546,
               3.710870,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(3.422664, 16.621161, 14.866293, 19.898710, coeffs));

    coeffs << -0.931916,
               1.112481,
              -2.757366,
              -4.066608,
              -2.305599,
               1.008503,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(4.526208, 19.392501, 14.866293, 19.898710, coeffs));

    ////  Score 1: trapezoid_rule(s, abs(pwlinear_s_deviation).^2)
    coeffs << -1.425423,
               0.110381,
              -3.503729,
              -1.653635,
              -0.427758,
               2.664837,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(4.894326, -10.892961, -13.390246, -6.065227, coeffs));

    coeffs << -1.375145,
               0.068578,
              -2.672705,
               0.226511,
              -2.154284,
              -0.792798,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(6.322943, -7.067303, -13.390246, -6.065227, coeffs));

    ////  Score 2: trapezoid_rule(t, abs(jt_ov).^2)
    coeffs << -1.312301,
               0.471297,
              -3.566605,
              -2.845610,
              -0.624448,
               3.126508,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(4.459086, 14.795959, 12.562317, 19.214848, coeffs));

    coeffs << -1.340049,
               0.102977,
              -3.244840,
               0.361157,
              -0.790136,
              -1.071140,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(4.831524, 17.393841, 12.562317, 19.214848, coeffs));

    ////  Score 3: trapezoid_rule(t, abs(at).^2)
    coeffs << -0.915350,
               0.512201,
              -3.299245,
              -3.209415,
              -0.997782,
               3.121202,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(3.452160, 1.035239, 0.029136, 4.487399, coeffs));

    coeffs << -0.910787,
               0.168456,
              -4.095100,
              -0.567607,
               0.893000,
               0.327358,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(3.281070, 3.310206, 0.029136, 4.487399, coeffs));

    ////  Score 4: var(diff(s))
    coeffs << -0.970088,
               0.131634,
              -4.150957,
              -0.531922,
               1.164149,
               0.201054,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(3.213073, -13.896619, -15.463818, -10.683546, coeffs));

    coeffs << -0.982769,
               0.008945,
              -3.853256,
               0.345667,
               0.312935,
              -0.495384,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(3.344807, -12.119011, -15.463818, -10.683546, coeffs));

    ////  Score 5: trapezoid_rule(s, abs(pwquad_s_deviation).^2)
    coeffs << -2.033143,
               0.159637,
              -3.340048,
              -2.862164,
              -0.706293,
               3.834944,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(9.274092, -20.940560, -25.288955, -12.375546, coeffs));

    coeffs << -1.988335,
              -0.593679,
              -3.149505,
               3.370676,
              -1.084819,
              -3.034472,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(10.189081, -15.099874, -25.288955, -12.375546, coeffs));

    ////  Score 6: trapezoid_rule(t, abs(vt).^2)
    coeffs << -0.965423,
               0.352499,
              -3.986055,
              -1.939040,
               0.650540,
               1.509845,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(3.045959, -4.501986, -6.398880, -1.465922, coeffs));

    coeffs << -1.022947,
              -0.583849,
              -2.981422,
               3.070086,
              -1.543889,
              -2.587213,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(3.154084, -3.244796, -6.398880, -1.465922, coeffs));

    ////  Score 7: trapezoid_rule(t, abs(ast).^2)
    coeffs << -0.988914,
               0.500173,
              -4.078646,
              -2.653387,
               0.995498,
               2.216244,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(3.829149, 1.970509, 0.913587, 5.525764, coeffs));

    coeffs << -0.963399,
               0.148312,
              -3.399922,
               0.422130,
              -0.644781,
              -1.664954,
               0.000000;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(3.439734, 4.353322, 0.913587, 5.525764, coeffs));

    ////  Score 8: trapezoid_rule(t, abs(at_ov).^2)
    coeffs << -1.403759,
               0.984287,
              -2.586599,
              -3.719602,
              -2.335020,
               2.402645,
               0.000000;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(4.515167, 6.460771, 3.993934, 10.975939, coeffs));

    coeffs << -1.376205,
               0.268116,
              -3.335262,
               0.540597,
               0.610685,
              -1.515206,
              -1.445888;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(4.366188, 8.360122, 3.993934, 10.975939, coeffs));

    ////  Score 9: max(abs(pwlinear_s_deviation))
    coeffs << -0.894727,
               0.179690,
              -4.463103,
              -1.186165,
               3.695260,
               1.349259,
              -2.591098;
    _scoreData->_penLikelihoods.push_back(PolynomialModel(2.872286, -3.799967, -5.367190, -0.927681, coeffs));

    coeffs << -0.979891,
               0.685637,
              -2.837750,
               0.924995,
               2.067630,
              -0.910657,
              -2.527087;
    _scoreData->_palmLikelihoods.push_back(PolynomialModel(3.038216, -2.328975, -5.367190, -0.927681, coeffs));

    //// Eta models

    coeffs.resize(5);

    ////  trapezoid_rule(t, abs(jt).^2)
    coeffs << -1.589325,
               3.743807,
              -0.211529,
              -1.914389,
               1.023909;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.023911, -0.695131, coeffs));

    ////  trapezoid_rule(s, abs(pwlinear_s_deviation).^2)
    coeffs << -1.622373,
               2.751246,
               0.211835,
              -0.911442,
               0.786574;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.387447, -0.695131, coeffs));

    ////  trapezoid_rule(t, abs(jt_ov).^2)
    coeffs << -1.274486,
               2.360163,
              -0.503858,
              -0.360648,
               0.835884;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -5.038034, -0.695131, coeffs));

    ////  trapezoid_rule(t, abs(at).^2)
    coeffs << -1.369176,
               3.217548,
              -0.724355,
              -0.705932,
               1.304552;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.387447, -0.695131, coeffs));

    ////  var(diff(s))
    coeffs << -1.526585,
               1.994023,
               0.470278,
              -0.237681,
               0.389300;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.428118, -0.695131, coeffs));

    ////  trapezoid_rule(s, abs(pwquad_s_deviation).^2)
    coeffs << -1.667559,
               2.501910,
               0.066149,
              -0.817324,
               1.164642;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.023911, -0.695131, coeffs));

    ////  trapezoid_rule(t, abs(vt).^2)
    coeffs << -1.162706,
               1.673751,
              -0.461184,
              -0.300808,
               0.741775;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.771406, -0.695131, coeffs));

    ////  trapezoid_rule(t, abs(ast).^2)
    coeffs << -1.534549,
               2.644240,
               0.370230,
              -0.702472,
               0.880460;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.274506, -0.695131, coeffs));

    ////  trapezoid_rule(t, abs(at_ov).^2)
    coeffs << -0.868969,
               1.266344,
              -0.269523,
               0.578113,
              -0.095912;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -5.203827, -0.695131, coeffs));

    ////  max(abs(pwlinear_s_deviation))
    coeffs << -1.513645,
               1.925736,
               0.687646,
               0.066800,
              -0.116071;
    _NPData->_etaModel.push_back(PolynomialModel(2.302585, -2.995732, -4.660740, -0.695131, coeffs));

    //// Neyman-Pearson voting calibration

    // These are scoring polynomials: each polynomial evaluates to the log-score we assign, assuming we see (index) number of votes.

    _NPData->_vetoThreshold = 3;

    _NPData->_defaultFPRate = 0.020000;

    coeffs << -0.914028,
               2.451166,
               0.350136,
              -0.194110,
              -0.046242;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -3.946002, -0.693147, coeffs));

    coeffs << -1.663818,
              -1.306716,
              -2.902459,
              -1.103371,
              -0.125701;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -3.848870, -0.693147, coeffs));

    coeffs << -1.835430,
              -1.977205,
              -2.973677,
              -1.035646,
              -0.113185;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -3.946002, -0.693147, coeffs));

    coeffs << -0.302835,
               0.859914,
              -0.481327,
              -0.122618,
              -0.001863;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.082404, -0.693147, coeffs));

    coeffs << -1.585249,
              -3.062274,
              -3.637050,
              -1.113704,
              -0.108668;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.311314, -0.693147, coeffs));

    coeffs << -0.514780,
              -0.710271,
              -1.244842,
              -0.265117,
              -0.013554;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.712869, -0.693147, coeffs));

    coeffs << -0.788811,
              -1.487002,
              -1.504951,
              -0.302115,
              -0.017454;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.829190, -0.693147, coeffs));

    coeffs << -0.200481,
              -0.017556,
              -0.048156,
               0.161359,
               0.028181;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.892852, -0.693147, coeffs));

    coeffs <<  0.382630,
               1.294200,
               0.969450,
               0.401613,
               0.044941;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.892852, -0.693147, coeffs));

    coeffs <<  0.507192,
               1.472112,
               1.055744,
               0.388942,
               0.040612;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.892852, -0.693147, coeffs));

    coeffs << -0.005282,
               0.237073,
               0.168222,
               0.054618,
               0.004797;
    _NPData->_scoreModels.push_back(PolynomialModel(1.000000, 0.000000, -4.892852, -0.693147, coeffs));

    //// Bayes likelihood classification

    // These are scoring polynomials: scores as a function of Bayes false positive rate.

    // This is the hand-tuned Bayes false positive rate that gets the 'best' rate
    _BayesData->_falsePositiveRate = 0.1384;

    coeffs.resize(5);

    // Pen score: log-score if Bayes says "Pen" as a function of false positive rate.

    coeffs << -0.699960,
               0.854392,
              -0.293162,
              -0.307915,
               0.288585;
    _BayesData->_penScore = PolynomialModel(2.302585, -2.995732, -4.961845, -0.693147, coeffs);

    // Palm score: log-score if Bayes says "Palm" as a function of false positive rate.

    coeffs << -3.735299,
               1.299524,
               0.940519,
              -0.200490,
              -0.249692;
    _BayesData->_palmScore = PolynomialModel(2.302585, -2.995732, -4.656463, -0.693147, coeffs);

    // Bayes Log Likelihood Threshold: Log-likelihood threshold value for a given false positive rate.

    coeffs << -9.091859,
               17.879141,
              -3.211344,
              -0.927055,
               6.297337;
    _BayesData->_logLikelihoodThreshold = PolynomialModel(2.302585, -2.995732, -5.115996, -0.693147, coeffs);

    //// Adaboost calibration

    // This is the hand-tuned NP false positive rate that gets the 'best' Adaboost rate
    _AdaboostData->_NPFalsePositiveRate = 0.2090;
    _AdaboostData->_NPBoostingCoefficients.resize(10);

    _AdaboostData->_NPBoostingCoefficients <<  0.089216,
                                               0.067971,
                                               0.306111,
                                               0.208414,
                                               0.258301,
                                               0.113953,
                                               0.303705,
                                               0.196337,
                                               0.293033,
                                               0.076585;

    _AdaboostData->_penScore = 0.597262;
    _AdaboostData->_palmScore = 0.067991;

    _AdaboostData->_convexCoefficients.resize(3);
    _AdaboostData->_convexCoefficients << 0.098957,
                                          0.270830,
                                          0.630214;

}

}
}

// Summary statistics //////////////////
//
// The following tables show error rates on the training set for
// the classification as a function of both the stroke sample sizes
// and the imposed false positive rate of a Neyman-Pearson test.
// Each classification test is a hypothesis test, the null hypothesis
// is "this is a pen". The alternative hypothesis is "this is a palm".
// All strokes in the training set that are marked as neither pens nor
// palms are not classified and are ignored.
//
// "NMin" -- Ignore (don't classify) strokes with fewer than NMin samples.
// "NMax" -- Any stroke with more than NMax samples is truncated to
//           the first NMax samples and then classified.
// "fpr" -- False positive rate. The percentage of true pens that
//          are incorrectly classified as palms.
// "fnr" -- False negative rate. The percentage of true palms that
//          are incorrectly classified as pens.
// "alpha" -- The false positive rate imposed on a Neyman-Pearson test.
//            This is a parameter required to construct the "S x" tests,
//            and can be any chosen value. I.e., this modifies the test
//            so that the "S x" test has a fpr of alpha on the training
//            set with NMin = 4, NMax = Inf.
//
// Most of these tests are constructed by heavily penalizing high
// fpr's. This was a design choice but there is flexibility in the c++
// code to allow higher fpr's, and this will get you much better fnr's.
//
// The following tests are compiled below, and all were calibrated
// with NMin = 4, NMax = Inf:
//
// "S x" -- where x is 0...9 is a Neyman-Pearson classifier based *only*
//          on score x, see chosenScoreIndices comment block above.
//          These tests are generated by imposing a default false
//          positive rate in np_voting_model.m. The c++ code allows
//          you to change this to impose any fpr less than 0.5.
//          This fpr is the parameter "alpha" above. This imposed fpr
//          is the actual fpr only for NMin = 4, NMax = Inf on the
//          training set.
// "NPV n" -- where n is 0...10 uses the "S x" classifiers as votes. A
//            stroke is marked pen if n or fewer "S x" votes say palm.
// "Bayes" -- Sums the likelihoods from each individual scores, and
//            classifies based on the cutoff that is computed in
//            bayes_cutoff_model.m
// "Adaboost" -- Boosted classier from the individual "S x" classifiers
// "Convex" -- Boosted classifier using "Adaboost", "Bayes", and "NPV n",
//             where n is np_voting.default_NPVeto
//
// Rates below (fpr, fnr, alpha) are errors (lower is better) and are
// given in thousandths, so an entry of 784 indicates a failure rate
// of 0.784, 015 indicates a failure rate of 0.015.
//
//
//
//                           ||       S 0               S 1               S 2               S 3
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------------------------------------------
//  (    4 ,  Inf ,  020  )  ||  ( 022 , 507 )     ( 020 , 563 )     ( 019 , 660 )     ( 021 , 652 )
//  (    5 ,  Inf ,  020  )  ||  ( 017 , 535 )     ( 014 , 600 )     ( 014 , 704 )     ( 019 , 633 )
//  (    6 ,  Inf ,  020  )  ||  ( 013 , 560 )     ( 010 , 625 )     ( 010 , 739 )     ( 018 , 615 )
//  (    7 ,  Inf ,  020  )  ||  ( 011 , 586 )     ( 007 , 647 )     ( 007 , 772 )     ( 017 , 597 )
//  (    8 ,  Inf ,  020  )  ||  ( 010 , 609 )     ( 005 , 668 )     ( 005 , 799 )     ( 017 , 578 )
//  (    9 ,  Inf ,  020  )  ||  ( 011 , 629 )     ( 004 , 686 )     ( 005 , 826 )     ( 018 , 565 )
//  (   10 ,  Inf ,  020  )  ||  ( 011 , 646 )     ( 004 , 698 )     ( 005 , 845 )     ( 019 , 553 )
//  (   11 ,  Inf ,  020  )  ||  ( 011 , 664 )     ( 003 , 710 )     ( 005 , 862 )     ( 020 , 542 )
//  (   12 ,  Inf ,  020  )  ||  ( 011 , 682 )     ( 003 , 722 )     ( 005 , 878 )     ( 020 , 531 )
//  (   13 ,  Inf ,  020  )  ||  ( 011 , 697 )     ( 003 , 733 )     ( 004 , 891 )     ( 019 , 521 )
//  (   14 ,  Inf ,  020  )  ||  ( 011 , 712 )     ( 003 , 738 )     ( 004 , 902 )     ( 020 , 510 )
//  (   15 ,  Inf ,  020  )  ||  ( 011 , 725 )     ( 002 , 746 )     ( 004 , 910 )     ( 021 , 503 )
//  (   16 ,  Inf ,  020  )  ||  ( 012 , 739 )     ( 002 , 756 )     ( 005 , 918 )     ( 021 , 492 )
//  (    4 ,    4 ,  020  )  ||  ( 226 , 340 )     ( 245 , 339 )     ( 226 , 400 )     ( 085 , 767 )
//  (    5 ,    5 ,  020  )  ||  ( 105 , 363 )     ( 109 , 432 )     ( 113 , 468 )     ( 050 , 755 )
//  (    6 ,    6 ,  020  )  ||  ( 048 , 370 )     ( 064 , 460 )     ( 066 , 494 )     ( 026 , 750 )
//  (    7 ,    7 ,  020  )  ||  ( 020 , 399 )     ( 031 , 476 )     ( 031 , 551 )     ( 020 , 748 )
//  (    8 ,    8 ,  020  )  ||  ( 002 , 419 )     ( 016 , 507 )     ( 005 , 550 )     ( 005 , 698 )
//  (    9 ,    9 ,  020  )  ||  ( 008 , 452 )     ( 014 , 553 )     ( 002 , 628 )     ( 005 , 690 )
//  (   10 ,   10 ,  020  )  ||  ( 009 , 454 )     ( 009 , 570 )     ( 006 , 654 )     ( 012 , 673 )
//  (   11 ,   11 ,  020  )  ||  ( 013 , 460 )     ( 006 , 578 )     ( 003 , 685 )     ( 013 , 672 )
//  (   12 ,   12 ,  020  )  ||  ( 021 , 496 )     ( 012 , 589 )     ( 021 , 717 )     ( 034 , 645 )
//  (   13 ,   13 ,  020  )  ||  ( 007 , 506 )     ( 003 , 664 )     ( 003 , 754 )     ( 007 , 659 )
//  (   14 ,   14 ,  020  )  ||  ( 004 , 532 )     ( 009 , 633 )     ( 004 , 793 )     ( 004 , 609 )
//  (   15 ,   15 ,  020  )  ||  ( 000 , 541 )     ( 008 , 610 )     ( 000 , 800 )     ( 013 , 644 )
//  (   16 ,   16 ,  020  )  ||  ( 009 , 512 )     ( 009 , 622 )     ( 004 , 816 )     ( 014 , 602 )
//  (    4 ,    6 ,  020  )  ||  ( 103 , 355 )     ( 115 , 400 )     ( 114 , 446 )     ( 046 , 759 )
//  (    4 ,    8 ,  020  )  ||  ( 060 , 370 )     ( 072 , 425 )     ( 069 , 475 )     ( 030 , 750 )
//  (    4 ,   10 ,  020  )  ||  ( 044 , 383 )     ( 054 , 446 )     ( 049 , 501 )     ( 024 , 739 )
//  (    4 ,   11 ,  020  )  ||  ( 040 , 387 )     ( 048 , 454 )     ( 043 , 512 )     ( 022 , 735 )
//  (    4 ,   12 ,  020  )  ||  ( 038 , 393 )     ( 045 , 461 )     ( 041 , 522 )     ( 023 , 731 )
//  (    4 ,   16 ,  020  )  ||  ( 030 , 410 )     ( 035 , 483 )     ( 032 , 557 )     ( 020 , 718 )
//  (    8 ,   10 ,  020  )  ||  ( 006 , 440 )     ( 013 , 540 )     ( 004 , 605 )     ( 007 , 688 )
//  (    8 ,   12 ,  020  )  ||  ( 010 , 452 )     ( 012 , 553 )     ( 007 , 635 )     ( 012 , 679 )
//  (    8 ,   16 ,  020  )  ||  ( 008 , 473 )     ( 010 , 578 )     ( 005 , 682 )     ( 011 , 664 )
//  (   10 ,   11 ,  020  )  ||  ( 011 , 457 )     ( 008 , 574 )     ( 004 , 668 )     ( 012 , 673 )
//  (   10 ,   12 ,  020  )  ||  ( 014 , 468 )     ( 009 , 578 )     ( 009 , 682 )     ( 018 , 665 )
//  (   10 ,   16 ,  020  )  ||  ( 009 , 493 )     ( 008 , 604 )     ( 006 , 732 )     ( 014 , 649 )
//  (   11 ,   12 ,  020  )  ||  ( 016 , 477 )     ( 009 , 583 )     ( 011 , 699 )     ( 022 , 660 )
//  (   11 ,   14 ,  020  )  ||  ( 012 , 494 )     ( 008 , 612 )     ( 008 , 731 )     ( 015 , 649 )
//  (   11 ,   16 ,  020  )  ||  ( 009 , 503 )     ( 008 , 613 )     ( 006 , 751 )     ( 014 , 643 )
//  (   12 ,   14 ,  020  )  ||  ( 011 , 510 )     ( 008 , 627 )     ( 010 , 751 )     ( 015 , 639 )
//  (   12 ,   16 ,  020  )  ||  ( 008 , 516 )     ( 008 , 623 )     ( 007 , 771 )     ( 015 , 634 )
//
//
//                           ||       S 4               S 5               S 6               S 7
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------------------------------------------
//  (    4 ,  Inf ,  020  )  ||  ( 020 , 778 )     ( 020 , 723 )     ( 019 , 825 )     ( 020 , 736 )
//  (    5 ,  Inf ,  020  )  ||  ( 014 , 796 )     ( 013 , 764 )     ( 012 , 864 )     ( 014 , 769 )
//  (    6 ,  Inf ,  020  )  ||  ( 010 , 809 )     ( 008 , 794 )     ( 007 , 892 )     ( 010 , 795 )
//  (    7 ,  Inf ,  020  )  ||  ( 007 , 817 )     ( 006 , 816 )     ( 005 , 911 )     ( 008 , 815 )
//  (    8 ,  Inf ,  020  )  ||  ( 005 , 821 )     ( 004 , 832 )     ( 004 , 925 )     ( 006 , 828 )
//  (    9 ,  Inf ,  020  )  ||  ( 004 , 828 )     ( 003 , 848 )     ( 004 , 936 )     ( 007 , 841 )
//  (   10 ,  Inf ,  020  )  ||  ( 004 , 833 )     ( 002 , 859 )     ( 003 , 945 )     ( 007 , 850 )
//  (   11 ,  Inf ,  020  )  ||  ( 003 , 837 )     ( 002 , 867 )     ( 003 , 951 )     ( 007 , 858 )
//  (   12 ,  Inf ,  020  )  ||  ( 003 , 840 )     ( 002 , 875 )     ( 003 , 955 )     ( 007 , 864 )
//  (   13 ,  Inf ,  020  )  ||  ( 002 , 843 )     ( 001 , 884 )     ( 003 , 959 )     ( 006 , 871 )
//  (   14 ,  Inf ,  020  )  ||  ( 002 , 846 )     ( 001 , 887 )     ( 003 , 962 )     ( 006 , 875 )
//  (   15 ,  Inf ,  020  )  ||  ( 002 , 850 )     ( 001 , 891 )     ( 003 , 964 )     ( 006 , 880 )
//  (   16 ,  Inf ,  020  )  ||  ( 002 , 850 )     ( 001 , 898 )     ( 003 , 965 )     ( 007 , 884 )
//  (    4 ,    4 ,  020  )  ||  ( 245 , 672 )     ( 294 , 479 )     ( 312 , 594 )     ( 257 , 539 )
//  (    5 ,    5 ,  020  )  ||  ( 125 , 709 )     ( 144 , 565 )     ( 125 , 674 )     ( 113 , 594 )
//  (    6 ,    6 ,  020  )  ||  ( 050 , 749 )     ( 048 , 628 )     ( 034 , 747 )     ( 037 , 646 )
//  (    7 ,    7 ,  020  )  ||  ( 045 , 781 )     ( 034 , 687 )     ( 031 , 802 )     ( 037 , 709 )
//  (    8 ,    8 ,  020  )  ||  ( 016 , 760 )     ( 011 , 684 )     ( 005 , 825 )     ( 002 , 711 )
//  (    9 ,    9 ,  020  )  ||  ( 005 , 775 )     ( 017 , 729 )     ( 005 , 833 )     ( 002 , 751 )
//  (   10 ,   10 ,  020  )  ||  ( 012 , 789 )     ( 006 , 778 )     ( 009 , 888 )     ( 006 , 762 )
//  (   11 ,   11 ,  020  )  ||  ( 010 , 804 )     ( 006 , 766 )     ( 003 , 904 )     ( 010 , 789 )
//  (   12 ,   12 ,  020  )  ||  ( 012 , 797 )     ( 017 , 766 )     ( 008 , 910 )     ( 021 , 782 )
//  (   13 ,   13 ,  020  )  ||  ( 003 , 809 )     ( 000 , 854 )     ( 007 , 915 )     ( 003 , 810 )
//  (   14 ,   14 ,  020  )  ||  ( 004 , 800 )     ( 000 , 828 )     ( 000 , 929 )     ( 004 , 804 )
//  (   15 ,   15 ,  020  )  ||  ( 004 , 839 )     ( 000 , 805 )     ( 004 , 955 )     ( 000 , 832 )
//  (   16 ,   16 ,  020  )  ||  ( 000 , 816 )     ( 000 , 852 )     ( 004 , 941 )     ( 009 , 813 )
//  (    4 ,    6 ,  020  )  ||  ( 114 , 704 )     ( 129 , 545 )     ( 120 , 659 )     ( 107 , 585 )
//  (    4 ,    8 ,  020  )  ||  ( 075 , 722 )     ( 079 , 584 )     ( 072 , 701 )     ( 066 , 619 )
//  (    4 ,   10 ,  020  )  ||  ( 054 , 732 )     ( 058 , 610 )     ( 052 , 726 )     ( 047 , 640 )
//  (    4 ,   11 ,  020  )  ||  ( 049 , 736 )     ( 052 , 620 )     ( 046 , 737 )     ( 042 , 649 )
//  (    4 ,   12 ,  020  )  ||  ( 046 , 739 )     ( 049 , 627 )     ( 043 , 745 )     ( 040 , 656 )
//  (    4 ,   16 ,  020  )  ||  ( 035 , 749 )     ( 037 , 654 )     ( 033 , 770 )     ( 031 , 676 )
//  (    8 ,   10 ,  020  )  ||  ( 011 , 773 )     ( 011 , 725 )     ( 006 , 846 )     ( 003 , 738 )
//  (    8 ,   12 ,  020  )  ||  ( 011 , 782 )     ( 011 , 738 )     ( 006 , 865 )     ( 007 , 753 )
//  (    8 ,   16 ,  020  )  ||  ( 008 , 792 )     ( 007 , 768 )     ( 005 , 886 )     ( 006 , 772 )
//  (   10 ,   11 ,  020  )  ||  ( 011 , 796 )     ( 006 , 773 )     ( 006 , 895 )     ( 008 , 775 )
//  (   10 ,   12 ,  020  )  ||  ( 011 , 796 )     ( 009 , 771 )     ( 007 , 899 )     ( 011 , 777 )
//  (   10 ,   16 ,  020  )  ||  ( 007 , 805 )     ( 004 , 800 )     ( 005 , 915 )     ( 008 , 795 )
//  (   11 ,   12 ,  020  )  ||  ( 011 , 801 )     ( 011 , 766 )     ( 005 , 906 )     ( 015 , 786 )
//  (   11 ,   14 ,  020  )  ||  ( 008 , 802 )     ( 006 , 799 )     ( 005 , 913 )     ( 010 , 795 )
//  (   11 ,   16 ,  020  )  ||  ( 006 , 809 )     ( 004 , 806 )     ( 004 , 922 )     ( 008 , 803 )
//  (   12 ,   14 ,  020  )  ||  ( 007 , 802 )     ( 005 , 813 )     ( 005 , 917 )     ( 010 , 798 )
//  (   12 ,   16 ,  020  )  ||  ( 005 , 811 )     ( 003 , 818 )     ( 005 , 928 )     ( 007 , 807 )
//
//
//                           ||       S 8               S 9
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------
//  (    4 ,  Inf ,  020  )  ||  ( 019 , 698 )     ( 019 , 665 )
//  (    5 ,  Inf ,  020  )  ||  ( 014 , 732 )     ( 013 , 720 )
//  (    6 ,  Inf ,  020  )  ||  ( 010 , 760 )     ( 009 , 758 )
//  (    7 ,  Inf ,  020  )  ||  ( 007 , 784 )     ( 005 , 791 )
//  (    8 ,  Inf ,  020  )  ||  ( 006 , 807 )     ( 003 , 818 )
//  (    9 ,  Inf ,  020  )  ||  ( 005 , 829 )     ( 001 , 839 )
//  (   10 ,  Inf ,  020  )  ||  ( 005 , 843 )     ( 000 , 855 )
//  (   11 ,  Inf ,  020  )  ||  ( 005 , 857 )     ( 000 , 867 )
//  (   12 ,  Inf ,  020  )  ||  ( 005 , 867 )     ( 000 , 880 )
//  (   13 ,  Inf ,  020  )  ||  ( 004 , 879 )     ( 000 , 892 )
//  (   14 ,  Inf ,  020  )  ||  ( 004 , 888 )     ( 000 , 896 )
//  (   15 ,  Inf ,  020  )  ||  ( 004 , 896 )     ( 000 , 904 )
//  (   16 ,  Inf ,  020  )  ||  ( 003 , 903 )     ( 000 , 913 )
//  (    4 ,    4 ,  020  )  ||  ( 196 , 494 )     ( 257 , 340 )
//  (    5 ,    5 ,  020  )  ||  ( 117 , 538 )     ( 117 , 463 )
//  (    6 ,    6 ,  020  )  ||  ( 064 , 582 )     ( 058 , 514 )
//  (    7 ,    7 ,  020  )  ||  ( 025 , 600 )     ( 040 , 571 )
//  (    8 ,    8 ,  020  )  ||  ( 014 , 603 )     ( 033 , 613 )
//  (    9 ,    9 ,  020  )  ||  ( 005 , 675 )     ( 011 , 677 )
//  (   10 ,   10 ,  020  )  ||  ( 000 , 700 )     ( 006 , 723 )
//  (   11 ,   11 ,  020  )  ||  ( 006 , 733 )     ( 000 , 721 )
//  (   12 ,   12 ,  020  )  ||  ( 021 , 730 )     ( 004 , 741 )
//  (   13 ,   13 ,  020  )  ||  ( 003 , 758 )     ( 000 , 837 )
//  (   14 ,   14 ,  020  )  ||  ( 014 , 778 )     ( 000 , 787 )
//  (   15 ,   15 ,  020  )  ||  ( 017 , 802 )     ( 004 , 785 )
//  (   16 ,   16 ,  020  )  ||  ( 004 , 808 )     ( 000 , 816 )
//  (    4 ,    6 ,  020  )  ||  ( 108 , 531 )     ( 118 , 425 )
//  (    4 ,    8 ,  020  )  ||  ( 066 , 550 )     ( 080 , 470 )
//  (    4 ,   10 ,  020  )  ||  ( 047 , 572 )     ( 058 , 506 )
//  (    4 ,   11 ,  020  )  ||  ( 042 , 581 )     ( 051 , 519 )
//  (    4 ,   12 ,  020  )  ||  ( 040 , 589 )     ( 047 , 529 )
//  (    4 ,   16 ,  020  )  ||  ( 032 , 614 )     ( 035 , 566 )
//  (    8 ,   10 ,  020  )  ||  ( 006 , 654 )     ( 017 , 665 )
//  (    8 ,   12 ,  020  )  ||  ( 009 , 679 )     ( 012 , 686 )
//  (    8 ,   16 ,  020  )  ||  ( 009 , 711 )     ( 008 , 723 )
//  (   10 ,   11 ,  020  )  ||  ( 003 , 716 )     ( 003 , 722 )
//  (   10 ,   12 ,  020  )  ||  ( 008 , 720 )     ( 003 , 728 )
//  (   10 ,   16 ,  020  )  ||  ( 009 , 750 )     ( 002 , 765 )
//  (   11 ,   12 ,  020  )  ||  ( 013 , 732 )     ( 001 , 730 )
//  (   11 ,   14 ,  020  )  ||  ( 011 , 747 )     ( 001 , 767 )
//  (   11 ,   16 ,  020  )  ||  ( 011 , 763 )     ( 001 , 775 )
//  (   12 ,   14 ,  020  )  ||  ( 012 , 753 )     ( 001 , 787 )
//  (   12 ,   16 ,  020  )  ||  ( 012 , 771 )     ( 001 , 791 )
//
//
//
//
//
//
//                           ||      NPV 0             NPV 1             NPV 2             NPV 3
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------------------------------------------
//  (    4 ,  Inf ,  020  )  ||  ( 069 , 203 )     ( 043 , 341 )     ( 032 , 446 )     ( 022 , 583 )
//  (    5 ,  Inf ,  020  )  ||  ( 056 , 227 )     ( 031 , 379 )     ( 023 , 490 )     ( 015 , 633 )
//  (    6 ,  Inf ,  020  )  ||  ( 045 , 248 )     ( 023 , 410 )     ( 016 , 528 )     ( 010 , 672 )
//  (    7 ,  Inf ,  020  )  ||  ( 036 , 267 )     ( 018 , 440 )     ( 012 , 562 )     ( 008 , 703 )
//  (    8 ,  Inf ,  020  )  ||  ( 031 , 283 )     ( 014 , 466 )     ( 010 , 590 )     ( 006 , 729 )
//  (    9 ,  Inf ,  020  )  ||  ( 029 , 299 )     ( 014 , 491 )     ( 009 , 616 )     ( 007 , 752 )
//  (   10 ,  Inf ,  020  )  ||  ( 028 , 310 )     ( 014 , 511 )     ( 009 , 637 )     ( 006 , 769 )
//  (   11 ,  Inf ,  020  )  ||  ( 028 , 319 )     ( 014 , 529 )     ( 009 , 657 )     ( 006 , 784 )
//  (   12 ,  Inf ,  020  )  ||  ( 028 , 328 )     ( 014 , 546 )     ( 009 , 675 )     ( 006 , 797 )
//  (   13 ,  Inf ,  020  )  ||  ( 027 , 337 )     ( 013 , 562 )     ( 008 , 691 )     ( 005 , 809 )
//  (   14 ,  Inf ,  020  )  ||  ( 027 , 343 )     ( 013 , 574 )     ( 008 , 704 )     ( 005 , 818 )
//  (   15 ,  Inf ,  020  )  ||  ( 028 , 348 )     ( 013 , 584 )     ( 008 , 717 )     ( 005 , 826 )
//  (   16 ,  Inf ,  020  )  ||  ( 027 , 352 )     ( 013 , 597 )     ( 008 , 728 )     ( 005 , 834 )
//  (    4 ,    4 ,  020  )  ||  ( 558 , 057 )     ( 484 , 115 )     ( 398 , 182 )     ( 300 , 282 )
//  (    5 ,    5 ,  020  )  ||  ( 339 , 084 )     ( 226 , 168 )     ( 183 , 237 )     ( 125 , 373 )
//  (    6 ,    6 ,  020  )  ||  ( 176 , 110 )     ( 112 , 189 )     ( 082 , 274 )     ( 050 , 436 )
//  (    7 ,    7 ,  020  )  ||  ( 112 , 131 )     ( 071 , 223 )     ( 048 , 332 )     ( 028 , 495 )
//  (    8 ,    8 ,  020  )  ||  ( 070 , 139 )     ( 019 , 236 )     ( 011 , 352 )     ( 005 , 514 )
//  (    9 ,    9 ,  020  )  ||  ( 032 , 180 )     ( 020 , 282 )     ( 011 , 392 )     ( 008 , 574 )
//  (   10 ,   10 ,  020  )  ||  ( 040 , 218 )     ( 012 , 313 )     ( 009 , 423 )     ( 009 , 611 )
//  (   11 ,   11 ,  020  )  ||  ( 023 , 214 )     ( 013 , 339 )     ( 013 , 456 )     ( 010 , 635 )
//  (   12 ,   12 ,  020  )  ||  ( 051 , 218 )     ( 034 , 348 )     ( 034 , 467 )     ( 025 , 642 )
//  (   13 ,   13 ,  020  )  ||  ( 015 , 255 )     ( 011 , 418 )     ( 007 , 531 )     ( 003 , 699 )
//  (   14 ,   14 ,  020  )  ||  ( 024 , 272 )     ( 009 , 429 )     ( 004 , 530 )     ( 004 , 708 )
//  (   15 ,   15 ,  020  )  ||  ( 035 , 297 )     ( 013 , 421 )     ( 004 , 567 )     ( 000 , 721 )
//  (   16 ,   16 ,  020  )  ||  ( 028 , 290 )     ( 009 , 433 )     ( 009 , 551 )     ( 009 , 701 )
//  (    4 ,    6 ,  020  )  ||  ( 307 , 080 )     ( 225 , 152 )     ( 180 , 224 )     ( 125 , 351 )
//  (    4 ,    8 ,  020  )  ||  ( 205 , 095 )     ( 140 , 173 )     ( 109 , 256 )     ( 074 , 393 )
//  (    4 ,   10 ,  020  )  ||  ( 153 , 111 )     ( 102 , 192 )     ( 079 , 279 )     ( 054 , 424 )
//  (    4 ,   11 ,  020  )  ||  ( 137 , 117 )     ( 091 , 201 )     ( 071 , 290 )     ( 049 , 437 )
//  (    4 ,   12 ,  020  )  ||  ( 130 , 122 )     ( 086 , 208 )     ( 067 , 299 )     ( 047 , 447 )
//  (    4 ,   16 ,  020  )  ||  ( 104 , 142 )     ( 067 , 236 )     ( 052 , 331 )     ( 036 , 481 )
//  (    8 ,   10 ,  020  )  ||  ( 047 , 175 )     ( 017 , 273 )     ( 010 , 385 )     ( 007 , 561 )
//  (    8 ,   12 ,  020  )  ||  ( 043 , 188 )     ( 019 , 295 )     ( 014 , 409 )     ( 010 , 585 )
//  (    8 ,   16 ,  020  )  ||  ( 037 , 215 )     ( 016 , 335 )     ( 011 , 450 )     ( 008 , 623 )
//  (   10 ,   11 ,  020  )  ||  ( 032 , 217 )     ( 012 , 325 )     ( 011 , 438 )     ( 009 , 622 )
//  (   10 ,   12 ,  020  )  ||  ( 037 , 217 )     ( 018 , 332 )     ( 017 , 446 )     ( 014 , 628 )
//  (   10 ,   16 ,  020  )  ||  ( 031 , 245 )     ( 014 , 375 )     ( 012 , 492 )     ( 009 , 665 )
//  (   11 ,   12 ,  020  )  ||  ( 035 , 216 )     ( 022 , 343 )     ( 022 , 461 )     ( 016 , 638 )
//  (   11 ,   14 ,  020  )  ||  ( 028 , 237 )     ( 017 , 378 )     ( 015 , 491 )     ( 011 , 666 )
//  (   11 ,   16 ,  020  )  ||  ( 029 , 252 )     ( 015 , 391 )     ( 012 , 509 )     ( 009 , 678 )
//  (   12 ,   14 ,  020  )  ||  ( 030 , 246 )     ( 018 , 394 )     ( 015 , 507 )     ( 011 , 680 )
//  (   12 ,   16 ,  020  )  ||  ( 031 , 263 )     ( 015 , 406 )     ( 012 , 525 )     ( 008 , 691 )
//
//
//                           ||      NPV 4             NPV 5             NPV 6             NPV 7
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------------------------------------------
//  (    4 ,  Inf ,  020  )  ||  ( 015 , 695 )     ( 010 , 800 )     ( 005 , 870 )     ( 003 , 921 )
//  (    5 ,  Inf ,  020  )  ||  ( 010 , 742 )     ( 006 , 838 )     ( 003 , 899 )     ( 001 , 943 )
//  (    6 ,  Inf ,  020  )  ||  ( 006 , 777 )     ( 004 , 864 )     ( 001 , 919 )     ( 000 , 956 )
//  (    7 ,  Inf ,  020  )  ||  ( 004 , 803 )     ( 002 , 882 )     ( 001 , 934 )     ( 000 , 965 )
//  (    8 ,  Inf ,  020  )  ||  ( 003 , 823 )     ( 001 , 896 )     ( 000 , 943 )     ( 000 , 970 )
//  (    9 ,  Inf ,  020  )  ||  ( 003 , 842 )     ( 001 , 910 )     ( 000 , 952 )     ( 000 , 976 )
//  (   10 ,  Inf ,  020  )  ||  ( 003 , 855 )     ( 001 , 919 )     ( 000 , 957 )     ( 000 , 979 )
//  (   11 ,  Inf ,  020  )  ||  ( 003 , 866 )     ( 001 , 926 )     ( 000 , 962 )     ( 000 , 981 )
//  (   12 ,  Inf ,  020  )  ||  ( 003 , 876 )     ( 001 , 932 )     ( 000 , 966 )     ( 000 , 982 )
//  (   13 ,  Inf ,  020  )  ||  ( 002 , 886 )     ( 001 , 938 )     ( 000 , 968 )     ( 000 , 984 )
//  (   14 ,  Inf ,  020  )  ||  ( 002 , 890 )     ( 001 , 940 )     ( 000 , 969 )     ( 000 , 984 )
//  (   15 ,  Inf ,  020  )  ||  ( 002 , 895 )     ( 001 , 944 )     ( 000 , 972 )     ( 000 , 986 )
//  (   16 ,  Inf ,  020  )  ||  ( 002 , 902 )     ( 001 , 948 )     ( 000 , 974 )     ( 000 , 988 )
//  (    4 ,    4 ,  020  )  ||  ( 226 , 412 )     ( 159 , 574 )     ( 104 , 693 )     ( 073 , 787 )
//  (    5 ,    5 ,  020  )  ||  ( 097 , 507 )     ( 062 , 662 )     ( 046 , 764 )     ( 031 , 855 )
//  (    6 ,    6 ,  020  )  ||  ( 032 , 577 )     ( 026 , 728 )     ( 008 , 812 )     ( 005 , 886 )
//  (    7 ,    7 ,  020  )  ||  ( 022 , 640 )     ( 020 , 771 )     ( 008 , 862 )     ( 002 , 922 )
//  (    8 ,    8 ,  020  )  ||  ( 002 , 647 )     ( 002 , 761 )     ( 002 , 854 )     ( 000 , 917 )
//  (    9 ,    9 ,  020  )  ||  ( 005 , 709 )     ( 002 , 820 )     ( 000 , 896 )     ( 000 , 948 )
//  (   10 ,   10 ,  020  )  ||  ( 006 , 739 )     ( 000 , 836 )     ( 000 , 911 )     ( 000 , 959 )
//  (   11 ,   11 ,  020  )  ||  ( 006 , 744 )     ( 003 , 858 )     ( 003 , 915 )     ( 000 , 963 )
//  (   12 ,   12 ,  020  )  ||  ( 012 , 761 )     ( 004 , 862 )     ( 004 , 936 )     ( 004 , 964 )
//  (   13 ,   13 ,  020  )  ||  ( 003 , 828 )     ( 000 , 909 )     ( 000 , 956 )     ( 000 , 980 )
//  (   14 ,   14 ,  020  )  ||  ( 004 , 819 )     ( 000 , 884 )     ( 000 , 924 )     ( 000 , 952 )
//  (   15 ,   15 ,  020  )  ||  ( 000 , 807 )     ( 000 , 892 )     ( 000 , 950 )     ( 000 , 967 )
//  (   16 ,   16 ,  020  )  ||  ( 000 , 813 )     ( 000 , 908 )     ( 000 , 943 )     ( 000 , 969 )
//  (    4 ,    6 ,  020  )  ||  ( 093 , 486 )     ( 065 , 642 )     ( 040 , 747 )     ( 027 , 835 )
//  (    4 ,    8 ,  020  )  ||  ( 055 , 529 )     ( 040 , 676 )     ( 024 , 777 )     ( 015 , 858 )
//  (    4 ,   10 ,  020  )  ||  ( 040 , 559 )     ( 028 , 700 )     ( 016 , 797 )     ( 010 , 873 )
//  (    4 ,   11 ,  020  )  ||  ( 036 , 570 )     ( 025 , 709 )     ( 015 , 804 )     ( 009 , 878 )
//  (    4 ,   12 ,  020  )  ||  ( 034 , 580 )     ( 023 , 717 )     ( 014 , 811 )     ( 008 , 883 )
//  (    4 ,   16 ,  020  )  ||  ( 026 , 611 )     ( 017 , 741 )     ( 010 , 828 )     ( 006 , 894 )
//  (    8 ,   10 ,  020  )  ||  ( 004 , 693 )     ( 001 , 802 )     ( 000 , 884 )     ( 000 , 939 )
//  (    8 ,   12 ,  020  )  ||  ( 006 , 712 )     ( 002 , 820 )     ( 001 , 897 )     ( 000 , 947 )
//  (    8 ,   16 ,  020  )  ||  ( 004 , 744 )     ( 001 , 844 )     ( 001 , 911 )     ( 000 , 953 )
//  (   10 ,   11 ,  020  )  ||  ( 006 , 742 )     ( 001 , 847 )     ( 001 , 913 )     ( 000 , 961 )
//  (   10 ,   12 ,  020  )  ||  ( 008 , 747 )     ( 002 , 851 )     ( 002 , 919 )     ( 001 , 962 )
//  (   10 ,   16 ,  020  )  ||  ( 005 , 780 )     ( 001 , 873 )     ( 001 , 931 )     ( 000 , 965 )
//  (   11 ,   12 ,  020  )  ||  ( 009 , 752 )     ( 003 , 860 )     ( 003 , 924 )     ( 001 , 963 )
//  (   11 ,   14 ,  020  )  ||  ( 007 , 783 )     ( 002 , 876 )     ( 002 , 932 )     ( 001 , 965 )
//  (   11 ,   16 ,  020  )  ||  ( 004 , 790 )     ( 001 , 882 )     ( 001 , 936 )     ( 000 , 966 )
//  (   12 ,   14 ,  020  )  ||  ( 007 , 800 )     ( 001 , 884 )     ( 001 , 939 )     ( 001 , 966 )
//  (   12 ,   16 ,  020  )  ||  ( 004 , 804 )     ( 000 , 890 )     ( 000 , 942 )     ( 000 , 967 )
//
//
//                           ||      NPV 8             NPV 9             NPV 10
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------------------------
//  (    4 ,  Inf ,  020  )  ||  ( 001 , 961 )     ( 000 , 990 )     ( 000 , 1000 )
//  (    5 ,  Inf ,  020  )  ||  ( 000 , 972 )     ( 000 , 994 )     ( 000 , 1000 )
//  (    6 ,  Inf ,  020  )  ||  ( 000 , 978 )     ( 000 , 996 )     ( 000 , 1000 )
//  (    7 ,  Inf ,  020  )  ||  ( 000 , 983 )     ( 000 , 997 )     ( 000 , 1000 )
//  (    8 ,  Inf ,  020  )  ||  ( 000 , 986 )     ( 000 , 998 )     ( 000 , 1000 )
//  (    9 ,  Inf ,  020  )  ||  ( 000 , 989 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   10 ,  Inf ,  020  )  ||  ( 000 , 991 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   11 ,  Inf ,  020  )  ||  ( 000 , 992 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   12 ,  Inf ,  020  )  ||  ( 000 , 992 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   13 ,  Inf ,  020  )  ||  ( 000 , 994 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   14 ,  Inf ,  020  )  ||  ( 000 , 994 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   15 ,  Inf ,  020  )  ||  ( 000 , 995 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   16 ,  Inf ,  020  )  ||  ( 000 , 995 )     ( 000 , 999 )     ( 000 , 1000 )
//  (    4 ,    4 ,  020  )  ||  ( 030 , 894 )     ( 012 , 966 )     ( 000 , 1000 )
//  (    5 ,    5 ,  020  )  ||  ( 003 , 929 )     ( 003 , 980 )     ( 000 , 1000 )
//  (    6 ,    6 ,  020  )  ||  ( 002 , 942 )     ( 002 , 985 )     ( 000 , 1000 )
//  (    7 ,    7 ,  020  )  ||  ( 002 , 957 )     ( 000 , 990 )     ( 000 , 1000 )
//  (    8 ,    8 ,  020  )  ||  ( 000 , 957 )     ( 000 , 993 )     ( 000 , 1000 )
//  (    9 ,    9 ,  020  )  ||  ( 000 , 969 )     ( 000 , 994 )     ( 000 , 1000 )
//  (   10 ,   10 ,  020  )  ||  ( 000 , 984 )     ( 000 , 997 )     ( 000 , 1000 )
//  (   11 ,   11 ,  020  )  ||  ( 000 , 988 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   12 ,   12 ,  020  )  ||  ( 004 , 978 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   13 ,   13 ,  020  )  ||  ( 000 , 990 )     ( 000 , 1000 )    ( 000 , 1000 )
//  (   14 ,   14 ,  020  )  ||  ( 000 , 978 )     ( 000 , 997 )     ( 000 , 1000 )
//  (   15 ,   15 ,  020  )  ||  ( 000 , 991 )     ( 000 , 1000 )    ( 000 , 1000 )
//  (   16 ,   16 ,  020  )  ||  ( 000 , 989 )     ( 000 , 1000 )    ( 000 , 1000 )
//  (    4 ,    6 ,  020  )  ||  ( 008 , 918 )     ( 005 , 976 )     ( 000 , 1000 )
//  (    4 ,    8 ,  020  )  ||  ( 005 , 929 )     ( 002 , 980 )     ( 000 , 1000 )
//  (    4 ,   10 ,  020  )  ||  ( 003 , 936 )     ( 001 , 982 )     ( 000 , 1000 )
//  (    4 ,   11 ,  020  )  ||  ( 003 , 939 )     ( 001 , 983 )     ( 000 , 1000 )
//  (    4 ,   12 ,  020  )  ||  ( 003 , 941 )     ( 001 , 984 )     ( 000 , 1000 )
//  (    4 ,   16 ,  020  )  ||  ( 002 , 947 )     ( 001 , 986 )     ( 000 , 1000 )
//  (    8 ,   10 ,  020  )  ||  ( 000 , 969 )     ( 000 , 995 )     ( 000 , 1000 )
//  (    8 ,   12 ,  020  )  ||  ( 000 , 973 )     ( 000 , 996 )     ( 000 , 1000 )
//  (    8 ,   16 ,  020  )  ||  ( 000 , 978 )     ( 000 , 997 )     ( 000 , 1000 )
//  (   10 ,   11 ,  020  )  ||  ( 000 , 986 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   10 ,   12 ,  020  )  ||  ( 001 , 984 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   10 ,   16 ,  020  )  ||  ( 000 , 985 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   11 ,   12 ,  020  )  ||  ( 001 , 984 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   11 ,   14 ,  020  )  ||  ( 001 , 984 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   11 ,   16 ,  020  )  ||  ( 000 , 986 )     ( 000 , 999 )     ( 000 , 1000 )
//  (   12 ,   14 ,  020  )  ||  ( 001 , 982 )     ( 000 , 998 )     ( 000 , 1000 )
//  (   12 ,   16 ,  020  )  ||  ( 000 , 985 )     ( 000 , 999 )     ( 000 , 1000 )
//
//
//
//
//
//
//                           ||      Bayes            Adaboost           Convex
//  ( NMin , NMax , alpha )  ||  ( fpr , fnr )     ( fpr , fnr )     ( fpr , fnr )
// --------------------------++------------------------------------------------------
//  (    4 ,  Inf ,  020  )  ||   ( 137, 138 )      ( 011, 788 )      ( 011, 788 )
//  (    5 ,  Inf ,  020  )  ||   ( 125, 150 )      ( 007, 823 )      ( 007, 823 )
//  (    6 ,  Inf ,  020  )  ||   ( 112, 164 )      ( 005, 848 )      ( 005, 848 )
//  (    7 ,  Inf ,  020  )  ||   ( 098, 177 )      ( 004, 865 )      ( 004, 865 )
//  (    8 ,  Inf ,  020  )  ||   ( 089, 192 )      ( 003, 876 )      ( 003, 876 )
//  (    9 ,  Inf ,  020  )  ||   ( 083, 205 )      ( 003, 889 )      ( 003, 889 )
//  (   10 ,  Inf ,  020  )  ||   ( 080, 217 )      ( 003, 899 )      ( 003, 899 )
//  (   11 ,  Inf ,  020  )  ||   ( 077, 227 )      ( 003, 906 )      ( 003, 906 )
//  (   12 ,  Inf ,  020  )  ||   ( 074, 238 )      ( 003, 913 )      ( 003, 913 )
//  (   13 ,  Inf ,  020  )  ||   ( 068, 249 )      ( 002, 919 )      ( 002, 919 )
//  (   14 ,  Inf ,  020  )  ||   ( 063, 259 )      ( 002, 923 )      ( 002, 923 )
//  (   15 ,  Inf ,  020  )  ||   ( 056, 268 )      ( 002, 928 )      ( 002, 928 )
//  (   16 ,  Inf ,  020  )  ||   ( 043, 279 )      ( 002, 932 )      ( 002, 932 )
//  (    4 ,    4 ,  020  )  ||   ( 601, 066 )      ( 177, 580 )      ( 177, 580 )
//  (    5 ,    5 ,  020  )  ||   ( 449, 061 )      ( 070, 653 )      ( 070, 653 )
//  (    6 ,    6 ,  020  )  ||   ( 330, 066 )      ( 018, 724 )      ( 018, 724 )
//  (    7 ,    7 ,  020  )  ||   ( 232, 058 )      ( 017, 771 )      ( 017, 771 )
//  (    8 ,    8 ,  020  )  ||   ( 174, 066 )      ( 002, 752 )      ( 002, 752 )
//  (    9 ,    9 ,  020  )  ||   ( 131, 083 )      ( 002, 790 )      ( 002, 790 )
//  (   10 ,   10 ,  020  )  ||   ( 114, 104 )      ( 003, 823 )      ( 003, 823 )
//  (   11 ,   11 ,  020  )  ||   ( 123, 110 )      ( 006, 823 )      ( 006, 823 )
//  (   12 ,   12 ,  020  )  ||   ( 183, 093 )      ( 012, 838 )      ( 012, 838 )
//  (   13 ,   13 ,  020  )  ||   ( 136, 131 )      ( 003, 875 )      ( 003, 875 )
//  (   14 ,   14 ,  020  )  ||   ( 177, 130 )      ( 004, 849 )      ( 004, 849 )
//  (   15 ,   15 ,  020  )  ||   ( 236, 126 )      ( 000, 880 )      ( 000, 880 )
//  (   16 ,   16 ,  020  )  ||   ( 147, 142 )      ( 000, 862 )      ( 000, 862 )
//  (    4 ,    6 ,  020  )  ||   ( 424, 064 )      ( 068, 641 )      ( 068, 641 )
//  (    4 ,    8 ,  020  )  ||   ( 320, 063 )      ( 040, 674 )      ( 040, 674 )
//  (    4 ,   10 ,  020  )  ||   ( 259, 068 )      ( 029, 695 )      ( 029, 695 )
//  (    4 ,   11 ,  020  )  ||   ( 243, 070 )      ( 026, 702 )      ( 026, 702 )
//  (    4 ,   12 ,  020  )  ||   ( 238, 072 )      ( 025, 709 )      ( 025, 709 )
//  (    4 ,   16 ,  020  )  ||   ( 222, 079 )      ( 019, 730 )      ( 019, 730 )
//  (    8 ,   10 ,  020  )  ||   ( 140, 082 )      ( 002, 785 )      ( 002, 785 )
//  (    8 ,   12 ,  020  )  ||   ( 144, 089 )      ( 005, 799 )      ( 005, 799 )
//  (    8 ,   16 ,  020  )  ||   ( 154, 102 )      ( 004, 820 )      ( 004, 820 )
//  (   10 ,   11 ,  020  )  ||   ( 118, 107 )      ( 004, 823 )      ( 004, 823 )
//  (   10 ,   12 ,  020  )  ||   ( 136, 103 )      ( 007, 827 )      ( 007, 827 )
//  (   10 ,   16 ,  020  )  ||   ( 155, 116 )      ( 004, 846 )      ( 004, 846 )
//  (   11 ,   12 ,  020  )  ||   ( 150, 102 )      ( 009, 830 )      ( 009, 830 )
//  (   11 ,   14 ,  020  )  ||   ( 152, 115 )      ( 007, 844 )      ( 007, 844 )
//  (   11 ,   16 ,  020  )  ||   ( 164, 120 )      ( 004, 852 )      ( 004, 852 )
//  (   12 ,   14 ,  020  )  ||   ( 164, 116 )      ( 007, 854 )      ( 007, 854 )
//  (   12 ,   16 ,  020  )  ||   ( 175, 122 )      ( 004, 860 )      ( 004, 860 )
//
//
