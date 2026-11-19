// SessionDetailView.swift
// 单次聆听记录的详情页。

import SwiftUI

struct SessionDetailView: View {
    let session: ListeningSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("聆听时长")
                            .font(.headline)
                            .foregroundStyle(AppColors.secondaryText)
                        BigDurationView(seconds: session.duration)
                        Divider().background(Color.white.opacity(0.15))
                        detailRow(label: "开始", value: "\(DurationFormat.dottedDate(session.start)) \(DurationFormat.clock(session.start))")
                        detailRow(label: "结束", value: "\(DurationFormat.dottedDate(session.end)) \(DurationFormat.clock(session.end))")
                        detailRow(label: "设备", value: DeviceNameStore.displayName(forDeviceId: session.deviceName, fallback: session.deviceName))
                        detailRow(label: "平均音量", value: session.averageVolumeDB.map { "\(Int($0.rounded())) dB" } ?? "—")
                    }
                }
                Text("一次聆听由健康数据中连续的耳机音频记录合并而来；间隔超过 10 分钟会断开为新的记录，因此次数与平均时长为估算值。")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .navigationTitle("聆听记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
