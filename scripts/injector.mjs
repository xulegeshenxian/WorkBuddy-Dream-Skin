import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "::1", "[::1]"]);
const ALLOWED_PAGE_PROTOCOLS = new Set(["vscode-file:", "file:"]);
const MAX_ART_BYTES = 16 * 1024 * 1024;
const SKIN_VERSION = (await fs.readFile(path.join(root, "VERSION"), "utf8")).trim();

const AUDIT_MODES = {
  "audit-hover":    { flag: "--audit-hover",    exitCode: 3, resetPointer: true,  run: (session)       => auditHoverSession(session) },
  "audit-composer": { flag: "--audit-composer", exitCode: 8, resetPointer: true,  run: (session)       => auditComposerSession(session) },
  "audit-scenes":   { flag: "--audit-scenes",   exitCode: 9, resetPointer: true,  run: (session, opts) => auditScenesSession(session, opts.auditLabel) },
  "audit-pages":    { flag: "--audit-pages",    exitCode: 4, resetPointer: false, run: (session, opts) => auditPagesSession(session, opts.auditDir, opts.auditLabel) },
  "audit-details":  { flag: "--audit-details",  exitCode: 5, resetPointer: false, run: (session, opts) => auditDetailsSession(session, opts.auditDir, opts.auditLabel) },
  "audit-settings": { flag: "--audit-settings", exitCode: 7, resetPointer: false, run: (session, opts) => auditSettingsSession(session, opts.auditDir, opts.auditLabel) },
};
const AUDIT_FLAG_TO_MODE = Object.fromEntries(Object.entries(AUDIT_MODES).map(([mode, spec]) => [spec.flag, mode]));
const NON_AUDIT_EXIT_CODES = { verify: 2, once: 6, remove: 10 };

function isRunResultFailed(mode, result) {
  if (mode === "probe") return false;
  if (mode === "remove") return result !== true;
  return !result?.pass;
}

function parseArgs(argv) {
  const options = { port: 0, mode: "watch", timeoutMs: 30000, screenshot: null, auditDir: null, auditLabel: null, reload: false, themeDir: null };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--port") options.port = Number(argv[++index]);
    else if (arg === "--once") options.mode = "once";
    else if (arg === "--watch") options.mode = "watch";
    else if (arg === "--verify") options.mode = "verify";
    else if (arg === "--remove") options.mode = "remove";
    else if (arg === "--probe") options.mode = "probe";
    else if (AUDIT_FLAG_TO_MODE[arg]) options.mode = AUDIT_FLAG_TO_MODE[arg];
    else if (arg === "--check-payload") options.mode = "check";
    else if (arg === "--timeout-ms") options.timeoutMs = Number(argv[++index]);
    else if (arg === "--screenshot") options.screenshot = path.resolve(argv[++index]);
    else if (arg === "--audit-dir") options.auditDir = path.resolve(argv[++index]);
    else if (arg === "--audit-label") options.auditLabel = argv[++index];
    else if (arg === "--theme-dir") options.themeDir = path.resolve(argv[++index]);
    else if (arg === "--reload") options.reload = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!Number.isInteger(options.port) || options.port < 1024 || options.port > 65535) {
    if (options.mode !== "check") throw new Error(`Invalid port: ${options.port}`);
  }
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs < 250 || options.timeoutMs > 120000) {
    throw new Error(`Invalid timeout: ${options.timeoutMs}`);
  }
  return options;
}

function validatedDebuggerUrl(target, port) {
  const url = new URL(target.webSocketDebuggerUrl);
  if (url.protocol !== "ws:" || !LOOPBACK_HOSTS.has(url.hostname) || Number(url.port) !== port) {
    throw new Error(`Rejected CDP WebSocket URL outside the selected loopback port: ${url.href}`);
  }
  return url.href;
}

class CdpSession {
  constructor(target, port) {
    this.target = target;
    this.ws = new WebSocket(validatedDebuggerUrl(target, port));
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    this.closed = false;
  }

