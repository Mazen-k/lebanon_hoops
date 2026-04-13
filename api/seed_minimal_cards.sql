-- Example rows to test pack opening (run in psql against BasketballApp).
-- Fix team_id / player_id / user_id if your DB already has data.

INSERT INTO teams (team_name) VALUES ('Demo Team');

INSERT INTO players (team_id, jersey_number, first_name, last_name, nationality, position, dominant_hand, dob)
VALUES (1, 99, 'Jamal', 'Demo', 'LB', 'PG', 'Right', '2000-01-01');

-- Lebanese base pack (packId lebanese_base) picks 4 random play_cards with card_type = base.
INSERT INTO play_cards (card_type, player_id, attack, defend, card_image)
VALUES
  ('base', 1, 72, 68, NULL),
  ('base', 1, 75, 70, NULL),
  ('base', 1, 88, 82, NULL),
  ('base', 1, 65, 90, NULL);

INSERT INTO users (username, email, password_hash)
VALUES ('demo_user', 'demo@example.com', 'placeholder_hash');

-- Flutter default DEV_USER_ID=1 must match users.user_id for the row above.
