# 变更记录

## [1.2.0] - 2026-11-17

### 新增
- **内置第三方包**：`vendor/polang233-cursor-language-pack-1.2.0.tgz`（2.1 MB），安装全程不联网
- `THIRD_PARTY_NOTICES.md`：第三方组件的来源、版本与 MIT 许可证声明

### 安全
- 提权注册脚本**不再写任何文件**（消除符号链接/重解析点与 TOCTOU 风险），结果只打印到控制台，由未提权的 `Get-ScheduledTask` 验证

### 变更
- `apply.ps1` 优先使用 `vendor/` 里的副本；缺失时回退到 npm 下载同一固定版本，两种情况都校验 SHA-512

## [1.1.0] - 2026-11-17

### 新增
- `scripts/auto-watch.ps1`：检测 Cursor 版本变化并自动重新汉化；Cursor 运行中则跳过本轮
- `scripts/install-autostart.ps1`：注册计划任务（登录后 2 分钟 + 每天 12:00）
- `scripts/register-task-elevated.ps1`：提权注册任务，结果文件使用 CreateNew 并校验重解析点
- `apply.ps1` 新增 `-NoRelaunch`、`-VerifyOnly` 开关

### 修复
- **执行顺序**：改为"下载 → 校验 → 解包 → 全部通过后才关闭 Cursor"，避免网络或校验失败打断用户
- **解包方式**：改用 `npm install --ignore-scripts`，修复 Git/MSYS 的 tar 把 `D:\` 解析为远程主机的问题
- **JSONC 兼容**：`config.json` 含注释，解析失败时回退到正则读取版本列表

### 安全
- 移除对缓存标记文件的信任，改为每次重新哈希并重新解包
- tarball 校验失败时不执行任何第三方代码

## [1.0.0] - 2026-11-16

### 新增
- `SKILL.md`：原理说明、三个已知坑、标准流程、故障排查
- `scripts/apply.ps1`：应用语言包（关闭 Cursor → 打补丁 → 验证 → 重启）
- `scripts/verify.ps1`：按证据验证（扩展、locale、备份数量）
- `scripts/restore.ps1`：按备份还原并恢复英文
- `scripts/detect.ps1`：环境巡检

### 安全
- 版本锁定 `@polang233/cursor-language-pack@1.2.0`
- 下载后校验 SHA-512，不匹配即中止
- 包名使用 `--` 分隔，防止被解析为 npm 参数
