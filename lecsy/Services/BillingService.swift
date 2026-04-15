//
//  BillingService.swift
//  lecsy
//
//  B2C 個人ユーザー向け Stripe 導線。2026-06-01 ローンチで B2B と同時に稼働。
//
//  2つの流れ:
//   1. Checkout (新規課金): Settings → "View Plans" → Safari で `/pricing` を開く。
//      Web 側で Stripe Checkout に遷移し、決済完了で webhook が subscriptions を active 化。
//      次回アプリ前景化で PlanService が再フェッチし Pro 反映。
//   2. Portal (既存サブスク管理): Settings → "Manage Subscription" → create-portal-session
//      Edge Function を呼び、返ってきた Stripe Customer Portal URL を Safari で開く。
//
//  success/cancel URL は Web 内で閉じる。iOS に戻す特殊 URL スキームは作らない。
//

import Foundation
import UIKit

@MainActor
final class BillingService {
    static let shared = BillingService()
    private init() {}

    /// B2C ユーザーがプラン選択するランディング。Safari で開く。
    let pricingURL = URL(string: "https://www.lecsy.app/pricing")!

    /// Portal 終了後に戻る先。Web アプリのホームで十分。
    private let portalReturnURL = "https://www.lecsy.app/app"

    enum BillingError: Error, LocalizedError {
        case notAuthenticated
        case noCustomer
        case invalidURL
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Please sign in to manage your subscription."
            case .noCustomer:       return "No Stripe customer found. Subscribe first."
            case .invalidURL:       return "Stripe returned an invalid URL."
            case .server(let m):    return m
            }
        }
    }

    /// `/pricing` を Safari で開く。
    func openPricing() {
        UIApplication.shared.open(pricingURL)
    }

    /// Stripe Customer Portal を開く。既存サブスクの解約・カード変更などに使う。
    /// 呼び出し側は try/catch でエラー表示する。
    func openPortal() async throws {
        guard AuthService.shared.isAuthenticated else {
            throw BillingError.notAuthenticated
        }

        struct Req: Encodable { let return_url: String }
        struct Res: Decodable { let url: String }

        let res: Res
        do {
            res = try await LecsyAPIClient.shared.invokeFunction(
                "create-portal-session",
                body: Req(return_url: portalReturnURL)
            )
        } catch SupabaseError.notFound {
            throw BillingError.noCustomer
        } catch SupabaseError.server(let msg, _) where msg.contains("no_customer") {
            throw BillingError.noCustomer
        } catch {
            throw BillingError.server(error.localizedDescription)
        }

        guard let url = URL(string: res.url) else { throw BillingError.invalidURL }
        await UIApplication.shared.open(url)
    }
}
