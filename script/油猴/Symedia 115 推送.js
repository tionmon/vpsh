// ==UserScript==
// @name         Magnet/ED2K 一键推送 115 & Symedia
// @version      1.1.0
// @description  自动检测网页中的 magnet 和 ed2k 链接，一键推送到 115 网盘离线下载或 Symedia
// @author       Antigravity
// @match        *://*/*
// @grant        GM_xmlhttpRequest
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_registerMenuCommand
// @grant        GM_addStyle
// @connect      115.com
// @connect      *
// @run-at       document-idle
// @license      MIT
// ==/UserScript==

(function () {
  "use strict";

  // ═══════════════════════════════════════════════════════════════
  //  CONFIG
  // ═══════════════════════════════════════════════════════════════
  const STORAGE_KEYS = {
    COOKIE_115: "mp_115_cookie",
    CID_115: "mp_115_cid",
    SYMEDIA_URL: "mp_symedia_url",
    SYMEDIA_TOKEN: "mp_symedia_token",
    SYMEDIA_API_PATH: "mp_symedia_api_path",
    ENABLE_115: "mp_enable_115",
    ENABLE_SYMEDIA: "mp_enable_symedia",
  };

  const API = {
    LIXIAN_ADD: "https://115.com/web/lixian/?ct=lixian&ac=add_task_url",
    SYMEDIA_DEFAULT_PATH: "/api/v1/plugin/cloud_helper/add_offline_urls_115",
  };

  const MARKER_ATTR = "data-mp-injected";

  // ═══════════════════════════════════════════════════════════════
  //  STYLES
  // ═══════════════════════════════════════════════════════════════
  GM_addStyle(`
        /* ── Push Buttons ───────────────────────────────────────── */
        .mp-btn-group {
            display: inline-flex;
            gap: 4px;
            margin-left: 6px;
            vertical-align: middle;
            flex-shrink: 0;
        }
        .mp-btn {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 10px;
            border: none;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            white-space: nowrap;
            transition: all 0.2s ease;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.4;
            user-select: none;
        }
        .mp-btn:active { transform: scale(0.95); }

        .mp-btn-115 {
            background: linear-gradient(135deg, #2a7fff 0%, #1565c0 100%);
            color: #fff;
            box-shadow: 0 2px 6px rgba(42,127,255,0.3);
        }
        .mp-btn-115:hover {
            box-shadow: 0 4px 12px rgba(42,127,255,0.45);
            transform: translateY(-1px);
        }
        .mp-btn-symedia {
            background: linear-gradient(135deg, #7c4dff 0%, #651fff 100%);
            color: #fff;
            box-shadow: 0 2px 6px rgba(124,77,255,0.3);
        }
        .mp-btn-symedia:hover {
            box-shadow: 0 4px 12px rgba(124,77,255,0.45);
            transform: translateY(-1px);
        }

        .mp-btn.loading {
            opacity: 0.7;
            pointer-events: none;
        }
        .mp-btn.success {
            background: linear-gradient(135deg, #4caf50 0%, #2e7d32 100%) !important;
            box-shadow: 0 2px 6px rgba(76,175,80,0.4) !important;
        }
        .mp-btn.fail {
            background: linear-gradient(135deg, #f44336 0%, #c62828 100%) !important;
            box-shadow: 0 2px 6px rgba(244,67,54,0.4) !important;
        }

        /* ── Toast ──────────────────────────────────────────────── */
        #mp-toast-container {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 2147483647;
            display: flex;
            flex-direction: column;
            gap: 8px;
            pointer-events: none;
        }
        .mp-toast {
            padding: 12px 20px;
            border-radius: 10px;
            font-size: 13px;
            font-weight: 500;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            color: #fff;
            backdrop-filter: blur(20px) saturate(180%);
            -webkit-backdrop-filter: blur(20px) saturate(180%);
            box-shadow: 0 8px 32px rgba(0,0,0,0.18);
            animation: mp-toast-in 0.35s cubic-bezier(0.16,1,0.3,1);
            max-width: 380px;
            word-break: break-all;
            pointer-events: auto;
            line-height: 1.5;
        }
        .mp-toast.success { background: rgba(46,125,50,0.92); }
        .mp-toast.error   { background: rgba(198,40,40,0.92); }
        .mp-toast.info    { background: rgba(21,101,192,0.92); }
        .mp-toast.warning { background: rgba(245,124,0,0.92); }

        .mp-toast-out {
            animation: mp-toast-out 0.3s ease forwards;
        }

        @keyframes mp-toast-in {
            from { opacity: 0; transform: translateX(40px) scale(0.96); }
            to   { opacity: 1; transform: translateX(0) scale(1); }
        }
        @keyframes mp-toast-out {
            from { opacity: 1; transform: translateX(0); }
            to   { opacity: 0; transform: translateX(40px); }
        }

        /* ── Settings Modal ─────────────────────────────────────── */
        .mp-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.35);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            z-index: 2147483646;
            display: flex;
            justify-content: center;
            align-items: center;
            animation: mp-overlay-in 0.25s ease;
        }
        @keyframes mp-overlay-in {
            from { opacity: 0; }
            to   { opacity: 1; }
        }
        .mp-modal {
            background: rgba(255,255,255,0.82);
            backdrop-filter: blur(40px) saturate(200%);
            -webkit-backdrop-filter: blur(40px) saturate(200%);
            border-radius: 20px;
            width: 440px;
            max-width: 92vw;
            max-height: 85vh;
            overflow-y: auto;
            box-shadow: 0 24px 80px rgba(0,0,0,0.12),
                        0 8px 32px rgba(0,0,0,0.08),
                        inset 0 1px 0 rgba(255,255,255,0.7);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            animation: mp-modal-in 0.35s cubic-bezier(0.16,1,0.3,1);
            border: 1px solid rgba(255,255,255,0.6);
        }
        @keyframes mp-modal-in {
            from { opacity: 0; transform: scale(0.95) translateY(10px); }
            to   { opacity: 1; transform: scale(1) translateY(0); }
        }
        .mp-modal-header {
            display: flex; justify-content: space-between; align-items: center;
            padding: 24px 28px 14px;
            border-bottom: 1px solid rgba(0,0,0,0.06);
        }
        .mp-modal-header h3 {
            margin: 0; font-size: 17px; font-weight: 700; color: #1a1a2e;
            letter-spacing: -0.3px;
        }
        .mp-modal-close {
            width: 28px; height: 28px; border-radius: 50%; border: none;
            background: rgba(0,0,0,0.06); color: #888; font-size: 16px;
            cursor: pointer; display: flex; align-items: center; justify-content: center;
            transition: all 0.2s;
        }
        .mp-modal-close:hover { background: rgba(0,0,0,0.12); color: #333; }
        .mp-modal-body { padding: 20px 28px 10px; }
        .mp-modal-footer {
            display: flex; justify-content: flex-end; gap: 10px;
            padding: 14px 28px 24px;
            border-top: 1px solid rgba(0,0,0,0.06);
        }

        .mp-section { margin-bottom: 22px; }
        .mp-section-title {
            font-size: 14px; font-weight: 700; color: #333;
            margin: 0 0 12px; display: flex; align-items: center; gap: 6px;
        }
        .mp-label {
            display: block; margin-bottom: 5px; color: #555;
            font-weight: 600; font-size: 12px;
        }
        .mp-input {
            width: 100%; padding: 9px 12px; border: 1px solid rgba(0,0,0,0.12);
            border-radius: 8px; font-size: 13px; background: rgba(255,255,255,0.6);
            transition: border-color 0.2s; box-sizing: border-box;
            font-family: inherit;
        }
        .mp-input:focus {
            outline: none; border-color: #2a7fff;
            box-shadow: 0 0 0 3px rgba(42,127,255,0.12);
        }
        .mp-input-group { margin-bottom: 12px; }
        .mp-hint {
            font-size: 11px; color: #888; margin-top: 4px; line-height: 1.5;
        }
        .mp-toggle-row {
            display: flex; align-items: center; gap: 8px;
            margin-bottom: 10px;
        }
        .mp-toggle-row label {
            font-size: 13px; font-weight: 600; color: #444; cursor: pointer;
        }
        .mp-checkbox {
            width: 18px; height: 18px; cursor: pointer; accent-color: #2a7fff;
        }
        .mp-btn-modal {
            padding: 9px 22px; border-radius: 10px; font-size: 13px;
            font-weight: 600; cursor: pointer; transition: all 0.2s;
            border: none;
        }
        .mp-btn-cancel {
            background: rgba(0,0,0,0.06); color: #666;
        }
        .mp-btn-cancel:hover { background: rgba(0,0,0,0.1); }
        .mp-btn-save {
            background: linear-gradient(135deg, #2a7fff, #1565c0);
            color: #fff; box-shadow: 0 4px 14px rgba(42,127,255,0.25);
        }
        .mp-btn-save:hover {
            box-shadow: 0 6px 20px rgba(42,127,255,0.35);
            transform: translateY(-1px);
        }

        .mp-divider {
            height: 1px; background: rgba(0,0,0,0.06);
            margin: 18px 0;
        }
    `);

  // ═══════════════════════════════════════════════════════════════
  //  TOAST
  // ═══════════════════════════════════════════════════════════════
  const Toast = {
    _container: null,

    _ensureContainer() {
      if (!this._container || !document.body.contains(this._container)) {
        this._container = document.createElement("div");
        this._container.id = "mp-toast-container";
        document.body.appendChild(this._container);
      }
    },

    show(msg, type = "info", duration = 3500) {
      this._ensureContainer();
      const el = document.createElement("div");
      el.className = `mp-toast ${type}`;
      el.textContent = msg;
      this._container.appendChild(el);
      setTimeout(() => {
        el.classList.add("mp-toast-out");
        el.addEventListener("animationend", () => el.remove());
      }, duration);
    },

    success(msg) {
      this.show(msg, "success");
    },
    error(msg) {
      this.show(msg, "error", 5000);
    },
    info(msg) {
      this.show(msg, "info");
    },
    warning(msg) {
      this.show(msg, "warning", 4000);
    },
  };

  // ═══════════════════════════════════════════════════════════════
  //  PUSH TO 115
  // ═══════════════════════════════════════════════════════════════
  const Push115 = {
    push(link) {
      const cookie = GM_getValue(STORAGE_KEYS.COOKIE_115, "");
      const cid = GM_getValue(STORAGE_KEYS.CID_115, "0") || "0";

      if (!cookie) {
        Toast.warning("请先在设置中配置 115 Cookie");
        return Promise.resolve({
          success: false,
          message: "未配置 115 Cookie",
        });
      }

      return new Promise((resolve) => {
        const postData = new URLSearchParams({
          url: link,
          wp_path_id: cid,
        });

        GM_xmlhttpRequest({
          method: "POST",
          url: API.LIXIAN_ADD,
          headers: {
            Cookie: cookie,
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          },
          data: postData.toString(),
          onload(response) {
            try {
              const r = JSON.parse(response.responseText);
              if (r.state) {
                resolve({
                  success: true,
                  message: `✅ 115离线任务已添加：${r.name || ""}`,
                });
              } else if (r.errcode === 911) {
                resolve({
                  success: false,
                  message: "❌ 115 Cookie 已失效，请重新设置",
                });
              } else if (r.errcode === 10004) {
                resolve({ success: false, message: "⚠️ 该任务已存在" });
              } else {
                resolve({
                  success: false,
                  message: `❌ 添加失败: ${r.error_msg || r.error || "未知错误"}`,
                });
              }
            } catch (e) {
              resolve({ success: false, message: `❌ 解析异常: ${e.message}` });
            }
          },
          onerror(err) {
            resolve({ success: false, message: "❌ 115 接口调用失败" });
          },
        });
      });
    },
  };

  // ═══════════════════════════════════════════════════════════════
  //  PUSH TO SYMEDIA
  // ═══════════════════════════════════════════════════════════════
  const PushSymedia = {
    push(link) {
      const symediaUrl = GM_getValue(STORAGE_KEYS.SYMEDIA_URL, "");
      const symediaToken = GM_getValue(STORAGE_KEYS.SYMEDIA_TOKEN, "symedia");
      const apiPath = GM_getValue(
        STORAGE_KEYS.SYMEDIA_API_PATH,
        API.SYMEDIA_DEFAULT_PATH,
      );

      if (!symediaUrl) {
        Toast.warning("请先在设置中配置 Symedia 地址");
        return Promise.resolve({
          success: false,
          message: "未配置 Symedia 地址",
        });
      }

      const normalizedUrl = symediaUrl.replace(/\/+$/, "");
      const fullApiUrl = `${normalizedUrl}${apiPath}?token=${symediaToken}`;

      console.log("[MagnetPush] Symedia API URL:", fullApiUrl);
      console.log("[MagnetPush] Pushing link:", link);

      return new Promise((resolve) => {
        const postData = JSON.stringify({
          urls: [link],
          parent_id: GM_getValue(STORAGE_KEYS.CID_115, "0") || "0",
        });

        GM_xmlhttpRequest({
          method: "POST",
          url: fullApiUrl,
          headers: {
            "Content-Type": "application/json",
          },
          data: postData,
          onload(response) {
            console.log(
              "[MagnetPush] Symedia response:",
              response.status,
              response.responseText,
            );
            try {
              const r = JSON.parse(response.responseText);
              if (response.status === 200 && r.success === true) {
                if (r.message && r.message.includes("失败")) {
                  resolve({
                    success: false,
                    message: `❌ Symedia: ${r.message}`,
                  });
                } else {
                  resolve({
                    success: true,
                    message: `✅ Symedia: ${r.message || "推送成功"}`,
                  });
                }
              } else if (response.status === 404) {
                resolve({
                  success: false,
                  message: `❌ Symedia API 路径不存在 (404)，请在设置中检查 API 路径`,
                });
              } else {
                resolve({
                  success: false,
                  message: `❌ Symedia [${response.status}]: ${r.message || r.detail || r.error || JSON.stringify(r).slice(0, 100)}`,
                });
              }
            } catch (e) {
              resolve({
                success: false,
                message: `❌ Symedia [${response.status}]: ${response.responseText?.slice(0, 120) || e.message}`,
              });
            }
          },
          onerror(err) {
            resolve({
              success: false,
              message: `❌ Symedia 接口调用失败 (${err.status || "网络错误"})`,
            });
          },
        });
      });
    },
  };

  // ═══════════════════════════════════════════════════════════════
  //  SETTINGS UI
  // ═══════════════════════════════════════════════════════════════
  const Settings = {
    open() {
      if (document.querySelector(".mp-overlay")) return;

      const enable115 = GM_getValue(STORAGE_KEYS.ENABLE_115, true);
      const enableSymedia = GM_getValue(STORAGE_KEYS.ENABLE_SYMEDIA, true);
      const cookie115 = GM_getValue(STORAGE_KEYS.COOKIE_115, "");
      const cid115 = GM_getValue(STORAGE_KEYS.CID_115, "0");
      const symediaUrl = GM_getValue(STORAGE_KEYS.SYMEDIA_URL, "");
      const symediaToken = GM_getValue(STORAGE_KEYS.SYMEDIA_TOKEN, "symedia");
      const symediaApiPath = GM_getValue(
        STORAGE_KEYS.SYMEDIA_API_PATH,
        API.SYMEDIA_DEFAULT_PATH,
      );

      const overlay = document.createElement("div");
      overlay.className = "mp-overlay";

      overlay.innerHTML = `
            <div class="mp-modal">
                <div class="mp-modal-header">
                    <h3>🧲 Magnet/ED2K 推送设置</h3>
                    <button class="mp-modal-close" id="mp-close">×</button>
                </div>
                <div class="mp-modal-body">

                    <!-- 115 Section -->
                    <div class="mp-section">
                        <div class="mp-section-title">📦 115 网盘离线下载</div>
                        <div class="mp-toggle-row">
                            <input type="checkbox" class="mp-checkbox" id="mp-enable-115" ${enable115 ? "checked" : ""}>
                            <label for="mp-enable-115">启用推送到 115</label>
                        </div>
                        <div class="mp-input-group">
                            <label class="mp-label">Cookie:</label>
                            <input type="password" class="mp-input" id="mp-cookie" value="${Settings._esc(cookie115)}" placeholder="UID=xxx;CID=xxx;SEID=xxx;...">
                            <div class="mp-hint">从浏览器访问 115.com 后复制 Cookie</div>
                        </div>
                        <div class="mp-input-group">
                            <label class="mp-label">目标文件夹 CID:</label>
                            <input type="text" class="mp-input" id="mp-cid" value="${Settings._esc(cid115)}" placeholder="0 = 根目录">
                            <div class="mp-hint">0 为根目录，可在 115 网盘中查看文件夹 URL 获取 CID</div>
                        </div>
                    </div>

                    <div class="mp-divider"></div>

                    <!-- Symedia Section -->
                    <div class="mp-section">
                        <div class="mp-section-title">🔗 Symedia 推送</div>
                        <div class="mp-toggle-row">
                            <input type="checkbox" class="mp-checkbox" id="mp-enable-symedia" ${enableSymedia ? "checked" : ""}>
                            <label for="mp-enable-symedia">启用推送到 Symedia</label>
                        </div>
                        <div class="mp-input-group">
                            <label class="mp-label">Symedia 地址:</label>
                            <input type="text" class="mp-input" id="mp-symedia-url" value="${Settings._esc(symediaUrl)}" placeholder="http://127.0.0.1:8095">
                        </div>
                        <div class="mp-input-group">
                            <label class="mp-label">Token:</label>
                            <input type="text" class="mp-input" id="mp-symedia-token" value="${Settings._esc(symediaToken)}" placeholder="默认: symedia">
                        </div>
                        <div class="mp-input-group">
                            <label class="mp-label">API 路径:</label>
                            <input type="text" class="mp-input" id="mp-symedia-api-path" value="${Settings._esc(symediaApiPath)}" placeholder="${API.SYMEDIA_DEFAULT_PATH}">
                            <div class="mp-hint">离线下载(magnet/ed2k): add_offline_urls_115<br>分享链接转存: add_share_urls_115</div>
                        </div>
                    </div>

                </div>
                <div class="mp-modal-footer">
                    <button class="mp-btn-modal mp-btn-cancel" id="mp-cancel">取消</button>
                    <button class="mp-btn-modal mp-btn-save" id="mp-save">保存设置</button>
                </div>
            </div>`;

      document.body.appendChild(overlay);

      // Close
      const close = () => {
        overlay.style.animation = "mp-toast-out 0.2s ease forwards";
        setTimeout(() => overlay.remove(), 200);
      };
      overlay.querySelector("#mp-close").onclick = close;
      overlay.querySelector("#mp-cancel").onclick = close;
      overlay.addEventListener("click", (e) => {
        if (e.target === overlay) close();
      });

      // Save
      overlay.querySelector("#mp-save").onclick = () => {
        GM_setValue(
          STORAGE_KEYS.ENABLE_115,
          overlay.querySelector("#mp-enable-115").checked,
        );
        GM_setValue(
          STORAGE_KEYS.ENABLE_SYMEDIA,
          overlay.querySelector("#mp-enable-symedia").checked,
        );
        GM_setValue(
          STORAGE_KEYS.COOKIE_115,
          overlay.querySelector("#mp-cookie").value.trim(),
        );
        GM_setValue(
          STORAGE_KEYS.CID_115,
          overlay.querySelector("#mp-cid").value.trim() || "0",
        );
        GM_setValue(
          STORAGE_KEYS.SYMEDIA_URL,
          overlay.querySelector("#mp-symedia-url").value.trim(),
        );
        GM_setValue(
          STORAGE_KEYS.SYMEDIA_TOKEN,
          overlay.querySelector("#mp-symedia-token").value.trim() || "symedia",
        );
        GM_setValue(
          STORAGE_KEYS.SYMEDIA_API_PATH,
          overlay.querySelector("#mp-symedia-api-path").value.trim() ||
            API.SYMEDIA_DEFAULT_PATH,
        );
        Toast.success("✅ 设置已保存");
        close();
        // Re-scan to update button visibility
        ButtonInjector.scanAll();
      };
    },

    _esc(s) {
      return String(s)
        .replace(/&/g, "&amp;")
        .replace(/"/g, "&quot;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
    },
  };

  // ═══════════════════════════════════════════════════════════════
  //  BUTTON INJECTOR
  // ═══════════════════════════════════════════════════════════════
  const ButtonInjector = {
    /**
     * Check if a link is a magnet or ed2k link
     */
    _isTargetLink(href) {
      if (!href) return false;
      const h = href.trim().toLowerCase();
      return h.startsWith("magnet:") || h.startsWith("ed2k://");
    },

    /**
     * Truncate link for display on button tooltip
     */
    _truncate(s, n = 60) {
      return s.length > n ? s.slice(0, n) + "…" : s;
    },

    /**
     * Create push button
     */
    _createBtn(link, type) {
      const btn = document.createElement("button");
      const is115 = type === "115";
      btn.className = `mp-btn ${is115 ? "mp-btn-115" : "mp-btn-symedia"}`;
      btn.textContent = is115 ? "⬆ 115" : "⬆ Symedia";
      btn.title = `推送到 ${is115 ? "115网盘" : "Symedia"}:\n${this._truncate(link)}`;

      btn.addEventListener("click", async (e) => {
        e.preventDefault();
        e.stopPropagation();

        if (
          btn.classList.contains("loading") ||
          btn.classList.contains("success")
        )
          return;

        btn.classList.add("loading");
        const originalText = btn.textContent;
        btn.textContent = is115 ? "⏳ 115…" : "⏳ Sym…";

        const pushFn = is115 ? Push115 : PushSymedia;
        const result = await pushFn.push(link);

        btn.classList.remove("loading");

        if (result.success) {
          btn.classList.add("success");
          btn.textContent = "✓ 完成";
          Toast.success(result.message);
        } else {
          btn.classList.add("fail");
          btn.textContent = "✗ 失败";
          Toast.error(result.message);
          // Allow retry after 3 seconds
          setTimeout(() => {
            btn.classList.remove("fail");
            btn.textContent = originalText;
          }, 3000);
        }
      });

      return btn;
    },

    /**
     * Inject buttons next to a single <a> element
     */
    _injectForLink(anchor) {
      if (anchor.hasAttribute(MARKER_ATTR)) return;
      anchor.setAttribute(MARKER_ATTR, "1");

      const href = anchor.href || anchor.getAttribute("href") || "";
      if (!this._isTargetLink(href)) return;

      const enable115 = GM_getValue(STORAGE_KEYS.ENABLE_115, true);
      const enableSymedia = GM_getValue(STORAGE_KEYS.ENABLE_SYMEDIA, true);

      if (!enable115 && !enableSymedia) return;

      const group = document.createElement("span");
      group.className = "mp-btn-group";

      if (enable115) group.appendChild(this._createBtn(href, "115"));
      if (enableSymedia) group.appendChild(this._createBtn(href, "symedia"));

      // Insert after the anchor
      if (anchor.nextSibling) {
        anchor.parentNode.insertBefore(group, anchor.nextSibling);
      } else {
        anchor.parentNode.appendChild(group);
      }
    },

    /**
     * Scan entire page for magnet/ed2k links and inject buttons
     */
    scanAll() {
      const anchors = document.querySelectorAll("a[href]");
      let count = 0;
      anchors.forEach((a) => {
        if (this._isTargetLink(a.href)) {
          this._injectForLink(a);
          count++;
        }
      });

      // Also scan text nodes for bare magnet/ed2k links not wrapped in <a>
      this._scanTextNodes(document.body);

      return count;
    },

    /**
     * Scan text nodes for bare magnet: or ed2k:// URLs
     * and wrap them in clickable links with push buttons
     */
    _scanTextNodes(root) {
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
        acceptNode(node) {
          // Skip script, style, textarea, input, and already processed
          const tag = node.parentElement?.tagName;
          if (!tag) return NodeFilter.FILTER_REJECT;
          if (
            ["SCRIPT", "STYLE", "TEXTAREA", "INPUT", "NOSCRIPT"].includes(tag)
          ) {
            return NodeFilter.FILTER_REJECT;
          }
          if (node.parentElement.closest("[" + MARKER_ATTR + "]")) {
            return NodeFilter.FILTER_REJECT;
          }
          const text = node.textContent;
          if (/(magnet:\?[^\s]+|ed2k:\/\/[^\s]+)/i.test(text)) {
            return NodeFilter.FILTER_ACCEPT;
          }
          return NodeFilter.FILTER_REJECT;
        },
      });

      const textNodes = [];
      while (walker.nextNode()) textNodes.push(walker.currentNode);

      textNodes.forEach((textNode) => {
        const text = textNode.textContent;
        const regex = /(magnet:\?[^\s<>"']+|ed2k:\/\/[^\s<>"']+)/gi;
        const parts = text.split(regex);
        if (parts.length <= 1) return;

        const frag = document.createDocumentFragment();
        const matches = text.match(regex) || [];
        let matchIdx = 0;

        parts.forEach((part, i) => {
          if (i > 0 && matchIdx < matches.length) {
            const link = matches[matchIdx++];
            const a = document.createElement("a");
            a.href = link;
            a.textContent = link.length > 80 ? link.slice(0, 80) + "…" : link;
            a.style.cssText = "word-break:break-all;color:inherit;";
            a.setAttribute(MARKER_ATTR, "1");
            frag.appendChild(a);

            // Add buttons
            const enable115 = GM_getValue(STORAGE_KEYS.ENABLE_115, true);
            const enableSymedia = GM_getValue(
              STORAGE_KEYS.ENABLE_SYMEDIA,
              true,
            );
            if (enable115 || enableSymedia) {
              const group = document.createElement("span");
              group.className = "mp-btn-group";
              if (enable115) group.appendChild(this._createBtn(link, "115"));
              if (enableSymedia)
                group.appendChild(this._createBtn(link, "symedia"));
              frag.appendChild(group);
            }
          }
          if (part) frag.appendChild(document.createTextNode(part));
        });

        textNode.parentNode.replaceChild(frag, textNode);
      });
    },

    /**
     * Process newly added DOM nodes (from MutationObserver)
     */
    processNodes(nodes) {
      nodes.forEach((node) => {
        if (node.nodeType !== Node.ELEMENT_NODE) return;
        // Check the node itself
        if (node.tagName === "A" && this._isTargetLink(node.href)) {
          this._injectForLink(node);
        }
        // Check descendants
        const anchors = node.querySelectorAll?.("a[href]") || [];
        anchors.forEach((a) => {
          if (this._isTargetLink(a.href)) {
            this._injectForLink(a);
          }
        });
        // Scan text nodes in new content
        if (node.querySelector || node.childNodes?.length) {
          this._scanTextNodes(node);
        }
      });
    },
  };

  // ═══════════════════════════════════════════════════════════════
  //  MUTATION OBSERVER
  // ═══════════════════════════════════════════════════════════════
  function startObserver() {
    const observer = new MutationObserver((mutations) => {
      const addedNodes = [];
      mutations.forEach((m) => {
        m.addedNodes.forEach((n) => addedNodes.push(n));
      });
      if (addedNodes.length > 0) {
        // Debounce: batch process with requestAnimationFrame
        requestAnimationFrame(() => ButtonInjector.processNodes(addedNodes));
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════
  function init() {
    // Skip if running inside an iframe to avoid duplicates
    if (window.self !== window.top) return;

    // Register menu command
    GM_registerMenuCommand("⚙️ 推送设置", () => Settings.open());

    // Initial scan
    const count = ButtonInjector.scanAll();
    if (count > 0) {
      Toast.info(`🧲 检测到 ${count} 个 magnet/ed2k 链接`);
    }

    // Watch for dynamically loaded content
    startObserver();
  }

  // Wait for DOM ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
