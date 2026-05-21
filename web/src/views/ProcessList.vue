<template>
    <div class="process-list">
        <!-- 工具栏 -->
        <div class="toolbar">
            <div class="search-wrap">
                <svg class="search-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
                </svg>
                <input
                    v-model="searchKeyword"
                    placeholder="搜索进程名称..."
                    class="search-input"
                    clearable
                />
            </div>

            <div class="filter-tabs">
                <button
                    v-for="tab in statusTabs"
                    :key="tab.value"
                    class="filter-tab"
                    :class="{ active: statusFilter === tab.value }"
                    @click="statusFilter = tab.value"
                >
                    <span class="tab-dot" :style="{ background: tab.color }" />
                    {{ tab.label }}
                    <span class="tab-count">{{ tab.count }}</span>
                </button>
            </div>

            <div class="toolbar-right">
                <button class="gen-prompt-btn" @click="showConfigPaths = true" title="管理 ecosystem 配置文件路径">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="3"/>
                        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                    </svg>
                    管理配置
                </button>
                <button class="gen-prompt-btn" @click="generateConfigPrompt" title="生成 PM2 配置 Prompt">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                        <polyline points="14 2 14 8 20 8"/>
                        <line x1="16" y1="13" x2="8" y2="13"/>
                        <line x1="16" y1="17" x2="8" y2="17"/>
                        <line x1="10" y1="9" x2="8" y2="9"/>
                    </svg>
                    生成配置 Prompt
                </button>
                <span class="total-label">共</span>
                <span class="total-num">{{ filteredList.length }}</span>
                <span class="total-label">个进程</span>
                <div class="ws-indicator" :class="store.wsConnected ? 'live' : 'dead'" :title="store.wsConnected ? 'WebSocket 已连接' : 'WebSocket 未连接'">
                    <span class="ws-dot" />
                    {{ store.wsConnected ? '实时' : '轮询' }}
                </div>
            </div>
        </div>

        <!-- 表格 -->
        <div class="table-wrap">
            <table class="data-table">
                <thead>
                    <tr>
                        <th class="col-name">名称</th>
                        <th class="col-status">状态</th>
                        <th class="col-port">端口</th>
                        <th class="col-source">来源</th>
                        <th class="col-mem sortable" @click="toggleSort('memory')">
                            内存
                            <SortIcon :field="'memory'" :sort="sort" />
                        </th>
                        <th class="col-restart sortable" @click="toggleSort('restarts')">
                            重启
                            <SortIcon :field="'restarts'" :sort="sort" />
                        </th>
                        <th class="col-uptime sortable" @click="toggleSort('uptime')">
                            运行时长
                            <SortIcon :field="'uptime'" :sort="sort" />
                        </th>
                        <th class="col-actions">操作</th>
                    </tr>
                </thead>
                <tbody>
                    <tr
                        v-for="row in filteredList"
                        :key="row.name"
                        class="data-row"
                        @click="goDetail(row.name)"
                    >
                        <td class="col-name">
                            <div class="name-wrap">
                                <span class="process-name">{{ row.name }}</span>
                                <button class="copy-btn" title="复制名称" @click.stop="copyName(row.name)">
                                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <rect x="9" y="9" width="13" height="13" rx="2"/>
                                        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                                    </svg>
                                </button>
                            </div>
                            <span class="process-pid">PID {{ row.pid || '—' }}</span>
                        </td>
                        <td class="col-status">
                            <StatusBadge :status="row.status" />
                        </td>
                        <td class="col-port mono">
                            <a
                                v-if="row.port"
                                :href="`http://localhost:${row.port}`"
                                target="_blank"
                                class="port-link"
                                @click.stop
                            >{{ row.port }}</a>
                            <span v-else class="muted">—</span>
                        </td>
                        <td class="col-source">
                            <span class="source-tag" :class="sourceClass(row)" :title="sourceTitle(row)">
                                {{ sourceLabel(row) }}
                            </span>
                        </td>
                        <td class="col-mem mono">{{ row.memoryHuman }}</td>
                        <td class="col-restart mono">
                            <span :class="row.restarts > 0 ? 'has-restarts' : ''">{{ row.restarts }}</span>
                        </td>
                        <td class="col-uptime mono muted">{{ row.uptimeHuman }}</td>
                        <td class="col-actions" @click.stop>
                            <ActionButtons :process="row" />
                        </td>
                    </tr>
                </tbody>
            </table>

            <!-- 空状态 -->
            <div v-if="!store.loading && filteredList.length === 0" class="empty-state">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-icon">
                    <rect x="2" y="3" width="20" height="14" rx="2"/>
                    <path d="M8 21h8M12 17v4"/>
                </svg>
                <p class="empty-title">{{ store.list.length === 0 ? '暂无 PM2 进程' : '无匹配结果' }}</p>
                <p class="empty-sub">{{ store.list.length === 0 ? '启动一个 PM2 进程，它将自动出现在这里' : '尝试调整筛选条件' }}</p>
            </div>

            <!-- Loading -->
            <div v-if="store.loading" class="loading-state">
                <div v-for="i in 5" :key="i" class="skeleton-row">
                    <div class="skeleton skeleton-name" />
                    <div class="skeleton skeleton-badge" />
                    <div class="skeleton skeleton-source" />
                    <div class="skeleton skeleton-mem" />
                    <div class="skeleton skeleton-restart" />
                    <div class="skeleton skeleton-uptime" />
                    <div class="skeleton skeleton-actions" />
                </div>
            </div>
        </div>

        <!-- 配置路径管理弹窗 -->
        <teleport to="body">
            <div v-if="showConfigPaths" class="modal-overlay" @click.self="showConfigPaths = false">
                <div class="modal-card">
                    <div class="modal-header">
                        <h3>Ecosystem 配置文件路径</h3>
                        <button class="modal-close" @click="showConfigPaths = false">&times;</button>
                    </div>
                    <div class="modal-body">
                        <div class="config-paths-list">
                            <div class="config-path-item">
                                <span class="path-badge primary">主配置</span>
                                <code class="path-text">{{ configPaths.primary || '未设置' }}</code>
                            </div>
                            <div v-if="configPaths.extra.length === 0" class="path-empty">
                                暂无额外配置路径
                            </div>
                            <div v-for="(p, i) in configPaths.extra" :key="i" class="config-path-item">
                                <span class="path-badge" :class="p.exists ? 'exists' : 'missing'">
                                    {{ p.exists ? '有效' : '不存在' }}
                                </span>
                                <code class="path-text">{{ p.path }}</code>
                                <button class="path-remove" @click="removeEcoPath(p.path)" title="移除">✕</button>
                            </div>
                        </div>
                        <div class="path-add-row">
                            <input
                                v-model="newPath"
                                type="text"
                                class="path-input"
                                placeholder="输入 ecosystem.config.js 的绝对路径"
                                @keyup.enter="addEcoPath"
                            />
                            <button class="path-add-btn" @click="addEcoPath" :disabled="!newPath.trim()">添加</button>
                        </div>
                        <p v-if="pathError" class="path-error">{{ pathError }}</p>
                    </div>
                </div>
            </div>
        </teleport>
    </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, h } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useProcessStore } from '@/stores/processes';
