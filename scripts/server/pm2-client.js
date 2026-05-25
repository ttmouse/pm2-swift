/**
 * PM2 连接管理
 *
 * 职责：
 * 1. 维护单一 PM2 连接（避免反复连接断开）
 * 2. 提供 Promise 化的 API
 * 3. 错误处理与重连
 */
'use strict';

const pm2 = require('pm2');
const path = require('path');
const fs = require('fs');
const os = require('os');
const logger = require('./utils/logger');

const ECOSYSTEM_CONFIG_PATH = path.join(os.homedir(), '.pm2', 'ecosystem.config.js');
const ECOSYSTEM_PATHS_FILE = path.join(os.homedir(), '.pm2', 'ecosystem-paths.json');
let ecosystemCache = { apps: [], loadedAt: 0 };

let connected = false;
let reconnectTimer = null;

/**
 * 连接到 PM2 daemon
 */
async function connect() {
    if (connected) return;

    return new Promise((resolve, reject) => {
        pm2.connect((err) => {
            if (err) {
                logger.error('PM2 connect error:', err.message);
                return reject(err);
            }
            connected = true;
            logger.info('PM2 connected');
            resolve();
        });
    });
}

/**
 * 确保已连接，必要时重连
 */
async function ensureConnect() {
    if (!connected) {
        await connect();
    }
}

/**
 * 获取进程列表（含配置来源识别）
 */
async function list() {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.list((err, processes) => {
            if (err) return reject(err);
            const formatted = processes.map(formatProcess);
            resolve(addConfigSource(formatted));
        });
    });
}

/**
 * 从所有 ecosystem config 中发现可启动的应用（未在 PM2 中运行的）
 */
async function getAvailableApps() {
    await ensureConnect();
    const runningNames = await new Promise((resolve, reject) => {
        pm2.list((err, processes) => {
            if (err) return reject(err);
            resolve(new Set(processes.map(p => p.name).filter(Boolean)));
        });
    });

    const allEcosystemApps = loadAllEcosystemConfigs();
    const available = [];

    for (const app of allEcosystemApps) {
        if (!runningNames.has(app.name)) {
            available.push({
                name: app.name,
                configFile: app.configFile,
                cwd: app.cwd,
                script: app.script,
                port: app.envPort,
            });
        }
    }
    return available;
}

/**
 * 从 ecosystem config 中读取指定 app 配置并启动
 */
async function startEcosystemApp(configFile, appName) {
    const absPath = path.resolve(configFile.replace(/^~/, os.homedir()));
    if (!fs.existsSync(absPath)) {
        throw new Error(`配置文件不存在: ${absPath}`);
    }

    delete require.cache[require.resolve(absPath)];
    const config = require(absPath);
    const apps = Array.isArray(config?.apps) ? config.apps : [];
    const app = apps.find(a => a && a.name === appName);

    if (!app) {
        throw new Error(`在 ${configFile} 中未找到 app: ${appName}`);
    }

    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.start(app, (err, process) => {
            if (err) return reject(err);
            resolve(formatProcess(process[0] || process));
        });
    });
}

/**
 * 启动进程
 */
async function start(nameOrConfig) {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.start(nameOrConfig, (err, process) => {
            if (err) return reject(err);
            resolve(formatProcess(process[0] || process));
        });
    });
}

/**
 * 停止进程
 */
async function stop(name) {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.stop(name, (err, process) => {
            if (err) return reject(err);
            resolve(formatProcess(process[0] || process));
        });
    });
}

/**
 * 重启进程
 */
async function restart(name) {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.restart(name, (err, process) => {
            if (err) return reject(err);
            resolve(formatProcess(process[0] || process));
        });
    });
}

/**
 * 删除进程
 */
async function deleteProcess(name) {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.delete(name, (err) => {
            if (err) return reject(err);
            resolve({ success: true });
        });
    });
}

/**
 * 获取进程详情（含配置来源识别）
 */
async function describe(name) {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.describe(name, (err, processList) => {
            if (err) return reject(err);
            if (!processList || processList.length === 0) {
                return reject(new Error(`Process '${name}' not found`));
            }
            const proc = formatProcess(processList[0]);
            // 单进程也带配置来源信息
            const enhanced = addConfigSource([proc]);
            resolve(enhanced[0]);
        });
    });
}

