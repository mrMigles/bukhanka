(() => {
  'use strict';
  const config = window.BUKHANKA_CONFIG;
  const query = new URLSearchParams(location.search);
  const testing = query.has('e2e') ? window.BUKHANKA_BOOT_TIMEOUTS || {} : {};
  const idleMs = testing.idleMs || 30000;
  const startupMs = testing.startupMs || 150000;
  const maxRetries = testing.maxRetries ?? 2;
  const retryCount = Math.min(2, Math.max(0, Number(query.get('boot_retry')) || 0));
  const overlay = document.getElementById('status');
  const title = document.getElementById('status-title');
  const description = document.getElementById('status-description');
  const stage = document.getElementById('status-stage');
  const progress = document.getElementById('status-progress');
  const elapsed = document.getElementById('status-elapsed');
  const startedAt = performance.now();
  let failed = false;
  let ready = false;
  let reloadTimer;
  let transportFailed = false;
  const state = window.bukhankaBootState = {phase:'script', loaded:0, total:0, retry:retryCount, error:''};
  const active = new Set();
  const clock = setInterval(() => {elapsed.textContent = Math.floor((performance.now()-startedAt)/1000) + ' с';}, 1000);
  const watchdog = setTimeout(() => fail(new Error('Игра не завершила запуск за отведённое время.'), false), startupMs);

  function reload(safe = false, auto = false) {
    const url = new URL(location.href);
    url.searchParams.set('boot_retry', auto ? retryCount + 1 : 0);
    url.searchParams.set('reload', Date.now());
    if(safe) url.searchParams.set('safe_mode','1');
    location.replace(url.href);
  }
  document.getElementById('retry').onclick = () => reload();
  document.getElementById('safe-start').onclick = () => reload(true);

  function fail(error, retryable = false) {
    if(failed || ready) return;
    failed = true;
    clearTimeout(watchdog);
    clearInterval(clock);
    for(const controller of active) controller.abort();
    state.phase = 'error';
    state.error = String(error?.message || error);
    overlay.classList.add('failed');
    title.textContent = navigator.onLine ? 'Загрузка прервалась' : 'Нет подключения к сети';
    description.textContent = 'Игра не запустилась. Попробуйте ещё раз; ваше сохранение останется на месте.';
    stage.textContent = 'Можно повторить загрузку';
    progress.removeAttribute('value');
    document.getElementById('status-actions').hidden = false;
    document.getElementById('status-details').hidden = false;
    document.getElementById('status-error').textContent = config.executable + '\n' + state.error;
    if(retryable && navigator.onLine && retryCount < maxRetries) {
      description.textContent = 'Соединение с сервером оборвалось. Повторяем загрузку; сохранение останется на месте.';
      stage.textContent = `Повторная попытка ${retryCount+1} из ${maxRetries}…`;
      reloadTimer = setTimeout(() => reload(false,true), testing.retryDelayMs || 2000);
    }
  }

  function finish() {
    if(failed || ready) return;
    ready = true;
    state.phase = 'ready';
    clearTimeout(watchdog);
    clearTimeout(reloadTimer);
    clearInterval(clock);
    // Let the first actual game frame render before removing the poster.
    requestAnimationFrame(() => requestAnimationFrame(() => overlay.remove()));
    const url = new URL(location.href);
    if(url.searchParams.has('boot_retry') || url.searchParams.has('reload')) {
      url.searchParams.delete('boot_retry'); url.searchParams.delete('reload');
      history.replaceState(null,'',url);
    }
  }
  window.addEventListener('bukhanka-ready',finish,{once:true});
  window.addEventListener('unhandledrejection',event => {if(!ready) fail(event.reason, event.reason instanceof TypeError);});
  window.addEventListener('error',event => {if(!ready && event.error) fail(event.error);});

  // Godot's fetch must have an inactivity timeout, including mid-response stalls.
  window.bukhankaFetchAsset = async file => {
    const controller = new AbortController();
    active.add(controller);
    let timer;
    const reset = () => {clearTimeout(timer); timer = setTimeout(() => controller.abort(new DOMException('Сервер перестал передавать данные.','TimeoutError')),idleMs);};
    reset();
    try {
      const response = await fetch(file,{signal:controller.signal,cache:retryCount ? 'reload' : 'default'});
      if(!response.ok) {
        const error = new Error(`Не удалось скачать файл (${response.status}): ${file}`);
        error.retryable = response.status>=500 || [404,408,429].includes(response.status);
        throw error;
      }
      const reader = response.body.getReader();
      return new Response(new ReadableStream({
        async pull(stream) {
          try {
            const result = await reader.read();
            if(result.done) {clearTimeout(timer);active.delete(controller);stream.close();}
            else {reset();stream.enqueue(result.value);}
          } catch(error) {
            transportFailed = true;
            clearTimeout(timer);active.delete(controller);stream.error(controller.signal.reason || error);
          }
        },
        cancel(reason) {clearTimeout(timer);active.delete(controller);controller.abort();return reader.cancel(reason);},
      }),{status:response.status,headers:response.headers});
    } catch(error) {
      transportFailed = true;
      clearTimeout(timer);active.delete(controller);
      throw controller.signal.reason || error;
    }
  };

  const canvas = document.getElementById('canvas');
  function resize() {
    const ratio = Math.min(window.devicePixelRatio || 1,1.5);
    canvas.width = Math.round(innerWidth*ratio);canvas.height = Math.round(innerHeight*ratio);
    canvas.style.width = innerWidth+'px';canvas.style.height = innerHeight+'px';
  }
  resize();window.addEventListener('resize',resize);
  canvas.addEventListener('webglcontextlost',() => {if(!ready) fail(new Error('Браузер потерял графический контекст. Попробуйте лёгкий запуск.'));});

  const script = document.createElement('script');
  script.src = config.executable + '.js';
  const scriptTimer = setTimeout(() => fail(new Error('Не удалось подключить игру: сервер не отвечает.'),true),idleMs);
  script.onerror = () => {clearTimeout(scriptTimer);fail(new Error('Не удалось подключить игру. Проверьте соединение.'),true);};
  script.onload = () => {
    clearTimeout(scriptTimer);
    if(failed) return;
    const missing = Engine.getMissingFeatures({threads:false});
    if(missing.length) {fail(new Error('Браузер не поддерживает необходимые возможности: '+missing.join(', ')));return;}
    const engine = new Engine({...config,canvas,onProgress(loaded,total) {
      if(failed || ready) return;
      state.loaded = loaded;state.total = total;
      if(total>0 && loaded>=total) {
        state.phase = 'compile';title.textContent = 'Запускаем движок';
        description.textContent = 'Файлы скачаны. Пожалуйста, подождите: браузер подготавливает игру.';
        stage.textContent = 'Подготовка игры…';progress.removeAttribute('value');
      } else if(total>0) {
        state.phase = 'download';title.textContent = 'Скачиваем игру';
        description.textContent = 'Пожалуйста, подождите. Первый запуск требует загрузки движка и горных маршрутов.';
        const percent = Math.min(100,Math.floor(loaded/total*100));
        progress.value = percent;stage.textContent = `Файлы игры · ${percent}%`;
      }
    },onPrint() {
      if(failed || ready || state.phase==='download') return;
      state.phase = 'world';title.textContent = 'Готовим горный маршрут';
      description.textContent = 'Пожалуйста, подождите. Строим мир и подготавливаем графику для вашего устройства.';
      stage.textContent = 'Почти в пути…';progress.removeAttribute('value');
    },onExit(code) {if(!ready) fail(new Error('Игра завершила запуск с кодом '+code));}});
    engine.startGame().then(() => {if(window.bukhankaGameReady) finish();}).catch(error => fail(error,transportFailed||error?.retryable||error?.name==='TimeoutError'||error?.name==='AbortError'||error instanceof TypeError));
  };
  document.head.appendChild(script);
})();
