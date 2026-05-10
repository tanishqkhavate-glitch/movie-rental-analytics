-- ============================================================
-- Sakila Sample Database Schema -- PostgreSQL Version
-- Converted from MySQL original (Version 0.8)
-- Compatible with PostgreSQL 12+
-- ============================================================

-- Drop and recreate database objects cleanly
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ============================================================
-- Custom ENUM types (replacing MySQL ENUM columns)
-- ============================================================

CREATE TYPE mpaa_rating AS ENUM ('G', 'PG', 'PG-13', 'R', 'NC-17');

-- ============================================================
-- TABLE: country
-- (no dependencies)
-- ============================================================

CREATE TABLE country (
    country_id  SERIAL          NOT NULL,
    country     VARCHAR(50)     NOT NULL,
    last_update TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (country_id)
);

-- ============================================================
-- TABLE: city
-- (depends on: country)
-- ============================================================

CREATE TABLE city (
    city_id     SERIAL      NOT NULL,
    city        VARCHAR(50) NOT NULL,
    country_id  INT         NOT NULL,
    last_update TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (city_id),
    CONSTRAINT fk_city_country
        FOREIGN KEY (country_id) REFERENCES country (country_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_country_id ON city (country_id);

-- ============================================================
-- TABLE: address
-- (depends on: city)
-- ============================================================

CREATE TABLE address (
    address_id  SERIAL      NOT NULL,
    address     VARCHAR(50) NOT NULL,
    address2    VARCHAR(50) DEFAULT NULL,
    district    VARCHAR(20) NOT NULL,
    city_id     INT         NOT NULL,
    postal_code VARCHAR(10) DEFAULT NULL,
    phone       VARCHAR(20) NOT NULL,
    last_update TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (address_id),
    CONSTRAINT fk_address_city
        FOREIGN KEY (city_id) REFERENCES city (city_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_city_id ON address (city_id);

-- ============================================================
-- TABLE: language
-- (no dependencies)
-- ============================================================

CREATE TABLE language (
    language_id SERIAL    NOT NULL,
    name        CHAR(20)  NOT NULL,
    last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (language_id)
);

-- ============================================================
-- TABLE: category
-- (no dependencies)
-- ============================================================

CREATE TABLE category (
    category_id SERIAL      NOT NULL,
    name        VARCHAR(25) NOT NULL,
    last_update TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (category_id)
);

-- ============================================================
-- TABLE: actor
-- (no dependencies)
-- ============================================================

CREATE TABLE actor (
    actor_id    SERIAL      NOT NULL,
    first_name  VARCHAR(45) NOT NULL,
    last_name   VARCHAR(45) NOT NULL,
    last_update TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (actor_id)
);

CREATE INDEX idx_actor_last_name ON actor (last_name);

-- ============================================================
-- TABLE: film
-- (depends on: language)
-- NOTE: MySQL ENUM -> PostgreSQL custom type mpaa_rating
--       MySQL SET('Trailers',...) -> TEXT[] array
-- ============================================================

CREATE TABLE film (
    film_id              SERIAL        NOT NULL,
    title                VARCHAR(255)  NOT NULL,
    description          TEXT          DEFAULT NULL,
    release_year         INT           DEFAULT NULL,
    language_id          INT           NOT NULL,
    original_language_id INT           DEFAULT NULL,
    rental_duration      SMALLINT      NOT NULL DEFAULT 3,
    rental_rate          DECIMAL(4,2)  NOT NULL DEFAULT 4.99,
    length               SMALLINT      DEFAULT NULL,
    replacement_cost     DECIMAL(5,2)  NOT NULL DEFAULT 19.99,
    rating               mpaa_rating   DEFAULT 'G',
    special_features     TEXT[]        DEFAULT NULL,
    last_update          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (film_id),
    CONSTRAINT fk_film_language
        FOREIGN KEY (language_id) REFERENCES language (language_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_film_language_original
        FOREIGN KEY (original_language_id) REFERENCES language (language_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_title               ON film (title);
CREATE INDEX idx_fk_language_id      ON film (language_id);
CREATE INDEX idx_fk_original_language_id ON film (original_language_id);

-- ============================================================
-- TABLE: film_text
-- (depends on: film — kept as plain table; full-text done via tsvector)
-- ============================================================

CREATE TABLE film_text (
    film_id     INT          NOT NULL,
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    PRIMARY KEY (film_id)
);

-- PostgreSQL full-text search index (replaces MySQL FULLTEXT KEY)
CREATE INDEX idx_title_description ON film_text
    USING GIN (to_tsvector('english', title || ' ' || COALESCE(description, '')));

-- ============================================================
-- TRIGGERS: keep film_text in sync with film
-- ============================================================

CREATE OR REPLACE FUNCTION trg_ins_film_fn() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO film_text (film_id, title, description)
    VALUES (NEW.film_id, NEW.title, NEW.description);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_film
    AFTER INSERT ON film
    FOR EACH ROW EXECUTE FUNCTION trg_ins_film_fn();

-- ------

CREATE OR REPLACE FUNCTION trg_upd_film_fn() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.title IS DISTINCT FROM NEW.title
       OR OLD.description IS DISTINCT FROM NEW.description THEN
        UPDATE film_text
           SET title       = NEW.title,
               description = NEW.description,
               film_id     = NEW.film_id
         WHERE film_id = OLD.film_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_film
    AFTER UPDATE ON film
    FOR EACH ROW EXECUTE FUNCTION trg_upd_film_fn();

-- ------

CREATE OR REPLACE FUNCTION trg_del_film_fn() RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM film_text WHERE film_id = OLD.film_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER del_film
    AFTER DELETE ON film
    FOR EACH ROW EXECUTE FUNCTION trg_del_film_fn();

-- ============================================================
-- TABLE: film_actor
-- (depends on: actor, film)
-- ============================================================

CREATE TABLE film_actor (
    actor_id    INT       NOT NULL,
    film_id     INT       NOT NULL,
    last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (actor_id, film_id),
    CONSTRAINT fk_film_actor_actor
        FOREIGN KEY (actor_id) REFERENCES actor (actor_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_film_actor_film
        FOREIGN KEY (film_id) REFERENCES film (film_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_film_id ON film_actor (film_id);

-- ============================================================
-- TABLE: film_category
-- (depends on: film, category)
-- ============================================================

CREATE TABLE film_category (
    film_id     INT       NOT NULL,
    category_id INT       NOT NULL,
    last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (film_id, category_id),
    CONSTRAINT fk_film_category_film
        FOREIGN KEY (film_id) REFERENCES film (film_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_film_category_category
        FOREIGN KEY (category_id) REFERENCES category (category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================
-- TABLE: store  (skeleton — staff FK added after staff table)
-- (depends on: address)
-- ============================================================

CREATE TABLE store (
    store_id         SERIAL    NOT NULL,
    manager_staff_id INT       DEFAULT NULL,   -- FK added after staff
    address_id       INT       NOT NULL,
    last_update      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (store_id),
    CONSTRAINT fk_store_address
        FOREIGN KEY (address_id) REFERENCES address (address_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_address_id_store ON store (address_id);

-- ============================================================
-- TABLE: staff
-- (depends on: address, store)
-- ============================================================

CREATE TABLE staff (
    staff_id    SERIAL       NOT NULL,
    first_name  VARCHAR(45)  NOT NULL,
    last_name   VARCHAR(45)  NOT NULL,
    address_id  INT          NOT NULL,
    picture     BYTEA        DEFAULT NULL,
    email       VARCHAR(50)  DEFAULT NULL,
    store_id    INT          NOT NULL,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    username    VARCHAR(16)  NOT NULL,
    password    VARCHAR(40)  DEFAULT NULL,
    last_update TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (staff_id),
    CONSTRAINT fk_staff_address
        FOREIGN KEY (address_id) REFERENCES address (address_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_staff_store
        FOREIGN KEY (store_id) REFERENCES store (store_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_store_id_staff   ON staff (store_id);
CREATE INDEX idx_fk_address_id_staff ON staff (address_id);

-- Now that staff exists, complete the store -> staff FK and unique index
ALTER TABLE store
    ADD CONSTRAINT fk_store_staff
        FOREIGN KEY (manager_staff_id) REFERENCES staff (staff_id)
        ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE UNIQUE INDEX idx_unique_manager ON store (manager_staff_id);

-- ============================================================
-- TABLE: customer
-- (depends on: store, address)
-- ============================================================

CREATE TABLE customer (
    customer_id SERIAL      NOT NULL,
    store_id    INT         NOT NULL,
    first_name  VARCHAR(45) NOT NULL,
    last_name   VARCHAR(45) NOT NULL,
    email       VARCHAR(50) DEFAULT NULL,
    address_id  INT         NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    create_date TIMESTAMP   NOT NULL,
    last_update TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id),
    CONSTRAINT fk_customer_address
        FOREIGN KEY (address_id) REFERENCES address (address_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_customer_store
        FOREIGN KEY (store_id) REFERENCES store (store_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_store_id_customer   ON customer (store_id);
CREATE INDEX idx_fk_address_id_customer ON customer (address_id);
CREATE INDEX idx_last_name              ON customer (last_name);

-- ============================================================
-- TABLE: inventory
-- (depends on: film, store)
-- ============================================================

CREATE TABLE inventory (
    inventory_id SERIAL    NOT NULL,
    film_id      INT       NOT NULL,
    store_id     INT       NOT NULL,
    last_update  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (inventory_id),
    CONSTRAINT fk_inventory_store
        FOREIGN KEY (store_id) REFERENCES store (store_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_inventory_film
        FOREIGN KEY (film_id) REFERENCES film (film_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_film_id_inventory      ON inventory (film_id);
CREATE INDEX idx_store_id_film_id          ON inventory (store_id, film_id);

-- ============================================================
-- TABLE: rental
-- (depends on: inventory, customer, staff)
-- ============================================================

CREATE TABLE rental (
    rental_id    SERIAL    NOT NULL,
    rental_date  TIMESTAMP NOT NULL,
    inventory_id INT       NOT NULL,
    customer_id  INT       NOT NULL,
    return_date  TIMESTAMP DEFAULT NULL,
    staff_id     INT       NOT NULL,
    last_update  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (rental_id),
    CONSTRAINT uq_rental_date_inventory_customer
        UNIQUE (rental_date, inventory_id, customer_id),
    CONSTRAINT fk_rental_staff
        FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rental_inventory
        FOREIGN KEY (inventory_id) REFERENCES inventory (inventory_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rental_customer
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_inventory_id ON rental (inventory_id);
CREATE INDEX idx_fk_customer_id  ON rental (customer_id);
CREATE INDEX idx_fk_staff_id     ON rental (staff_id);

-- ============================================================
-- TABLE: payment
-- (depends on: customer, staff, rental)
-- ============================================================

CREATE TABLE payment (
    payment_id   SERIAL       NOT NULL,
    customer_id  INT          NOT NULL,
    staff_id     INT          NOT NULL,
    rental_id    INT          DEFAULT NULL,
    amount       DECIMAL(5,2) NOT NULL,
    payment_date TIMESTAMP    NOT NULL,
    last_update  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_rental
        FOREIGN KEY (rental_id) REFERENCES rental (rental_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_payment_customer
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_payment_staff
        FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX idx_fk_staff_id_payment    ON payment (staff_id);
CREATE INDEX idx_fk_customer_id_payment ON payment (customer_id);

-- ============================================================
-- VIEWS
-- ============================================================

CREATE OR REPLACE VIEW customer_list AS
SELECT
    cu.customer_id              AS id,
    cu.first_name || ' ' || cu.last_name AS name,
    a.address                   AS address,
    a.postal_code               AS "zip code",
    a.phone                     AS phone,
    city.city                   AS city,
    country.country             AS country,
    CASE WHEN cu.active THEN 'active' ELSE '' END AS notes,
    cu.store_id                 AS sid
FROM customer AS cu
JOIN address AS a       ON cu.address_id = a.address_id
JOIN city               ON a.city_id = city.city_id
JOIN country            ON city.country_id = country.country_id;

-- ------

CREATE OR REPLACE VIEW film_list AS
SELECT
    film.film_id        AS fid,
    film.title          AS title,
    film.description    AS description,
    category.name       AS category,
    film.rental_rate    AS price,
    film.length         AS length,
    film.rating         AS rating,
    STRING_AGG(actor.first_name || ' ' || actor.last_name, ', ') AS actors
FROM category
LEFT JOIN film_category ON category.category_id = film_category.category_id
LEFT JOIN film          ON film_category.film_id = film.film_id
JOIN film_actor         ON film.film_id = film_actor.film_id
JOIN actor              ON film_actor.actor_id = actor.actor_id
GROUP BY film.film_id, film.title, film.description,
         film.rental_rate, film.length, film.rating, category.name;

-- ------

CREATE OR REPLACE VIEW nicer_but_slower_film_list AS
SELECT
    film.film_id        AS fid,
    film.title          AS title,
    film.description    AS description,
    category.name       AS category,
    film.rental_rate    AS price,
    film.length         AS length,
    film.rating         AS rating,
    STRING_AGG(
        INITCAP(LOWER(actor.first_name)) || ' ' || INITCAP(LOWER(actor.last_name)),
        ', '
    ) AS actors
FROM category
LEFT JOIN film_category ON category.category_id = film_category.category_id
LEFT JOIN film          ON film_category.film_id = film.film_id
JOIN film_actor         ON film.film_id = film_actor.film_id
JOIN actor              ON film_actor.actor_id = actor.actor_id
GROUP BY film.film_id, film.title, film.description,
         film.rental_rate, film.length, film.rating, category.name;

-- ------

CREATE OR REPLACE VIEW staff_list AS
SELECT
    s.staff_id                      AS id,
    s.first_name || ' ' || s.last_name AS name,
    a.address                       AS address,
    a.postal_code                   AS "zip code",
    a.phone                         AS phone,
    city.city                       AS city,
    country.country                 AS country,
    s.store_id                      AS sid
FROM staff AS s
JOIN address AS a   ON s.address_id = a.address_id
JOIN city           ON a.city_id = city.city_id
JOIN country        ON city.country_id = country.country_id;

-- ------

CREATE OR REPLACE VIEW sales_by_store AS
SELECT
    c.city || ',' || cy.country             AS store,
    m.first_name || ' ' || m.last_name      AS manager,
    SUM(p.amount)                           AS total_sales
FROM payment AS p
INNER JOIN rental    AS r  ON p.rental_id = r.rental_id
INNER JOIN inventory AS i  ON r.inventory_id = i.inventory_id
INNER JOIN store     AS s  ON i.store_id = s.store_id
INNER JOIN address   AS a  ON s.address_id = a.address_id
INNER JOIN city      AS c  ON a.city_id = c.city_id
INNER JOIN country   AS cy ON c.country_id = cy.country_id
INNER JOIN staff     AS m  ON s.manager_staff_id = m.staff_id
GROUP BY s.store_id, c.city, cy.country, m.first_name, m.last_name
ORDER BY cy.country, c.city;

-- ------

CREATE OR REPLACE VIEW sales_by_film_category AS
SELECT
    c.name        AS category,
    SUM(p.amount) AS total_sales
FROM payment AS p
INNER JOIN rental        AS r  ON p.rental_id = r.rental_id
INNER JOIN inventory     AS i  ON r.inventory_id = i.inventory_id
INNER JOIN film          AS f  ON i.film_id = f.film_id
INNER JOIN film_category AS fc ON f.film_id = fc.film_id
INNER JOIN category      AS c  ON fc.category_id = c.category_id
GROUP BY c.name
ORDER BY total_sales DESC;

-- ------

CREATE OR REPLACE VIEW actor_info AS
SELECT
    a.actor_id,
    a.first_name,
    a.last_name,
    STRING_AGG(
        DISTINCT c.name || ': ' || (
            SELECT STRING_AGG(f.title, ', ' ORDER BY f.title)
            FROM film f
            INNER JOIN film_category fc2 ON f.film_id = fc2.film_id
            INNER JOIN film_actor    fa2 ON f.film_id = fa2.film_id
            WHERE fc2.category_id = c.category_id
              AND fa2.actor_id = a.actor_id
        ),
        '; '
    ) AS film_info
FROM actor AS a
LEFT JOIN film_actor    AS fa ON a.actor_id = fa.actor_id
LEFT JOIN film_category AS fc ON fa.film_id = fc.film_id
LEFT JOIN category      AS c  ON fc.category_id = c.category_id
GROUP BY a.actor_id, a.first_name, a.last_name;

-- ============================================================
-- FUNCTIONS  (replaces MySQL stored functions)
-- ============================================================

-- inventory_in_stock
CREATE OR REPLACE FUNCTION inventory_in_stock(p_inventory_id INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_rentals INT;
    v_out     INT;
BEGIN
    SELECT COUNT(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
        RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory
    LEFT JOIN rental USING (inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
      AND rental.return_date IS NULL;

    RETURN (v_out = 0);
END;
$$;

-- ------

-- inventory_held_by_customer
CREATE OR REPLACE FUNCTION inventory_held_by_customer(p_inventory_id INT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_customer_id INT;
BEGIN
    SELECT customer_id INTO v_customer_id
    FROM rental
    WHERE return_date IS NULL
      AND inventory_id = p_inventory_id;

    RETURN v_customer_id;   -- returns NULL if not found (no rows)
END;
$$;

-- ------

-- get_customer_balance
CREATE OR REPLACE FUNCTION get_customer_balance(
    p_customer_id    INT,
    p_effective_date TIMESTAMP
)
RETURNS DECIMAL(5,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_rentfees DECIMAL(5,2) := 0;
    v_overfees INTEGER      := 0;
    v_payments DECIMAL(5,2) := 0;
BEGIN
    -- 1) Rental fees
    SELECT COALESCE(SUM(film.rental_rate), 0) INTO v_rentfees
    FROM film
    JOIN inventory ON film.film_id       = inventory.film_id
    JOIN rental    ON inventory.inventory_id = rental.inventory_id
    WHERE rental.rental_date  <= p_effective_date
      AND rental.customer_id  = p_customer_id;

    -- 2) Overdue fees (1 day = $1)
    SELECT COALESCE(SUM(
        GREATEST(
            (rental.return_date::DATE - rental.rental_date::DATE) - film.rental_duration,
            0
        )
    ), 0) INTO v_overfees
    FROM rental
    JOIN inventory ON inventory.inventory_id = rental.inventory_id
    JOIN film      ON film.film_id           = inventory.film_id
    WHERE rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id
      AND rental.return_date IS NOT NULL;

    -- 3) Payments already made
    SELECT COALESCE(SUM(payment.amount), 0) INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
      AND payment.customer_id  = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END;
$$;

-- ============================================================
-- PROCEDURES  (replaces MySQL stored procedures)
-- PostgreSQL uses FUNCTIONS that return SETOF or refcursor
-- ============================================================

-- film_in_stock
CREATE OR REPLACE FUNCTION film_in_stock(
    p_film_id   INT,
    p_store_id  INT,
    OUT p_film_count INT
)
RETURNS SETOF INT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
        SELECT inventory_id
        FROM inventory
        WHERE film_id  = p_film_id
          AND store_id = p_store_id
          AND inventory_in_stock(inventory_id);

    GET DIAGNOSTICS p_film_count = ROW_COUNT;
END;
$$;

-- ------

-- film_not_in_stock
CREATE OR REPLACE FUNCTION film_not_in_stock(
    p_film_id   INT,
    p_store_id  INT,
    OUT p_film_count INT
)
RETURNS SETOF INT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
        SELECT inventory_id
        FROM inventory
        WHERE film_id  = p_film_id
          AND store_id = p_store_id
          AND NOT inventory_in_stock(inventory_id);

    GET DIAGNOSTICS p_film_count = ROW_COUNT;
END;
$$;

-- ------

-- rewards_report
CREATE OR REPLACE FUNCTION rewards_report(
    min_monthly_purchases      SMALLINT,
    min_dollar_amount_purchased DECIMAL(10,2)
)
RETURNS TABLE (
    customer_id  INT,
    store_id     INT,
    first_name   VARCHAR,
    last_name    VARCHAR,
    email        VARCHAR,
    address_id   INT,
    active       BOOLEAN,
    create_date  TIMESTAMP,
    last_update  TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    last_month_start DATE;
    last_month_end   DATE;
BEGIN
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased must be > $0.00';
    END IF;

    last_month_start := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::DATE;
    last_month_end   := (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 day')::DATE;

    CREATE TEMP TABLE IF NOT EXISTS tmp_customer (customer_id INT NOT NULL PRIMARY KEY)
        ON COMMIT DROP;

    INSERT INTO tmp_customer (customer_id)
    SELECT p.customer_id
    FROM payment AS p
    WHERE p.payment_date::DATE BETWEEN last_month_start AND last_month_end
    GROUP BY p.customer_id
    HAVING SUM(p.amount) > min_dollar_amount_purchased
       AND COUNT(p.customer_id) > min_monthly_purchases;

    RETURN QUERY
        SELECT c.customer_id, c.store_id, c.first_name, c.last_name,
               c.email, c.address_id, c.active, c.create_date, c.last_update
        FROM tmp_customer AS t
        INNER JOIN customer AS c ON t.customer_id = c.customer_id;
END;
$$;

-- ============================================================
-- Reset sequences to match loaded data (run AFTER data load)
-- ============================================================

-- After loading data, sequences must be updated so next INSERT
-- does not collide.  Call this function once after data import:

CREATE OR REPLACE FUNCTION reset_sequences() RETURNS VOID AS $$
BEGIN
    PERFORM setval('actor_actor_id_seq',      (SELECT MAX(actor_id)      FROM actor));
    PERFORM setval('address_address_id_seq',  (SELECT MAX(address_id)    FROM address));
    PERFORM setval('category_category_id_seq',(SELECT MAX(category_id)   FROM category));
    PERFORM setval('city_city_id_seq',        (SELECT MAX(city_id)       FROM city));
    PERFORM setval('country_country_id_seq',  (SELECT MAX(country_id)    FROM country));
    PERFORM setval('customer_customer_id_seq',(SELECT MAX(customer_id)   FROM customer));
    PERFORM setval('film_film_id_seq',        (SELECT MAX(film_id)       FROM film));
    PERFORM setval('inventory_inventory_id_seq',(SELECT MAX(inventory_id) FROM inventory));
    PERFORM setval('language_language_id_seq',(SELECT MAX(language_id)   FROM language));
    PERFORM setval('payment_payment_id_seq',  (SELECT MAX(payment_id)    FROM payment));
    PERFORM setval('rental_rental_id_seq',    (SELECT MAX(rental_id)     FROM rental));
    PERFORM setval('staff_staff_id_seq',      (SELECT MAX(staff_id)      FROM staff));
    PERFORM setval('store_store_id_seq',      (SELECT MAX(store_id)      FROM store));
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- END OF SCHEMA
-- ============================================================
