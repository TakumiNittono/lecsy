#!/usr/bin/env node

/**
 * Apple OAuth Secret Key Generator for Supabase
 * 
 * 使用方法:
 * 1. Apple Developer ConsoleでSign In with Apple用のキーを作成
 * 2. .p8ファイルをダウンロード
 * 3. このスクリプトを実行:
 *    node generate-apple-secret.js
 */

const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function generateSecretKey() {
  console.log('🍎 Apple OAuth Secret Key Generator for Supabase\n');
  console.log('このスクリプトは、Supabase用のApple OAuth Secret Key（JWT）を生成します。\n');

  try {
    // 必要な情報を入力
    let teamId = await question('1. Team IDを入力してください（Apple Developer Consoleの右上から取得）: ');
    let keyId = await question('2. Key IDを入力してください（作成したキーのID）: ');
    let servicesId = await question('3. Services IDを入力してください（デフォルト: com.takumiNittono.lecsy.auth）: ') || 'com.takumiNittono.lecsy.auth';
    let keyPath = await question('4. .p8ファイルのパスを入力してください（例: ./AuthKey_XXXXXXXXXX.p8）: ');
    
    // すべての入力値から余分なスペースを削除
    teamId = teamId.trim();
    keyId = keyId.trim();
    servicesId = servicesId.trim();
    keyPath = keyPath.trim();
    
    // 相対パスの場合、現在のディレクトリからのパスに変換
    if (!keyPath.startsWith('/') && !keyPath.startsWith('~')) {
      keyPath = path.resolve(process.cwd(), keyPath);
    }
    
    // ~ をホームディレクトリに展開
    if (keyPath.startsWith('~')) {
      keyPath = keyPath.replace('~', process.env.HOME || process.env.USERPROFILE || '');
    }

    // ファイルの存在確認
    if (!fs.existsSync(keyPath)) {
      console.error(`❌ エラー: ファイルが見つかりません: ${keyPath}`);
      console.error(`   絶対パス: ${path.resolve(keyPath)}`);
      console.error(`   現在のディレクトリ: ${process.cwd()}`);
      process.exit(1);
    }

    // 秘密鍵を読み込む
    const privateKey = fs.readFileSync(keyPath, 'utf8');

    // 現在時刻
    const now = Math.floor(Date.now() / 1000);
    // 6ヶ月後（180日）
    const expiration = now + (86400 * 180);

    // JWTを生成（値に余分なスペースがないことを確認）
    console.log('🔍 デバッグ情報:');
    console.log('  Team ID:', JSON.stringify(teamId));
    console.log('  Key ID:', JSON.stringify(keyId));
    console.log('  Services ID:', JSON.stringify(servicesId));
    
    const token = jwt.sign(
      {
        iss: teamId.trim(),
        iat: now,
        exp: expiration,
        aud: 'https://appleid.apple.com',
        sub: servicesId.trim(),
      },
      privateKey,
      {
        algorithm: 'ES256',
        keyid: keyId.trim(),
      }
    );

    console.log('\n✅ Secret Keyが生成されました！\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('以下のSecret KeyをSupabase Dashboardの「Secret Key (for OAuth)」フィールドに貼り付けてください:\n');
    console.log(token);
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('📝 設定手順:');
    console.log('1. Supabase Dashboard > Authentication > Providers > Apple を開く');
    console.log('2. 「Secret Key (for OAuth)」フィールドに上記のJWTを貼り付け');
    console.log('3. 「Save」をクリック');
    console.log('\n⚠️  注意: Secret Keyは6ヶ月ごとに期限切れになります。');
    console.log('   期限切れの1ヶ月前に新しいキーを生成して更新してください。\n');

  } catch (error) {
    console.error('❌ エラーが発生しました:', error.message);
    if (error.message.includes('jsonwebtoken')) {
      console.error('\n💡 jsonwebtokenパッケージがインストールされていない可能性があります。');
      console.error('   以下のコマンドでインストールしてください:');
      console.error('   npm install jsonwebtoken\n');
    }
    process.exit(1);
  } finally {
    rl.close();
  }
}

// 実行
generateSecretKey();
