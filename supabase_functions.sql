-- This file contains SQL functions and policies for the MechFind app

-- Function to get latest conversations for a user
CREATE OR REPLACE FUNCTION get_latest_conversations(current_user_id UUID)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    image_url TEXT,
    last_message TEXT,
    last_message_time TIMESTAMP WITH TIME ZONE,
    unread_count BIGINT
)
LANGUAGE SQL
AS $$
    WITH latest_messages AS (
        SELECT DISTINCT ON (
            CASE 
                WHEN sender_id = current_user_id THEN receiver_id
                ELSE sender_id
            END
        )
        CASE 
            WHEN sender_id = current_user_id THEN receiver_id
            ELSE sender_id
        END AS other_user_id,
        content AS last_message,
        created_at AS last_message_time
        FROM messages
        WHERE sender_id = current_user_id OR receiver_id = current_user_id
        ORDER BY 
            CASE 
                WHEN sender_id = current_user_id THEN receiver_id
                ELSE sender_id
            END,
            created_at DESC
    ),
    unread_counts AS (
        SELECT 
            sender_id AS other_user_id,
            COUNT(*) AS unread_count
        FROM messages
        WHERE receiver_id = current_user_id 
        AND is_read = FALSE
        GROUP BY sender_id
    )
    SELECT 
        u.id,
        u.full_name,
        u.image_url,
        lm.last_message,
        lm.last_message_time,
        COALESCE(uc.unread_count, 0) AS unread_count
    FROM latest_messages lm
    JOIN users u ON u.id = lm.other_user_id
    LEFT JOIN unread_counts uc ON uc.other_user_id = lm.other_user_id
    ORDER BY lm.last_message_time DESC;
$$;

-- Row Level Security policies for messages table
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Users can read messages they sent or received
CREATE POLICY "Users can view their messages" ON messages
FOR SELECT USING (
    auth.uid() = sender_id OR auth.uid() = receiver_id
);

-- Users can insert messages they are sending
CREATE POLICY "Users can insert messages they send" ON messages
FOR INSERT WITH CHECK (
    auth.uid() = sender_id
);

-- Users can update messages they received (for marking as read)
CREATE POLICY "Users can update messages they received" ON messages
FOR UPDATE USING (
    auth.uid() = receiver_id
);

-- Storage policies for user profile images
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);
