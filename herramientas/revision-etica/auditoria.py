"""Revisión preliminar de accesibilidad (WCAG 2.2) del prototipo, pantalla por pantalla.
Pruebas automáticas propias; no reemplaza una revisión con lector de pantalla.
Uso: python3 auditoria.py <carpeta_salida>
"""
import json, os, sys
from playwright.sync_api import sync_playwright

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
BASE = "http://127.0.0.1:8765/index.html"
PANTALLAS = [
    ("tablero", "#/", "Tablero del turno"),
    ("camiones", "#/c", "Camiones"),
    ("ficha", "#/n/5980R63-2426-1348", "Ficha del neumático"),
    ("agendar", "#/a/5980R63-2426-1348", "Agendar intervención"),
    ("ordenes", "#/o", "Órdenes de trabajo"),
    ("editar", "#/e/ot-0068", "Modificar o anular orden"),
    ("simulador", "#/sim", "Simulador del pórtico"),
]

JS = r"""
() => {
  const vis = el => { const r = el.getBoundingClientRect(); const cs = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none' && parseFloat(cs.opacity) > 0.05; };
  const parse = c => { const m = c.match(/rgba?\(([^)]+)\)/); if (!m) return null;
    const p = m[1].split(/[ ,\/]+/).filter(Boolean).map(Number); return {r:p[0], g:p[1], b:p[2], a: p.length > 3 ? p[3] : 1}; };
  const over = (top, bot) => { const a = top.a + bot.a * (1 - top.a);
    if (a === 0) return {r:0,g:0,b:0,a:0};
    return {r:(top.r*top.a + bot.r*bot.a*(1-top.a))/a, g:(top.g*top.a + bot.g*bot.a*(1-top.a))/a, b:(top.b*top.a + bot.b*bot.a*(1-top.a))/a, a}; };
  const lum = c => { const f = v => { v/=255; return v <= 0.03928 ? v/12.92 : Math.pow((v+0.055)/1.055, 2.4); };
    return 0.2126*f(c.r) + 0.7152*f(c.g) + 0.0722*f(c.b); };
  const ratio = (a, b) => { const l1 = lum(a), l2 = lum(b); return (Math.max(l1,l2)+0.05)/(Math.min(l1,l2)+0.05); };
  const bgOf = el => { let layers = [], gradient = false, n = el;
    while (n && n.nodeType === 1) { const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') gradient = true;
      const c = parse(cs.backgroundColor); if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; }
      n = n.parentElement; }
    let bg = {r:255,g:255,b:255,a:1};
    for (let i = layers.length - 1; i >= 0; i--) bg = over(layers[i], bg);
    return {bg, gradient}; };
  const sel = el => { let s = el.tagName.toLowerCase(); if (el.id) s += '#' + el.id;
    const t = (el.innerText || el.textContent || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').trim().replace(/\s+/g,' ').slice(0, 60);
    return s + (t ? ' «' + t + '»' : ''); };

  const res = {contraste: [], contraste_revisar: [], click_sin_teclado: [], objetivos_pequenos: [], controles_sin_etiqueta: [],
               botones_sin_nombre: [], svg_sin_alternativa: [], img_sin_alt: [], encabezados: [], animaciones: [], toast: null, desborde_320: null};
  const vistos = new Set();
  // 1.4.3 Contraste mínimo
  document.querySelectorAll('#app *, header *').forEach(el => {
    if (!vis(el)) return;
    const own = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim().length > 0);
    if (!own) return;
    if (el.closest('button[disabled], [aria-disabled="true"]')) return;
    const cs = getComputedStyle(el);
    let op = 1, n = el; while (n && n.nodeType === 1) { op *= parseFloat(getComputedStyle(n).opacity); n = n.parentElement; }
    if (op < 0.6) return; // elemento inactivo o decorativo
    const fg0 = parse(cs.color); if (!fg0) return;
    const {bg, gradient} = bgOf(el);
    const fg = over(fg0, bg);
    const r = ratio(fg, bg);
    const size = parseFloat(cs.fontSize), bold = parseInt(cs.fontWeight) >= 700;
    const grande = size >= 24 || (bold && size >= 18.66);
    const minimo = grande ? 3 : 4.5;
    const texto = (el.innerText ?? el.textContent ?? '').trim().replace(/\s+/g,' ').slice(0, 50);
    const clave = texto + '|' + cs.color + '|' + Math.round(r*10);
    if (vistos.has(clave)) return; vistos.add(clave);
    const item = {texto, ratio: Math.round(r*100)/100, minimo, tamano: size, color: cs.color};
    if (gradient) res.contraste_revisar.push(item);
    else if (r < minimo) res.contraste.push(item);
  });
  // 2.1.1 Teclado: elementos con onclick que no reciben foco
  document.querySelectorAll('[onclick]').forEach(el => {
    if (!vis(el)) return;
    const tag = el.tagName;
    if (['A','BUTTON','INPUT','SELECT','TEXTAREA','SUMMARY'].includes(tag)) return;
    if (el.getAttribute('onclick').includes('stopPropagation')) return;
    if (el.hasAttribute('tabindex') && parseInt(el.getAttribute('tabindex')) >= 0) return;
    const alt = el.querySelector('button, a[href]');
    res.click_sin_teclado.push({elemento: sel(el), tag, tiene_boton_alternativo: !!alt});
  });
  // 2.5.8 Tamaño del objetivo (mínimo 24 × 24 px)
  document.querySelectorAll('button, a[href], input, select, textarea, [onclick]').forEach(el => {
    if (!vis(el)) return; const r = el.getBoundingClientRect();
    if (r.width < 24 || r.height < 24) res.objetivos_pequenos.push({elemento: sel(el), ancho: Math.round(r.width), alto: Math.round(r.height)});
  });
  // 1.3.1 / 4.1.2 / 3.3.2 Etiquetas de controles
  document.querySelectorAll('input, select, textarea').forEach(el => {
    if (!vis(el) || el.type === 'hidden') return;
    const id = el.id; const lab = (id && document.querySelector('label[for="'+id+'"]')) || el.closest('label');
    if (!lab && !el.getAttribute('aria-label') && !el.getAttribute('aria-labelledby'))
      res.controles_sin_etiqueta.push({elemento: sel(el), placeholder: el.getAttribute('placeholder') || ''});
  });
  // 4.1.2 Botones sin nombre accesible
  document.querySelectorAll('button, a[href]').forEach(el => {
    if (!vis(el)) return;
    const nombre = (el.innerText || '').trim() || el.getAttribute('aria-label') || el.getAttribute('title');
    if (!nombre) res.botones_sin_nombre.push({elemento: el.outerHTML.slice(0, 120)});
  });
  // 1.1.1 Contenido no textual
  document.querySelectorAll('#app svg').forEach(el => {
    if (!vis(el)) return; const r = el.getBoundingClientRect();
    if (r.width < 40 && r.height < 40) return; // íconos pequeños
    if (el.getAttribute('aria-hidden') === 'true') return;
    if (!el.getAttribute('aria-label') && !el.querySelector('title') && !el.getAttribute('aria-labelledby'))
      res.svg_sin_alternativa.push({ancho: Math.round(r.width), alto: Math.round(r.height), role: el.getAttribute('role') || ''});
  });
  document.querySelectorAll('img').forEach(el => { if (!el.hasAttribute('alt')) res.img_sin_alt.push(el.src); });
  // Estructura
  document.querySelectorAll('h1, h2, h3').forEach(h => { if (vis(h)) res.encabezados.push(h.tagName + ' ' + h.innerText.trim().replace(/\s+/g,' ').slice(0, 70)); });
  // 2.2.2 Pausar, detener, ocultar
  document.querySelectorAll('.animate-pulse, .animate-ping, .animate-laser, .animate-spin').forEach(el => {
    if (!vis(el)) return; const r = el.getBoundingClientRect();
    res.animaciones.push({clase: [...el.classList].filter(c => c.startsWith('animate')).join(' '), ancho: Math.round(r.width), alto: Math.round(r.height), texto: (el.innerText||'').trim().slice(0,50)});
  });
  const t = document.getElementById('toast');
  res.toast = t ? {role: t.getAttribute('role'), aria_live: t.getAttribute('aria-live')} : null;
  res.reduce_motion = [...document.styleSheets].some(s => { try { return [...s.cssRules].some(r => r.media && r.media.mediaText.includes('prefers-reduced-motion')); } catch(e) { return false; } });
  res.titulo = document.title;
  res.lang = document.documentElement.lang;
  res.enlace_saltar = !!document.querySelector('a[href^="#main"], a[href^="#contenido"], .skip-link');
  return res;
}
"""

