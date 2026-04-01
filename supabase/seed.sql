-- ============================================
-- Seed data for local development
-- テスト用の組織・ユーザー・transcripts
-- ============================================

-- ============================================
-- 1. テストユーザー作成 (auth.users)
-- ============================================
-- パスワードは全員 "password123"

-- Admin / Owner: あなた自身
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'nittonotakumi@gmail.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"full_name": "Takumi Nittono"}'::jsonb,
  now(), now(), '', ''
);

-- Teacher 1
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'teacher1@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"full_name": "Yuki Tanaka"}'::jsonb,
  now(), now(), '', ''
);

-- Teacher 2
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token)
VALUES (
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'teacher2@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"full_name": "Sakura Yamada"}'::jsonb,
  now(), now(), '', ''
);

-- Student 1
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token)
VALUES (
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'student1@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"full_name": "Ken Suzuki"}'::jsonb,
  now(), now(), '', ''
);

-- Student 2
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token)
VALUES (
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'student2@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"full_name": "Mika Sato"}'::jsonb,
  now(), now(), '', ''
);

-- Student 3 (inactive - no recent recordings)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token)
VALUES (
  '00000000-0000-0000-0000-000000000006',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'student3@example.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"full_name": "Ryo Watanabe"}'::jsonb,
  now(), now(), '', ''
);

-- auth.identities も必要 (Supabase authが要求する)
INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
SELECT id, id, id, json_build_object('sub', id, 'email', email)::jsonb, 'email', now(), now(), now()
FROM auth.users WHERE id IN (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000006'
);

-- ============================================
-- 2. 組織作成
-- ============================================

-- 語学学校
INSERT INTO organizations (id, name, slug, type, plan, max_seats)
VALUES (
  '10000000-0000-0000-0000-000000000001',
  'Tokyo Language Academy',
  'tokyo-language-academy',
  'language_school',
  'growth',
  30
);

-- 大学
INSERT INTO organizations (id, name, slug, type, plan, max_seats)
VALUES (
  '10000000-0000-0000-0000-000000000002',
  'Waseda University IEP',
  'waseda-iep',
  'university_iep',
  'enterprise',
  200
);

-- ============================================
-- 3. メンバー登録
-- ============================================

-- Tokyo Language Academy
INSERT INTO organization_members (org_id, user_id, role) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'owner'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'teacher'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'teacher'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'student'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'student'),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'student');

-- Waseda (Takumi is admin here too)
INSERT INTO organization_members (org_id, user_id, role) VALUES
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'admin');

-- ============================================
-- 4. Transcripts (録音データ)
-- ============================================

