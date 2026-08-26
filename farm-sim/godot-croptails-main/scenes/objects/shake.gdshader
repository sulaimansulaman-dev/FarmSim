shader_type canvas_item;

uniform float intensity = 0.0;
uniform float speed = 1.0;

void vertex() {
    vec2 shake = vec2(0.0);

    if (VERTEX.y < 0.0)
        shake.x = sin(TIME * speed * 2.0 * PI) * VERTEX.y * intensity;

    VERTEX.xy += shake;
}