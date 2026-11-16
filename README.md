# Cursor 中文化 Skill

把 [Cursor IDE](https://cursor.com) 汉化成**简体中文 / 繁体中文 / 日语**的自动化 Skill，覆盖：

- 编辑器界面（VS Code 层）
- **Cursor 自有界面**：设置页、Agents 主界面、订阅页

> 官方从未发布中文版 Cursor。本项目封装第三方语言包 `@polang233/cursor-language-pack`，并补齐了它官方文档里没写清楚的三个坑。

## 为什么需要这个 Skill

直接把微软官方语言包装进 Cursor，**只能汉化 VS Code 那一层**，Cursor 自己的设置页和 Agents 界面仍然是英文。社区方案（polang233）通过改写 Cursor 的 workbench bundle 解决了这个问题，但原始流程有三个坑：

| 坑 | 现象 | 本 Skill 的处理 |
|---|---|---|
| 只改 `argv.json` 的 locale | 界面完全不变 | 必须同时替换 bundle 文案 |
| `--vsix` 参数 | 只汉化、不装切换扩展，Cursor 内没有语言切换命令 | 显式传 `assets/language-pack.vsix` |
| Cursor 自动更新 | 界面变回英文 | 重跑 `apply.ps1` 即可 |

## 环境要求

- Windows 10/11
- Cursor（已验证版本见 `package/config.json` 的 `verifiedCursorVersions`）
- Node.js 18.17+（脚本用它运行上游安装器）

## 用法

### 1. 检测当前状态

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\detect.ps1
```

输出示例：

```
cursor_dir=E:\Cursor
cursor_version=3.30.14
vscode_version=1.128.0
pack_installed=True
argv_locale=zh-cn
backup_files=4
```

### 2. 应用汉化

先完全退出 Cursor，然后：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply.ps1 -Locale zh-cn
```

可选参数：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `-Locale` | `zh-cn` | `zh-cn` / `zh-tw` / `ja` |
| `-CursorDir` | 自动探测 | Cursor 安装目录（含 `resources\app`） |
| `-CacheDir` | `D:\Tools\cursor-chinese\cache` | 语言包缓存位置 |

### 3. 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

判定依据（不靠截图）：扩展已安装、`argv.json` 的 `locale` 正确、备份文件 ≥ 3 个。

### 4. 开启自动维护（推荐）

Cursor 每次自动更新都会把界面变回英文。装一次自动维护，之后无需人工干预：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-autostart.ps1 -Locale zh-cn
```

注意：注册计划任务需要**管理员权限**，请在提权后的 PowerShell 里执行。

它注册的任务 `Cursor Chinese Auto` 会在**每次登录后 2 分钟**和**每天 12:00** 检查一次：

| 情况 | 行为 |
|---|---|
| 已是最新且翻译完好 | 什么都不做 |
| Cursor 版本变了 | 自动重新汉化 |
| **Cursor 正在运行** | **本轮跳过**，绝不影响你正在用的窗口 |
| 翻译被破坏（备份缺失等） | 自动修复 |

日志：`D:\Tools\cursor-chinese\cache\logs\auto-watch.log`

卸载：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-autostart.ps1 -Uninstall
```

### 5. 回滚

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore.ps1
```

按备份还原程序文件，并把显示语言设回 `en`。

## 工作原理

1. 从 npm 下载 `@polang233/cursor-language-pack`
2. 改写 Cursor 安装目录内的 workbench bundle 文案
3. 同步更新 `product.json` 的校验和（否则 Cursor 会判定安装被篡改）
4. 每个被改文件先备份（带 sha256），并存放在 `~/.cursor/cursor-language-pack/installs/`
5. 安装切换扩展，写入 `argv.json` 的 `locale`

## 安全说明

- 不联网上传任何数据；只在安装时从 npm 下载语言包
- **版本锁定 + 完整性校验**：默认固定 `@polang233/cursor-language-pack@1.2.0`，拒绝未固定版本；下载的 tarball 必须匹配已知 SHA-512，不匹配立即中止，不会执行任何代码
- 不安装系统服务、不设置开机启动、不修改系统环境
- 只修改 Cursor 安装目录内的 bundle 与 `product.json`，均有备份可还原
- **依赖第三方项目**：`polang233/cursor-language-pack`（MIT），非 Cursor 官方支持
- Cursor 每次自动更新后会覆盖 bundle，需要重跑 `apply.ps1`

## 常见问题

**界面仍是英文？**
确认 `apply.ps1` 传了 `--vsix`，并检查 `verify.ps1` 的 `backup_files` 是否 ≥ 3。

**提示"安装已损坏"？**
校验和未同步。先 `restore.ps1`，再重新 `apply.ps1`。

**从命令行启动 Cursor 报 `bad option`？**
shell 继承了 `ELECTRON_RUN_AS_NODE`，清空该变量后再启动（脚本已自动处理）。

**设置页中文、编辑器英文？**
反过来，说明装的是微软官方包而非本项目。

## 许可证

- 本项目（Skill 与脚本）：MIT
- 上游语言包：`@polang233/cursor-language-pack`（MIT），版权归其作者所有

## 安全设计（可逐条核对）

| 风险 | 本项目的处理 |
|---|---|
| 供应链投毒 | 版本锁定 `1.2.0`，拒绝未固定版本；**每次运行都重新校验 tarball 的 SHA-512**，不匹配立即中止 |
| 缓存投毒 | 不信任任何缓存标记；每次运行都从已校验的 tarball 重新解包到全新目录再执行 |
| 执行时机 | **先下载并校验，全部通过后才关闭 Cursor**；校验失败不会打断你正在用的窗口 |
| 自动执行 | 检测到 Cursor 正在运行就跳过本轮，绝不强杀进程 |
| 回滚 | 上游安装器对每个改动文件做备份（含 sha256），`restore.ps1` 一键还原 |

## 账号安全

本方案**不接触 Cursor 账号**：

- 不读取、不写入登录凭据/token
- 不修改登录状态、不切换账号
- 不向任何服务器上传数据
- 只修改本地安装目录里的界面文案文件

因此不存在"账号被封/被盗"的链路。**但请注意**：修改程序文件本身可能不符合 Cursor 的服务条款，这一点需要你自己判断。

## 官方声明

本项目**与 Cursor（Anysphere, Inc.）没有任何关联**，不是官方产品，也未获其背书。
本项目**与 `polang233/cursor-language-pack` 的作者无隶属关系**，只是调用其公开发布的安装器。

## 免责声明

> **使用本项目即表示你已知悉并接受以下全部内容。**

1. 本项目按 **"AS IS"** 提供，不附带任何明示或暗示的担保，包括但不限于适销性、特定用途适用性和非侵权保证。
2. Cursor 的界面文案与程序结构可能随时变更，**本项目可能失效、导致界面异常、功能缺失或无法启动**。
3. 修改程序文件可能**违反 Cursor 的服务条款**，相关后果由使用者自行承担。
4. 安装目录中的文件会被修改（有备份）。**回滚失败或备份损坏时，你可能需要重新安装 Cursor**，本地设置与扩展可能需要重新配置。
5. 第三方语言包由上游作者维护，其**正确性、安全性、可用性不由本项目负责**。
6. **在法律允许的最大范围内，作者与贡献者不对因使用或无法使用本项目而产生的任何直接、间接、附带、特殊或后果性损失承担责任**，包括但不限于数据丢失、业务中断、账号受限或利润损失。
7. 如果你不接受上述任何一条，**请不要使用本项目**。

## 版本与变更

变更记录见 [CHANGELOG.md](CHANGELOG.md)。安全相关的问题请先阅读 [SECURITY.md](SECURITY.md)。
