import * as THREE from 'three';
import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

const app = document.querySelector('#app');
if (app) app.remove();

const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

const uniforms = {
  u_time: { value: 0 },
  u_resolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
  u_cameraPos: { value: new THREE.Vector3(0, 0, 5) },
  u_cameraTarget: { value: new THREE.Vector3(0, 0, 0) },
};

const material = new THREE.ShaderMaterial({
  vertexShader,
  fragmentShader,
  uniforms,
});

const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), material);
scene.add(quad);

// Order vs chaos concept:
// The camera path is deterministic trigonometric law (order),
// continuously observing recursive fractal instability (chaos).
function updateCameraPath(t) {
  const radius = 4.6 + 0.7 * Math.sin(t * 0.17);
  const azimuth = t * 0.22 + 0.4 * Math.sin(t * 0.11);
  const polar = 1.05 + 0.22 * Math.sin(t * 0.19) + 0.08 * Math.cos(t * 0.07);

  const sp = Math.sin(polar);
  const cp = Math.cos(polar);

  const x = radius * sp * Math.cos(azimuth);
  const y = radius * cp;
  const z = radius * sp * Math.sin(azimuth);

  uniforms.u_cameraPos.value.set(x, y, z);

  // Small target drift keeps framing cinematic but stable.
  uniforms.u_cameraTarget.value.set(
    0.25 * Math.sin(t * 0.13),
    0.18 * Math.sin(t * 0.21),
    0.25 * Math.cos(t * 0.16),
  );
}

function onResize() {
  renderer.setSize(window.innerWidth, window.innerHeight);
  uniforms.u_resolution.value.set(window.innerWidth, window.innerHeight);
}

window.addEventListener('resize', onResize);

const clock = new THREE.Clock();

function animate() {
  const t = clock.getElapsedTime();
  uniforms.u_time.value = t;
  updateCameraPath(t);

  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}

animate();
