#version 330

// This code was spaghettified by nearby black hole code.

// Normalized screen coordinates
in vec2 pos;

// Colour that will eventually be on the screen
out vec4 outCol;

// Some input from outside
uniform vec2 screenSize;
uniform vec2 aspect;
uniform sampler2D skymap;
uniform sampler2D dustmap;
uniform float time;
uniform vec3 cameraPos;
uniform mat3 cameraDir;

// The value we all know and love
#define PI 3.1415926535


// Cast a ray to the skymap. Origin doesn't matter as the skymap is infintely far away. Returns the colour of the
// skymap.
vec4 castSkymap(vec3 d) {
    float h = (atan(d.z, d.x) + PI) / (2 * PI);
    float v = (atan(d.y, length(d.xz)) * 2 / PI) / 2 + 0.5;

    return texture(skymap, vec2(h, v));
}

// Returns an axis-angle rotation matrix
mat3 rotationMatrix(vec3 axis, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat3(
    oc * axis.x * axis.x + c, /*    */ oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s,
    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, /*    */ oc * axis.y * axis.z - axis.x * s,
    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c /*    */
    );
}

// Computes the black hole gravitational lensing.
bool raycastBlackHole(vec3 rayO, vec3 rayD, vec3 center, float lens, float schwarzschild, float photonSphereCycles, float holeBlur, out vec3 outO, out vec3 outD, out float hole) {
    vec3 pos = center - rayO;

    float projD = dot(pos, rayD);
    vec3 projP = rayD * projD;

    float x = distance(pos, projP);

    float y = sqrt(lens * lens - x * x);
    float t = projD - y;

    if (t < 0) {
        return false;
    }

    if (x > lens) {
        return false;
    }

    float ox = x - schwarzschild;
    float dx = 1.0 + ox;
    float mx = lens - schwarzschild;
    float ip = 1.0 - (ox / mx);

    float cycles = mix(0.0, photonSphereCycles / (dx * dx * dx), ip * ip);
    float angle = cycles * 2.0 * PI; // This is the amount of angle the ray orbits around the black hole

    // Rotate around the black hole here:
    vec3 rotAxis = normalize(cross(rayD, pos));

    vec3 pt = t * rayD;
    vec3 localPt = pt - pos;

    mat3 rot = rotationMatrix(rotAxis, -angle);

    vec3 newLocalPt = rot * localPt;
    vec3 newD = rot * rayD;

    outD = newD;
    outO = rayO + pos + newLocalPt;


    // Compute hole factor: how much black do we see
    if (x < schwarzschild) {
        hole = 1;
    } else if (x < schwarzschild + holeBlur) {
        hole = 1 - (x - schwarzschild) / holeBlur;
    } else {
        hole = 0;
    }

    return true;
}


// Raycast a star
bool raycastStar(vec3 rayO, vec3 rayD, vec3 center, float innerRadius, float lightRadius, out vec3 outO, out vec3 outD, out float light, out float background) {
    vec3 pos = center - rayO;

    float projD = dot(pos, rayD);
    vec3 projP = rayD * projD;

    float x = distance(pos, projP);

    float r = lightRadius;
    float y = sqrt(lightRadius * lightRadius - x * x);
    float t1 = projD - y;
    float t2 = projD + y;

    if (t1 < 0) {
        return false;
    }

    if (x > lightRadius) {
        return false;
    }

    outD = rayD;
    outO = rayO + t2 * rayD;

    if (x < innerRadius) {
        float ip = x / innerRadius;
        float ip4 = ip * ip * ip * ip;

        background = 0;
        light = (1 + (1 - ip4) * 3);

    } else {
        float ip = 1 - (x - innerRadius) / (lightRadius - innerRadius);

        background = 1;
        light = ip * ip * ip;
    }

    return true;
}

// Raycast a dust disc
bool raycastDust(vec3 rayO, vec3 rayD, vec3 center, vec3 norm, float radius, out vec3 outO, out vec3 outD, out float dust, out float t) {
    vec3 pos = center - rayO;

    t = dot(pos, norm) / dot(rayD, norm);

    if (t < 0) {
        return false;
    }

    outD = rayD;
    outO = rayO + t * rayD;

    float d = distance(outO, center);
    if (d > radius) {
        return false;
    }

    float f = d / radius;
    dust = (1 - f * f * f) * (1 - f);

    return true;
}

