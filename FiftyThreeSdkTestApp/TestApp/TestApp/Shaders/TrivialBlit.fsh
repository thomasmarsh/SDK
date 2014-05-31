
uniform sampler2D texture;
varying highp vec2 tex0;

void main()
{
    gl_FragColor = texture2D(texture, tex0);
}