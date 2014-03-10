//
//  Shader.fsh
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
