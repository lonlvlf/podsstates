// HealthKitStore.swift
// 数据层：向 HealthKit 申请授权、读取耳机聆听数据、合并为聆听片段并汇总统计。
//
// 数据来源说明（已按 Apple HealthKit 文档核对）：
// - 耳机聆听数据使用 HKCategoryTypeIdentifier.headphoneAudioExposure（iOS 14+）。
//   每条样本是一条 HKCategorySample，startDate/endDate 标出一段聆听时间。
//   注意：Apple 官方把这类样本定义为“耳机音频暴露”记录，Health App 用它绘制
//   “耳机音频音量”。本 App 把样本起止时间当作聆听时段来统计，因此所有
//   由样本合并得到的数字（次数、平均每次、最长一次）都在界面上标注“估算”，
//   与原版 App 的做法一致。
// - 音量：样本 metadata 中可能带有 HKMetadataKeyAudioExposureLevel（单位 dBASPL）。
//   该 metadata 并非每条样本都有；读不到时平均音量显示为“—”，不编造数字。
//   代码里用字符串键读取 metadata，避免因常量名差异导致编译失败。
// - 设备：样本的 HKDevice（name / manufacturer / model）标识耳机；
//   取不到 HKDevice 时回退到样本 sourceRevision.source.name。
// - 会话合并：相邻样本间隔 ≤ 10 分钟视为同一次聆听（见 sessionGapSeconds）。
//   该阈值是经验假设，已在 README 中列出。

