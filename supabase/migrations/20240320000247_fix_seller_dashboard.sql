-- Drop existing views
drop view if exists seller_analytics_summary cascade;
drop view if exists seller_subscription_status cascade;

-- Create analytics views
create or replace view seller_analytics_summary as
select 
    s.id as seller_id,
    s.business_name,
    s.total_orders,
    s.subscription_status,
    coalesce(pv.total_views, 0) as total_views,
    coalesce(pv.views_last_7_days, 0) as views_last_7_days,
    coalesce(ss.total_appearances, 0) as total_appearances,
    coalesce(ss.appearances_last_7_days, 0) as appearances_last_7_days
from sellers s
left join (
    select 
        seller_id,
        count(*) as total_views,
        count(case when created_at >= now() - interval '7 days' then 1 end) as views_last_7_days
    from pageviews
    group by seller_id
) pv on s.id = pv.seller_id
left join (
    select 
        seller_id,
        count(*) as total_appearances,
        count(case when created_at >= now() - interval '7 days' then 1 end) as appearances_last_7_days
    from seller_search_appearances
    group by seller_id
) ss on s.id = ss.seller_id;

-- Create subscription status view
create or replace view seller_subscription_status as
select
  s.id,
  s.business_name,
  s.total_orders,
  s.subscription_status,
  s.setup_intent_id,
  s.setup_intent_status,
  s.setup_intent_client_secret,
  s.subscription_start_date,
  s.subscription_end_date,
  s.card_last4,
  s.card_brand,
  coalesce(s.debt_amount, 0) as debt_amount,
  s.last_failed_charge,
  s.failed_charge_amount,
  case
    when s.total_orders >= 3 then true
    else false
  end as requires_subscription,
  case
    when coalesce(s.debt_amount, 0) > 0 then false
    when s.subscription_status = 'active' then true
    when s.total_orders < 3 then true
    else false
  end as can_accept_orders,
  greatest(0, 3 - s.total_orders) as orders_until_subscription
from sellers s;

-- Grant permissions
grant select on seller_analytics_summary to authenticated;
grant select on seller_subscription_status to authenticated;