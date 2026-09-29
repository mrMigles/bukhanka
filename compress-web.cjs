const fs = require('node:fs/promises');
const path = require('node:path');
const zlib = require('node:zlib');
const { promisify } = require('node:util');

const brotli = promisify(zlib.brotliCompress);
const gzip = promisify(zlib.gzip);
const directory = process.argv[2] || path.join(__dirname, 'builds', 'Web');

async function main() {
  const { version } = JSON.parse(await fs.readFile(path.join(directory, 'version.json'), 'utf8'));
  for (const name of [`game-${version}.wasm`, `game-${version}.pck`, `game-${version}.js`]) {
    const source = await fs.readFile(path.join(directory, name));
    const [br, gz] = await Promise.all([
      brotli(source, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 7 } }),
      gzip(source, { level: 6 }),
    ]);
    await Promise.all([
      fs.writeFile(path.join(directory, name + '.br'), br),
      fs.writeFile(path.join(directory, name + '.gz'), gz),
    ]);
    console.log(`${name}: ${(source.length / 1048576).toFixed(1)} MiB -> ${(br.length / 1048576).toFixed(1)} MiB Brotli`);
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
