"""Capturas anotadas del prototipo para docs/etica.md.
Cada etiqueta corresponde a un hallazgo de docs/etica.md. Animaciones detenidas para que la captura sea nítida.
Uso: python3 anotar.py <carpeta_salida>
"""
import os, sys
from playwright.sync_api import sync_playwright

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
BASE = "http://127.0.0.1:8765/index.html"

COLORES = {  # tipo: (borde y fondo de la etiqueta, color del texto)
    "A": ("#e879f9", "#1a0820"),   # accesibilidad
    "T": ("#22d3ee", "#04161a"),   # transparencia e IA
    "P": ("#facc15", "#1f1600"),   # priorización y sesgo
    "D": ("#a3e635", "#0f1a00"),   # datos personales
    "OK": ("#ffffff", "#065f46"),  # ya resuelto
}

OVERLAY = r"""
(items) => {
  const find = (s) => {
    if (s.startsWith('xpath=')) { const r = document.evaluate(s.slice(6), document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null); return r.singleNodeValue; }
    const m = s.match(/^(.*)@(\d+)$/); if (m) return document.querySelectorAll(m[1])[parseInt(m[2])];
    return document.querySelector(s);
  };
  const out = [];
  items.forEach(it => {
    const el = find(it.sel);
    if (!el) { out.push({codigo: it.codigo, ok: false}); return; }
    const r = el.getBoundingClientRect();
    const x = r.left + scrollX, y = r.top + scrollY, pad = it.pad ?? 4;
    const box = document.createElement('div');
    Object.assign(box.style, {position:'absolute', left:(x-pad)+'px', top:(y-pad)+'px', width:(r.width+2*pad)+'px', height:(r.height+2*pad)+'px',
      border:'3px dashed ' + it.borde, borderRadius:'10px', zIndex:9998, pointerEvents:'none', boxShadow:'0 0 0 2px rgba(0,0,0,.35)'});
    document.body.appendChild(box);
    const tag = document.createElement('div');
    tag.textContent = it.etiqueta;
    Object.assign(tag.style, {position:'absolute', zIndex:9999, pointerEvents:'none', background: it.borde, color: it.texto,
      font:'800 15px/1 Arial, Helvetica, sans-serif', padding:'5px 8px', borderRadius:'999px', border:'2px solid #0b0f15',
      boxShadow:'0 2px 6px rgba(0,0,0,.5)', whiteSpace:'nowrap', letterSpacing:'.3px'});
    document.body.appendChild(tag);
    const tw = tag.getBoundingClientRect().width, th = tag.getBoundingClientRect().height;
    let lx = x - pad - 10, ly = y - pad - th + 6;
    if (it.pos === 'tr') lx = x + r.width + pad - tw + 10;
    if (it.pos === 'r') { lx = x + r.width + pad + 6; ly = y + r.height/2 - th/2; }
    if (it.pos === 'l') { lx = x - pad - tw - 6; ly = y + r.height/2 - th/2; }
    if (it.pos === 'bl') { ly = y + r.height + pad - 6; }
    if (it.pos === 'br') { lx = x + r.width + pad - tw + 10; ly = y + r.height + pad - 6; }
    tag.style.left = Math.max(2, lx) + 'px'; tag.style.top = Math.max(2, ly) + 'px';
    out.push({codigo: it.codigo, ok: true});
  });
  return out;
}
"""

