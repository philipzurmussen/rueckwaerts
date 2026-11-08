-- =====================================================================
-- Ollah! – Datenbank-Einrichtung für Supabase
-- Einmal komplett im SQL Editor ausführen. Kann gefahrlos erneut
-- ausgeführt werden (Funktionen werden aktualisiert, Daten bleiben).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Tabellen -------------------------------------------------

create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nickname    text not null default 'Spieler' check (char_length(nickname) between 1 and 16),
  avatar      text not null default '🦊' check (char_length(avatar) between 1 and 8),
  color       text not null default '#ff8fab' check (color ~ '^#[0-9a-fA-F]{6}$'),
  created_at  timestamptz not null default now()
);

create table if not exists public.games (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  player_a      uuid not null references public.profiles(id) on delete cascade,
  player_b      uuid references public.profiles(id) on delete cascade,
  is_random     boolean not null default false,
  status        text not null default 'open' check (status in ('open','active','done')),
  total_rounds  int not null default 6,
  cur_round     int not null default 0,      -- Anzahl bereits vorgegebener Runden
  turn          uuid,                        -- wer ist dran (null = niemand / wartet auf Beitritt)
  forfeit_by    uuid,                        -- wer hat durch Zeitablauf verloren
  last_move_at  timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create index if not exists games_a_idx on public.games(player_a);
create index if not exists games_b_idx on public.games(player_b);
create index if not exists games_open_idx on public.games(status, is_random);

create table if not exists public.rounds (
  game_id     uuid not null references public.games(id) on delete cascade,
  round_no    int  not null,
  setter      uuid not null,
  word_text   text check (char_length(word_text) <= 40),
  word_path   text not null,
  created_at  timestamptz not null default now(),
  primary key (game_id, round_no)
);

create table if not exists public.attempts (
  game_id     uuid not null,
  round_no    int  not null,
  player      uuid not null,
  audio_path  text not null,
  sim         real not null check (sim between 0 and 1),
  stars       int  not null check (stars between 0 and 3),
  created_at  timestamptz not null default now(),
  primary key (game_id, round_no, player),
  foreign key (game_id, round_no) references public.rounds(game_id, round_no) on delete cascade
);

create table if not exists public.reactions (
  id          bigint generated always as identity primary key,
  game_id     uuid not null,
  round_no    int  not null,
  target      uuid not null,     -- Spieler, dessen Aufnahme gemeint ist
  from_player uuid not null,
  emoji       text not null check (emoji in ('😂','🤯','👏','🙈','🔥')),
  created_at  timestamptz not null default now(),
  foreign key (game_id, round_no, target) references public.attempts(game_id, round_no, player) on delete cascade
);
create index if not exists reactions_game_idx on public.reactions(game_id);

-- ---------- Hilfsfunktionen ------------------------------------------

create or replace function public.is_player(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.games where id = g and auth.uid() in (player_a, player_b));
$$;

create or replace function public.new_code() returns text
language plpgsql volatile set search_path = public as $$
declare abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := '';
    for i in 1..6 loop c := c || substr(abc, 1 + floor(random() * length(abc))::int, 1); end loop;
    exit when not exists (select 1 from public.games where code = c);
  end loop;
  return c;
end $$;

create or replace function public.profile_json(p uuid) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('id', id, 'nickname', nickname, 'avatar', avatar, 'color', color)
  from public.profiles where id = p;
$$;

-- ---------- Sicherheit (Row Level Security) --------------------------
-- Gelesen wird über die Funktionen unten; die Regeln hier schützen den
-- Direktzugriff und steuern, wer Live-Änderungen (Realtime) bekommt.

alter table public.profiles  enable row level security;
alter table public.games     enable row level security;
alter table public.rounds    enable row level security;
alter table public.attempts  enable row level security;
alter table public.reactions enable row level security;

drop policy if exists "Profile lesen" on public.profiles;
create policy "Profile lesen" on public.profiles for select to authenticated using (true);

drop policy if exists "Eigene Spiele lesen" on public.games;
create policy "Eigene Spiele lesen" on public.games for select to authenticated
  using (auth.uid() in (player_a, player_b));

drop policy if exists "Runden lesen" on public.rounds;
create policy "Runden lesen" on public.rounds for select to authenticated using (public.is_player(game_id));
drop policy if exists "Versuche lesen" on public.attempts;
create policy "Versuche lesen" on public.attempts for select to authenticated using (public.is_player(game_id));
drop policy if exists "Reaktionen lesen" on public.reactions;
create policy "Reaktionen lesen" on public.reactions for select to authenticated using (public.is_player(game_id));
-- Kein direktes Schreiben: alle Änderungen laufen über die Funktionen.

-- ---------- Spiel-Funktionen -----------------------------------------

-- Profil anlegen/ändern
create or replace function public.save_profile(p_nickname text, p_avatar text, p_color text) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Nicht angemeldet'; end if;
  insert into public.profiles(id, nickname, avatar, color)
  values (me, left(coalesce(nullif(trim(p_nickname), ''), 'Spieler'), 16), p_avatar, p_color)
  on conflict (id) do update set nickname = excluded.nickname, avatar = excluded.avatar, color = excluded.color;
  return public.profile_json(me);
end $$;

-- Neues Duell (Freund) oder Zufallsgegner suchen
create or replace function public.start_game(p_random boolean default false) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games;
begin
  if me is null or not exists (select 1 from public.profiles where id = me) then
    raise exception 'Bitte zuerst ein Profil anlegen';
  end if;
  if p_random then
    -- offenes Zufallsspiel eines anderen übernehmen (der Ersteller hat schon vorgelegt)
    select * into g from public.games
      where status = 'open' and is_random and player_b is null and player_a <> me and cur_round >= 1
        and not exists (select 1 from public.games x where x.status <> 'done' and x.is_random
                        and ((x.player_a = me and x.player_b = games.player_a) or (x.player_b = me and x.player_a = games.player_a)))
      order by created_at
      limit 1 for update skip locked;
    if found then
      update public.games set player_b = me, status = 'active', turn = me, last_move_at = now(), updated_at = now()
        where id = g.id;
      return json_build_object('id', g.id, 'code', g.code, 'joined', true);
    end if;
    -- schon ein eigenes, noch unbespieltes Zufallsspiel? Dann das weiterverwenden
    select * into g from public.games
      where player_a = me and is_random and status = 'open' and cur_round = 0 limit 1;
    if found then return json_build_object('id', g.id, 'code', g.code, 'joined', false); end if;
  end if;
  insert into public.games(code, player_a, is_random, turn)
    values (public.new_code(), me, p_random, me) returning * into g;
  return json_build_object('id', g.id, 'code', g.code, 'joined', false);
end $$;

-- Einladung annehmen
create or replace function public.join_game(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games;
begin
  if me is null or not exists (select 1 from public.profiles where id = me) then
    raise exception 'Bitte zuerst ein Profil anlegen';
  end if;
  select * into g from public.games where code = upper(trim(p_code)) for update;
  if not found then raise exception 'Kein Duell mit diesem Code gefunden'; end if;
  if g.player_a = me or g.player_b = me then return json_build_object('id', g.id); end if;
  if g.player_b is not null then raise exception 'Dieses Duell ist schon vergeben'; end if;
  if g.status = 'done' then raise exception 'Dieses Duell ist schon vorbei'; end if;
  update public.games
    set player_b = me, status = 'active',
        turn = case when cur_round = 0 then player_a else me end,
        last_move_at = now(), updated_at = now()
    where id = g.id;
  return json_build_object('id', g.id);
end $$;

-- Zug Teil 1: das Wort des Gegners beantworten (ein Versuch).
-- Nach der letzten Runde endet damit das Duell.
create or replace function public.answer_round(p_game uuid, p_path text, p_sim real, p_stars int) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games;
begin
  select * into g from public.games where id = p_game for update;
  if not found or me not in (g.player_a, coalesce(g.player_b, g.player_a)) then raise exception 'Nicht dein Duell'; end if;
  if g.status = 'done' then raise exception 'Dieses Duell ist schon vorbei'; end if;
  if g.turn is distinct from me then raise exception 'Du bist gerade nicht dran'; end if;
  if g.cur_round = 0 then raise exception 'Es gibt noch kein Wort zu beantworten'; end if;
  if exists (select 1 from public.attempts where game_id = p_game and round_no = g.cur_round and player = me) then
    raise exception 'Diese Runde hast du schon gespielt';
  end if;
  if p_path is null or left(p_path, 37) <> p_game::text || '/' then raise exception 'Aufnahme fehlt'; end if;
  insert into public.attempts(game_id, round_no, player, audio_path, sim, stars)
    values (p_game, g.cur_round, me, p_path, greatest(0, least(1, p_sim)), greatest(0, least(3, p_stars)));
  if g.cur_round >= g.total_rounds then
    update public.games set status = 'done', turn = null, last_move_at = now(), updated_at = now() where id = p_game;
  else
    update public.games set last_move_at = now(), updated_at = now() where id = p_game;
  end if;
  return json_build_object('ok', true, 'done', g.cur_round >= g.total_rounds);
end $$;

-- Zug Teil 2: neues Wort vorgeben und selbst einmal versuchen.
-- Danach ist der Gegner dran.
create or replace function public.set_word(
  p_game uuid, p_word_text text, p_word_path text, p_own_path text, p_own_sim real, p_own_stars int
) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games; opp uuid; nr int; prefix text;
begin
  select * into g from public.games where id = p_game for update;
  if not found or me not in (g.player_a, coalesce(g.player_b, g.player_a)) then raise exception 'Nicht dein Duell'; end if;
  if g.status = 'done' then raise exception 'Dieses Duell ist schon vorbei'; end if;
  if g.turn is distinct from me then raise exception 'Du bist gerade nicht dran'; end if;
  if g.cur_round >= g.total_rounds then raise exception 'Alle Runden sind schon vergeben'; end if;
  if g.cur_round > 0 and not exists (select 1 from public.attempts where game_id = p_game and round_no = g.cur_round and player = me) then
    raise exception 'Erst das Wort deines Gegners spielen';
  end if;
  prefix := p_game::text || '/';
  if p_word_path is null or p_own_path is null
     or left(p_word_path, length(prefix)) <> prefix or left(p_own_path, length(prefix)) <> prefix then
    raise exception 'Aufnahme fehlt';
  end if;
  opp := case when me = g.player_a then g.player_b else g.player_a end;
  nr := g.cur_round + 1;
  insert into public.rounds(game_id, round_no, setter, word_text, word_path)
    values (p_game, nr, me, nullif(left(trim(coalesce(p_word_text, '')), 40), ''), p_word_path);
  insert into public.attempts(game_id, round_no, player, audio_path, sim, stars)
    values (p_game, nr, me, p_own_path, greatest(0, least(1, p_own_sim)), greatest(0, least(3, p_own_stars)));
  update public.games set cur_round = nr, turn = opp, last_move_at = now(), updated_at = now() where id = p_game;
  return json_build_object('ok', true);
end $$;

-- alte Version aus einem früheren Entwurf entfernen
drop function if exists public.play_move(uuid,text,real,int,text,text,text,real,int);

-- Auf eine Aufnahme reagieren
create or replace function public.react(p_game uuid, p_round int, p_target uuid, p_emoji text) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if not public.is_player(p_game) then raise exception 'Nicht dein Duell'; end if;
  if p_target = me then raise exception 'Nicht auf dich selbst'; end if;
  if not exists (select 1 from public.attempts where game_id = p_game and round_no = p_round and player = me) then
    raise exception 'Erst selbst versuchen';
  end if;
  if (select count(*) from public.reactions where game_id = p_game and round_no = p_round and from_player = me) >= 10 then
    return json_build_object('ok', false);
  end if;
  insert into public.reactions(game_id, round_no, target, from_player, emoji) values (p_game, p_round, p_target, me, p_emoji);
  update public.games set updated_at = now() where id = p_game;
  return json_build_object('ok', true);
end $$;

-- Duell aufgeben / offene Einladung löschen
create or replace function public.leave_game(p_game uuid) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games;
begin
  select * into g from public.games where id = p_game for update;
  if not found or me not in (g.player_a, coalesce(g.player_b, g.player_a)) then raise exception 'Nicht dein Duell'; end if;
  if g.player_b is null then
    delete from public.games where id = p_game;
  elsif g.status <> 'done' then
    update public.games set status = 'done', forfeit_by = me, turn = null, updated_at = now() where id = p_game;
  end if;
  return json_build_object('ok', true);
end $$;

-- Übersicht meiner Duelle (inkl. 48-Stunden-Regel)
create or replace function public.my_games() returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); res json;
begin
  if me is null then return '[]'::json; end if;
  -- Wer 48 Stunden nicht zieht, verliert
  update public.games set status = 'done', forfeit_by = turn, turn = null, updated_at = now()
    where status = 'active' and turn is not null and last_move_at < now() - interval '48 hours'
      and me in (player_a, player_b);
  -- Nie angenommene Einladungen nach 14 Tagen aufräumen
  delete from public.games where player_a = me and player_b is null and created_at < now() - interval '14 days';

  select coalesce(json_agg(x order by x.sort1, x.last_move_at desc), '[]'::json) into res from (
    select g.id, g.code, g.status, g.is_random, g.cur_round, g.total_rounds, g.last_move_at,
           g.forfeit_by = me as i_forfeited,
           g.forfeit_by is not null and g.forfeit_by <> me as opp_forfeited,
           g.turn = me as my_turn,
           public.profile_json(case when g.player_a = me then g.player_b else g.player_a end) as opponent,
           coalesce((select sum(stars) from public.attempts a where a.game_id = g.id and a.player = me), 0) as my_score,
           coalesce((select sum(stars) from public.attempts a where a.game_id = g.id and a.player <> me
                      and exists (select 1 from public.attempts b where b.game_id = a.game_id and b.round_no = a.round_no and b.player = me)), 0) as opp_score,
           case when g.status = 'done' then 2 when g.turn = me then 0 else 1 end as sort1
    from public.games g
    where me in (g.player_a, g.player_b)
      and (g.status <> 'done' or g.updated_at > now() - interval '30 days')
    order by g.updated_at desc
    limit 60
  ) x;
  return res;
end $$;

-- Ein Duell im Detail. Wörter und gegnerische Aufnahmen werden erst
-- freigegeben, wenn man die Runde selbst gespielt hat.
create or replace function public.game_detail(p_game uuid) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games; opp uuid; res json;
begin
  select * into g from public.games where id = p_game;
  if not found or me not in (g.player_a, coalesce(g.player_b, g.player_a)) then raise exception 'Nicht dein Duell'; end if;
  opp := case when me = g.player_a then g.player_b else g.player_a end;
  select json_build_object(
    'id', g.id, 'code', g.code, 'status', g.status, 'is_random', g.is_random,
    'cur_round', g.cur_round, 'total_rounds', g.total_rounds, 'my_turn', g.turn = me,
    'i_forfeited', g.forfeit_by = me, 'opp_forfeited', g.forfeit_by is not null and g.forfeit_by <> me,
    'last_move_at', g.last_move_at,
    'me', public.profile_json(me), 'opponent', public.profile_json(opp),
    'rounds', coalesce((
      select json_agg(json_build_object(
        'round_no', r.round_no,
        'mine', r.setter = me,
        'word_path', r.word_path,
        'word_text', case when r.setter = me or mine.player is not null then r.word_text end,
        'my', case when mine.player is null then null else json_build_object('path', mine.audio_path, 'sim', mine.sim, 'stars', mine.stars) end,
        'their', case when theirs.player is null then null
                      when mine.player is null then json_build_object('hidden', true)
                      else json_build_object(
                        'path', case when theirs.sim >= 0.10 then theirs.audio_path end,
                        'sim', theirs.sim, 'stars', theirs.stars) end,
        'got', coalesce((select json_agg(emoji order by id) from public.reactions x
                          where x.game_id = r.game_id and x.round_no = r.round_no and x.target = me), '[]'::json),
        'sent', coalesce((select json_agg(distinct emoji) from public.reactions x
                          where x.game_id = r.game_id and x.round_no = r.round_no and x.from_player = me), '[]'::json)
      ) order by r.round_no)
      from public.rounds r
      left join public.attempts mine   on mine.game_id = r.game_id and mine.round_no = r.round_no and mine.player = me
      left join public.attempts theirs on theirs.game_id = r.game_id and theirs.round_no = r.round_no and theirs.player = opp
      where r.game_id = g.id
    ), '[]'::json)
  ) into res;
  return res;
end $$;

-- Ausführrechte: nur angemeldete Nutzer (auch anonyme)
revoke all on function public.save_profile(text,text,text), public.start_game(boolean), public.join_game(text),
  public.answer_round(uuid,text,real,int), public.set_word(uuid,text,text,text,real,int), public.react(uuid,int,uuid,text),
  public.leave_game(uuid), public.my_games(), public.game_detail(uuid) from public, anon;
grant execute on function public.save_profile(text,text,text), public.start_game(boolean), public.join_game(text),
  public.answer_round(uuid,text,real,int), public.set_word(uuid,text,text,text,real,int), public.react(uuid,int,uuid,text),
  public.leave_game(uuid), public.my_games(), public.game_detail(uuid) to authenticated;
grant select on public.profiles, public.games, public.rounds, public.attempts, public.reactions to authenticated;

-- ---------- Audio-Speicher -------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('audio', 'audio', false, 2097152, array['audio/wav'])
on conflict (id) do nothing;

drop policy if exists "Ollah Audio hochladen" on storage.objects;
create policy "Ollah Audio hochladen" on storage.objects for insert to authenticated
  with check (bucket_id = 'audio' and public.is_player(((storage.foldername(name))[1])::uuid));

drop policy if exists "Ollah Audio lesen" on storage.objects;
create policy "Ollah Audio lesen" on storage.objects for select to authenticated
  using (bucket_id = 'audio' and public.is_player(((storage.foldername(name))[1])::uuid));

-- ---------- Live-Aktualisierung --------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'games') then
    alter publication supabase_realtime add table public.games;
  end if;
end $$;
