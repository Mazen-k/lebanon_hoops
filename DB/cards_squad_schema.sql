-- 1v1 lineup: five slot columns named "PG", "SG", "PF", "SF", "C" (quoted so they stay uppercase).
-- Empty slot = -1 (NOT NULL DEFAULT -1).
--
-- If you use FOREIGN KEY ("PG") REFERENCES play_cards(card_id), PostgreSQL still checks -1 against play_cards.
-- You need either a sentinel row play_cards.card_id = -1, or drop those FKs and rely on API validation.

CREATE TABLE IF NOT EXISTS cards_squad (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    squad_number INT NOT NULL CHECK (squad_number IN (1, 2, 3)),
    squad_name VARCHAR(100) NOT NULL,

    "PG" INT NOT NULL DEFAULT -1,
    "SG" INT NOT NULL DEFAULT -1,
    "PF" INT NOT NULL DEFAULT -1,
    "SF" INT NOT NULL DEFAULT -1,
    "C" INT NOT NULL DEFAULT -1,

    CONSTRAINT fk_cards_squad_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cards_squad_pg
        FOREIGN KEY ("PG") REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_sg
        FOREIGN KEY ("SG") REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_pf
        FOREIGN KEY ("PF") REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_sf
        FOREIGN KEY ("SF") REFERENCES play_cards(card_id),

    CONSTRAINT fk_cards_squad_c
        FOREIGN KEY ("C") REFERENCES play_cards(card_id),

    CONSTRAINT unique_user_squad_number
        UNIQUE (user_id, squad_number)
);
