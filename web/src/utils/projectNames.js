/**
 * PM2 进程名 → 中文项目名称映射
 * key: 进程名（不区分大小写），value: 中文显示名
 */
export const PROCESS_NAMES = {
  'ai-sale': 'AI 销售',
  'chrome-cdp': 'Chrome CDP',
  'dd-math-static': 'DD 数学',
  'flow-ad-api': '广告流量 API',
  'flow-ad-streamlit': '广告流量',
  'hero-pk-game': 'Hero PK 游戏',
  'paperclip-ceo-heartbeat': 'Paperclip 心跳',
  'pm2-dashboard': 'PM2 面板',
  'subform': '子表单',
  'web-share': '网页分享',
  'yqa-meun': 'YQA 菜单',
};

/** 分组前缀 → 中文项目名称映射 */
export const GROUP_NAMES = {
  'xm-bazi': '八字',
  'flow-ad': '广告流量',
  'xm-console': '控制台',
  'xm-ai-config': 'AI 配置',
  'xm-checkpoint': '检查点提取',
  'xm-digital-human': '数字人',
  'xm-droid': 'Droid 监控',
  'xm-opencode': 'OpenCode',
  'xm-pm2': 'PM2 守护',
  'xm-syai-admin': 'SYAI 管理',
  'xm-syai-chat': 'SYAI 聊天',
  'xm-telegram': 'Telegram 机器人',
  'xm-yqa': 'YQA 面板',
  'requirement-analyzer': '需求分析',
  'paperclip-ceo': 'Paperclip 心跳',
  'hero-pk': 'Hero PK 游戏',
};

/**
 * 获取进程的中文显示名
 * @param {string} name - PM2 进程名
 * @returns {string} 中文名（无映射时返回原名称）
 */
export function getProcessDisplayName(name) {
  return PROCESS_NAMES[name.toLowerCase()] || name;
}

/**
 * 获取分组的中文显示名（支持运行时覆盖）
 * @param {string} key - 分组 key（如 xm-console）
 * @param {Object} [overrides] - 运行时覆盖映射
 * @returns {string} 中文名（无映射时返回原 key）
 */
export function getGroupDisplayName(key, overrides) {
  const lower = key.toLowerCase();
  if (overrides && overrides[lower] !== undefined) {
    return overrides[lower];
  }
  return GROUP_NAMES[lower] || key;
}
