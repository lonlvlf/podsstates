// SettingsView.swift
// 设置页：数据来源、健康授权状态、重新授权、关于。

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HealthKitStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("数据来源")
                                    .font(.headline)
                                switch store.mode {
                                case .loading:
                                    Text("正在读取健康数据…")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.secondaryText)
                                case .live:
                                    Text("真实数据：来自本机“健康”中的耳机音频暴露记录，仅在本机统计，不上传服务器。")
                                        .font(.subheadline)
                                case .demo:
                                    HStack(alignment: .firstTextBaseline) {
                                        DemoBadge()
                                        Text("当前显示示例数据。")
                                            .font(.subheadline)
                                    }
                                    Text(store.lastError ?? "未获得健康数据或暂无记录。")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("健康授权")
                                    .font(.headline)
                                if store.authorizationDenied {
                                    Text("健康数据授权已被拒绝，请在系统设置中开启。")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.secondaryText)
                                    Button("打开系统设置") {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppColors.accent)
                                } else {
                                    Button("重新请求健康授权") {
                                        Task { await store.requestAuthorization() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppColors.accent)
                                    Text("授权只读耳机音频暴露记录，不会写入或修改任何健康数据。")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                if let error = store.lastError, store.mode != .demo {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("关于")
                                    .font(.headline)
                                Text("Pods Stats（复刻版）1.0\n只读本机健康数据，不联网、不注册账号、不含广告。\n一次聆听的合并规则：相邻记录间隔超过 10 分钟即断开，次数与平均时长为估算值。")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
