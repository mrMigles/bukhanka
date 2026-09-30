const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const output = process.argv[2] || path.join(__dirname, 'builds', 'Web');
const source = path.join(__dirname, 'web');

async function main() {
  const payloads = await Promise.all(['index.js', 'index.wasm', 'index.pck'].map(name => fs.readFile(path.join(output, name))));
  const hash = crypto.createHash('sha256');
  payloads.forEach(data => hash.update(data));
  const version = hash.digest('hex').slice(0, 12);
  const stem = `game-${version}`;
  const htmlPath = path.join(output, 'index.html');
  let html = await fs.readFile(htmlPath, 'utf8');
  for (const suffix of ['js', 'wasm', 'pck']) html = html.replaceAll(`index.${suffix}`, `${stem}.${suffix}`);
  html = html.replace('"executable":"index"', `"executable":"${stem}"`);
  html = html.replace('initial-scale=1.0', 'initial-scale=1.0, viewport-fit=cover');
  // Own canvas sizing instead of allocating full DPR=3/4 phone framebuffers.
  html = html.replace('"canvasResizePolicy":2', '"canvasResizePolicy":0');
  html = html.replace('const engine = new Engine(GODOT_CONFIG);', `const engine = new Engine(GODOT_CONFIG);
const gameCanvas = document.getElementById('canvas');
function resizeGameCanvas() {
  const ratio = Math.min(window.devicePixelRatio || 1, 1.5);
  gameCanvas.width = Math.round(innerWidth * ratio);
  gameCanvas.height = Math.round(innerHeight * ratio);
  gameCanvas.style.width = innerWidth + 'px';
  gameCanvas.style.height = innerHeight + 'px';
}
resizeGameCanvas();
window.addEventListener('resize', resizeGameCanvas);`);
  html = html.replace('</head>', '<style>:root{--safe-left:env(safe-area-inset-left,0px);--safe-top:env(safe-area-inset-top,0px);--safe-right:env(safe-area-inset-right,0px);--safe-bottom:env(safe-area-inset-bottom,0px)}</style>\n</head>');
  if (!html.includes(`"executable":"${stem}"`) || !html.includes(`${stem}.js`)) throw new Error('Godot HTML layout changed');
  html = html.replace('</head>', `  <link rel="manifest" href="index.manifest.json">\n  <script defer src="pwa-update-${version}.js"></script>\n</head>`);
  await fs.writeFile(htmlPath, html);

  for (const suffix of ['js', 'wasm', 'pck', 'audio.worklet.js', 'audio.position.worklet.js']) {
    await fs.rename(path.join(output, `index.${suffix}`), path.join(output, `${stem}.${suffix}`));
  }
  for (const size of [192, 512]) {
    await fs.copyFile(path.join(source, `icon-${size}.png`), path.join(output, `icon-${size}.png`));
  }
  const manifest = {
    id: './', name: 'Буханка • Выше облаков', short_name: 'Буханка',
    start_url: './?source=pwa', scope: './', display: 'standalone',
    background_color: '#173c3b', theme_color: '#173c3b',
    icons: [192, 512].map(size => ({ src: `icon-${size}.png`, sizes: `${size}x${size}`, type: 'image/png' })),
  };
  await fs.writeFile(path.join(output, 'index.manifest.json'), JSON.stringify(manifest));
  await fs.writeFile(path.join(output, 'version.json'), JSON.stringify({ version, builtAt: new Date().toISOString() }));
  for (const [template, target] of [
    ['pwa-update.js', `pwa-update-${version}.js`],
    ['service-worker.js', 'index.service.worker.js'],
  ]) {
    const text = (await fs.readFile(path.join(source, template), 'utf8')).replaceAll('__BUILD_VERSION__', version);
    await fs.writeFile(path.join(output, target), text);
  }
  for (const name of await fs.readdir(output)) {
    if (/^game-[0-9a-f]{12}\./.test(name) && !name.startsWith(`${stem}.`) ||
        /^pwa-update-[0-9a-f]{12}\.js$/.test(name) && name !== `pwa-update-${version}.js` ||
        /^index\.(?:js|wasm|pck)(?:\.br|\.gz)?$/.test(name)) {
      await fs.unlink(path.join(output, name));
    }
  }
  console.log(`Web version: ${version}`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
