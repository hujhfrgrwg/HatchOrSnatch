// dump_layout.js: inject into a design page (headless Chrome, page loaded with ?raw, fonts and
// images ready). Walks every `.grp` wrapper and returns a JSON tree of Roblox-ready nodes in
// absolute stage px. Anything Roblox can't draw natively (patterns, clip-path, filters, inline SVG)
// becomes a `raster` node tagged with data-rid, for the exporter to screenshot alone at 2x.
//
// Node shape:
//   { k: 'group'|'frame'|'text'|'image'|'raster', n: name, r: [x,y,w,h],
//     bg: [r,g,b,a], grad: {angle, stops:[[pos,[r,g,b,a]]]}, radius, stroke: {w, c},
//     text, font: {family, weight, size}, color, tstroke: {w, c}, align, src, rid, ch: [...] }
//
// Group wrapper convention in the HTML:
//   <div class="grp" data-n="Hotbar" data-anchor="bottom"> ...full-stage, invisible... </div>
// Name nodes with data-name="SellAllButton". Never use a GuiObject property name (Active, Visible...).
(() => {
  let RID = 0;
  const num = s => parseFloat(s) || 0;
  const R = el => { const r = el.getBoundingClientRect(); return [r.left, r.top, r.width, r.height].map(v => Math.round(v * 100) / 100); };
  const rgba = s => {
    const m = s && s.match(/rgba?\(([^)]+)\)/); if (!m) return null;
    const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
    return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
  };
  const visibleColor = c => c && c[3] > 0.003;

  function gradient(bg) {
    const m = bg.match(/linear-gradient\((.*)\)$/); if (!m) return null;
    const parts = m[1].split(/,(?![^(]*\))/).map(s => s.trim());
    let angle = 180;
    if (!/^rgb/.test(parts[0])) {
      const a = parts.shift();
      const d = a.match(/(-?[\d.]+)deg/);
      angle = d ? +d[1] : ({ 'to bottom': 180, 'to right': 90, 'to top': 0, 'to left': 270 })[a] ?? 180;
    }
    const stops = parts.map((p, i) => {
      const pos = p.match(/([\d.]+)%/);
      return [pos ? +pos[1] / 100 : i / Math.max(parts.length - 1, 1), rgba(p)];
    });
    return { angle, stops };
  }

  function needsRaster(el, cs) {
    return cs.clipPath !== 'none' || cs.filter !== 'none' || el.tagName === 'svg' ||
      /url\(|repeating-|radial-|conic-/.test(cs.backgroundImage) || el.dataset.raster === '1';
  }

  function node(el) {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || num(cs.opacity) === 0) return null;
    const n = { n: el.dataset.name || el.dataset.n || el.tagName.toLowerCase(), r: R(el) };

    if (needsRaster(el, cs)) {
      n.k = 'raster'; n.rid = 'r' + (RID++); el.setAttribute('data-rid', n.rid);
      return n; // children of a raster are baked into it, except live text marked data-live
    }
    if (el.tagName === 'IMG') {
      n.k = 'image'; n.src = el.getAttribute('src').split('?')[0];
      return n;
    }
    const ownText = [...el.childNodes].filter(c => c.nodeType === 3).map(c => c.textContent).join('').replace(/\s+/g, ' ').trim();
    n.k = ownText ? 'text' : 'frame';
    const bg = rgba(cs.backgroundColor); if (visibleColor(bg)) n.bg = bg;
    const g = gradient(cs.backgroundImage); if (g) n.grad = g;
    if (num(cs.borderTopWidth) > 0) n.stroke = { w: num(cs.borderTopWidth), c: rgba(cs.borderTopColor) };
    if (num(cs.borderTopLeftRadius) > 0) n.radius = num(cs.borderTopLeftRadius);
    if (ownText) {
      n.text = ownText; // whitespace collapsed: Roblox would draw every space
      n.font = { family: cs.fontFamily.split(',')[0].replace(/['"]/g, ''), weight: +cs.fontWeight, size: num(cs.fontSize) };
      n.color = rgba(cs.color);
      const ts = num(cs.webkitTextStrokeWidth);
      if (ts > 0) n.tstroke = { w: ts / 2, c: rgba(cs.webkitTextStrokeColor) }; // CSS stroke straddles the edge
      n.align = cs.textAlign;
    }
    const ch = [...el.children].map(node).filter(Boolean);
    if (ch.length) n.ch = ch;
    return n;
  }

  return [...document.querySelectorAll('.grp')].map(g => ({
    k: 'group', n: g.dataset.n, anchor: g.dataset.anchor || 'center', r: R(g),
    ch: [...g.children].map(node).filter(Boolean),
  }));
})();