PANTALLAS = [
    {"archivo": "anot-01-tablero.png", "ruta": "#/", "recorte": (0, 0, 1366, 1000), "items": [
        ("T1", "T", "xpath=//h1//span[contains(.,'Pórtico En Línea')]", "r"),
        ("A1 · T2", "A", "div.animate-pulse.border-2", "tl"),
        ("P1", "P", "xpath=//div[@onclick][contains(.,'Sin Proyección') or contains(.,'SIN PROYECCIÓN')]", "tr"),
        ("A3", "A", "xpath=//div[@onclick][contains(.,'Zona Roja') or contains(.,'ZONA ROJA')]", "tl"),
        ("A2", "A", "#search-box", "tl"),
        ("A4", "A", "xpath=(//button[normalize-space()='Todas'])[2]", "tr"),
        ("T3", "T", "xpath=//th[contains(.,'Tipo Tasa') or contains(.,'TIPO TASA')]", "tl"),
        ("P2", "P", "xpath=//th[contains(.,'Horas') or contains(.,'HORAS')]", "tr"),
        ("✓ palabra + color", "OK", "xpath=(//tbody//span[contains(.,'Rojo (<200h)')])[1]", "bl"),
        ("✓ alternativa con teclado", "OK", "xpath=(//tbody//button[contains(.,'Ficha')])[1]", "l"),
    ]},
    {"archivo": "anot-02-camiones.png", "ruta": "#/c", "recorte": (0, 90, 1366, 650), "items": [
        ("A5", "A", "xpath=//button[contains(.,'P3') and contains(.,'34 h')]", "tl"),
        ("A5", "A", "xpath=//button[contains(.,'P6') and contains(.,'441 h')]", "tr"),
        ("A2", "A", "#truck-search", "tl"),
        ("P1", "P", "xpath=(//*[contains(text(),'6 Neumáticos 59/80R63')])[1]", "bl"),
    ]},
    {"archivo": "anot-03-ficha.png", "ruta": "#/n/5980R63-2426-1348", "recorte": (0, 70, 1366, 1015), "items": [
        ("A6", "A", "button[onclick='history.back()']", "bl"),
        ("✓ IA declarada", "OK", "xpath=//span[contains(.,'Confianza IA')]", "tr"),
        ("✓ dato sintético declarado", "OK", "xpath=//p[contains(.,'Fotografía sintética')]", "tr"),
        ("T4", "T", "xpath=//div[contains(text(),'Validación del Planificador')]/..", "tl"),
        ("A7", "A", "svg[role='img']@1", "tl"),
        ("T5", "T", "xpath=//span[contains(.,'Validada para reclamo')]", "tr"),
        ("T6", "T", "xpath=//*[contains(text(),'Acción recomendada por el sistema')]/ancestor::div[contains(@class,'rounded-2xl')][1]", "tl"),
        ("T1", "T", "xpath=//*[contains(text(),'Resolución 3D')]", "tr"),
    ]},
    {"archivo": "anot-03b-ficha-verde.png", "ruta": "#/n/5980R63-2053-1317", "recorte": "auto", "items": [
        ("T6", "T", "xpath=//button[contains(.,'Agendar Intervención en Taller')]", "tl"),
    ]},
    {"archivo": "anot-04-agendar.png", "ruta": "#/a/5980R63-2426-1348", "recorte": (280, 80, 1090, 830), "items": [
        ("A6", "A", "xpath=//h1[contains(.,'Agendar')]/preceding::button[1]", "bl"),
        ("T9", "T", "xpath=//h3[contains(.,'Trazabilidad')]/..", "tl"),
        ("T9", "T", "xpath=//button[contains(.,'SAP PM')]", "tr"),
    ]},
    {"archivo": "anot-05-ordenes.png", "ruta": "#/o", "recorte": (0, 70, 1366, 620), "items": [
        ("T7", "T", "xpath=//div[@onclick][contains(.,'EJECUTADAS') or contains(.,'Ejecutadas')]", "tr"),
        ("T7", "T", "xpath=//div[@onclick][contains(.,'ANULADAS') or contains(.,'Anuladas')]", "tr"),
        ("A8", "A", "xpath=(//button[normalize-space()='ver más'])[1]", "r"),
        ("A2", "A", "#order-search", "tl"),
        ("✓ sin datos personales", "OK", "xpath=//button[contains(.,'Exportar Informe')]", "bl"),
    ]},
    {"archivo": "anot-06-simulador.png", "ruta": "#/sim", "recorte": (0, 70, 1366, 1010), "items": [
        ("D1", "D", "img[alt='Camión CAEX']", "tr"),
        ("A2", "A", "select", "tl"),
        ("T1", "T", "xpath=//span[contains(.,'Precisión: ±0,5')]", "tr"),
        ("A4 · A9", "A", "#sim-terminal", "tl"),
        ("T8", "T", "xpath=//h3[contains(.,'Paso Registrado')]/ancestor::div[contains(@class,'border-2')][1]", "tl"),
    ]},
]


def preparar(pg, ruta, tema="oscuro", ancho=1366):
    pg.set_viewport_size({"width": ancho, "height": 900})
    pg.goto("about:blank")  # recarga completa: borra anotaciones y tema de la captura anterior
    pg.goto(BASE + ruta); pg.wait_for_timeout(1300)
    pg.evaluate("document.documentElement.removeAttribute('data-theme')")
    if tema == "claro":
        pg.evaluate("document.documentElement.setAttribute('data-theme','light')"); pg.wait_for_timeout(300)
    pg.add_style_tag(content="*,*::before,*::after{animation:none!important;transition:none!important}")
    pg.evaluate("window.scrollTo(0,0)")


def anotar(pg, items):
    data = [{"codigo": c, "etiqueta": c, "borde": COLORES[t][0], "texto": COLORES[t][1], "sel": s, "pos": pos} for c, t, s, pos in items]
    res = pg.evaluate(OVERLAY, data)
    faltan = [r["codigo"] for r in res if not r["ok"]]
    if faltan:
        print("   NO ENCONTRADOS:", faltan)
    return res