import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitStore: ObservableObject {

    // MARK: - 公开状态

    /// 健康数据是否可用、授权状态、是否正在用示例数据。
    enum DataMode {
        case loading
        case live            // 真实 HealthKit 数据
        case demo            // 示例数据（未授权 / 无数据 / 设备不支持）
    }

    @Published var mode: DataMode = .loading
    @Published var authorizationDenied = false
    @Published var today: DayStats?
    @Published var allSessions: [ListeningSession] = []
    @Published var devices: [DeviceStats] = []
    @Published var lastError: String?

    /// 相邻样本间隔超过该值（秒）即断开为新的聆听片段。假设值，见 README。
    static let sessionGapSeconds: TimeInterval = 10 * 60

    /// 示例数据最晚日期固定为 2026-11-19（与截图一致）；真实数据始终以当天为准。
    static let demoReferenceDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 19
        return Calendar.current.date(from: c) ?? Date()
    }()

    // MARK: - 私有

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private var headphoneExposureType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .headphoneAudioExposure)
    }

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 统计的基准日期：真实数据用当天，示例数据固定为 2026-11-19（与截图一致），
    /// 这样示例模式下“今天”“近7天”等页面都有内容可看。
    var referenceDate: Date { mode == .demo ? DemoData.demoToday : Date() }

    // MARK: - 授权

    /// 请求读取耳机音频暴露数据的权限。只读，不写回任何数据。
    func requestAuthorization() async {
        guard isHealthDataAvailable, let type = headphoneExposureType else {
            loadDemo(reason: "此设备不支持健康数据")
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [type])
            let status = healthStore.authorizationStatus(for: type)
            if status == .sharingDenied {
                authorizationDenied = true
                loadDemo(reason: "未获得健康数据授权")
            } else {
                await reloadAll()
            }
        } catch {
            lastError = error.localizedDescription
            loadDemo(reason: "授权失败")
        }
    }

    // MARK: - 读取与汇总

    /// 读取最近 `days` 天的全部样本并汇总。
    func reloadAll(days: Int = 90) async {
        mode = .loading
        guard let type = headphoneExposureType else {
            loadDemo(reason: "此设备不支持健康数据")
            return
        }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: end))!
        let samples = await fetchSamples(type: type, from: start, to: end)
        if samples.isEmpty {
            loadDemo(reason: "健康数据中暂无耳机聆听记录")
            return
        }
        let sessions = Self.mergeSessions(from: samples)
        allSessions = sessions
        devices = Self.summarizeDevices(sessions: sessions)
        today = Self.dayStats(for: calendar.startOfDay(for: Date()), sessions: sessions)
        mode = .live
    }

    /// 读取某一天的统计（用于“今天”页切换日期）。
    func dayStats(for day: Date) -> DayStats {
        if mode == .demo {
            return DemoData.dayStats(for: day)
        }
        return Self.dayStats(for: day, sessions: allSessions)
    }

    /// 读取某段时间的全部会话（用于“统计”页）。
    func sessions(from start: Date, to end: Date) -> [ListeningSession] {
        if mode == .demo {
            return DemoData.sessions(from: start, to: end)
        }
        return allSessions.filter { $0.start >= start && $0.start < end }
    }

    /// 读取某段时间的设备统计（用于“设备”页及设备详情）。
    func deviceStats(from start: Date, to end: Date) -> [DeviceStats] {
        if mode == .demo {
            return DemoData.deviceStats(from: start, to: end)
        }
        return Self.summarizeDevices(sessions: sessions(from: start, to: end))
    }

    // MARK: - HealthKit 查询

    private func fetchSamples(type: HKCategoryType, from start: Date, to end: Date) async -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    Task { @MainActor in self.lastError = error.localizedDescription }
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 会话合并与汇总（纯函数，便于测试与复用）

    /// 把原始样本按时间排序，相邻间隔 ≤ sessionGapSeconds 的合并为一次聆听。
    static func mergeSessions(from samples: [HKCategorySample]) -> [ListeningSession] {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var sessions: [ListeningSession] = []
        var currentStart: Date?
        var currentEnd: Date?
        var currentDeviceName = ""
        var currentManufacturer: String?
        var currentModelCode: String?
        var volumes: [Double] = []

        func flush() {
            guard let s = currentStart, let e = currentEnd else { return }
            let avgVolume = volumes.isEmpty ? nil : volumes.reduce(0, +) / Double(volumes.count)
            sessions.append(ListeningSession(
                id: UUID(), start: s, end: e,
                deviceName: currentDeviceName.isEmpty ? "未知设备" : currentDeviceName,
                manufacturer: currentManufacturer, modelCode: currentModelCode,
                averageVolumeDB: avgVolume))
        }

        for sample in sorted {
            let device = sample.device
            let name = device?.name ?? sample.sourceRevision.source.name
            let volume = (sample.metadata?["HKMetadataKeyAudioExposureLevel"] as? NSNumber)?.doubleValue
            if let s = currentStart, let e = currentEnd {
                if sample.startDate.timeIntervalSince(e) <= sessionGapSeconds {
                    // 同一次聆听：延长结束时间，累计音量
                    currentEnd = max(e, sample.endDate)
                    if let volume { volumes.append(volume) }
                    continue
                } else {
                    flush()
                }
            }
            currentStart = sample.startDate
            currentEnd = sample.endDate
            currentDeviceName = name
            currentManufacturer = device?.manufacturer
            currentModelCode = device?.model
            volumes = volume.map { [$0] } ?? []
        }
        flush()
        return sessions
    }

    /// 某一天的统计。
    static func dayStats(for day: Date, sessions: [ListeningSession]) -> DayStats {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        // 会话可能跨午夜：按与当天的重叠部分计入当日。
        var hourly = [TimeInterval](repeating: 0, count: 24)
        var total: TimeInterval = 0
        var daySessions: [ListeningSession] = []
        for session in sessions {
            let overlapStart = max(session.start, dayStart)
            let overlapEnd = min(session.end, dayEnd)
            guard overlapEnd > overlapStart else { continue }
            daySessions.append(session)
            total += overlapEnd.timeIntervalSince(overlapStart)
            // 把重叠部分按小时切分
            var cursor = overlapStart
            while cursor < overlapEnd {
                let hour = calendar.component(.hour, from: cursor)
                let nextHour = calendar.date(byAdding: .hour, value: 1, to: calendar.startOfDay(for: cursor).addingTimeInterval(TimeInterval(hour) * 3600)) ?? overlapEnd
                let segmentEnd = min(nextHour, overlapEnd)
                hourly[hour] += segmentEnd.timeIntervalSince(cursor)
                cursor = segmentEnd
            }
        }
        let longest = daySessions.map(\.duration).max() ?? 0
        return DayStats(date: dayStart, totalDuration: total, sessionCount: daySessions.count,
                        longestSession: longest, hourlyDurations: hourly, sessions: daySessions)
    }

    /// 按设备汇总。
    static func summarizeDevices(sessions: [ListeningSession]) -> [DeviceStats] {
        let grouped = Dictionary(grouping: sessions) { $0.deviceName }
        let grandTotal = sessions.reduce(0) { $0 + $1.duration }
        return grouped.map { name, list in
            let total = list.reduce(0) { $0 + $1.duration }
            let volumes = list.compactMap(\.averageVolumeDB)
            let days = Set(list.map { Calendar.current.startOfDay(for: $0.start) }).count
            let deviceDates = list.map(\.start)
            return DeviceStats(
                id: name,
                name: name,
                manufacturer: list.first?.manufacturer,
                modelCode: list.first?.modelCode,
                totalDuration: total,
                sessionCount: list.count,
                longestSession: list.map(\.duration).max() ?? 0,
                averageSession: list.isEmpty ? 0 : total / Double(list.count),
                averageVolumeDB: volumes.isEmpty ? nil : volumes.reduce(0, +) / Double(volumes.count),
                shareOfTotal: grandTotal > 0 ? total / grandTotal : 0,
                daysWithRecords: days,
                historyStart: deviceDates.min(),
                historyEnd: deviceDates.max())
        }.sorted { $0.totalDuration > $1.totalDuration }
    }

    // MARK: - 示例数据

    private func loadDemo(reason: String) {
        lastError = reason
        allSessions = DemoData.allSessions
        devices = DemoData.deviceStats(from: DemoData.historyStart, to: DemoData.historyEnd)
        today = DemoData.dayStats(for: calendar.startOfDay(for: DemoData.demoToday))
        mode = .demo
    }
}
