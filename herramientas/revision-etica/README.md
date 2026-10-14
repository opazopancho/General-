# Revisión de accesibilidad y anotaciones del prototipo

Scripts con que se hizo la revisión de la sección 3 de [`docs/etica.md`](../../docs/etica.md). Se vuelven a correr en cada entrega para ver qué hallazgos siguen abiertos.

| Script | Qué hace |
|---|---|
| `auditoria.py` | Recorre las siete pantallas en tema oscuro y claro. Mide el contraste de cada texto, recorre cada pantalla con la tecla Tab, revisa el tamaño de los objetivos, las etiquetas, los nombres accesibles, las alternativas de texto, los mensajes de estado y el reflujo a 320 px. Deja capturas y un `resultados.json` |
| `anotar.py` | Genera las capturas anotadas de `docs/img/etica/`. Los códigos (A1, T6, P1…) son los de `docs/etica.md` |

## Cómo se usan

Requieren Python 3 y Playwright con Chromium (`pip install playwright` y `playwright install chromium`).

```bash
# 1. Servir el prototipo en el puerto 8765
cd frontend
python3 -m http.server 8765

# 2. En otra terminal, desde la raíz del repositorio
python3 herramientas/revision-etica/auditoria.py salida-auditoria
python3 herramientas/revision-etica/anotar.py salida-anotaciones
```

Si cambia el texto de una pantalla, puede que `anotar.py` avise «NO ENCONTRADOS»: hay que actualizar el selector de ese código en la lista `PANTALLAS`.

Son pruebas automáticas propias y no reemplazan una prueba con lector de pantalla ni con personas con discapacidad.
