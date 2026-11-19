// Models.swift
// 数据模型：一次聆听片段、按日统计、按设备统计

import Foundation

/// 一次聆听记录（一段连续的聆听时间）。
/// 由 HealthKit 耳机音频暴露样本合并而来：相邻样本间隔超过 sessionGap 时断开为新的片段。
struct ListeningSession: Identifiable, Hashable {
    let id: UUID
    /// 片段开始时间
    let start: Date
    /// 片段结束时间
    let end: Date
    /// 耳机设备名，如 "AirPods 5 无线充电版"
    let deviceName: String
    /// 设备厂商，如 "Apple Inc."
    let manufacturer: String?
    /// 设备型号代码，如 "0x2030"（HealthKit HKDevice.model，缺失时为空）
    let modelCode: String?
    /// 该片段的平均音量（dB）。HealthKit 样本未必携带音量，缺失时为 nil。
    let averageVolumeDB: Double?

    var duration: TimeInterval { end.timeIntervalSince(start) }
    /// 当天开始的次数等“估算”数字由 HealthKitStore 标注；此处只存原始值。
}

/// 一天的聆听统计。
struct DayStats: Identifiable, Hashable {
    let id = UUID()
    let date: Date          // 当天 00:00
    let totalDuration: TimeInterval
    let sessionCount: Int
    let longestSession: TimeInterval
    /// 24 小时各自的聆听时长（秒），用于“时段分布”柱状图。
    let hourlyDurations: [TimeInterval]   // 长度 24
    let sessions: [ListeningSession]
}

/// 一台设备的累计统计。
struct DeviceStats: Identifiable, Hashable {
    let id: String          // 设备唯一键：厂商 + 型号 + 名称
    let name: String        // 如 "AirPods 5 无线充电版"
    let manufacturer: String?
    let modelCode: String?
    let totalDuration: TimeInterval
    let sessionCount: Int
    let longestSession: TimeInterval
    let averageSession: TimeInterval
    let averageVolumeDB: Double?
    /// 在当前纳入设备中的时长占比（0...1）。
    let shareOfTotal: Double
    /// 有记录的天数。
    let daysWithRecords: Int
    /// 已读取历史的起止日期。
    let historyStart: Date?
    let historyEnd: Date?
}

/// 时间段选择。
enum Period: String, CaseIterable, Identifiable {
    case week = "近7天"
    case month = "近30天"
    case custom = "自选日期"

    var id: String { rawValue }

    /// 该时间段相对今天的起始日（custom 时由调用方传入自定义范围）。
    func startDate(relativeTo today: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .week:  return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: today))!
        case .month: return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: today))!
        case .custom: return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: today))!
        }
    }
}
