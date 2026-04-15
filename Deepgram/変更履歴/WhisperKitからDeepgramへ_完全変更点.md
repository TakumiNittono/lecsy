# WhisperKit → Deepgram 完全変更点

> 作成日: 2026-04-14
> これは lecsy の方向性における**最大の転換**。このファイルに全ての変更点を記録。

---

## 🎯 一行サマリ

**WhisperKit（オンデバイス）からDeepgram Nova-3（クラウド）への全面移行。これに伴い、プロダクト・価格・営業・競合・書類・技術のすべてが変わった。**

---

## 📋 変更点一覧（15項目）

### 1. 文字起こしエンジン
| 項目 | Before | After |
|-----|--------|------|
| エンジン | **WhisperKit**（オンデバイス） | **Deepgram Nova-3**（クラウドStreaming/Prerecorded） |
| 精度（英語） | 85-88% | **95%+** |
| 精度（非ネイティブ） | 70-80% | **90%+** |
| 遅延 | 1-4秒（端末依存） | **<500ms** |
| 対応言語 | 12言語 | **20+言語** |
| 中国圏接続 | ❌ | ✅ |
| オフライン | ✅ | Prerecordedで代替 |

### 2. プロダクトビジョン
| 項目 | Before | After |
|-----|--------|------|
| メイン訴求 | "完全オンデバイス・プライバシーファースト" | **"留学生の英語講義学期OS"** |
| ターゲット | FL語学学校 + B2C全般 | **米大学国際留学生 80万人** |
| 最上位ビジョン | ランゲージラボ代替 | **世界中の大学が使うアプリ** |

### 3. 5つのキラー機能（新規）
WhisperKit時代にはほぼ無かった、Deepgram化で可能になった機能:

1. 🌐 **Real-time Bilingual Captions**（英+母語並列、<500ms遅延）
2. 📚 **Course Hierarchy**（学期→コース→週→回、Syllabus Intelligence）
3. 🤖 **AI Study Guide + Quiz**（Quick/Standard/Deep、GPT-4o Mini生成）
4. 📖 **Vocabulary Intelligence**（自動抽出 + Anki export）
5. 🎯 **Exam Prep Plan**（試験カウントダウン自動学習計画）

### 4. 決済モデル
| 項目 | Before | After |
|-----|--------|------|
| 主経路 | Apple IAP想定 | **Stripe一本**（Apple IAP廃止） |
| 理由 | — | Apple 30%回避、B2B Invoice対応、多通貨 |
| アーキ | iOS内決済 | **iOS-Web分離パターン**（Netflix/Notion型） |

### 5. 価格体系
| プラン | Before | After |
|-----|--------|------|
| Free | 永続無料、全機能 | 永続無料、Streamingなし、Study Guide 3回/月 |
| Pro | $9.99/月 | **$12.99/月**（$109/年） |
| Student | $4.99/月 | **$6.99/月**（$59/年） |
| B2B Starter | $299/月 | **$499/月** (ISSS Starter, 100席) |
| B2B Growth | $599/月 | **$999/月** (ISSS Growth, 500席) |
| Enterprise | $15-50K/年 | **$25-75K/年** (SAML/LTI/VPAT完備) |

### 6. ターゲット市場の変更
| 項目 | Before | After |
|-----|--------|------|
| 一次 | FL語学学校（ESL系）| **米大学の留学生個人（B2C）** |
| 二次 | フロリダ州大学Disability | **大学ISSS（International Student Services）** |
| 三次 | 米国他州大学 | **Enterprise全学契約** |
| flagship | Santa Fe College ESL | **UF ELI** + Santa Fe 並行 |

### 7. 言語展開順
| Phase | Before | After |
|-----|--------|------|
| 1 | 英語 + スペイン語 | **日本語 + 英語**（たくみの強み活用） |
| 2 | + 中国語 | + 韓国語 |
| 3 | + 12言語全対応 | + 中国語 |
| 4 | — | + ベトナム語・スペイン語・ポ語 |
| 5 | — | + EU・アジア言語 |

### 8. プライバシー訴求の変更
| 項目 | Before | After |
|-----|--------|------|
| コピー | "Your audio never leaves your device" | **"Lecsy servers never store your audio. Deepgram processes and deletes within 30 days."** |
| 根拠 | 完全オンデバイス | lecsyサーバー保存ゼロ + Deepgramの30日自動削除 |
| ZDR契約 | N/A | 将来交渉（MRR $10K到達後） |

### 9. 競合ポジショニング
| 項目 | Before | After |
|-----|--------|------|
| 主な比較対象 | Otter / Notta / Rev | **PolyPal / LectMate / StudyFetch / Glean** |
| 差別化 | 12言語 + オンデバイス + 無料 | **5機能統合 × 留学生特化 × グローバルコンプラ** |

### 10. Backend技術
| 項目 | Before | After |
|-----|--------|------|
| STT | WhisperKit（iOS内） | **Deepgram API + Edge Function** |
| AI生成 | なし | **GPT-4o Mini**（翻訳・Study Guide・Vocab・Quiz） |
| セマンティック検索 | なし | **text-embedding-3-small + pgvector** |
| 同期 | ローカルのみ | **Supabase Postgres クラウド同期**（テキストのみ） |

