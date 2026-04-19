-- 1v1 lineup: five slots named PG, SG, SF, PF, C in DDL; PostgreSQL folds unquoted identifiers to lowercase
-- columns pg, sg, sf, pf, c. Empty slot = -1 (NOT NULL DEFAULT -1).
--
-- If you use FOREIGN KEY (pg) REFERENCES play_cards(card_id), PostgreSQL still checks -1 against play_cards.
-- You need either a sentinel row play_cards.card_id = -1, or drop those FKs and rely on API validation.

CREATE TABLE IF NOT EXISTS cards_squad (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    squad_number INT NOT NULL CHECK (squad_number IN (1, 2, 3)),
    squad_name VARCHAR(100) NOT NULL,

    pg INT NOT NULL DEFAULT -1,
    sg INT NOT NULL DEFAULT -1,
    sf INT NOT NULL DEFAULT -1,
    pf INT NOT NULL DEFAULT -1,
    c INT NOT NULL DEFAULT -1,

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