-- Helper: 今月のデータを大量に作る
-- User 1 (Takumi) - 今月5件、直近7日以内に3件
INSERT INTO transcripts (user_id, title, content, duration, language, word_count, created_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'English Conversation Practice', 'Today we practiced ordering food at a restaurant. The key phrases were: Could I have the menu please? I would like to order the pasta. Can I get the check?', 1800, 'en', 32, now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000000001', 'TOEFL Listening Section 3', 'The lecture discussed the impact of climate change on marine ecosystems. Professor mentioned that coral reefs are particularly vulnerable to temperature changes.', 2400, 'en', 26, now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000001', 'Business English Meeting', 'Lets go over the quarterly results. Revenue increased by 15 percent compared to last quarter. The main driver was our expansion into the Asian market.', 3600, 'en', 28, now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000000001', 'Japanese Grammar Review', '今日は敬語の使い方を復習しました。尊敬語、謙譲語、丁寧語の違いについて学びました。', 1200, 'ja', 15, now() - interval '12 days'),
  ('00000000-0000-0000-0000-000000000001', 'Pronunciation Workshop', 'Focus on minimal pairs: ship/sheep, bit/beat, full/fool. Practice the difference between short and long vowels.', 900, 'en', 18, now() - interval '20 days');

-- User 2 (Teacher Yuki) - 今月4件、直近7日以内に2件
INSERT INTO transcripts (user_id, title, content, duration, language, word_count, created_at) VALUES
  ('00000000-0000-0000-0000-000000000002', 'Intermediate Grammar Class', 'Today we covered the present perfect tense. Have you ever been to Japan? I have lived here for three years. She has already finished her homework.', 2700, 'en', 27, now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000002', 'Reading Comprehension', 'The passage was about sustainable energy solutions. Students discussed solar panels, wind turbines, and hydroelectric power as alternatives to fossil fuels.', 1800, 'en', 23, now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000000002', 'Speaking Test Preparation', 'Practice describing your hometown. Talk about the weather, local food, and interesting places to visit. Use descriptive adjectives and comparatives.', 2100, 'en', 22, now() - interval '10 days'),
  ('00000000-0000-0000-0000-000000000002', 'Vocabulary Building', 'Academic word list: hypothesis, methodology, significant, correlation, implications. Use each word in a sentence related to your research topic.', 1500, 'en', 20, now() - interval '18 days');

-- User 3 (Teacher Sakura) - 今月3件、直近7日以内に1件
INSERT INTO transcripts (user_id, title, content, duration, language, word_count, created_at) VALUES
  ('00000000-0000-0000-0000-000000000003', 'Advanced Discussion', 'The topic was artificial intelligence in education. Students debated whether AI tutors could replace human teachers. Most agreed that AI is a supplement not a replacement.', 3000, 'en', 29, now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000000003', 'Writing Workshop', 'Essay structure review: introduction with thesis statement, body paragraphs with topic sentences, and conclusion. Practice writing argumentative essays.', 2400, 'en', 20, now() - interval '15 days'),
  ('00000000-0000-0000-0000-000000000003', 'Listening Exercise', 'BBC News listening exercise. Students practiced note-taking while listening to a report about global trade agreements and their impact on developing nations.', 1800, 'en', 24, now() - interval '22 days');

-- User 4 (Student Ken) - 今月6件、直近7日以内に4件 (most active student!)
INSERT INTO transcripts (user_id, title, content, duration, language, word_count, created_at) VALUES
  ('00000000-0000-0000-0000-000000000004', 'Self Study - Podcast', 'Listened to an English podcast about travel in Southeast Asia. Learned new vocabulary: backpacking, itinerary, accommodation, budget-friendly.', 1200, 'en', 20, now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000000004', 'Class Recording - Grammar', 'Present perfect continuous: I have been studying English for two years. She has been working at this company since 2020.', 2700, 'en', 22, now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000004', 'Shadowing Practice', 'Practiced shadowing with TED talk about growth mindset. Key takeaway: effort and persistence matter more than natural talent.', 900, 'en', 18, now() - interval '4 days'),
  ('00000000-0000-0000-0000-000000000004', 'Conversation with AI', 'Practiced introducing myself and talking about hobbies. I like playing soccer and reading manga. I want to improve my English for studying abroad.', 600, 'en', 25, now() - interval '6 days'),
  ('00000000-0000-0000-0000-000000000004', 'Movie Listening', 'Watched a scene from The Social Network. Practiced catching fast dialogue and slang expressions. Mark says: You know what is cooler than a million dollars?', 1500, 'en', 27, now() - interval '14 days'),
  ('00000000-0000-0000-0000-000000000004', 'Vocabulary Quiz Prep', 'Reviewed 50 words from the academic word list. Focused on words starting with A and B: abstract, adjacent, behalf, benefit, category, comprehensive.', 1800, 'en', 24, now() - interval '25 days');

-- User 5 (Student Mika) - 今月2件、直近7日以内に1件
INSERT INTO transcripts (user_id, title, content, duration, language, word_count, created_at) VALUES
  ('00000000-0000-0000-0000-000000000005', 'IELTS Practice Test', 'Completed a full IELTS listening practice test. Section 1 was about booking a hotel room. Section 2 was a tour guide describing a museum.', 2400, 'en', 26, now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000005', 'Group Discussion Recording', 'Discussed the advantages and disadvantages of social media. Points raised: connectivity, misinformation, mental health impacts, and digital literacy.', 1800, 'en', 21, now() - interval '16 days');

-- User 6 (Student Ryo) - 先月のみ、今月は0件 (inactive user)
INSERT INTO transcripts (user_id, title, content, duration, language, word_count, created_at) VALUES
  ('00000000-0000-0000-0000-000000000006', 'Old Recording', 'This is an older recording from last month. Basic greetings and self introduction practice.', 600, 'en', 14, now() - interval '35 days'),
  ('00000000-0000-0000-0000-000000000006', 'Another Old One', 'Practiced numbers and dates in English. January, February, March. First, second, third.', 450, 'en', 12, now() - interval '40 days');

-- ============================================
-- 5. Subscriptions
-- ============================================
INSERT INTO subscriptions (user_id, status, provider) VALUES
  ('00000000-0000-0000-0000-000000000001', 'active', 'stripe'),
  ('00000000-0000-0000-0000-000000000002', 'active', 'stripe'),
  ('00000000-0000-0000-0000-000000000003', 'active', 'appstore'),
  ('00000000-0000-0000-0000-000000000004', 'free', NULL),
  ('00000000-0000-0000-0000-000000000005', 'free', NULL),
  ('00000000-0000-0000-0000-000000000006', 'free', NULL);

-- ============================================
-- 期待される結果 (Tokyo Language Academy):
-- Total Members: 6
-- Monthly Recordings: 20 (今月分)
-- Monthly Duration: 合計 ~9.5時間
-- Active Users (7日): 5 (Ryo以外)
-- Recent Activity: 直近10件が表示される
-- ============================================
