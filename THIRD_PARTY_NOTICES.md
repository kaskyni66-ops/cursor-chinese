# 第三方组件声明

本仓库在 `vendor/` 目录中**原样收录**了以下第三方发行包，用于让安装过程完全不联网：

## @polang233/cursor-language-pack

| 项目 | 值 |
|---|---|
| 名称 | `@polang233/cursor-language-pack` |
| 版本 | `1.2.0` |
| 作者 | polang233 |
| 仓库 | https://github.com/polang233/cursor-language-pack |
| 许可证 | MIT |
| 文件 | `vendor/polang233-cursor-language-pack-1.2.0.tgz` |
| SHA-512 | `sha512-qTJNW44qwKMmQeqRcWGdVzF6e2CKte6BF1Rxt94jeRi9ZHe/WHsWPSDru6DExcvWrby7iFlIn69kzJkCQrtleg==` |

该包未做任何修改，逐字节与 npm 发布版本一致（脚本在每次运行时会校验上表中的 SHA-512）。

### 许可证

```
MIT License

Copyright (c) polang233

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 说明

- 本项目的作者与上述第三方作者**没有隶属或合作关系**
- 该语言包的更新、缺陷与安全由上游作者负责
- 若你不同意随附该第三方包，可删除 `vendor/` 目录；脚本会自动回退到从 npm 下载同一固定版本并校验哈希
