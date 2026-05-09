const pm2 = require('pm2');
const fs = require('fs');
const path = require('path');

const ECOSYSTEM_CONFIG_PATH = '/Users/douba/.pm2/ecosystem.config.js';

process.on('exit', () => { try { pm2.disconnect(); } catch (_) {} });

// 项目目录配置 - 扫描这些目录下的 pm2.config.js
const PROJECT_DIRS = [
  '/Users/douba/Projects/XM/project',
  '/Users/douba/Projects/XM/AI工作区',
  '/Users/douba/Projects/XM/telegram_ops_bot',
];

function debugLog(message) {
  try {
    fs.appendFileSync('/tmp/visual-pm2-wrapper.log', `${new Date().toISOString()} ${message}\n`);
  } catch (_) {}
}

const command = process.argv[2];
const args = process.argv.slice(3);

// 全局未捕获异常处理：确保始终输出 JSON 错误
process.on('uncaughtException', (err) => {
  console.error(JSON.stringify({ error: err.message || 'Unknown error' }));
  try { pm2.disconnect(); } catch (_) {}
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  const message = reason instanceof Error ? reason.message : String(reason);
  console.error(JSON.stringify({ error: message }));
  try { pm2.disconnect(); } catch (_) {}
  process.exit(1);
});

function normalizePort(value) {
  const port = Number(value);
  if (Number.isInteger(port) && port > 0 && port < 65536) return port;
  return null;
}

function normalizeArgs(args) {
  if (args === null || args === undefined) return [];
  if (Array.isArray(args)) return args;
  if (typeof args === 'string') return args.split(' ').filter(s => s.length > 0);
  return [];
}

function extractPortFromArgs(args) {
  const argText = Array.isArray(args) ? args.join(' ') : String(args || '');
  if (!argText) return null;

  // 模式匹配顺序很重要：从最具体到最不具体
  const patterns = [
    // uvicorn/fastapi 格式: --port 18920 或 --port=18920
    /--port[=\s]+(\d{4,5})/i,
    // 独立格式: python -m http.server 3456
    /\bhttp\.server\s+(\d{4,5})\b/i,
    // npx serve 格式: -l 7373 或 --listen 7373
    /(?:-(?:l|listen)|--(?:listen))\s+(\d{4,5})\b/i,
    // 简写 -p: uvicorn main:app -p 8000
    /(?<![-\w])-(?:p|port)\s+(\d{4,5})\b/i,
    // Streamlit: server.port 格式
    /server\.port[=\s]+(\d{4,5})/i,
  ];

  for (const pattern of patterns) {
    const match = argText.match(pattern);
    if (match && match[1]) {
      const port = normalizePort(match[1]);
      if (port !== null) {
        return port;
      }
    }
  }
  return null;
}

function categorizeApp(name) {
  if (name.includes('-api') || name.includes('-backend') || name.includes('api')) return 'API';
  if (name.includes('-frontend') || name.includes('-client') || name.includes('web')) return 'Frontend';
  if (name.includes('-bot') || name.includes('telegram') || name.includes('bot')) return 'Bot';
  if (name.includes('-monitor') || name.includes('guardian') || name.includes('monitor')) return 'Monitor';
  if (name.includes('game') || name.includes('pk')) return 'Game';
  return 'Other';
}

let portMapCache = { map: null, mtime: 0, ttl: 5000 };

function buildEcosystemPortMap() {
  const now = Date.now();
  if (portMapCache.map !== null && (now - portMapCache.mtime) < portMapCache.ttl) {
    return portMapCache.map;
  }

  try {
    const resolvedPath = path.resolve(ECOSYSTEM_CONFIG_PATH);
    delete require.cache[require.resolve(resolvedPath)];
    const ecosystemConfig = require(resolvedPath);
    const apps = Array.isArray(ecosystemConfig?.apps) ? ecosystemConfig.apps : [];
    const result = new Map();

    for (const app of apps) {
      if (!app || !app.name) continue;
      const env = app.env || {};
      const port = [env.PORT, env.port, env.VITE_PORT, env.UVICORN_PORT, env.HTTP_PORT]
        .map(normalizePort)
        .find(v => v !== null) ?? extractPortFromArgs(app.args);
      if (port !== null) result.set(app.name, port);
    }
    portMapCache = { map: result, mtime: now, ttl: 5000 };
    return result;
  } catch (error) {
    debugLog(`ecosystem_parse_error=${error.message}`);
    return new Map();
  }
}

