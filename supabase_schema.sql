-- 啟用 Row Level Security 用到的 uuid 擴充
create extension if not exists "uuid-ossp";

-- ── 使用者設定檔 ──────────────────────────────────
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text default '我',
  created_at timestamptz default now()
);

-- ── 銀行帳戶 ──────────────────────────────────────
create table bank_accounts (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  bank text not null,
  currency text not null default 'TWD',   -- TWD / USD / JPY
  amount numeric not null default 0,
  rate numeric not null default 0,         -- 年利率 %
  period text not null default 'monthly',  -- monthly/quarterly/halfyear/yearly
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── 投資帳戶 ──────────────────────────────────────
create table inv_accounts (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  market text not null default 'tw',   -- tw / us
  currency text not null default 'TWD',
  cash numeric default 0,
  created_at timestamptz default now()
);

-- ── 持股 ──────────────────────────────────────────
create table holdings (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  account_id uuid references inv_accounts on delete cascade not null,
  ticker text not null,
  name text not null,
  shares numeric not null default 0,
  cost numeric not null default 0,       -- 每股均成本
  price numeric not null default 0,      -- 最新價（定期更新）
  chg numeric default 0,                 -- 今日漲跌 %
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── 房貸 ──────────────────────────────────────────
create table mortgages (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  bank text not null,
  total numeric not null,                -- 貸款總額
  paid_periods integer not null default 0,
  total_periods integer not null,
  rate numeric not null,                 -- 年利率 %
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── Row Level Security（每個人只能看自己的資料）──────
alter table profiles      enable row level security;
alter table bank_accounts enable row level security;
alter table inv_accounts  enable row level security;
alter table holdings      enable row level security;
alter table mortgages     enable row level security;

create policy "own profile"      on profiles      for all using (auth.uid() = id);
create policy "own bank"         on bank_accounts for all using (auth.uid() = user_id);
create policy "own inv accounts" on inv_accounts  for all using (auth.uid() = user_id);
create policy "own holdings"     on holdings      for all using (auth.uid() = user_id);
create policy "own mortgages"    on mortgages     for all using (auth.uid() = user_id);

-- ── 新用戶自動建立 profile ────────────────────────
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
