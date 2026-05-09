# Node.js 编码规范

## PM2 封装层契约

### 输出格式

| 场景 | 输出目标 | 格式 |
|------|----------|------|
| 成功 | stdout | JSON（对象或数组） |
| 错误 | stderr | `JSON.stringify({ error: "message" })` |
| 调试 | 文件 | `debugLog()` → `/tmp/visual-pm2-wrapper.log` |

### 强制规则

1. **全局异常捕获**: 启动时必须注册 `uncaughtException` 和 `unhandledRejection` 处理，输出 `{ error: message }` JSON 到 stderr 后 `exit(1)`
2. **PM2 连接生命周期**: `connect()` → 执行 → `disconnect()` + `process.exit()`。**所有路径必须断开连接**，否则 PM2 daemon 积累孤儿连接
3. **`require.cache` 清理**: 加载外部配置文件前必须清除缓存: `delete require.cache[require.resolve(path)]`

## 代码约定

- 使用 `const` / `let`（禁止 `var`）
- 异步操作使用 async/await（IIFE 包装）
- 文件名: kebab-case（`pm2_wrapper.js`）
- 字符串使用单引号
- 缩进: 2 空格

## 命令实现模式

**同步回调模式**（stop/restart/delete/save/flush）:

```javascript
pm2[command](args[0], (err) => {
    if (err) console.error(JSON.stringify({ error: err.message }))
    else console.log(JSON.stringify({ success: true }))
    pm2.disconnect()
    process.exit(err ? 1 : 0)
})
```

**异步 IIFE 模式**（start/scan/start-app）:

```javascript
(async () => {
    try {
        // 多步骤业务逻辑
        console.log(JSON.stringify({ success: true }))
        pm2.disconnect()
        process.exit(0)
    } catch (e) {
        console.error(JSON.stringify({ error: e.message }))
        pm2.disconnect()
        process.exit(1)
    }
})()
```

## 端口匹配优先级

`extractPortFromArgs()` 中模式匹配顺序（从最具体到最不具体）:

1. `--port N` → uvicorn/fastapi
2. `http.server` → Python HTTP server
3. `-l N` / `--listen N` → npx serve
4. `-p N` → 通用简写
5. `server.port=N` → Streamlit

先匹配长选项避免短选项误匹配。