### 11. 営業ナラティブ
| 軸 | Before | After |
|-----|--------|------|
| 主軸 | "ランゲージラボ代替" | **"留学生の学期まるごとAI OS"** |
| 副軸 | "12言語対応" | **"音声ゼロ保存 + AI Study Guide"** |
| 第三軸 | "FERPA準拠" | **"Accessibility Compliance Tool"** |

### 12. 書類整備
Deepgram化に伴い新規/更新:
- プライバシーポリシー（Deepgram/OpenAI 追加）
- Subprocessors 公開ページ
- Stripe経由を明記
- HECVAT Lite 回答テンプレ（ZDRなし版）
- FERPA Addendum

### 13. 既存ユーザー対応
**500人のユーザー**:
- ローカルデータをクラウドへオプトイン同期
- WhisperKit 削除後もテキスト履歴は維持
- 「音声は引き続き保存されません」訴求継続

詳細: `技術/ローカルtoクラウド移行設計.md`

### 14. タイムライン
| Phase | Before | After |
|-----|--------|------|
| 4-5月 | B2B営業準備 | **Deepgram移行実装 + 4校デモ** |
| 6/1 | Pro機能課金ON | **Deepgram版ローンチ + Stripe課金** |
| 6-8月 | FL営業 + 日本B2C | **Summer pilot + 留学生獲得** |
| 9-12月 | 米国展開 | **UF ELI Fall有料契約 + ISSS営業** |
| 2027 Q1 | Enterprise準備 | **SOC2/VPAT/SAML準備** |

### 15. リスクと堀
| 項目 | Before | After |
|-----|--------|------|
| 最大脅威 | Otter値下げ | **StudyFetch多言語化** |
| 堀 | オンデバイスUX | **日本人創業者 × 留学生コミュ × データ資産** |

---

## 🎯 なぜこの変更をしたか（意思決定根拠）

### 1. WhisperKit精度の天井
- 12言語対応だが精度85-88%が限界
- 中国圏ユーザーが使えない構造問題
- 専門用語（学術）の認識率悪い

### 2. Deepgram Nova-3の革新
- 2025年リリースの最新モデル
- 95%+精度、400ms遅延
- Multilingual auto-switch
- Keyterm Prompting で学術語彙対応

### 3. 「留学生特化」の発見
- 55社調査で「留学生×学期OS×iOS」完全空白
- たくみ自身のストーリー最大活用
- 市場80万人、TAM $288M

### 4. Stripe一本化の効率
- Apple 30%は Student $6.99 を赤字化
- Stripe 2.9%で粗利56%確保
- B2B Invoice対応

### 5. 構造的堀の構築
- 日本/韓国/中国語コミュ浸透（競合届かない）
- データ資産累積
- ISSS営業ルート（Disability Officeと別予算）

---

## ⚠️ この変更に伴う注意

1. **古いノートとの矛盾**
   - `Deepgram/` フォルダの内容を正とする
   - 古い「オンデバイス」「$9.99」「FL語学学校」記述は無効

2. **既存ユーザーへの説明**
   - 移行メールで丁寧に変更点伝える
   - 「より正確、より賢く、より世界中で使える lecsy」
   - テキストデータは保持、音声は引き続き保存されない

3. **App Store 再審査**
   - Stripe経由に変更のためメタデータ更新必要
   - 「Subscription managed on lecsy.app」明記
   - IAP は一切削除

4. **法務書類の再署名**
   - 既存MSA/DPA等をDeepgram反映版に更新
   - 既存パイロット校に連絡

---

## 🔄 変更を反映したファイル一覧

戦略ドキュメント（Deepgram/内）:
- ✅ 01_ビジョンと勝ち筋
- ✅ 02_5キラー機能完全仕様
- ✅ 03_競合完全ガイド
- ✅ 04_営業完全戦術書
- ✅ 05_90日アクションプラン
- ✅ 06_技術スタック完全版
- ✅ 07_価格とユニットエコノミクス
- ✅ 08_法務コンプライアンス
- ✅ 09_リスクマップと対策
- ✅ 10_勝利のための鉄則

サブフォルダ（詳細版）:
- ✅ プロダクト/プロダクト概要.md
- ✅ プロダクト/キラー5機能仕様.md
- ✅ ビジネス/価格体系.md
- ✅ ビジネス/競合分析.md
- ✅ ビジネス/ターゲット市場と営業戦略.md
- ✅ ビジネス/Stripe課金アーキテクチャ.md
- ✅ 技術/Deepgram-only設計_2026.md
- ✅ 技術/ローカルtoクラウド移行設計.md
- ✅ ロードマップ/将来ビジョン.md
- ✅ ロードマップ/実行タイムライン_2026.md
- ✅ 営業/_営業プレイブック共通.md
- ✅ 営業/HECVAT_Lite_回答テンプレ.md
- ✅ 営業/uf_eli.md
- ✅ 営業/F-1中の無料パイロット運用.md
- ✅ 法務OPT/OPT_LLC設立タイムライン.md

---

## 🎯 結論

**この転換は戻れない**。lecsyの未来はDeepgramの上に立つ。

WhisperKitの良い点（オフライン、プライバシー）は惜しいが、**精度・多言語・低遅延・機能拡張性**の方が事業価値として大きい。

Deepgramの弱点（原価、30日保持）は、プラン設計と訴求の工夫で克服済み。

**6/1 ローンチまでに全面切替完了**。
