-- 管理者は全レポートを閲覧・更新可能
-- (auth.users テーブルでメールアドレスを確認)

CREATE POLICY "Admins can view all reports"
    ON reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.email = 'nittonotakumi@gmail.com'
        )
    );

CREATE POLICY "Admins can update all reports"
    ON reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.email = 'nittonotakumi@gmail.com'
        )
    );
