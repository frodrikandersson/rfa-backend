-- Save this as init.sql in your project root
-- This will run when the db_init container starts

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users & Authentication

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    username TEXT UNIQUE NOT NULL CHECK (length(username) BETWEEN 3 AND 20),
    password_hash TEXT NOT NULL,
    is_verified BOOL DEFAULT false,
    gdpr_consent_at TIMESTAMP WITH TIME ZONE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    timezone TEXT DEFAULT 'UTC',
    use_local_timezone BOOL DEFAULT true,
    profile_image_url TEXT
);

CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);



-- 2. Game Accounts & States

CREATE TABLE game_states (
    state_id SERIAL PRIMARY KEY,
    state_number INT NOT NULL CHECK (state_number BETWEEN 1 AND 999999),
    name TEXT NOT NULL,
    UNIQUE(state_number)
);

CREATE TABLE user_game_accounts (
    account_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    state_id INT NOT NULL REFERENCES game_states(state_id),
    verified BOOL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used TIMESTAMP WITH TIME ZONE,
    is_main_account BOOL DEFAULT false,
    UNIQUE(user_id, state_id, account_id)
);

CREATE OR REPLACE FUNCTION check_user_game_account_limit()
RETURNS TRIGGER AS $$
DECLARE
    account_count INT;
BEGIN
    SELECT COUNT(*) INTO account_count
    FROM user_game_accounts
    WHERE user_id = NEW.user_id
      AND state_id = NEW.state_id;

    IF TG_OP = 'INSERT' AND account_count >= 2 THEN
        RAISE EXCEPTION 'User % already has 2 accounts in state %', NEW.user_id, NEW.state_id;
    END IF;

    IF TG_OP = 'UPDATE' AND 
       (NEW.user_id != OLD.user_id OR NEW.state_id != OLD.state_id) AND 
       account_count >= 2 THEN
        RAISE EXCEPTION 'User % already has 2 accounts in state %', NEW.user_id, NEW.state_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_limit_user_game_accounts
BEFORE INSERT OR UPDATE ON user_game_accounts
FOR EACH ROW
EXECUTE FUNCTION check_user_game_account_limit();



-- 3. Alliances & Members

CREATE TABLE alliances (
    alliance_id SERIAL PRIMARY KEY,
    state_id INT REFERENCES game_states(state_id),
    name TEXT NOT NULL,
    description TEXT,
    is_recruiting BOOL DEFAULT false,
    is_hidden BOOL DEFAULT false,
    timezone TEXT DEFAULT 'UTC',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by INT REFERENCES users(user_id),
    recruitment_message TEXT,
    requirements TEXT,
    contact_info TEXT,
    logo_url TEXT
);

CREATE TABLE alliance_ranks (
    rank_id SERIAL PRIMARY KEY,
    alliance_id INT NOT NULL REFERENCES alliances(alliance_id) ON DELETE CASCADE,
    rank_level INT NOT NULL CHECK (rank_level BETWEEN 1 AND 5),
     rank_name TEXT GENERATED ALWAYS AS ('R' || rank_level::text) STORED,
    can_manage_events BOOL DEFAULT false,
    can_manage_members BOOL DEFAULT false,
    can_manage_alliance BOOL DEFAULT false,
    can_manage_maps BOOL DEFAULT false,
    UNIQUE(alliance_id, rank_level)
);

