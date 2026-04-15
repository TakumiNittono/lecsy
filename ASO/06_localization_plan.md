# 06. ローカライズ戦略

## 原則
App Store Connect のロケール追加は**ほぼ無料で露出が倍増**する。
Lecsy はアプリ本体が12言語対応なのに、ストアロケールが JP/EN のみ = 宝の持ち腐れ。

## 優先順位(ROI 順)

### Tier 1(今月中に追加)
| ロケール | 理由 | 作業量 |
|---|---|---|
| **Korean (ko)** | 留学生市場最大、Otter が弱い、翻訳コスト低 | 小 |
| **Spanish (Mexico)** | 米国ヒスパニック + ラテン、B2B ESL 学校直結 | 小 |
| **Simplified Chinese** | 中国系留学生(米国IEP の最大顧客層) | 中 |

### Tier 2(2ヶ月以内)
| ロケール | 理由 |
|---|---|
| Traditional Chinese (台湾/香港) | 日本語話者の隣接市場 |
| French | カナダ留学生 + アフリカ仏語圏 |
| Portuguese (Brazil) | ラテン留学生 |

### Tier 3(あとで)
- German, Italian, Arabic, Hindi, Russian

## ロケールごとに用意するもの
各ロケール、以下6点:
1. App Name
2. Subtitle
3. Keywords
4. Promotional Text
5. Description(機械翻訳+ネイティブ校正1回)
6. スクショ(テキスト部分だけ差し替え、構図共通)

## 翻訳ワークフロー
- DeepL で下訳 → Fiverr / Upwork でネイティブ校正($20-40 / 言語)
- **スクショのテキストだけ** は必ずネイティブチェック(誤字が即 1★ になる)
- App 内 UI は既存の Localizable.strings を流用

## US 英語と UK/AU 英語
- Apple は自動継承するが、**en-GB と en-AU を追加**するだけで別検索結果に出る
- コストほぼゼロ、DL +5-10% の報告例あり
- **最優先:今すぐやる**(メタデータは en-US をコピペでOK)

## 各ロケール専用キーワードは 03 を参照