FOCO = r"""
() => { const el = document.activeElement; if (!el || el === document.body) return null;
  const cs = getComputedStyle(el); const r = el.getBoundingClientRect();
  return {elemento: el.tagName.toLowerCase() + ' «' + (el.innerText || el.value || el.getAttribute('placeholder') || '').trim().replace(/\s+/g,' ').slice(0,40) + '»',
          contorno: cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0, sombra: cs.boxShadow !== 'none',
          visible: r.top >= 0 && r.bottom <= innerHeight, top: Math.round(r.top)}; }
"""

resultados = {}
with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    for tema in ("oscuro", "claro"):
        ctx = b.new_context(viewport={"width": 1366, "height": 900}, device_scale_factor=1)
        pg = ctx.new_page()
        pg.goto(BASE + "#/"); pg.wait_for_timeout(1500)
        pg.evaluate("localStorage.clear()"); pg.reload(); pg.wait_for_timeout(1500)
        if tema == "claro":
            pg.evaluate("document.documentElement.setAttribute('data-theme','light')")
        for clave, ruta, nombre in PANTALLAS:
            pg.goto(BASE + ruta); pg.wait_for_timeout(1300)
            if tema == "claro":
                pg.evaluate("document.documentElement.setAttribute('data-theme','light')"); pg.wait_for_timeout(300)
            r = pg.evaluate(JS)
            if tema == "oscuro":
                pg.screenshot(path=f"{OUT}/{clave}.png", full_page=True)
                # 2.4.7 Foco visible y 2.1.1: recorrido con Tab
                pg.evaluate("window.scrollTo(0,0); document.activeElement && document.activeElement.blur()")
                foco = []
                for _ in range(40):
                    pg.keyboard.press("Tab"); pg.wait_for_timeout(40)
                    f = pg.evaluate(FOCO)
                    if f: foco.append(f)
                r["recorrido_tab"] = foco
                # 1.4.10 Reflujo a 320 px de ancho
                pg.set_viewport_size({"width": 320, "height": 800}); pg.goto(BASE + ruta); pg.wait_for_timeout(900)
                r["desborde_320"] = pg.evaluate("({ancho: document.documentElement.scrollWidth, vista: innerWidth})")
                pg.screenshot(path=f"{OUT}/{clave}_320.png", full_page=False)
                pg.set_viewport_size({"width": 1366, "height": 900})
            resultados.setdefault(clave, {"nombre": nombre, "ruta": ruta})[tema] = r
        ctx.close()
    b.close()

json.dump(resultados, open(f"{OUT}/resultados.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
for k, v in resultados.items():
    o = v["oscuro"]; c = v["claro"]
    print(f"{v['nombre']:28} contraste<min oscuro {len(o['contraste']):3} claro {len(c['contraste']):3} | revisar(degradado) {len(o['contraste_revisar']):2} | "
          f"click sin teclado {len(o['click_sin_teclado']):2} | objetivos<24 {len(o['objetivos_pequenos']):2} | sin etiqueta {len(o['controles_sin_etiqueta'])} | "
          f"svg sin alt {len(o['svg_sin_alternativa'])} | animaciones {len(o['animaciones'])} | 320px {o['desborde_320']}")
