# MCP (Model Context Protocol)

> 出典: [[NotebookLM_学習/⑨ AI LLM アプリ開発]] / Anthropic 公式

## MCP とは

Claude などのLLMが**外部データソースやツールに標準化された方法でアクセス**するためのプロトコル。

「AI向けの USB」と理解すると早い。

## 4つの活用メリット

### 1. コンテキスト提供の標準化
Supabase内のデータやiOSローカル情報を、Claudeが**「ツール」や「リソース」として標準化された手法**で取得。

### 2. 開発効率の向上
MCP サーバーを一度構築すれば、アプリ側のコードを大幅に書き換えずに、
**新しいデータソースや機能を「プラグイン」として追加**可能。

### 3. プロンプトテンプレートの共有
MCP の「プロンプト」機能で lecsy 固有の要約テンプレートを**モデルに即座に提供**できる。

### 4. リモート MCP の活用
サーバー側（**Supabase Edge Functions 等**）で MCP サーバーをホスト → セキュアに企業内データや外部 API にアクセス。

## lecsy での適用アイデア

- **lecsy-mcp サーバー**: Supabase Edge Function で MCP サーバー実装
  - `resources`: 生徒データ、授業データ、カリキュラム
  - `tools`: 出欠記録、進捗レポート生成、保護者通知
  - `prompts`: 要約テンプレ、学習分析テンプレ

→ iOS アプリから呼び出す Claude が、**学校の文脈を自動で理解**して応答

## 実装ステップ

1. `@modelcontextprotocol/sdk` を Supabase Edge Function にデプロイ
2. resource / tool / prompt を定義
3. iOS 側で MCP クライアント設定
4. Claude API 呼び出し時に MCP サーバー URL を指定

## 関連

- [[Claude プロンプト設計5原則]]
- [[AI エージェント構築パターン]]
