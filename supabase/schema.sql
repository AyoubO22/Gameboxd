-- Gameboxd — Supabase schema. Paste it in the SQL editor (Dashboard → SQL Editor → New query → Run).
-- Safe to re-run: every statement checks before creating.

-- Profiles: one per account, public (pseudo, avatar), editable only by its owner.
create table if not exists public.profiles (
    id           uuid primary key references auth.users (id) on delete cascade,
    username     text not null unique
                 check (username ~ '^[a-z0-9_]{3,20}$'),
    display_name text check (char_length(display_name) <= 40),
    bio          text check (char_length(bio) <= 160),
    avatar_url   text,
    created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;
drop policy if exists "profiles are public" on public.profiles;
create policy "profiles are public" on public.profiles for select using (true);
drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert" on public.profiles for insert with check (auth.uid() = id);
drop policy if exists "own profile update" on public.profiles;
create policy "own profile update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- The profile is created with the account, from the pseudo chosen at sign-up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    insert into public.profiles (id, username, display_name)
    values (new.id,
            lower(new.raw_user_meta_data ->> 'username'),
            new.raw_user_meta_data ->> 'display_name');
    return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
    for each row execute function public.handle_new_user();

-- Is a pseudo free? Callable before sign-up (anonymous), answers true/false only.
create or replace function public.username_available(name text)
returns boolean language sql stable security definer set search_path = public as $$
    select not exists (select 1 from public.profiles where username = lower(name));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- Follows: who follows whom. Anyone can see them; you only add or remove your own.
create table if not exists public.follows (
    follower_id uuid not null references public.profiles (id) on delete cascade,
    followee_id uuid not null references public.profiles (id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (follower_id, followee_id),
    check (follower_id <> followee_id)
);
create index if not exists follows_followee_idx on public.follows (followee_id);

alter table public.follows enable row level security;
drop policy if exists "follows are public" on public.follows;
create policy "follows are public" on public.follows for select using (true);
drop policy if exists "follow as yourself" on public.follows;
create policy "follow as yourself" on public.follows for insert with check (auth.uid() = follower_id);
drop policy if exists "unfollow as yourself" on public.follows;
create policy "unfollow as yourself" on public.follows for delete using (auth.uid() = follower_id);

-- Activity: what people share (a session, a finished game, a rating, a review).
create table if not exists public.activities (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references public.profiles (id) on delete cascade,
    kind           text not null check (kind in ('played', 'completed', 'platinum', 'rated', 'reviewed', 'added')),
    game_title     text not null check (char_length(game_title) <= 200),
    game_cover_url text,
    rating         smallint check (rating between 1 and 5),
    review         text check (char_length(review) <= 2000),
    minutes        integer check (minutes >= 0),
    created_at     timestamptz not null default now()
);
create index if not exists activities_user_time_idx on public.activities (user_id, created_at desc);

alter table public.activities enable row level security;
drop policy if exists "activity is public" on public.activities;
create policy "activity is public" on public.activities for select using (true);
drop policy if exists "post as yourself" on public.activities;
create policy "post as yourself" on public.activities for insert with check (auth.uid() = user_id);
drop policy if exists "delete your own" on public.activities;
create policy "delete your own" on public.activities for delete using (auth.uid() = user_id);

-- Account deletion from inside the app (an App Store requirement). Deleting the auth user
-- cascades to the profile, follows and activity.
create or replace function public.delete_account()
returns void language sql security definer set search_path = public as $$
    delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