CREATE TABLE alliance_members (
    alliance_id INT NOT NULL REFERENCES alliances(alliance_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    rank_id INT NOT NULL REFERENCES alliance_ranks(rank_id),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    promoted_by INT REFERENCES users(user_id),
    trust_score INT DEFAULT 100 CHECK (trust_score BETWEEN 0 AND 100),
    PRIMARY KEY (alliance_id, user_id)
);



-- 4. Guides & Voting

CREATE TABLE guides (
    guide_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    posted_with_account INT REFERENCES user_game_accounts(account_id) ON DELETE SET NULL,
    title TEXT NOT NULL CHECK (length(title) BETWEEN 5 AND 200),
    content TEXT NOT NULL CHECK (length(content) > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    is_public BOOL DEFAULT true,
    view_count INT DEFAULT 0,
    upvote_count INT DEFAULT 0,
    search_vector TSVECTOR
);

-- Add hot_score column after the table is created
ALTER TABLE guides ADD COLUMN hot_score FLOAT;

-- Create the trigger function to update hot_score
CREATE OR REPLACE FUNCTION update_hot_score()
RETURNS TRIGGER AS $$
BEGIN
    NEW.hot_score := LOG(GREATEST(1, NEW.upvote_count + 1)) + EXTRACT(EPOCH FROM NEW.created_at) / 45000;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger that calls the function on insert or update
CREATE TRIGGER trg_update_hot_score
BEFORE INSERT OR UPDATE ON guides
FOR EACH ROW
EXECUTE FUNCTION update_hot_score();


CREATE TABLE guide_upvotes (
    guide_id INT NOT NULL REFERENCES guides(guide_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    upvoted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (guide_id, user_id)
);

CREATE TABLE guide_tags (
    tag_id SERIAL PRIMARY KEY,
    tag_name TEXT NOT NULL UNIQUE
);

CREATE TABLE guide_to_tags (
    guide_id INT NOT NULL REFERENCES guides(guide_id) ON DELETE CASCADE,
    tag_id INT NOT NULL REFERENCES guide_tags(tag_id) ON DELETE CASCADE,
    PRIMARY KEY (guide_id, tag_id)
);

CREATE TABLE guide_comments (
    comment_id SERIAL PRIMARY KEY,
    guide_id INT NOT NULL REFERENCES guides(guide_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    posted_with_account INT REFERENCES user_game_accounts(account_id),
    content TEXT NOT NULL CHECK (length(content) > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_flagged BOOL DEFAULT false,
    parent_comment_id INT REFERENCES guide_comments(comment_id) ON DELETE SET NULL
);

CREATE TABLE guide_images (
    image_id SERIAL PRIMARY KEY,
    guide_id INT NOT NULL REFERENCES guides(guide_id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    caption TEXT,
    display_order INT DEFAULT 0,
    width INT,
    height INT,
    file_size INT,
    mime_type TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT valid_display_order CHECK (display_order >= 0)
);

CREATE INDEX idx_guide_images ON guide_images(guide_id, display_order);
CREATE INDEX idx_guides_search ON guides USING GIN(search_vector);


-- 5. Maps & Tiles

CREATE TABLE maps (
    map_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    alliance_id INT REFERENCES alliances(alliance_id) ON DELETE SET NULL,
    map_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    modified_at TIMESTAMP WITH TIME ZONE,
    is_active BOOL DEFAULT true,
    grid_size_x INT DEFAULT 50,
    grid_size_y INT DEFAULT 50,
    is_alliance_map BOOL DEFAULT false,
    thumbnail_url TEXT
);

CREATE TABLE tile_types (
    tile_type_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    size_x INT NOT NULL CHECK (size_x BETWEEN 1 AND 5),
    size_y INT NOT NULL CHECK (size_y BETWEEN 1 AND 5),
    image_url TEXT NOT NULL,
    wilderness_image_url TEXT,
    description TEXT,
    min_rank INT DEFAULT 1 CHECK (min_rank BETWEEN 1 AND 4),
    max_rank INT DEFAULT 4 CHECK (max_rank BETWEEN 1 AND 4),
    is_obstruction BOOL DEFAULT false,
    max_per_map INT,
    category TEXT CHECK (category IN ('city', 'resource', 'military', 'special'))
);

-- Your tiles table, without the invalid CHECK constraint
CREATE TABLE tiles (
    tile_id SERIAL PRIMARY KEY,
    map_id INT NOT NULL REFERENCES maps(map_id) ON DELETE CASCADE,
    x INT NOT NULL CHECK (x BETWEEN 0 AND 49),
    y INT NOT NULL CHECK (y BETWEEN 0 AND 49),
    tile_type_id INT NOT NULL REFERENCES tile_types(tile_type_id),
    owner_id INT REFERENCES users(user_id) ON DELETE SET NULL,
    assigned_rank INT CHECK (assigned_rank BETWEEN 1 AND 4), -- still restrict to 1..4 in general
    is_alliance_hq BOOL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(map_id, x, y)
);

-- Trigger function to check assigned_rank range per tile_type
CREATE OR REPLACE FUNCTION check_assigned_rank() RETURNS trigger AS $$
DECLARE
    min_rank_val INT;
    max_rank_val INT;
BEGIN
    IF NEW.assigned_rank IS NOT NULL THEN
        SELECT min_rank, max_rank
        INTO min_rank_val, max_rank_val
        FROM tile_types
        WHERE tile_type_id = NEW.tile_type_id;

        IF min_rank_val IS NULL OR max_rank_val IS NULL THEN
            RAISE EXCEPTION 'tile_type_id % not found in tile_types table', NEW.tile_type_id;
        END IF;

        IF NEW.assigned_rank < min_rank_val OR NEW.assigned_rank > max_rank_val THEN
            RAISE EXCEPTION 'assigned_rank % is out of bounds (% to %) for tile_type_id %',
                NEW.assigned_rank, min_rank_val, max_rank_val, NEW.tile_type_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach the trigger to the tiles table
CREATE TRIGGER trg_check_assigned_rank
BEFORE INSERT OR UPDATE ON tiles
FOR EACH ROW
EXECUTE FUNCTION check_assigned_rank();

CREATE INDEX idx_tiles_map_id ON tiles(map_id);


-- 6. Alliance Events

CREATE TABLE alliance_events (
    event_id SERIAL PRIMARY KEY,
    alliance_id INT NOT NULL REFERENCES alliances(alliance_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'bear_trap_1', 'bear_trap_2', 'crazy_joe', 'foundry', 'alliance_rush'
    )),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by INT REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_recurring BOOL DEFAULT false,
    recurrence_pattern TEXT,
    notes TEXT
);

CREATE TABLE event_waves (
    wave_id SERIAL PRIMARY KEY,
    event_id INT NOT NULL REFERENCES alliance_events(event_id) ON DELETE CASCADE,
    wave_number INT NOT NULL CHECK (wave_number BETWEEN 1 AND 5),
    start_offset INTERVAL NOT NULL,
    max_participants INT,
    UNIQUE(event_id, wave_number)
);

CREATE TABLE event_participants (
    participant_id SERIAL PRIMARY KEY,
    event_id INT NOT NULL REFERENCES alliance_events(event_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    wave_id INT REFERENCES event_waves(wave_id) ON DELETE SET NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by INT REFERENCES users(user_id) ON DELETE SET NULL,
    status TEXT DEFAULT 'confirmed' CHECK (status IN ('pending', 'confirmed', 'declined')),
    UNIQUE(event_id, user_id)
);

CREATE INDEX idx_event_participants_event_id ON event_participants(event_id);

-- 7. Notifications & Preferences

CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'upvote', 'comment', 'event_reminder', 'alliance_invite'
    )),
    event_data JSONB NOT NULL,
    source_user_id INT REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOL DEFAULT false,
    is_email_sent BOOL DEFAULT false
);

CREATE TABLE user_notification_preferences (
    user_id INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    notify_on_upvote BOOL DEFAULT true,
    notify_on_comment BOOL DEFAULT true,
    notify_event_reminders BOOL DEFAULT true,
    notify_alliance_invites BOOL DEFAULT true,
    digest_frequency TEXT CHECK (digest_frequency IN ('instant', 'hourly', 'daily')) DEFAULT 'instant'
);

CREATE TABLE user_notification_channels (
    user_id INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    enable_web_push BOOL DEFAULT true,
    enable_email BOOL DEFAULT false,
    enable_browser_notifications BOOL DEFAULT true,
    enable_in_app_notifications BOOL DEFAULT true,
    digest_frequency TEXT CHECK (digest_frequency IN (
        'instant', 'hourly', 'daily', 'weekly', 'never'
    )) DEFAULT 'instant',
    last_notified_at TIMESTAMP WITH TIME ZONE,
    email_notification_address TEXT CHECK (
        email_notification_address ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'
    ),
    push_notification_token TEXT,
    webhook_url TEXT,
    CONSTRAINT valid_notification_target CHECK (
        (enable_email = false OR email_notification_address IS NOT NULL) AND
        (enable_web_push = false OR push_notification_token IS NOT NULL)
    )
);

-- For web push subscription management
CREATE TABLE user_push_subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL,
    p256dh_key TEXT NOT NULL,
    auth_key TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, endpoint)
);



-- 8. User Customization

CREATE TYPE cosmetic_type AS ENUM (
    'city_skin', 'marching_skin', 'nameplate_skin',
    'avatar_frame', 'teleport_skin', 'private_chat_skin',
    'chief_profile', 'name_card'
);

CREATE TABLE user_cosmetics (
    cosmetic_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    cosmetic_type cosmetic_type NOT NULL,
    image_url TEXT NOT NULL,
    wilderness_image_url TEXT,
    name TEXT NOT NULL,
    effect_description TEXT,
    is_active BOOL DEFAULT false,
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, cosmetic_type, name)
);



