#version 330

layout (location = 0) in vec3 inPos;

out vec2 pos;

void main() {
    gl_Position = vec4(inPos, 1);

    pos = inPos.xy;
}
