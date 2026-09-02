create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text,role text not null default 'user' check(role in('user','admin')),created_at timestamptz not null default now());
create table if not exists public.wallets(user_id uuid primary key references auth.users(id) on delete cascade,balance bigint not null default 0 check(balance>=0),updated_at timestamptz not null default now());
create table if not exists public.wallet_transactions(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,type text not null check(type in('deposit','order','refund','adjustment')),amount bigint not null,balance_before bigint not null default 0,balance_after bigint not null default 0,status text not null default 'pending' check(status in('pending','success','failed','cancelled')),reference text unique,provider_cost bigint not null default 0,profit bigint not null default 0,description text,created_at timestamptz not null default now());
create table if not exists public.deposits(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,provider_id text,external_id text unique,requested_amount bigint not null check(requested_amount>0),fee bigint not null default 0,received_amount bigint not null default 0,status text not null default 'pending' check(status in('pending','success','cancelled','expired')),payment_method text not null default 'qris',qr_image text,qr_string text,expires_at timestamptz,created_at timestamptz not null default now(),paid_at timestamptz);
create table if not exists public.pricing_rules(id uuid primary key default gen_random_uuid(),service_code text,country_code text,operator_id text,markup_type text not null default 'fixed' check(markup_type in('fixed','percent')),markup_value bigint not null default 0 check(markup_value>=0),active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.orders(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,external_id text unique,service_code text,service_name text,country_code text,operator_id text,provider_cost bigint not null default 0,sale_price bigint not null default 0,profit bigint not null default 0,status text not null default 'pending',created_at timestamptz not null default now(),completed_at timestamptz);
create table if not exists public.admin_audit_logs(id uuid primary key default gen_random_uuid(),admin_id uuid not null references auth.users(id) on delete cascade,action text not null,target_type text,target_id text,metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now());

alter table public.profiles enable row level security; alter table public.wallets enable row level security; alter table public.wallet_transactions enable row level security; alter table public.deposits enable row level security; alter table public.pricing_rules enable row level security; alter table public.orders enable row level security; alter table public.admin_audit_logs enable row level security;
drop policy if exists profiles_own on public.profiles; create policy profiles_own on public.profiles for select using(auth.uid()=id);
drop policy if exists wallet_own on public.wallets; create policy wallet_own on public.wallets for select using(auth.uid()=user_id);
drop policy if exists tx_own on public.wallet_transactions; create policy tx_own on public.wallet_transactions for select using(auth.uid()=user_id);
drop policy if exists deposits_own on public.deposits; create policy deposits_own on public.deposits for select using(auth.uid()=user_id);
drop policy if exists orders_own on public.orders; create policy orders_own on public.orders for select using(auth.uid()=user_id);
drop policy if exists pricing_read on public.pricing_rules; create policy pricing_read on public.pricing_rules for select using(active=true);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')) on conflict(id) do nothing;
insert into public.wallets(user_id,balance) values(new.id,0) on conflict(user_id) do nothing;
return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.apply_wallet_transaction(p_user_id uuid,p_type text,p_amount bigint,p_reference text,p_description text default null,p_provider_cost bigint default 0,p_profit bigint default 0)
returns public.wallet_transactions language plpgsql security definer set search_path=public as $$
declare w public.wallets; t public.wallet_transactions;
begin
if exists(select 1 from public.wallet_transactions where reference=p_reference) then select * into t from public.wallet_transactions where reference=p_reference; return t; end if;
select * into w from public.wallets where user_id=p_user_id for update;
if not found then raise exception 'Wallet not found'; end if;
if p_amount<0 and w.balance+p_amount<0 then raise exception 'Insufficient balance'; end if;
update public.wallets set balance=balance+p_amount,updated_at=now() where user_id=p_user_id returning * into w;
insert into public.wallet_transactions(user_id,type,amount,balance_before,balance_after,status,reference,provider_cost,profit,description)
values(p_user_id,p_type,p_amount,w.balance-p_amount,w.balance,'success',p_reference,p_provider_cost,p_profit,p_description) returning * into t;
return t; end; $$;
