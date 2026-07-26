CREATE SCHEMA IF NOT EXISTS hive.datalake
WITH (location = 's3a://datalake/');


CREATE TABLE hive.datalake.nyc_taxi (
    VendorID                INTEGER,
    tpep_pickup_datetime    TIMESTAMP(3),
    tpep_dropoff_datetime   TIMESTAMP(3),
    passenger_count         DOUBLE,
    trip_distance           DOUBLE,
    RatecodeID              DOUBLE,
    store_and_fwd_flag      VARCHAR,
    PULocationID            INTEGER,
    DOLocationID            INTEGER,
    payment_type            BIGINT,
    fare_amount             DOUBLE,
    extra                   DOUBLE,
    mta_tax                 DOUBLE,
    tip_amount              DOUBLE,
    tolls_amount            DOUBLE,
    improvement_surcharge   DOUBLE,
    total_amount            DOUBLE,
    congestion_surcharge    DOUBLE,
    Airport_fee             DOUBLE,
    cbd_congestion_fee      DOUBLE
)
WITH (
    external_location = 's3a://datalake/nyc_taxi/2026/01',
    format = 'PARQUET'
);
