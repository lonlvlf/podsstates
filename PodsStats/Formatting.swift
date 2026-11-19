// Formatting.swift
// 时间 / 时长的中文显示格式，与原版 App 截图一致。

import Foundation

enum DurationFormat {

    /// 时长显示："4 h 48 min"、"1 h 9 min"、"48 min"、"2 min"。
    static func hMin(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 { return "\(h) h \(m) min" }
        return "\(m) min"
    }

    /// 时长拆成小时 / 分钟两段，用于大字号 + 小单位混排（如 "4 h 48 min"）。
    static func hMinParts(_ seconds: TimeInterval) -> [(value: String, unit: String)] {
        let totalMinutes = Int((seconds / 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 { return [("\(h)", "h"), ("\(m)", "min")] }
        return [("\(m)", "min")]
    }

    /// 时刻："18:06"。
    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    /// 日期："2026.11.19"。
    static func dottedDate(_ date: Date) -> String {
        dottedDateFormatter.string(from: date)
    }

    /// 日期区间："2026.9.18 – 2026.11.19"。
    static func range(_ start: Date, _ end: Date) -> String {
        "\(dottedDate(start)) – \(dottedDate(end))"
    }

    /// 占比："100%"。
    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: - 私有 formatter（静态复用）

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dottedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy.M.d"
        return f
    }()
}
