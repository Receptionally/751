-- Drop existing tables and start fresh
drop table if exists public.sellers cascade;

-- Create sellers table with snake_case column names
create table public.sellers (
    id uuid primary key,
    name text not null,
    business_name text not null,
    business_address text not null,
    email text not null unique,
    phone text not null,
    firewood_unit text,
    price_per_unit decimal(10,2),
    max_delivery_distance integer,
    min_delivery_fee decimal(10,2),
    price_per_mile decimal(10,2),
    payment_timing text,
    accepts_cash_on_delivery boolean default false,
    provides_stacking boolean default false,
    stacking_fee_per_unit decimal(10,2),
    status text not null default 'pending',
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    
    constraint sellers_status_check check (status in ('pending', 'approved', 'rejected')),
    constraint sellers_firewood_unit_check check (firewood_unit in ('cords', 'facecords', 'ricks')),
    constraint sellers_payment_timing_check check (payment_timing in ('scheduling', 'delivery'))
);

-- Enable RLS
alter table public.sellers enable row level security;

-- Create policies
create policy "Enable read for all users"
    on public.sellers for select
    using (true);

create policy "Enable insert for authenticated users"
    on public.sellers for insert
    to authenticated
    with check (auth.uid() = id);

create policy "Enable update for authenticated users"
    on public.sellers for update
    to authenticated
    using (auth.uid() = id);

-- Update handle_new_user function to match column names
create or replace function public.handle_new_user()
returns trigger as $$
begin
  if new.raw_user_meta_data->>'role' = 'seller' then
    insert into public.sellers (
      id,
      name,
      business_name,
      business_address,
      email,
      phone,
      firewood_unit,
      price_per_unit,
      max_delivery_distance,
      min_delivery_fee,
      price_per_mile,
      payment_timing,
      accepts_cash_on_delivery,
      provides_stacking,
      stacking_fee_per_unit,
      status
    ) values (
      new.id,
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'businessName',
      new.raw_user_meta_data->>'businessAddress',
      new.email,
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'firewoodUnit',
      (new.raw_user_meta_data->>'pricePerUnit')::decimal,
      (new.raw_user_meta_data->>'maxDeliveryDistance')::integer,
      (new.raw_user_meta_data->>'minDeliveryFee')::decimal,
      (new.raw_user_meta_data->>'pricePerMile')::decimal,
      new.raw_user_meta_data->>'paymentTiming',
      (new.raw_user_meta_data->>'acceptsCashOnDelivery')::boolean,
      (new.raw_user_meta_data->>'providesStacking')::boolean,
      (new.raw_user_meta_data->>'stackingFeePerUnit')::decimal,
      'pending'
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

-- Recreate trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();