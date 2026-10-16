-- Gameboxd — Supabase schema. Paste it in the SQL editor (Dashboard → SQL Editor → New query → Run).
-- Safe to re-run: every statement checks before creating.

-- Profiles: one per account, readable by signed-in players, editable only by its owner.
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
-- Read policy: v3 (players only).
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

-- Follows: who follows whom. Players can see them; you only add or remove your own.
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
-- Read policy: v3 (players only).
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
-- Read policy: v3 (public profiles only).
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

-- ─────────────────────────────────────────────────────────────────────────────
-- v2 — Public library: each player's collection, readable by players while the profile is public, written by its
-- owner only. The phone stays the source of truth; this is a mirror friends can browse.
create table if not exists public.library_games (
    user_id       uuid not null references public.profiles (id) on delete cascade,
    game_id       uuid not null,              -- the id of the game on the owner's phone
    rawg_id       integer,
    title         text not null check (char_length(title) <= 200),
    platform      text check (char_length(platform) <= 60),
    release_year  text check (char_length(release_year) <= 10),
    cover_url     text,
    genres        text[] not null default '{}',
    status        text not null check (status in ('none', 'wantToPlay', 'playing', 'completed', 'shelved', 'platinum')),
    rating        smallint not null default 0 check (rating between 0 and 5),
    review        text check (char_length(review) <= 10000),
    is_spoiler    boolean not null default false,
    play_minutes  integer not null default 0 check (play_minutes >= 0),
    completion    smallint not null default 0 check (completion between 0 and 100),
    is_favorite   boolean not null default false,
    completed_at  timestamptz,
    updated_at    timestamptz not null default now(),
    primary key (user_id, game_id)
);
create index if not exists library_games_user_status_idx on public.library_games (user_id, status);

alter table public.library_games enable row level security;
drop policy if exists "libraries are public" on public.library_games;
-- Read policy: v3 (public profiles only).
drop policy if exists "own library insert" on public.library_games;
create policy "own library insert" on public.library_games for insert with check (auth.uid() = user_id);
drop policy if exists "own library update" on public.library_games;
create policy "own library update" on public.library_games for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own library delete" on public.library_games;
create policy "own library delete" on public.library_games for delete using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- v3 — Steam id on the profile: lets players find their Steam friends on Gameboxd and
-- shows what they're playing. Public, like a Steam profile link; set by the app on link.
alter table public.profiles add column if not exists steam_id text
    check (steam_id ~ '^[0-9]{17}$');
create unique index if not exists profiles_steam_id_key on public.profiles (steam_id) where steam_id is not null;

-- ─────────────────────────────────────────────────────────────────────────────
-- v4 — Security. Run it after v1 to v3; safe to re-run.

-- "Profil public" lives in the database, so the server enforces it (it used to be a
-- setting on the phone only: activity stayed readable after going private).
alter table public.profiles add column if not exists is_public boolean not null default true;

