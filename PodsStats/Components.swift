// Components.swift
// 通用 UI：磨砂玻璃卡片、大字号时长、时段分布柱状图、时间段选择、示例数据角标。

import SwiftUI

// MARK: - 配色

enum AppColors {
    /// 深蓝青渐变背景（上浅下深，与截图一致）。
    static let backgroundTop = Color(red: 0.08, green: 0.23, blue: 0.31)
    static let backgroundBottom = Color(red: 0.02, green: 0.08, blue: 0.15)
    static let accent = Color(red: 0.56, green: 0.76, blue: 0.91)   // #8FC3E8 左右
    static let cardFill = Color.white.opacity(0.09)
    static let cardBorder = Color.white.opacity(0.14)
    static let secondaryText = Color.white.opacity(0.6)
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - 磨砂玻璃卡片

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardFill)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.cardBorder, lineWidth: 1))
            .cornerRadius(20)
    }
}

// MARK: - 大字号时长（数字大、单位小）

struct BigDurationView: View {
    let seconds: TimeInterval

    var body: some View {
        let parts = DurationFormat.hMinParts(seconds)
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            ForEach(0..<parts.count, id: \.self) { index in
                let part = parts[index]
                Text(part.value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(part.unit)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }
}

// MARK: - 示例数据角标

struct DemoBadge: View {
    var body: some View {
        Text("示例数据")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.yellow.opacity(0.25))
            .foregroundStyle(Color.yellow)
            .clipShape(Capsule())
    }
}

// MARK: - 时间段选择（近7天 / 近30天 / 自选日期）

struct PeriodPills: View {
    @Binding var period: Period
    var onCustomTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases) { p in
                Button {
                    if p == .custom {
                        onCustomTap?()
                    } else {
                        period = p
                    }
                } label: {
                    Text(p.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(period == p ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
                        .foregroundStyle(period == p ? Color.white : AppColors.secondaryText)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(period == p ? 0.25 : 0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 统计小格（标签 + 值 + 备注）

struct StatCell: View {
    let label: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 时段分布柱状图（24 小时，点柱子看该时段时长）

struct HourlyBarChart: View {
    /// 24 小时各自的聆听时长（秒）。
    let hourly: [TimeInterval]
    @Binding var selectedHour: Int?

    private var yMax: TimeInterval {
        let maxValue = hourly.max() ?? 0
        // 向上取整到 25 分钟的倍数，最小 25 分钟。
        let step: TimeInterval = 25 * 60
        return max(step, ceil(maxValue / step) * step)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                // Y 轴刻度
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(yMax / 60))m").font(.caption2).foregroundStyle(AppColors.secondaryText)
                    Spacer()
                    Text("\(Int(yMax / 120))m").font(.caption2).foregroundStyle(AppColors.secondaryText)
                    Spacer()
                    Text("0m").font(.caption2).foregroundStyle(AppColors.secondaryText)
                }
                .frame(width: 30, height: 120)

                // 柱子
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        let height = yMax > 0 ? CGFloat(hourly[hour] / yMax) * 120 : 0
                        Button {
                            selectedHour = (selectedHour == hour) ? nil : hour
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(selectedHour == hour ? AppColors.accent : Color.white.opacity(hourly[hour] > 0 ? 0.45 : 0.15))
                                .frame(height: max(height, hourly[hour] > 0 ? 4 : 2))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: 120)
            }

            // X 轴刻度
            HStack {
                Text("00:00").font(.caption2).foregroundStyle(AppColors.secondaryText)
                Spacer()
                Text("07:00").font(.caption2).foregroundStyle(AppColors.secondaryText)
                Spacer()
                Text("14:00").font(.caption2).foregroundStyle(AppColors.secondaryText)
                Spacer()
                Text("21:00").font(.caption2).foregroundStyle(AppColors.secondaryText)
            }
            .padding(.leading, 30)

            // 选中时段的详情
            if let hour = selectedHour {
                Text("\(hour) 点–\(hour + 1) 点：聆听 \(DurationFormat.hMin(hourly[hour]))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 30)
            } else {
                Text("轻点柱形查看时长")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 30)
            }
        }
    }
}

// MARK: - 按日柱状图（统计页）

struct DailyBarChart: View {
    /// 每天（00:00）的聆听时长。
    let days: [(date: Date, duration: TimeInterval)]

    private var maxDuration: TimeInterval {
        days.map { $0.duration }.max() ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(days.indices, id: \.self) { index in
                    let item = days[index]
                    let height = maxDuration > 0 ? CGFloat(item.duration / maxDuration) * 110 : 0
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.duration > 0 ? AppColors.accent : Color.white.opacity(0.15))
                            .frame(height: max(height, item.duration > 0 ? 4 : 2))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 110)

            if let first = days.first?.date, let last = days.last?.date {
                HStack {
                    Text(DurationFormat.dottedDate(first)).font(.caption2).foregroundStyle(AppColors.secondaryText)
                    Spacer()
                    Text(DurationFormat.dottedDate(last)).font(.caption2).foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - 设备显示名（用户可在设备详情页“编辑”改名，存在 UserDefaults）

enum DeviceNameStore {
    static func displayName(for device: DeviceStats) -> String {
        displayName(forDeviceId: device.id, fallback: device.name)
    }

    static func displayName(forDeviceId id: String, fallback: String) -> String {
        UserDefaults.standard.string(forKey: "deviceDisplayName.\(id)") ?? fallback
    }

    static func setDisplayName(_ name: String, for device: DeviceStats) {
        UserDefaults.standard.set(name, forKey: "deviceDisplayName.\(device.id)")
    }
}
