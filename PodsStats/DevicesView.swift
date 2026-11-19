// DevicesView.swift
// “设备”页：按耳机分组的累计统计列表，点进设备详情。

import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: HealthKitStore
    @State private var nameRefresh = false   // 改名后刷新列表显示

    private var devices: [DeviceStats] {
        // store.devices 已汇总全部已读会话（示例模式为示例数据，真实模式为最近 90 天）。
        store.devices
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("设备")
                        .font(.largeTitle.weight(.bold))
                    if store.mode == .demo {
                        DemoBadge()
                    }
                    Spacer()
                }

                if devices.isEmpty {
                    GlassCard {
                        Text("暂无设备记录")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                } else {
                    ForEach(devices) { device in
                        NavigationLink(value: device) {
                            GlassCard {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "headphones")
                                            .font(.title3)
                                            .foregroundStyle(AppColors.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(DeviceNameStore.displayName(for: device))
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text("\(device.daysWithRecords) 个有记录日 · \(device.sessionCount) 次")
                                            .font(.subheadline)
                                            .foregroundStyle(AppColors.secondaryText)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(DurationFormat.hMin(device.totalDuration))
                                            .font(.headline)
                                        Text(DurationFormat.percent(device.shareOfTotal))
                                            .font(.subheadline)
                                            .foregroundStyle(AppColors.secondaryText)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("设备按健康数据中的耳机记录分组；改名只影响本机显示，不改动健康数据。")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .navigationDestination(for: DeviceStats.self) { device in
            DeviceDetailView(device: device)
        }
        .onAppear { nameRefresh.toggle() }
    }
}
