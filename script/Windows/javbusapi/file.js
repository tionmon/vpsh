// ==UserScript==
// @name         影巢 Emby&115 转存助手
// @version      1.5.1
// @description  影巢显示emby已入库以及未入库 支持主页,详情页,用户页面,合集页面，添加一键转存 115 按钮转存到 115 网盘，ui 可选文件夹 id  支持日志显示与日志推送 tgbot， 支持并适配移动端与pc端
// @author       楠
// @match        *://hdhive.com/*
// @match        *://www.hdhive.com/*
// @match        *://115.com/s/*
// @match        *://115cdn.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        window.close
// @grant        window.opener
// @license      MIT
// @icon         https://hdhive.com/apple-touch-icon.png
// @namespace    https://greasyfork.org/users/1514724
// @run-at       document-start
// @downloadURL https://update.greasyfork.org/scripts/552585/%E5%BD%B1%E5%B7%A2%20Emby115%20%E8%BD%AC%E5%AD%98%E5%8A%A9%E6%89%8B.user.js
// @updateURL https://update.greasyfork.org/scripts/552585/%E5%BD%B1%E5%B7%A2%20Emby115%20%E8%BD%AC%E5%AD%98%E5%8A%A9%E6%89%8B.meta.js
// ==/UserScript==

(function () {
    'use strict';

    const CONFIG = {
        targetDomain: 'hdhive.com',
        autoCloseDelay: 1500,
        maxWaitTime: 15000,
        api115: 'https://115cdn.com/webapi/share/receive',
        snap115: 'https://115cdn.com/webapi/share/snap',
        tgApi: 'https://api.telegram.org/bot{token}/sendMessage',
        symediaApiPath: '/api/v1/plugin/cloud_helper/add_share_urls_115'
    };

    let EMBY_CONFIG = {
        HOST: GM_getValue("embyHost", ""),
        API_KEY: GM_getValue("embyApiKey", "")
    };

    const state = {
        processingItems: new Set(),
        processedItems: new Set(),
        embyCache: new Map(),
        transferButtonsInitialized: false
    };

    const BUTTON_STYLES = {
        posterBtn: {
            size: '25px',
            position: { top: '10px', right: '10px' },
            has: {
                bg: 'linear-gradient(135deg, #4CAF50 0%, #2E7D32 100%)',
                icon: '✓',
                border: '2px solid rgba(255,255,255,0.8)'
            },
            notHas: {
                bg: 'linear-gradient(135deg, #F44336 0%, #C62828 100%)',
                icon: '✗',
                border: '2px solid rgba(255,255,255,0.8)'
            },
            hoverEffect: 'scale(1.1)'
        },
        nameBtn: {
            padding: '3px 10px',
            marginTop: '5px',
            fontSize: '11px',
            has: {
                bg: 'rgba(76, 175, 80, 0.15)',
                text: '已入库',
                textColor: '#4CAF50',
                border: '1px solid rgba(76, 175, 80, 0.3)'
            },
            notHas: {
                bg: 'rgba(244, 67, 54, 0.15)',
                text: '未入库',
                textColor: '#F44336',
                border: '1px solid rgba(244, 67, 54, 0.3)'
            },
            hoverEffect: 'translateY(-1px)'
        },
        detailBtn: {
            posterBtn: {
                size: '30px',
                position: { top: '15px', right: '15px' },
                has: {
                    bg: 'linear-gradient(135deg, #4CAF50 0%, #2E7D32 100%)',
                    icon: '✓',
                    border: '2px solid rgba(255,255,255,0.9)'
                },
                notHas: {
                    bg: 'linear-gradient(135deg, #F44336 0%, #C62828 100%)',
                    icon: '✗',
                    border: '2px solid rgba(255,255,255,0.9)'
                },
                hoverEffect: 'scale(1.15)'
            },
            titleBtn: {
                padding: '5px 15px',
                marginLeft: '10px',
                fontSize: '12px',
                has: {
                    bg: 'rgba(76, 175, 80, 0.15)',
                    text: '已入库',
                    textColor: '#4CAF50',
                    border: '1px solid rgba(76, 175, 80, 0.4)'
                },
                notHas: {
                    bg: 'rgba(244, 67, 54, 0.15)',
                    text: '未入库',
                    textColor: '#F44336',
                    border: '1px solid rgba(244, 67, 54, 0.4)'
                },
                hoverEffect: 'translateY(-1px)'
            }
        },
        searchYearBtn: {
            padding: '3px 10px',
            marginLeft: '10px',
            fontSize: '11px',
            has: {
                bg: 'rgba(76, 175, 80, 0.15)',
                text: '已入库',
                textColor: '#4CAF50',
                border: '1px solid rgba(76, 175, 80, 0.3)'
            },
            notHas: {
                bg: 'rgba(244, 67, 54, 0.15)',
                text: '未入库',
                textColor: '#F44336',
                border: '1px solid rgba(244, 67, 54, 0.3)'
            },
            hoverEffect: 'translateY(-1px)'
        },
        userPageBtn: {
            padding: '3px 10px',
            marginLeft: '8px',
            fontSize: '11px',
            has: {
                bg: 'rgba(76, 175, 80, 0.35)',
                text: '已入库',
                textColor: '#4CAF50',
                border: '1px solid rgba(76, 175, 80, 0.4)'
            },
            notHas: {
                bg: 'rgba(244, 67, 54, 0.35)',
                text: '未入库',
                textColor: '#F44336',
                border: '1px solid rgba(244, 67, 54, 0.4)'
            },
            hoverEffect: 'translateY(-1px)'
        },
        collectionBtn: {
            padding: '3px 10px',
            marginLeft: '10px',
            fontSize: '11px',
            has: {
                bg: 'rgba(76, 175, 80, 0.15)',
                text: '已入库',
                textColor: '#4CAF50',
                border: '1px solid rgba(76, 175, 80, 0.3)'
            },
            notHas: {
                bg: 'rgba(244, 67, 54, 0.15)',
                text: '未入库',
                textColor: '#F44336',
                border: '1px solid rgba(244, 67, 54, 0.3)'
            },
            hoverEffect: 'translateY(-1px)'
        },
        settingBtn: {
            padding: '6px 16px',
            marginRight: '10px',
            fontSize: '12px',
            has: {
                bg: 'rgba(100, 181, 246, 0.35)',
                text: '设置',
                textColor: '#64B5F6',
                border: '1px solid rgba(100, 181, 246, 0.4)'
            },
            hoverEffect: 'translateY(-1px)',
            iconSize: '16px'
        },
        transferBtn: {
            padding: '3px 10px',
            marginLeft: '4px',
            fontSize: '11px',
            bg: 'rgba(227, 242, 253, 1)',
            textColor: '#0d47a1',
            border: '1px solid rgba(13, 71, 161, 0.3)',
            hoverEffect: 'translateY(-1px)',
            iconSize: '16px'
        }
    };

    const Utils = {
        normalizeText: (t = '') => String(t).replace(/\s+/g, '').trim().toLowerCase(),

        isSafari: (() => {
            try {
                const ua = navigator.userAgent;
                return /Safari/.test(ua) && !/Chrome|Chromium|Edg|OPR|Android/.test(ua);
            } catch (e) {
                return false;
            }
        })(),

        isDetailPage: () => {
            const path = window.location.pathname;
            return /^\/(movie|tv)\/[\w-]+/.test(path);
        },

        isUserPage: () => window.location.pathname.startsWith('/user/'),

        isCollectionPage: () => window.location.pathname.startsWith('/collection/'),

        isResourcePage: () => location.href.includes('/resource/'),

        isFinal115Page: () => location.href.includes('115cdn.com') || location.href.includes('115.com/s/'),

        isParentPage: () => {
            const href = location.href;
            const isDetailPage =
                (href.includes('/movie/') && href.split('/movie/').length > 1) ||
                (href.includes('/tv/') && href.split('/tv/').length > 1);
            return href.includes(CONFIG.targetDomain) && isDetailPage && !href.includes('/resource/');
        },

        isHDHiveSite: () => {
            return location.hostname.includes('hdhive.com') &&
                !Utils.isResourcePage() &&
                !Utils.isFinal115Page();
        },

        verifyAndFormatUrl: (rawUrl) => {
            try {
                if (!rawUrl) return { success: false, msg: "链接为空" };
                const urlObj = new URL(rawUrl);
                if (!urlObj.hostname.includes('115')) return { success: false, msg: "非115域名" };

                const pickcode = urlObj.pathname.split('/').pop();
                if (!pickcode) return { success: false, msg: "无法提取Pickcode" };

                const search = urlObj.search;
                if (!search || !search.includes('=')) return { success: false, msg: "链接未包含密码(Key)" };

                const lastEqualIndex = rawUrl.lastIndexOf('=');
                let potentialPass = rawUrl.substring(lastEqualIndex + 1);

                if (potentialPass.length >= 4) {
                    var password = potentialPass.substring(0, 4);
                } else {
                    return { success: false, msg: "密码长度不足" };
                }

                return { success: true, url: `https://115.com/s/${pickcode}?password=${password}`, msg: "格式化成功" };
            } catch (e) { return { success: false, msg: `解析异常: ${e.message}` }; }
        },

        parseShareLink: (shareLink) => {
            const shareCodeMatch = shareLink.match(/\/s\/([^?]+)/);
            const passwordMatch = shareLink.match(/password=(\w{4})/);
            if (!shareCodeMatch || !passwordMatch) return { success: false };
            return {
                success: true,
                shareCode: shareCodeMatch[1],
                receiveCode: passwordMatch[1]
            };
        },

        humanReadable: (size) => {
            if (size < 1024) return `${size}B`;
            else if (size < 1024 ** 2) return `${(size / 1024).toFixed(2)}KB`;
            else if (size < 1024 ** 3) return `${(size / 1024 / 1024).toFixed(2)}MB`;
            else if (size < 1024 ** 4) return `${(size / 1024 / 1024 / 1024).toFixed(2)}GB`;
            else if (size < 1024 ** 5) return `${(size / 1024 / 1024 / 1024 / 1024).toFixed(2)}TB`;
            else return `${(size / 1024 / 1024 / 1024 / 1024 / 1024).toFixed(2)}PB`;
        },

        normalizeUrl: (url) => {
            if (!url) return '';
            return url.replace(/\/+$/, '');
        }
    };

    const Logger = {
        stats: { free: 0, paid: 0, unlocked: 0 },
        processedLinks: new Set(),
        currentTaskId: null,
        logPanel: null,
        logContent: null,

        init: () => {
            Logger.createLogPanel();
        },

        createLogPanel: () => {
            const logPanel = document.createElement('div');
            logPanel.id = 'hdhive-log-panel';
            Object.assign(logPanel.style, {
                position: 'fixed',
                bottom: '85px',
                right: '20px',
                width: '380px',
                height: '380px',
                backgroundColor: 'white',
                boxShadow: '0 4px 15px rgba(0,0,0,0.2)',
                borderRadius: '8px',
                zIndex: 99999,
                display: 'none',
                flexDirection: 'column',
                fontFamily: 'sans-serif',
                border: '1px solid #ddd',
                fontSize: '12px'
            });

            logPanel.innerHTML = `
                <div style="padding:10px;border-bottom:1px solid #eee;background:#f1f3f5;
                    border-radius:8px 8px 0 0;font-weight:bold;display:flex;justify-content:space-between;">
                    <span>🤖 115转存助手日志</span>
                    <span style="cursor:pointer;user-select:none;" onclick="document.getElementById('hdhive-log-panel').style.display='none';">⊖</span>
                </div>
                <div id="log-stats" style="padding:8px;border-bottom:1px solid #eee;display:flex;gap:10px;background:#fff;flex-wrap:wrap;">
                    <span id="stat-free" style="color:#2e7d32;display:none;">免费: 0</span>
                    <span id="stat-paid" style="color:#d32f2f;display:none;">付费: 0</span>
                    <span id="stat-unlocked" style="color:#1976d2;display:none;">已解锁: 0</span>
                </div>
                <div id="log-content" style="flex:1;overflow-y:auto;padding:10px;line-height:1.6;background:#fafafa;"></div>
            `;

            document.body.appendChild(logPanel);
            Logger.logPanel = logPanel;
            Logger.logContent = document.getElementById('log-content');
        },

        showLogPanel: () => {
            if (Logger.logPanel) {
                Logger.logPanel.style.display = 'flex';
            }
        },

        hideLogPanel: () => {
            if (Logger.logPanel) {
                Logger.logPanel.style.display = 'none';
            }
        },

        toggleLogPanel: () => {
            if (Logger.logPanel.style.display === 'flex') {
                Logger.hideLogPanel();
            } else {
                Logger.showLogPanel();
            }
        },

        startNewTask: (resourceUrl) => {
            const taskId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
            Logger.currentTaskId = taskId;
            TelegramPush.startTask(taskId, resourceUrl);
            return taskId;
        },

        endCurrentTask: (status = 'completed') => {
            if (Logger.currentTaskId) {
                TelegramPush.endTask(Logger.currentTaskId, status);
                Logger.currentTaskId = null;
            }
        },

        addLog: (msg, type = 'info', includeInTg = true) => {
            if (!Logger.logContent) return;

            const entry = document.createElement('div');
            entry.style.borderBottom = '1px dashed #eee';
            entry.style.padding = '2px 0';
            const time = new Date().toLocaleTimeString();
            let color = ({ error: '#d32f2f', success: '#2e7d32', process: '#0288d1' })[type] || '#333';

            const logText = `[${time}] ${msg.replace(/<[^>]*>/g, '')}`;
            entry.innerHTML = `<span style="color:#999">[${time}]</span> <span style="color:${color}">${msg}</span>`;
            Logger.logContent.appendChild(entry);
            Logger.logContent.scrollTop = Logger.logContent.scrollHeight;

            if (includeInTg && Logger.currentTaskId) {
                TelegramPush.addLogToTask(Logger.currentTaskId, logText);
            }
        },

        updateStats: (type) => {
            const statElement = document.getElementById(`stat-${type}`);
            if (Logger.stats[type] !== undefined && statElement) {
                Logger.stats[type]++;
                statElement.textContent = `${type === 'free' ? '免费' : (type === 'paid' ? '付费' : '已解锁')}: ${Logger.stats[type]}`;
                statElement.style.display = 'inline';
            }
        },

        isLinkProcessed: (link) => {
            return Logger.processedLinks.has(link);
        },

        markLinkAsProcessed: (link) => {
            Logger.processedLinks.add(link);
        }
    };

    const TelegramPush = {
        pendingTasks: new Map(),

        init: () => {
            TelegramPush.pendingTasks.clear();
        },

        startTask: (taskId, resourceUrl) => {
            TelegramPush.pendingTasks.set(taskId, {
                logs: [],
                startTime: new Date(),
                resourceUrl: resourceUrl,
                status: 'processing'
            });
        },

        addLogToTask: (taskId, logEntry) => {
            if (TelegramPush.pendingTasks.has(taskId)) {
                const task = TelegramPush.pendingTasks.get(taskId);
                task.logs.push(logEntry);

                if (task.status === 'completed' || task.status === 'failed') {
                    TelegramPush.processTask(taskId);
                }
            }
        },

        endTask: (taskId, status = 'completed') => {
            if (TelegramPush.pendingTasks.has(taskId)) {
                const task = TelegramPush.pendingTasks.get(taskId);
                task.status = status;
                task.endTime = new Date();

                TelegramPush.processTask(taskId);
            }
        },

        processTask: async (taskId) => {
            if (!TelegramPush.pendingTasks.has(taskId)) return;

            const task = TelegramPush.pendingTasks.get(taskId);

            const enableTgPush = GM_getValue('tg_enable_push', false);
            if (!enableTgPush) {
                TelegramPush.pendingTasks.delete(taskId);
                return;
            }

            if (task.logs.length === 0) return;

            let message = '';

            task.logs.forEach(log => {
                message += `${log}\n`;
            });

            await TelegramPush.sendToTelegram(message);

            TelegramPush.pendingTasks.delete(taskId);
        },

        sendToTelegram: async (message) => {
            const botToken = GM_getValue('tg_bot_token', '');
            const chatId = GM_getValue('tg_chat_id', '');
            const proxyUrl = GM_getValue('tg_proxy', '');

            if (!botToken || !chatId) {
                console.warn('Telegram推送配置不完整');
                return false;
            }

            const apiUrl = CONFIG.tgApi.replace('{token}', botToken);

            return new Promise((resolve) => {
                const params = {
                    chat_id: chatId,
                    text: message,
                    parse_mode: 'HTML',
                    disable_web_page_preview: true
                };

                const requestOptions = {
                    method: 'POST',
                    url: apiUrl,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    data: JSON.stringify(params),
                    onload: (response) => {
                        if (response.status === 200) {
                            console.log('Telegram推送成功');
                            resolve(true);
                        } else {
                            console.error('Telegram推送失败:', response.statusText);
                            resolve(false);
                        }
                    },
                    onerror: (error) => {
                        console.error('Telegram推送错误:', error);
                        resolve(false);
                    }
                };

                if (proxyUrl) {
                    requestOptions.proxy = proxyUrl;
                }

                GM_xmlhttpRequest(requestOptions);
            });
        },

        testPush: async () => {
            const testMessage = '🚀 HDHIVE 推送测试\n📅 ' + new Date().toLocaleString() + '\n✅ 这是一条测试消息，用于验证Telegram推送功能是否正常工作。';
            const result = await TelegramPush.sendToTelegram(testMessage);

            if (result) {
                Logger.addLog('✅ Telegram推送测试成功', 'success');
            } else {
                Logger.addLog('❌ Telegram推送测试失败，请检查配置', 'error');
            }

            return result;
        }
    };

    const Transfer115 = {
        transfer: async (shareLink, cookie, targetCid) => {
            const parseResult = Utils.parseShareLink(shareLink);
            if (!parseResult.success) {
                return {
                    success: false,
                    message: '❌ 无法解析分享链接或密码',
                    file_size: ''
                };
            }

            const { shareCode, receiveCode } = parseResult;

            return new Promise((resolve) => {
                const postData = new URLSearchParams({
                    share_code: shareCode,
                    receive_code: receiveCode,
                    cid: targetCid,
                    is_check: 0
                });

                GM_xmlhttpRequest({
                    method: "POST",
                    url: CONFIG.api115,
                    headers: {
                        "Cookie": cookie,
                        "Content-Type": "application/x-www-form-urlencoded"
                    },
                    data: postData.toString(),
                    onload: (response) => {
                        try {
                            const respJson = JSON.parse(response.responseText);

                            if (respJson.state === true) {
                                Transfer115.getFileSize(shareCode, receiveCode, cookie).then(fileSize => {
                                    resolve({
                                        success: true,
                                        message: `✅ 115转存成功[${fileSize}]`,
                                        file_size: fileSize
                                    });
                                }).catch(err => {
                                    resolve({
                                        success: true,
                                        message: '✅ 115转存成功[大小未知]',
                                        file_size: ''
                                    });
                                });
                            } else if (respJson.errno === 4100024) {
                                resolve({
                                    success: false,
                                    message: '⚠️ 转存失败：你已经转存过该文件',
                                    file_size: ''
                                });
                            } else if (respJson.errno === 4100008) {
                                resolve({
                                    success: false,
                                    message: '❌ 转存失败：分享链接密码错误',
                                    file_size: ''
                                });
                            } else if (respJson.errno === 4100010) {
                                resolve({
                                    success: false,
                                    message: '❌ 转存失败：分享已取消',
                                    file_size: ''
                                });
                            } else if (respJson.errno === 4100018) {
                                resolve({
                                    success: false,
                                    message: '❌ 转存失败：链接已过期',
                                    file_size: ''
                                });
                            } else {
                                resolve({
                                    success: false,
                                    message: `❌ 转存失败: ${respJson.error || '未知错误'}`,
                                    file_size: ''
                                });
                            }
                        } catch (e) {
                            resolve({
                                success: false,
                                message: `❌ 转存异常: ${e.message}`,
                                file_size: ''
                            });
                        }
                    },
                    onerror: (error) => {
                        resolve({
                            success: false,
                            message: '❌ 转存接口调用失败',
                            file_size: ''
                        });
                    }
                });
            });
        },

        getFileSize: async (shareCode, receiveCode, cookie) => {
            return new Promise((resolve, reject) => {
                const snapParams = {
                    "_v": 2,
                    "share_code": shareCode,
                    "receive_code": receiveCode,
                    "offset": 0,
                    "limit": 20,
                    "cid": ""
                };

                const queryString = new URLSearchParams(snapParams).toString();

                GM_xmlhttpRequest({
                    method: "GET",
                    url: `${CONFIG.snap115}?${queryString}`,
                    headers: {
                        "Cookie": cookie,
                        "Referer": "https://115.com/",
                        "Origin": "https://115.com",
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                    },
                    onload: (response) => {
                        try {
                            const fileInfoJson = JSON.parse(response.responseText);
                            if (fileInfoJson.state && fileInfoJson.data && fileInfoJson.data.list && fileInfoJson.data.list[0]) {
                                const fileSize = fileInfoJson.data.list[0].s || 0;
                                resolve(Utils.humanReadable(fileSize));
                            } else {
                                if (fileInfoJson.data && fileInfoJson.data[0]) {
                                    const fileSize = fileInfoJson.data[0].s || fileInfoJson.data[0].size || 0;
                                    resolve(Utils.humanReadable(fileSize));
                                } else {
                                    reject(new Error('无法获取文件大小'));
                                }
                            }
                        } catch (e) {
                            reject(e);
                        }
                    },
                    onerror: (error) => {
                        reject(error);
                    }
                });
            });
        },

        transferBySymedia: async (shareLink, symediaUrl, symediaToken, targetCid) => {
            if (!symediaUrl || !symediaToken) {
                return {
                    success: false,
                    message: '❌ Symedia配置不完整'
                };
            }

            const normalizedUrl = Utils.normalizeUrl(symediaUrl);
            const apiUrl = `${normalizedUrl}${CONFIG.symediaApiPath}?token=${symediaToken}`;

            return new Promise((resolve) => {
                const postData = JSON.stringify({
                    urls: [shareLink],
                    parent_id: targetCid ? String(targetCid) : '0'
                });

                GM_xmlhttpRequest({
                    method: "POST",
                    url: apiUrl,
                    headers: {
                        "Content-Type": "application/json"
                    },
                    data: postData,
                    onload: (response) => {
                        try {
                            const respJson = JSON.parse(response.responseText);
                            if (response.status === 200 && respJson.success === true) {
                                if (respJson.message && respJson.message.includes('转存失败')) {
                                    resolve({
                                        success: false,
                                        message: `❌ Symedia转存失败: ${respJson.message}`
                                    });
                                } else {
                                    resolve({
                                        success: true,
                                        message: `✅ Symedia转存: ${respJson.message}`
                                    });
                                }
                            } else {
                                resolve({
                                    success: false,
                                    message: `❌ Symedia转存失败: ${respJson.message || '未知错误'}`
                                });
                            }
                        } catch (e) {
                            resolve({
                                success: false,
                                message: `❌ Symedia转存异常: ${e.message}`
                            });
                        }
                    },
                    onerror: (error) => {
                        resolve({
                            success: false,
                            message: '❌ Symedia接口调用失败'
                        });
                    }
                });
            });
        }
    };

    const EmbyHelper = {
        checkEmbyResource: (name, year) => {
            return new Promise((resolve) => {
                const cacheKey = `${name}-${year}`;
                if (state.embyCache.has(cacheKey)) {
                    resolve(state.embyCache.get(cacheKey));
                    return;
                }
                const searchUrl = `${EMBY_CONFIG.HOST}/emby/Items?api_key=${EMBY_CONFIG.API_KEY}&SearchTerm=${encodeURIComponent(name)}&IncludeItemTypes=Movie,Series&Recursive=true&Fields=ProductionYear,OriginalTitle&Limit=20`;
                GM_xmlhttpRequest({
                    method: 'GET',
                    url: searchUrl,
                    onload: function (response) {
                        try {
                            const data = JSON.parse(response.responseText);
                            let hasResource = false;
                            if (data.Items && data.Items.length > 0) {
                                const chineseMatch = data.Items.find(item => {
                                    const itemName = item.Name;
                                    const itemYear = item.ProductionYear;
                                    return itemName === name && itemYear === year;
                                });
                                if (chineseMatch) {
                                    hasResource = true;
                                } else {
                                    const englishMatch = data.Items.find(item => {
                                        const itemOriginalTitle = item.OriginalTitle;
                                        const itemYear = item.ProductionYear;
                                        return itemOriginalTitle && itemOriginalTitle === name && itemYear === year;
                                    });
                                    hasResource = !!englishMatch;
                                }
                            }
                            state.embyCache.set(cacheKey, hasResource);
                            resolve(hasResource);
                        } catch (error) {
                            state.embyCache.set(cacheKey, false);
                            resolve(false);
                        }
                    },
                    onerror: function (error) {
                        state.embyCache.set(cacheKey, false);
                        resolve(false);
                    }
                });
            });
        },

        extractInfoFromPoster: (poster) => {
            const nameElement = poster.querySelector('p.MuiTypography-body1');
            const yearElement = Array.from(poster.querySelectorAll('p.MuiTypography-body1')).find(p => /^\d{4}$/.test(p.textContent.trim()));

            if (nameElement && yearElement && nameElement !== yearElement) {
                const name = nameElement.textContent.trim();
                const year = parseInt(yearElement.textContent.trim(), 10);
                if (name && !isNaN(year)) {
                    return { name, year, element: poster };
                }
            }
            return null;
        },

        extractInfoFromDetail: () => {
            const titleElement = document.querySelector('h1');
            if (titleElement) {
                const titleText = titleElement.childNodes[0]?.textContent?.trim() || '';
                const yearElement = titleElement.querySelector('p');
                if (yearElement) {
                    const yearText = yearElement.textContent.trim();
                    const yearMatch = yearText.match(/\((\d{4})\)/);
                    if (yearMatch) {
                        const year = parseInt(yearMatch[1], 10);
                        return { name: titleText, year };
                    }
                }
            }
            return null;
        },

        extractInfoFromUserPage: (element) => {
            const text = element.textContent.trim();
            const match = text.match(/(.+?)\s*\((\d{4})\)/);
            if (match) {
                const name = match[1].trim();
                const year = parseInt(match[2], 10);
                return { name, year, element };
            }
            return null;
        },

        extractInfoFromSearchYear: (element) => {
            const text = element.textContent.trim();
            const match = text.match(/\((\d{4})\)/);
            if (match) {
                const year = parseInt(match[1], 10);
                const nameElement = element.previousElementSibling;
                if (nameElement) {
                    const name = nameElement.textContent.trim();
                    return { name, year, element };
                }
            }
            return null;
        },

        extractInfoFromCollection: (element) => {
            const nameElement = element.querySelector('p.MuiTypography-body1');
            const yearElement = Array.from(element.querySelectorAll('p.MuiTypography-body1')).find(p => /^\d{4}$/.test(p.textContent.trim()));

            if (nameElement && yearElement && nameElement !== yearElement) {
                const name = nameElement.textContent.trim();
                const year = parseInt(yearElement.textContent.trim(), 10);
                if (name && !isNaN(year)) {
                    return { name, year, element };
                }
            }
            return null;
        },

        createPosterButton: (hasResource) => {
            const btn = document.createElement('div');
            btn.className = `emby-poster-btn ${hasResource ? 'has' : 'not-has'}`;
            btn.textContent = hasResource ? BUTTON_STYLES.posterBtn.has.icon : BUTTON_STYLES.posterBtn.notHas.icon;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            return btn;
        },

        createNameButton: (hasResource) => {
            const btn = document.createElement('span');
            btn.className = `emby-name-btn ${hasResource ? 'has' : 'not-has'}`;
            btn.textContent = hasResource ? BUTTON_STYLES.nameBtn.has.text : BUTTON_STYLES.nameBtn.notHas.text;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            return btn;
        },

        createDetailPosterButton: (hasResource) => {
            const btn = document.createElement('div');
            btn.className = `emby-detail-poster-btn ${hasResource ? 'has' : 'not-has'}`;
            btn.textContent = hasResource ? BUTTON_STYLES.detailBtn.posterBtn.has.icon : BUTTON_STYLES.detailBtn.posterBtn.notHas.icon;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            return btn;
        },

        createDetailTitleButton: (hasResource) => {
            const btn = document.createElement('span');
            btn.className = `emby-detail-title-btn ${hasResource ? 'has' : 'not-has'}`;
            btn.textContent = hasResource ? BUTTON_STYLES.detailBtn.titleBtn.has.text : BUTTON_STYLES.detailBtn.titleBtn.notHas.text;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            return btn;
        },

        createSearchYearButton: (hasResource) => {
            const btn = document.createElement('span');
            btn.className = `emby-search-year-btn ${hasResource ? 'has' : 'not-has'}`;
            btn.textContent = hasResource ? BUTTON_STYLES.searchYearBtn.has.text : BUTTON_STYLES.searchYearBtn.notHas.text;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            return btn;
        },

        createUserPageButton: (hasResource) => {
            const btn = document.createElement('span');
            btn.className = `emby-user-page-btn ${hasResource ? 'has' : 'not-has'}`;
            const state = hasResource ? BUTTON_STYLES.userPageBtn.has : BUTTON_STYLES.userPageBtn.notHas;
            btn.textContent = state.text;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            btn.disabled = true;
            return btn;
        },

        createCollectionButton: (hasResource) => {
            const btn = document.createElement('span');
            btn.className = `emby-collection-btn ${hasResource ? 'has' : 'not-has'}`;
            btn.textContent = hasResource ? BUTTON_STYLES.collectionBtn.has.text : BUTTON_STYLES.collectionBtn.notHas.text;
            btn.title = hasResource ? 'Emby库中有此资源' : 'Emby库中无此资源';
            return btn;
        },

        createSettingButton: () => {
            const btn = document.createElement('span');
            btn.className = 'emby-setting-btn';
            btn.innerHTML = `
                <span style="display:inline-block;width:16px;height:16px;margin-right:8px;
                    background-image:url('https://raw.githubusercontent.com/lige47/QuanX-icon-rule/main/icon/04ProxySoft/emby.png');
                    background-size:contain;background-repeat:no-repeat;background-position:center;
                    filter:brightness(0.9);"></span>
                <span>设置</span>
                <span style="display:inline-block;width:16px;height:16px;margin-left:8px;
                    background-image:url('https://115.com/favicon.ico');
                    background-size:contain;background-repeat:no-repeat;background-position:center;"></span>
            `;
            btn.title = '多功能设置';
            return btn;
        },

        createTransferButton: () => {
            const btn = document.createElement('div');
            btn.className = 'one-click-transfer-btn';
            btn.style.cssText = 'cursor:pointer;margin-left:4px;background:rgba(227, 242, 253, 0.3);color:#0d47a1;display:inline-flex;align-items:center;padding:0 8px;height:27px;border-radius:13.5px;font-weight:bold;font-size:13px;';
            btn.innerHTML = '<img src="https://115.com/favicon.ico" style="width:14px;height:14px;margin-right:4px;">一键转存';
            return btn;
        }
    };

    const SettingsManager = {
        showSettingsModal: () => {
            if (document.querySelector('#tm-settings-modal')) return;

            const embyHost = EMBY_CONFIG.HOST || '';
            const embyApiKey = EMBY_CONFIG.API_KEY || '';
            const cookie115 = GM_getValue('115_cookie') || '';
            const cid115 = GM_getValue('115_cid') || '0';
            const tgBotToken = GM_getValue('tg_bot_token') || '';
            const tgChatId = GM_getValue('tg_chat_id') || '';
            const tgProxy = GM_getValue('tg_proxy', '');
            const tgEnablePush = GM_getValue('tg_enable_push', false);

            const transferMethod = GM_getValue('115_transfer_method', 'cookie');
            const symediaUrl = GM_getValue('symedia_url', '');
            const symediaToken = GM_getValue('symedia_token', 'symedia');
            const enableTransfer = GM_getValue('115_enable_transfer', true);

            const overlay = document.createElement('div');
            overlay.id = 'tm-settings-modal';
            Object.assign(overlay.style, {
                position: 'fixed',
                top: '0',
                left: '0',
                width: '100%',
                height: '100%',
                background: 'rgba(0,0,0,0.5)',
                zIndex: 10001,
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center'
            });

            const modal = document.createElement('div');
            Object.assign(modal.style, {
                background: '#fff',
                padding: '20px 25px',
                borderRadius: '10px',
                width: '500px',
                boxShadow: '0 6px 20px rgba(0,0,0,0.3)',
                fontFamily: 'Arial, sans-serif',
                maxHeight: '85vh',
                overflowY: 'auto'
            });

            modal.innerHTML = `
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:15px;">
                    <h3 style="margin:0;color:#333">多功能助手设置</h3>
                    <button id="tm-settings-close" style="background:none;border:none;font-size:18px;cursor:pointer;color:#666;">×</button>
                </div>

                <div style="display:flex;gap:5px;margin-bottom:20px;border-bottom:1px solid #eee;padding-bottom:10px;">
                    <button class="tm-tab-btn active" data-tab="emby">Emby设置</button>
                    <button class="tm-tab-btn" data-tab="115">115网盘设置</button>
                    <button class="tm-tab-btn" data-tab="telegram">Telegram推送</button>
                    <button class="tm-tab-btn" data-tab="logs">日志</button>
                </div>

                <div id="tm-tab-emby" class="tm-tab-content active">
                    <div style="margin-bottom:20px;">
                        <h4 style="margin-top:0;margin-bottom:10px;color:#444;">Emby服务器设置</h4>
                        <div style="margin-bottom:10px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">Emby地址:</label>
                            <input id="tm-emby-host" type="text" value="${embyHost}" placeholder="http/s://emby地址" style="width:100%;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                        </div>
                        <div style="margin-bottom:10px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">API密钥:</label>
                            <div style="display:flex;align-items:center;gap:8px;">
                                <input id="tm-emby-apikey" type="password" value="${embyApiKey}" placeholder="输入您的Emby API密钥" style="flex:1;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                                <button id="tm-toggle-emby-apikey" style="padding:6px 10px;border:none;border-radius:4px;background:#666;color:#fff;cursor:pointer;white-space:nowrap;font-size:12px;">显示</button>
                            </div>
                        </div>
                        <div style="margin-top:15px;padding-top:10px;border-top:1px dashed #eee;">
                            <button id="tm-emby-refresh" style="width:100%;padding:8px;border:none;border-radius:4px;background:#2196F3;color:#fff;cursor:pointer;font-size:12px;font-weight:bold;">🔄 刷新 Emby 缓存并重新扫描</button>
                            <button id="tm-refresh-transfer-buttons" style="width:100%;padding:8px;border:none;border-radius:4px;background:#FF9800;color:#fff;cursor:pointer;font-size:12px;font-weight:bold;margin-top:10px;">🔄 刷新 115 转存按钮</button>
                        </div>
                    </div>
                </div>

                <div id="tm-tab-115" class="tm-tab-content">
                    <div style="margin-bottom:20px;">
                        <h4 style="margin-top:0;margin-bottom:10px;color:#444;">115网盘设置</h4>

                        <div style="display:flex;align-items:center;margin-bottom:10px;">
                            <input type="checkbox" id="tm-enable-transfer" ${enableTransfer ? 'checked' : ''} style="margin-right:8px;">
                            <label for="tm-enable-transfer" style="color:#555;font-weight:bold;font-size:13px;">启用115转存功能</label>
                        </div>

                        <div style="margin-bottom:15px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">转存方式:</label>
                            <select id="tm-transfer-method" style="width:100%;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                                <option value="cookie" ${transferMethod === 'cookie' ? 'selected' : ''}>115 Cookie转存</option>
                                <option value="symedia" ${transferMethod === 'symedia' ? 'selected' : ''}>Symedia API转存</option>
                            </select>
                        </div>

                        <div id="tm-cookie-settings" class="tm-transfer-settings" style="display:${transferMethod === 'cookie' ? 'block' : 'none'};">
                            <div style="margin-bottom:10px;">
                                <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">Cookie:</label>
                                <div style="display:flex;align-items:center;gap:8px;">
                                    <input id="tm-cookie-input" type="password" value="${cookie115}" placeholder="请输入115 Cookie" style="flex:1;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                                    <button id="tm-toggle-cookie" style="padding:6px 10px;border:none;border-radius:4px;background:#666;color:#fff;cursor:pointer;white-space:nowrap;font-size:12px;">显示</button>
                                </div>
                                <div style="font-size:11px;color:#666;margin-top:4px;">
                                    格式：UID=xxx;CID=xxx;SEID=xxx;... 或直接从浏览器复制
                                </div>
                            </div>
                        </div>

                        <div id="tm-symedia-settings" class="tm-transfer-settings" style="display:${transferMethod === 'symedia' ? 'block' : 'none'};">
                            <div style="margin-bottom:10px;">
                                <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">Symedia地址:</label>
                                <input id="tm-symedia-url" type="text" value="${symediaUrl}" placeholder="http://127.0.0.1:8095" style="width:100%;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                            </div>
                            <div style="margin-bottom:10px;">
                                <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">Token:</label>
                                <input id="tm-symedia-token" type="text" value="${symediaToken}" placeholder="默认: symedia" style="width:100%;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                            </div>
                            <div style="font-size:11px;color:#666;margin-top:4px;">
                                格式：http://IP:端口，token默认symedia
                            </div>
                        </div>

                        <div style="margin-bottom:10px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">目标文件夹 CID:</label>
                            <div style="display:flex;gap:10px;">
                                <input id="tm-cid-input" type="text" value="${cid115}" placeholder="0为根目录" style="flex:1;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                                <button id="tm-browse-folders" style="padding:6px 12px;border:none;border-radius:4px;background:#2196F3;color:#fff;cursor:pointer;font-size:12px;${transferMethod === 'cookie' ? '' : 'display:none;'}">浏览文件夹</button>
                            </div>
                            <div style="font-size:11px;color:#666;margin-top:4px;">
                                <div>说明:</div>
                                <div>• 如果关闭"启用115转存功能"，则不会执行转存，只输出链接和日志</div>
                                <div>• Cookie转存：需要有效的115 Cookie，可点击"浏览文件夹"选择</div>
                                <div>• Symedia转存：转存可触发实时监控归档整理 token默认symedia</div>
                                <div>• 文件夹ID：0为转存到根目录</div>
                                <div>• 当前设置：${cid115}</div>
                            </div>
                        </div>
                    </div>
                </div>

                <div id="tm-tab-telegram" class="tm-tab-content">
                    <div style="margin-bottom:20px;">
                        <h4 style="margin-top:0;margin-bottom:10px;color:#444;">Telegram推送设置</h4>

                        <div style="display:flex;align-items:center;margin-bottom:10px;">
                            <input type="checkbox" id="tm-tg-enable" ${tgEnablePush ? 'checked' : ''} style="margin-right:8px;">
                            <label for="tm-tg-enable" style="color:#555;font-weight:bold;font-size:13px;">启用Telegram推送</label>
                        </div>

                        <div style="margin-bottom:10px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">Bot Token:</label>
                            <div style="display:flex;align-items:center;gap:8px;">
                                <input id="tm-tg-token" type="password" value="${tgBotToken}" placeholder="请输入Telegram Bot Token" style="flex:1;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                                <button id="tm-toggle-token" style="padding:6px 10px;border:none;border-radius:4px;background:#666;color:#fff;cursor:pointer;white-space:nowrap;font-size:12px;">显示</button>
                            </div>
                        </div>

                        <div style="margin-bottom:10px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">Chat ID:</label>
                            <input id="tm-tg-chatid" type="text" value="${tgChatId}" placeholder="请输入Telegram Chat ID" style="width:100%;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                        </div>

                        <div style="margin-bottom:15px;">
                            <label style="display:block;margin-bottom:5px;color:#555;font-weight:bold;font-size:13px;">代理地址 (可选):</label>
                            <div style="display:flex;gap:8px;">
                                <input id="tm-tg-proxy" type="text" value="${tgProxy}" placeholder="http://ip:端口 (可选)" style="flex:1;padding:8px;border:1px solid #ccc;border-radius:4px;font-size:12px;">
                                <button id="tm-test-proxy" style="padding:6px 12px;border:none;border-radius:4px;background:#ff9800;color:#fff;cursor:pointer;font-size:12px;">测试推送</button>
                            </div>
                            <div style="font-size:11px;color:#666;margin-top:4px;">
                                注意：代理设置将在测试时立即生效，保存后对所有推送生效
                            </div>
                        </div>
                    </div>
                </div>

                <div id="tm-tab-logs" class="tm-tab-content">
                    <div style="margin-bottom:20px;">
                        <h4 style="margin-top:0;margin-bottom:10px;color:#444;">操作日志</h4>
                        <div style="margin-bottom:10px;display:flex;gap:10px;">
                            <button id="tm-clear-logs" style="padding:6px 12px;border:none;border-radius:4px;background:#f44336;color:#fff;cursor:pointer;font-size:12px;">清空日志</button>
                            <button id="tm-show-log-panel" style="padding:6px 12px;border:none;border-radius:4px;background:#2196F3;color:#fff;cursor:pointer;font-size:12px;">显示独立日志面板</button>
                        </div>
                        <div style="border:1px solid #eee;border-radius:4px;padding:10px;height:300px;overflow-y:auto;background:#fafafa;font-size:11px;">
                            <div id="tm-settings-log-content"></div>
                        </div>
                    </div>
                </div>

                <div style="text-align:right;margin-top:20px;">
                    <button id="tm-settings-cancel" style="margin-right:10px;padding:8px 16px;border:none;border-radius:4px;background:#ccc;color:#fff;cursor:pointer;font-size:12px;">取消</button>
                    <button id="tm-settings-save" style="padding:8px 16px;border:none;border-radius:4px;background:#4CAF50;color:#fff;cursor:pointer;font-size:12px;">保存设置</button>
                </div>
            `;

            overlay.appendChild(modal);
            document.body.appendChild(overlay);

            const tabBtns = modal.querySelectorAll('.tm-tab-btn');
            const tabContents = modal.querySelectorAll('.tm-tab-content');
            tabBtns.forEach(btn => {
                btn.addEventListener('click', function () {
                    const tab = this.getAttribute('data-tab');
                    tabBtns.forEach(b => b.classList.remove('active'));
                    tabContents.forEach(c => c.classList.remove('active'));
                    this.classList.add('active');
                    document.getElementById(`tm-tab-${tab}`).classList.add('active');
                    if (tab === 'logs') SettingsManager.refreshLogContent();
                });
            });

            const transferMethodSelect = modal.querySelector('#tm-transfer-method');
            const cookieSettings = modal.querySelector('#tm-cookie-settings');
            const symediaSettings = modal.querySelector('#tm-symedia-settings');
            const browseFoldersBtn = modal.querySelector('#tm-browse-folders');
            transferMethodSelect.addEventListener('change', function () {
                const method = this.value;
                cookieSettings.style.display = method === 'cookie' ? 'block' : 'none';
                symediaSettings.style.display = method === 'symedia' ? 'block' : 'none';
                browseFoldersBtn.style.display = method === 'cookie' ? '' : 'none';
            });

            modal.querySelector('#tm-settings-close').onclick = () => overlay.remove();

            const embyApiKeyInput = modal.querySelector('#tm-emby-apikey');
            const toggleEmbyApiKeyBtn = modal.querySelector('#tm-toggle-emby-apikey');
            if (toggleEmbyApiKeyBtn) {
                toggleEmbyApiKeyBtn.addEventListener('click', function () {
                    if (embyApiKeyInput.type === 'password') {
                        embyApiKeyInput.type = 'text';
                        toggleEmbyApiKeyBtn.textContent = '隐藏';
                    } else {
                        embyApiKeyInput.type = 'password';
                        toggleEmbyApiKeyBtn.textContent = '显示';
                    }
                });
            }

            modal.querySelector('#tm-emby-refresh').onclick = async () => {
                const btn = modal.querySelector('#tm-emby-refresh');
                const originalText = btn.innerHTML;
                btn.innerHTML = '🔄 正在刷新...';
                btn.disabled = true;

                state.embyCache.clear();
                state.processedItems.clear();
                state.processingItems.clear();

                const selectorList = [
                    '.emby-poster-btn',
                    '.emby-name-btn',
                    '.emby-detail-poster-btn',
                    '.emby-detail-title-btn',
                    '.emby-search-year-btn',
                    '.emby-user-page-btn',
                    '.emby-collection-btn'
                ];
                document.querySelectorAll(selectorList.join(',')).forEach(el => el.remove());

                await processAllPosters();

                setTimeout(() => {
                    btn.innerHTML = '✅ 刷新完成';
                    setTimeout(() => {
                        btn.innerHTML = originalText;
                        btn.disabled = false;
                    }, 1000);
                }, 500);
            };

            modal.querySelector('#tm-refresh-transfer-buttons').onclick = async () => {
                const btn = modal.querySelector('#tm-refresh-transfer-buttons');
                const originalText = btn.innerHTML;
                btn.innerHTML = '🔄 正在刷新...';
                btn.disabled = true;

                document.querySelectorAll('.one-click-transfer-btn').forEach(b => b.remove());

                if (Utils.isUserPage()) {
                    await processUserPageButtons();
                } else if (Utils.isParentPage()) {
                    addButtons();
                }

                setTimeout(() => {
                    btn.innerHTML = '✅ 刷新完成';
                    setTimeout(() => {
                        btn.innerHTML = originalText;
                        btn.disabled = false;
                    }, 1000);
                }, 500);
            };

            const cookieInput = modal.querySelector('#tm-cookie-input');
            const toggleCookieBtn = modal.querySelector('#tm-toggle-cookie');
            toggleCookieBtn.addEventListener('click', function () {
                if (cookieInput.type === 'password') {
                    cookieInput.type = 'text';
                    toggleCookieBtn.textContent = '隐藏';
                } else {
                    cookieInput.type = 'password';
                    toggleCookieBtn.textContent = '显示';
                }
            });

            const tokenInput = modal.querySelector('#tm-tg-token');
            const toggleTokenBtn = modal.querySelector('#tm-toggle-token');
            toggleTokenBtn.addEventListener('click', function () {
                if (tokenInput.type === 'password') {
                    tokenInput.type = 'text';
                    toggleTokenBtn.textContent = '隐藏';
                } else {
                    tokenInput.type = 'password';
                    toggleTokenBtn.textContent = '显示';
                }
            });

            modal.querySelector('#tm-browse-folders').onclick = () => {
                const cookieValue = cookieInput.value.trim();
                if (!cookieValue) {
                    alert('请先输入Cookie');
                    return;
                }
                GM_setValue('115_cookie', cookieValue);
                SettingsManager.showFolderBrowser();
            };

            modal.querySelector('#tm-test-proxy').onclick = async () => {
                const token = tokenInput.value.trim();
                const chatId = modal.querySelector('#tm-tg-chatid').value.trim();
                const proxy = modal.querySelector('#tm-tg-proxy').value.trim();
                const enablePush = modal.querySelector('#tm-tg-enable').checked;

                const originalToken = GM_getValue('tg_bot_token');
                const originalChatId = GM_getValue('tg_chat_id');
                const originalProxy = GM_getValue('tg_proxy');
                const originalEnablePush = GM_getValue('tg_enable_push');

                GM_setValue('tg_bot_token', token);
                GM_setValue('tg_chat_id', chatId);
                GM_setValue('tg_proxy', proxy);
                GM_setValue('tg_enable_push', enablePush);

                const testBtn = modal.querySelector('#tm-test-proxy');
                const originalText = testBtn.textContent;
                testBtn.textContent = '测试中...';
                testBtn.disabled = true;

                try {
                    const result = await TelegramPush.testPush();

                    if (result) {
                        alert('✅ Telegram推送测试成功！');
                    } else {
                        alert('❌ Telegram推送测试失败，请检查配置和网络连接');
                    }
                } catch (error) {
                    alert('❌ 测试过程中发生错误: ' + error.message);
                } finally {
                    testBtn.textContent = originalText;
                    testBtn.disabled = false;

                    GM_setValue('tg_bot_token', originalToken);
                    GM_setValue('tg_chat_id', originalChatId);
                    GM_setValue('tg_proxy', originalProxy);
                    GM_setValue('tg_enable_push', originalEnablePush);
                }
            };

            modal.querySelector('#tm-clear-logs').onclick = () => {
                if (Logger.logContent) {
                    Logger.logContent.innerHTML = '';
                    Logger.stats = { free: 0, paid: 0, unlocked: 0 };
                    document.querySelectorAll('#log-stats span').forEach(span => {
                        span.style.display = 'none';
                        span.textContent = span.id.replace('stat-', '') + ': 0';
                    });
                }
                SettingsManager.refreshLogContent();
            };

            modal.querySelector('#tm-show-log-panel').onclick = () => {
                Logger.showLogPanel();
                overlay.remove();
            };

            modal.querySelector('#tm-settings-cancel').onclick = () => overlay.remove();

            modal.querySelector('#tm-settings-save').onclick = () => {
                const newEmbyHost = modal.querySelector('#tm-emby-host').value.trim();
                const newEmbyApiKey = embyApiKeyInput.value.trim();
                const newCookie = cookieInput.value.trim();
                const newCid = modal.querySelector('#tm-cid-input').value.trim() || '0';
                const newTgToken = tokenInput.value.trim();
                const newTgChatId = modal.querySelector('#tm-tg-chatid').value.trim();
                const newTgProxy = modal.querySelector('#tm-tg-proxy').value.trim();
                const newTgEnable = modal.querySelector('#tm-tg-enable').checked;

                const newTransferMethod = modal.querySelector('#tm-transfer-method').value;
                const newSymediaUrl = modal.querySelector('#tm-symedia-url').value.trim();
                const newSymediaToken = modal.querySelector('#tm-symedia-token').value.trim() || 'symedia';
                const newEnableTransfer = modal.querySelector('#tm-enable-transfer').checked;

                GM_setValue('embyHost', newEmbyHost);
                GM_setValue('embyApiKey', newEmbyApiKey);
                EMBY_CONFIG.HOST = newEmbyHost;
                EMBY_CONFIG.API_KEY = newEmbyApiKey;

                GM_setValue('115_cookie', newCookie);
                GM_setValue('115_cid', newCid);
                GM_setValue('tg_bot_token', newTgToken);
                GM_setValue('tg_chat_id', newTgChatId);
                GM_setValue('tg_proxy', newTgProxy);
                GM_setValue('tg_enable_push', newTgEnable);

                GM_setValue('115_transfer_method', newTransferMethod);
                GM_setValue('symedia_url', newSymediaUrl);
                GM_setValue('symedia_token', newSymediaToken);
                GM_setValue('115_enable_transfer', newEnableTransfer);

                state.embyCache.clear();
                state.processedItems.clear();
                state.processingItems.clear();
                state.transferButtonsInitialized = false;

                Logger.addLog('✅ 所有设置已保存', 'success');
                overlay.remove();

                processAllPosters();

                if (Utils.isUserPage()) {
                    processUserPageButtons();
                } else if (Utils.isParentPage()) {
                    addButtons();
                }
            };

            SettingsManager.refreshLogContent();

            const style = document.createElement('style');
            style.textContent = `
                .tm-tab-btn { padding: 8px 16px; border: none; background: #f1f3f5; color: #666; cursor: pointer; font-size: 12px; border-radius: 4px 4px 0 0; transition: all 0.3s; }
                .tm-tab-btn.active { background: #2196F3; color: white; font-weight: bold; }
                .tm-tab-content { display: none; }
                .tm-tab-content.active { display: block; }
            `;
            modal.appendChild(style);
        },

        refreshLogContent: () => {
            const logContainer = document.querySelector('#tm-settings-log-content');
            if (!logContainer || !Logger.logContent) return;
            logContainer.innerHTML = Logger.logContent.innerHTML || '<div style="text-align:center;color:#999;padding:20px;">暂无日志</div>';
        },

        showFolderBrowser: async () => {
            if (document.querySelector('#tm-folder-browser')) return;

            const overlay = document.createElement('div');
            overlay.id = 'tm-folder-browser';
            Object.assign(overlay.style, {
                position: 'fixed',
                top: '0',
                left: '0',
                width: '100%',
                height: '100%',
                background: 'rgba(0,0,0,0.5)',
                zIndex: 10002,
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center'
            });

            const modal = document.createElement('div');
            Object.assign(modal.style, {
                background: '#fff',
                padding: '20px',
                borderRadius: '10px',
                width: '500px',
                maxHeight: '80vh',
                boxShadow: '0 6px 20px rgba(0,0,0,0.3)',
                fontFamily: 'Arial, sans-serif',
                display: 'flex',
                flexDirection: 'column'
            });

            modal.innerHTML = `
                <h3 style="margin-top:0;margin-bottom:15px;color:#333">浏览文件夹</h3>
                <div id="tm-current-path" style="margin-bottom:10px;padding:8px;background:#f5f5f5;border-radius:4px;font-size:12px;">根目录</div>
                <div id="tm-folders-list" style="flex:1;overflow-y:auto;margin-bottom:15px;min-height:200px;border:1px solid #eee;border-radius:4px;">
                    <div style="text-align:center;padding:40px 0;color:#999;">加载中...</div>
                </div>
                <div style="display:flex;justify-content:space-between;gap:10px;">
                    <button id="tm-folder-back" style="flex:1;padding:8px 12px;border:none;border-radius:4px;background:#ccc;color:#fff;cursor:pointer;font-size:12px;">返回上级</button>
                    <button id="tm-folder-cancel" style="flex:1;padding:8px 12px;border:none;border-radius:4px;background:#ccc;color:#fff;cursor:pointer;font-size:12px;">取消</button>
                    <button id="tm-folder-select" style="flex:1;padding:8px 12px;border:none;border-radius:4px;background:#4CAF50;color:#fff;cursor:pointer;font-size:12px;">选择</button>
                </div>
            `;

            overlay.appendChild(modal);
            document.body.appendChild(overlay);

            let currentCid = 0;
            let currentPath = ["根目录"];
            let cidStack = [];
            let pathStack = [];

            const getFolders = async (cid = 0) => {
                const cookie = GM_getValue('115_cookie');
                if (!cookie) {
                    Logger.addLog('❌ 获取文件夹失败：Cookie 未设置', 'error');
                    return [];
                }

                return new Promise((resolve) => {
                    GM_xmlhttpRequest({
                        method: "GET",
                        url: `https://webapi.115.com/files?aid=1&cid=${cid}&show_dir=1&nsprefix=1`,
                        headers: {
                            "Cookie": cookie,
                            "User-Agent": "Mozilla/5.0"
                        },
                        onload: (response) => {
                            try {
                                const data = JSON.parse(response.responseText);
                                if (data.state && data.data) {
                                    const folders = data.data
                                        .filter(item => item.fl && item.fl.length === 0)
                                        .map(item => ({
                                            name: item.n,
                                            cid: item.cid
                                        }));
                                    resolve(folders);
                                } else {
                                    resolve([]);
                                }
                            } catch (e) {
                                resolve([]);
                            }
                        },
                        onerror: () => resolve([])
                    });
                });
            };

            const loadFolders = async (cid = 0) => {
                const foldersList = document.getElementById('tm-folders-list');
                foldersList.innerHTML = '<div style="text-align:center;padding:40px 0;color:#999;">加载中...</div>';

                const folders = await getFolders(cid);

                if (folders.length === 0) {
                    foldersList.innerHTML = '<div style="text-align:center;padding:40px 0;color:#999;">该目录下没有文件夹</div>';
                    return;
                }

                foldersList.innerHTML = '';
                folders.forEach(folder => {
                    const folderItem = document.createElement('div');
                    Object.assign(folderItem.style, {
                        padding: '10px',
                        borderBottom: '1px solid #eee',
                        cursor: 'pointer',
                        display: 'flex',
                        justifyContent: 'space-between',
                        fontSize: '12px'
                    });
                    folderItem.innerHTML = `
                        <span>${folder.name}</span>
                        <span style="color:#999;">CID: ${folder.cid}</span>
                    `;

                    folderItem.addEventListener('mouseenter', () => {
                        folderItem.style.backgroundColor = '#f5f5f5';
                    });

                    folderItem.addEventListener('mouseleave', () => {
                        folderItem.style.backgroundColor = 'transparent';
                    });

                    folderItem.onclick = () => {
                        cidStack.push(currentCid);
                        pathStack.push([...currentPath]);
                        currentCid = folder.cid;
                        currentPath.push(folder.name);
                        updatePathDisplay();
                        loadFolders(currentCid);
                    };

                    foldersList.appendChild(folderItem);
                });
            };

            const updatePathDisplay = () => {
                const pathElement = document.getElementById('tm-current-path');
                pathElement.textContent = currentPath.join(' / ');
            };

            modal.querySelector('#tm-folder-back').onclick = () => {
                if (cidStack.length > 0) {
                    currentCid = cidStack.pop();
                    currentPath = pathStack.pop();
                    updatePathDisplay();
                    loadFolders(currentCid);
                }
            };

            modal.querySelector('#tm-folder-cancel').onclick = () => {
                overlay.remove();
            };

            modal.querySelector('#tm-folder-select').onclick = () => {
                if (currentCid !== 0) {
                    const cidInput = document.querySelector('#tm-cid-input');
                    if (cidInput) {
                        cidInput.value = currentCid;
                    }
                    Logger.addLog(`已选择文件夹: ${currentPath.join(' / ')} (CID: ${currentCid})`, 'success');
                }
                overlay.remove();
            };

            await loadFolders(currentCid);
            updatePathDisplay();
        },

        addSettingButton: () => {
            const checkInterval = setInterval(() => {
                const titleEl = document.querySelector('p.MuiTypography-body1');
                if (titleEl && titleEl.textContent.includes('HDHIVE')) {
                    clearInterval(checkInterval);

                    if (document.querySelector('.emby-setting-btn')) return;

                    const btn = EmbyHelper.createSettingButton();
                    btn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        e.preventDefault();
                        SettingsManager.showSettingsModal();
                    });

                    titleEl.parentNode.insertBefore(btn, titleEl.nextSibling);
                }
            }, 500);
        }
    };

    async function processPoster(poster) {
        const itemKey = `poster-${poster.href}`;
        if (state.processedItems.has(itemKey) || state.processingItems.has(itemKey)) {
            return;
        }
        state.processingItems.add(itemKey);
        const info = EmbyHelper.extractInfoFromPoster(poster);
        if (!info) {
            state.processingItems.delete(itemKey);
            return;
        }
        try {
            const hasResource = await EmbyHelper.checkEmbyResource(info.name, info.year);
            if (!poster.querySelector('.emby-poster-btn')) {
                const posterImageContainer = poster.querySelector('div[class*="Box-root"]');
                if (posterImageContainer) {
                    const btn = EmbyHelper.createPosterButton(hasResource);
                    posterImageContainer.style.position = 'relative';
                    posterImageContainer.appendChild(btn);
                }
            }
            if (!poster.querySelector('.emby-name-btn')) {
                const yearElement = info.element.querySelector('p.MuiTypography-body1');
                if (yearElement) {
                    const btn = EmbyHelper.createNameButton(hasResource);
                    const buttonContainer = document.createElement('div');
                    buttonContainer.style.display = 'flex';
                    buttonContainer.style.justifyContent = 'center';
                    buttonContainer.style.width = '100%';
                    buttonContainer.appendChild(btn);
                    yearElement.parentNode.insertBefore(buttonContainer, yearElement.nextSibling);
                }
            }
            state.processedItems.add(itemKey);
        } catch (error) {
        } finally {
            state.processingItems.delete(itemKey);
        }
    }

    async function processDetailPage() {
        if (!Utils.isDetailPage()) return;
        const detailKey = 'detail-page';
        if (state.processedItems.has(detailKey) || state.processingItems.has(detailKey)) {
            return;
        }
        state.processingItems.add(detailKey);
        const info = EmbyHelper.extractInfoFromDetail();
        if (!info) {
            state.processingItems.delete(detailKey);
            return;
        }
        try {
            const hasResource = await EmbyHelper.checkEmbyResource(info.name, info.year);
            if (!document.querySelector('.emby-detail-poster-btn')) {
                const posterContainer = document.querySelector('div[class*="Box-root"]');
                if (posterContainer) {
                    const btn = EmbyHelper.createDetailPosterButton(hasResource);
                    posterContainer.style.position = 'relative';
                    posterContainer.appendChild(btn);
                }
            }
            if (!document.querySelector('.emby-detail-title-btn')) {
                const titleElement = document.querySelector('h1');
                if (titleElement) {
                    const btn = EmbyHelper.createDetailTitleButton(hasResource);
                    titleElement.parentNode.insertBefore(btn, titleElement.nextSibling);
                }
            }
            state.processedItems.add(detailKey);
        } catch (error) {
        } finally {
            state.processingItems.delete(detailKey);
        }
    }

    async function processSearchYearButtons() {
        const resultItems = document.querySelectorAll('a[href*="/tmdb/"]');
        for (const item of resultItems) {
            const itemKey = `search-${item.href}`;
            if (state.processedItems.has(itemKey) || state.processingItems.has(itemKey)) {
                continue;
            }
            state.processingItems.add(itemKey);
            const yearText = item.querySelector('.MuiTypography-body2');
            if (yearText && yearText.textContent.includes('(')) {
                const info = EmbyHelper.extractInfoFromSearchYear(yearText);
                if (info) {
                    try {
                        const hasResource = await EmbyHelper.checkEmbyResource(info.name, info.year);
                        if (!yearText.parentNode.querySelector('.emby-search-year-btn')) {
                            const btn = EmbyHelper.createSearchYearButton(hasResource);
                            yearText.parentNode.insertBefore(btn, yearText.nextSibling);
                        }
                    } catch (error) {
                    }
                }
            }
            state.processedItems.add(itemKey);
            state.processingItems.delete(itemKey);
        }
    }

    async function processCollectionButtons() {
        if (!Utils.isCollectionPage()) return;
        const collectionItems = document.querySelectorAll('a[href*="/tmdb/"]');
        for (const item of collectionItems) {
            const itemKey = `collection-${item.href}`;
            if (state.processedItems.has(itemKey) || state.processingItems.has(itemKey)) {
                continue;
            }
            state.processingItems.add(itemKey);
            const info = EmbyHelper.extractInfoFromCollection(item);
            if (info) {
                try {
                    const hasResource = await EmbyHelper.checkEmbyResource(info.name, info.year);
                    if (!item.querySelector('.emby-poster-btn')) {
                        const posterImageContainer = item.querySelector('div[class*="Box-root"]');
                        if (posterImageContainer) {
                            const btn = EmbyHelper.createPosterButton(hasResource);
                            posterImageContainer.style.position = 'relative';
                            posterImageContainer.appendChild(btn);
                        }
                    }
                    if (!item.querySelector('.emby-collection-btn')) {
                        const btn = EmbyHelper.createCollectionButton(hasResource);
                        const yearElement = info.element.querySelector('p.MuiTypography-body1');
                        if (yearElement) {
                            const buttonContainer = document.createElement('div');
                            buttonContainer.style.display = 'flex';
                            buttonContainer.style.justifyContent = 'center';
                            buttonContainer.style.width = '100%';
                            buttonContainer.appendChild(btn);
                            yearElement.parentNode.insertBefore(buttonContainer, yearElement.nextSibling);
                        }
                    }
                } catch (error) {
                }
            }
            state.processedItems.add(itemKey);
            state.processingItems.delete(itemKey);
        }
    }

    async function processUserPageButtons() {
        const elements = Array.from(document.querySelectorAll('p.MuiTypography-body1'))
            .filter(el => /\(\d{4}\)/.test(el.textContent));

        for (const el of elements) {
            const itemKey = `user-${el.textContent}`;
            if (state.processedItems.has(itemKey) || state.processingItems.has(itemKey)) {
                continue;
            }
            state.processingItems.add(itemKey);
            const info = EmbyHelper.extractInfoFromUserPage(el);
            if (info) {
                try {
                    const hasResource = await EmbyHelper.checkEmbyResource(info.name, info.year);
                    if (!el.querySelector('.emby-user-page-btn')) {
                        const btn = EmbyHelper.createUserPageButton(hasResource);
                        el.appendChild(btn);
                    }
                } catch (error) {
                }
            }
            state.processedItems.add(itemKey);
            state.processingItems.delete(itemKey);
        }

        document.querySelectorAll('.MuiGrid2-root.mui-1ypgxrn').forEach(container => {
            if (container.querySelector('.one-click-transfer-btn')) return;

            const link = container.querySelector('a[href*="/resource/"]');
            if (!link) return;

            const has115Tag = container.textContent.includes('115网盘');
            if (!has115Tag) return;

            const btn = EmbyHelper.createTransferButton();
            btn.style.marginLeft = '8px';
            btn.style.verticalAlign = 'middle';
            btn.style.marginTop = '5px';

            btn.onclick = (e) => {
                e.preventDefault();
                e.stopPropagation();

                const rawTarget = `${location.origin}${link.getAttribute('href')}`;

                if (Logger.isLinkProcessed(rawTarget)) {
                    Logger.addLog(`⚠️ 该资源已在处理中，请勿重复点击`, 'process');
                    return;
                }
                Logger.markLinkAsProcessed(rawTarget);

                Logger.startNewTask(rawTarget);
                Logger.addLog(`开始处理 (User页面智能检测) <a href="${rawTarget}" target="_blank">${rawTarget}</a>`, 'process');

                const processedTarget = `${rawTarget}?autotransfer=1&type=user_auto`;
                window.open(processedTarget, '_blank', `width=600,height=500`);
            };

            const yearElement = container.querySelector('p.MuiTypography-body1');
            if (yearElement) {
                const embyBtn = yearElement.querySelector('.emby-user-page-btn');
                if (embyBtn) {
                    embyBtn.insertAdjacentElement('afterend', btn);
                } else {
                    yearElement.appendChild(btn);
                }
            }
        });
    }

    async function processAllPosters() {
        const posters = document.querySelectorAll('a[href*="/movie/"], a[href*="/tv/"]');
        for (const poster of posters) {
            await processPoster(poster);
        }

        const popoverPosters = document.querySelectorAll('a[href*="/movie/"], a[href*="/tv/"]');
        for (const poster of popoverPosters) {
            await processPoster(poster);
        }

        await processDetailPage();
        await processSearchYearButtons();
        await processCollectionButtons();
        if (Utils.isUserPage()) {
            await processUserPageButtons();
        }
    }

    function removeButtons() { document.querySelectorAll('.one-click-transfer-btn').forEach(b => b.remove()); }

    function addButtons() {
        const resourceContainers = document.querySelectorAll('.MuiBox-root.mui-1uuwy6r');
        resourceContainers.forEach(container => {
            if (container.querySelector('.one-click-transfer-btn')) return;

            const link = container.querySelector('a[href^="/resource/"]');
            if (!link) return;

            let type = 'unknown'; let cost = '';
            const chips = container.querySelectorAll('.MuiChip-root');
            chips.forEach(chip => {
                const t = chip.textContent;
                if (t.includes('免费')) type = 'free';
                else if (t.includes('已解锁')) type = 'unlocked';
                else if (t.includes('积分')) { type = 'paid'; cost = t.replace(/[^\d]/g, ''); }
            });

            Logger.updateStats(type);

            const btn = EmbyHelper.createTransferButton();

            btn.onclick = (e) => {
                e.preventDefault(); e.stopPropagation();
                const logType = (type === 'paid') ? `${cost} 积分` : (type === 'free') ? '免费' : '已解锁';
                const rawTarget = `${location.origin}${link.getAttribute('href')}`;

                if (Logger.isLinkProcessed(rawTarget)) {
                    Logger.addLog(`⚠️ 该资源已在处理中，请勿重复点击`, 'process');
                    return;
                }
                Logger.markLinkAsProcessed(rawTarget);

                Logger.startNewTask(rawTarget);
                Logger.addLog(`开始处理 链接 [${logType}] <a href="${rawTarget}" target="_blank">${rawTarget}</a>`, 'process');

                const processedTarget = `${rawTarget}?autotransfer=1&type=${type}`;
                window.open(processedTarget, '_blank', `width=600,height=500`);
            };

            const chipContainer = container.querySelector('.mui-drwuj3');
            if (chipContainer) {
                chipContainer.appendChild(btn);
            }
        });
    }

    function initParentPage() {
        window.addEventListener('message', (event) => {
            if (event.data && event.data.type === 'HDHIVE_RESULT') {
                const { status, url, error, step } = event.data;
                if (status === 'success') {
                    if (Logger.isLinkProcessed(url)) {
                        return;
                    }
                    Logger.markLinkAsProcessed(url);
                    Logger.addLog(`✅ <b>获取成功</b>: <a href="${url}" target="_blank">${url}</a>`, 'success');
                    handleTransfer115(url);
                }
                else if (status === 'process') {
                    if (!Logger.isLinkProcessed(`process_${step}`)) {
                        Logger.markLinkAsProcessed(`process_${step}`);
                        Logger.addLog(`👉 ${step}`, 'process');
                    }
                }
                else if (status === 'error') Logger.addLog(`❌ <b>失败</b>: ${error}`, 'error');
            }
        });

        async function handleTransfer115(url) {
            const enableTransfer = GM_getValue('115_enable_transfer', true);

            if (!enableTransfer) {
                Logger.addLog(`<span style="color:#ff9800;">⚠️ 未开启转存，取消转存</span>`, 'error');
                Logger.endCurrentTask('completed');
                return;
            }

            const transferMethod = GM_getValue('115_transfer_method', 'cookie');
            const cid = GM_getValue('115_cid') || '0';

            const transferKey = `transfer_${url}`;
            if (Logger.isLinkProcessed(transferKey)) {
                return;
            }
            Logger.markLinkAsProcessed(transferKey);

            let result;

            if (transferMethod === 'cookie') {
                const cookie = GM_getValue('115_cookie');
                if (!cookie) {
                    Logger.addLog('❌ 未填写 115 Cookie，取消转存', 'process');
                    Logger.endCurrentTask('failed');
                    return;
                }
                result = await Transfer115.transfer(url, cookie, cid);
            } else if (transferMethod === 'symedia') {
                const symediaUrl = GM_getValue('symedia_url', '');
                const symediaToken = GM_getValue('symedia_token', 'symedia');

                if (!symediaUrl) {
                    Logger.addLog('❌ 未填写 Symedia 地址，取消转存', 'process');
                    Logger.endCurrentTask('failed');
                    return;
                }

                result = await Transfer115.transferBySymedia(url, symediaUrl, symediaToken, cid);
            } else {
                Logger.addLog('❌ 未知的转存方式', 'error');
                Logger.endCurrentTask('failed');
                return;
            }

            if (result.success) {
                Logger.addLog(result.message, 'success');
                Logger.endCurrentTask('completed');
            } else {
                if (!result.message.includes('❌') && !result.message.includes('⚠️')) {
                    Logger.addLog(`❌ ${result.message}`, 'error');
                } else {
                    Logger.addLog(result.message, 'error');
                }
                Logger.endCurrentTask('failed');
            }
        }

        function is115Tab() { return document.querySelector('.MuiTab-root.Mui-selected')?.textContent?.includes('115网盘'); }
        function startObserver() {
            new MutationObserver(() => {
                if (is115Tab()) addButtons();
                else removeButtons();
            }).observe(document.body, { childList: true, subtree: true });
            if (is115Tab()) addButtons();
        }

        if (Utils.isUserPage()) {
            new MutationObserver(async () => {
                await processUserPageButtons();
            }).observe(document.body, { childList: true, subtree: true });

            processUserPageButtons();
        } else {
            startObserver();
        }
    }

    function initChildPage() {
        const params = new URLSearchParams(location.search);
        if (!params.has('autotransfer')) return;

        const type = params.get('type');
        let isFinished = false;

        const send = (data) => window.opener && window.opener.postMessage({ type: 'HDHIVE_RESULT', ...data }, '*');
        const log = (step) => send({ status: 'process', step });
        const fail = (msg) => { if (isFinished) return; isFinished = true; clearAllFinders(); send({ status: 'error', error: msg }); };

        const success = (rawUrl) => {
            if (isFinished) return;
            const check = Utils.verifyAndFormatUrl(rawUrl);
            if (check.success) {
                isFinished = true;
                clearAllFinders();
                send({ status: 'success', url: check.url });
                setTimeout(() => window.close(), CONFIG.autoCloseDelay);
            } else {
                if (type === 'paid' || type === 'user_auto') console.log("捕获到无效链接/非最终链接，忽略:", rawUrl);
                else fail(`链接校验不通过: ${check.msg} (URL: ${rawUrl})`);
            }
        };

        const finders = [];
        function clearAllFinders() { finders.forEach(id => { try { clearInterval(id); } catch (e) { }; try { clearTimeout(id); } catch (e) { }; }); finders.length = 0; }

        function checkUnlockAndCost() {
            const buttons = Array.from(document.querySelectorAll('button'));
            const unlockBtn = buttons.find(btn => {
                const text = Utils.normalizeText(btn.textContent);
                return text.includes('确定解锁') || (text.includes('解锁') && !text.includes('取消') && !text.includes('close'));
            });

            if (unlockBtn && !unlockBtn.dataset.clicked) {
                unlockBtn.dataset.clicked = "true";

                const boxRoots = Array.from(document.querySelectorAll('.MuiBox-root'));
                const pointsDiv = boxRoots.find(el => el.textContent && (el.textContent.includes('积分解锁') || el.textContent.includes('需要使用')));

                if (pointsDiv) {
                    const text = pointsDiv.textContent || '';
                    const unlockedMatch = text.match(/已解锁人数\s*[:：]?\s*(\d+)/) || text.match(/已解锁\s*(\d+)/);
                    const unlockedCount = unlockedMatch ? unlockedMatch[1] : '未知';
                    const pointsMatch = text.match(/需要使用\s*(\d+)\s*积分/) || text.match(/消耗[:：]?\s*(\d+)\s*积分/);
                    const pointsCount = pointsMatch ? pointsMatch[1] : '未知';
                    log(`🔍 已解锁: ${unlockedCount} 人`);
                    log(`💰 需要: ${pointsCount} 积分`);
                }

                log('✅ 找到解锁按钮');

                if (Utils.isSafari) {
                    unlockBtn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                } else {
                    try { unlockBtn.click(); }
                    catch (e) { unlockBtn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window })); log('⚠️ click() 失败，改用 dispatchEvent'); }
                }
                return true;
            }
            return false;
        }

        if (type === 'paid' || type === 'user_auto') {
            const unlockFinder = setInterval(() => {
                if (isFinished) return;
                checkUnlockAndCost();
            }, 300);
            finders.push(unlockFinder);
        }

        document.addEventListener('DOMContentLoaded', () => {
            const to = setTimeout(() => { if (!isFinished) fail('操作超时 (未获取到有效带密码链接)'); }, CONFIG.maxWaitTime);
            finders.push(to);

            const observer = new MutationObserver((mutations, obs) => {
                if (isFinished) { obs.disconnect(); return; }

                const links = document.querySelectorAll('a');
                for (let a of links) {
                    if (a.href && a.href.includes('115')) {
                        const check = Utils.verifyAndFormatUrl(a.href);
                        if (check.success) { success(a.href); obs.disconnect(); return; }
                    }
                }
            });
            observer.observe(document.body, { childList: true, subtree: true });
        });

        const oldXhr = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function () {
            this.addEventListener('load', function () {
                const txt = this.responseText;
                if (txt && (txt.includes('115cdn.com') || txt.includes('115.com/s/'))) {
                    const match = txt.match(/https?:\/\/[^\s"']+/);
                    if (match) {
                        const check = Utils.verifyAndFormatUrl(match[0]);
                        if (check.success) {
                            log('已拦截XHR中的解锁链接');
                            success(match[0]);
                        }
                    }
                }
            });
            return oldXhr.apply(this, arguments);
        };

        const oldOpen = window.open;
        window.open = function (url) {
            if (url && (url.includes('115cdn.com') || url.includes('115.com/s/'))) {
                const check = Utils.verifyAndFormatUrl(url);
                if (check.success) { log('已拦截window.open跳转'); success(url); return null; }
            }
            return oldOpen.apply(this, arguments);
        };
    }

    function initFinal115Page() {
        if (!window.opener) return;
        const check = Utils.verifyAndFormatUrl(location.href);
        if (check.success) {
            window.opener.postMessage({ type: 'HDHIVE_RESULT', status: 'success', url: check.url }, '*');
            window.close();
        }
        else {
            window.opener.postMessage({ type: 'HDHIVE_RESULT', status: 'error', error: `跳转链接无效: ${check.msg}` }, '*');
        }
    }

    function init() {
        TelegramPush.init();
        Logger.init();

        if (Utils.isResourcePage()) {
            initChildPage();
        } else if (Utils.isFinal115Page()) {
            initFinal115Page();
        } else if (Utils.isHDHiveSite()) {
            SettingsManager.addSettingButton();

            processAllPosters();
            setupSearchListener();
            setupUrlChangeListener();
            setupSearchDialogListener();

            let mutationTimeout;
            const observer = new MutationObserver(mutations => {
                clearTimeout(mutationTimeout);
                mutationTimeout = setTimeout(() => {
                    let shouldProcess = false;
                    for (const mutation of mutations) {
                        if (mutation.addedNodes.length > 0) {
                            shouldProcess = true;
                            break;
                        }
                    }
                    if (shouldProcess) {
                        processAllPosters();
                    }
                }, 300);
            });

            observer.observe(document.body, {
                childList: true,
                subtree: true
            });

            if (Utils.isParentPage() || Utils.isUserPage()) {
                initParentPage();
            }
        }
    }

    function setupSearchListener() {
        const searchInput = document.querySelector('input[type="text"][name="search"]');
        if (searchInput) {
            searchInput.addEventListener('input', () => {
                state.processedItems.clear();
                state.processingItems.clear();
                setTimeout(processAllPosters, 1000);
            });
        }
    }

    function setupUrlChangeListener() {
        let currentUrl = window.location.href;
        const observer = new MutationObserver(() => {
            if (window.location.href !== currentUrl) {
                currentUrl = window.location.href;
                state.processedItems.clear();
                state.processingItems.clear();
                state.embyCache.clear();
                setTimeout(processAllPosters, 1000);
            }
        });
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    function setupSearchDialogListener() {
        const observer = new MutationObserver(() => {
            const searchDialog = document.querySelector('.MuiDialog-paper');
            if (searchDialog) {
                state.processedItems.clear();
                state.processingItems.clear();
                setTimeout(processAllPosters, 500);
            }
        });
        observer.observe(document.body, { childList: true, subtree: true });
    }

    const style = document.createElement('style');
    style.textContent = `
        .emby-poster-btn {
            position: absolute;
            width: ${BUTTON_STYLES.posterBtn.size};
            height: ${BUTTON_STYLES.posterBtn.size};
            top: ${BUTTON_STYLES.posterBtn.position.top};
            right: ${BUTTON_STYLES.posterBtn.position.right};
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            font-weight: bold;
            cursor: pointer;
            z-index: 100;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            text-shadow: 0 1px 2px rgba(0,0,0,0.2);
        }
        .emby-poster-btn.has {
            background: ${BUTTON_STYLES.posterBtn.has.bg};
            color: white;
            border: ${BUTTON_STYLES.posterBtn.has.border};
        }
        .emby-poster-btn.not-has {
            background: ${BUTTON_STYLES.posterBtn.notHas.bg};
            color: white;
            border: ${BUTTON_STYLES.posterBtn.notHas.border};
        }
        .emby-poster-btn:hover {
            transform: ${BUTTON_STYLES.posterBtn.hoverEffect};
            box-shadow: 0 6px 20px rgba(0,0,0,0.3);
        }
        .emby-name-btn {
            display: inline-flex;
            align-items: center;
            margin-top: ${BUTTON_STYLES.nameBtn.marginTop};
            padding: ${BUTTON_STYLES.nameBtn.padding};
            border-radius: 12px;
            font-size: ${BUTTON_STYLES.nameBtn.fontSize};
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            background: transparent;
        }
        .emby-name-btn.has {
            background: ${BUTTON_STYLES.nameBtn.has.bg};
            color: ${BUTTON_STYLES.nameBtn.has.textColor};
            border: ${BUTTON_STYLES.nameBtn.has.border};
        }
        .emby-name-btn.not-has {
            background: ${BUTTON_STYLES.nameBtn.notHas.bg};
            color: ${BUTTON_STYLES.nameBtn.notHas.textColor};
            border: ${BUTTON_STYLES.nameBtn.notHas.border};
        }
        .emby-name-btn:hover {
            transform: ${BUTTON_STYLES.nameBtn.hoverEffect};
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }
        .emby-detail-poster-btn {
            position: absolute;
            width: ${BUTTON_STYLES.detailBtn.posterBtn.size};
            height: ${BUTTON_STYLES.detailBtn.posterBtn.size};
            top: ${BUTTON_STYLES.detailBtn.posterBtn.position.top};
            right: ${BUTTON_STYLES.detailBtn.posterBtn.position.right};
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            font-weight: bold;
            cursor: pointer;
            z-index: 100;
            box-shadow: 0 6px 20px rgba(0,0,0,0.3);
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        .emby-detail-poster-btn.has {
            background: ${BUTTON_STYLES.detailBtn.posterBtn.has.bg};
            color: white;
            border: ${BUTTON_STYLES.detailBtn.posterBtn.has.border};
        }
        .emby-detail-poster-btn.not-has {
            background: ${BUTTON_STYLES.detailBtn.posterBtn.notHas.bg};
            color: white;
            border: ${BUTTON_STYLES.detailBtn.posterBtn.notHas.border};
        }
        .emby-detail-poster-btn:hover {
            transform: ${BUTTON_STYLES.detailBtn.posterBtn.hoverEffect};
            box-shadow: 0 8px 25px rgba(0,0,0,0.4);
        }
        .emby-detail-title-btn {
            display: inline-flex;
            align-items: center;
            margin-left: ${BUTTON_STYLES.detailBtn.titleBtn.marginLeft};
            padding: ${BUTTON_STYLES.detailBtn.titleBtn.padding};
            border-radius: 15px;
            font-size: ${BUTTON_STYLES.detailBtn.titleBtn.fontSize};
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            background: transparent;
        }
        .emby-detail-title-btn.has {
            background: ${BUTTON_STYLES.detailBtn.titleBtn.has.bg};
            color: ${BUTTON_STYLES.detailBtn.titleBtn.has.textColor};
            border: ${BUTTON_STYLES.detailBtn.titleBtn.has.border};
        }
        .emby-detail-title-btn.not-has {
            background: ${BUTTON_STYLES.detailBtn.titleBtn.notHas.bg};
            color: ${BUTTON_STYLES.detailBtn.titleBtn.notHas.textColor};
            border: ${BUTTON_STYLES.detailBtn.titleBtn.notHas.border};
        }
        .emby-detail-title-btn:hover {
            transform: ${BUTTON_STYLES.detailBtn.titleBtn.hoverEffect};
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
        .emby-search-year-btn {
            display: inline-flex;
            align-items: center;
            margin-left: ${BUTTON_STYLES.searchYearBtn.marginLeft};
            padding: ${BUTTON_STYLES.searchYearBtn.padding};
            border-radius: 12px;
            font-size: ${BUTTON_STYLES.searchYearBtn.fontSize};
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            background: transparent;
        }
        .emby-search-year-btn.has {
            background: ${BUTTON_STYLES.searchYearBtn.has.bg};
            color: ${BUTTON_STYLES.searchYearBtn.has.textColor};
            border: ${BUTTON_STYLES.searchYearBtn.has.border};
        }
        .emby-search-year-btn.not-has {
            background: ${BUTTON_STYLES.searchYearBtn.notHas.bg};
            color: ${BUTTON_STYLES.searchYearBtn.notHas.textColor};
            border: ${BUTTON_STYLES.searchYearBtn.notHas.border};
        }
        .emby-search-year-btn:hover {
            transform: ${BUTTON_STYLES.searchYearBtn.hoverEffect};
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }
        .emby-user-page-btn {
            display: inline-flex;
            align-items: center;
            margin-left: ${BUTTON_STYLES.userPageBtn.marginLeft};
            padding: ${BUTTON_STYLES.userPageBtn.padding};
            border-radius: 12px;
            font-size: ${BUTTON_STYLES.userPageBtn.fontSize};
            font-weight: 600;
            cursor: default;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            opacity: 0.7;
        }
        .emby-user-page-btn.has {
            background: ${BUTTON_STYLES.userPageBtn.has.bg};
            color: ${BUTTON_STYLES.userPageBtn.has.textColor};
            border: ${BUTTON_STYLES.userPageBtn.has.border};
        }
        .emby-user-page-btn.not-has {
            background: ${BUTTON_STYLES.userPageBtn.notHas.bg};
            color: ${BUTTON_STYLES.userPageBtn.notHas.textColor};
            border: ${BUTTON_STYLES.userPageBtn.notHas.border};
        }
        .emby-user-page-btn:hover {
            transform: ${BUTTON_STYLES.userPageBtn.hoverEffect};
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }
        .emby-collection-btn {
            display: inline-flex;
            align-items: center;
            margin-left: ${BUTTON_STYLES.collectionBtn.marginLeft};
            padding: ${BUTTON_STYLES.collectionBtn.padding};
            border-radius: 12px;
            font-size: ${BUTTON_STYLES.collectionBtn.fontSize};
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            background: transparent;
        }
        .emby-collection-btn.has {
            background: ${BUTTON_STYLES.collectionBtn.has.bg};
            color: ${BUTTON_STYLES.collectionBtn.has.textColor};
            border: ${BUTTON_STYLES.collectionBtn.has.border};
        }
        .emby-collection-btn.not-has {
            background: ${BUTTON_STYLES.collectionBtn.notHas.bg};
            color: ${BUTTON_STYLES.collectionBtn.notHas.textColor};
            border: ${BUTTON_STYLES.collectionBtn.notHas.border};
        }
        .emby-collection-btn:hover {
            transform: ${BUTTON_STYLES.collectionBtn.hoverEffect};
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }
        
        .emby-setting-btn {
            display: inline-flex;
            align-items: center;
            padding: ${BUTTON_STYLES.settingBtn.padding};
            margin-left: 10px;
            border-radius: 14px;
            font-size: ${BUTTON_STYLES.settingBtn.fontSize};
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            background: ${BUTTON_STYLES.settingBtn.has.bg};
            color: ${BUTTON_STYLES.settingBtn.has.textColor};
            border: ${BUTTON_STYLES.settingBtn.has.border};
            vertical-align: middle;
        }
        .emby-setting-btn:hover {
            transform: ${BUTTON_STYLES.settingBtn.hoverEffect};
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }

        .emby-name-btn::before,
        .emby-detail-title-btn::before,
        .emby-search-year-btn::before,
        .emby-user-page-btn::before,
        .emby-collection-btn::before {
            content: "";
            display: inline-block;
            width: 16px;
            height: 16px;
            margin-right: 6px;
            background-image: url('https://raw.githubusercontent.com/lige47/QuanX-icon-rule/main/icon/04ProxySoft/emby.png');
            background-size: contain;
            background-repeat: no-repeat;
            background-position: center;
            filter: brightness(0.9);
        }
        .emby-detail-title-btn::before {
            width: 18px;
            height: 18px;
            margin-right: 8px;
        }

        .MuiPopover-root .emby-poster-btn,
        .MuiPopover-root .emby-name-btn,
        .MuiPopover-root .emby-detail-poster-btn,
        .MuiPopover-root .emby-detail-title-btn,
        .MuiPopover-root .emby-search-year-btn,
        .MuiPopover-root .emby-user-page-btn,
        .MuiPopover-root .emby-collection-btn,
        .MuiPopover-root .emby-setting-btn {
            z-index: 1500;
        }
        #hdhive-notice {
            position: fixed;
            top: 10px;
            left: 50%;
            transform: translateX(-50%);
            padding: 8px 12px;
            background-color: #ff9800;
            color: #fff;
            font-size: 14px;
            font-weight: bold;
            border-radius: 4px;
            z-index: 9999;
            box-shadow: 0 2px 6px rgba(0,0,0,0.3);
        }
    `;
    document.head.appendChild(style);

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();