import StatusBadge from '@/components/StatusBadge.vue';
import ActionButtons from '@/components/ActionButtons.vue';
import { ElMessage } from 'element-plus';

// SortIcon component
const SortIcon = {
    props: ['field', 'sort'],
    setup(props) {
        return () => h('span', { class: 'sort-icon ' + (props.sort.field === props.field ? 'active' : '') }, [
            h('svg', { width: 9, height: 9, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': 2.5 }, [
                h('path', { d: props.sort.field === props.field && props.sort.dir === 'asc'
                    ? 'M12 19V5M5 12l7-7 7 7'
                    : 'M12 5v14M19 12l-7 7-7-7' })
            ])
        ]);
    }
};

const store = useProcessStore();
const router = useRouter();
const route = useRoute();
const searchKeyword = ref('');
const statusFilter = ref('online');
const sort = ref({ field: 'name', dir: 'asc' });

// 配置路径管理
const showConfigPaths = ref(false);
const newPath = ref('');
const pathError = ref('');
const configPaths = ref({ primary: '', extra: [], total: 0 });

async function fetchConfigPaths() {
    try {
        const res = await fetch('/api/config/paths');
        const json = await res.json();
        configPaths.value = json.data;
    } catch (e) { /* ignore */ }
}

async function addEcoPath() {
    const p = newPath.value.trim();
    if (!p) return;
    pathError.value = '';
    try {
        const res = await fetch('/api/config/paths', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path: p }),
        });
        const json = await res.json();
        if (json.success) {
            newPath.value = '';
            await fetchConfigPaths();
            // 刷新进程列表以更新来源识别
            await store.fetchList();
        } else {
            pathError.value = json.error || '添加失败';
        }
    } catch (e) {
        pathError.value = e.message;
    }
}

