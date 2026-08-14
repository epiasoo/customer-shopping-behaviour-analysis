-- =============================================================================
-- Customer Shopping Behaviour Analysis — star schema
-- Target: MySQL 8.0+
--
-- The notebook creates these tables automatically via SQLAlchemy's to_sql().
-- This file is the explicit DDL: it documents the intended types, keys and
-- constraints, and lets the warehouse be rebuilt without running Python.
--
-- Usage:
--   mysql -u root -p < sql/schema.sql
-- Then run the notebook to populate, or LOAD DATA INFILE from data/processed/.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS customer_behaviour
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE customer_behaviour;

-- Dependency order matters: drop children before parents.
DROP TABLE IF EXISTS fact_purchase;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_item;
DROP TABLE IF EXISTS dim_location;


-- -----------------------------------------------------------------------------
-- Dimensions
-- -----------------------------------------------------------------------------

-- One row per customer. Demographics plus the derived bands and the K-Means
-- segment assigned in the notebook.
CREATE TABLE dim_customer (
    customer_id         INT             NOT NULL,
    age                 TINYINT UNSIGNED NOT NULL,
    age_band            VARCHAR(10)     NOT NULL COMMENT 'Fixed bands: 18-24 .. 65+',
    gender              VARCHAR(10)     NOT NULL,
    loyalty_tier        VARCHAR(20)     NOT NULL COMMENT 'Banded from previous_purchases',
    segment             VARCHAR(40)     NOT NULL COMMENT 'K-Means behavioural segment',
    is_subscriber       TINYINT(1)      NOT NULL,
    previous_purchases  SMALLINT        NOT NULL,
    PRIMARY KEY (customer_id),
    INDEX idx_customer_segment  (segment),
    INDEX idx_customer_age_band (age_band),
    CONSTRAINT chk_customer_age CHECK (age BETWEEN 18 AND 100)
) ENGINE = InnoDB;


-- Product taxonomy. item_key is a surrogate key generated in the notebook.
CREATE TABLE dim_item (
    item_key        SMALLINT     NOT NULL,
    item_purchased  VARCHAR(50)  NOT NULL,
    category        VARCHAR(30)  NOT NULL,
    PRIMARY KEY (item_key),
    UNIQUE KEY uq_item (item_purchased, category),
    INDEX idx_item_category (category)
) ENGINE = InnoDB;


CREATE TABLE dim_location (
    location_key  SMALLINT     NOT NULL,
    location      VARCHAR(50)  NOT NULL,
    PRIMARY KEY (location_key),
    UNIQUE KEY uq_location (location)
) ENGINE = InnoDB;


-- -----------------------------------------------------------------------------
-- Fact
-- -----------------------------------------------------------------------------
-- IMPORTANT: the source is a customer-level snapshot, so this is one row per
-- customer, not a transaction log. There is no order date. Any time-based
-- analysis (trends, cohorts, true LTV) would need a different source.

CREATE TABLE fact_purchase (
    purchase_key             INT            NOT NULL,
    customer_id              INT            NOT NULL,
    item_key                 SMALLINT       NOT NULL,
    location_key             SMALLINT       NOT NULL,
    season                   VARCHAR(10)    NOT NULL,
    size                     VARCHAR(5)     NOT NULL,
    color                    VARCHAR(20)    NOT NULL,
    purchase_amount          SMALLINT       NOT NULL COMMENT 'USD, most recent order',
    review_rating            DECIMAL(3,2)   NOT NULL,
    review_rating_imputed    TINYINT(1)     NOT NULL COMMENT '1 = filled with category median',
    received_discount        TINYINT(1)     NOT NULL,
    shipping_type            VARCHAR(20)    NOT NULL,
    payment_method           VARCHAR(20)    NOT NULL,
    purchase_frequency_days  SMALLINT       NOT NULL COMMENT 'Stated cadence in days',
    purchases_per_year       DECIMAL(6,2)   NOT NULL COMMENT '365 / cadence',
    est_annual_value         DECIMAL(10,2)  NOT NULL
        COMMENT 'purchase_amount x purchases_per_year. Planning proxy, NOT a forecast.',

    PRIMARY KEY (purchase_key),
    INDEX idx_fact_customer (customer_id),
    INDEX idx_fact_item     (item_key),
    INDEX idx_fact_location (location_key),
    INDEX idx_fact_season   (season),

    CONSTRAINT fk_fact_customer FOREIGN KEY (customer_id)
        REFERENCES dim_customer (customer_id),
    CONSTRAINT fk_fact_item FOREIGN KEY (item_key)
        REFERENCES dim_item (item_key),
    CONSTRAINT fk_fact_location FOREIGN KEY (location_key)
        REFERENCES dim_location (location_key),

    CONSTRAINT chk_purchase_amount CHECK (purchase_amount >= 0),
    CONSTRAINT chk_review_rating   CHECK (review_rating BETWEEN 1 AND 5)
) ENGINE = InnoDB;


-- -----------------------------------------------------------------------------
-- Post-load verification
-- -----------------------------------------------------------------------------
-- Run after populating. Expected: 3900 / 3900 / 25 / 50, and zero orphans.

-- SELECT 'fact_purchase' AS table_name, COUNT(*) AS rows FROM fact_purchase
-- UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
-- UNION ALL SELECT 'dim_item',     COUNT(*) FROM dim_item
-- UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location;

-- SELECT COUNT(*) AS orphaned_items
-- FROM      fact_purchase f
-- LEFT JOIN dim_item i ON f.item_key = i.item_key
-- WHERE     i.item_key IS NULL;
