/* HDL midterm guide: tabs, highlighting, copy, waveforms, quizzes, checklists */
(function () {
  "use strict";
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* ignore */ } },
  };

  let mermaidReady = false;

  /* ---------------- theme ---------------- */
  const themeBtn = document.getElementById("theme-btn");
  const themes = ["system", "light", "dark"];
  const themeLabel = { system: "主題：系統", light: "主題：淺色", dark: "主題：深色" };
  function applyTheme(t) {
    if (t === "system") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", t);
    if (themeBtn) themeBtn.textContent = themeLabel[t];
  }
  let theme = store.get("hdl-theme") || "system";
  applyTheme(theme);
  if (themeBtn) themeBtn.addEventListener("click", () => {
    theme = themes[(themes.indexOf(theme) + 1) % 3];
    store.set("hdl-theme", theme);
    applyTheme(theme);
  });

  /* ---------------- SystemVerilog highlighter ---------------- */
  const KW = new Set(("module endmodule input output inout always always_ff always_comb always_latch assign begin end if else " +
    "case casez casex endcase default for while repeat forever initial posedge negedge or and not nand nor xor xnor buf " +
    "parameter localparam typedef enum struct packed function endfunction task endtask return automatic unique priority " +
    "genvar generate endgenerate import package endpackage do break continue ref const").split(" "));
  const TY = new Set("logic wire reg integer int bit byte shortint longint signed unsigned real time string".split(" "));
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const TOK = /(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|("(?:[^"\\\n]|\\.)*")|(\$[a-zA-Z_]\w*)|(`[a-zA-Z_]\w*)|(\d*'[sS]?[bBoOdDhH][0-9a-fA-FxXzZ_?]+|'[01xz]|\b\d[\d_]*(?:\.\d+)?(?:ns|ps|us|ms|s)?\b)|([a-zA-Z_]\w*)/g;
  function highlight(src, lang) {
    if (lang === "text" || lang === "tcl" || lang === "dat") return esc(src);
    let out = "", last = 0, m;
    TOK.lastIndex = 0;
    while ((m = TOK.exec(src))) {
      out += esc(src.slice(last, m.index));
      const t = m[0];
      if (m[1]) out += '<span class="c">' + esc(t) + "</span>";
      else if (m[2]) out += '<span class="s">' + esc(t) + "</span>";
      else if (m[3] || m[4]) out += '<span class="y">' + esc(t) + "</span>";
      else if (m[5]) out += '<span class="n">' + esc(t) + "</span>";
      else if (KW.has(t)) out += '<span class="k">' + t + "</span>";
      else if (TY.has(t)) out += '<span class="t">' + t + "</span>";
      else out += esc(t);
      last = TOK.lastIndex;
    }
    return out + esc(src.slice(last));
  }

  document.querySelectorAll("pre.code").forEach((pre) => {
    const raw = pre.textContent.replace(/^\n/, "").replace(/\s+$/, "");
    pre.dataset.raw = raw;
    pre.innerHTML = highlight(raw, pre.dataset.lang || "sv");
    const wrap = document.createElement("div");
    wrap.className = "code-wrap";
    const head = document.createElement("div");
    head.className = "code-head";
    const name = document.createElement("span");
    name.textContent = pre.dataset.title || (pre.dataset.lang === "tcl" ? "tcl" : "SystemVerilog");
    const acts = document.createElement("span");
    acts.className = "acts";
    const copy = document.createElement("button");
    copy.type = "button";
    copy.textContent = "複製";
    copy.addEventListener("click", () => {
      const done = () => { copy.textContent = "已複製"; setTimeout(() => (copy.textContent = "複製"), 1400); };
      const fallback = () => {
        const r = document.createRange(); r.selectNodeContents(pre);
        const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r);
        copy.textContent = "已選取，按 Ctrl+C";
      };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(raw).then(done, fallback);
      else fallback();
    });
    acts.appendChild(copy);
    if (pre.dataset.src) {
      const a = document.createElement("a");
      a.href = pre.dataset.src; a.textContent = "原始檔"; a.target = "_blank"; a.rel = "noopener";
      acts.appendChild(a);
    }
    head.append(name, acts);
    pre.parentNode.insertBefore(wrap, pre);
    wrap.append(head, pre);
  });

  /* ---------------- waveform renderer ---------------- */
  const NS = "http://www.w3.org/2000/svg";
  function renderWave(el) {
    let cfg;
    try { cfg = JSON.parse(el.dataset.wave); } catch (e) { el.textContent = "waveform error"; return; }
    const W = 36 * (cfg.hscale || 1), H = 22, G = 12, nameW = cfg.nameW || 78;
    const sigs = cfg.signals;
    const n = Math.max(...sigs.map((s) => s.wave.length));
    const top = cfg.marks ? 18 : 4;
    const width = nameW + n * W + 8, height = top + sigs.length * (H + G) + 2;
    const p = [];
    p.push(`<defs><pattern id="hx${el.dataset.i}" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="6" class="w-hatch"/></pattern></defs>`);
    for (let i = 0; i <= n; i++) p.push(`<line x1="${nameW + i * W}" y1="${top - 2}" x2="${nameW + i * W}" y2="${height}" class="w-grid"/>`);
    sigs.forEach((s, r) => {
      const yh = top + r * (H + G), yl = yh + H, ym = yh + H / 2;
      p.push(`<text x="${nameW - 8}" y="${ym + 4}" text-anchor="end" class="w-name">${esc(s.name)}</text>`);
      const segs = []; let di = 0;
      for (let i = 0; i < s.wave.length; i++) {
        const c = s.wave[i], last = segs[segs.length - 1];
        if (c === ".") { if (!last) continue; if (last.t === "p" || last.t === "n") segs.push({ t: last.t, s: i, l: 1 }); else last.l++; continue; }
        if ("pn01xz".includes(c)) segs.push({ t: c, s: i, l: 1 });
        else segs.push({ t: "=", s: i, l: 1, hl: c === "3", lab: (s.data || [])[di++] ?? "" });
      }
      let prev = null; let d = "";
      segs.forEach((g) => {
        const x0 = nameW + g.s * W, x1 = nameW + (g.s + g.l) * W, xm = x0 + W / 2;
        if (g.t === "p") { d += `M${x0} ${yl}L${x0} ${yh}L${xm} ${yh}L${xm} ${yl}L${x1} ${yl}`; prev = yl; }
        else if (g.t === "n") { d += `M${x0} ${yh}L${x0} ${yl}L${xm} ${yl}L${xm} ${yh}L${x1} ${yh}`; prev = yh; }
        else if (g.t === "0" || g.t === "1") {
          const y = g.t === "1" ? yh : yl;
          d += (prev !== null && prev !== "bus" && prev !== y) ? `M${x0} ${prev}L${x0} ${y}L${x1} ${y}` : `M${x0} ${y}L${x1} ${y}`;
          prev = y;
        } else if (g.t === "z") { d += `M${x0} ${ym}L${x1} ${ym}`; prev = ym; }
        else {
          const e = 4;
          const cls = g.t === "x" ? `fill="url(#hx${el.dataset.i})" class="w-xb"` : `class="w-bus${g.hl ? " w-hl" : ""}"`;
          p.push(`<polygon points="${x0},${ym} ${x0 + e},${yh} ${x1 - e},${yh} ${x1},${ym} ${x1 - e},${yl} ${x0 + e},${yl}" ${cls}/>`);
          if (g.t === "=") p.push(`<text x="${(x0 + x1) / 2}" y="${ym + 4}" text-anchor="middle" class="w-lab">${esc(String(g.lab))}</text>`);
          prev = "bus";
        }
      });
      if (d) p.push(`<path d="${d}" class="w-line"/>`);
    });
    (cfg.marks || []).forEach((m) => {
      const x = nameW + m.at * W;
      p.push(`<line x1="${x}" y1="${top - 4}" x2="${x}" y2="${height}" class="w-mark"/>`);
      p.push(`<text x="${x + 3}" y="11" class="w-marklab">${esc(m.label)}</text>`);
    });
    el.innerHTML = `<svg xmlns="${NS}" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(cfg.title || "timing diagram")}">${p.join("")}</svg>`;
  }
  document.querySelectorAll(".wave").forEach((el, i) => { el.dataset.i = i; renderWave(el); });

  /* ---------------- tabs ---------------- */
  const tabSets = [];
  document.querySelectorAll(".tabs").forEach((box) => {
    const list = box.querySelector(":scope > .tablist");
    const panels = [...box.querySelectorAll(":scope > .tabpanel")];
    const btns = panels.map((pn) => {
      const b = document.createElement("button");
      b.type = "button"; b.setAttribute("role", "tab");
      b.textContent = pn.dataset.label;
      b.addEventListener("click", () => { select(pn.id); history.replaceState(null, "", "#" + pn.id); window.scrollTo({ top: box.offsetTop - 140 }); });
      list.appendChild(b);
      pn.setAttribute("role", "tabpanel");
      return b;
    });
    function select(id) {
      panels.forEach((pn, i) => {
        const on = pn.id === id;
        pn.hidden = !on;
        btns[i].setAttribute("aria-selected", on ? "true" : "false");
        if (on) { renderMermaidIn(pn); btns[i].scrollIntoView({ block: "nearest", inline: "nearest" }); }
      });
    }
    tabSets.push({ box, panels, select });
    select(panels[0].id);
  });

  function openFromHash() {
    const id = decodeURIComponent(location.hash.slice(1));
    if (!id) return;
    const target = document.getElementById(id);
    if (!target) return;
    // open every tab panel that contains the target (outermost first)
    const chain = [];
    let node = target;
    while (node) { if (node.classList && node.classList.contains("tabpanel")) chain.unshift(node); node = node.parentElement; }
    chain.forEach((pn) => tabSets.forEach((t) => { if (t.panels.includes(pn)) t.select(pn.id); }));
    if (!target.classList.contains("tabpanel")) setTimeout(() => target.scrollIntoView({ block: "start" }), 30);
  }
  window.addEventListener("hashchange", openFromHash);
  openFromHash();

  /* ---------------- mermaid (rendered lazily when a tab becomes visible) ---------------- */
  function renderMermaidIn(root) {
    if (!window.mermaid) return;
    if (!mermaidReady) {
      const dark = document.documentElement.getAttribute("data-theme") === "dark" ||
        (!document.documentElement.getAttribute("data-theme") && matchMedia("(prefers-color-scheme: dark)").matches);
      window.mermaid.initialize({ startOnLoad: false, theme: dark ? "dark" : "neutral", securityLevel: "strict", fontFamily: "JetBrains Mono, monospace" });
      mermaidReady = true;
    }
    const nodes = [...root.querySelectorAll("pre.mermaid:not([data-processed])")].filter((n) => n.offsetParent !== null);
    if (nodes.length) window.mermaid.run({ nodes }).catch(() => {});
  }
  window.addEventListener("load", () => {
    document.querySelectorAll(".tabpanel:not([hidden])").forEach(renderMermaidIn);
    if (!document.querySelector(".tabs")) renderMermaidIn(document);
  });

  /* ---------------- quizzes ---------------- */
  document.querySelectorAll(".quiz").forEach((qz) => {
    const qs = [...qz.querySelectorAll(".q")];
    const scoreEl = qz.parentElement.querySelector(".score");
    let answered = 0, right = 0;
    const update = () => { if (scoreEl) scoreEl.textContent = `得分 ${right} / ${qs.length}（已作答 ${answered} 題）`; };
    qs.forEach((q, qi) => {
      const ans = Number(q.dataset.answer);
      const src = q.querySelector("ol");
      const exp = q.querySelector(".exp");
      const box = document.createElement("div");
      box.className = "opts";
      const items = [...src.children];
      items.forEach((li, i) => {
        const b = document.createElement("button");
        b.type = "button"; b.className = "opt";
        b.innerHTML = String.fromCharCode(65 + i) + ". " + li.innerHTML;
        b.addEventListener("click", () => {
          if (q.dataset.done) return;
          q.dataset.done = "1"; answered++;
          if (i === ans) right++;
          [...box.children].forEach((x, j) => { if (j === ans) x.classList.add("right"); else if (j === i) x.classList.add("wrong"); });
          if (exp) exp.hidden = false;
          update();
        });
        box.appendChild(b);
      });
      src.replaceWith(box);
      const t = q.querySelector(".qt");
      if (t) t.textContent = `${qi + 1}. ` + t.textContent;
    });
    const reset = qz.parentElement.querySelector(".quiz-reset");
    if (reset) reset.addEventListener("click", () => {
      qs.forEach((q) => { delete q.dataset.done; q.querySelectorAll(".opt").forEach((o) => o.classList.remove("right", "wrong")); const e = q.querySelector(".exp"); if (e) e.hidden = true; });
      answered = 0; right = 0; update();
    });
    update();
  });

  /* ---------------- checklists ---------------- */
  document.querySelectorAll(".check input[type=checkbox]").forEach((cb) => {
    const k = "hdl-chk-" + cb.id;
    cb.checked = store.get(k) === "1";
    cb.addEventListener("change", () => store.set(k, cb.checked ? "1" : "0"));
  });

  /* ---------------- seven-segment playground ---------------- */
  document.querySelectorAll(".segplay").forEach((box) => {
    const segs = [...box.querySelectorAll(".s")];
    const out = box.querySelector(".segbits");
    const FONT = ["1000000", "1111001", "0100100", "0110000", "0011001", "0010010", "0000010", "1111000", "0000000", "0010000"];
    function show() {
      // DISPLAY = {g,f,e,d,c,b,a}, active-low
      const order = ["g", "f", "e", "d", "c", "b", "a"];
      const bits = order.map((n) => (box.querySelector(`.s[data-seg="${n}"]`).classList.contains("lit") ? "0" : "1")).join("");
      const digit = FONT.indexOf(bits);
      out.innerHTML = `DISPLAY = 7'b${bits}` + (digit >= 0 ? `　→ 數字 ${digit}` : "");
    }
    segs.forEach((s) => s.addEventListener("click", () => { s.classList.toggle("lit"); show(); }));
    box.querySelectorAll("[data-digit]").forEach((b) => b.addEventListener("click", () => {
      const bits = FONT[Number(b.dataset.digit)];
      ["g", "f", "e", "d", "c", "b", "a"].forEach((n, i) => box.querySelector(`.s[data-seg="${n}"]`).classList.toggle("lit", bits[i] === "0"));
      show();
    }));
    show();
  });
})();