async function removeEcoPath(p) {
    try {
        await fetch('/api/config/paths', {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path: p }),
        });
        await fetchConfigPaths();
        await store.fetchList();
    } catch (e) { /* ignore */ }
}

// 打开弹窗时获取路径列表
watch(showConfigPaths, (v) => { if (v) fetchConfigPaths(); });

// 配置来源识别
function sourceClass(row) {
    const m = row.configMatch;
    if (m === 'exact') return 'src-eco';
    if (m === 'broken') return 'src-broken';
    if (m === 'self') return 'src-self';
    return 'src-manual';
}
function sourceLabel(row) {
    const m = row.configMatch;
    if (m === 'exact') return 'ecosystem';
    if (m === 'broken') return 'ecosystem(失效)';
    if (m === 'self') return 'dashboard';
    return '手动';
}
function sourceTitle(row) {
    // hover 时显示完整配置文件路径
    if (row.configFile) return `来源: ${row.configFile}`;
    if (row.configMatch === 'manual') return '来源: 手动启动或 dump.pm2 恢复';
    if (row.configMatch === 'self') return '来源: pm2_http_server.js';
    return '';
}

onMounted(() => {
    // 从 URL 读取筛选条件
    if (route.query.search) searchKeyword.value = route.query.search;
    if (route.query.status) statusFilter.value = route.query.status;

    store.fetchList();
    store.startMetricsStream();
});

onUnmounted(() => {
    store.stopMetricsStream();
});

// 筛选条件同步到 URL
watch([searchKeyword, statusFilter], () => {
    const query = {};
    if (searchKeyword.value) query.search = searchKeyword.value;
    if (statusFilter.value) query.status = statusFilter.value;
    router.replace({ query });
});

// Status tabs with counts
const statusTabs = computed(() => {
    const tabs = [
        { value: '', label: '全部', color: '#a1a1aa' },
        { value: 'online', label: '在线', color: '#22c55e' },
        { value: 'stopped', label: '已停止', color: '#52525b' },
        { value: 'errored', label: '错误', color: '#ef4444' },
    ];
    return tabs.map(tab => ({
        ...tab,
        count: tab.value === ''
            ? store.list.length
            : store.list.filter(p => p.status === tab.value).length,
    }));
});

const filteredList = computed(() => {
    let list = store.list;

    if (statusFilter.value) {
        list = list.filter(p => p.status === statusFilter.value);
    }
    if (searchKeyword.value) {
        const kw = searchKeyword.value.toLowerCase();
        list = list.filter(p => p.name.toLowerCase().includes(kw));
    }

    // Sort
    list = [...list].sort((a, b) => {
        const field = sort.value.field;
        const dir = sort.value.dir === 'asc' ? 1 : -1;
        if (field === 'name') return a.name.localeCompare(b.name) * dir;
        return ((a[field] ?? 0) - (b[field] ?? 0)) * dir;
    });

    return list;
});

function toggleSort(field) {
    if (sort.value.field === field) {
        sort.value.dir = sort.value.dir === 'asc' ? 'desc' : 'asc';
    } else {
        sort.value.field = field;
        sort.value.dir = 'asc';
    }
}

