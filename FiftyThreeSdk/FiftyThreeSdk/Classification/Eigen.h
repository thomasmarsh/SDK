//
//  Eigen.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

// We need to turn off 64 bit warnings in Eigen headers.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-register"

// Note this pulls in lot of extra numerics that only the classification project actually uses.
#include <Eigen/Dense>
#include <Eigen/Geometry>
#include <Eigen/QR>

#pragma clang diagnostic pop
#pragma clang diagnostic pop
