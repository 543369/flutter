const menu = document.querySelector('.menu-toggle');
const nav = document.getElementById('main-nav');
if (menu && nav) {
  const closeMenu = () => { nav.classList.remove('is-open'); menu.setAttribute('aria-expanded', 'false'); menu.setAttribute('aria-label', '展开导航'); };
  menu.addEventListener('click', () => {
    const open = menu.getAttribute('aria-expanded') !== 'true';
    menu.setAttribute('aria-expanded', String(open));
    menu.setAttribute('aria-label', open ? '收起导航' : '展开导航');
    nav.classList.toggle('is-open', open);
  });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') { closeMenu(); menu.focus(); } });
  nav.addEventListener('click', event => { if (event.target.closest('a')) closeMenu(); });
}
(async () => {
  const button = document.getElementById('android-download');
  if (!button) return;
  const status = document.getElementById('release-status');
  try {
    const response = await fetch('releases.json');
    if (!response.ok) throw new Error('Release metadata unavailable');
    const { android: release } = await response.json();
    if (!release || !release.url || !release.version) return;
    const url = new URL(release.url, location.href);
    if (url.protocol !== 'https:' && !(url.origin === location.origin && url.protocol === 'http:')) throw new Error('Invalid download URL');
    button.href = url.href;
    button.removeAttribute('aria-disabled');
    button.textContent = '下载 Android APK ↓';
    button.style.background = 'var(--green)';
    button.style.color = '#fff';
    document.getElementById('android-meta').textContent = [`版本 ${release.version}`, release.date, release.size, release.requirements, release.sha256 ? `SHA-256: ${release.sha256}` : null].filter(Boolean).join(' · ');
    status.textContent = '安装前请核对系统要求、版本信息与文件校验值。';
    document.querySelector('.page-intro > p:last-child').textContent = '下载 Android APK，开启你们的陪伴日常。';
  } catch {
    status.textContent = '暂时无法读取下载信息，请稍后刷新页面。';
  }
})();
