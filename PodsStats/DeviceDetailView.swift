// DeviceDetailView.swift
// 设备详情页：累计时长、占比、所选周期、累计统计 2×2。

import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceStats
    @EnvironmentObject private var store: HealthKitStore
    @State private var period: Period = .month
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -29, to: Date())!
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false
    @State private var showRename = false
    @State private var newName = ""
    @State private var displayName = ""

    private var calendar: Calendar { Calendar.current }

    /// 当前周期内该设备的统计（按周期重新汇总）。
    private var stats: DeviceStats {
        let start: Date
        let end: Date
        if period == .custom {
            start = calendar.startOfDay(for: customStart)
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd))!
        } else {
            start = period.startDate(relativeTo: store.referenceDate)
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: store.referenceDate))!
        }
        let inRange = store.deviceStats(from: start, to: end)
        // deviceStats 汇总时占比按“当前纳入设备”计算；此处只取本设备那一行。
        return inRange.first { $0.id == device.id }
            ?? DeviceStats(id: device.id, name: device.name, manufacturer: device.manufacturer,
                           modelCode: device.modelCode, totalDuration: 0, sessionCount: 0,
                           longestSession: 0, averageSession: 0, averageVolumeDB: nil,
                           shareOfTotal: 0, daysWithRecords: 0, historyStart: nil, historyEnd: nil)
    }

    /// 所选周期的起止（用于“所选周期 …”一行）。
    private var periodRangeText: String {
        if period == .custom {
            return DurationFormat.range(calendar.startOfDay(for: customStart), customEnd)
        }
        let start = period.startDate(relativeTo: store.referenceDate)
        return DurationFormat.range(start, store.referenceDate)
    }

    private var historyText: String {
        if let start = stats.historyStart, let end = stats.historyEnd {
            return "已读取历史 \(DurationFormat.range(start, end)) · \(stats.daysWithRecords) 个有记录日"
        }
        if let start = device.historyStart, let end = device.historyEnd {
            return "已读取历史 \(DurationFormat.range(start, end)) · \(device.daysWithRecords) 个有记录日"
        }
        return "暂无读取历史"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero 卡片
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "headphones")
                                    .font(.title2)
                                    .foregroundStyle(AppColors.accent)
                            }
                            Text("通用耳机图示")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                            Spacer()
                            if store.mode == .demo {
                                DemoBadge()
                            }
                        }
                        BigDurationView(seconds: stats.totalDuration)
                        Text("\(DurationFormat.percent(stats.shareOfTotal)) · 当前纳入设备中的占比")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                // 所选周期 + 厂商型号
                Text("所选周期 \(periodRangeText) · \(device.manufacturer ?? "未知厂商") · \(device.modelCode ?? "—")")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)

                PeriodPills(period: $period) {
                    showCustomPicker = true
                }

                // 累计时长 + 历史
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("累计聆听时长")
                                .font(.headline)
                            Spacer()
                            Text(DurationFormat.hMin(stats.totalDuration))
                                .font(.headline)
                        }
                        Text(historyText)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                // 2×2 统计
                GlassCard {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        StatCell(label: "累计佩戴次数", value: "\(stats.sessionCount) 次", footnote: "估算")
                        StatCell(label: "平均每次", value: DurationFormat.hMin(stats.averageSession), footnote: "有效聆听 · 估算")
                        StatCell(label: "最长一次", value: DurationFormat.hMin(stats.longestSession), footnote: "有效聆听 · 估算")
                        StatCell(label: "平均音量", value: stats.averageVolumeDB.map { "\(Int($0.rounded())) dB" } ?? "—", footnote: "1-3 级")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") {
                    newName = displayName
                    showRename = true
                }
            }
        }
        .alert("重命名设备", isPresented: $showRename) {
            TextField("设备名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    DeviceNameStore.setDisplayName(trimmed, for: device)
                    displayName = trimmed
                }
            }
        } message: {
            Text("改名只影响本机显示，不改动健康数据。")
        }
        .sheet(isPresented: $showCustomPicker) {
            CustomPeriodPickerView(start: $customStart, end: $customEnd) {
                period = .custom
                showCustomPicker = false
            } onCancel: {
                showCustomPicker = false
            }
        }
        .onAppear {
            displayName = DeviceNameStore.displayName(for: device)
        }
    }
}
