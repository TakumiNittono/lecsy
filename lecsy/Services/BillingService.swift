//
//  BillingService.swift
//  lecsy
//
//  B2B 専用期 (2026-06-01 ローンチまで) は個人向け課金 UI を露出しない。
//  Pro は「組織管理画面で admin が email を追加 → ユーザーがサインイン →
//  auth.users trigger で organization_members が active 化」という経路のみ。
//
//  本ファイルは将来 B2C 有料化で再利用するためのプレースホルダ。
//  現状はどこからも呼ばれていない。
//

import Foundation

@MainActor
final class BillingService {
    static let shared = BillingService()
    private init() {}
}