// General sphere raycast, which is used to determine which object we hit first without adding all the extra calculations
bool raycastSphere(vec3 o, vec3 d, vec3 center, float r, bool inside, out float t, out vec3 n, out vec2 uv) {
    vec3 pos = center - o;

    float projD = dot(pos, d);
    vec3 projP = d * projD;

    float x = distance(pos, projP);

    if (x > r) {
        return false;
    }

    float y = sqrt(r * r - x * x);
    t = inside ? projD + y : projD - y;

    if (t < 0) {
        return false;
    }

    vec3 hitPt = t * d;
    n = normalize(hitPt - pos);

    return true;
}

#define MAX_BOUNCES 30

// Object definitions

#define TYPE_PLANET 0u
#define TYPE_BLACK_HOLE 1u
#define TYPE_STAR 2u
#define TYPE_DUST 3u

struct Object {
    uint type;

    vec3 pos;
    vec3 up;
    float radius;

    // Misc properties, vary per object type
    float a;
    float b;
    float c;
    vec3 color;
};


// Action definitions
#define A_RAYCAST 0u
#define A_COMBINE_BLACK_HOLE 1u
#define A_COMBINE_STAR 2u
#define A_COMBINE_DUST 3u

struct Action {
    uint type;

    // raycast
    vec3 d, o;
    int bounce;
    int skip;

    // misc
    float a, b, c, d;
    int obj;

    // return value
    vec3 col;
};


