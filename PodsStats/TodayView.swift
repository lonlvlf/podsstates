// TodayView.swift
// “今天”页：日期切换、当天累计时长、时段分布柱状图、聆听记录。

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: HealthKitStore
    @State private var selectedDate: Date = Date()
    @State private var selectedHour: Int?
    @State private var showSettings = false

    private var stats: DayStats {
        store.dayStats(for: selectedDate)
    }

    /// 可往前翻的最早日期（示例模式：历史起日；真实模式：90 天前）。
    private var earliestDate: Date {
        if store.mode == .demo {
            return Calendar.current.startOfDay(for: DemoData.historyStart)
        }
        return Calendar.current.date(byAdding: .day, value: -90, to: Calendar.current.startOfDay(for: Date()))!
    }

    private var canGoBack: Bool {
        Calendar.current.startOfDay(for: selectedDate) > earliestDate
    }

    private var canGoForward: Bool {
        Calendar.current.startOfDay(for: selectedDate) < Calendar.current.startOfDay(for: store.referenceDate)
    }

    private func shiftDay(by days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = next
        selectedHour = nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题 + 设置
                HStack(alignment: .firstTextBaseline) {
                    Text("今天")
                        .font(.largeTitle.weight(.bold))
                    if store.mode == .demo {
                        DemoBadge()
                    }
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }

                // 日期切换
                HStack {
                    Button { shiftDay(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundStyle(canGoBack ? .white : .white.opacity(0.25))
                    }
                    .disabled(!canGoBack)

                    Text(DurationFormat.dottedDate(selectedDate))
                        .font(.headline)
                        .frame(minWidth: 110)

                    Button { shiftDay(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(canGoForward ? .white : .white.opacity(0.25))
                    }
                    .disabled(!canGoForward)
                }

                // 累计聆听时长
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("累计聆听时长")
                            .font(.headline)
                            .foregroundStyle(AppColors.secondaryText)
                        BigDurationView(seconds: stats.totalDuration)
                        Divider().background(Color.white.opacity(0.15))
                        HStack {
                            Text("当天开始")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                            Text("\(stats.sessionCount) 次")
                                .font(.subheadline.weight(.semibold))
                            Text("· 估算")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        HStack {
                            Text("最长当日片段")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                            Text(DurationFormat.hMin(stats.longestSession))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                // 时段分布
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("时段分布")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 16) {
                                Button { shiftDay(by: -1) } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline)
                                        .foregroundStyle(canGoBack ? .white : .white.opacity(0.25))
                                }
                                .disabled(!canGoBack)
                                Button { shiftDay(by: 1) } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline)
                                        .foregroundStyle(canGoForward ? .white : .white.opacity(0.25))
                                }
                                .disabled(!canGoForward)
                            }
                        }
                        HourlyBarChart(hourly: stats.hourlyDurations, selectedHour: $selectedHour)
                    }
                }

                // 聆听记录
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("聆听记录")
                            .font(.headline)
                        Spacer()
                        Text("当天可见 \(stats.sessions.count) 条")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    if stats.sessions.isEmpty {
                        GlassCard {
                            Text("当天暂无聆听记录")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    } else {
                        ForEach(stats.sessions) { session in
                            NavigationLink(value: session) {
                                GlassCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(DurationFormat.clock(session.start)) – \(DurationFormat.clock(session.end))")
                                                .font(.headline)
                                            Text(DurationFormat.hMin(session.duration))
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.secondaryText)
                                        }
                                        Spacer()
                                        HStack(spacing: 6) {
                                            Image(systemName: "headphones")
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.accent)
                                            Text(DeviceNameStore.displayName(forDeviceId: session.deviceName, fallback: session.deviceName))
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.secondaryText)
                                                .lineLimit(1)
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
            .padding(.bottom, 110)   // 给悬浮 Tab 栏留空
        }
        .navigationDestination(for: ListeningSession.self) { session in
            SessionDetailView(session: session)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            // 示例模式下默认停在 2026-11-19（示例数据的“今天”）；真实模式用当天。
            if store.mode == .demo {
                selectedDate = DemoData.demoToday
            } else {
                selectedDate = Date()
            }
        }
        .onChange(of: store.mode) { _, newMode in
            if newMode == .demo {
                selectedDate = DemoData.demoToday
            } else {
                selectedDate = Date()
            }
        }
    }
}
