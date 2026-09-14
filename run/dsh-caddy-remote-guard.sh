#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Install/update a tiny local DSH profile bundle that keeps remote Settings
# available while suppressing the Host-native "Open configuration file"
# affordance. Loopback browsers are left untouched.

DSH_USER="${DSH_USER:-dsh}"
DSH_HOME="${DSH_HOME:-/var/lib/dsh}"
DSH_PROFILE="${DSH_PROFILE:-web}"
DSH_BIN="${DSH_BIN:-$(command -v dsh || true)}"
DSH_PORT="${DSH_PORT:-3080}"
GUARD_NAME="dsh-caddy-remote-guard"
GUARD_DIR="${DSH_REMOTE_GUARD_DIR:-${DSH_HOME}/local-plugins/${GUARD_NAME}}"
PATH_DSH="${PATH_DSH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[i]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'die "脚本在第 ${LINENO} 行失败。请查看上方错误信息。"' ERR

[[ "$EUID" -eq 0 ]] || die "请使用 root 运行。"
[[ -n "$DSH_BIN" && -x "$DSH_BIN" ]] || die "找不到 dsh 命令。"
id "$DSH_USER" >/dev/null 2>&1 || die "DSH 用户不存在：$DSH_USER"
command -v systemctl >/dev/null 2>&1 || die "需要 systemd。"

run_as_dsh() {
  runuser -u "$DSH_USER" -- env \
    HOME="$DSH_HOME" \
    DSH_HOME="$DSH_HOME" \
    PATH="$PATH_DSH" \
    "$@"
}

log "生成本地远程 UI guard 插件..."
install -d -m 0750 -o "$DSH_USER" -g "$DSH_USER" "$GUARD_DIR/lib"

cat > "$GUARD_DIR/package.json" <<'EOF_PACKAGE'
{
  "name": "dsh-caddy-remote-guard",
  "version": "1.0.0",
  "description": "Keep DSH remote settings while hiding Host-native document open capability from remote browsers.",
  "type": "module",
  "main": "lib/index.js",
  "exports": {
    ".": "./lib/index.js",
    "./package.json": "./package.json"
  },
  "files": [
    "lib",
    "cordis.patch.yml"
  ],
  "engines": {
    "node": ">=20.0.0"
  },
  "dsh": {
    "bundle": {
      "patch": "./cordis.patch.yml"
    }
  }
}
EOF_PACKAGE

cat > "$GUARD_DIR/cordis.patch.yml" <<'EOF_PATCH'
# Managed by dsh-caddy-remote-guard.sh.
# This row only modifies the browser bootstrap. It does not change the DSH
# bind address, trusted hosts, settings data, or credential APIs.
- insert:
    - id: dsh-caddy-remote-guard
      name: 'dsh-caddy-remote-guard'
EOF_PATCH

cat > "$GUARD_DIR/lib/index.js" <<'EOF_JS'
/**
 * Browser-side guard for remote DSH deployments.
 *
 * dsh-web-lan-access intentionally declares ownsHost=true so authenticated
 * remote pages can use Host-backed Settings/Credentials. DSH also interprets
 * that as permission to render the Host-native "Open configuration file"
 * action. On a headless VPS that action can never open a desktop editor.
 *
 * This bootstrap wraps only the generic fetch transport. For a non-loopback
 * browser and only /api/settings/describe, it changes hasDocument to false.
 * All namespaces, writes, credentials, model catalog calls, and other RPCs
 * pass through unchanged. Loopback pages preserve stock behavior.
 */

const MARKER = '<!--dsh-caddy-remote-guard-->'

