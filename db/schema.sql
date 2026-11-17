-- PestBusterAI image metadata (PostgreSQL 13+)

CREATE TYPE processing_status AS ENUM (
    'uploaded',    -- row created by ingestion, not yet picked up
    'processing',  -- CV model is working on it
    'processed',   -- processed image written to S3
    'failed'       -- see error_message
);

CREATE TABLE images (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- where the files live
    s3_bucket          TEXT NOT NULL,
    raw_s3_key         TEXT NOT NULL,
    processed_s3_key   TEXT,                 -- NULL until status = 'processed'

    -- parsed from the key
    vineyard_id        TEXT NOT NULL,
    flight_id          TEXT NOT NULL,

    -- parsed from EXIF/XMP; nullable so a photo with missing tags still gets a row
    captured_at        TIMESTAMPTZ,
    latitude           DOUBLE PRECISION CHECK (latitude  BETWEEN -90  AND 90),
    longitude          DOUBLE PRECISION CHECK (longitude BETWEEN -180 AND 180),
    altitude_m         REAL,                 -- EXIF GPSAltitude (above sea level)
    relative_altitude_m REAL,                -- DJI XMP RelativeAltitude (above takeoff point)

    -- pipeline state
    status             processing_status NOT NULL DEFAULT 'uploaded',
    error_message      TEXT,
    uploaded_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT images_raw_key_unique UNIQUE (s3_bucket, raw_s3_key),
    CONSTRAINT processed_key_when_processed
        CHECK (status <> 'processed' OR processed_s3_key IS NOT NULL)
);

CREATE INDEX images_status_idx      ON images (status);
CREATE INDEX images_flight_idx      ON images (flight_id);
CREATE INDEX images_captured_at_idx ON images (captured_at);

-- keep updated_at current on every change
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER images_set_updated_at
    BEFORE UPDATE ON images
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
