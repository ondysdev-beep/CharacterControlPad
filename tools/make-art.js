// Generates the addon's textures (original artwork, drawn with signed distance functions):
//   CharacterControlPad/Media/Controller.tga  512x256  schematic gamepad for the settings window
//   CharacterControlPad/Media/Glyphs.tga      512x64   8 round button badges: cross, circle, square, triangle, up, down, left, right
//   CharacterControlPad/Media/Glow.tga        64x64    soft ring used to highlight a button on the controller
// Usage: node tools/make-art.js [previewDir]   (previewDir: also writes PNG previews there)
// The marker coordinates used by ConfigWindow.lua (LAYOUT) refer to the 512x256 controller canvas.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'CharacterControlPad', 'Media');
const SS = 4; // supersampling per axis

// ---------------------------------------------------------------- canvas
function Canvas(w, h) {
  return { w, h, px: new Float32Array(w * h * 4) }; // premultiplied-free RGBA 0..1
}

function hex(c, a = 1) {
  const n = parseInt(c.slice(1), 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, a];
}

// coverage of a shape given by sdf(x, y) (negative inside), supersampled
function coverage(sdf, x, y) {
  let inside = 0;
  for (let sy = 0; sy < SS; sy++) {
    for (let sx = 0; sx < SS; sx++) {
      if (sdf(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS) <= 0) inside++;
    }
  }
  return inside / (SS * SS);
}

// source-over blend; color may be a function (x, y) -> rgba
function fill(cv, sdf, color, bbox) {
  const [x0, y0, x1, y1] = bbox || [0, 0, cv.w, cv.h];
  for (let y = Math.max(0, Math.floor(y0)); y < Math.min(cv.h, Math.ceil(y1)); y++) {
    for (let x = Math.max(0, Math.floor(x0)); x < Math.min(cv.w, Math.ceil(x1)); x++) {
      const cov = coverage(sdf, x, y);
      if (cov <= 0) continue;
      const c = typeof color === 'function' ? color(x + 0.5, y + 0.5) : color;
      const a = c[3] * cov;
      const i = (y * cv.w + x) * 4;
      const da = cv.px[i + 3];
      const oa = a + da * (1 - a);
      for (let k = 0; k < 3; k++) {
        cv.px[i + k] = oa > 0 ? (c[k] * a + cv.px[i + k] * da * (1 - a)) / oa : 0;
      }
      cv.px[i + 3] = oa;
    }
  }
}

// outline = band |d| <= w/2 around the shape edge
const stroke = (sdf, w) => (x, y) => Math.abs(sdf(x, y)) - w / 2;
// shrink / grow
const inset = (sdf, d) => (x, y) => sdf(x, y) + d;

// ---------------------------------------------------------------- shapes
const circle = (cx, cy, r) => (x, y) => Math.hypot(x - cx, y - cy) - r;
function roundRect(cx, cy, hw, hh, r) {
  return (x, y) => {
    const qx = Math.abs(x - cx) - hw + r;
    const qy = Math.abs(y - cy) - hh + r;
    return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
  };
}
function capsule(ax, ay, bx, by, r) {
  return (x, y) => {
    const pax = x - ax, pay = y - ay, bax = bx - ax, bay = by - ay;
    const h = Math.max(0, Math.min(1, (pax * bax + pay * bay) / (bax * bax + bay * bay)));
    return Math.hypot(pax - bax * h, pay - bay * h) - r;
  };
}
function segment(ax, ay, bx, by, w) {
  return capsule(ax, ay, bx, by, w / 2);
}
// smooth union
function smin(k, ...sdfs) {
  return (x, y) => {
    let d = sdfs[0](x, y);
    for (let i = 1; i < sdfs.length; i++) {
      const b = sdfs[i](x, y);
      const h = Math.max(0, Math.min(1, 0.5 + 0.5 * (b - d) / k));
      d = b * (1 - h) + d * h - k * h * (1 - h);
    }
    return d;
  };
}
const union = (...sdfs) => (x, y) => Math.min(...sdfs.map(f => f(x, y)));
// triangle (equilateral-ish) given 3 points, exact sdf
function triangle(p0, p1, p2) {
  return (x, y) => {
    const e = [[p1[0] - p0[0], p1[1] - p0[1]], [p2[0] - p1[0], p2[1] - p1[1]], [p0[0] - p2[0], p0[1] - p2[1]]];
    const v = [[x - p0[0], y - p0[1]], [x - p1[0], y - p1[1]], [x - p2[0], y - p2[1]]];
    let d = Infinity, s = Infinity;
    for (let i = 0; i < 3; i++) {
      const h = Math.max(0, Math.min(1, (v[i][0] * e[i][0] + v[i][1] * e[i][1]) / (e[i][0] ** 2 + e[i][1] ** 2)));
      const px = v[i][0] - e[i][0] * h, py = v[i][1] - e[i][1] * h;
      d = Math.min(d, px * px + py * py);
      const sgn = e[i][0] * v[i][1] - e[i][1] * v[i][0];
      s = Math.min(s, sgn * Math.sign(e[0][0] * e[2][1] - e[0][1] * e[2][0]) * -1);
    }
    return Math.sqrt(d) * (s > 0 ? 1 : -1) * -1;
  };
}

