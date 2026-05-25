<template>
    <div class="detail">
        <!-- 返回 -->
        <div class="back-bar">
            <button class="back-btn" @click="$router.push('/')">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M19 12H5M12 19l-7-7 7-7"/>
                </svg>
                返回列表
            </button>
        </div>

        <!-- 进程基本信息 -->
        <div class="info-grid" v-if="process">
            <div class="info-card main-card">
                <div class="card-header">
                    <div class="process-identity">
                        <span class="process-name-lg">{{ process.name }}</span>
                        <span class="process-pid-lg">PID {{ process.pid || '—' }}</span>
                    </div>
                    <StatusBadge :status="process.status" />
                </div>

                <div class="metrics-row">
                    <div class="metric-block">
                        <span class="metric-label">内存</span>
                        <span class="metric-value">{{ process.memoryHuman }}</span>
                        <div class="metric-bar">
                            <div class="metric-fill memory-fill" :style="{ width: memoryPct + '%' }" />
                        </div>
                    </div>
                    <div class="metric-block">
                        <span class="metric-label">重启</span>
                        <span class="metric-value" :class="process.restarts > 0 ? 'warn' : ''">{{ process.restarts }}</span>
                    </div>
                    <div class="metric-block">
                        <span class="metric-label">运行时长</span>
                        <span class="metric-value muted">{{ process.uptimeHuman }}</span>
                    </div>
                </div>
            </div>

            <div class="info-card side-card">
                <div class="card-header">
                    <span class="card-title">详情</span>
                </div>
                <div class="detail-list">
                    <div class="detail-row">
                        <span class="detail-key">PM2 ID</span>
                        <span class="detail-val mono">{{ process.pmId }}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-key">来源</span>
                        <span class="detail-val">
                            <span class="source-tag" :class="sourceClass(process)" :title="sourceTitle(process)">
                                {{ sourceLabel(process) }}
                            </span>
                        </span>
                    </div>
                    <div class="detail-row" v-if="process.configFile">
                        <span class="detail-key">配置文件</span>
                        <span class="detail-val mono muted">{{ process.configFile }}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-key">解释器</span>
                        <span class="detail-val mono muted">{{ process.interpreter || '—' }}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-key">启动时间</span>
                        <span class="detail-val mono muted">{{ process.createdAt ? formatDate(process.createdAt) : '—' }}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-key">工作目录</span>
                        <span class="detail-val mono muted tooltipped">{{ process.script || '—' }}</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- 操作区 -->
        <div class="action-bar" v-if="process">
            <button class="action-primary" :class="process.status === 'online' ? 'btn-danger' : 'btn-success'" @click="handleAction(process.status === 'online' ? 'stop' : 'start')" :disabled="pending">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
                    <rect x="6" y="6" width="12" height="12" rx="2" v-if="process.status === 'online'" />
                    <polygon points="5,3 19,12 5,21" v-else />
                </svg>
                {{ process.status === 'online' ? '停止' : '启动' }}
            </button>
            <button class="action-secondary" @click="handleAction('restart')" :disabled="pending">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                    <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>
                    <path d="M21 3v5h-5"/>
                    <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/>
                    <path d="M3 21v-5h5"/>
                </svg>
                重启
            </button>
            <button class="action-secondary" @click="$router.push(`/process/${encodeURIComponent(process.name)}/logs`)" :disabled="pending">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                    <polyline points="14 2 14 8 20 8"/>
                    <line x1="16" y1="13" x2="8" y2="13"/>
                    <line x1="16" y1="17" x2="8" y2="17"/>
                </svg>
                查看日志
            </button>
            <button class="action-danger" @click="handleDelete" :disabled="pending">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
                </svg>
                删除
            </button>
        </div>

        <!-- 加载骨架 -->
        <div v-if="!process" class="loading-grid">
            <div class="skeleton-card" />
            <div class="skeleton-card" />
        </div>
    </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessageBox, ElMessage } from 'element-plus';
import { http } from '@/api/http';
import { connectMetricsWS } from '@/api/ws';
import StatusBadge from '@/components/StatusBadge.vue';

const props = defineProps({ name: String });
const route = useRoute();
const router = useRouter();

const process = ref(null);
const pending = ref(false);
let ws = null;

const memoryPct = computed(() => {
    if (!process.value) return 0;
    // 假设总内存 32GB，显示相对百分比（这里只能显示相对值）
    const totalMem = 32 * 1024 * 1024 * 1024;
    return Math.min((process.value.memory / totalMem) * 100, 100);
});

// 配置来源识别（同 ProcessList.vue）
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
    if (row.configFile) return `来源: ${row.configFile}`;
    if (row.configMatch === 'manual') return '来源: 手动启动或 dump.pm2 恢复';
    if (row.configMatch === 'self') return '来源: pm2_http_server.js';
    return '';
}

onMounted(async () => {
    await fetchProcess();
    startStream();
});

onUnmounted(() => { if (ws) ws.close(); });

async function fetchProcess() {
    try {
        const res = await http.get(`/processes/${props.name}`);
        process.value = res.data;
    } catch { ElMessage.error('获取进程详情失败'); }
}

