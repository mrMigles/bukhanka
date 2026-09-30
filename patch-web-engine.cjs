// Godot 4.7.2's generated loader drops stream and initialization rejections.
// Fail packaging if the upstream anchors change instead of silently losing fixes.
module.exports = function patchEngine(source) {
  function once(before, after) {
    if(source.split(before).length!==2) throw new Error('Godot loader anchor changed: '+before.slice(0,75));
    source=source.replace(before,after);
  }
  once('return fetch(file).then(function (response) {', 'return (window.bukhankaFetchAsset ? window.bukhankaFetchAsset(file) : fetch(file)).then(function (response) {');
  once('const DOWNLOAD_ATTEMPTS_MAX = 4;', 'const DOWNLOAD_ATTEMPTS_MAX = 1;');
  once('onloadprogress(reader, controller).then(function () {\n\t\t\t\t\tcontroller.close();\n\t\t\t\t});', 'onloadprogress(reader, controller).then(function () {\n\t\t\t\t\tcontroller.close();\n\t\t\t\t}).catch(function (error) { load_status.done = true; controller.error(error); });');
  const init = /function doInit\(promise\) \{[\s\S]*?\n\t\t\t\tpreloader\.setProgressFunc/;
  if(!init.test(source)) throw new Error('Godot initialization anchor changed');
  source=source.replace(init,`function doInit(promise) {
    return new Promise(function (resolve, reject) {
      promise.then(function (response) {
        // Consume the original stream: cloning it retains another entire WASM on phones.
        const wasm = new Response(response.body, {headers: {'content-type':'application/wasm'}});
        const options = me.config.getModuleConfig(loadPath, wasm);
        options['instantiateWasm'] = function (imports, onSuccess) {
          const compilation = typeof WebAssembly.instantiateStreaming === 'function'
            ? WebAssembly.instantiateStreaming(Promise.resolve(wasm), imports)
            : wasm.arrayBuffer().then(function (buffer) { return WebAssembly.instantiate(buffer, imports); });
          compilation.then(function (result) { onSuccess(result.instance, result.module); }).catch(reject);
          return {};
        };
        Godot(options).then(function (module) {
          module['initFS'](me.config.persistentPaths).then(function () {
            me.rtenv = module;
            if(me.config.unloadAfterInit) Engine.unload();
            resolve();
          }).catch(reject);
        }).catch(reject);
      }).catch(reject);
    });
  }
                preloader.setProgressFunc`);
  return source;
};
