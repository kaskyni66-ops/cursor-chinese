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

### 4. 回滚

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

## 免责声明

本项目不是 Cursor 官方产品，修改程序文件可能违反其服务条款。使用前请自行评估，风险自负。
