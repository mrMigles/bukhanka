const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.env.WEB_ROOT || path.join(__dirname, 'builds/Web'));
const mime = {'.html':'text/html; charset=utf-8','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml','.json':'application/json'};
const port = Number(process.env.PORT || 8065);
const server = http.createServer((req,res)=>{
  let pathname;
  try { pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname); } catch {res.writeHead(400).end();return;}
  const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if(!file.startsWith(root + path.sep)){res.writeHead(403).end();return;}
  fs.stat(file,(err,stat)=>{
    if(err || !stat.isFile()){res.writeHead(404).end('Not found');return;}
    const accepts = req.headers['accept-encoding'] || '';
    const preferred = accepts.includes('br') ? ['br', 'gzip'] : accepts.includes('gzip') ? ['gzip'] : [];
    function send(index) {
      const encoding = preferred[index];
      const selected = encoding === 'br' ? file + '.br' : encoding === 'gzip' ? file + '.gz' : file;
      fs.stat(selected, (compressedError, selectedStat) => {
        if (encoding && (compressedError || !selectedStat.isFile() || selectedStat.mtimeMs < stat.mtimeMs)) {
          send(index + 1);
          return;
        }
        const etag = `W/"${stat.size}-${Math.trunc(stat.mtimeMs)}-${encoding || 'identity'}"`;
        const immutable = /^(game-[0-9a-f]{12}\.|pwa-update-[0-9a-f]{12}\.js$)/.test(path.basename(file));
        const headers = {
          'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
          'Content-Length': selectedStat.size,
          'Cache-Control': immutable ? 'public, max-age=31536000, immutable' : 'no-store',
          'ETag': etag,
          'Vary': 'Accept-Encoding',
          'Cross-Origin-Opener-Policy': 'same-origin',
          'Cross-Origin-Embedder-Policy': 'require-corp',
        };
        if (encoding) headers['Content-Encoding'] = encoding;
        if (req.headers['if-none-match'] === etag) {
          delete headers['Content-Length'];
          res.writeHead(304, headers).end();
          return;
        }
        res.writeHead(200, headers);
        fs.createReadStream(selected).pipe(res);
      });
    }
    send(0);
  });
}).listen(port,'127.0.0.1',()=>console.log(`Bukhanka: http://127.0.0.1:${port}`));
module.exports = server;
