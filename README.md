# Pods Stats（复刻版）— iOS 原生 App

照原版 Pods Stats 截图复刻的耳机聆听统计 App：今天 / 统计 / 设备三页，数据来自 iPhone 自带的“健康”App（耳机音频暴露记录），只在手机本地统计，不联网、不注册账号、不含广告。

## 功能对照（按截图）

- **今天**：日期切换（< >）、当天累计聆听时长、当天开始次数（估算）、最长当日片段、时段分布柱状图（点柱子看该时段时长）、聆听记录（点进单条详情）。
- **统计**：近 7 天 / 近 30 天 / 自选日期；累计时长、佩戴次数、平均每次、最长一次、平均音量、日均聆听、每日柱状图、按设备占比。
- **设备**：按耳机分组的累计统计；设备详情页有累计时长、占比、所选周期（厂商 · 型号代码）、已读取历史与有记录日、累计佩戴次数 / 平均每次 / 最长一次 / 平均音量；右上角“编辑”可改名（只改本机显示）。
- **设置**（今天页右上角齿轮）：数据来源（真实数据 / 示例数据）、健康授权状态、重新请求授权、打开系统设置。
- 未授权、无数据或设备不支持时，显示明确标注“示例数据”的演示内容（数值与截图一致：2026-11-19 当天 4 h 48 min、14 次、最长 1 h 9 min；AirPods 5 累计 369 h 5 min、786 次），绝不出现空白页。

## 文件结构

```
PodsStats.xcodeproj/          Xcode 工程（scheme：PodsStats，target：PodsStats）
PodsStats/
  PodsStatsApp.swift          App 入口 + 底部悬浮胶囊 Tab 栏
  Models.swift                ListeningSession / DayStats / DeviceStats / Period
  HealthKitStore.swift        授权、读数、会话合并、汇总统计
  DemoData.swift              示例数据（确定性生成，每次启动相同）
  Formatting.swift            时长/日期显示格式
  Components.swift            玻璃卡片、柱状图、时间段选择等通用组件
  TodayView.swift             今天页
  StatsView.swift             统计页
  DevicesView.swift           设备页
  DeviceDetailView.swift      设备详情页
  SessionDetailView.swift     单条聆听记录详情
  SettingsView.swift          设置页
  Info.plist                  含健康数据使用说明（中文）
  PodsStats.entitlements      HealthKit 权限
  LaunchScreen.storyboard     启动屏（深色底）
  Assets.xcassets/            App 图标（耳机图案）+ 强调色
build-ipa.sh                  本地/云端编译未签名 IPA 的脚本
.github/workflows/build-ipa.yml   GitHub Actions 云端编译工作流
```

## 办法一：在 Mac 上本地编译 IPA

需要一台 Mac + Xcode 16（iOS 17 SDK），不需要开发者账号、不需要证书：

```bash
./build-ipa.sh
```

产物在 `./build/PodsStats.ipa`。也可以在 Xcode 里打开 `PodsStats.xcodeproj`，选真机或 Generic iOS Device，Product → Build（签名已在工程里关掉：Manual、无 Team、`CODE_SIGNING_ALLOWED=NO`）。

## 办法二：GitHub Actions 云端编译（不用 Mac）

1. 在 GitHub 新建一个仓库（公开或私有都行），把本目录所有文件推上去（`main` 分支）。
2. 打开仓库页面 → Actions → 找到 `Build unsigned IPA` → Run workflow（或直接推一次代码自动触发）。
3. 等工作流跑完（约 3–8 分钟），在该次运行页面底部下载 `PodsStats-unsigned-ipa`（里面是 `PodsStats.ipa`）。

## 安装到 iPhone（AltStore 侧载，Windows 电脑）

1. **电脑准备**：到 [altstore.io](https://altstore.io) 下载安装 AltServer（Windows 版）；再装苹果官网的 iTunes（不要用微软商店版）和 iCloud for Windows；重启电脑。
2. **手机连电脑**：iPhone 用数据线连电脑，点“信任此电脑”；打开 AltServer（任务栏小图标）→ Install AltStore → 选你的 iPhone → 输入你的 Apple ID 和密码（只发给苹果用于签发 7 天证书，不经过任何第三方服务器）。
3. **信任证书**：手机上打开 设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → 信任。
4. **装 IPA**：把 `PodsStats.ipa` 传到手机（iCloud 云盘 / 微信文件传输助手 / U 盘都行），在手机“文件”里点开 IPA → 分享 → 用 AltStore 打开；或在 AltStore 里点 + 号选 IPA。AltStore 会用你的免费 Apple ID 签名安装。
5. **首次打开**：App 会弹健康授权，点“允许”后即可看到真实数据。免费 Apple ID 的限制：证书 7 天过期，同时最多装 3 个侧载 App；AltServer 在电脑上开着且手机连同一 Wi-Fi 时，AltStore 会自动续签（需在 iTunes 里开启“通过 Wi-Fi 与此 iPhone 同步”）。
6. 装好后 App 完全离线使用：不联网、不开代理、不用打开 Muse。

## 数据与隐私

- 只读 `HKCategoryTypeIdentifier.headphoneAudioExposure`（耳机音频暴露记录，iOS 14+），不写回任何数据。
- 音量取样本 metadata 里的 `HKMetadataKeyAudioExposureLevel`（单位 dBASPL），读不到的样本不计入平均音量。
- 设备按样本的 `HKDevice`（名称 / 厂商 / 型号）分组，取不到时回退到数据来源名称。
- 改名、统计周期等设置只存在本机 UserDefaults。

## 假设与已知事项

- **会话合并**：相邻记录间隔 ≤ 10 分钟视为同一次聆听；超过即断开。因此次数、平均每次、最长一次均为估算值，界面上按原版标注“估算”。
- **平均音量**：对有音量值的样本取算术平均；全部样本都没有音量时显示“—”。
- **示例数据**：确定性伪随机生成，数值与截图一致（今天 4 h 48 min / 14 次 / 最长 1 h 9 min；设备累计 369 h 5 min / 786 次 / 平均 0 h 28 min / 最长 7 h 16 min / 平均音量 67；历史 2026.9.18–2026.11.19，62 个有记录日）。
- **HealthKit 与免费签名**：HealthKit 是设备本地能力，免费 Apple ID 签名同样可用（与 Loop 等开源健康 App 的侧载做法相同）。万一某台设备上 AltStore 签名时丢掉了 HealthKit 权限，App 会在设置页显示具体错误并回落到示例数据，不会闪退或空白。
- **未在本机编译验证**：本工程在 Linux 上编写，无法运行 Xcode；首次在 Mac / GitHub Actions 上编译时如遇报错，把报错贴回来即可定位（最可能的是 Xcode 版本低于 16 或 workflow 的 macOS 镜像里没有 Xcode 16.2，脚本里已做了回落处理）。
