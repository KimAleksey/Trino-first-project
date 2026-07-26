CREATE SCHEMA minio.datalake
WITH (location = 's3://datalake/');

DROP TABLE minio.datalake.nyc_taxi;

CREATE TABLE minio.datalake.nyc_taxi (
    VendorID               INTEGER,
    tpep_pickup_datetime    TIMESTAMP(3),
    tpep_dropoff_datetime   TIMESTAMP(3),
    passenger_count         DOUBLE,
    trip_distance           DOUBLE,
    RatecodeID               DOUBLE,
    store_and_fwd_flag      VARCHAR,
    PULocationID             INTEGER,
    DOLocationID             INTEGER,
    payment_type             BIGINT,
    fare_amount              DOUBLE,
    extra                    DOUBLE,
    mta_tax                  DOUBLE,
    tip_amount               DOUBLE,
    tolls_amount             DOUBLE,
    improvement_surcharge    DOUBLE,
    total_amount             DOUBLE,
    congestion_surcharge     DOUBLE,
    Airport_fee              DOUBLE,
    cbd_congestion_fee       DOUBLE,
    year                    VARCHAR,
    month                   VARCHAR
)
WITH (
    external_location = 's3://datalake/nyc_taxi/',
    format = 'PARQUET',
    partitioned_by = ARRAY['year', 'month']
);

CALL minio.system.sync_partition_metadata('datalake', 'nyc_taxi', 'FULL');

SELECT * FROM minio.datalake.nyc_taxi;