function goDetail(name) {
    router.push(`/process/${encodeURIComponent(name)}`);
}

async function copyName(name) {
    try {
        await navigator.clipboard.writeText(name);
        ElMessage.success(`已复制: ${name}`);
    } catch {
        ElMessage.warning('复制失败');
    }
}

function buildPortTable(processes) {
    const header = '| 项目名称 | 状态 | 端口 | 启动路径 |\n|---------|------|------|---------|';
    const rows = processes.map(p =>
        `| ${p.name} | ${p.status} | ${p.port || '—'} | ${p.script || '—'} |`
    );
    return [header, ...rows].join('\n');
}

async function generateConfigPrompt() {
    const processes = store.list;
    const portTable = buildPortTable(processes);
    const prompt = `# PM2 项目配置生成任务

## 已知项目端口参考

以下是当前环境中已部署的项目及其端口信息，可作为端口分配参考：

${portTable}

## 你的任务

为给定的项目目录生成 PM2 ecosystem.config.js 配置文件。请按以下步骤执行：

### 步骤 1：分析项目目录
- 检查 package.json（Node.js 项目）或 requirements.txt / main.py（Python 项目）
- 检查启动脚本位置（scripts.start、main 入口等）
- 检查端口配置（环境变量、config 文件、hardcode）
- 检查技术栈（Vite / Express / FastAPI / Streamlit 等）

### 步骤 2：确认端口
- 优先使用项目内已配置的端口
- 如果项目未指定端口，参照上方已知端口表，选择一个未被占用的端口
- 如有冲突，请输出冲突提示

### 步骤 3：生成配置

请输出符合以下模板的 ecosystem.config.js：

\`\`\`javascript
module.exports = {
  apps: [{
    name: '<项目名称>',
    cwd: '<项目目录绝对路径>',
    script: '<启动脚本或命令>',
    interpreter: '<解释器 (node/python3/none)>',
    instances: 1,
    autorestart: true,
    watch: false,
    min_uptime: 10000,
    max_restarts: 10,
    exp_backoff_restart_delay: 1000,
    env: {
      NODE_ENV: 'production',
      PORT: <端口号>,
      PATH: process.env.PATH || '/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin',
      HOME: process.env.HOME || '',
    },
    error_file: '<项目目录>/logs/<name>-error.log',
    out_file: '<项目目录>/logs/<name>-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    merge_logs: true,
  }]
};
\`\`\`

### 注意事项
- 如果项目有多个启动项（如 前端+后端），拆分为多个 app 条目
- 日志目录需保证存在，若不存在则在配置中添加 mkdir -p 命令
- Python 项目使用 interpreter: 'none'，script: 'python3'，args: '-m uvicorn ...'
- 前端 Vite 项目使用 interpreter: 'none'，script: 'npx'，args: 'vite --port <port> --host'
- 确保端口号与环境中的其他项目不冲突
`;

    try {
        await navigator.clipboard.writeText(prompt);
        ElMessage.success('配置 Prompt 已复制，共 ' + processes.length + ' 个项目参考');
    } catch {
        ElMessage.warning('复制失败');
    }
}

</script>

<style scoped>
/* ===== Toolbar ===== */
.toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
    flex-wrap: wrap;
}

.search-wrap {
    position: relative;
    display: flex;
    align-items: center;
}

.search-icon {
    position: absolute;
    left: 10px;
    color: var(--text-muted);
    pointer-events: none;
}

.search-input {
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    color: var(--text-primary);
    font-size: 13px;
    padding: 7px 12px 7px 30px;
    width: 220px;
    outline: none;
    transition: var(--transition);
}

.search-input::placeholder { color: var(--text-muted); }

.search-input:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-dim);
}

.filter-tabs {
    display: flex;
    gap: 4px;
    background: var(--bg-surface);
    padding: 3px;
    border-radius: 8px;
    border: 1px solid var(--border);
}

.filter-tab {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 12px;
    font-weight: 500;
    color: var(--text-muted);
    background: transparent;
    border: none;
    padding: 4px 10px;
    border-radius: 5px;
    cursor: pointer;
    transition: var(--transition);
}

