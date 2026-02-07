#!/usr/bin/env node

/**
 * Apple Provider設定確認スクリプト
 * 
 * このスクリプトは、Supabase DashboardでのApple Provider設定を確認するための
 * チェックリストを表示します。
 * 
 * 使用方法:
 *   node check-apple-provider.js
 */

const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function checkAppleProvider() {
  console.log('🍎 Apple Provider 設定確認ツール\n');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('このツールは、Supabase DashboardでのApple Provider設定を確認するための');
  console.log('チェックリストを表示します。\n');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  const checks = [];

  // Step 1: Supabase Dashboardへのアクセス
  console.log('📋 Step 1: Supabase Dashboard にアクセス\n');
  console.log('1. https://app.supabase.com にログイン');
  console.log('2. プロジェクト「bjqilokchrqfxzimfnpm」を選択');
  console.log('3. Authentication > Providers > Apple を開く\n');
  
  const dashboardOpened = await question('✅ Supabase Dashboard > Authentication > Providers > Apple を開きましたか？ (y/n): ');
  checks.push({ name: 'Dashboardを開いた', status: dashboardOpened.toLowerCase() === 'y' });

  // Step 2: Enable Sign in with Apple
  console.log('\n📋 Step 2: Enable Sign in with Apple の確認\n');
  console.log('「Enable Sign in with Apple」のトグルスイッチがONになっているか確認してください。\n');
  
  const enableToggle = await question('✅ 「Enable Sign in with Apple」がONになっていますか？ (y/n): ');
  checks.push({ name: 'Enable Sign in with Apple がON', status: enableToggle.toLowerCase() === 'y' });

  // Step 3: Client ID
  console.log('\n📋 Step 3: Client ID (Services ID) の確認\n');
  console.log('「Client ID (Services ID)」フィールドに以下が設定されているか確認してください:');
  console.log('   com.takumiNittono.lecsy.auth\n');
  
  const clientId = await question('✅ Client IDが正しく設定されていますか？ (y/n): ');
  checks.push({ name: 'Client ID が正しい', status: clientId.toLowerCase() === 'y' });

  // Step 4: Team ID
  console.log('\n📋 Step 4: Team ID の確認\n');
  console.log('「Team ID」フィールドに以下が設定されているか確認してください:');
  console.log('   G7LG228243\n');
  
  const teamId = await question('✅ Team IDが正しく設定されていますか？ (y/n): ');
  checks.push({ name: 'Team ID が正しい', status: teamId.toLowerCase() === 'y' });

  // Step 5: Key ID
  console.log('\n📋 Step 5: Key ID の確認\n');
  console.log('「Key ID」フィールドに正しいKey IDが設定されているか確認してください。');
  console.log('（例: 5HH2THJXAY）\n');
  
  const keyId = await question('✅ Key IDが設定されていますか？ (y/n): ');
  checks.push({ name: 'Key ID が設定されている', status: keyId.toLowerCase() === 'y' });

  // Step 6: Secret Key
  console.log('\n📋 Step 6: Secret Key (for OAuth) の確認\n');
  console.log('「Secret Key (for OAuth)」フィールドにJWT形式の長い文字列が');
  console.log('設定されているか確認してください（空欄ではない）。\n');
  
  const secretKey = await question('✅ Secret Keyが設定されていますか（空欄ではない）？ (y/n): ');
  checks.push({ name: 'Secret Key が設定されている', status: secretKey.toLowerCase() === 'y' });

  // Step 7: Save
  console.log('\n📋 Step 7: 設定の保存\n');
  console.log('すべての設定を確認したら、「Save」ボタンをクリックしてください。\n');
  
  const saved = await question('✅ 「Save」ボタンをクリックしましたか？ (y/n): ');
  checks.push({ name: '設定を保存した', status: saved.toLowerCase() === 'y' });

  // 結果の表示
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('📊 確認結果:\n');

  const passed = checks.filter(c => c.status).length;
  const total = checks.length;

  checks.forEach((check, index) => {
    const icon = check.status ? '✅' : '❌';
    console.log(`${icon} ${index + 1}. ${check.name}`);
  });

  console.log(`\n結果: ${passed}/${total} 項目が確認されました\n`);

  if (passed === total) {
    console.log('🎉 すべての設定が正しく確認されました！');
    console.log('\n次のステップ:');
    console.log('1. iOSアプリを再起動');
    console.log('2. Sign in with Appleを再度試す');
  } else {
    console.log('⚠️  いくつかの設定が確認されていません。');
    console.log('\n❌ が付いている項目を確認してください。');
    console.log('\n詳細な手順は、SUPABASE_APPLE_PROVIDER_FIX.md を参照してください。');
    
    // 問題がある場合の追加情報
    if (!checks[1].status) {
      console.log('\n💡 「Enable Sign in with Apple」がOFFの場合:');
      console.log('   Supabase Dashboard > Authentication > Providers > Apple で');
      console.log('   トグルスイッチをONにして「Save」をクリックしてください。');
    }
    
    if (!checks[5].status) {
      console.log('\n💡 Secret Keyが空欄または期限切れの場合:');
      console.log('   以下のコマンドでSecret Keyを再生成してください:');
      console.log('   node generate-apple-secret.js');
      console.log('\n   生成されたJWTをSupabase Dashboardに貼り付けて「Save」をクリックしてください。');
    }
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  rl.close();
}

// 実行
checkAppleProvider().catch(error => {
  console.error('❌ エラーが発生しました:', error.message);
  process.exit(1);
});
