---
trigger: model_decision
description: Node.js PM2 封装层契约（输出格式、全局异常捕获、PM2 连接生命周期），代码约定，命令实现模式（同步/异步），端口匹配顺序规则。
---
# Node.js 编码规范

## PM2 封装层契约

### 输出格式

所有命令必须遵守统一的输出格式：

| 场景 | 输出目标 | 格式 |
|------|----------|------|
| 成功 | stdout | JSON（可以是对象或数组） |
| 错误 | stderr | `JSON.stringify({ error: "message" })` |
| 调试 | 文件 | `debugLog()` → `/tmp/visual-pm2-wrapper.log` |

### 强制规则

1. **全局异常捕获**
   ```javascript
   process.on('uncaughtException', (err) => {
     console.error(JSON.stringify({ error: err.message }));
     try { pm2.disconnect(); } catch (_) {}
     process.exit(1);
   });
   process.on('unhandledRejection', (reason) => { ... });
   ```

2. **PM2 连接生命周期**
   - 命令开始时 `pm2.connect()`
   - 命令结束时 `pm2.disconnect()` + `process.exit()`
   - 所有路径（成功/错误/异常）必须断开连接

3. **`require.cache` 清理**
   - 加载配置文件前必须清除缓存：`delete require.cache[require.resolve(path)]`

## 代码约定

- 使用 `const` / `let`（禁止 `var`）
- 异步操作使用 async/await（IIFE 包装）
- 文件名: kebab-case（`pm2_wrapper.js`）
- 字符串使用单引号
- 缩进: 2 空格

## 命令实现模式

### 同步回调模式（stop/restart/delete/save/flush）
```javascript
case 'stop':
  pm2[command](args[0], (err) => {
    if (err) { console.error(JSON.stringify({ error: err.message })); }
    else { console.log(JSON.stringify({ success: true })); }
    pm2.disconnect();
    process.exit(err ? 1 : 0);
  });
```

### 异步模式（start/scan/start-app）
```javascript
case 'start':
  (async () => {
    try {
      // ... 业务逻辑
      console.log(JSON.stringify({ success: true }));
      pm2.disconnect();
      process.exit(0);
    } catch (e) {
      console.error(JSON.stringify({ error: e.message }));
      pm2.disconnect();
      process.exit(1);
    }
  })();
```

## 端口匹配顺序

在 `extractPortFromArgs()` 中，模式匹配必须从最具体到最不具体：
1. `--port`（uvicorn/fastapi）
2. `http.server`（Python HTTP server）
3. `-l`/`--listen`（npx serve）
4. `-p` 简写
5. `server.port`（Streamlit）
