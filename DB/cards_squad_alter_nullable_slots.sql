-- Run once if slot columns need NULL for empties (and are already named pg, sg, sf, pf, c).
-- Clears invalid non-positive values, then allows NULL.

UPDATE cards_squad SET pg = NULL WHERE pg IS NOT NULL AND pg <= 0;
UPDATE cards_squad SET sg = NULL WHERE sg IS NOT NULL AND sg <= 0;
UPDATE cards_squad SET sf = NULL WHERE sf IS NOT NULL AND sf <= 0;
UPDATE cards_squad SET pf = NULL WHERE pf IS NOT NULL AND pf <= 0;
UPDATE cards_squad SET c = NULL WHERE c IS NOT NULL AND c <= 0;

ALTER TABLE cards_squad ALTER COLUMN pg DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN sg DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN sf DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN pf DROP NOT NULL;
ALTER TABLE cards_squad ALTER COLUMN c DROP NOT NULL;

ALTER TABLE cards_squad ALTER COLUMN pg DROP DEFAULT;
ALTER TABLE cards_squad ALTER COLUMN sg DROP DEFAULT;
ALTER TABLE cards_squad ALTER COLUMN sf DROP DEFAULT;
ALTER TABLE cards_squad ALTER COLUMN pf DROP DEFAULT;
ALTER TABLE cards_squad ALTER COLUMN c DROP DEFAULT;
