-- First drop existing function and view
drop function if exists update_seller_setup_intent cascade;
drop view if exists seller_subscription_status cascade;

-- Add payment setup tracking fields to sellers table
alter table public.sellers
  add column if not exists setup_intent_id text,
  add column if not exists setup_intent_status text check (setup_intent_status in ('requires_payment_method', 'requires_confirmation', 'succeeded', 'canceled')),
  add column if not exists setup_intent_client_secret text;

-- Create function to update setup intent status
create or replace function update_seller_setup_intent(
  p_seller_id uuid,
  p_setup_intent_id text,
  p_status text,
  p_client_secret text
) returns void as $$
begin
  update sellers
  set 
    setup_intent_id = p_setup_intent_id,
    setup_intent_status = p_status,
    setup_intent_client_secret = p_client_secret,
    subscription_status = case
      when p_status = 'succeeded' then 'active'
      else subscription_status
    end,
    subscription_start_date = case
      when p_status = 'succeeded' then now()
      else subscription_start_date
    end
  where id = p_seller_id;
end;
$$ language plpgsql security definer;

-- Create new view with all fields
create view seller_subscription_status as
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
grant select on seller_subscription_status to authenticated;
grant execute on function update_seller_setup_intent(uuid, text, text, text) to authenticated;

-- Force schema cache refresh
notify pgrst, 'reload schema';