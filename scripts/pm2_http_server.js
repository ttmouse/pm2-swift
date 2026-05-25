#!/usr/bin/env node
/**
 * PM2 Web Dashboard HTTP Server
 *
 * 职责：
 * 1. 启动 Express HTTP 服务
 * 2. 启动 WebSocket 服务（共用同一端口）
 * 3. 加载路由和中间件
 * 4. 错误处理与日志记录
 */

'use strict';

const express = require('express');
const { WebSocketServer } = require('ws');
const http = require('http');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const PORT = process.env.PM2_DASHBOARD_PORT || 4321;
const HOST = process.env.PM2_DASHBOARD_HOST || '127.0.0.1';
const STATIC_DIR = path.join(__dirname, '../web/dist');
const VITE_DEV_PORT = 4322;
const isDev = process.env.VITE_DEV === 'true';

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// 中间件
app.use(express.json());

// API 路由
app.use('/api/processes', require('./server/routes/processes'));
app.use('/api/logs', require('./server/routes/logs'));
app.use('/api/metrics', require('./server/routes/metrics'));
app.use('/api/config', require('./server/routes/config'));

// 未匹配的 API 路径返回 JSON 404（放在静态资源之前，避免被 SPA 吞掉）
app.use('/api', (req, res) => {
    res.status(404).json({ error: 'API endpoint not found', code: 'NOT_FOUND' });
});

if (isDev) {
    // 开发模式：非 API/WS 请求代理到 Vite 开发服务器（提供 HMR）
    console.log(`[dev] Proxying frontend requests to Vite dev server at :${VITE_DEV_PORT}`);
    app.use(createProxyMiddleware({
        target: `http://127.0.0.1:${VITE_DEV_PORT}`,
        changeOrigin: true,
        ws: true,
    }));
} else {
    // 生产模式：提供构建后的静态文件
    app.use(express.static(STATIC_DIR, {
        maxAge: '1h',
        etag: true,
        lastModified: true,
    }));

    // SPA 降级 — 未匹配 GET 请求返回 index.html
    app.get('*', (req, res) => {
        res.sendFile(path.join(STATIC_DIR, 'index.html'));
    });

    // 非 GET 未匹配路径返回 404
    app.use((req, res) => {
        res.status(404).json({ error: 'Not found' });
    });
}

// 全局错误处理 — 放在最后，确保捕获所有下游路由/中间件的错误
app.use(require('./server/middleware/error-handler'));

// WebSocket 路由分发
wss.on('connection', (ws, req) => {
    const urlObj = new URL(req.url, `http://${req.headers.host}`);
    const pathname = urlObj.pathname;

    if (pathname.startsWith('/ws/logs/')) {
        const processName = pathname.replace('/ws/logs/', '');
        require('./server/websocket/log-stream').handle(ws, req, processName);
    } else if (pathname === '/ws/metrics') {
        require('./server/websocket/metrics-stream').handle(ws, req);
    } else {
        ws.close(1008, 'Unknown WebSocket path');
    }
});

// 全局异常捕获
process.on('uncaughtException', (err) => {
    console.error('Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

server.listen(PORT, HOST, () => {
    console.log(`PM2 Dashboard running at http://${HOST}:${PORT}`);
});

module.exports = { app, server, wss };