.filter-tab:hover { color: var(--text-secondary); background: var(--bg-elevated); }

.filter-tab.active {
    background: var(--bg-elevated);
    color: var(--text-primary);
}

.tab-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    flex-shrink: 0;
}

.tab-count {
    font-size: 10px;
    font-weight: 700;
    background: var(--bg-hover);
    color: var(--text-muted);
    padding: 0 5px;
    border-radius: 3px;
    font-variant-numeric: tabular-nums;
}

.filter-tab.active .tab-count {
    background: var(--accent-dim);
    color: var(--accent);
}

.toolbar-right {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: 6px;
}

.gen-prompt-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 11px;
    font-weight: 600;
    color: var(--accent);
    background: var(--accent-dim);
    border: 1px solid transparent;
    padding: 4px 10px;
    border-radius: 6px;
    cursor: pointer;
    transition: var(--transition);
    white-space: nowrap;
}
.gen-prompt-btn:hover {
    background: var(--accent);
    color: #fff;
}

.total-label {
    font-size: 12px;
    color: var(--text-muted);
}

.total-num {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
}

.ws-indicator {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    padding: 2px 8px;
    border-radius: 4px;
}

.ws-indicator.live {
    color: var(--status-online);
    background: rgba(34, 197, 94, 0.1);
}

.ws-indicator.dead {
    color: var(--text-muted);
    background: var(--bg-surface);
}

.ws-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: currentColor;
}

.ws-indicator.live .ws-dot { animation: breathe 2s ease-in-out infinite; }

@keyframes breathe {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
}

/* ===== Table ===== */
.table-wrap {
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
}

.data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
}

.data-table th {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: var(--text-muted);
    padding: 10px 12px;
    text-align: left;
    border-bottom: 1px solid var(--border-subtle);
    background: var(--bg-surface);
    white-space: nowrap;
    user-select: none;
}

.data-table th.sortable {
    cursor: pointer;
    display: table-cell;
}

.data-table th.sortable:hover { color: var(--text-secondary); }

.sort-icon { display: inline-flex; align-items: center; margin-left: 3px; opacity: 0.4; }
.sort-icon.active { opacity: 1; color: var(--accent); }

.data-row {
    cursor: pointer;
    transition: var(--transition);
}

.data-row:hover td { background: var(--bg-elevated); }

.data-row td {
    padding: 10px 12px;
    border-bottom: 1px solid var(--border-subtle);
    vertical-align: middle;
    transition: background 0.1s;
}

.data-row:last-child td { border-bottom: none; }

/* Column specific */
.col-name { min-width: 160px; }
.col-status { width: 110px; }
.col-port { width: 70px; }
.col-source { width: 95px; }
.col-mem { width: 90px; }
.col-restart { width: 70px; }
.col-uptime { width: 110px; }
.col-actions { width: 110px; }

.name-wrap {
    display: flex;
    align-items: center;
    gap: 4px;
}

.copy-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border: none;
    border-radius: 4px;
    background: transparent;
    color: var(--text-muted);
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.15s, background 0.15s, color 0.15s;
    flex-shrink: 0;
    padding: 0;
}
.data-row:hover .copy-btn {
    opacity: 1;
}
.copy-btn:hover {
    background: var(--bg-hover);
    color: var(--accent);
}

.process-name {
    display: block;
    font-weight: 600;
    color: var(--text-primary);
    font-size: 13px;
    margin-bottom: 1px;
}

.process-pid {
    font-size: 10px;
    color: var(--text-muted);
    font-variant-numeric: tabular-nums;
}

.mono {
    font-variant-numeric: tabular-nums;
    font-family: 'SF Mono', 'JetBrains Mono', 'Fira Code', monospace;
}

.has-restarts { color: var(--status-launching); }
.muted { color: var(--text-muted); }

.port-link {
    color: var(--accent);
    text-decoration: none;
    font-weight: 600;
    cursor: pointer;
}
.port-link:hover {
    text-decoration: underline;
}

