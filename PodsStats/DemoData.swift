// DemoData.swift
// 示例数据：未授权 / 无数据 / 不支持 HealthKit 时使用，保证每个界面都有内容可看。
// 数值与原版 App 截图一致：
//   今天（2026-11-19）累计 4 h 48 min、14 次、最长 1 h 9 min；
//   设备 AirPods 5 无线充电版累计 369 h 5 min、786 次、平均 0 h 28 min、
//   最长 7 h 16 min、平均音量 67、历史 2026.9.18 – 2026.11.19、62 个有记录日。
// 生成方式：确定性伪随机（固定种子），每次启动结果相同；
// 除今天外的 61 天会话总时长经缩放校准，使设备累计恰好等于 369 h 5 min。

import Foundation

enum DemoData {

    static let deviceName = "AirPods 5 无线充电版"
    static let manufacturer = "Apple Inc."
    static let modelCode = "0x2030"

    /// 演示“今天”
    static let demoToday: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 19
        return Calendar.current.date(from: c)!
    }()

    /// 历史起日 2026-09-18，止日 2026-11-19（共 63 天，其中 2026-10-05 无记录 → 62 个有记录日）。
    static let historyStart: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 18
        return Calendar.current.date(from: c)!
    }()
    static let historyEnd: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 19; c.hour = 23; c.minute = 59
        return Calendar.current.date(from: c)!
    }()

    static let targetDeviceTotalSeconds: TimeInterval = 369 * 3600 + 5 * 60   // 369 h 5 min
    static let targetSessionCount = 786
    static let targetLongestSeconds: TimeInterval = 7 * 3600 + 16 * 60        // 7 h 16 min
    static let targetAverageVolumeDB = 67.0

    // MARK: - 生成

    /// 全部示例会话（按时间排序）。
    static let allSessions: [ListeningSession] = generate()

    static func sessions(from start: Date, to end: Date) -> [ListeningSession] {
        allSessions.filter { $0.start >= start && $0.start < end }
    }

    static func dayStats(for day: Date) -> DayStats {
        HealthKitStore.dayStats(for: day, sessions: allSessions)
    }

    static func deviceStats(from start: Date, to end: Date) -> [DeviceStats] {
        HealthKitStore.summarizeDevices(sessions: sessions(from: start, to: end))
    }

    // MARK: - 私有生成逻辑

    /// 今天的 14 次聆听（与截图一致：合计 4 h 48 min，最长 1 h 9 min，含 18:06–18:08）。
    private static func todaySessions() -> [ListeningSession] {
        let day = demoToday
        func at(_ hour: Int, _ minute: Int, durationMinutes: Int) -> ListeningSession {
            let cal = Calendar.current
            let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
            return ListeningSession(id: UUID(), start: start,
                                    end: start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                                    deviceName: deviceName, manufacturer: manufacturer,
                                    modelCode: modelCode, averageVolumeDB: targetAverageVolumeDB)
        }
        return [
            at(5, 2, durationMinutes: 48),
            at(6, 5, durationMinutes: 30),
            at(6, 50, durationMinutes: 25),
            at(7, 20, durationMinutes: 20),
            at(7, 50, durationMinutes: 28),
            at(8, 40, durationMinutes: 12),
            at(9, 15, durationMinutes: 10),
            at(10, 5, durationMinutes: 2),
            at(13, 5, durationMinutes: 8),
            at(13, 40, durationMinutes: 69),
            at(15, 0, durationMinutes: 20),
            at(16, 10, durationMinutes: 4),
            at(17, 0, durationMinutes: 10),
            at(18, 6, durationMinutes: 2),
        ]
    }

    private static func generate() -> [ListeningSession] {
        var rng = SeededRandom(seed: 20261119)
        let cal = Calendar.current
        var sessions = todaySessions()
        let todayTotal = sessions.reduce(0) { $0 + $1.duration }

        // 其余 61 天：2026-09-18 至 2026-11-18，跳过 2026-10-05（无记录日）。
        var otherDays: [Date] = []
        var d = historyStart
        while d < cal.startOfDay(for: demoToday) {
            if !(cal.component(.month, from: d) == 10 && cal.component(.day, from: d) == 5) {
                otherDays.append(d)
            }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        // 其中一天只放一次 7 h 16 min 的超长聆听（“最长一次”），当天不再生成其他会话。
        let longDayIndex = otherDays.count / 2
        let longDay = otherDays[longDayIndex]
        let longStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: longDay)!
        let longSession = ListeningSession(id: UUID(), start: longStart,
                                           end: longStart.addingTimeInterval(targetLongestSeconds),
                                           deviceName: deviceName, manufacturer: manufacturer,
                                           modelCode: modelCode, averageVolumeDB: targetAverageVolumeDB)

        // 其余 60 天：总次数 786 - 14（今天） - 1（超长那天）= 771 次，均匀分配（51 天 13 次，9 天 12 次）。
        let normalDays = otherDays.enumerated().filter { $0.offset != longDayIndex }.map { $0.element }
        let totalNormal = targetSessionCount - todaySessions().count - 1
        let base = totalNormal / normalDays.count
        var remainder = totalNormal % normalDays.count
        var counts: [Int] = normalDays.map { _ in base }
        var i = 0
        while remainder > 0 { counts[i % counts.count] += 1; remainder -= 1; i += 1 }

        var others: [ListeningSession] = [longSession]
        for (day, count) in zip(normalDays, counts) {
            // 每天最多 13 次 × (40 分钟 + 25 分钟间隔) = 845 分钟，从 7:00 起算不会超出当天。
            var cursor = cal.date(bySettingHour: 7, minute: rng.nextInt(in: 0...30), second: 0, of: day)!
            for _ in 0..<count {
                let minutes = rng.nextInt(in: 8...40)
                let volume = 62.0 + Double(rng.nextInt(in: 0...10))
                others.append(ListeningSession(id: UUID(), start: cursor,
                                              end: cursor.addingTimeInterval(TimeInterval(minutes * 60)),
                                              deviceName: deviceName, manufacturer: manufacturer,
                                              modelCode: modelCode, averageVolumeDB: volume))
                cursor = cursor.addingTimeInterval(TimeInterval((minutes + rng.nextInt(in: 5...25)) * 60))
            }
        }

        // 缩放（不含超长会话和今天）：使“今天以外”的总时长恰好等于目标总时长减去今天与超长会话。
        let targetOthers = targetDeviceTotalSeconds - todayTotal - targetLongestSeconds
        let scalable = others.filter { $0.id != longSession.id }
        let actualOthers = scalable.reduce(0) { $0 + $1.duration }
        let factor = targetOthers / actualOthers
        var scaled: [ListeningSession] = [longSession]
        for s in scalable {
            let newDuration = max(300, (s.duration * factor).rounded())
            scaled.append(ListeningSession(id: s.id, start: s.start,
                                           end: s.start.addingTimeInterval(newDuration),
                                           deviceName: s.deviceName, manufacturer: s.manufacturer,
                                           modelCode: s.modelCode, averageVolumeDB: s.averageVolumeDB))
        }

        // 注意：缩放后极少数相邻会话可能重叠约 1 分钟（缩放倍率 1.17 下，
        // 只有“原长 ≥34 分钟且间隔恰好 5 分钟”的组合才会重叠），
        // 在按日柱状图上完全看不出来；不做截断处理，以保证累计总时长精确等于目标值。
        sessions.append(contentsOf: scaled)
        return sessions.sorted { $0.start < $1.start }
    }
}

/// 确定性伪随机数发生器（xorshift64*），保证示例数据每次启动都相同。
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        var x = state
        x ^= x >> 12; x ^= x << 25; x ^= x >> 27
        state = x
        return x &* 0x2545F4914F6CDD1D
    }
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(next() % UInt64(span))
    }
}
