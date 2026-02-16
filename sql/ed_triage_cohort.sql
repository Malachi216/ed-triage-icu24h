
WITH ed_base AS (
  SELECT
    e.subject_id,
    e.hadm_id,
    e.stay_id,
    e.intime AS arrival_time,
    p.anchor_age,
    p.gender,
    e.race
  FROM `physionet-data.mimiciv_ed.edstays` AS e
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.patients` AS p
    USING (subject_id)
),

early_vitals AS (
  SELECT
    v.subject_id,
    v.stay_id,
    -- example: median vitals in first 2 hours
    AVG(v.temperature) AS temp_mean_2h,
    AVG(v.heartrate)   AS hr_mean_2h,
    AVG(v.resprate)    AS rr_mean_2h,
    AVG(v.o2sat)       AS o2_mean_2h,
    AVG(v.sbp)         AS sbp_mean_2h,
    AVG(v.dbp)         AS dbp_mean_2h
  FROM `physionet-data.mimiciv_ed.vitalsign` AS v
  JOIN `physionet-data.mimiciv_ed.edstays`   AS e
    ON v.subject_id = e.subject_id
   AND v.stay_id    = e.stay_id
   AND v.charttime BETWEEN e.intime
                       AND DATETIME_ADD(e.intime, INTERVAL 2 HOUR)
  GROUP BY v.subject_id, v.stay_id
),

icu_flag AS (
  SELECT
    hadm_id,
    MIN(intime) AS first_icu_intime
  FROM `physionet-data.mimiciv_3_1_icu.icustays`
  GROUP BY hadm_id
)

SELECT
  b.*,
  ev.* EXCEPT(subject_id, stay_id),
  i.first_icu_intime AS icu_intime,
  CASE
    WHEN i.first_icu_intime IS NOT NULL
         AND DATETIME_DIFF(i.first_icu_intime, b.arrival_time, HOUR) <= 24
    THEN 1 ELSE 0
  END AS icu_24h
FROM ed_base b
LEFT JOIN early_vitals ev
  USING (subject_id, stay_id)
LEFT JOIN icu_flag i
  USING (hadm_id);
