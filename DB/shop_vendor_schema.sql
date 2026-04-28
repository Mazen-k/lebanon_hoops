-- Fan Shop vendor module. Run after shop_schema.sql.
-- Mirrors the court_reservation_schema pattern.

-- Shop vendor accounts (one row per store owner).
CREATE TABLE IF NOT EXISTS shop_vendors (
    shop_vendor_id SERIAL PRIMARY KEY,
    shop_name      VARCHAR(100)  NOT NULL,
    description    TEXT,
    username       VARCHAR(50)   NOT NULL UNIQUE,
    password_hash  VARCHAR(255)  NOT NULL,
    logo_url       VARCHAR(255)
);

-- Link existing shop_items to a vendor (nullable for legacy/global items).
ALTER TABLE shop_items
    ADD COLUMN IF NOT EXISTS shop_vendor_id INT
        REFERENCES shop_vendors(shop_vendor_id) ON DELETE SET NULL;

-- Additional gallery photos per item (separate from the main image_url thumbnail).
CREATE TABLE IF NOT EXISTS shop_item_photos (
    photo_id       SERIAL PRIMARY KEY,
    item_id        INT  NOT NULL
        REFERENCES shop_items(item_id) ON DELETE CASCADE,
    photo_url      TEXT NOT NULL
);

-- Seed: one demo shop vendor.
-- Password is 'vendor123' hashed with bcrypt cost 10.
INSERT INTO shop_vendors (shop_name, description, username, password_hash)
SELECT 'Lebanese League Official Store',
       'Official licensed merchandise for the Lebanese Basketball League.',
       'shop_admin',
       '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LmTeBiz/Lhu'
WHERE NOT EXISTS (SELECT 1 FROM shop_vendors WHERE username = 'shop_admin');

-- Assign existing seed items to the demo vendor.
UPDATE shop_items
SET shop_vendor_id = (SELECT shop_vendor_id FROM shop_vendors WHERE username = 'shop_admin')
WHERE shop_vendor_id IS NULL;
