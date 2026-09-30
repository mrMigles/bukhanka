// Verify the actual nginx delivery path, including the proxy's Via header.
const assert = require('node:assert/strict');
async function main() {
  const base = process.argv[2] || 'http://127.0.0.1:8091';
  const {version} = await (await fetch(base+'/version.json')).json();
  for(const extension of ['wasm','pck','js']) {
    const url = `${base}/game-${version}.${extension}`;
    const headers = {'Accept-Encoding':'gzip','Via':'1.1 Caddy'};
    const response = await fetch(url,{method:'HEAD',headers});
    assert.equal(response.status,200);
    assert.equal(response.headers.get('content-encoding'),'gzip','Proxy disables compression: '+extension);
    assert.match(response.headers.get('vary'),/Accept-Encoding/i);
    assert.match(response.headers.get('cache-control'),/immutable/);
    const plain = await fetch(url,{method:'HEAD',headers:{'Accept-Encoding':'identity','Via':'1.1 Caddy'}});
    const wire = Number(response.headers.get('content-length'));
    const raw = Number(plain.headers.get('content-length'));
    assert(wire<raw,'Compression does not reduce '+extension);
    if(extension==='wasm') {
      assert(wire<raw*.4,'WASM exceeds the mobile transfer budget');
      const payload = Buffer.from(await (await fetch(url,{headers})).arrayBuffer());
      assert.equal(payload.length,raw);
      assert.equal(payload.subarray(0,8).toString('hex'),'0061736d01000000');
    }
    console.log(JSON.stringify({extension,wire,raw,proxyCompression:'gzip'}));
  }
  const html = await (await fetch(base+'/')).text();
  assert(html.includes('Пожалуйста, подождите'));
  assert(!html.includes('status-splash'));
  for(const name of [`loading-${version}.js`,`poster-${version}.webp`]) {
    const response=await fetch(`${base}/${name}`,{method:'HEAD'});
    assert.equal(response.status,200);
    assert.match(response.headers.get('cache-control'),/immutable/);
  }
  console.log('PASS proxy delivery and loading shell');
}
main().catch(error => {console.error(error);process.exitCode=1;});