-- 9. GDPR Compliance Tables

CREATE TABLE gdpr_consents (
    consent_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    consent_type TEXT NOT NULL CHECK (consent_type IN (
        'privacy_policy', 'cookies', 'marketing', 'data_processing'
    )),
    consent_version TEXT NOT NULL,
    granted BOOL NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    user_agent TEXT,
    UNIQUE(user_id, consent_type, consent_version)
);

CREATE TABLE gdpr_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    request_type TEXT NOT NULL CHECK (request_type IN (
        'data_export', 'account_deletion', 'consent_withdrawal'
    )),
    status TEXT NOT NULL CHECK (status IN (
        'pending', 'processing', 'completed', 'failed'
    )) DEFAULT 'pending',
    request_data JSONB,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT, -- System or admin username
    data_download_url TEXT,
    download_expires_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

CREATE INDEX idx_gdpr_requests_user ON gdpr_requests(user_id, status);
CREATE INDEX idx_gdpr_requests_age ON gdpr_requests(requested_at) WHERE status = 'pending';



-- Indexes for Performance

-- Core indexes
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_user_username_lower ON users(LOWER(username));
CREATE INDEX idx_user_game_accounts ON user_game_accounts(user_id, state_id);

-- Alliance indexes
CREATE INDEX idx_alliance_membership ON alliance_members(user_id, alliance_id);
CREATE INDEX idx_alliance_state ON alliances(state_id);