/**
 * 获取日志
 */
async function getLogs(name, lines = 100) {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.getLogs(
            { identity: null, max_size: lines * 1024, process_name: name || 'all' },
            (err, data) => {
                if (err) return reject(err);
                resolve({
                    out: data.data,
                    err: data.err,
                });
            }
        );
    });
}

/**
 * 清空日志
 */
async function flush() {
    await ensureConnect();
    return new Promise((resolve, reject) => {
        pm2.flush((err) => {
            if (err) return reject(err);
            resolve({ success: true });
        });
    });
}

/**
 * 从 process args 中提取端口号
 * 支持 --port 42069 / --port=42069 / -p 42069 / -l 7373 / --listen 7373
 * 也支持命令字符串中内嵌（如 bash -c "uvicorn ... --port 18920"）
 */
function extractPortFromArgs(args) {
    if (!args || !Array.isArray(args)) return null;
    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        // --port=42069 或 --listen=7373
        const eq = arg.match(/^(?:--port|--listen)=(\d{1,5})$/);
        if (eq) return eq[1];
        // -p=42069
        const short = arg.match(/^-p=(\d{1,5})$/);
        if (short) return short[1];
        // --port 42069 / --listen 7373 / -p 42069 / -l 7373 (next arg is port)
        if (((arg === '--port' || arg === '--listen' || arg === '-p' || arg === '-l') && i + 1 < args.length)
            && /^\d{1,5}$/.test(args[i + 1])) {
            return args[i + 1];
        }
        // 命令字符串中内嵌 --port=xxxx 或 --port xxxx
        const match = arg.match(/--port[=\s]+(\d{2,5})/);
        if (match) return match[1];
        // 命令字符串中内嵌 --listen=xxxx 或 --listen xxxx
        const matchListen = arg.match(/--listen[=\s]+(\d{2,5})/);
        if (matchListen) return matchListen[1];
        // 命令字符串中内嵌 -l xxxx
        const matchL = arg.match(/-l[=\s]+(\d{2,5})/);
        if (matchL) return matchL[1];
        // 命令字符串中内嵌 -p xxxx（但要小心不是 -p setup.py 这种情况）
        const matchShortArg = arg.match(/-p[=\s]+(\d{2,5})/);
        if (matchShortArg) return matchShortArg[1];
        // python -m http.server PORT 模式
        if (arg === 'http.server' && i + 1 < args.length && /^\d{2,5}$/.test(args[i + 1])) {
            return args[i + 1];
        }
    }
    return null;
}

/**
 * 加载单个 ecosystem config 文件
 * 返回 { file: string, apps: [...] }
 */
function loadSingleEcosystemConfig(configPath) {
    try {
        if (!fs.existsSync(configPath)) return { file: configPath, apps: [] };

        const stat = fs.lstatSync(configPath);
        let actualPath = configPath;
        if (stat.isSymbolicLink()) {
            actualPath = path.resolve(path.dirname(configPath), fs.readlinkSync(configPath));
        }
        if (!fs.existsSync(actualPath)) return { file: configPath, apps: [] };

        delete require.cache[require.resolve(actualPath)];
        const config = require(actualPath);

        const configDir = path.dirname(actualPath);
        const xmRoot = path.join(os.homedir(), 'Projects', 'XM');
        const pm2Home = path.join(os.homedir(), '.pm2');

        const apps = (config.apps || []).map(app => {
            let cwd = app.cwd || '';
            if (!cwd) return appInfo(app, '');

            if (path.isAbsolute(cwd)) return appInfo(app, cwd);

            const candidates = [
                path.resolve(configDir, cwd),
                path.resolve(pm2Home, cwd),
                path.resolve(xmRoot, cwd),
            ];

            let resolved = candidates[0];
            for (const candidate of candidates) {
                if (fs.existsSync(candidate)) { resolved = candidate; break; }
            }

            return appInfo(app, resolved);
        });

        return { file: configPath, apps };
    } catch (err) {
        logger.error(`Failed to load ${configPath}:`, err.message);
        return { file: configPath, apps: [] };
    }
}

function appInfo(app, cwd) {
    return {
        name: app.name || '',
        cwd,
        script: app.script || '',
        args: Array.isArray(app.args) ? app.args.join(' ') : (app.args || ''),
        envPort: app.env?.PORT || null,
    };
}