  async open() {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("CDP WebSocket open timed out")), 5000);
      this.ws.addEventListener("open", () => { clearTimeout(timeout); resolve(); }, { once: true });
      this.ws.addEventListener("error", () => { clearTimeout(timeout); reject(new Error("CDP WebSocket open failed")); }, { once: true });
    });
    this.ws.addEventListener("message", (event) => this.onMessage(event));
    this.ws.addEventListener("close", () => {
      this.closed = true;
      for (const pending of this.pending.values()) {
        clearTimeout(pending.timeout);
        pending.reject(new Error("CDP socket closed"));
      }
      this.pending.clear();
    });
    await this.send("Runtime.enable");
    await this.send("Page.enable");
    return this;
  }

  onMessage(event) {
    const message = JSON.parse(String(event.data));
    if (message.id) {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      clearTimeout(pending.timeout);
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(`${message.error.message} (${message.error.code})`));
      else pending.resolve(message.result);
      return;
    }
    for (const listener of this.listeners.get(message.method) ?? []) listener(message.params ?? {});
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) ?? [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }

  send(method, params = {}, commandTimeoutMs = 10000) {
    if (this.closed) return Promise.reject(new Error("CDP session is closed"));
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP command timed out: ${method}`));
      }, commandTimeoutMs);
      this.pending.set(id, { resolve, reject, timeout });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const response = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
      userGesture: false,
    });
    if (response.exceptionDetails) {
      const detail = response.exceptionDetails.exception?.description ?? response.exceptionDetails.text;
      throw new Error(`Renderer evaluation failed: ${detail}`);
    }
    return response.result?.value;
  }

  close() {
    if (!this.closed) this.ws.close();
    this.closed = true;
  }
}

async function listCandidateTargets(port) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const targets = await response.json();
    return targets.filter((target) => {
      if (target.type !== "page" || !target.webSocketDebuggerUrl || !target.url) return false;
      try {
        const pageUrl = new URL(target.url);
        validatedDebuggerUrl(target, port);
        return ALLOWED_PAGE_PROTOCOLS.has(pageUrl.protocol);
      } catch {
        return false;
      }
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function probeSession(session) {
  return session.evaluate(`(() => {
    const selectors = {
      root: '#root',
      workspace: '.claw-workspace, .teams-content-wrapper, .colleague-chat-page__shell, .colleagues-chat-float',
      sidebar: '.conversation-sidebar, .claw-secondary-sidebar, .claw-sidebar-drawer, .colleagues-chat-float__sidebar',
      chat: '.cbChat, [class*="_cbChat_"], .colleague-chat-cb-chat, .colleague-chat-messages',
      composer: '.input-area-container, [class*="_input-area-container_"], .wb-input-wrapper, textarea, [contenteditable="true"]',
      artifact: '.detail-panel-container, .colleague-chat-artifact-drawer, .colleague-detail-panel'
    };
    const markers = Object.fromEntries(Object.entries(selectors).map(([key, selector]) => [key, Boolean(document.querySelector(selector))]));
    const workspace = document.querySelector(selectors.workspace);
    const inspectRoot = document.querySelector('#root');
    const paintedLayers = inspectRoot ? [...inspectRoot.querySelectorAll('*')].map((node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        tag: node.tagName.toLowerCase(),
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        width: Math.round(box.width),
        height: Math.round(box.height),
        background: style.backgroundColor,
        backgroundImage: style.backgroundImage.slice(0, 180),
        color: style.color
      };
    }).filter((item) => item.width > 180 && item.height > 20 && (item.background !== 'rgba(0, 0, 0, 0)' || item.backgroundImage !== 'none')).slice(0, 60) : [];
    const lightLayers = inspectRoot ? [...inspectRoot.querySelectorAll('*')].map((node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        tag: node.tagName.toLowerCase(),
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        width: Math.round(box.width),
        height: Math.round(box.height),
        background: style.backgroundColor,
        backgroundImage: style.backgroundImage.slice(0, 180)
      };
    }).filter((item) => {
      const channels = (item.background.match(/[0-9]+/g) || []).slice(0, 3).map(Number);
      return item.width > 50 && item.height > 4 && channels.length === 3 && channels.every((value) => value >= 220);
    }).slice(0, 80) : [];
    const composerNode = document.querySelector(selectors.composer);
    const layoutChain = [];
    for (let node = composerNode; node && layoutChain.length < 8; node = node.parentElement) {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      layoutChain.push({
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : node.tagName,
        top: Math.round(box.top),
        bottom: Math.round(box.bottom),
        height: Math.round(box.height),
        position: style.position,
        overflow: style.overflow
      });
    }
    const pseudoLayers = inspectRoot ? [...inspectRoot.querySelectorAll('*')].flatMap((node) => ['::before', '::after'].map((pseudo) => {
      const style = getComputedStyle(node, pseudo);
      return {
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        pseudo,
        content: style.content,
        background: style.backgroundColor,
        backgroundImage: style.backgroundImage.slice(0, 180)
      };
    })).filter((item) => item.content !== 'none' && (item.background !== 'rgba(0, 0, 0, 0)' || item.backgroundImage !== 'none')).slice(0, 80) : [];
    const navigationControls = inspectRoot ? [...inspectRoot.querySelectorAll('button, [role="button"], a')].map((node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 60) || '',
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        tag: node.tagName.toLowerCase(),
        x: Math.round(box.left + box.width / 2),
        y: Math.round(box.top + box.height / 2),
        width: Math.round(box.width),
        height: Math.round(box.height),
        visible: box.width > 0 && box.height > 0 && style.display !== 'none' && style.visibility !== 'hidden'
      };
    }).filter((item) => item.visible && item.text).slice(0, 160) : [];
    const pageRoots = inspectRoot ? [...inspectRoot.querySelectorAll('*')].map((node) => {
      const box = node.getBoundingClientRect();
      return {
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        width: Math.round(box.width),
        height: Math.round(box.height)
      };
    }).filter((item) => item.className && item.width > 500 && item.height > 400).slice(0, 40) : [];
    return {
      title: document.title,
      href: location.href,
      markers,
      workbuddy: /workbuddy/i.test(document.title) && markers.root,
      bodyClass: document.body?.className ?? '',
      rootChildren: document.querySelector('#root')?.childElementCount ?? 0,
      paintedLayers,
      lightLayers,
      layoutChain,
      pseudoLayers,
      navigationControls,
      pageRoots
    };
  })()`);
}

async function connectWorkBuddyTargets(port, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const targets = await listCandidateTargets(port);
      const connected = [];
      for (const target of targets) {
        let session;
        try {
          session = await new CdpSession(target, port).open();
          const probe = await probeSession(session);
          if (probe?.workbuddy) connected.push({ target, session, probe });
          else session.close();
        } catch (error) {
          session?.close();
          lastError = error;
        }
      }
      if (connected.length) return connected;
      lastError = new Error("No page matched the WorkBuddy title and root markers");
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  throw new Error(`No verified WorkBuddy renderer on 127.0.0.1:${port}: ${lastError?.message ?? "timed out"}`);
}

function safeText(value, fallback, maxLength) {
  return typeof value === "string" && value.trim() ? value.trim().slice(0, maxLength) : fallback;
}

function safeColor(value, fallback) {
  if (typeof value !== "string") return fallback;
  const normalized = value.trim();
  return /^#[0-9a-f]{6}$/i.test(normalized) || /^rgba?\([0-9., %]+\)$/i.test(normalized) ? normalized : fallback;
}

function safeNumber(value, fallback, minimum = 0, maximum = 1) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(maximum, Math.max(minimum, number)) : fallback;
}

function safeChoice(value, allowed, fallback) {
  return typeof value === "string" && allowed.includes(value.toLowerCase()) ? value.toLowerCase() : fallback;
}

function safeCssPosition(value, fallback) {
  if (typeof value !== "string") return fallback;
  const normalized = value.trim().replace(/\s+/g, " ");
  const token = "(?:left|center|right|top|bottom|-?\\d+(?:\\.\\d+)?(?:%|px))";
  return new RegExp(`^${token}(?: ${token}){0,3}$`, "i").test(normalized) ? normalized : fallback;
}

function safeCssSize(value, fallback) {
  if (typeof value !== "string") return fallback;
  const normalized = value.trim().replace(/\s+/g, " ");
  const token = "(?:cover|contain|auto|\\d+(?:\\.\\d+)?(?:%|px|vw|vh))";
  return new RegExp(`^${token}(?: ${token})?$`, "i").test(normalized) ? normalized : fallback;
}

function safeAssetName(value, fallback = null) {
  if (value === null || value === undefined || value === "") return fallback;
  if (typeof value !== "string" || path.basename(value) !== value) throw new Error("Theme images must stay inside the theme directory");
  return value;
}

async function loadTheme(themeDir) {
  let assetsRoot = path.join(root, "assets");
  if (themeDir) {
    try {
      await fs.access(path.join(themeDir, "theme.json"));
      assetsRoot = themeDir;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
  const configPath = path.join(assetsRoot, "theme.json");
  const raw = JSON.parse(await fs.readFile(configPath, "utf8"));
  if (![1, 2].includes(raw.schemaVersion)) throw new Error(`${configPath} has an unsupported schema version`);
  const legacyImage = safeAssetName(raw.image);
  const backgroundImage = safeAssetName(raw.images?.background, legacyImage);
  if (!backgroundImage) throw new Error(`${configPath} does not define a background image`);
  const heroImage = safeAssetName(raw.images?.hero, backgroundImage);
  const characterImage = safeAssetName(raw.images?.character, null);
  const theme = {
    schemaVersion: 2,
    id: safeText(raw.id, "custom", 80),
    style: safeText(raw.style, "deep-sea", 40),
    appearance: safeChoice(raw.appearance, ["light", "dark"], "dark"),
    name: safeText(raw.name, "WorkBuddy Dream Skin", 80),
    eyebrow: safeText(raw.eyebrow, "WORKBUDDY DREAM SKIN", 80),
    tagline: safeText(raw.tagline, "Make thoughtful work visible.", 160),
    status: safeText(raw.status, "LOCAL LINK ACTIVE", 80),
    images: {
      background: backgroundImage,
      hero: heroImage,
      character: characterImage,
    },
    layout: {
      backgroundPosition: safeCssPosition(raw.layout?.backgroundPosition, "50% 50%"),
      backgroundSize: safeCssSize(raw.layout?.backgroundSize, "cover"),
      heroPosition: safeCssPosition(raw.layout?.heroPosition, "50% 50%"),
      heroSize: safeCssSize(raw.layout?.heroSize, "cover"),
      characterPosition: safeCssPosition(raw.layout?.characterPosition, "right 28px bottom 86px"),
      characterSize: safeCssSize(raw.layout?.characterSize, "360px auto"),
    },
    effects: {
      backgroundOverlay: safeNumber(raw.effects?.backgroundOverlay, .86),
      heroOverlay: safeNumber(raw.effects?.heroOverlay, .72),
      characterOpacity: safeNumber(raw.effects?.characterOpacity, 1),
      panelOpacity: safeNumber(raw.effects?.panelOpacity, .96, .35, 1),
    },
    decoration: {
      mode: safeChoice(raw.decoration?.mode, ["auto", "on", "off"], characterImage ? "auto" : "off"),
      style: safeText(raw.decoration?.style, raw.style || "deep-sea", 40),
      source: safeText(raw.decoration?.source, characterImage ? "legacy" : "none", 40),
      variant: safeText(raw.decoration?.variant, characterImage ? "legacy" : "none", 40),
    },
    colors: {
      background: safeColor(raw.colors?.background, "#071318"),
      panel: safeColor(raw.colors?.panel, "#0B2025"),
      panelAlt: safeColor(raw.colors?.panelAlt, "#102B30"),
      accent: safeColor(raw.colors?.accent, "#58E6C2"),
      accentAlt: safeColor(raw.colors?.accentAlt, "#8BF3D8"),
      secondary: safeColor(raw.colors?.secondary, "#2F96A3"),
      highlight: safeColor(raw.colors?.highlight, "#F2B866"),
      text: safeColor(raw.colors?.text, "#E8F7F3"),
      muted: safeColor(raw.colors?.muted, "#91AAA5"),
      line: safeColor(raw.colors?.line, "rgba(88, 230, 194, .22)"),
    },
  };
  const mimeByExtension = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".gif": "image/gif", ".svg": "image/svg+xml" };
  const assets = {};
  for (const [role, fileName] of Object.entries(theme.images)) {
    if (!fileName) {
      assets[role] = null;
      continue;
    }
    const imagePath = path.join(assetsRoot, fileName);
    const imageStat = await fs.stat(imagePath);
    if (!imageStat.isFile() || imageStat.size < 1 || imageStat.size > MAX_ART_BYTES) {
      throw new Error(`Theme image must be a non-empty file no larger than ${MAX_ART_BYTES} bytes: ${fileName}`);
    }
    const extension = path.extname(imagePath).toLowerCase();
    if (!mimeByExtension[extension]) throw new Error(`Unsupported theme image format: ${extension || "missing"}`);
    assets[role] = { imagePath, mime: mimeByExtension[extension] };
  }
  return { assets, theme };
}

async function loadStylesheet() {
  const cssDir = path.join(root, "assets", "css");
  const manifest = JSON.parse(await fs.readFile(path.join(cssDir, "manifest.json"), "utf8"));
  if (!Array.isArray(manifest.files) || manifest.files.length === 0) {
    throw new Error("assets/css/manifest.json is missing a non-empty files array");
  }
  const parts = await Promise.all(manifest.files.map((name) => {
    if (typeof name !== "string" || !/^[A-Za-z0-9._-]+\.css$/.test(name)) {
      throw new Error(`assets/css/manifest.json rejects entry: ${name}`);
    }
    return fs.readFile(path.join(cssDir, name), "utf8");
  }));
  return parts.join("");
}

async function loadPayload(themeDir) {
  const [css, template, loaded] = await Promise.all([
    loadStylesheet(),
    fs.readFile(path.join(root, "assets", "renderer-inject.js"), "utf8"),
    loadTheme(themeDir),
  ]);
  const artDataUrls = {};
  let imageBytes = 0;
  const artCache = new Map();
  for (const [role, asset] of Object.entries(loaded.assets)) {
    if (!asset) {
      artDataUrls[role] = null;
      continue;
    }
    if (!artCache.has(asset.imagePath)) {
      const art = await fs.readFile(asset.imagePath);
      imageBytes += art.length;
      artCache.set(asset.imagePath, `data:${asset.mime};base64,${art.toString("base64")}`);
    }
    artDataUrls[role] = artCache.get(asset.imagePath);
  }
  const payload = template
    .replace("__WORKBUDDY_SKIN_CSS_JSON__", JSON.stringify(css))
    .replace("__WORKBUDDY_SKIN_ART_JSON__", JSON.stringify(artDataUrls))
    .replace("__WORKBUDDY_SKIN_THEME_JSON__", JSON.stringify(loaded.theme))
    .replace("__WORKBUDDY_SKIN_VERSION_JSON__", JSON.stringify(SKIN_VERSION));
  return { imageBytes, payload, theme: loaded.theme };
}

async function removeFromSession(session) {
  return session.evaluate(`(() => {
    window.__WORKBUDDY_DREAM_SKIN_DISABLED__ = true;
    const state = window.__WORKBUDDY_DREAM_SKIN_STATE__;
    if (state?.cleanup) return state.cleanup();
    document.documentElement?.classList.remove('workbuddy-dream-skin');
    document.body?.classList.remove('workbuddy-dream-skin-body');
    document.getElementById('workbuddy-dream-skin-style')?.remove();
    document.getElementById('workbuddy-dream-skin-chrome')?.remove();
    return true;
  })()`);
}

async function verifySession(session) {
  return session.evaluate(`(() => {
    const visible = (node) => {
      if (!node) return null;
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return { width: Math.round(box.width), height: Math.round(box.height), visible: box.width > 0 && box.height > 0 && style.display !== 'none' && style.visibility !== 'hidden' };
    };
    const rgb = (value) => {
      const channels = (value.match(/[0-9.]+/g) || []).slice(0, 3).map(Number);
      if (channels.length !== 3) return null;
      return value.startsWith('color(srgb') ? channels.map((item) => item <= 1 ? item * 255 : item) : channels;
    };
    const surfaceIsTransparent = (value) => {
      if (value === 'rgba(0, 0, 0, 0)' || value === 'transparent') return true;
      const slashAlpha = /\\/\\s*([0-9.]+)\\s*\\)$/.exec(value)?.[1];
      if (slashAlpha !== undefined) return Number(slashAlpha) < .12;
      const rgbaAlpha = /^rgba\\([^,]+,[^,]+,[^,]+,\\s*([0-9.]+)\\)$/.exec(value)?.[1];
      return rgbaAlpha !== undefined && Number(rgbaAlpha) < .12;
    };
    const luminance = (channels) => {
      const linear = channels.map((value) => {
        const normalized = value / 255;
        return normalized <= .03928 ? normalized / 12.92 : ((normalized + .055) / 1.055) ** 2.4;
      });
      return .2126 * linear[0] + .7152 * linear[1] + .0722 * linear[2];
    };
    const contrast = (node) => {
      if (!node) return null;
      const style = getComputedStyle(node);
      const foreground = rgb(style.color);
      let backgroundNode = node;
      while (backgroundNode && surfaceIsTransparent(getComputedStyle(backgroundNode).backgroundColor)) backgroundNode = backgroundNode.parentElement;
      const background = rgb(backgroundNode ? getComputedStyle(backgroundNode).backgroundColor : style.backgroundColor);
      if (!foreground || !background) return null;
      const first = luminance(foreground);
      const second = luminance(background);
      return Number(((Math.max(first, second) + .05) / (Math.min(first, second) + .05)).toFixed(2));
    };
    const chrome = document.getElementById('workbuddy-dream-skin-chrome');
    const appearance = document.documentElement.dataset.workbuddyDreamSkinAppearance || 'dark';
    const topbar = document.querySelector('.workbuddy-topbar');
    const selectedItem = document.querySelector('.conversation-list .conversation-agent-card[class*="_selected_"]');
    const chatPage = Boolean(document.querySelector('.main-content--chat'));
    const chatChromeClear = !chatPage || ['.wbds-brand', '.wbds-status', '.wbds-coordinate', '.wbds-character'].every((selector) => {
      const node = chrome?.querySelector(selector);
      return !node || getComputedStyle(node).display === 'none';
    });
    const contentSurfaces = [...document.querySelectorAll('.cb-markdown-pre, .cb-markdown-pre__header, .cb-markdown table, .cb-markdown th')]
      .filter((node) => visible(node)?.visible)
      .map((node) => {
        const style = getComputedStyle(node);
        const background = rgb(style.backgroundColor);
        return {
          className: typeof node.className === 'string' ? node.className.slice(0, 120) : '',
          background: style.backgroundColor,
          contrast: contrast(node),
          luminance: background ? Number(luminance(background).toFixed(3)) : null
        };
      });
    const taskContentClear = contentSurfaces.every((surface) => surface.luminance !== null &&
      (appearance === 'light' ? surface.luminance > .65 : surface.luminance < .35) &&
      (surface.contrast === null || surface.contrast >= 4.5));
    const preparing = document.querySelector('.workspace-preparing');
    const preparingStyle = preparing ? getComputedStyle(preparing) : null;
    const preparingBackground = preparingStyle ? rgb(preparingStyle.backgroundColor) : null;
    const preparingClear = !visible(preparing)?.visible || Boolean(preparingBackground &&
      (appearance === 'light' ? luminance(preparingBackground) > .65 : luminance(preparingBackground) < .35));
    const rootStyle = getComputedStyle(document.documentElement);
    const permissionButton = [...document.querySelectorAll('button')].find((node) => node.textContent?.trim().includes('默认权限'));
    const decorationImage = chrome?.querySelector('.wbds-character-card img');
    const result = {
      installed: document.documentElement.classList.contains('workbuddy-dream-skin'),
      appearance,
      version: window.__WORKBUDDY_DREAM_SKIN_STATE__?.version ?? null,
      themeId: window.__WORKBUDDY_DREAM_SKIN_STATE__?.themeId ?? null,
      stylePresent: Boolean(document.getElementById('workbuddy-dream-skin-style')),
      chromePresent: Boolean(chrome),
      chromePointerEvents: chrome ? getComputedStyle(chrome).pointerEvents : null,
      artLayers: {
        background: rootStyle.getPropertyValue('--wbds-background-art').trim(),
        hero: rootStyle.getPropertyValue('--wbds-hero-art').trim(),
        character: rootStyle.getPropertyValue('--wbds-character-art').trim(),
        characterLayer: Boolean(chrome?.querySelector('.wbds-character')),
        characterImage: decorationImage ? {
          width: Math.round(decorationImage.getBoundingClientRect().width),
          height: Math.round(decorationImage.getBoundingClientRect().height),
          objectFit: getComputedStyle(decorationImage).objectFit
        } : null
      },
      runtimeText: {
        primary: rootStyle.getPropertyValue('--cb-text-primary').trim(),
        secondary: rootStyle.getPropertyValue('--cb-text-secondary').trim(),
        muted: rootStyle.getPropertyValue('--cb-text-muted').trim(),
        permissionColor: permissionButton ? getComputedStyle(permissionButton).color : null,
        permissionContrast: contrast(permissionButton)
      },
      root: visible(document.querySelector('#root')),
      workspace: visible(document.querySelector('.claw-workspace, .teams-content-wrapper, .colleague-chat-page__shell, .colleagues-chat-float')),
      sidebar: visible(document.querySelector('.conversation-sidebar, .claw-secondary-sidebar, .claw-sidebar-drawer, .colleagues-chat-float__sidebar')),
      chat: visible(document.querySelector('.cbChat, [class*="_cbChat_"], .colleague-chat-cb-chat, .colleague-chat-messages')),
      composer: visible(document.querySelector('.input-area-container, [class*="_input-area-container_"], .wb-input-wrapper, textarea, [contenteditable="true"]')),
      documentOverflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      topbarContrast: contrast(topbar),
      selectedItemContrast: contrast(selectedItem),
      chatChromeClear,
      taskContentClear,
      contentSurfaces,
      preparingClear
    };
    result.pass = result.installed && result.version === ${JSON.stringify(SKIN_VERSION)} && result.stylePresent &&
      result.chromePresent && result.chromePointerEvents === 'none' && result.root?.visible && !result.documentOverflowX &&
      result.artLayers.background !== 'none' && result.artLayers.hero !== 'none' && result.artLayers.characterLayer &&
      result.artLayers.characterImage?.objectFit === 'contain' && result.runtimeText.primary && result.runtimeText.secondary &&
      (result.runtimeText.permissionContrast === null || result.runtimeText.permissionContrast >= 4.5) &&
      (result.topbarContrast === null || result.topbarContrast >= 4.5) &&
      (result.selectedItemContrast === null || result.selectedItemContrast >= 4.5) && result.chatChromeClear &&
      result.taskContentClear && result.preparingClear;
    return result;
  })()`);
}

async function waitForVerifiedSession(session, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let result;
  while (Date.now() < deadline) {
    result = await verifySession(session);
    if (result.pass) return result;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return result;
}

async function auditHoverSession(session) {
  const targets = await session.evaluate(`(() => {
    const visible = (node) => {
      if (!node) return false;
      const box = node.getBoundingClientRect();
      return box.width > 0 && box.height > 0 && box.top >= 30 && box.bottom <= innerHeight;
    };
    const point = (name, node) => {
      if (!visible(node)) return null;
      const box = node.getBoundingClientRect();
      return { name, className: typeof node.className === 'string' ? node.className.slice(0, 160) : '', x: Math.round(box.left + box.width / 2), y: Math.round(box.top + box.height / 2) };
    };
    const hittableCard = (node) => {
      if (!visible(node)) return false;
      const box = node.getBoundingClientRect();
      const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return hit?.closest('.conversation-agent-card') === node;
    };
    const cards = [...document.querySelectorAll('.conversation-list .conversation-agent-card')];
    const card = cards.find((node) => hittableCard(node) && !node.className.includes('_selected_')) || cards.find(hittableCard);
    const showMoreButtons = [...document.querySelectorAll('.conversation-show-more-button')].filter(visible);
    return [
      point('show-more', showMoreButtons[0]),
      point('collapse', showMoreButtons.length > 1 ? showMoreButtons[showMoreButtons.length - 1] : null),
      point('spaces-label', document.querySelector('.conversation-section-label.conversation-section-label-groups')),
      point('growth-plan', document.querySelector('.growth-plan-entry')),
      point('quick-action', document.querySelector('.quick-actions__item')),
      point('conversation-card', card)
    ].filter(Boolean);
  })()`);
  if (!targets.length) return { pass: true, skipped: true, reason: "No hover audit target is visible", targets: [] };
  const results = [];
  for (const target of targets) {
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: target.x, y: target.y });
    await new Promise((resolve) => setTimeout(resolve, 650));
    const result = await session.evaluate(`(() => {
    const channels = (value) => {
      const values = (value.match(/[0-9.]+/g) || []).slice(0, 3).map(Number);
      return value.startsWith('color(srgb') ? values.map((item) => item <= 1 ? item * 255 : item) : values;
    };
    const luminance = (values) => {
      const linear = values.map((value) => {
        const normalized = value / 255;
        return normalized <= .03928 ? normalized / 12.92 : ((normalized + .055) / 1.055) ** 2.4;
      });
      return .2126 * linear[0] + .7152 * linear[1] + .0722 * linear[2];
    };
    const ratio = (foreground, background) => {
      const first = luminance(channels(foreground));
      const second = luminance(channels(background));
      return Number(((Math.max(first, second) + .05) / (Math.min(first, second) + .05)).toFixed(2));
    };
    const describe = (node, textNode = node) => {
      if (!node) return null;
      const surface = getComputedStyle(node);
      const text = getComputedStyle(textNode || node);
      const backgroundChannels = channels(surface.backgroundColor);
      return {
        tag: node.tagName.toLowerCase(),
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        parentClassName: typeof node.parentElement?.className === 'string' ? node.parentElement.className.slice(0, 180) : '',
        role: node.getAttribute('role'),
        background: surface.backgroundColor,
        color: text.color,
        brightness: backgroundChannels.length === 3 ? Math.round(backgroundChannels.reduce((sum, value) => sum + value, 0) / 3) : null,
        contrast: ratio(text.color, surface.backgroundColor)
      };
    };
    const hovered = document.elementFromPoint(${target.x}, ${target.y});
    const appearance = document.documentElement.dataset.workbuddyDreamSkinAppearance || 'dark';
    const surfaceNode = hovered?.closest('.conversation-agent-card, .conversation-section-label, .growth-plan-entry, .quick-actions__item, button, [role="button"]') || hovered;
    const title = surfaceNode?.querySelector('[class*="_title_"]') || surfaceNode;
    const tooltips = [...document.querySelectorAll('[role="tooltip"], .ant-tooltip-inner, [class*="tooltip" i]')]
      .filter((node) => {
        const box = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        return box.width > 0 && box.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
      }).slice(0, 8).map((node) => describe(node));
    const surface = describe(surfaceNode, title);
    const lightSurfaces = appearance === 'dark' ? [...document.querySelectorAll('#root *, body > div:not(#root) *')].filter((node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      const values = channels(style.backgroundColor);
      return box.top >= 30 && box.width > 50 && box.height > 20 && !node.closest('.workbuddy-window-controls') &&
        style.display !== 'none' && style.visibility !== 'hidden' &&
        values.length === 3 && values.every((value) => value >= 220);
    }).slice(0, 20).map((node) => describe(node)) : [];
    const overlaySelector = '[role="menu"], [role="listbox"], .ant-popover-inner, .ant-dropdown-menu, [class*="popover" i], [class*="dropdown-menu" i]';
    const overlayText = [...document.querySelectorAll(overlaySelector)].flatMap((root) => [...root.querySelectorAll('*')]
      .filter((node) => node.children.length === 0 && node.textContent?.trim())
      .map((node) => {
        const box = node.getBoundingClientRect();
        if (box.width <= 0 || box.height <= 0) return null;
        let backgroundNode = node;
        while (backgroundNode && getComputedStyle(backgroundNode).backgroundColor === 'rgba(0, 0, 0, 0)') {
          if (backgroundNode === root) break;
          backgroundNode = backgroundNode.parentElement;
        }
        const foreground = getComputedStyle(node).color;
        const background = getComputedStyle(backgroundNode || root).backgroundColor;
        return {
          text: node.textContent.trim().slice(0, 60),
          className: typeof node.className === 'string' ? node.className.slice(0, 160) : '',
          color: foreground,
          background,
          contrast: ratio(foreground, background)
        };
      }).filter(Boolean)).slice(0, 30);
    const surfaceTonePass = appearance === 'light' ? surface?.brightness >= 180 : surface?.brightness < 180;
    const tooltipPass = tooltips.every((item) => (appearance === 'light' ? item.brightness >= 180 : item.brightness < 180) && item.contrast >= 4.5);
    const overlayTextPass = overlayText.every((item) => item.contrast >= 4.5);
    return {
      pass: Boolean(surface && surfaceTonePass && surface.contrast >= 4.5 && tooltipPass && overlayTextPass && lightSurfaces.length === 0),
      appearance,
      surface,
      tooltips,
      lightSurfaces,
      overlayText
    };
    })()`);
    results.push({ name: target.name, targetClassName: target.className, x: target.x, y: target.y, ...result });
  }
  return { pass: results.every((item) => item.pass), skipped: false, targets: results };
}

async function findControlPointDetail(session, spec) {
  return session.evaluate(`(() => {
    const spec = ${JSON.stringify(spec)};
    const scope = spec.scope ? document.querySelector(spec.scope) : document;
    if (!scope) return { point: null, diagnosis: { reason: 'scope-not-found', scope: spec.scope } };
    const visible = (node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      if (box.width <= 0 || box.height <= 0) return false;
      if (style.display === 'none' || style.visibility === 'hidden') return false;
      if (spec.allowClipped) {
        // Docked bottom-bar controls extend past innerHeight; require only that the center is on-screen
        // and the top is below any fake window chrome.
        const centerY = box.top + box.height / 2;
        return centerY >= 30 && centerY < innerHeight;
      }
      return box.top >= 30 && box.bottom <= innerHeight;
    };
    let candidates = spec.selector ? [...scope.querySelectorAll(spec.selector)] : [...scope.querySelectorAll('button, [role="button"], a')];
    const rawMatches = candidates.length;
    if (spec.text) {
      candidates = candidates.filter((node) => {
        const text = node.textContent?.trim().replace(/\\s+/g, ' ') || '';
        return spec.exactText ? text === spec.text : text.startsWith(spec.text);
      });
    }
    const textMatches = candidates.length;
    let node = candidates.find(visible);
    if (!node) {
      const nearMiss = candidates[0];
      const box = nearMiss?.getBoundingClientRect();
      const style = nearMiss ? getComputedStyle(nearMiss) : null;
      return {
        point: null,
        diagnosis: {
          reason: rawMatches === 0 ? 'selector-no-match' : textMatches === 0 ? 'text-filter-no-match' : 'visibility-check-failed',
          rawMatches,
          textMatches,
          innerHeight,
          nearMiss: nearMiss ? {
            className: typeof nearMiss.className === 'string' ? nearMiss.className.slice(0, 180) : '',
            rect: box ? { x: Math.round(box.left), y: Math.round(box.top), w: Math.round(box.width), h: Math.round(box.height) } : null,
            display: style?.display,
            visibility: style?.visibility,
          } : null,
        },
      };
    }
    if (spec.closestClickable) {
      node = node.closest('button, [role="button"], a, [role="menuitem"], [class*="item" i]') || node;
    }
    const box = node.getBoundingClientRect();
    return {
      point: {
        x: Math.round(box.left + box.width / 2),
        y: Math.round(box.top + box.height / 2),
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        text: node.textContent?.trim().replace(/\\s+/g, ' ').slice(0, 60) || ''
      }
    };
  })()`);
}

async function findControlPoint(session, spec) {
  const detail = await findControlPointDetail(session, spec);
  return detail?.point ?? null;
}

async function clickControl(session, spec) {
  const detail = await findControlPointDetail(session, spec);
  const point = detail?.point;
  if (!point) return {
    clicked: false,
    reason: `Control not found: ${spec.name || spec.text || spec.selector}`,
    diagnosis: detail?.diagnosis,
  };
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
  await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await new Promise((resolve) => setTimeout(resolve, spec.waitMs || 1300));
  return { clicked: true, point };
}

async function closeSettingsModal(session) {
  const point = await session.evaluate(`(() => {
    const modal = [...document.querySelectorAll('.settings-modal')].find((node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return box.width > 0 && box.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
    });
    if (!modal) return null;
    const modalBox = modal.getBoundingClientRect();
    const close = [...modal.querySelectorAll('button, [role="button"]')].find((node) => {
      const box = node.getBoundingClientRect();
      return box.width > 0 && box.height > 0 && box.top < modalBox.top + 80 && box.right > modalBox.right - 80;
    });
    if (!close) return null;
    const box = close.getBoundingClientRect();
    return { x: Math.round(box.left + box.width / 2), y: Math.round(box.top + box.height / 2) };
  })()`);
  if (!point) return { closed: false, alreadyClosed: true };
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
  await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await new Promise((resolve) => setTimeout(resolve, 500));
  return { closed: true, point };
}

async function auditComposerSession(session) {
  await closeSettingsModal(session);
  const states = [];
  const hoverAndAudit = async (label, spec, waitMs = 500) => {
    const point = await findControlPoint(session, spec);
    if (!point) {
      states.push({ label, pass: false, reason: `Control not found: ${spec.name || spec.selector}` });
      return null;
    }
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
    await new Promise((resolve) => setTimeout(resolve, waitMs));
    if (spec.expectedSurface) {
      for (let attempt = 0; attempt < 2; attempt += 1) {
        const visible = await session.evaluate(`Boolean([...document.querySelectorAll(${JSON.stringify(spec.expectedSurface)})].find((candidate) => {
          const box = candidate.getBoundingClientRect();
          const style = getComputedStyle(candidate);
          return box.width > 0 && box.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
        }))`);
        if (visible) break;
        await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x + (attempt + 1) * 2, y: point.y });
        await new Promise((resolve) => setTimeout(resolve, 550));
      }
    }
    const visual = await auditVisualState(session, label);
    if (spec.expectedSurface) {
      visual.expectedSurface = await session.evaluate(`(() => {
        const node = [...document.querySelectorAll(${JSON.stringify(spec.expectedSurface)})].find((candidate) => {
          const box = candidate.getBoundingClientRect();
          const style = getComputedStyle(candidate);
          return box.width > 0 && box.height > 0 && style.display !== 'none' && style.visibility !== 'hidden';
        });
        if (!node) return null;
        const style = getComputedStyle(node);
        const box = node.getBoundingClientRect();
        return {
          className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
          width: Math.round(box.width),
          height: Math.round(box.height),
          background: style.backgroundColor,
          color: style.color
        };
      })()`);
      visual.pass = visual.pass && Boolean(visual.expectedSurface);
    }
    states.push({ label, point, ...visual });
    return point;
  };

  await hoverAndAudit("composer-model-trigger-hover", {
    name: "composer-model-trigger",
    selector: 'button[class*="_trigger_qeqjw_"]'
  });
  await hoverAndAudit("composer-workspace-trigger-hover", {
    name: "composer-workspace-trigger",
    selector: 'button[class*="_chip_fxx2z_"]'
  });
  await hoverAndAudit("composer-permission-trigger-hover", {
    name: "composer-permission-trigger",
    selector: '.wb-home-composer button[class*="_button_18jez_"]'
  });

  const opened = await clickControl(session, {
    name: "composer-model-trigger-open",
    selector: 'button[class*="_trigger_qeqjw_"]',
    waitMs: 500
  });
  if (!opened.clicked) {
    states.push({ label: "composer-model-popover-open", pass: false, reason: opened.reason });
  } else {
    const popover = await auditVisualState(session, "composer-model-popover-open");
    states.push(popover);
    await hoverAndAudit("composer-model-item-hover", {
      name: "composer-model-item",
      selector: '[class*="_popover_qeqjw_"] [class*="_modelItem_"]',
      text: "GLM-5v-Turbo",
      closestClickable: true,
      expectedSurface: '[class*="_subMenu_gtbqm_"]'
    }, 850);
  }

  await session.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  await session.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
  await new Promise((resolve) => setTimeout(resolve, 250));
  return { pass: states.length === 5 && states.every((state) => state.pass), states };
}

async function auditScenesSession(session, auditLabel = null) {
  await closeSettingsModal(session);
  const allScenes = ["日常办公", "代码开发", "设计创意"];
  const scenes = auditLabel ? allScenes.filter((scene) => scene === auditLabel) : allScenes;
  const states = [];
  for (const scene of scenes) {
    const sceneClick = await clickControl(session, {
      name: `scene-${scene}`,
      selector: ".wb-scene-tabs__pill",
      text: scene,
      exactText: true,
      waitMs: 350
    });
    if (!sceneClick.clicked) {
      states.push({ label: scene, pass: false, reason: sceneClick.reason });
      continue;
    }
    const action = await session.evaluate(`(() => {
      const node = [...document.querySelectorAll('.quick-actions__item')].find((candidate) => {
        const box = candidate.getBoundingClientRect();
        const style = getComputedStyle(candidate);
        return !candidate.classList.contains('quick-actions__item--more') && box.width > 0 && box.height > 0 && style.display !== 'none';
      });
      if (!node) return null;
      const box = node.getBoundingClientRect();
      return { x: Math.round(box.left + box.width / 2), y: Math.round(box.top + box.height / 2), text: node.textContent?.trim() || '' };
    })()`);
    if (!action) {
      states.push({ label: scene, pass: false, reason: "No quick action is visible" });
      continue;
    }
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: action.x, y: action.y });
    await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: action.x, y: action.y, button: "left", clickCount: 1 });
    await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: action.x, y: action.y, button: "left", clickCount: 1 });
    await new Promise((resolve) => setTimeout(resolve, 550));
    const visual = await auditVisualState(session, `scene-${scene}-${action.text}`);
    const controls = await session.evaluate(`(() => [...document.querySelectorAll('.main-content button, .main-content [role="button"]')].map((node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        text: node.textContent?.trim().replace(/\\s+/g, ' ').slice(0, 80) || '',
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        x: Math.round(box.left), y: Math.round(box.top), width: Math.round(box.width), height: Math.round(box.height),
        background: style.backgroundColor, color: style.color
      };
    }).filter((item) => item.width > 40 && item.height > 20 && item.y > 360 && item.y < 660).slice(0, 30))()`);
    states.push({ label: scene, action: action.text, controls, ...visual });
    const recommendation = await findControlPoint(session, {
      name: `scene-recommendation-${scene}`,
      selector: ".quick-actions-sub__item"
    });
    if (!recommendation) {
      states.push({ label: `${scene}-recommendation-hover`, pass: false, reason: "No recommendation is visible" });
      continue;
    }
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: recommendation.x, y: recommendation.y });
    await new Promise((resolve) => setTimeout(resolve, 450));
    const hoverVisual = await auditVisualState(session, `scene-${scene}-recommendation-hover`);
    states.push({ label: `${scene}-recommendation-hover`, recommendation, ...hoverVisual });
  }
  await clickControl(session, {
    name: "scene-restore-office",
    selector: ".wb-scene-tabs__pill",
    text: "日常办公",
    exactText: true,
    waitMs: 250
  });
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
  return { pass: states.length === scenes.length * 2 && states.every((state) => state.pass), states };
}

async function closeTopOverlay(session) {
  const point = await session.evaluate(`(() => {
    const visible = (node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return box.width > 300 && box.height > 200 && style.display !== 'none' && style.visibility !== 'hidden';
    };
    const overlays = [...document.querySelectorAll('[role="dialog"], [class*="modal" i], [class*="dialog" i]')].filter(visible);
    const overlay = overlays.sort((a, b) => b.getBoundingClientRect().width * b.getBoundingClientRect().height - a.getBoundingClientRect().width * a.getBoundingClientRect().height)[0];
    if (!overlay) return null;
    const box = overlay.getBoundingClientRect();
    const close = [...overlay.querySelectorAll('button, [role="button"]')].find((node) => {
      const nodeBox = node.getBoundingClientRect();
      return nodeBox.width > 0 && nodeBox.height > 0 && nodeBox.top < box.top + 80 && nodeBox.right > box.right - 80;
    });
    if (!close) return null;
    const closeBox = close.getBoundingClientRect();
    return { x: Math.round(closeBox.left + closeBox.width / 2), y: Math.round(closeBox.top + closeBox.height / 2) };
  })()`);
  if (!point) return { closed: false };
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: point.x, y: point.y });
  await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1 });
  await new Promise((resolve) => setTimeout(resolve, 500));
  return { closed: true, point };
}

async function openKnowledgeFromMore(session, point) {
  if (!point) return false;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const submenuX = Math.min(point.x + 96, 250);
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
    await new Promise((resolve) => setTimeout(resolve, 80));
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: submenuX, y: point.y });
    await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: submenuX, y: point.y, button: "left", clickCount: 1 });
    await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: submenuX, y: point.y, button: "left", clickCount: 1 });
    await new Promise((resolve) => setTimeout(resolve, 160));
    const opened = await session.evaluate(`Boolean([...document.querySelectorAll('*')].find((node) => { const box = node.getBoundingClientRect(); const style = getComputedStyle(node); return node.textContent?.trim() === '腾讯文档' && box.width > 0 && box.height > 0 && box.left >= 230 && box.right <= 470 && box.top >= 30 && box.bottom <= innerHeight && style.display !== 'none' && style.visibility !== 'hidden'; }))`);
    if (!opened) continue;
    await session.send("Runtime.evaluate", {
      expression: `(() => { const nodes = [...document.querySelectorAll('*')].filter((node) => { const box = node.getBoundingClientRect(); const style = getComputedStyle(node); return node.textContent?.trim() === '腾讯文档' && box.width > 0 && box.height > 0 && box.left >= 230 && box.right <= 470 && box.top >= 30 && box.bottom <= innerHeight && style.display !== 'none' && style.visibility !== 'hidden'; }).sort((a, b) => a.getBoundingClientRect().width - b.getBoundingClientRect().width); const node = nodes[0]; const target = node?.closest('button, [role="button"], a, [role="menuitem"], [class*="item" i]') || node; target?.click(); })()`,
      userGesture: true
    });
    await new Promise((resolve) => setTimeout(resolve, 1200));
    return true;
  }
  return false;
}

async function auditVisualState(session, label) {
  return session.evaluate(`(() => {
    const label = ${JSON.stringify(label)};
    const channels = (value) => {
      const values = (value.match(/[0-9.]+/g) || []).slice(0, 3).map(Number);
      return value.startsWith('color(srgb') ? values.map((item) => item <= 1 ? item * 255 : item) : values;
    };
    const luminance = (values) => {
      const linear = values.map((value) => {
        const normalized = value / 255;
        return normalized <= .03928 ? normalized / 12.92 : ((normalized + .055) / 1.055) ** 2.4;
      });
      return .2126 * linear[0] + .7152 * linear[1] + .0722 * linear[2];
    };
    const ratio = (foreground, background) => {
      const firstValues = channels(foreground);
      const secondValues = channels(background);
      if (firstValues.length !== 3 || secondValues.length !== 3) return null;
      const first = luminance(firstValues);
      const second = luminance(secondValues);
      return Number(((Math.max(first, second) + .05) / (Math.min(first, second) + .05)).toFixed(2));
    };
    const visible = (node) => {
      const box = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return box.width > 0 && box.height > 0 && box.bottom > 30 && box.top < innerHeight && style.display !== 'none' && style.visibility !== 'hidden';
    };
    const roots = [
      document.querySelector('.teams-main-content'),
      document.querySelector('.conversation-sidebar'),
      document.querySelector('.detail-panel-container'),
      document.querySelector('.sidebar-next'),
      document.querySelector('.settings-modal'),
      document.querySelector('.tencent-docs-auth-guide'),
      ...document.querySelectorAll('.main-content, [role="dialog"], [class*="modal" i], [class*="dialog" i], [class*="menu" i], [class*="popover" i]'),
      ...document.querySelectorAll('body > div:not(#root)')
    ].filter(Boolean);
    const nodes = [...new Set(roots.flatMap((root) => [root, ...root.querySelectorAll('*')]))];
    const describe = (node, style = getComputedStyle(node)) => ({
      tag: node.tagName.toLowerCase(),
      className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
      background: style.backgroundColor,
      color: style.color
    });
    const appearance = document.documentElement.dataset.workbuddyDreamSkinAppearance || 'dark';
    const lightRaw = appearance === 'dark' ? nodes.filter((node) => {
      if (!visible(node) || node.closest('.workbuddy-window-controls')) return false;
      if (node.matches('img[class*="qrcode" i], img[class*="qr-code" i]')) return false;
      const box = node.getBoundingClientRect();
      const values = channels(getComputedStyle(node).backgroundColor);
      return box.width > 50 && box.height > 20 && values.length === 3 && values.every((value) => value >= 220);
    }).map((node) => describe(node)) : [];
    const lightMap = new Map();
    for (const item of lightRaw) {
      const key = [item.tag, item.className, item.background].join('|');
      const existing = lightMap.get(key) || { ...item, count: 0 };
      existing.count += 1;
      lightMap.set(key, existing);
    }
    const surfaceIsTransparent = (value) => {
      if (value === 'rgba(0, 0, 0, 0)' || value === 'transparent') return true;
      const slashAlpha = /\\/\\s*([0-9.]+)\\s*\\)$/.exec(value)?.[1];
      if (slashAlpha !== undefined) return Number(slashAlpha) < .12;
      const rgbaAlpha = /^rgba\\([^,]+,[^,]+,[^,]+,\\s*([0-9.]+)\\)$/.exec(value)?.[1];
      return rgbaAlpha !== undefined && Number(rgbaAlpha) < .12;
    };
    const lowContrastRaw = nodes.filter((node) => visible(node) && !node.closest('#workbuddy-dream-skin-chrome') && node.children.length === 0 && node.textContent?.trim() && !node.matches('[class*="_levelBadge_qeqjw_"]')).map((node) => {
      let backgroundNode = node;
      while (backgroundNode && surfaceIsTransparent(getComputedStyle(backgroundNode).backgroundColor)) backgroundNode = backgroundNode.parentElement;
      const foreground = getComputedStyle(node).color;
      const background = backgroundNode ? getComputedStyle(backgroundNode).backgroundColor : 'rgb(7, 19, 24)';
      return { ...describe(node), background, contrast: ratio(foreground, background) };
    }).filter((item) => item.contrast !== null && item.contrast < 4.5);
    const contrastMap = new Map();
    for (const item of lowContrastRaw) {
      const key = [item.tag, item.className, item.background, item.color].join('|');
      const existing = contrastMap.get(key) || { ...item, count: 0 };
      existing.count += 1;
      contrastMap.set(key, existing);
    }
    const hasLightRgb = (value) => Array.from({ length: 16 }, (_, index) => 'rgb(' + (240 + index)).some((prefix) => value.includes(prefix));
    const pseudoLight = appearance === 'dark' ? nodes.flatMap((node) => ['::before', '::after'].map((pseudo) => {
      const style = getComputedStyle(node, pseudo);
      return {
        className: typeof node.className === 'string' ? node.className.slice(0, 180) : '',
        pseudo,
        content: style.content,
        background: style.backgroundColor,
        backgroundImage: style.backgroundImage.slice(0, 180)
      };
    })).filter((item) => item.content !== 'none' && !item.className.includes('_slider_qeqjw_') && (hasLightRgb(item.background) || hasLightRgb(item.backgroundImage))).slice(0, 40) : [];
    const pageRoots = nodes.filter((node) => {
      const box = node.getBoundingClientRect();
      return visible(node) && box.width > 500 && box.height > 400 && typeof node.className === 'string' && node.className;
    }).slice(0, 20).map((node) => String(node.className).slice(0, 180));
    const result = {
      label,
      appearance,
      pageRoots,
      lightSurfaces: [...lightMap.values()].slice(0, 50),
      lowContrast: [...contrastMap.values()].slice(0, 50),
      pseudoLight,
      overflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth
    };
    result.pass = result.lightSurfaces.length === 0 && result.lowContrast.length === 0 && result.pseudoLight.length === 0 && !result.overflowX;
    return result;
  })()`);
}

async function auditPagesSession(session, auditDir = null, auditLabel = null) {
  const results = [];
  await closeSettingsModal(session);
  const visit = async (label, spec) => {
    const navigation = await clickControl(session, spec);
    if (!navigation.clicked) {
      results.push({ label, pass: false, navigation });
      return;
    }
    results.push({ ...(await auditVisualState(session, label)), navigation });
    if (auditDir && (!auditLabel || auditLabel === label)) await capture(session, path.join(auditDir, `${String(results.length).padStart(2, '0')}-${label}.png`));
  };
  const sidebar = ".conversation-list";
  const searchNavigation = await clickControl(session, { name: "conversation-search", selector: ".conversation-list-search-button", waitMs: 500 });
  const searchAudit = { ...(await auditVisualState(session, "conversation-search")), navigation: searchNavigation };
  searchAudit.pass = searchAudit.pass && searchNavigation.clicked && Boolean(await session.evaluate(`document.querySelector('.conversation-search-modal')?.getBoundingClientRect().width > 0`));
  results.push(searchAudit);
  if (auditDir && (!auditLabel || auditLabel === "conversation-search")) await capture(session, path.join(auditDir, `${String(results.length).padStart(2, '0')}-conversation-search.png`));
  await closeTopOverlay(session);
  await visit("new-task", { name: "new-task", scope: sidebar, selector: ".conversation-list-tab-button", text: "新建任务" });
  const historyCandidates = await session.evaluate(`(() => {
    const seen = new Set();
    return [...document.querySelectorAll('.conversation-list .conversation-agent-card--standalone, .conversation-list .conversation-agent-card')]
      .filter((node) => {
        const box = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        const text = node.textContent?.trim().replace(/\\s+/g, ' ') || '';
        if (!text || seen.has(text) || box.width <= 0 || box.height <= 0 || box.top < 30 || box.bottom > innerHeight) return false;
        if (style.display === 'none' || style.visibility === 'hidden') return false;
        seen.add(text);
        return true;
      })
      .slice(0, 4)
      .map((node) => {
        const box = node.getBoundingClientRect();
        return { text: node.textContent?.trim().replace(/\\s+/g, ' ').slice(0, 100) || '', x: Math.round(box.left + box.width / 2), y: Math.round(box.top + box.height / 2) };
      });
  })()`);
  const historySamples = [];
  const historyResultNumber = results.length + 1;
  for (let index = 0; index < historyCandidates.length; index += 1) {
    const candidate = historyCandidates[index];
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: candidate.x, y: candidate.y });
    await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: candidate.x, y: candidate.y, button: "left", clickCount: 1 });
    await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: candidate.x, y: candidate.y, button: "left", clickCount: 1 });
    await new Promise((resolve) => setTimeout(resolve, 1400));
    const inspectHistory = async (scrollTarget = null) => session.evaluate(`(() => {
      const visible = (node) => {
        if (!node) return false;
        const box = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        return box.width > 0 && box.height > 0 && box.bottom > 30 && box.top < innerHeight && style.display !== 'none' && style.visibility !== 'hidden';
      };
      const scrollables = [...document.querySelectorAll('.main-content--chat *')].filter((node) => {
        const style = getComputedStyle(node);
        return node.scrollHeight > node.clientHeight + 40 && /auto|scroll/.test(style.overflowY);
      }).sort((a, b) => (b.scrollHeight - b.clientHeight) - (a.scrollHeight - a.clientHeight));
      const scroller = scrollables[0] || null;
      const requested = ${JSON.stringify(scrollTarget)};
      if (scroller && requested === 'top') scroller.scrollTop = 0;
      if (scroller && requested === 'bottom') scroller.scrollTop = scroller.scrollHeight;
      if (scroller && requested) scroller.dispatchEvent(new Event('scroll', { bubbles: true }));
      const chrome = document.getElementById('workbuddy-dream-skin-chrome');
      const messages = [...document.querySelectorAll('.cb-assistant-message, .cb-markdown, [class*="_assistantMessage_"], [class*="_assistantTextContent_"], [class*="_userMessage_"], [class*="_chatMessageBox_"], .group-messages')].filter(visible);
      const visibleText = [...document.querySelectorAll('.main-content--chat *')].filter((node) => {
        if (!visible(node) || !node.textContent?.trim() || node.children.length > 0) return false;
        return !node.closest('.workbuddy-topbar, .input-area-container, [class*="_input-area-container_"], #workbuddy-dream-skin-chrome');
      });
      const composer = document.querySelector('.input-area-container, [class*="_input-area-container_"], .wb-input-wrapper, textarea, [contenteditable="true"]');
      const artifacts = [...document.querySelectorAll('.artifact-slot-panel, .detail-panel-container, .colleague-chat-artifact-drawer, .cb-overview-artifact-item')].filter(visible);
      const decorationHidden = ['.wbds-brand', '.wbds-status', '.wbds-coordinate', '.wbds-character'].every((selector) => {
        const node = chrome?.querySelector(selector);
        return !node || getComputedStyle(node).display === 'none';
      });
      return {
        chatPage: Boolean(document.querySelector('.main-content--chat')),
        visibleMessageCount: messages.length,
        visibleTextCount: visibleText.length,
        composerVisible: visible(composer),
        markdownCount: document.querySelectorAll('.cb-markdown').length,
        codeBlockCount: document.querySelectorAll('.cb-markdown-pre, pre').length,
        tableCount: document.querySelectorAll('.cb-markdown table').length,
        artifactCount: artifacts.length,
        decorationHidden,
        scroll: scroller ? { className: typeof scroller.className === 'string' ? scroller.className.slice(0, 160) : '', top: Math.round(scroller.scrollTop), height: scroller.clientHeight, fullHeight: scroller.scrollHeight, max: Math.max(0, scroller.scrollHeight - scroller.clientHeight) } : null
      };
    })()`);
    const initial = await inspectHistory();
    await inspectHistory("top");
    await new Promise((resolve) => setTimeout(resolve, 420));
    const topStructure = await inspectHistory("top");
    await new Promise((resolve) => setTimeout(resolve, 120));
    const topVisual = await auditVisualState(session, `history-task-${index + 1}-top`);
    if (auditDir && (!auditLabel || auditLabel === "history-task")) {
      await capture(session, path.join(auditDir, `${String(historyResultNumber).padStart(2, '0')}-history-task-${String(index + 1).padStart(2, '0')}-top.png`));
    }
    await inspectHistory("bottom");
    await new Promise((resolve) => setTimeout(resolve, 420));
    const bottomStructure = await inspectHistory("bottom");
    await new Promise((resolve) => setTimeout(resolve, 120));
    const bottomVisual = await auditVisualState(session, `history-task-${index + 1}-bottom`);
    if (auditDir && (!auditLabel || auditLabel === "history-task")) {
      await capture(session, path.join(auditDir, `${String(historyResultNumber).padStart(2, '0')}-history-task-${String(index + 1).padStart(2, '0')}-bottom.png`));
    }
    const structurePass = initial.chatPage && initial.visibleTextCount > 0 && initial.composerVisible && initial.decorationHidden &&
      topStructure.visibleTextCount > 0 && bottomStructure.visibleTextCount > 0 && topStructure.scroll && topStructure.scroll.top <= 2 &&
      bottomStructure.scroll && bottomStructure.scroll.top >= Math.max(0, bottomStructure.scroll.max - 2);
    historySamples.push({
      index: index + 1,
      title: candidate.text,
      pass: Boolean(structurePass && topVisual.pass && bottomVisual.pass),
      initial,
      top: { structure: topStructure, visual: topVisual },
      bottom: { structure: bottomStructure, visual: bottomVisual }
    });
  }
  results.push({
    label: "history-task",
    pass: historySamples.length === 4 && historySamples.every((sample) => sample.pass),
    requestedSamples: 4,
    sampleCount: historySamples.length,
    samples: historySamples
  });
  await clickControl(session, { name: "history-restore-new-task", scope: sidebar, selector: ".conversation-list-tab-button", text: "新建任务", waitMs: 700 });
  await visit("assistant", { name: "assistant", scope: sidebar, selector: ".conversation-list-tab-button", text: "助理" });
  await visit("projects", { name: "projects", scope: sidebar, selector: ".conversation-list-tab-button", text: "项目" });
  await visit("experts", { name: "experts", scope: sidebar, selector: ".conversation-list-tab-button", text: "专家", waitMs: 3200 });
  await visit("skills", { name: "skills", selector: ".um-tab", text: "技能" });
  await visit("connectors", { name: "connectors", selector: ".um-tab", text: "连接器" });
  await visit("automation", { name: "automation", scope: sidebar, selector: ".conversation-list-tab-button", text: "自动化" });
  const menuAlreadyOpen = await session.evaluate(`Boolean([...document.querySelectorAll('.daily-checkin-card, [class*="user-menu"]')].find((node) => {
    const box = node.getBoundingClientRect();
    const style = getComputedStyle(node);
    return box.width > 100 && box.height > 100 && style.display !== 'none' && style.visibility !== 'hidden';
  }))`);
  const userMenuNavigation = menuAlreadyOpen ? { clicked: false, alreadyOpen: true } : await clickControl(session, { name: "user-menu", selector: ".user-menu-trigger" });
  const userMenuAudit = { ...(await auditVisualState(session, "user-menu")), navigation: userMenuNavigation };
  results.push(userMenuAudit);
  if (auditDir && (!auditLabel || auditLabel === "user-menu")) await capture(session, path.join(auditDir, `${String(results.length).padStart(2, '0')}-user-menu.png`));
  const userMenuProbe = await probeSession(session);
  const userMenuResult = results[results.length - 1];
  userMenuResult.controls = userMenuProbe.navigationControls
    .filter((item) => item.x < 320 && item.y > 80)
    .map((item) => ({ text: item.text, className: item.className, tag: item.tag, x: item.x, y: item.y }));
  await visit("settings", { name: "settings", selector: "[class*=\"user-menu\"] *, .daily-checkin-card ~ *", text: "设置", exactText: true, waitMs: 2000 });
  await closeSettingsModal(session);
  await clickControl(session, { name: "restore-new-task", scope: sidebar, selector: ".conversation-list-tab-button", text: "新建任务", waitMs: 700 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
  return { pass: results.every((item) => item.pass), results };
}

async function auditDetailsSession(session, auditDir = null, auditLabel = null) {
  const results = [];
  const sidebar = ".conversation-list";
  const record = async (label) => {
    const result = await auditVisualState(session, label);
    results.push(result);
    if (auditDir && (!auditLabel || auditLabel === label)) {
      await capture(session, path.join(auditDir, `${String(results.length).padStart(2, "0")}-${label}.png`));
    }
  };
  await closeSettingsModal(session);

  await clickControl(session, { name: "projects", scope: sidebar, selector: ".conversation-list-tab-button", text: "项目", waitMs: 1200 });
  await clickControl(session, { name: "new-project", selector: "button, [role=\"button\"]", text: "新建项目", waitMs: 700 });
  await record("project-dialog");
  await clickControl(session, { name: "cancel-project", selector: "button, [role=\"button\"]", text: "取消", exactText: true, waitMs: 1200 });

  await clickControl(session, { name: "automation", scope: sidebar, selector: ".conversation-list-tab-button", text: "自动化", waitMs: 1200 });
  await clickControl(session, { name: "add-automation", selector: "button, [role=\"button\"]", text: "添加自动化", waitMs: 900 });
  await record("automation-editor");
  await clickControl(session, { name: "cancel-automation", selector: "button, [role=\"button\"]", text: "取消", exactText: true, waitMs: 500 });

  await new Promise((resolve) => setTimeout(resolve, 1800));

  await clickControl(session, { name: "more", scope: sidebar, selector: ".conversation-list-tab-button", text: "更多", waitMs: 900 });
  const morePoint = await findControlPoint(session, { name: "more-submenu", scope: sidebar, selector: ".conversation-list-tab-button", text: "更多" });
  if (morePoint) {
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
    await new Promise((resolve) => setTimeout(resolve, 250));
    const submenuX = Math.min(morePoint.x + 96, 250);
    await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: submenuX, y: morePoint.y });
    await session.send("Input.dispatchMouseEvent", { type: "mousePressed", x: submenuX, y: morePoint.y, button: "left", clickCount: 1 });
    await session.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: submenuX, y: morePoint.y, button: "left", clickCount: 1 });
    await new Promise((resolve) => setTimeout(resolve, 900));
  }
  await record("more-menu");
  await openKnowledgeFromMore(session, morePoint);
  await record("knowledge-auth");
  let authVisible = await session.evaluate(`Boolean([...document.querySelectorAll('.tencent-docs-auth-guide')].find((node) => node.getBoundingClientRect().width > 0))`);
  if (!authVisible) {
    results.pop();
    await clickControl(session, { name: "automation-retry", scope: sidebar, selector: ".conversation-list-tab-button", text: "自动化", waitMs: 1400 });
    await clickControl(session, { name: "more-retry", scope: sidebar, selector: ".conversation-list-tab-button", text: "更多", waitMs: 400 });
    const retryPoint = await findControlPoint(session, { name: "more-submenu-retry", scope: sidebar, selector: ".conversation-list-tab-button", text: "更多" });
    await openKnowledgeFromMore(session, retryPoint);
    await record("knowledge-auth");
    authVisible = await session.evaluate(`Boolean([...document.querySelectorAll('.tencent-docs-auth-guide')].find((node) => node.getBoundingClientRect().width > 0))`);
  }
  results[results.length - 1].expectedRootVisible = authVisible;
  results[results.length - 1].pass = results[results.length - 1].pass && authVisible;

  await clickControl(session, { name: "experts", scope: sidebar, selector: ".conversation-list-tab-button", text: "专家", waitMs: 3200 });
  await clickControl(session, { name: "expert-card", selector: ".ec-expert-card", waitMs: 900 });
  await record("expert-dialog");
  await closeTopOverlay(session);
  await new Promise((resolve) => setTimeout(resolve, 2200));

  await clickControl(session, { name: "restore-new-task", scope: sidebar, selector: ".conversation-list-tab-button", text: "新建任务", waitMs: 700 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
  return { pass: results.length === 5 && results.every((item) => item.pass), results };
}

async function auditSettingsSession(session, auditDir = null, auditLabel = null) {
  const results = [];
  const sidebar = ".conversation-list";
  await closeSettingsModal(session);
  const menuAlreadyOpen = await session.evaluate(`Boolean([...document.querySelectorAll('.user-menu-popover')].find((node) => { const box = node.getBoundingClientRect(); const style = getComputedStyle(node); return box.width > 100 && box.height > 100 && style.display !== 'none' && style.visibility !== 'hidden'; }))`);
  if (!menuAlreadyOpen) await clickControl(session, { name: "user-menu", selector: ".user-menu-trigger", allowClipped: true, waitMs: 500 });
  await clickControl(session, { name: "settings", selector: ".user-menu-popover .user-menu-item-label, [class*=\"user-menu\"] .user-menu-item-label, [class*=\"user-menu\"] *", text: "设置", exactText: true, waitMs: 1200 });

  const sections = [
    ["account", "账户管理"],
    ["agent-mailbox", "智能体邮箱"],
    ["system", "系统设置"],
    ["agents", "智能体设置"],
    ["shortcuts", "快捷键"],
    ["memory", "记忆"],
    ["models", "模型"],
    ["assistant", "助理设置"],
    ["personalization", "个性化"],
    ["data", "数据管理"],
    ["security", "安全中心"],
    ["help", "帮助与反馈"]
  ];
  for (const [label, text] of sections) {
    const navigation = await clickControl(session, { name: label, selector: ".settings-navigation__item, .settings-navigation__label", text, exactText: true, closestClickable: true, waitMs: 650 });
    if (!navigation.clicked) {
      results.push({ label, pass: false, navigation });
      continue;
    }
    const result = { ...(await auditVisualState(session, `settings-${label}`)), label, navigation };
    results.push(result);
    if (auditDir && (!auditLabel || auditLabel === label)) {
      await capture(session, path.join(auditDir, `${String(results.length).padStart(2, "0")}-settings-${label}.png`));
    }
  }

  await closeSettingsModal(session);
  await new Promise((resolve) => setTimeout(resolve, 900));
  await clickControl(session, { name: "restore-new-task", scope: sidebar, selector: ".conversation-list-tab-button", text: "新建任务", waitMs: 700 });
  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
  return { pass: results.length === sections.length && results.every((item) => item.pass), results };
}

async function capture(session, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  const params = { format: "png", fromSurface: true, captureBeyondViewport: false };
  try {
    const metrics = await session.send("Page.getLayoutMetrics", {}, 5000);
    const viewport = metrics.cssVisualViewport || metrics.visualViewport || {};
    const width = Math.max(1, Math.floor(viewport.clientWidth ?? viewport.width ?? 0));
    const height = Math.max(1, Math.floor(viewport.clientHeight ?? viewport.height ?? 0));
    if (width > 1 && height > 1) {
      params.clip = { x: 0, y: 0, width, height, scale: 1 };
    }
  } catch {}
  const response = await session.send("Page.captureScreenshot", params, 30000);
  await fs.writeFile(outputPath, Buffer.from(response.data, "base64"));
}

async function runOneShot(options) {
  const connected = await connectWorkBuddyTargets(options.port, options.timeoutMs);
  const loaded = options.mode === "once" || options.reload ? await loadPayload(options.themeDir) : null;
  const results = [];
  let screenshotCaptured = false;
  for (const { target, session, probe } of connected) {
    try {
      if (options.mode === "remove") await removeFromSession(session);
      else if (options.mode === "once") await session.evaluate(loaded.payload);
      if (options.reload) {
        await session.send("Page.reload", { ignoreCache: true });
        await new Promise((resolve) => setTimeout(resolve, 1600));
        if (options.mode !== "remove") await session.evaluate(loaded.payload);
      }
      const auditSpec = AUDIT_MODES[options.mode];
      const result = auditSpec ? await auditSpec.run(session, options)
        : options.mode === "probe" ? probe
        : options.mode === "remove" ? await session.evaluate("!document.documentElement.classList.contains('workbuddy-dream-skin')")
          : await waitForVerifiedSession(session, options.timeoutMs);
      results.push({ targetId: target.id, title: target.title, url: target.url, probe, result });
      if (options.screenshot && !screenshotCaptured) {
        await capture(session, options.screenshot);
        screenshotCaptured = true;
      }
      if (auditSpec?.resetPointer) {
        await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1, y: 1 });
      }
    } finally {
      session.close();
    }
  }
  console.log(JSON.stringify({ mode: options.mode, version: SKIN_VERSION, port: options.port, targets: results }, null, 2));
  const anyFailed = results.some((item) => isRunResultFailed(options.mode, item.result));
  const exitCode = NON_AUDIT_EXIT_CODES[options.mode] ?? AUDIT_MODES[options.mode]?.exitCode;
  if (anyFailed && exitCode) process.exitCode = exitCode;
}

async function runWatch(options) {
  const { payload } = await loadPayload(options.themeDir);
  const sessions = new Map();
  let stopping = false;
  const stop = () => { stopping = true; };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
  while (!stopping) {
    let targets = [];
    try {
      targets = await listCandidateTargets(options.port);
    } catch (error) {
      console.error(`[workbuddy-skin] ${new Date().toISOString()} ${error.message}`);
      await new Promise((resolve) => setTimeout(resolve, 1000));
      continue;
    }
    const activeIds = new Set(targets.map((target) => target.id));
    for (const [id, session] of sessions) {
      if (!activeIds.has(id) || session.closed) {
        session.close();
        sessions.delete(id);
      }
    }
    for (const target of targets) {
      if (sessions.has(target.id)) continue;
      let session;
      try {
        session = await new CdpSession(target, options.port).open();
        const probe = await probeSession(session);
        if (!probe?.workbuddy) {
          session.close();
          continue;
        }
        session.on("Page.loadEventFired", () => {
          setTimeout(() => session.evaluate(payload).catch((error) => console.error(`[workbuddy-skin] reinject failed: ${error.message}`)), 250);
        });
        await session.evaluate(payload);
        sessions.set(target.id, session);
        console.log(`[workbuddy-skin] injected WorkBuddy target ${target.id} (${target.title || target.url})`);
      } catch (error) {
        session?.close();
        console.error(`[workbuddy-skin] target ${target.id} rejected: ${error.message}`);
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 900));
  }
  for (const session of sessions.values()) session.close();
}

try {
  const options = parseArgs(process.argv.slice(2));
  if (options.mode === "check") {
    const loaded = await loadPayload(options.themeDir);
    console.log(JSON.stringify({ pass: true, version: SKIN_VERSION, themeId: loaded.theme.id, themeName: loaded.theme.name, imageBytes: loaded.imageBytes, payloadBytes: Buffer.byteLength(loaded.payload) }, null, 2));
  } else if (options.mode === "watch") await runWatch(options);
  else await runOneShot(options);
} catch (error) {
  console.error(`[workbuddy-skin] ${error.stack || error.message}`);
  process.exitCode = 1;
}