/* ===== Config Source Tag ===== */
.source-tag {
    display: inline-block;
    font-size: 11px;
    padding: 1px 7px;
    border-radius: 3px;
    font-weight: 500;
    white-space: nowrap;
    line-height: 18px;
}
.src-eco {
    background: rgba(52, 211, 153, 0.15);
    color: #059669;
}
.src-broken {
    background: rgba(239, 68, 68, 0.12);
    color: #dc2626;
}
.src-manual {
    background: rgba(148, 163, 184, 0.12);
    color: #64748b;
}
.src-self {
    background: rgba(96, 165, 250, 0.15);
    color: #3b82f6;
}

/* ===== Empty & Loading ===== */
.empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 64px 24px;
    gap: 8px;
}

.empty-icon { color: var(--text-muted); margin-bottom: 8px; }

.empty-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-secondary);
}

.empty-sub {
    font-size: 13px;
    color: var(--text-muted);
}

.loading-state {
    padding: 8px;
}

.skeleton-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    border-bottom: 1px solid var(--border-subtle);
}

.skeleton-row:last-child { border-bottom: none; }

.skeleton {
    background: linear-gradient(90deg, var(--bg-elevated) 25%, var(--bg-hover) 50%, var(--bg-elevated) 75%);
    background-size: 200% 100%;
    border-radius: 4px;
    animation: shimmer 1.4s ease-in-out infinite;
    height: 14px;
}

@keyframes shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
}

.skeleton-name { width: 140px; }
.skeleton-badge { width: 70px; }
.skeleton-source { width: 80px; }
.skeleton-mem { width: 70px; }
.skeleton-restart { width: 40px; }
.skeleton-uptime { width: 80px; }
.skeleton-actions { width: 90px; margin-left: auto; }

/* ===== Config Paths Modal ===== */
.modal-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.4);
    display: flex; align-items: center; justify-content: center;
    z-index: 9999;
}
.modal-card {
    background: #1e1e2e; border-radius: 12px; width: 560px; max-width: 90vw;
    box-shadow: 0 8px 32px rgba(0,0,0,0.4); overflow: hidden;
}
.modal-header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 16px 20px; border-bottom: 1px solid rgba(255,255,255,0.06);
}
.modal-header h3 { margin: 0; font-size: 15px; color: #e2e8f0; }
.modal-close { background: none; border: none; color: #94a3b8; font-size: 20px; cursor: pointer; padding: 0 4px; }
.modal-close:hover { color: #e2e8f0; }

.modal-body { padding: 20px; }
.config-paths-list { margin-bottom: 16px; }
.config-path-item {
    display: flex; align-items: center; gap: 10px;
    padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.04);
}
.path-badge {
    font-size: 10px; padding: 1px 6px; border-radius: 3px; flex-shrink: 0; font-weight: 500;
}
.path-badge.primary { background: rgba(96,165,250,0.15); color: #60a5fa; }
.path-badge.exists { background: rgba(52,211,153,0.15); color: #34d399; }
.path-badge.missing { background: rgba(239,68,68,0.12); color: #f87171; }

.path-text { font-size: 12px; color: #94a3b8; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; }
.path-remove { background: none; border: none; color: #64748b; cursor: pointer; font-size: 14px; padding: 2px 6px; }
.path-remove:hover { color: #f87171; }

.path-empty { font-size: 12px; color: #64748b; padding: 8px 0; }

.path-add-row { display: flex; gap: 8px; }
.path-input {
    flex: 1; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08);
    border-radius: 6px; padding: 8px 12px; color: #e2e8f0; font-size: 13px;
    font-family: 'SF Mono', 'Menlo', monospace;
}
.path-input:focus { outline: none; border-color: rgba(96,165,250,0.4); }
.path-add-btn {
    background: rgba(96,165,250,0.15); border: 1px solid rgba(96,165,250,0.3);
    color: #60a5fa; border-radius: 6px; padding: 8px 16px; font-size: 13px; cursor: pointer; white-space: nowrap;
}
.path-add-btn:hover { background: rgba(96,165,250,0.25); }
.path-add-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.path-error { font-size: 12px; color: #f87171; margin-top: 8px; }
</style>