/**
 * 加载所有 ecosystem config 文件
 */
function loadAllEcosystemConfigs() {
    if (ecosystemCache.loadedAt && Date.now() - ecosystemCache.loadedAt < 5000) {
        return ecosystemCache.apps;
    }

    const paths = getEcosystemPaths();
    const allApps = [];

    for (const configPath of paths) {
        const { file, apps } = loadSingleEcosystemConfig(configPath);
        for (const app of apps) {
            // 同一进程名取第一个匹配的配置（主配置优先）
            if (!allApps.find(a => a.name === app.name)) {
                allApps.push({ ...app, configFile: file });
            }
        }
    }

    ecosystemCache = { apps: allApps, loadedAt: Date.now() };
    return allApps;
}

/**
 * 为进程列表添加 configSource 字段
 * 比对所有已知 ecosystem config 文件确定来源
 */
function addConfigSource(processes) {
    const allEcosystemApps = loadAllEcosystemConfigs();
    const ecoMap = {};
    for (const app of allEcosystemApps) {
        if (!ecoMap[app.name]) {
            ecoMap[app.name] = app;
        }
    }

    return processes.map(proc => {
        if (proc.name === 'pm2-dashboard') {
            return { ...proc, configSource: 'pm2_http_server.js', configMatch: 'self', configFile: null };
        }

        const ecoApp = ecoMap[proc.name];
        if (!ecoApp) {
            return { ...proc, configSource: '手动启动 / dump.pm2', configMatch: 'manual', configFile: null };
        }

        // 检查 PM2 实际使用的 cwd 是否存在
        const pm2Cwd = proc.pmCwd || proc.script || '';
        const cwdExists = pm2Cwd && fs.existsSync(pm2Cwd);

        // 生成简短的文件名显示
        const shortFile = ecoApp.configFile
            ? ecoApp.configFile.replace(os.homedir(), '~')
            : 'ecosystem.config.js';

        if (cwdExists) {
            return {
                ...proc,
                configSource: 'ecosystem.config.js',
                configMatch: 'exact',
                configFile: shortFile,
            };
        }

        return {
            ...proc,
            configSource: 'ecosystem.config.js (路径失效)',
            configMatch: 'broken',
            configFile: shortFile,
            configCwd: ecoApp.cwd,
        };
    });
}

/**
 * 强制刷新 ecosystem config 缓存
 */
function refreshEcosystemCache() {
    ecosystemCache = { apps: [], loadedAt: 0 };
}

/**
 * 格式化进程数据
 */
function formatProcess(p) {
    if (!p) return null;
    return {
        name: p.name,
        pid: p.pid,
        pmId: p.pm_id,
        status: p.pm2_env?.status || 'unknown',
        cpu: p.monit?.cpu || 0,
        memory: p.monit?.memory || 0,
        memoryHuman: formatBytes(p.monit?.memory || 0),
        restarts: p.pm2_env?.restart_time || 0,
        uptime: p.pm2_env?.pm_uptime ? Date.now() - p.pm2_env.pm_uptime : 0,
        uptimeHuman: formatUptime(p.pm2_env?.pm_uptime ? Date.now() - p.pm2_env.pm_uptime : 0),
        createdAt: p.pm2_env?.created_at ? new Date(p.pm2_env.created_at).toISOString() : null,
        interpreter: p.pm2_env?.exec_interpreter || '',
        script: p.pm2_env?.exec_cwd || '',
        pmCwd: p.pm2_env?.pm_cwd || '',
        port: p.pm2_env?.env?.PORT || extractPortFromArgs(p.pm2_env?.args) || null,
    };
}

/**
 * 格式化字节数
 */
function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

/**
 * 格式化运行时长
 */