function bounds(cx, cy, r) {
  return [cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2];
}

// ---------------------------------------------------------------- symbols
const COLORS = {
  cross: '#7fa8e8', circle: '#ec6f78', square: '#df8fcc', triangle: '#4fc7a4', arrow: '#d6dae2',
};

// draws a face-button / arrow symbol of size s (radius of the symbol area) at cx, cy
function symbol(cv, kind, cx, cy, s, w) {
  const b = bounds(cx, cy, s + w);
  if (kind === 'cross') {
    const k = s * 0.62;
    fill(cv, union(segment(cx - k, cy - k, cx + k, cy + k, w), segment(cx - k, cy + k, cx + k, cy - k, w)), hex(COLORS.cross), b);
  } else if (kind === 'circle') {
    fill(cv, stroke(circle(cx, cy, s * 0.62), w), hex(COLORS.circle), b);
  } else if (kind === 'square') {
    const k = s * 0.55;
    fill(cv, stroke(roundRect(cx, cy, k, k, w * 0.25), w), hex(COLORS.square), b);
  } else if (kind === 'triangle') {
    const k = s * 0.72;
    const p = [[cx, cy - k], [cx + k * 0.866, cy + k * 0.5], [cx - k * 0.866, cy + k * 0.5]];
    fill(cv, stroke(triangle(...p), w), hex(COLORS.triangle), b);
  } else {
    const k = s * 0.6;
    const dirs = {
      up: [[cx, cy - k], [cx + k, cy + k * 0.55], [cx - k, cy + k * 0.55]],
      down: [[cx, cy + k], [cx - k, cy - k * 0.55], [cx + k, cy - k * 0.55]],
      left: [[cx - k, cy], [cx + k * 0.55, cy - k], [cx + k * 0.55, cy + k]],
      right: [[cx + k, cy], [cx - k * 0.55, cy + k], [cx - k * 0.55, cy - k]],
    };
    fill(cv, triangle(...dirs[kind]), hex(COLORS.arrow), b);
  }
}

// ---------------------------------------------------------------- controller
function controller() {
  const cv = Canvas(512, 256);
  const L = 165, R = 347;
  // triggers (L2 / R2) and bumpers (L1 / R1) behind the body
  for (const x of [L, R]) {
    fill(cv, roundRect(x, 21, 42, 11, 9), hex('#3a404a'));
    fill(cv, stroke(roundRect(x, 21, 42, 11, 9), 1.5), hex('#5f6775'));
    fill(cv, roundRect(x, 38, 48, 9, 8), hex('#464d58'));
    fill(cv, stroke(roundRect(x, 38, 48, 9, 8), 1.5), hex('#6a7381'));
  }
  // body: rounded centre + two grips, smoothly joined
  const body = smin(28,
    roundRect(256, 105, 152, 62, 46),
    capsule(160, 128, 120, 200, 44),
    capsule(352, 128, 392, 200, 44));
  const gradient = (x, y) => {
    const t = Math.max(0, Math.min(1, (y - 40) / 210));
    const top = hex('#353a44'), bottom = hex('#1b1e23');
    return [0, 1, 2].map(k => top[k] * (1 - t) + bottom[k] * t).concat(1);
  };
  fill(cv, body, gradient);
  fill(cv, stroke(inset(body, 1.5), 3), hex('#6b7382'));
  // soft top highlight
  fill(cv, (x, y) => Math.max(body(x, y) + 4, y - 70), hex('#ffffff', 0.04));

  // touchpad
  fill(cv, roundRect(256, 80, 58, 33, 10), hex('#2a2f37'));
  fill(cv, stroke(roundRect(256, 80, 58, 33, 10), 1.5), hex('#596170'));
  // create / options
  fill(cv, roundRect(190, 60, 4, 9, 4), hex('#596170'));
  fill(cv, roundRect(322, 60, 4, 9, 4), hex('#596170'));
  // PS button and mute
  fill(cv, circle(256, 140, 8), hex('#4d5462'));
  fill(cv, roundRect(256, 160, 10, 3, 3), hex('#4d5462'));

  // D-pad well + cross
  fill(cv, circle(150, 100, 38), hex('#000000', 0.18));
  const dpad = union(roundRect(150, 100, 11, 30, 4), roundRect(150, 100, 30, 11, 4));
  fill(cv, dpad, hex('#3d434e'));
  fill(cv, stroke(dpad, 1.5), hex('#646c7a'));
  symbol(cv, 'up', 150, 82, 7, 0);
  symbol(cv, 'down', 150, 118, 7, 0);
  symbol(cv, 'left', 132, 100, 7, 0);
  symbol(cv, 'right', 168, 100, 7, 0);

  // face buttons
  fill(cv, circle(362, 100, 40), hex('#000000', 0.18));
  const face = [['triangle', 362, 74], ['circle', 388, 100], ['square', 336, 100], ['cross', 362, 126]];
  for (const [kind, x, y] of face) {
    fill(cv, circle(x, y, 13), hex('#2b3038'));
    fill(cv, stroke(circle(x, y, 13), 1.5), hex('#646c7a'));
    symbol(cv, kind, x, y, 9, 2.2);
  }

  // sticks
  for (const x of [205, 307]) {
    fill(cv, circle(x, 150, 25), hex('#15171b'));
    fill(cv, circle(x, 150, 18), hex('#363b45'));
    fill(cv, stroke(circle(x, 150, 18), 1.5), hex('#6b7382'));
    fill(cv, stroke(circle(x, 150, 10), 1), hex('#2a2e35'));
  }
  return cv;
}

