-- Court reservation module (PostgreSQL). Run on your BasketballApp DB if tables are missing.
-- Public API never returns owner username/password_hash.

CREATE TABLE IF NOT EXISTS courts (
    court_id SERIAL PRIMARY KEY,
    court_name VARCHAR(100) NOT NULL,
    location VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    logo_url VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS playgrounds (
    playground_id SERIAL PRIMARY KEY,
    court_id INT NOT NULL,
    playground_name VARCHAR(100) NOT NULL,
    price_per_hour DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    can_half_court BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_playground_court
        FOREIGN KEY (court_id)
        REFERENCES courts(court_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS playground_photos (
    photo_id SERIAL PRIMARY KEY,
    playground_id INT NOT NULL,
    photo_url VARCHAR(255) NOT NULL,
    CONSTRAINT fk_photo_playground
        FOREIGN KEY (playground_id)
        REFERENCES playgrounds(playground_id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS playground_availability (
    availability_id SERIAL PRIMARY KEY,
    playground_id INT NOT NULL,
    available_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_availability_playground
        FOREIGN KEY (playground_id)
        REFERENCES playgrounds(playground_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_availability_time
        CHECK (end_time > start_time)
);

CREATE TABLE IF NOT EXISTS reservations (
    reservation_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    availability_id INT NOT NULL UNIQUE,
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'booked',
    CONSTRAINT fk_reservation_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_reservation_availability
        FOREIGN KEY (availability_id)
        REFERENCES playground_availability(availability_id)
        ON DELETE CASCADE
);

-- Optional seed (skips rows that already exist). Replace dummy password_hash if you use owner login later.
INSERT INTO courts (court_name, location, phone_number, username, password_hash, logo_url)
SELECT v.court_name, v.location, v.phone_number, v.username, v.password_hash, v.logo_url
FROM (VALUES
  (
    'Hoops Arena Beirut',
    'Sin El Fil, Lebanon',
    '+961 1 000 000',
    'hoops_arena_owner',
    '$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=200&h=200&fit=crop'
  ),
  (
    'North Coast Courts',
    'Batroun, Lebanon',
    '+961 3 000 000',
    'north_coast_owner',
    '$2a$10$BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
    'https://images.unsplash.com/photo-1519861531473-933026218?w=200&h=200&fit=crop'
  )
) AS v(court_name, location, phone_number, username, password_hash, logo_url)
WHERE NOT EXISTS (SELECT 1 FROM courts c WHERE c.username = v.username);

INSERT INTO playgrounds (court_id, playground_name, price_per_hour, is_active, can_half_court)
SELECT c.court_id, v.playground_name, v.price::decimal, TRUE, v.can_half
FROM courts c
JOIN (VALUES
  ('hoops_arena_owner', 'Championship court', 85.00::numeric, TRUE),
  ('hoops_arena_owner', 'Training lane', 48.00::numeric, FALSE),
  ('north_coast_owner', 'Outdoor Pro', 62.00::numeric, TRUE)
) AS v(owner_username, playground_name, price, can_half) ON c.username = v.owner_username
WHERE NOT EXISTS (
  SELECT 1 FROM playgrounds p WHERE p.court_id = c.court_id AND p.playground_name = v.playground_name
);

INSERT INTO playground_photos (playground_id, photo_url)
SELECT p.playground_id, v.url
FROM playgrounds p
JOIN courts c ON c.court_id = p.court_id
JOIN (VALUES
  ('Championship court', 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800'),
  ('Championship court', 'https://images.unsplash.com/photo-1519861531473-933026218?w=800'),
  ('Training lane', 'https://images.unsplash.com/photo-1519861531473-933026218?w=800'),
  ('Outdoor Pro', 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800')
) AS v(pg_name, url) ON p.playground_name = v.pg_name
WHERE NOT EXISTS (
  SELECT 1 FROM playground_photos ph WHERE ph.playground_id = p.playground_id AND ph.photo_url = v.url
);

INSERT INTO playground_availability (playground_id, available_date, start_time, end_time, is_available)
SELECT p.playground_id, d.dt::date, t.start_t::time, t.end_t::time, TRUE
FROM playgrounds p
CROSS JOIN generate_series(current_date, current_date + 6, interval '1 day') AS d(dt)
CROSS JOIN (VALUES
  ('17:00'::time, '18:00'::time),
  ('18:00'::time, '19:00'::time),
  ('19:00'::time, '20:00'::time),
  ('20:00'::time, '21:00'::time)
) AS t(start_t, end_t)
WHERE NOT EXISTS (
    SELECT 1 FROM playground_availability a
    WHERE a.playground_id = p.playground_id
      AND a.available_date = d.dt::date
      AND a.start_time = t.start_t
  );
