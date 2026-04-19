-- Optional: only if cards_squad was created with quoted uppercase columns ("PG", …).
-- After this, use cards_squad_schema.sql / cards_squad_alter_nullable_slots.sql conventions.

ALTER TABLE cards_squad RENAME COLUMN "PG" TO pg;
ALTER TABLE cards_squad RENAME COLUMN "SG" TO sg;
ALTER TABLE cards_squad RENAME COLUMN "SF" TO sf;
ALTER TABLE cards_squad RENAME COLUMN "PF" TO pf;
ALTER TABLE cards_squad RENAME COLUMN "C" TO c;
