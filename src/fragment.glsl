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
    vec3 base = mix(vec3(0.05, 0.14, 0.35), vec3(0.95, 0.55, 0.22), smoothstep(0.05, 0.95, s));
    base += vec3(0.2, 0.1, 0.25) * exp(-3.0 * trap);

    col = base * (0.13 + 1.25 * diff) + 0.75 * spec + 0.35 * fres;
  } else {
    float g = 0.5 + 0.5 * rd.y;
    col = mix(vec3(0.01, 0.01, 0.02), vec3(0.06, 0.09, 0.15), g);
  }

  col = col / (1.0 + col);
  col = pow(col, vec3(0.94));

  gl_FragColor = vec4(col, 1.0);
}
