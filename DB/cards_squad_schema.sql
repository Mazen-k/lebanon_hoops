-- 1v1 lineup storage (apply once if missing).
-- Maps UI positions: guard1=PG, guard2=SG, forward1=SF, forward2=PF, center=C.

CREATE TABLE IF NOT EXISTS cards_squad (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    squad_number INT NOT NULL CHECK (squad_number IN (1, 2, 3)),
    squad_name VARCHAR(100) NOT NULL,

    guard1 INT NOT NULL,
    guard2 INT NOT NULL,
    forward1 INT NOT NULL,
    forward2 INT NOT NULL,
    center INT NOT NULL,

    CONSTRAINT fk_cards_squad_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cards_squad_guard1
        FOREIGN KEY (guard1) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_guard2
        FOREIGN KEY (guard2) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_forward1
        FOREIGN KEY (forward1) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_forward2
        FOREIGN KEY (forward2) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_center
        FOREIGN KEY (center) REFERENCES play_cards(card_id),

    CONSTRAINT unique_user_squad_number
        UNIQUE (user_id, squad_number)
);
