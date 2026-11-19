// PodsStatsApp.swift
// App 入口 + 底部悬浮胶囊 Tab 栏（今天 / 统计 / 设备）。

import SwiftUI

@main
struct PodsStatsApp: App {
    @StateObject private var store = HealthKitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .task {
                    await store.requestAuthorization()
                }
        }
    }
}

enum MainTab: String, CaseIterable {
    case today = "今天"
    case stats = "统计"
    case devices = "设备"

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .stats: return "chart.bar.fill"
        case .devices: return "headphones"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: HealthKitStore
    @State private var selectedTab: MainTab = .today

    var body: some View {
        ZStack {
            AppBackground()

            // 三个 Tab 各自独立的 NavigationStack，切换时保留导航状态。
            Group {
                switch selectedTab {
                case .today:
                    NavigationStack { TodayView() }
                case .stats:
                    NavigationStack { StatsView() }
                case .devices:
                    NavigationStack { DevicesView() }
                }
            }

            // 底部悬浮胶囊 Tab 栏
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    ForEach(MainTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.subheadline.weight(.semibold))
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.white.opacity(0.2) : Color.clear)
                            .foregroundStyle(selectedTab == tab ? Color.white : AppColors.secondaryText)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.1))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .padding(.bottom, 24)
            }
        }
    }
}