pm2.connect((err) => {
  debugLog(`command=${command} args=${JSON.stringify(args)}`);
  if (err) {
    debugLog(`connect_error=${err.message}`);
    console.error(JSON.stringify({ error: err.message }));
    pm2.disconnect(() => process.exit(1));
  }

  switch (command) {
    case 'list':
      pm2.list((err, runningList) => {
        debugLog(`list_start runningCount=${runningList?.length || 'undefined'}`);
        if (err) {
          console.error(JSON.stringify({ error: err.message }));
          pm2.disconnect();
          process.exit(1);
        }
        
        const ecosystemPortMap = buildEcosystemPortMap();
        const runningMap = new Map(runningList.map(p => [p.name, p]));
        
        // 获取 ecosystem.config.js 中定义的所有项目
        let ecosystemApps = [];
        try {
          const resolvedPath = path.resolve(ECOSYSTEM_CONFIG_PATH);
          debugLog(`ecosystem_path=${resolvedPath}`);
          delete require.cache[resolvedPath];
          const ecosystemConfig = require(resolvedPath);
          ecosystemApps = Array.isArray(ecosystemConfig?.apps) ? ecosystemConfig.apps : [];
          debugLog(`ecosystem_apps_count=${ecosystemApps.length}`);
        } catch (e) {
          debugLog(`ecosystem_load_error=${e.message}`);
        }
        
        const projects = [];
        
        // 先添加 ecosystem.config.js 中定义的所有项目
        for (const app of ecosystemApps) {
          if (!app || !app.name) continue;
          
          const running = runningMap.get(app.name);
          
          if (running) {
            // 运行中的项目，使用实时数据
            projects.push({
              id: running.name,
              name: running.name,
              pid: running.pid || null,
              status: running.pm2_env.status,
              cpu: running.monit?.cpu || 0,
              memory: (running.monit?.memory || 0) / (1024 * 1024),
              uptime: running.pm2_env.pm_uptime ? Math.floor((Date.now() - running.pm2_env.pm_uptime) / 1000) : 0,
              restarts: running.pm2_env.restart_time || 0,
              port: ecosystemPortMap.get(running.name) || null,
              url: null,
              host: 'localhost',
              logPath: running.pm2_env.pm_err_log_path || null,
              outPath: running.pm2_env.pm_out_log_path || null,
              errorPath: running.pm2_env.pm_err_log_path || null,
              category: categorizeApp(running.name),
              projectPath: running.pm2_env.cwd || running.pm2_env.pm_cwd || app.cwd || '',
              interpreter: running.pm2_env.interpreter || null,
              script: running.pm2_env.pm_exec_path || null,
              args: normalizeArgs(running.pm2_env.args),
              tags: null,
              notes: null,
              autoStart: true,
              priority: null
            });
          } else {
            // 未运行但配置中存在的项目
            projects.push({
              id: app.name,
              name: app.name,
              pid: null,
              status: 'stopped',
              cpu: 0,
              memory: 0,
              uptime: 0,
              restarts: 0,
              port: ecosystemPortMap.get(app.name) || extractPortFromArgs(app.args) || null,
              url: null,
              host: 'localhost',
              logPath: app.error_file || null,
              outPath: app.out_file || null,
              errorPath: app.error_file || null,
              category: categorizeApp(app.name),
              projectPath: app.cwd || '',
              interpreter: app.interpreter || null,
              script: app.script || null,
              args: normalizeArgs(app.args),
              tags: null,
              notes: null,
              autoStart: true,
              priority: null
            });
          }
        }
        
        // 添加在 ecosystem.config.js 中不存在但 PM2 中正在运行的进程
        for (const running of runningList) {
          if (!ecosystemApps.some(a => a.name === running.name)) {
            projects.push({
              id: running.name,
              name: running.name,
              pid: running.pid || null,
              status: running.pm2_env.status,
              cpu: running.monit?.cpu || 0,
              memory: (running.monit?.memory || 0) / (1024 * 1024),
              uptime: running.pm2_env.pm_uptime ? Math.floor((Date.now() - running.pm2_env.pm_uptime) / 1000) : 0,
              restarts: running.pm2_env.restart_time || 0,
              port: ecosystemPortMap.get(running.name) || null,
              url: null,
              host: 'localhost',
              logPath: running.pm2_env.pm_err_log_path || null,
              outPath: running.pm2_env.pm_out_log_path || null,
              errorPath: running.pm2_env.pm_err_log_path || null,
              category: categorizeApp(running.name),
              projectPath: running.pm2_env.cwd || running.pm2_env.pm_cwd || '',
              interpreter: running.pm2_env.interpreter || null,
              script: running.pm2_env.pm_exec_path || null,
              args: normalizeArgs(running.pm2_env.args),
              tags: null,
              notes: null,
              autoStart: null,
              priority: null
            });
          }
        }
        
        console.log(JSON.stringify(projects));
        pm2.disconnect();
      });
      break;

    case 'start':
      // 支持两种格式：
      // 1. start <config-file-path> - 从配置文件启动所有应用
      // 2. start <project-name> - 从默认配置启动指定项目
      (async () => {
        try {
          const target = args[0];
          
          if (!target) {
            console.error(JSON.stringify({ error: 'Target required' }));
            pm2.disconnect();
            process.exit(1);
          }
          
          // 检查是否是文件路径
          if (fs.existsSync(path.resolve(target))) {
            // 启动配置文件中的所有应用
            const configPath = path.resolve(target);
            const configDir = path.dirname(configPath);
            const config = require(configPath);
            const apps = Array.isArray(config?.apps) ? config.apps : [];
            
            const list = await new Promise((resolve, reject) => {
              pm2.list((err, list) => err ? reject(err) : resolve(list));
            });
            const existingNames = new Set(list.map(p => p.name).filter(Boolean));
            
            const results = [];
            for (const app of apps) {
              if (!app || !app.name) continue;
              
              if (existingNames.has(app.name)) {
                results.push({ name: app.name, skipped: true, reason: 'already_running' });
                continue;
              }
              
              // 将相对路径解析为绝对路径（基于配置文件所在目录）
              const resolvedApp = { ...app };
              if (resolvedApp.cwd && !path.isAbsolute(resolvedApp.cwd)) {
                resolvedApp.cwd = path.resolve(configDir, resolvedApp.cwd);
              }
              if (resolvedApp.error_file && !path.isAbsolute(resolvedApp.error_file)) {
                resolvedApp.error_file = path.resolve(configDir, resolvedApp.error_file);
              }
              if (resolvedApp.out_file && !path.isAbsolute(resolvedApp.out_file)) {
                resolvedApp.out_file = path.resolve(configDir, resolvedApp.out_file);
              }
              
              try {
                // pm2.start(cmd, opts, cb) 使用回调模式，不返回 Promise
                await new Promise((resolve, reject) => {
                  pm2.start(resolvedApp, (err, procs) => {
                    if (err) reject(err);
                    else resolve(procs);
                  });
                });
                results.push({ name: app.name, started: true });
              } catch (e) {
                results.push({ name: app.name, error: e.message });
              }
            }
            
            console.log(JSON.stringify({ success: true, results }));
          } else {
            // 尝试作为项目名称处理，从 ecosystem.config.js 查找
            const projectName = target;
            
            // 加载 ecosystem 配置
            let ecosystemApps = [];
            try {
              const ecosystemConfig = require(ECOSYSTEM_CONFIG_PATH);
              ecosystemApps = Array.isArray(ecosystemConfig?.apps) ? ecosystemConfig.apps : [];
            } catch (e) {
              console.error(JSON.stringify({ error: 'Failed to load ecosystem config: ' + e.message }));
              pm2.disconnect();
              process.exit(1);
            }
            
            // 查找指定项目
            const app = ecosystemApps.find(a => a && a.name === projectName);
            if (!app) {
              console.error(JSON.stringify({ error: 'Project not found: ' + projectName }));
              pm2.disconnect();
              process.exit(1);
            }
            
            // 直接启动，不需要检查已存在（PM2 start 会自动处理）
            // pm2.start(cmd, opts, cb) 使用回调模式，不返回 Promise
            // 将相对路径解析为绝对路径（基于 ecosystem config 所在目录）
            const resolvedApp = { ...app };
            const ecosystemDir = path.dirname(path.resolve(ECOSYSTEM_CONFIG_PATH));
            if (resolvedApp.cwd && !path.isAbsolute(resolvedApp.cwd)) {
              resolvedApp.cwd = path.resolve(ecosystemDir, resolvedApp.cwd);
            }
            if (resolvedApp.error_file && !path.isAbsolute(resolvedApp.error_file)) {
              resolvedApp.error_file = path.resolve(ecosystemDir, resolvedApp.error_file);
            }
            if (resolvedApp.out_file && !path.isAbsolute(resolvedApp.out_file)) {
              resolvedApp.out_file = path.resolve(ecosystemDir, resolvedApp.out_file);
            }
            await new Promise((resolve, reject) => {
              pm2.start(resolvedApp, (err, procs) => {
                if (err) reject(err);
                else resolve(procs);
              });
            });
            
            console.log(JSON.stringify({ success: true, name: projectName, started: true }));
          }
          
          pm2.disconnect();
          process.exit(0);
        } catch (e) {
          console.error(JSON.stringify({ error: e.message }));
          pm2.disconnect();
          process.exit(1);
        }
      })();
      break;

    case 'stop':
    case 'restart':
    case 'delete':
      pm2[command](args[0], (err) => {
        if (err) {
          console.error(JSON.stringify({ error: err.message }));
        } else {
          console.log(JSON.stringify({ success: true }));
        }
        pm2.disconnect();
        process.exit(err ? 1 : 0);
      });
      break;

    case 'logs':
      const [processName, lines = '100'] = args;
      pm2.describe(processName, (err, process) => {
        if (err || !process || process.length === 0) {
          console.error(JSON.stringify({ error: err?.message || 'Process not found' }));
          pm2.disconnect();
          process.exit(1);
        }
        
        const proc = process[0];
        const readLog = (logPath) => {
          if (!logPath || !fs.existsSync(logPath)) return '';
          try {
            const content = fs.readFileSync(logPath, 'utf8');
            return content.split('\n').slice(-parseInt(lines)).join('\n');
          } catch (e) {
            return `[Error reading ${logPath}]: ${e.message}`;
          }
        };
        
        const outLog = readLog(proc.pm2_env.pm_out_log_path);
        const errLog = readLog(proc.pm2_env.pm_err_log_path);
        const timestamp = new Date().toISOString().substring(0, 19).replace('T', ' ');
        
        console.log([
          `${timestamp} [INFO] === STDOUT ===`,
          outLog || '(No output)',
          `${timestamp} [ERROR] === STDERR ===`,
          errLog || '(No errors)'
        ].join('\n\n'));
        pm2.disconnect();
      });
      break;

    case 'flush':
      pm2.flush((err) => {
        if (err) console.error(JSON.stringify({ error: err.message }));
        else console.log(JSON.stringify({ success: true }));
        pm2.disconnect();
        process.exit(err ? 1 : 0);
      });
      break;

    case 'save':
      pm2.dump((err) => {
        if (err) console.error(JSON.stringify({ error: err.message }));
        else console.log(JSON.stringify({ success: true }));
        pm2.disconnect();
        process.exit(err ? 1 : 0);
      });
      break;

    // 扫描项目目录，发现新的 PM2 配置
    case 'scan':
      (async () => {
        try {
          const list = await new Promise((resolve, reject) => {
            pm2.list((err, list) => err ? reject(err) : resolve(list));
          });
          const existingNames = new Set(list.map(p => p.name).filter(Boolean));
          const discoveredApps = [];
          
          for (const dir of PROJECT_DIRS) {
            const expandedDir = dir.startsWith('~') ? dir.replace('~', process.env.HOME || '') : dir;
            if (!fs.existsSync(expandedDir)) continue;
            
            const subdirs = fs.readdirSync(expandedDir, { withFileTypes: true })
              .filter(d => d.isDirectory())
              .map(d => d.name);
            
            for (const subdir of subdirs) {
              const projectPath = path.join(expandedDir, subdir);
              const configPath = path.join(projectPath, 'pm2.config.js');
              
              if (!fs.existsSync(configPath)) continue;
              
              try {
                delete require.cache[require.resolve(configPath)];
                const config = require(configPath);
                const apps = Array.isArray(config?.apps) ? config.apps : [];
                
                for (const app of apps) {
                  if (!app || !app.name) continue;
                  if (existingNames.has(app.name)) continue;
                  
                  const env = app.env || {};
                  const port = env.PORT || env.port || extractPortFromArgs(app.args) || null;
                  
                  discoveredApps.push({
                    name: app.name,
                    configPath: configPath,
                    projectPath: projectPath,
                    script: app.script || null,
                    port: port ? Number(port) : null,
                    category: categorizeApp(app.name),
                  });
                }
              } catch (e) {
                debugLog(`scan_config_error=${configPath} ${e.message}`);
              }
            }
          }
          
          console.log(JSON.stringify({ success: true, apps: discoveredApps }));
          pm2.disconnect();
          process.exit(0);
        } catch (e) {
          console.error(JSON.stringify({ error: e.message }));
          pm2.disconnect();
          process.exit(1);
        }
      })();
      break;

    // 启动单个应用（从发现的配置中）
    case 'start-app':
      (async () => {
        try {
          const configPath = args[0];
          const appName = args[1];
          
          if (!configPath || !appName) {
            console.error(JSON.stringify({ error: 'configPath and appName required' }));
            pm2.disconnect();
            process.exit(1);
          }
          
          const config = require(path.resolve(configPath));
          const apps = Array.isArray(config?.apps) ? config.apps : [];
          const app = apps.find(a => a && a.name === appName);
          
          if (!app) {
            console.error(JSON.stringify({ error: `App ${appName} not found` }));
            pm2.disconnect();
            process.exit(1);
          }
          
          await new Promise((resolve, reject) => {
            pm2.start(app, (err) => err ? reject(err) : resolve());
          });
          
          console.log(JSON.stringify({ success: true, name: appName }));
          pm2.disconnect();
          process.exit(0);
        } catch (e) {
          console.error(JSON.stringify({ error: e.message }));
          pm2.disconnect();
          process.exit(1);
        }
      })();
      break;

    default:
      console.error(JSON.stringify({ error: 'Unknown command: ' + command }));
      pm2.disconnect();
      process.exit(1);
  }
});
