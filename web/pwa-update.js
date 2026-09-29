(() => {
  const version = '__BUILD_VERSION__';
  window.BUKHANKA_BUILD = version;
  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;

  let checking = false;
  function offerUpdate(nextVersion) {
    if (document.getElementById('bukhanka-update')) return;
    const banner = document.createElement('div');
    banner.id = 'bukhanka-update';
    banner.setAttribute('role', 'status');
    banner.style.cssText = 'position:fixed;z-index:10000;left:12px;right:12px;bottom:calc(12px + env(safe-area-inset-bottom));max-width:480px;margin:auto;padding:12px 16px;border-radius:14px;background:#173c3b;color:#fff;font:16px system-ui;box-shadow:0 4px 24px #0008;display:flex;align-items:center;gap:12px';
    const label = document.createElement('span');
    label.textContent = 'Доступна новая версия игры';
    label.style.flex = '1';
    const button = document.createElement('button');
    button.textContent = 'Обновить';
    button.style.cssText = 'border:0;border-radius:10px;padding:10px 14px;background:#e7d8ad;color:#173c3b;font:600 15px system-ui';
    button.addEventListener('click', () => {
      if (typeof window.bukhankaSave === 'function') window.bukhankaSave();
      const url = new URL(location.href);
      url.searchParams.set('v', nextVersion);
      location.replace(url.href);
    });
    banner.append(label, button);
    document.body.appendChild(banner);
  }

  async function checkUpdate() {
    if (checking) return;
    checking = true;
    try {
      const response = await fetch('version.json', { cache: 'no-store' });
      if (!response.ok) return;
      const remote = await response.json();
      if (remote.version && remote.version !== version) offerUpdate(remote.version);
      const registration = await navigator.serviceWorker.getRegistration();
      if (registration) await registration.update();
    } catch (error) {
      console.debug('Update check unavailable:', error);
    } finally {
      checking = false;
    }
  }
  window.bukhankaCheckUpdate = checkUpdate;

  async function register() {
    const hadController = Boolean(navigator.serviceWorker.controller);
    if (hadController) {
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        if (typeof window.bukhankaSave === 'function') window.bukhankaSave();
        location.reload();
      }, { once: true });
    }
    try {
      await navigator.serviceWorker.register(`index.service.worker.js?v=${version}`, {
        scope: './', updateViaCache: 'none',
      });
      const active = await navigator.serviceWorker.ready;
      active.active?.postMessage('PRIME');
      await checkUpdate();
    } catch (error) {
      console.warn('PWA registration failed:', error);
    }
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) checkUpdate();
    });
    setInterval(() => { if (!document.hidden) checkUpdate(); }, 300000);
  }

  // Let the game finish its first load before the worker warms its offline cache.
  const status = document.getElementById('status');
  if (!status) { register(); return; }
  const observer = new MutationObserver(() => {
    if (!status.isConnected) { observer.disconnect(); register(); }
  });
  observer.observe(document.body, { childList: true });
})();