function startStream() {
    ws = connectMetricsWS((data) => {
        if (data.type === 'metrics') {
            const p = data.data.find(item => item.name === props.name);
            if (p) process.value = p;
        }
    });
}

function formatDate(iso) {
    if (!iso) return '—';
    return new Date(iso).toLocaleString('zh-CN', { hour12: false });
}

async function handleAction(action) {
    if (pending.value) return;
    pending.value = true;
    try {
        await http.post(`/processes/${props.name}/${action}`);
        await fetchProcess();
        ElMessage({ message: `${action === 'stop' ? '已停止' : action === 'start' ? '已启动' : '已重启'} ${props.name}`, type: 'success', duration: 1500 });
    } catch {} finally { pending.value = false; }
}

async function handleDelete() {
    try {
        await ElMessageBox.confirm(`删除后无法恢复，确认删除「${props.name}」？`, '删除确认', { type: 'warning', confirmButtonClass: 'el-button--danger' });
        pending.value = true;
        await http.delete(`/processes/${props.name}`);
        ElMessage({ message: '已删除', type: 'success', duration: 1500 });
        router.push('/');
    } catch {} finally { pending.value = false; }
}
</script>

<style scoped>
.detail { display: flex; flex-direction: column; gap: 16px; }

.back-bar { margin-bottom: 4px; }

.back-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-muted);
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px 8px;
    border-radius: 6px;
    transition: var(--transition);
}
.back-btn:hover { color: var(--text-primary); background: var(--bg-elevated); }

/* Cards */
.info-grid {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 16px;
}

@media (max-width: 900px) {
    .info-grid { grid-template-columns: 1fr; }
}

.info-card {
    background: var(--bg-surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 20px;
}

.card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    margin-bottom: 20px;
}

.process-identity { display: flex; flex-direction: column; gap: 3px; }

.process-name-lg {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    letter-spacing: -0.3px;
}

.process-pid-lg {
    font-size: 11px;
    color: var(--text-muted);
    font-variant-numeric: tabular-nums;
}

.card-title {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: var(--text-muted);
}

/* Metrics Row */
.metrics-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
}

@media (max-width: 700px) {
    .metrics-row { grid-template-columns: repeat(2, 1fr); }
}

.metric-block { display: flex; flex-direction: column; gap: 4px; }

.metric-label {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-muted);
}

.metric-value {
    font-size: 22px;
    font-weight: 700;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.5px;
}

.warn { color: var(--status-launching); }
.muted { color: var(--text-muted); }

.metric-bar {
    height: 3px;
    background: var(--bg-elevated);
    border-radius: 2px;
    overflow: hidden;
    margin-top: 4px;
}

.metric-fill {
    height: 100%;
    border-radius: 2px;
    transition: width 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}

.memory-fill { background: #6366f1; }

/* Detail List */
.detail-list { display: flex; flex-direction: column; gap: 10px; }

.detail-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
    padding-bottom: 10px;
    border-bottom: 1px solid var(--border-subtle);
}

.detail-row:last-child { border-bottom: none; padding-bottom: 0; }

.detail-key {
    font-size: 12px;
    color: var(--text-muted);
    flex-shrink: 0;
}

.detail-val {
    font-size: 12px;
    color: var(--text-secondary);
    text-align: right;
    word-break: break-all;
}

.mono { font-variant-numeric: tabular-nums; font-family: 'SF Mono', 'JetBrains Mono', monospace; }

/* Action Bar */
.action-bar {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

.action-primary, .action-secondary, .action-danger {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 600;
    padding: 8px 16px;
    border-radius: var(--radius);
    border: 1px solid;
    cursor: pointer;
    transition: var(--transition);
}

.action-primary { background: var(--accent); border-color: var(--accent); color: #fff; }
.action-primary:hover { background: var(--accent-hover); border-color: var(--accent-hover); }
.action-primary:active { transform: scale(0.96); }
.action-primary:disabled { opacity: 0.4; cursor: not-allowed; }

.action-secondary { background: transparent; border-color: var(--border); color: var(--text-secondary); }
.action-secondary:hover { background: var(--bg-elevated); border-color: var(--bg-hover); color: var(--text-primary); }
.action-secondary:disabled { opacity: 0.4; cursor: not-allowed; }

.action-danger { background: transparent; border-color: rgba(239, 68, 68, 0.3); color: #ef4444; }
.action-danger:hover { background: rgba(239, 68, 68, 0.1); }
.action-danger:disabled { opacity: 0.4; cursor: not-allowed; }

/* Loading */
.loading-grid { display: grid; grid-template-columns: 1fr 320px; gap: 16px; }

.skeleton-card {
    height: 180px;
    background: linear-gradient(90deg, var(--bg-surface) 25%, var(--bg-elevated) 50%, var(--bg-surface) 75%);
    background-size: 200% 100%;
    border-radius: var(--radius-lg);
    animation: shimmer 1.4s ease-in-out infinite;
}

@keyframes shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
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
</style>
