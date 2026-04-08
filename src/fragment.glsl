precision highp float;

varying vec2 vUv;

uniform float u_time;
uniform vec2  u_resolution;
uniform vec3  u_cameraPos;
uniform vec3  u_cameraTarget;

#define MAX_STEPS 150
#define MAX_DIST  90.0
#define HIT_EPS   0.0013
#define FRACTAL_ITERS 10
#define BAILOUT 8.0

vec3 palette(float t){
  // Cosine palette for rich spectral color variation.
  vec3 a = vec3(0.52, 0.50, 0.55);
  vec3 b = vec3(0.48, 0.46, 0.45);
  vec3 c = vec3(1.00, 1.00, 1.00);
  vec3 d = vec3(0.00, 0.20, 0.40);
  return a + b * cos(6.28318 * (c * t + d));
}

mat3 rotY(float a){
  float c = cos(a), s = sin(a);
  return mat3(
    c, 0.0, -s,
    0.0, 1.0, 0.0,
    s, 0.0,  c
  );
}

mat3 rotX(float a){
  float c = cos(a), s = sin(a);
  return mat3(
    1.0, 0.0, 0.0,
    0.0, c, -s,
    0.0, s,  c
  );
}

// Mandelbulb DE with animated power (2..8) and subtle entropy rotation.
float mandelbulbDE(vec3 p, out float trap){
  vec3 z = p;
  float dr = 1.0;
  float r = 0.0;
  trap = 1e9;

  float power = mix(2.0, 8.0, 0.5 + 0.5 * sin(u_time * 0.23));

  for(int i = 0; i < FRACTAL_ITERS; i++){
    r = length(z);
    if(r > BAILOUT) break;

    trap = min(trap, r);

    float theta = acos(clamp(z.z / max(r, 1e-6), -1.0, 1.0));
    float phi = atan(z.y, z.x);

    dr = power * pow(r, power - 1.0) * dr + 1.0;

    float zr = pow(r, power);
    theta *= power;
    phi   *= power;

    z = zr * vec3(
      sin(theta) * cos(phi),
      sin(theta) * sin(phi),
      cos(theta)
    ) + p;

    // Entropy injection: deterministic time-rotation that slowly destabilizes symmetry.
    z = rotY(0.08 * sin(u_time * 0.35)) * rotX(0.056 * sin(u_time * 0.35)) * z;
  }

  return 0.5 * log(max(r, 1e-6)) * r / max(dr, 1e-6);
}

float mapScene(vec3 p, out float trap){
  return mandelbulbDE(p, trap);
}

vec3 calcNormal(vec3 p){
  float t;
  vec2 e = vec2(HIT_EPS, 0.0);
  return normalize(vec3(
    mapScene(p + e.xyy, t) - mapScene(p - e.xyy, t),
    mapScene(p + e.yxy, t) - mapScene(p - e.yxy, t),
    mapScene(p + e.yyx, t) - mapScene(p - e.yyx, t)
  ));
}

void buildCameraBasis(in vec3 ro, in vec3 ta, out vec3 f, out vec3 r, out vec3 u){
  f = normalize(ta - ro);
  r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
  u = cross(f, r);
}

void main(){
  vec2 uv = vUv * 2.0 - 1.0;
  uv.x *= u_resolution.x / max(u_resolution.y, 1.0);

  vec3 ro = u_cameraPos;
  vec3 ta = u_cameraTarget;

  vec3 f, r, u;
  buildCameraBasis(ro, ta, f, r, u);

  vec3 rd = normalize(uv.x * r + uv.y * u + 1.9 * f);

  float dTravel = 0.0;
  float d = 0.0;
  float trap = 0.0;
  int steps = 0;

  for(int i = 0; i < MAX_STEPS; i++){
    vec3 p = ro + rd * dTravel;
    d = mapScene(p, trap);

    if(d < HIT_EPS || dTravel > MAX_DIST){
      steps = i;
      break;
    }

    dTravel += d * 0.92;
    steps = i;
  }

  vec3 col;

  if(dTravel < MAX_DIST){
    vec3 p = ro + rd * dTravel;
    vec3 n = calcNormal(p);

    vec3 lightPos = vec3(6.0, 7.0, 5.0);
    vec3 l = normalize(lightPos - p);
    vec3 v = normalize(ro - p);
    vec3 h = normalize(l + v);

    float diff = max(dot(n, l), 0.0);
    float spec = pow(max(dot(n, h), 0.0), 60.0);
    float fres = pow(1.0 - max(dot(n, v), 0.0), 3.0);

    float s = float(steps) / float(MAX_STEPS);

    // Multi-source color signal: marching complexity + orbit trap + slow time hue drift.
    float colorT = s * 1.6 + 0.45 * exp(-2.2 * trap) + 0.08 * sin(u_time * 0.22);
    vec3 spectral = palette(colorT);

    // Extra magenta/cyan accent layer to intensify fractal boundaries.
    vec3 accent = mix(vec3(1.00, 0.15, 0.70), vec3(0.05, 0.95, 1.00), smoothstep(0.10, 0.95, s));
    vec3 base = mix(spectral, accent, 0.35 + 0.25 * fres);

    col = base * (0.16 + 1.35 * diff) + 0.95 * spec + 0.55 * fres;
  } else {
    float g = 0.5 + 0.5 * rd.y;
    vec3 skyA = vec3(0.01, 0.01, 0.03);
    vec3 skyB = vec3(0.12, 0.05, 0.22);
    vec3 skyC = vec3(0.08, 0.25, 0.40);
    col = mix(skyA, skyB, g);
    col = mix(col, skyC, 0.35 * (0.5 + 0.5 * sin(u_time * 0.15 + rd.x * 1.8)));
  }

  col = col / (1.0 + col);
  col = pow(col, vec3(0.90));

  gl_FragColor = vec4(col, 1.0);
}