const BOOTSTRAP_SCRIPT = `<script>(function(){
  var g=globalThis;
  function isLoopback(){
    var h=(g.location&&g.location.hostname||'').toLowerCase();
    return h==='localhost'||h==='::1'||/^127\./.test(h)||h.endsWith('.localhost');
  }
  function wrap(t){
    if(!t||t.__dshCaddyRemoteGuard===true||typeof t.fetch!=='function')return t;
    var original=t.fetch;
    t.fetch=async function(input,init){
      var response=await original.call(t,input,init);
      if(isLoopback())return response;
      try{
        var raw=(typeof Request!=='undefined'&&input instanceof Request)?input.url:input;
        var url=new URL(raw,g.location&&g.location.href||'http://dsh.internal');
        if(url.pathname!=='/api/settings/describe')return response;
        var payload=await response.clone().json();
        if(payload&&payload.result&&payload.result.ok===true&&payload.result.value&&typeof payload.result.value==='object'){
          payload.result.value.hasDocument=false;
          var headers=new Headers(response.headers);
          headers.delete('content-length');
          headers.delete('content-encoding');
          return new Response(JSON.stringify(payload),{
            status:response.status,
            statusText:response.statusText,
            headers:headers
          });
        }
      }catch(error){
        console.warn('[dsh-caddy-remote-guard] settings describe filter failed',error);
      }
      return response;
    };
    try{Object.defineProperty(t,'__dshCaddyRemoteGuard',{value:true,configurable:true});}
    catch(_){t.__dshCaddyRemoteGuard=true;}
    return t;
  }
  if(g.__DSH_TRANSPORT__){
    wrap(g.__DSH_TRANSPORT__);
    return;
  }
  var pending;
  try{
    Object.defineProperty(g,'__DSH_TRANSPORT__',{
      configurable:true,
      get:function(){return pending;},
      set:function(next){
        pending=wrap(next);
        Object.defineProperty(g,'__DSH_TRANSPORT__',{
          configurable:true,
          writable:true,
          value:pending
        });
      }
    });
  }catch(error){
    console.warn('[dsh-caddy-remote-guard] transport hook install failed',error);
  }
})();</script>`

function injectGuard(html) {
  if (html.includes(MARKER)) return html
  const head = html.indexOf('<head>')
  if (head === -1) return html
  return html.slice(0, head + 6) + MARKER + BOOTSTRAP_SCRIPT + html.slice(head + 6)
}

export const inject = ['webServer']

function apply(ctx) {
  ctx.effect(
    () => ctx.webServer.tapIndex(injectGuard),
    'dsh-caddy: hide Host-native settings document action from remote browsers',
  )
}

export { apply, injectGuard }
EOF_JS

chown -R "$DSH_USER:$DSH_USER" "$GUARD_DIR"
chmod 0644 "$GUARD_DIR/package.json" "$GUARD_DIR/cordis.patch.yml" "$GUARD_DIR/lib/index.js"

log "安装/更新 DSH remote guard profile bundle..."
run_as_dsh "$DSH_BIN" plugin --profile "$DSH_PROFILE" remove "$GUARD_NAME" >/dev/null 2>&1 || true
run_as_dsh "$DSH_BIN" plugin --profile "$DSH_PROFILE" add "file:${GUARD_DIR}"

log "验证 profile 配置可以解析..."
run_as_dsh "$DSH_BIN" --profile "$DSH_PROFILE" --dump-config >/tmp/dsh-remote-guard-config.txt
if ! grep -q 'dsh-caddy-remote-guard' /tmp/dsh-remote-guard-config.txt; then
  rm -f /tmp/dsh-remote-guard-config.txt
  die "remote guard 未出现在 composed config 中。"
fi
rm -f /tmp/dsh-remote-guard-config.txt

log "重启 DSH..."
systemctl restart dsh.service

READY=0
for _ in $(seq 1 30); do
  PAGE="$(curl -fsS --connect-timeout 2 "http://127.0.0.1:${DSH_PORT}/" 2>/dev/null || true)"
  if printf '%s' "$PAGE" | grep -q 'dsh-caddy-remote-guard'; then
    READY=1
    break
  fi
  sleep 1
done

if [[ "$READY" -eq 1 ]]; then
  log "remote guard 已注入 WebUI。"
else
  info "首页可能受 DSH token/cookie 保护，改用安装文件与 composed config 完成验证。"
  grep -q 'dsh-caddy-remote-guard' "$GUARD_DIR/lib/index.js" || die "guard 文件验证失败。"
fi

printf '\n完成。远程浏览器将不再显示“打开配置文件”；loopback 浏览器保持原行为。\n'
printf 'Models / Provider / API Key 等远程 Settings 能力不受影响。\n'
