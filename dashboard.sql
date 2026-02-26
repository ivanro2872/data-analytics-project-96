-- агрегация данных по дням и UTM-меткам
SELECT
    DATE(visit_date) AS visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    COUNT(DISTINCT visitor_id) AS visitors_count, -- уникальные визиты
    COUNT(DISTINCT lead_id) AS leads_count,      -- уникальные лиды
    COUNT(DISTINCT CASE WHEN status_id = 142 THEN lead_id END) AS purchases_count, -- успешные продажи
    SUM(CASE WHEN status_id = 142 THEN amount ELSE 0 END) AS revenue -- сумма выручки
FROM
    last_paid_click
GROUP BY
    DATE(visit_date),
    utm_source,
    utm_medium,
    utm_campaign
ORDER BY
    visit_date DESC;

-- объединение данных о визитах и лидах с данными о расходах
SELECT
    v.visit_date,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    v.visitors_count,
    v.leads_count,
    v.purchases_count,
    v.revenue,
    c.total_cost -- подтягиваем расходы из другого датасета
FROM (
    -- подзапрос визитов и лидов (как в п.1)
) v
LEFT JOIN costs_table c ON
    v.visit_date = c.cost_date AND
    v.utm_source = c.utm_source AND
    v.utm_medium = c.utm_medium AND
    v.utm_campaign = c.utm_campaign;

-- примеры вычисляемых полей (для дашборда)
SELECT
    ...,
    -- CPU
    SAFE_DIVIDE(total_cost, visitors_count) AS CPU,
    -- CPL
    SAFE_DIVIDE(total_cost, leads_count) AS CPL,
    -- CPPU
    SAFE_DIVIDE(total_cost, purchases_count) AS CPPU,
    -- ROI (%)
    SAFE_DIVIDE((revenue - total_cost), total_cost) * 100 AS ROI_percent
FROM aggregate_last_paid_click;

-- расчет времени между визитом и покупкой (для успешных продаж)
SELECT
    visitor_id,
    visit_date,
    created_at AS lead_created_date,
    DATE_DIFF(created_at, visit_date, DAY) AS days_to_lead, -- дни до лида
    amount
FROM
    last_paid_click
WHERE
    status_id = 142 -- только успешные продажи
    AND created_at IS NOT NULL
ORDER BY
    days_to_lead;

WITH conversion_time AS (
    SELECT
        DATE_DIFF(created_at, visit_date, DAY) AS days_to_close
    FROM last_paid_click
    WHERE status_id = 142 AND created_at IS NOT NULL
)
SELECT
    APPROX_QUANTILES(days_to_close, 100)[OFFSET(90)] AS percentile_90_days
FROM conversion_time;