# Propuesta de aviso de IA (T1, T2, T3): se inserta solo en la captura, no cambia el prototipo.
PROPUESTA = r"""
() => {
  const main = document.querySelector('#app');
  const aviso = document.createElement('div');
  aviso.setAttribute('role', 'note');
  aviso.innerHTML = `<strong style="color:#0b0f15;background:#22d3ee;border-radius:6px;padding:2px 7px;margin-right:8px">Prototipo · datos sintéticos</strong>
    Las <strong>horas remanentes</strong> y las <strong>zonas</strong> son estimaciones del modelo de proyección v1.3, y los <strong>daños</strong> los propone un modelo de visión.
    Ningún dato viene todavía de un pórtico real. La decisión de intervenir es siempre del planificador. <u>Cómo se calcula</u>`;
  Object.assign(aviso.style, {border:'2px solid #22d3ee', background:'rgba(34,211,238,.10)', color:'#e6f6fa', borderRadius:'12px',
    padding:'10px 14px', margin:'0 0 16px 0', font:'14px/1.45 Arial, Helvetica, sans-serif'});
  main.prepend(aviso);
  const badge = [...document.querySelectorAll('h1 span')].find(s => s.innerText.includes('Pórtico En Línea'));
  if (badge) { badge.innerHTML = '● Pórtico simulado'; badge.style.color = '#fbbf24'; badge.style.borderColor = 'rgba(251,191,36,.5)'; badge.style.background = 'rgba(251,191,36,.1)'; }
  const alerta = document.querySelector('div.animate-pulse.border-2');
  if (alerta) {
    const p = [...alerta.querySelectorAll('*')].find(e => e.childNodes.length && /certeza/.test(e.innerText) && e.children.length < 3);
    if (p) p.innerHTML = p.innerHTML.replace(/\((\d+)% certeza\)/, '· <span style="background:#22d3ee;color:#04161a;border-radius:5px;padding:1px 6px;font-weight:700">Detectado por IA · confianza $1 % · confirmar en terreno</span>');
    alerta.classList.remove('animate-pulse');
  }
  const th = [...document.querySelectorAll('th')].find(t => /HORAS|Horas/.test(t.innerText));
  if (th) th.insertAdjacentHTML('beforeend', '<div style="font:700 10px Arial;color:#22d3ee;letter-spacing:.3px">ESTIMACIÓN IA ⓘ</div>');
  return true;
}
"""

with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    ctx = b.new_context(viewport={"width": 1366, "height": 900}, device_scale_factor=2)
    pg = ctx.new_page()
    pg.goto(BASE + "#/"); pg.wait_for_timeout(800); pg.evaluate("localStorage.clear()")
    for pan in PANTALLAS:
        print(pan["archivo"])
        preparar(pg, pan["ruta"])
        anotar(pg, pan["items"])
        if pan["recorte"] == "auto":  # cabecera de la ficha + banda de acción recomendada
            alto = pg.evaluate("document.documentElement.scrollHeight")
            x0, y0, x1, y1 = 0, 70, 1366, alto
        else:
            x0, y0, x1, y1 = pan["recorte"]
        pg.screenshot(path=f"{OUT}/{pan['archivo']}", clip={"x": x0, "y": y0, "width": x1 - x0, "height": y1 - y0}, full_page=True)

    print("anot-07-tema-claro.png")
    preparar(pg, "#/n/5980R63-2426-1348", tema="claro")
    anotar(pg, [
        ("A10", "A", "xpath=//*[contains(text(),'HORAS REMANENTES') or contains(text(),'Horas Remanentes') or contains(text(),'Horas remanentes')]/..", "tl"),
        ("A10", "A", "xpath=(//*[contains(text(),'1,17')])[1]/..", "tr"),
        ("A10", "A", "xpath=//span[contains(.,'Validada para reclamo')]", "tr"),
    ])
    pg.screenshot(path=f"{OUT}/anot-07-tema-claro.png", clip={"x": 0, "y": 160, "width": 1366, "height": 600}, full_page=True)

    print("anot-08-320px.png")
    ctx2 = b.new_context(viewport={"width": 320, "height": 640}, device_scale_factor=2)
    pg2 = ctx2.new_page()
    preparar(pg2, "#/", ancho=320)
    pg2.set_viewport_size({"width": 320, "height": 640})
    anotar(pg2, [("A11", "A", "nav", "bl")])
    pg2.screenshot(path=f"{OUT}/anot-08-320px.png", clip={"x": 0, "y": 0, "width": 460, "height": 400}, full_page=True)

    print("anot-09-propuesta-aviso-ia.png")
    preparar(pg, "#/")
    pg.evaluate(PROPUESTA)
    pg.screenshot(path=f"{OUT}/anot-09-propuesta-aviso-ia.png", clip={"x": 0, "y": 70, "width": 1366, "height": 640}, full_page=True)
    b.close()
print("listo")