void main() {
    // Compute ray direction
    vec2 l = pos * aspect * 0.5;
    vec3 d = normalize(cameraDir * vec3(l.x, l.y, -1));
    vec3 o = cameraPos;

    // Ojbects
    Object objects[50];
    int objectCount = 3;

    // Black hole
    objects[0].type = TYPE_BLACK_HOLE;
    objects[0].pos = vec3(0, 0, 0);
    objects[0].radius = 12.0;
    objects[0].a = 4.0; // Schwarzschild radius
    objects[0].b = 2.0; // Amount of light orbits at photon sphere
    objects[0].c = 1.7; // Blur radius of black hole

    // Star
    objects[1].type = TYPE_STAR;
    objects[1].pos = vec3(sin(time / 10.0 + 7.9917377) * 40, 0.0, cos(time / 10.0 + 7.9917377) * 40);
    objects[1].radius = 5.0;
    objects[1].a = 4.0; // Core radius
    objects[1].color = vec3(1.0, 0.3, 0.1);

    // Star
    objects[2].type = TYPE_STAR;
    objects[2].pos = vec3(sin(-time / 2.5) * 20, 0.0, cos(-time / 2.5) * 20);
    objects[2].radius = 3.0;
    objects[2].a = 2.3; // Core radius
    objects[2].color = vec3(0.7, 0.8, 1.0);

    for (int i = 0; i < 10; i++) {
        // Dust
        objects[objectCount].type = TYPE_DUST;
        objects[objectCount].pos = vec3(sin(i / (6.0 / (2 * PI))) * 18, sin(i * 239), cos(i / (6.0 / (2 * PI))) * 18);
        objects[objectCount].radius = 17.0;
        objects[objectCount].up = normalize(vec3(sin(i * 881 + 34) * 0.1, 1, sin(i * 263 + 55) * 0.1));
        objects[objectCount].a = 0.2 * sin(i * 818) + 0.9; // Opacity
        objects[objectCount].color = vec3(1.0, 1.0, 1.0);

        objectCount++;

        // Outer Dust
        objects[objectCount].type = TYPE_DUST;
        objects[objectCount].pos = vec3(sin(i / (6.0 / (2 * PI))) * 25, sin(i * 125 + 881), cos(i / (6.0 / (2 * PI))) * 25);
        objects[objectCount].radius = 28.0;
        objects[objectCount].up = normalize(vec3(sin(i * 32 + 51) * 0.1, 1, sin(i * 87 + 31) * 0.1));
        objects[objectCount].a = 0.2 * sin(i * 2124 + 3) + 0.7; // Opacity
        objects[objectCount].color = vec3(1.0, 1.0, 1.0);

        objectCount++;
    }



    vec3 no, nd;

    // Action stack:
    Action as[2 * MAX_BOUNCES + 1];

    as[0].type = A_RAYCAST;
    as[0].d = d;
    as[0].o = o;
    as[0].bounce = 0;
    as[0].skip = -1;

    vec3 color = vec3(0, 0, 1);

    int stack = 1;

    int iterations = 0;
    while (stack > 0 && iterations <= 6 * MAX_BOUNCES) {
        iterations++;

        // Do some stackoverflow checking. Also catch infinite recursion here
        if (stack > 2 * MAX_BOUNCES + 1) {
            color = vec3(0, 1, 1);
            break;
        }

        if (iterations >= 6 * MAX_BOUNCES) {
            color = vec3(1, float(stack) / (2), 1);
            break;
        }

        stack--;

        Action action = as[stack];

        if (action.type == A_RAYCAST) {
            // Raycast action
            int hitIndex = -1;
            float hitT = 1e20;

            int bounce = action.bounce;
            int skip = action.skip;
            vec3 co = action.o;
            vec3 cd = action.d;

            // First determine what object we hit
            for (int oi = 0; oi < objectCount; oi++) {
                if (oi == skip) {
                    continue;
                }

                Object obj = objects[oi];


                // Dust objects aren't spheres, we must treat them differently
                if (obj.type == TYPE_DUST) {
                    float t, dust;
                    vec3 tmpO, tmpD;
                    if (raycastDust(co, cd, obj.pos, obj.up, obj.radius, tmpO, tmpD, dust, t)) {
                        if (t < hitT) {
                            hitIndex = oi;
                            hitT = t;
                        }
                    }
                } else {
                    float t;
                    vec3 n;
                    vec2 uv;
                    if (raycastSphere(co, cd, obj.pos, obj.radius, false, t, n, uv)) {
                        if (t < hitT) {
                            hitIndex = oi;
                            hitT = t;
                        }
                    }
                }
            }


            // If we hit something:
            if (hitIndex != -1) {
                Object hitObj = objects[hitIndex];

                vec3 hitP = co + cd * hitT;

                float hole, lt, bt, dust, t;


                // Note that whatever actions we push will happen in reverse order
                switch (hitObj.type) {
                    case TYPE_BLACK_HOLE:
                        if (raycastBlackHole(co, cd, hitObj.pos, hitObj.radius, hitObj.a, hitObj.b, hitObj.c, no, nd, hole)) {
                            // Black hole hit: push a black hole processing step
                            as[stack].type = A_COMBINE_BLACK_HOLE;
                            as[stack].a = hole;
                            as[stack].o = hitP;
                            as[stack].obj = hitIndex;
                            as[stack].col = vec3(0, 0, 0);

                            stack++;

                            if (hole < 0.9999) {
                                // If we don't cross the event horizon, cast a lensed ray
                                if (bounce < MAX_BOUNCES) {
                                    as[stack].type = A_RAYCAST;
                                    as[stack].d = nd;
                                    as[stack].o = no;
                                    as[stack].skip = hitIndex;
                                    as[stack].bounce = bounce + 1;

                                    stack++;
                                } else {
                                    // Out of bounces, simply cast the skymap
                                    as[stack].col = castSkymap(nd).rgb;
                                }
                            }
                            continue;
                        }
                        break;

                    case TYPE_STAR:
                        if (raycastStar(co, cd, hitObj.pos, hitObj.a, hitObj.radius, no, nd, lt, bt)) {
                            // Star hit: push star processing step
                            as[stack].type = A_COMBINE_STAR;
                            as[stack].a = lt;
                            as[stack].b = bt;
                            as[stack].o = hitP;
                            as[stack].obj = hitIndex;
                            as[stack].col = vec3(0, 0, 0);

                            stack++;

                            if (bt > 0) {
                                // If we did not go through the inner sphere of the star, we still see background, so
                                // continue tracing
                                if (bounce < MAX_BOUNCES) {
                                    as[stack].type = A_RAYCAST;
                                    as[stack].d = nd;
                                    as[stack].o = no;
                                    as[stack].skip = hitIndex;
                                    as[stack].bounce = bounce + 1;

                                    stack++;
                                } else {
                                    as[stack].col = castSkymap(nd).rgb;
                                }
                            }
                            continue;
                        }
                        break;

                    case TYPE_DUST:
                        if (raycastDust(co, cd, hitObj.pos, hitObj.up, hitObj.radius, no, nd, dust, t)) {
                            // Dust hit: dust processing step
                            as[stack].type = A_COMBINE_DUST;
                            as[stack].a = dust;
                            as[stack].o = hitP;
                            as[stack].obj = hitIndex;
                            as[stack].col = vec3(0, 0, 0);

                            stack++;

                            // Dust is always transparent, so keep on tracing
                            if (bounce < MAX_BOUNCES) {
                                as[stack].type = A_RAYCAST;
                                as[stack].d = nd;
                                as[stack].o = no;
                                as[stack].skip = hitIndex;
                                as[stack].bounce = bounce + 1;

                                stack++;
                            } else {
                                as[stack].col = castSkymap(nd).rgb;
                            }
                            continue;
                        }
                        break;
                }
            }

            // If we hit nothing or we didn't process what we hit, we will hit the skymap
            vec3 rayColor = castSkymap(cd).rgb;
            if (stack <= 0) {
                color = rayColor;
                break;
            } else {
                // Output color to the color of the action below in the stack, equivalent to returning in recursion
                as[stack - 1].col = rayColor;
            }
        } else if (action.type == A_COMBINE_BLACK_HOLE) {
            // Action: process a black hole. We already did the lensing at this point so this just mixes in the black
            // part of the black hole.
            float hole = action.a;
            vec3 background = action.col;

            vec3 rayColor = background * (1 - hole);
            if (stack <= 0) {
                color = rayColor;
                break;
            } else {
                as[stack - 1].col = rayColor;
            }
        } else if (action.type == A_COMBINE_STAR) {
            // Action: process a star. We simply mix the light with the background.
            float lt = action.a;
            float bt = action.b;
            vec3 background = action.col;

            vec3 rayColor = background * bt + objects[action.obj].color * lt;
            if (stack <= 0) {
                color = rayColor;
                break;
            } else {
                as[stack - 1].col = rayColor;
            }
        } else if (action.type == A_COMBINE_DUST) {
            // Action: process dust.
            float dust = action.a;
            vec3 background = action.col;
            vec3 hitP = action.o;

            Object cobj = objects[action.obj];

            vec3 lighting = vec3(0.4);
            float proximity = 1;

            // Iterate objects, some of them are stars that illuminate the dust, and we fade dust to transparent near
            // objects so they don't seem to shamelessly clip through.
            for (int oi = 0; oi < objectCount; oi++) {
                Object obj = objects[oi];

                if (obj.type == TYPE_DUST) { // Dust doesn't count here
                    continue;
                }

                // Proximity transparency factor
                float rd = distance(hitP, obj.pos) - obj.radius;
                if (rd < 0) {
                    proximity = 0;
                } else {
                    proximity *= tanh(rd / 7);
                }

                // If a star is near, illuminate the dust
                if (obj.type == TYPE_STAR) {
                    float d = (distance(hitP, obj.pos) - obj.radius) / 4 + 0.7;
                    float i = 15 / (d * d);
                    lighting += i * obj.color;
                }
            }

            // Apply dust texture map
            vec2 duv = hitP.xz / 80 + vec2(0.5);
            float dustFac = texture(dustmap, duv).r;

            // Final mix
            vec3 rayColor = mix(background, cobj.color * lighting, dust * proximity * cobj.a * dustFac);
            if (stack <= 0) {
                color = rayColor;
                break;
            } else {
                as[stack - 1].col = rayColor;
            }
        }
    }

    // Aaaand we're done!
    outCol = vec4(color, 1);
}
