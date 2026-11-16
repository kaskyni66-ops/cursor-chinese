# 变更记录

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
