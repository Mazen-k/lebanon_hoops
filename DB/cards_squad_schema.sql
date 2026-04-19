-- 1v1 lineup: slot columns pg, sg, sf, pf, c (lowercase).
-- Empty slot = NULL (FK to play_cards allows NULL).
-- Rows are created only via POST /cards/squad when all five slots are filled (app flow).

CREATE TABLE IF NOT EXISTS cards_squad (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    squad_number INT NOT NULL CHECK (squad_number IN (1, 2, 3)),
    squad_name VARCHAR(100) NOT NULL,

    pg INT,
    sg INT,
    sf INT,
    pf INT,
    c INT,

    CONSTRAINT fk_cards_squad_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cards_squad_pg
        FOREIGN KEY (pg) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_sg
        FOREIGN KEY (sg) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_sf
        FOREIGN KEY (sf) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_pf
        FOREIGN KEY (pf) REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_c
        FOREIGN KEY (c) REFERENCES play_cards(card_id),

    CONSTRAINT unique_user_squad_number
        UNIQUE (user_id, squad_number)
);