// ---------------------------------------------------------------- glyph badges
function glyphs() {
  const cv = Canvas(512, 64);
  const kinds = ['cross', 'circle', 'square', 'triangle', 'up', 'down', 'left', 'right'];
  kinds.forEach((kind, i) => {
    const cx = i * 64 + 32, cy = 32;
    fill(cv, circle(cx, cy, 28), hex('#23272e'), bounds(cx, cy, 30));
    fill(cv, stroke(circle(cx, cy, 27), 2.5), hex('#6b7382'), bounds(cx, cy, 30));
    symbol(cv, kind, cx, cy, 18, 5);
  });
  return cv;
}

function glow() {
  const cv = Canvas(64, 64);
  for (let y = 0; y < 64; y++) {
    for (let x = 0; x < 64; x++) {
      const d = Math.hypot(x + 0.5 - 32, y + 0.5 - 32);
      const ring = Math.exp(-(((d - 22) / 5) ** 2));
      const inner = d < 22 ? 0.18 : 0;
      const a = Math.min(1, ring + inner) * (d < 31 ? 1 : 0);
      const i = (y * 64 + x) * 4;
      cv.px.set([1, 1, 1, a], i);
    }
  }
  return cv;
}

// ---------------------------------------------------------------- writers
function toBytes(cv) {
  const out = Buffer.alloc(cv.w * cv.h * 4);
  for (let i = 0; i < cv.w * cv.h * 4; i++) out[i] = Math.round(Math.max(0, Math.min(1, cv.px[i])) * 255);
  return out; // RGBA, top row first
}

// 32-bit uncompressed TGA, bottom-left origin, 8 alpha bits
function writeTGA(file, cv) {
  const rgba = toBytes(cv);
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(cv.w, 12);
  header.writeUInt16LE(cv.h, 14);
  header[16] = 32;
  header[17] = 8;
  const body = Buffer.alloc(cv.w * cv.h * 4);
  for (let y = 0; y < cv.h; y++) {
    const src = (cv.h - 1 - y) * cv.w * 4;
    for (let x = 0; x < cv.w; x++) {
      const s = src + x * 4, d = (y * cv.w + x) * 4;
      body[d] = rgba[s + 2]; body[d + 1] = rgba[s + 1]; body[d + 2] = rgba[s]; body[d + 3] = rgba[s + 3];
    }
  }
  fs.writeFileSync(file, Buffer.concat([header, body]));
}

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}

// PNG preview composited on a background colour (only for looking at the art)
function writePNG(file, cv, bg = [0.09, 0.09, 0.1]) {
  const rgba = toBytes(cv);
  const raw = Buffer.alloc((cv.w * 3 + 1) * cv.h);
  for (let y = 0; y < cv.h; y++) {
    raw[y * (cv.w * 3 + 1)] = 0;
    for (let x = 0; x < cv.w; x++) {
      const s = (y * cv.w + x) * 4, a = rgba[s + 3] / 255;
      for (let k = 0; k < 3; k++) raw[y * (cv.w * 3 + 1) + 1 + x * 3 + k] = Math.round(rgba[s + k] * a + bg[k] * 255 * (1 - a));
    }
  }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(cv.w, 0); ihdr.writeUInt32BE(cv.h, 4); ihdr[8] = 8; ihdr[9] = 2;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0)),
  ]));
}

fs.mkdirSync(OUT, { recursive: true });
const art = { Controller: controller(), Glyphs: glyphs(), Glow: glow() };
for (const [name, cv] of Object.entries(art)) {
  writeTGA(path.join(OUT, name + '.tga'), cv);
  console.log('wrote Media/' + name + '.tga', cv.w + 'x' + cv.h);
}
const preview = process.argv[2];
if (preview) {
  fs.mkdirSync(preview, { recursive: true });
  for (const [name, cv] of Object.entries(art)) writePNG(path.join(preview, name + '.png'), cv);
  console.log('previews in', preview);
}
