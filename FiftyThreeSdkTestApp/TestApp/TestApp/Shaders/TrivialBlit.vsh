//
//  TrivialBlit.vsh
//  TestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//
attribute vec2 inVertex;
attribute vec2 inTex;
uniform mat4 MVP;

varying vec2 tex0;

void main()
{
    gl_Position = MVP * vec4(inVertex.x, inVertex.y, 0, 1);
    tex0 = inTex;
}
