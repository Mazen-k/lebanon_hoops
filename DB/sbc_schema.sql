CREATE TABLE sbc_challenges (
    sbc_id SERIAL PRIMARY KEY,
    sbc_name VARCHAR(100) NOT NULL,
    description TEXT,
    reward_card_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sbc_reward_card
        FOREIGN KEY (reward_card_id)
        REFERENCES play_cards(card_id)
);

CREATE TABLE sbc_requirements (
    requirement_id SERIAL PRIMARY KEY,
    sbc_id INT NOT NULL,

    requirement_type VARCHAR(50) NOT NULL,
    required_value INT,
    required_text VARCHAR(100),
    min_count INT DEFAULT 1,

    CONSTRAINT fk_sbc_requirement
        FOREIGN KEY (sbc_id)
        REFERENCES sbc_challenges(sbc_id)
        ON DELETE CASCADE
);
