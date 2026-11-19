// StatsView.swift
// “统计”页：时间段选择、总时长与各项汇总、按日柱状图、按设备占比。

import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: HealthKitStore
    @State private var period: Period = .week
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -29, to: Date())!
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false

    private var calendar: Calendar { Calendar.current }

    private var rangeStart: Date {
        if period == .custom {
            return calendar.startOfDay(for: customStart)
        }
        return period.startDate(relativeTo: store.referenceDate)
    }

    private var rangeEnd: Date {
        if period == .custom {
            // 自选结束日含当天：取次日 00:00 作为上界。
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd))!
        }
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: store.referenceDate))!
    }

    private var sessions: [ListeningSession] {
        store.sessions(from: rangeStart, to: rangeEnd)
    }

    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    private var averageSession: TimeInterval {
        sessions.isEmpty ? 0 : totalDuration / Double(sessions.count)
    }

    private var longestSession: TimeInterval {
        sessions.map(\.duration).max() ?? 0
    }

    private var averageVolume: Double? {
        let volumes = sessions.compactMap(\.averageVolumeDB)
        guard !volumes.isEmpty else { return nil }
        return volumes.reduce(0, +) / Double(volumes.count)
    }

    /// 区间内每一天的时长（用于按日柱状图）。
    private var dailyTotals: [(date: Date, duration: TimeInterval)] {
        var day = rangeStart
        var result: [(Date, TimeInterval)] = []
        while day < rangeEnd {
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            let total = sessions.reduce(0) { partial, s in
                let overlapStart = max(s.start, day)
                let overlapEnd = min(s.end, next)
                return partial + max(0, overlapEnd.timeIntervalSince(overlapStart))
            }
            result.append((day, total))
            day = next
        }
        return result
    }

    private var deviceStats: [DeviceStats] {
        store.deviceStats(from: rangeStart, to: rangeEnd)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("统计")
                        .font(.largeTitle.weight(.bold))
                    if store.mode == .demo {
                        DemoBadge()
                    }
                    Spacer()
                }

                PeriodPills(period: $period) {
                    showCustomPicker = true
                }

                Text(DurationFormat.range(rangeStart, calendar.date(byAdding: .day, value: -1, to: rangeEnd)!))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)

                // 总时长
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("累计聆听时长")
                            .font(.headline)
                            .foregroundStyle(AppColors.secondaryText)
                        BigDurationView(seconds: totalDuration)
                        Divider().background(Color.white.opacity(0.15))
                        HStack(spacing: 24) {
                            StatCell(label: "佩戴次数", value: "\(sessions.count) 次", footnote: "估算")
                            StatCell(label: "平均每次", value: DurationFormat.hMin(averageSession), footnote: "有效聆听 · 估算")
                            StatCell(label: "最长一次", value: DurationFormat.hMin(longestSession), footnote: "有效聆听 · 估算")
                        }
                        HStack(spacing: 24) {
                            StatCell(label: "平均音量", value: averageVolume.map { "\(Int($0.rounded())) dB" } ?? "—", footnote: "读不到音量时显示 —")
                            StatCell(label: "日均聆听", value: dailyTotals.isEmpty ? "—" : DurationFormat.hMin(totalDuration / Double(dailyTotals.count)), footnote: "按所选周期天数")
                            StatCell(label: "有记录天数", value: "\(dailyTotals.filter { $0.duration > 0 }.count) 天", footnote: "")
                        }
                    }
                }

                // 按日柱状图
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("每日聆听")
                            .font(.headline)
                        DailyBarChart(days: dailyTotals)
                    }
                }

                // 按设备占比
                if !deviceStats.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("按设备")
                            .font(.headline)
                        ForEach(deviceStats) { device in
                            NavigationLink(value: device) {
                                GlassCard {
                                    HStack {
                                        Image(systemName: "headphones")
                                            .foregroundStyle(AppColors.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(DeviceNameStore.displayName(for: device))
                                                .font(.headline)
                                            Text("\(device.sessionCount) 次 · 平均音量 \(device.averageVolumeDB.map { "\(Int($0.rounded())) dB" } ?? "—")")
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.secondaryText)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(DurationFormat.hMin(device.totalDuration))
                                                .font(.headline)
                                            Text(DurationFormat.percent(device.shareOfTotal))
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.secondaryText)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .navigationDestination(for: DeviceStats.self) { device in
            DeviceDetailView(device: device)
        }
        .sheet(isPresented: $showCustomPicker) {
            CustomPeriodPickerView(start: $customStart, end: $customEnd) {
                period = .custom
                showCustomPicker = false
            } onCancel: {
                showCustomPicker = false
            }
        }
    }
}

// MARK: - 自选日期弹窗

struct CustomPeriodPickerView: View {
    @Binding var start: Date
    @Binding var end: Date
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("开始日期", selection: $start, in: ...Date(), displayedComponents: .date)
                DatePicker("结束日期", selection: $end, in: start...Date(), displayedComponents: .date)
            }
            .navigationTitle("自选日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定", action: onConfirm)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
