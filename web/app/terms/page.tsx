'use client';

import Link from 'next/link';

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="bg-white shadow-lg rounded-lg p-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-8">利用規約</h1>
          
          <p className="text-gray-600 mb-6">
            最終更新日: 2026年1月28日
          </p>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">1. サービスの概要</h2>
            <p className="text-gray-600 leading-relaxed">
              lecsy（以下「本サービス」）は、講義の音声を録音し、リアルタイムで文字起こしを行うアプリケーションです。
              本サービスを利用することで、この利用規約に同意したものとみなされます。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">2. アカウント</h2>
            <p className="text-gray-600 leading-relaxed">
              本サービスの一部機能を利用するには、Apple ID または Google アカウントでのログインが必要です。
              アカウントの認証情報は適切に管理し、第三者に共有しないでください。
              アカウントの不正使用については、ユーザー自身が責任を負うものとします。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">3. 利用料金</h2>
            <p className="text-gray-600 leading-relaxed mb-4">
              本サービスは基本機能を無料で提供しています。追加機能（Pro プラン）は有料サブスクリプションとして提供されます。
            </p>
            <ul className="list-disc list-inside text-gray-600 space-y-2 ml-4">
              <li><strong>無料プラン</strong>: 録音、オフライン文字起こし、Web同期（基本機能）</li>
              <li><strong>Pro プラン</strong>: AI要約、試験対策モード、優先サポート</li>
            </ul>
            <p className="text-gray-600 leading-relaxed mt-4">
              サブスクリプションは自動更新されます。解約は Apple App Store の設定から行ってください。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">4. 禁止事項</h2>
            <p className="text-gray-600 leading-relaxed mb-4">
              以下の行為は禁止されています：
            </p>
            <ul className="list-disc list-inside text-gray-600 space-y-2 ml-4">
              <li>他者の権利を侵害するコンテンツの録音・保存</li>
              <li>違法な目的での本サービスの使用</li>
              <li>本サービスのリバースエンジニアリングや不正アクセス</li>
              <li>本サービスのセキュリティを脅かす行為</li>
              <li>商用目的での無断使用</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">5. 知的財産権</h2>
            <p className="text-gray-600 leading-relaxed">
              本サービスおよび関連するすべてのコンテンツ（ソフトウェア、デザイン、テキスト、グラフィック）の
              知的財産権は当社に帰属します。ユーザーが作成したコンテンツの所有権はユーザーに帰属しますが、
              サービス提供のために必要な範囲で当社に使用許諾を付与するものとします。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">6. 免責事項</h2>
            <p className="text-gray-600 leading-relaxed">
              本サービスは「現状有姿」で提供され、明示または黙示の保証は行いません。
              文字起こしの正確性について保証するものではなく、重要な内容については必ず元の音声と照合してください。
              本サービスの利用によって生じた損害について、当社は責任を負いません。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">7. サービスの変更・終了</h2>
            <p className="text-gray-600 leading-relaxed">
              当社は、事前の通知なしに本サービスの内容を変更、または一時的・恒久的に終了する権利を有します。
              サービス終了の場合は、適切な期間を設けてユーザーに通知します。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">8. 準拠法・管轄</h2>
            <p className="text-gray-600 leading-relaxed">
              この利用規約は日本法に準拠します。
              本サービスに関連する紛争については、東京地方裁判所を第一審の専属的合意管轄裁判所とします。
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-4">9. お問い合わせ</h2>
            <p className="text-gray-600 leading-relaxed">
              利用規約に関するご質問は、以下までお問い合わせください：
            </p>
            <p className="text-gray-600 mt-4">
              <strong>メール:</strong> support@lecsy.app
            </p>
          </section>

          <div className="border-t pt-8 mt-8">
            <Link href="/" className="text-blue-600 hover:text-blue-800 font-medium">
              ← ホームに戻る
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
