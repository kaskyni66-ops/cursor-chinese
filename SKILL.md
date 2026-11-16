---
name: cursor-chinese
description: 把 Cursor IDE 汉化成简体/繁体中文，覆盖编辑器、设置页和 Agent 界面。用于新装 Cursor 后中文化、Cursor 自动更新后恢复中文、或回滚为英文。当用户说"Cursor 中文""Cursor 汉化""Cursor 变回英文了"时使用。
allowed-tools:
  - Read
  - Write
  - PowerShell
  - Bash
---

# Cursor 中文化

## 背景（先理解原理，再动手）

Cursor **官方没有中文版**。界面语言分两层：

| 层 | 内容 | 谁能汉化 |
|---|---|---|
| VS Code 层 | 编辑器菜单、命令、设置项名 | 微软官方语言包 `ms-ceintl.vscode-language-pack-zh-hans` |
| Cursor 自有层 | Agents 主界面、设置页、订阅页 | **只有第三方包**，官方语言包无效 |

本项目采用 `@polang233/cursor-language-pack`（MIT，Open VSX 发布）。它的做法：

1. 改写 Cursor 安装目录里的 workbench bundle 文案
2. 同步更新 `product.json` 的校验和（否则 Cursor 判定安装被篡改）
3. 每个被改文件先备份，备份带 sha256
4. 安装一个扩展，负责在 Cursor 内切换语言并写 `argv.json` 的 `locale`

## 三个必须知道的坑（踩过）

1. **只改 `argv.json` 的 locale 没用。** 界面文案在 bundle 里，必须替换文案。
2. **必须显式传 `--vsix`。** npm 包把 VSIX 放在 `assets/`，而脚本默认只找 `dist/`；不传就只汉化、不装切换扩展。
3. **Cursor 每次自动更新都会覆盖 bundle，界面变回英文。** 这是设计使然，重跑一次即可。

## 标准流程

### 第 1 步：检测环境

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\detect.ps1"
```

输出：Cursor 安装目录、版本号、是否已被打包汉化、`argv.json` 位置。

**版本必须命中包的 `verifiedCursorVersions`**（在包的 `config.json` 里）。不命中就先告知用户风险，不直接装。

### 第 2 步：应用汉化

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\apply.ps1" -Locale zh-cn
```

脚本会依次做：
1. 完全退出 Cursor（含子进程），确认进程数归零
2. 卸载冲突的微软官方语言包
3. `npm pack` 下载并解包语言包（缓存到 `%LOCALAPPDATA%\cursor-chinese`）
4. 运行 `translate-install.mjs --dir=<安装目录> --locale=<语言> --vsix=<assets 里的 vsix>`
5. 校验：备份目录存在、`product.json` 校验和已更新
6. 重新启动 Cursor

### 第 3 步：验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\verify.ps1"
```

判定标准（缺一不可）：
- 扩展 `polang233.cursor-language-pack` 已安装
- `argv.json` 的 `locale` 等于目标语言
- bundle 备份目录里有 ≥3 个文件
- Cursor 进程能正常启动

**不看截图不算通过** —— 必须确认菜单/设置页实际显示中文。

### 回滚

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\restore.ps1"
```

调用 `--undo`，按备份还原程序文件，并把 `locale` 改回 `en`。

## 语言代码

| 值 | 语言 |
|---|---|
| `zh-cn` | 简体中文 |
| `zh-tw` | 繁体中文 |
| `ja` | 日语 |
| `en` | 英文（等同回滚显示语言） |

## 自动维护（安装后无需人工干预）

Skill 的用户不一定有 AI 盯着，所以提供一次性的自动化安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\install-autostart.ps1" -Locale zh-cn
```

它注册计划任务 `Cursor Chinese Auto`：

| 触发时机 | 原因 |
|---|---|
| 每次登录后 2 分钟 | Cursor 更新通常在重启时生效，此时 Cursor 还没启动 |
| 每天 12:00 | 机器长时间不关时兜底检查 |

判定逻辑（`scripts/auto-watch.ps1`）：

1. 读取当前 Cursor 版本、扩展、locale、备份数量
2. 与 `state.json` 记录的上次版本比对
3. 三者都健康且版本未变 → 什么都不做
4. **Cursor 正在运行 → 本轮跳过并记日志**，绝不强制关闭用户正在用的窗口
5. 需要处理且 Cursor 未运行 → 调用 `apply.ps1 -NoRelaunch`，成功后更新 `state.json`

日志：`<CacheDir>\logs\auto-watch.log`

卸载自动化：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\install-autostart.ps1" -Uninstall
```

> 注册计划任务需要管理员权限（普通权限会报 Access denied）；脚本会自动提示用提权窗口执行。

## 故障排查

| 现象 | 原因 | 处理 |
|---|---|---|
| 界面仍英文 | 只改了 locale，没改 bundle | 重跑 apply，确认 `--vsix` 已传且退出码正常 |
| 提示"安装已损坏" | `product.json` 校验和没同步 | 用 `restore` 还原后重跑 |
| 设置页英文、编辑器中文 | 装的是微软官方包 | 卸载 `ms-ceintl.*`，改用本方案 |
| 启动报 `bad option` | 从带 `ELECTRON_RUN_AS_NODE` 的 shell 启动 | 清空该环境变量再启动 |
| 更新后变英文 | Cursor 覆盖了 bundle | 重跑 apply |

## 安全边界

- 只修改 Cursor 安装目录内的 bundle 与 `product.json`，**不改系统设置、不装服务、不加自启**
- 不联网上传任何数据（安装包本身从 npm/Open VSX 下载）
- 第三方包非官方，**每次 Cursor 更新后需要重跑**
- 执行前确认安装包仍在（最坏情况可重装 Cursor）
