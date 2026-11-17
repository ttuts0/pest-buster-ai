# Storage layer

How PestBusterAI stores drone images and their metadata.

## S3

- **Bucket:** `pestbusterai-images`
- **Region:** US East (Ohio), `us-east-2`

Key format:

```
raw/{vineyard_id}/{YYYY-MM-DD}/{flight_id}/{filename}.JPG
processed/{vineyard_id}/{YYYY-MM-DD}/{flight_id}/{filename}.jpg
```

Example: `raw/vy001/2026-11-16/f003/DJI_0042.JPG`

- `raw/` holds the original photos from the drone. Nothing else writes here.
- `processed/` holds the detection model's output. The key is the raw key with the prefix swapped.
- `vineyard_id` and `flight_id` are short lowercase IDs with no spaces. The flight folder keeps keys unique, because DJI filenames repeat.
- The date is the flight date.

## PostgreSQL

- **Instance:** Amazon RDS for PostgreSQL, `pestbusterai-db`, in `us-east-2`
- **Database:** `pestbuster`
- **Table:** `images`, defined in [`db/schema.sql`](../db/schema.sql)

One row per raw image.

| Column | Meaning |
|---|---|
| `s3_bucket`, `raw_s3_key` | Where the original image is. Unique together. |
| `processed_s3_key` | Where the model's output is. Empty until processing finishes. |
| `vineyard_id`, `flight_id` | Taken from the key. |
| `captured_at` | When the photo was taken, from the image's EXIF data. |
| `latitude`, `longitude` | GPS position from EXIF, in decimal degrees. |
| `altitude_m` | Altitude above sea level from EXIF, in meters. |
| `relative_altitude_m` | Height above the takeoff point from DJI's metadata, in meters. |
| `status` | Where the image is in the pipeline (see below). |
| `error_message` | Why processing failed, when `status` is `failed`. |
| `uploaded_at`, `updated_at` | Set automatically. |

GPS, timestamp and altitude can be empty if a photo is missing those EXIF tags.

## Processing status

| Value | Meaning | Set by |
|---|---|---|
| `uploaded` | Row created, image not yet picked up | Ingestion |
| `processing` | Model is working on the image | Detection step |
| `processed` | Output written to `processed/`, `processed_s3_key` filled in | Detection step |
| `failed` | Processing failed, reason in `error_message` | Detection step |

## Credentials

The database password and endpoint are not stored in this repository. Ask Grant for access.
