const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const patchEngine = require('./patch-web-engine.cjs');

const output = process.argv[2] || path.join(__dirname, 'builds', 'Web');
const source = path.join(__dirname, 'web');

async function main() {
  const enginePath = path.join(output,'index.js');
  await fs.writeFile(enginePath,patchEngine(await fs.readFile(enginePath,'utf8')));
  const payloads = await Promise.all(['index.js', 'index.wasm', 'index.pck'].map(name => fs.readFile(path.join(output, name))));
  const hash = crypto.createHash('sha256');
  payloads.forEach(data => hash.update(data));
  for(const name of ['loading.html','loading.css','loading.js','loading-poster.webp','service-worker.js','pwa-update.js']) hash.update(await fs.readFile(path.join(source,name)));
  const version = hash.digest('hex').slice(0, 12);
  const stem = `game-${version}`;
  const htmlPath = path.join(output, 'index.html');
  const exported = await fs.readFile(htmlPath,'utf8');
  const match = exported.match(/const GODOT_CONFIG = (\{[^\n]+\});/);
  if(!match) throw new Error('Godot HTML configuration changed');
  const config = JSON.parse(match[1]);
  config.executable = stem;
  config.canvasResizePolicy = 0;
  config.fileSizes = Object.fromEntries(Object.entries(config.fileSizes).map(([name,size]) => [name.replace('index.',stem+'.'),size]));
  const css = await fs.readFile(path.join(source,'loading.css'),'utf8');
  let html = (await fs.readFile(path.join(source,'loading.html'),'utf8')).replace('__LOADING_STYLE__',css).replace('__GODOT_CONFIG__',JSON.stringify(config)).replaceAll('__BUILD_VERSION__',version);
  await fs.writeFile(htmlPath, html);
  await fs.copyFile(path.join(source,'loading.js'),path.join(output,`loading-${version}.js`));
  await fs.copyFile(path.join(source,'loading-poster.webp'),path.join(output,`poster-${version}.webp`));

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
        /^(loading-[0-9a-f]{12}\.js|poster-[0-9a-f]{12}\.webp)$/.test(name) && !name.includes(version) ||
        /^index\.(?:js|wasm|pck)(?:\.br|\.gz)?$/.test(name)) {
      await fs.unlink(path.join(output, name));
    }
  }
  console.log(`Web version: ${version}`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
