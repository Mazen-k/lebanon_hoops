-- Wishlist tables for card trading (run once on BasketballApp DB).

CREATE TABLE IF NOT EXISTS wishlists (
    wishlist_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    msg VARCHAR(50) NOT NULL DEFAULT 'Best cards Please',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_wishlist_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

-- Existing DBs without msg (run once if upgrading):
-- ALTER TABLE wishlists ADD COLUMN IF NOT EXISTS msg VARCHAR(50) NOT NULL DEFAULT 'Best cards Please';

CREATE TABLE IF NOT EXISTS wishlist_cards (
    wishlist_id INT NOT NULL,
    card_id INT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (wishlist_id, card_id),
    CONSTRAINT fk_wishlist_cards_wishlist
        FOREIGN KEY (wishlist_id)
        REFERENCES wishlists(wishlist_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_wishlist_cards_card
        FOREIGN KEY (card_id)
        REFERENCES play_cards(card_id)
        ON DELETE CASCADE
);