function formatUptime(ms) {
    if (!ms || ms <= 0) return '0s';
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ${hours % 24}h`;
    if (hours > 0) return `${hours}h ${minutes % 60}m`;
    if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
    return `${seconds}s`;
}

/**
 * 断开连接
 */
function disconnect() {
    if (connected) {
        pm2.disconnect();
        connected = false;
        logger.info('PM2 disconnected');
    }
}

// ─────────────────────────────────────────────
// Ecosystem 配置路径管理
// ─────────────────────────────────────────────

/**
 * 获取所有 ecosystem config 路径（主配置 + 额外配置）
 */
function getEcosystemPaths() {
    const paths = [ECOSYSTEM_CONFIG_PATH];
    try {
        if (fs.existsSync(ECOSYSTEM_PATHS_FILE)) {
            const extra = JSON.parse(fs.readFileSync(ECOSYSTEM_PATHS_FILE, 'utf8'));
            if (Array.isArray(extra)) {
                for (const p of extra) {
                    // 展开 ~ 和相对路径
                    let resolved = p;
                    if (resolved.startsWith('~')) {
                        resolved = path.join(os.homedir(), resolved.slice(1));
                    }
                    if (!path.isAbsolute(resolved)) {
                        resolved = path.resolve(resolved);
                    }
                    if (fs.existsSync(resolved) && !paths.includes(resolved)) {
                        paths.push(resolved);
                    }
                }
            }
        }
    } catch (e) {
        logger.error('Failed to load ecosystem paths:', e.message);
    }
    return paths;
}

/**
 * 添加额外 ecosystem config 路径
 */
function addEcosystemPath(filePath) {
    let resolved = filePath;
    if (resolved.startsWith('~')) {
        resolved = path.join(os.homedir(), resolved.slice(1));
    }
    if (!path.isAbsolute(resolved)) {
        resolved = path.resolve(resolved);
    }
    if (!fs.existsSync(resolved)) {
        throw new Error(`文件不存在: ${resolved}`);
    }
    if (resolved === ECOSYSTEM_CONFIG_PATH) {
        throw new Error('主配置文件已在列表中');
    }

    let paths = [];
    try {
        if (fs.existsSync(ECOSYSTEM_PATHS_FILE)) {
            paths = JSON.parse(fs.readFileSync(ECOSYSTEM_PATHS_FILE, 'utf8')) || [];
        }
    } catch (e) { /* ignore */ }

    if (paths.includes(filePath)) {
        return { existed: true, path: resolved };
    }

    paths.push(filePath);
    fs.writeFileSync(ECOSYSTEM_PATHS_FILE, JSON.stringify(paths, null, 2));
    refreshEcosystemCache();
    return { existed: false, path: resolved };
}

/**
 * 移除额外 ecosystem config 路径
 */
function removeEcosystemPath(filePath) {
    let paths = [];
    try {
        if (fs.existsSync(ECOSYSTEM_PATHS_FILE)) {
            paths = JSON.parse(fs.readFileSync(ECOSYSTEM_PATHS_FILE, 'utf8')) || [];
        }
    } catch (e) { return false; }

    const idx = paths.indexOf(filePath);
    if (idx === -1) return false;

    paths.splice(idx, 1);
    fs.writeFileSync(ECOSYSTEM_PATHS_FILE, JSON.stringify(paths, null, 2));
    refreshEcosystemCache();
    return true;
}

/**
 * 列出所有额外 ecosystem config 路径
 */
function listEcosystemPaths() {
    try {
        if (fs.existsSync(ECOSYSTEM_PATHS_FILE)) {
            const paths = JSON.parse(fs.readFileSync(ECOSYSTEM_PATHS_FILE, 'utf8')) || [];
            return paths.map(p => {
                let resolved = p;
                if (resolved.startsWith('~')) resolved = path.join(os.homedir(), resolved.slice(1));
                const config = loadSingleEcosystemConfig(resolved);
                return {
                    path: p,
                    resolved,
                    exists: fs.existsSync(resolved),
                    apps: config.apps.map(a => ({
                        name: a.name,
                        script: a.script,
                        cwd: a.cwd,
                        port: a.envPort,
                    })),
                };
            });
        }
    } catch (e) { /* ignore */ }
    return [];
}

module.exports = {
    connect,
    ensureConnect,
    list,
    start,
    stop,
    restart,
    delete: deleteProcess,
    describe,
    getLogs,
    flush,
    disconnect,
    refreshEcosystemCache,
    loadEcosystemConfig: loadAllEcosystemConfigs,
    getEcosystemPaths,
    addEcosystemPath,
    removeEcosystemPath,
    listEcosystemPaths,
    getAvailableApps,
    startEcosystemApp,
};
