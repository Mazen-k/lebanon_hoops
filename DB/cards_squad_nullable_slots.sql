-- Allow empty lineup slots (API exposes empty as card_id -1; DB stores NULL).
-- Run once on existing DBs that created cards_squad with NOT NULL on position columns.

ALTER TABLE cards_squad ALTER COLUMN guard1 DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN guard2 DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN forward1 DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN forward2 DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN center DROP NOT NULL;