-- Guide indexes
CREATE INDEX idx_guide_search ON guides USING GIN(search_vector);
CREATE INDEX idx_guide_author ON guides(user_id);
CREATE INDEX idx_guide_upvotes ON guide_upvotes(guide_id);
CREATE INDEX idx_guide_tags ON guide_to_tags(tag_id);

-- Map indexes
CREATE INDEX idx_map_tiles ON tiles(map_id);
CREATE INDEX idx_tile_ownership ON tiles(owner_id) WHERE owner_id IS NOT NULL;

-- Event indexes
CREATE INDEX idx_event_participation ON event_participants(user_id, event_id);
CREATE INDEX idx_event_wave ON event_waves(event_id);

-- Notification indexes
CREATE INDEX idx_unread_notifications ON notifications(user_id) WHERE is_read = false;
CREATE INDEX idx_notification_delivery ON notifications(user_id, is_email_sent);

-- Guide images optimization
CREATE INDEX idx_guide_image_metadata ON guide_images(guide_id)
    INCLUDE (width, height, file_size);

-- GDPR performance
CREATE INDEX idx_gdpr_active_consents ON gdpr_consents(user_id)
    WHERE granted = true AND revoked_at IS NULL;

-- Notification channel lookup
CREATE INDEX idx_notification_prefs ON user_notification_channels(user_id)
    WHERE enable_web_push = true OR enable_email = true;

-- Ensure notifications table uses proper channels
ALTER TABLE notifications 
ADD CONSTRAINT fk_notification_channels 
FOREIGN KEY (user_id) REFERENCES user_notification_channels(user_id) ON DELETE CASCADE;

-- Connect GDPR requests to consents
ALTER TABLE gdpr_requests
ADD COLUMN related_consent_id INT REFERENCES gdpr_consents(consent_id) ON DELETE SET NULL;

CREATE MATERIALIZED VIEW gdpr_audit_trail AS
SELECT 
    u.user_id,
    u.email,
    COUNT(DISTINCT gc.consent_id) FILTER (WHERE gc.granted = true) AS granted_consents,
    COUNT(DISTINCT gc.consent_id) FILTER (WHERE gc.granted = false) AS revoked_consents,
    COUNT(DISTINCT gr.request_id) FILTER (WHERE gr.request_type = 'data_export') AS data_exports,
    COUNT(DISTINCT gr.request_id) FILTER (WHERE gr.request_type = 'account_deletion') AS deletion_requests,
    MAX(gr.requested_at) AS last_request_date
FROM users u
LEFT JOIN gdpr_consents gc ON u.user_id = gc.user_id
LEFT JOIN gdpr_requests gr ON u.user_id = gr.user_id
GROUP BY u.user_id
WITH DATA;

-- Refresh this view nightly
CREATE OR REPLACE FUNCTION refresh_gdpr_audit()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY gdpr_audit_trail;
END;
$$ LANGUAGE plpgsql;

-- Create read-only user for analytics
CREATE ROLE readonly WITH LOGIN PASSWORD 'readonly_pass';
GRANT CONNECT ON DATABASE defaultdb TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;