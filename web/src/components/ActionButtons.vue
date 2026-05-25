<template>
    <div v-if="!isProtected" class="action-group">
        <button
            class="action-btn"
            :class="process.status === 'online' ? 'btn-stop' : 'btn-start'"
            :disabled="pending"
            @click.stop="handleAction(process.status === 'online' ? 'stop' : 'start')"
            :title="process.status === 'online' ? '停止' : '启动'"
        >
            <svg v-if="!pending" width="11" height="11" viewBox="0 0 24 24" fill="currentColor">
                <rect x="6" y="6" width="12" height="12" rx="2" v-if="process.status === 'online'" />
                <polygon points="5,3 19,12 5,21" v-else />
            </svg>
            <svg v-else width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="spin">
                <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>
            </svg>
        </button>

        <button
            class="action-btn btn-restart"
            :disabled="pending"
            @click.stop="handleAction('restart')"
            title="重启"
        >
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
                <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>
                <path d="M21 3v5h-5"/>
                <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/>
                <path d="M3 21v-5h5"/>
            </svg>
        </button>

        <button
            class="action-btn btn-delete"
            @click.stop="handleDelete"
            title="删除"
        >
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/>
                <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
                <path d="M10 11v6M14 11v6"/>
                <path d="M9 6V4h6v2"/>
            </svg>
        </button>
    </div>
    <span v-else class="protected-label">系统</span>
</template>

<script setup>
import { ref, computed } from 'vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import { useProcessStore } from '@/stores/processes';

const props = defineProps({
    process: { type: Object, required: true },
    onRefresh: { type: Function, default: null },
    protectedNames: { type: Array, default: () => ['pm2-dashboard'] },
});

const isProtected = computed(() => props.protectedNames.includes(props.process.name));

const store = useProcessStore();
const pending = ref(false);

async function handleAction(action) {
    if (pending.value) return;
    pending.value = true;
    try {
        await store[action](props.process.name);
        ElMessage({ message: `${action === 'stop' ? '已停止' : action === 'start' ? '已启动' : '已重启'} ${props.process.name}`, type: 'success', duration: 1500 });
    } catch {
        // error handled in store
    } finally {
        pending.value = false;
    }
}

async function handleDelete() {
    try {
        await ElMessageBox.confirm(
            `删除后无法恢复，确认删除进程「${props.process.name}」？`,
            '删除确认',
            { type: 'warning', confirmButtonClass: 'el-button--danger' }
        );
        pending.value = true;
        await store.remove(props.process.name);
        ElMessage({ message: '已删除', type: 'success', duration: 1500 });
    } catch {
        // cancel or error
    } finally {
        pending.value = false;
    }
}
</script>

<style scoped>
.action-group {
    display: flex;
    align-items: center;
    gap: 4px;
}

.action-btn {
    width: 26px;
    height: 26px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--text-muted);
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: var(--transition);
}

.action-btn:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
    border-color: var(--bg-hover);
}

.action-btn:active {
    transform: scale(0.9);
}

.action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
}

.btn-start:hover {
    color: var(--status-online);
    border-color: var(--status-online);
    background: rgba(34, 197, 94, 0.1);
}

.btn-stop:hover {
    color: var(--status-launching);
    border-color: var(--status-launching);
    background: rgba(245, 158, 11, 0.1);
}

.btn-delete:hover {
    color: var(--status-errored);
    border-color: var(--status-errored);
    background: rgba(239, 68, 68, 0.1);
}

.protected-label {
    font-size: 10px;
    color: var(--text-muted);
    padding: 2px 8px;
    background: var(--bg-elevated);
    border-radius: 4px;
    font-weight: 500;
    letter-spacing: 0.3px;
}

.spin {
    animation: spin 0.7s linear infinite;
}

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}
</style>