-- Can the caller see this player's collection and activity? Their own always; others'
-- only while the profile is public. Security definer so it reads profiles without
-- depending on the caller's own policies.
create or replace function public.is_visible(owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select owner = auth.uid()
        or exists (select 1 from public.profiles where id = owner and is_public);
$$;
revoke all on function public.is_visible(uuid) from public, anon;
grant execute on function public.is_visible(uuid) to authenticated;

-- Reading the social network needs an account: the anon key ships inside the app, so
-- "public" used to mean "anyone on the internet can download every player".
drop policy if exists "profiles are public" on public.profiles;
drop policy if exists "profiles are readable by players" on public.profiles;
create policy "profiles are readable by players" on public.profiles for select to authenticated using (true);
drop policy if exists "follows are public" on public.follows;
drop policy if exists "follows are readable by players" on public.follows;
create policy "follows are readable by players" on public.follows for select to authenticated using (true);
drop policy if exists "activity is public" on public.activities;
drop policy if exists "activity of public profiles" on public.activities;
create policy "activity of public profiles" on public.activities for select to authenticated using (public.is_visible(user_id));
drop policy if exists "libraries are public" on public.library_games;
drop policy if exists "libraries of public profiles" on public.library_games;
create policy "libraries of public profiles" on public.library_games for select to authenticated using (public.is_visible(user_id));

-- Pictures other players' phones load on their own: only from the game databases the
-- app uses, so nobody can point covers at their own server and log visitors' addresses.
-- Mirrored in the app by RemoteImage.isAllowed.
create or replace function public.is_allowed_image_url(url text)
returns boolean language sql immutable as $$
    select url is null
        or (char_length(url) <= 2048
            and url ~ '^https://([a-z0-9-]+\.)*(rawg\.io|igdb\.com|steamstatic\.com|steampowered\.com|playstation\.com|playstation\.net)/');
$$;
update public.profiles set avatar_url = null where not public.is_allowed_image_url(avatar_url);
update public.activities set game_cover_url = null where not public.is_allowed_image_url(game_cover_url);
update public.library_games set cover_url = null where not public.is_allowed_image_url(cover_url);
alter table public.profiles drop constraint if exists profiles_avatar_url_allowed;
alter table public.profiles add constraint profiles_avatar_url_allowed check (public.is_allowed_image_url(avatar_url));
alter table public.activities drop constraint if exists activities_cover_allowed;
alter table public.activities add constraint activities_cover_allowed check (public.is_allowed_image_url(game_cover_url));
alter table public.library_games drop constraint if exists library_games_cover_allowed;
alter table public.library_games add constraint library_games_cover_allowed check (public.is_allowed_image_url(cover_url));

-- Genres: a short list of short labels, not a place to store megabytes.
update public.library_games set genres = genres[1:30] where cardinality(genres) > 30;
alter table public.library_games drop constraint if exists library_games_genres_bounded;
alter table public.library_games add constraint library_games_genres_bounded
    check (cardinality(genres) <= 30 and char_length(array_to_string(genres, ',')) <= 1000);

-- Names that would pass for the app itself. Existing accounts are left alone (not valid);
-- new pseudos and new display names are checked.
create or replace function public.is_reserved_name(name text)
returns boolean language sql immutable as $$
    select coalesce(lower(name) ~ 'gameboxd'
                 or lower(name) ~ '^(admin|administrateur|administrator|moderateur|moderator|modo|support|staff|team|official|officiel)([_ ]|$)', false);
$$;
alter table public.profiles drop constraint if exists profiles_names_not_reserved;
alter table public.profiles add constraint profiles_names_not_reserved
    check (not public.is_reserved_name(username) and not public.is_reserved_name(display_name)) not valid;

create or replace function public.username_available(name text)
returns boolean language sql stable security definer set search_path = public as $$
    select not public.is_reserved_name(name)
       and not exists (select 1 from public.profiles where username = lower(name));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- Flood limits: one account can't bury everyone's feed or fill the database.
create or replace function public.enforce_rate_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    recent integer;
begin
    if tg_table_name = 'activities' then
        select count(*) into recent from public.activities
            where user_id = new.user_id and created_at > now() - interval '1 hour';
        if recent >= 60 then
            raise exception 'rate limit: too many activities' using errcode = 'P0001';
        end if;
    elsif tg_table_name = 'follows' then
        select count(*) into recent from public.follows
            where follower_id = new.follower_id and created_at > now() - interval '1 hour';
        if recent >= 100 then
            raise exception 'rate limit: too many follows' using errcode = 'P0001';
        end if;
    elsif tg_table_name = 'library_games' then
        select count(*) into recent from public.library_games where user_id = new.user_id;
        if recent >= 10000 then
            raise exception 'rate limit: library too large' using errcode = 'P0001';
        end if;
    end if;
    return new;
end;
$$;
drop trigger if exists activities_rate_limit on public.activities;
create trigger activities_rate_limit before insert on public.activities
    for each row execute function public.enforce_rate_limit();
drop trigger if exists follows_rate_limit on public.follows;
create trigger follows_rate_limit before insert on public.follows
    for each row execute function public.enforce_rate_limit();
drop trigger if exists library_games_rate_limit on public.library_games;
create trigger library_games_rate_limit before insert on public.library_games
    for each row execute function public.enforce_rate_limit();

-- Steam id: only the `steam-link` Edge Function sets it, after Steam confirms the player
-- owns that account (Steam sign-in). Before, the app wrote it and anyone could claim
-- someone else's id. Players can still remove theirs.
alter table public.profiles add column if not exists steam_verified boolean not null default false;
update public.profiles set steam_id = null where steam_id is not null and not steam_verified;

create or replace function public.protect_steam_id()
returns trigger language plpgsql as $$
begin
    if current_user in ('anon', 'authenticated') then
        if tg_op = 'INSERT' then
            new.steam_id := null;
            new.steam_verified := false;
        elsif new.steam_id is null then
            new.steam_verified := false;
        else
            new.steam_id := old.steam_id;
            new.steam_verified := old.steam_verified;
        end if;
    end if;
    return new;
end;
$$;
drop trigger if exists profiles_protect_steam_id on public.profiles;
create trigger profiles_protect_steam_id before insert or update on public.profiles
    for each row execute function public.protect_steam_id();
