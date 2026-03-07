with visitors_with_leads as (
    select
        s.visitor_id,
        s.visit_date,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        lower(s.source) as utm_source,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

aggregated_data as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(distinct visitor_id) as visitors_count,
        count(distinct lead_id) as leads_count,
        count(
            distinct case
                when status_id = 142 then lead_id
            end
        ) as purchases_count,
        coalesce(
            sum(
                case
                    when status_id = 142 then amount
                end
            ),
            0
        ) as revenue
    from visitors_with_leads
    where
        rn = 1
        and lead_id is not null
    group by
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date)
),

marketing_data as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign

    union all

    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
)

select
    a.visit_date,
    a.utm_source,
    a.utm_medium,
    a.utm_campaign,
    a.visitors_count,
    a.leads_count,
    a.purchases_count,
    coalesce(a.revenue, 0) as revenue,
    coalesce(m.total_cost, 0) as total_cost
from aggregated_data as a
left join marketing_data as m
    on
        a.visit_date = m.visit_date
        and a.utm_source = m.utm_source
        and a.utm_medium = m.utm_medium
        and a.utm_campaign = m.utm_campaign
order by
    revenue desc nulls last,
    a.visit_date asc,
    a.visitors_count desc,
    a.utm_source asc,
    a.utm_medium asc,
    a.utm_campaign asc
limit 15;
