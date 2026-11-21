# YSP PC Monitor

这是运行在 Clocteck HoloCubic Lua 固件上的 PC 性能监控应用。它从 Windows 侧 `holo-bridge` 拉取数据，在设备上显示 `SYSTEM`、`THERMAL`、`POWER`、`NETWORK` 四页，也可在同一应用内切到 Bambu Lab X2D 状态。Windows bridge 不在这个 Git 仓库里；本库的 `holo_pc_monitor` 和 `aida_monitor` 是不同应用。

## 代码入口

| 文件 | 职责 |
| --- | --- |
| [`package/app.info`](package/app.info) | 应用名、入口和版本；应用 ID 由 SD 目录名 `ysp_pc_monitor` 决定 |
| [`package/config.lua`](package/config.lua) | Windows bridge 主机、端口、路径、超时与串口日志 |
| [`package/pc_client.lua`](package/pc_client.lua) | TCP 连接、HTTP SSE 行解析、样本校验、超时与退避重连 |
| [`package/pc_state.lua`](package/pc_state.lua) | 最近有效样本、采样历史和在线状态 |
| [`package/main.lua`](package/main.lua) | 初始化、定时器、翻页、应用退出和渲染调度 |
| [`package/mic_tap.lua`](package/mic_tap.lua) | 本地识别双敲和三敲，不保存或发送音频 |
| [`package/printer_client.lua`](package/printer_client.lua) | 异步读取 X2D 快照，独立处理无数据和过期 |
| [`package/pages/`](package/pages/) 和 [`package/widgets/`](package/widgets/) | 页面与通用绘制、格式化函数 |

[平台 Lua API](../README_LUA.md) 和 [LVGL API](../README_LVGL.md) 用于确认设备运行时支持的接口。[HUD 预览](design/hud_preview.html) 是设计参考，不代替设备验证。

## 连接与显示

- 设备用 `config.host` 指向 **Windows 的局域网地址**，而不是设备自己的地址。当前默认端口 `28765`，路径 `/sse`。主机地址以配置文件为准，不把机器专用地址抄进其他文档。
- 客户端处理 `data: …` 行，按 `{|}` 分隔条目。至少解析出一个已知数值指标才算有效样本；不要求 GPU 指标存在。变更 bridge 的 SSE 字段时，要同时检查 Lua 的字段映射。
- 当前 TCP 建连超时为 7 秒，连接内 5 秒没有有效样本会重连，退避从 2 秒加到最多 30 秒，收到有效样本后重置。显示层在约 10 秒没有有效样本后将数据标记为过期，收到两个有效样本后恢复在线。
- 从未收到足够有效样本时显示 `PC // NO DATA`；曾在线时保留当前页与最后的有效数据并标记 `STALE DATA`。恢复后保留当前页。旧版本的 `PC // SLEEP` 不是休眠检测结果。

## 翻页与切换视图

- 在线时，向左或向右倾斜仍可翻页。设备平放时，轻敲底座两下去下一页，双敲与倾斜共用翻页冷却。双敲在第二下后约等半秒，确认没有第三下才翻页。
- 连续轻敲三下切到 X2D，再三下回到之前的 PC 页。三敲不受两边的数据在线状态限制；在 X2D 视图中，双敲和倾斜不会改变隐藏的 PC 页。后台继续接收 PC 样本并记录历史。
- PC 视图停留在非 `SYSTEM` 页面时，60 秒内没有成功切换 PC 页面会自动回到 `SYSTEM`。手动翻页会重新计时；SSE 样本和连接状态变化不会续期。X2D 显示期间暂停此计时，三敲返回时保留原 PC 页并重新开始 60 秒。
- 仅在 X2D 视图打开时轮询 Windows bridge 的 `/printer/status`。首次没样本显示 `NO DATA`，掉线保留最后读数并显示 `STALE DATA`。这依赖 Windows bridge 运行并启用 X2D 采集；Cubic 不直连打印机，也不控制打印。
- X2D 页显示左右喷嘴各自的实际温度（来自 extruder ID 0/1），以及床温、腔温、进度、耗材和 AMS 相对湿度；无有效读数时显示 `--`。
- 手势只在本应用运行时使用麦克风，灵敏度阈值仍为 `1200`，只统计瞬时峰值。若误触或需要让出麦克风，在设备 `config.lua` 的 `return config` 前加入 `config.mic_double_tap = false`，再重启应用，即可同时关闭两种敲击手势。麦克风不可用时，倾斜翻页和 PC 监控不受影响。

## 部署与回滚

1. 在设备上确认目标是 `/sd/apps/ysp_pc_monitor/`，先备份将替换的文件。首次安装时，将 `package/` 的**内容**复制到该目录，不额外嵌套 `package`。设备端的 `config.lua` 可能针对当前网络配置，不要无意覆盖。
2. 用 SD 卡或同局域网的 [DevTools](../README.md) 更新文件。如果使用 HTTP，设备有 DevTools 时可通过 `/devtools/` 操作，固件文件 API 的上传入口是 `PUT /api/system/fs/upload?path=...`。更新现有应用时优先上传临时副本、回读校验，再替换正式文件并保留旧文件。
3. 首次安装后重扫应用列表；更新后退出并重新启动 `ysp_pc_monitor`，确保重新加载 Lua。支持固件应用 API 时可用空请求体 `POST /api/system/exit` 退出前台应用，再用 `POST /api/system/launch?id=ysp_pc_monitor` 启动；`GET /api/system/state` 可核对 `current_app.id`。若接口不可用，从设备 launcher 操作即可。
4. 若启动异常，恢复备份，并重新启动应用。这里不涉及刷写整机固件。

## 验证与排障

- 有标准 Lua 编译器时，在仓库根运行 `Get-ChildItem .\ysp_pc_monitor\package -Recurse -Filter *.lua | ForEach-Object { luac -p $_.FullName; if ($LASTEXITCODE -ne 0) { throw "Lua syntax check failed: $($_.FullName)" } }`。语法通过不代表设备绑定 API 测试通过。
- 修改连接或显示状态时，覆盖首次无数据、TCP 超时、连接后无有效首帧、旧连接回调、断线保留数据、恢复后保留页面等场景。当前目录没有提交自动化测试套件。
- 真机上先核对上传文件和当前应用，再看是否连回 Windows bridge。串口开启时可查 `[ysp-pc-monitor]` 的 `timeout connect`、`stale`、`presence offline/online` 日志。如果打开串口触发复位，不要将那次复位当作原故障证据。
