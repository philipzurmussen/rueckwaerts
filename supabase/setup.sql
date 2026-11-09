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
alter table public.games add column if not exists rematch_of uuid;
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

-- Erlaubte Listen-Wörter: Bei Zufallsgegnern wird nur Text aus dieser
-- Liste gespeichert (selbst getippte Wörter gibt es nur unter Freunden).
create table if not exists public.words (word text primary key);
alter table public.words enable row level security;
insert into public.words(word) values
  ('Giraffe'),
  ('Krokodil'),
  ('Elefant'),
  ('Schmetterling'),
  ('Känguru'),
  ('Nilpferd'),
  ('Pinguin'),
  ('Erdmännchen'),
  ('Eichhörnchen'),
  ('Schildkröte'),
  ('Flamingo'),
  ('Papagei'),
  ('Wildschwein'),
  ('Seepferdchen'),
  ('Gorilla'),
  ('Faultier'),
  ('Marienkäfer'),
  ('Waschbär'),
  ('Tintenfisch'),
  ('Chamäleon'),
  ('Dromedar'),
  ('Igel'),
  ('Spaghetti'),
  ('Pfannkuchen'),
  ('Gummibärchen'),
  ('Brokkoli'),
  ('Ananas'),
  ('Kartoffelsalat'),
  ('Pommes'),
  ('Lasagne'),
  ('Schokolade'),
  ('Erdbeere'),
  ('Pizza'),
  ('Joghurt'),
  ('Avocado'),
  ('Fischstäbchen'),
  ('Zimtschnecke'),
  ('Banane'),
  ('Mandarine'),
  ('Spinat'),
  ('Döner'),
  ('Wassermelone'),
  ('Brezel'),
  ('Pfefferminz'),
  ('Kölner Dom'),
  ('Rhein'),
  ('Karneval'),
  ('Alaaf'),
  ('Kamelle'),
  ('Veedel'),
  ('Ehrenfeld'),
  ('Nippes'),
  ('Deutz'),
  ('Hohenzollernbrücke'),
  ('Heinzelmännchen'),
  ('Funkenmariechen'),
  ('Büdchen'),
  ('Tünnes'),
  ('Schäl'),
  ('Domplatte'),
  ('Rheinseilbahn'),
  ('Mülheim'),
  ('Rodenkirchen'),
  ('Halve Hahn'),
  ('Flora'),
  ('Severin'),
  ('Australien'),
  ('Mexiko'),
  ('Kanada'),
  ('Ghana'),
  ('Norwegen'),
  ('Portugal'),
  ('Japan'),
  ('Argentinien'),
  ('Madagaskar'),
  ('Island'),
  ('Paris'),
  ('Barcelona'),
  ('Amsterdam'),
  ('Istanbul'),
  ('Hamburg'),
  ('München'),
  ('New York'),
  ('Kopenhagen'),
  ('Marokko'),
  ('Neuseeland'),
  ('Accra'),
  ('Rio de Janeiro'),
  ('Zahnarzt'),
  ('Lokführerin'),
  ('Bäcker'),
  ('Polizistin'),
  ('Astronaut'),
  ('Tierärztin'),
  ('Schornsteinfeger'),
  ('Pilotin'),
  ('Gärtner'),
  ('Friseurin'),
  ('Kapitän'),
  ('Erzieherin'),
  ('Schreiner'),
  ('Cutterin'),
  ('Tontechniker'),
  ('Zauberer'),
  ('Detektivin'),
  ('Bauarbeiter'),
  ('Postbote'),
  ('Köchin'),
  ('Feuerwehrfrau'),
  ('Bademeister'),
  ('Albert Einstein'),
  ('Mozart'),
  ('Beethoven'),
  ('Kleopatra'),
  ('Napoleon'),
  ('Goethe'),
  ('Marilyn Monroe'),
  ('Elvis Presley'),
  ('Helene Fischer'),
  ('Thomas Gottschalk'),
  ('Heidi Klum'),
  ('Michael Schumacher'),
  ('Lionel Messi'),
  ('Taylor Swift'),
  ('Beyoncé'),
  ('Leonardo DiCaprio'),
  ('Shakira'),
  ('Lukas Podolski'),
  ('Udo Lindenberg'),
  ('Usain Bolt'),
  ('Serena Williams'),
  ('Harry Potter'),
  ('Ich verstehe nur Bahnhof'),
  ('Da liegt der Hund begraben'),
  ('Den Nagel auf den Kopf treffen'),
  ('Um den heißen Brei reden'),
  ('Auf dem Holzweg sein'),
  ('Die Kuh vom Eis holen'),
  ('Ins Fettnäpfchen treten'),
  ('Mit dem falschen Fuß aufstehen'),
  ('Jemandem einen Bären aufbinden'),
  ('Das ist nicht mein Bier'),
  ('Alles in Butter'),
  ('Da steppt der Bär'),
  ('Tomaten auf den Augen'),
  ('Ich glaub, mein Schwein pfeift'),
  ('Hals- und Beinbruch'),
  ('Jetzt geht’s los'),
  ('Guten Appetit'),
  ('Schönen Feierabend'),
  ('Kölle Alaaf'),
  ('Et hätt noch immer jot jejange'),
  ('Wer zuletzt lacht'),
  ('Ich hab Hunger'),
  ('Was geht ab'),
  ('Zack, die Bohne'),
  ('Mach mal Pause'),
  ('Ollah, wie geht’s'),
  ('Butter bei die Fische'),
  ('Ab durch die Mitte'),
  ('Schwein gehabt'),
  ('Liebe geht durch den Magen'),
  ('Donaudampfschiff'),
  ('Streichholzschächtelchen'),
  ('Quietscheentchen'),
  ('Purzelbaum'),
  ('Regenschirm'),
  ('Kuddelmuddel'),
  ('Schnickschnack'),
  ('Hokuspokus'),
  ('Wackelpudding'),
  ('Trampolin'),
  ('Zauberstab'),
  ('Schneemann'),
  ('Achterbahn'),
  ('Luftballon'),
  ('Kaugummi'),
  ('Plappermaul'),
  ('Schlafanzug'),
  ('Kirschkernspucken'),
  ('Ringelnatter'),
  ('Fahrradklingel'),
  ('Butterblume'),
  ('Zahnbürste')
on conflict do nothing;

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

-- Eigenes Profil lesen (z. B. nach dem Anmelden auf einem neuen Gerät)
create or replace function public.my_profile() returns json
language sql stable security definer set search_path = public as $$
  select public.profile_json(auth.uid());
$$;

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
declare me uuid := auth.uid(); g public.games; opp uuid; nr int; prefix text; v_text text;
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
  v_text := nullif(left(trim(coalesce(p_word_text, '')), 40), '');
  if g.is_random and v_text is not null and not exists (select 1 from public.words where word = v_text) then
    v_text := null;
  end if;
  insert into public.rounds(game_id, round_no, setter, word_text, word_path)
    values (p_game, nr, me, v_text, p_word_path);
  insert into public.attempts(game_id, round_no, player, audio_path, sim, stars)
    values (p_game, nr, me, p_own_path, greatest(0, least(1, p_own_sim)), greatest(0, least(3, p_own_stars)));
  update public.games set cur_round = nr, turn = opp, last_move_at = now(), updated_at = now() where id = p_game;
  return json_build_object('ok', true);
end $$;

-- alte Version aus einem früheren Entwurf entfernen
drop function if exists public.play_move(uuid,text,real,int,text,text,text,real,int);

-- Revanche: neues Duell gegen denselben Gegner (wer tippt, gibt zuerst vor).
-- Tippen beide, landen sie im selben neuen Duell.
create or replace function public.rematch(p_game uuid) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.games; opp uuid; nid uuid;
begin
  select * into g from public.games where id = p_game for update;
  if not found or me not in (g.player_a, coalesce(g.player_b, g.player_a)) then raise exception 'Nicht dein Duell'; end if;
  if g.status <> 'done' then raise exception 'Das Duell läuft noch'; end if;
  opp := case when me = g.player_a then g.player_b else g.player_a end;
  if opp is null then raise exception 'Kein Gegner für eine Revanche'; end if;
  select id into nid from public.games where rematch_of = p_game limit 1;
  if nid is not null then return json_build_object('id', nid, 'existing', true); end if;
  insert into public.games(code, player_a, player_b, status, turn, rematch_of)
    values (public.new_code(), me, opp, 'active', me, p_game) returning id into nid;
  return json_build_object('id', nid, 'existing', false);
end $$;

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
           (select x.id from public.games x where x.rematch_of = g.id limit 1) as rematch_id,
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
    'rematch_id', (select x.id from public.games x where x.rematch_of = g.id limit 1),
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
revoke all on function public.rematch(uuid) from public, anon;
grant execute on function public.rematch(uuid) to authenticated;
revoke all on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;
revoke all on function public.save_profile(text,text,text), public.start_game(boolean), public.join_game(text),
  public.answer_round(uuid,text,real,int), public.set_word(uuid,text,text,text,real,int), public.react(uuid,int,uuid,text),
  public.leave_game(uuid), public.my_games(), public.game_detail(uuid) from public, anon;
grant execute on function public.save_profile(text,text,text), public.start_game(boolean), public.join_game(text),
  public.answer_round(uuid,text,real,int), public.set_word(uuid,text,text,text,real,int), public.react(uuid,int,uuid,text),
  public.leave_game(uuid), public.my_games(), public.game_detail(uuid) to authenticated;
grant select on public.profiles, public.games, public.rounds, public.attempts, public.reactions to authenticated;

-- ---------- Seasons (Wochen-Challenges) -----------------------------
-- Pro Woche eine Begriffsliste zu einem Thema. Alle spielen dieselben
-- Begriffe – jeder spricht sie selbst ein und imitiert die eigene
-- Rückwärts-Version (ein Versuch je Begriff). Seasons lassen sich im
-- Voraus planen.

create table if not exists public.admins (uid uuid primary key);
alter table public.admins enable row level security;

create table if not exists public.seasons (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 40),
  topic       text check (char_length(topic) <= 40),
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz not null,
  created_at  timestamptz not null default now()
);
alter table public.seasons alter column id set default gen_random_uuid();
create table if not exists public.season_words (
  season_id  uuid not null references public.seasons(id) on delete cascade,
  idx        int  not null,
  word_text  text not null check (char_length(word_text) between 1 and 40),
  path       text,
  primary key (season_id, idx)
);
alter table public.season_words alter column path drop not null;
create table if not exists public.season_attempts (
  season_id  uuid not null,
  idx        int  not null,
  player     uuid not null references public.profiles(id) on delete cascade,
  sim        real not null check (sim between 0 and 1),
  stars      int  not null check (stars between 0 and 3),
  created_at timestamptz not null default now(),
  primary key (season_id, idx, player),
  foreign key (season_id, idx) references public.season_words(season_id, idx) on delete cascade
);
alter table public.seasons         enable row level security;
alter table public.season_words    enable row level security;
alter table public.season_attempts enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where uid = auth.uid());
$$;

create or replace function public.whoami() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('uid', auth.uid(), 'admin', public.is_admin());
$$;

-- frühere Entwurfsversion entfernen
drop function if exists public.create_season(uuid,text,text,timestamptz,json);

-- Season anlegen (nur Admin). p_words: ["Kastanie", "Laubhaufen", ...]
create or replace function public.create_season(p_title text, p_topic text, p_starts timestamptz, p_ends timestamptz, p_words json) returns json
language plpgsql security definer set search_path = public as $$
declare w text; i int := 0; sid uuid; st timestamptz := greatest(coalesce(p_starts, now()), now() - interval '1 minute');
begin
  if not public.is_admin() then raise exception 'Nur für Admins'; end if;
  if json_array_length(p_words) < 3 or json_array_length(p_words) > 20 then raise exception 'Bitte 3 bis 20 Begriffe'; end if;
  if p_ends <= st then raise exception 'Das Ende muss nach dem Start liegen'; end if;
  if p_ends <= now() then raise exception 'Das Ende liegt in der Vergangenheit'; end if;
  if exists (select 1 from public.seasons where starts_at < p_ends and ends_at > st) then
    raise exception 'In diesem Zeitraum gibt es schon eine Season';
  end if;
  insert into public.seasons(title, topic, starts_at, ends_at)
    values (trim(p_title), nullif(trim(coalesce(p_topic, '')), ''), st, p_ends) returning id into sid;
  for w in select json_array_elements_text(p_words) loop
    if nullif(trim(w), '') is null then continue; end if;
    i := i + 1;
    insert into public.season_words(season_id, idx, word_text) values (sid, i, left(trim(w), 40));
  end loop;
  return json_build_object('ok', true, 'id', sid);
end $$;

-- Laufende Season beenden / geplante löschen (nur Admin)
create or replace function public.end_season(p_id uuid) returns json
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Nur für Admins'; end if;
  delete from public.seasons where id = p_id and starts_at > now();
  update public.seasons set ends_at = least(ends_at, now()) where id = p_id;
  return json_build_object('ok', true);
end $$;

-- Geplante und laufende Seasons (für das Studio)
create or replace function public.list_seasons() returns json
language plpgsql stable security definer set search_path = public as $$
declare res json;
begin
  if not public.is_admin() then raise exception 'Nur für Admins'; end if;
  select coalesce(json_agg(json_build_object(
    'id', s.id, 'title', s.title, 'starts_at', s.starts_at, 'ends_at', s.ends_at,
    'running', s.starts_at <= now(),
    'words', (select json_agg(word_text order by idx) from public.season_words where season_id = s.id),
    'players', (select count(distinct player) from public.season_attempts where season_id = s.id)
  ) order by s.starts_at), '[]'::json) into res
  from public.seasons s where s.ends_at > now();
  return res;
end $$;

-- Rangliste einer Season
create or replace function public.season_board(p_id uuid, p_limit int default 50) returns json
language sql stable security definer set search_path = public as $$
  with t as (
    select player, sum(stars) as st, sum(sim) as sm, count(*) as n
    from public.season_attempts where season_id = p_id group by player
  ), r as (
    select t.*, rank() over (order by st desc, sm desc) as rk from t
  )
  select coalesce(json_agg(json_build_object('rank', r.rk, 'nickname', p.nickname, 'avatar', p.avatar, 'color', p.color,
                                             'stars', r.st, 'played', r.n, 'me', r.player = auth.uid()) order by r.rk), '[]'::json)
  from (select * from r order by rk limit p_limit) r join public.profiles p on p.id = r.player;
$$;

-- Aktuelle Season mit meinem Stand, dazu letzte und nächste Season
create or replace function public.current_season() returns json
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); s public.seasons; l public.seasons; n public.seasons; res json; last json; nxt json;
begin
  select * into l from public.seasons where ends_at <= now() order by ends_at desc limit 1;
  if found then last := json_build_object('id', l.id, 'title', l.title, 'top', public.season_board(l.id, 3)); end if;
  select * into n from public.seasons where starts_at > now() order by starts_at limit 1;
  if found then nxt := json_build_object('title', n.title, 'starts_at', n.starts_at); end if;
  select * into s from public.seasons where starts_at <= now() and ends_at > now() order by starts_at desc limit 1;
  if not found then return json_build_object('active', null, 'last', last, 'next', nxt); end if;
  with r as (
    select player, rank() over (order by sum(stars) desc, sum(sim) desc) as rk, sum(stars) as st
    from public.season_attempts where season_id = s.id group by player
  )
  select json_build_object(
    'active', json_build_object(
      'id', s.id, 'title', s.title, 'topic', s.topic, 'ends_at', s.ends_at,
      'words', (select json_agg(json_build_object(
                  'idx', w.idx, 'word_text', w.word_text,
                  'my', case when a.player is null then null else json_build_object('sim', a.sim, 'stars', a.stars) end
                ) order by w.idx)
                from public.season_words w
                left join public.season_attempts a on a.season_id = w.season_id and a.idx = w.idx and a.player = me
                where w.season_id = s.id),
      'board', public.season_board(s.id, 10),
      'me', json_build_object('rank', (select rk from r where player = me), 'stars', coalesce((select st from r where player = me), 0)),
      'players', (select count(*) from r)
    ),
    'last', last, 'next', nxt
  ) into res;
  return res;
end $$;

-- Einen Begriff der Season spielen (ein Versuch)
create or replace function public.season_attempt(p_season uuid, p_idx int, p_sim real, p_stars int) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); t text;
begin
  if me is null or not exists (select 1 from public.profiles where id = me) then raise exception 'Bitte zuerst ein Profil anlegen'; end if;
  if not exists (select 1 from public.seasons where id = p_season and starts_at <= now() and ends_at > now()) then
    raise exception 'Diese Season ist vorbei';
  end if;
  select word_text into t from public.season_words where season_id = p_season and idx = p_idx;
  if not found then raise exception 'Begriff nicht gefunden'; end if;
  if exists (select 1 from public.season_attempts where season_id = p_season and idx = p_idx and player = me) then
    raise exception 'Diesen Begriff hast du schon gespielt';
  end if;
  insert into public.season_attempts(season_id, idx, player, sim, stars)
    values (p_season, p_idx, me, greatest(0, least(1, p_sim)), greatest(0, least(3, p_stars)));
  return json_build_object('ok', true, 'word_text', t);
end $$;

revoke all on function public.whoami(), public.create_season(text,text,timestamptz,timestamptz,json),
  public.end_season(uuid), public.list_seasons(), public.season_board(uuid,int), public.current_season(),
  public.season_attempt(uuid,int,real,int) from public, anon;
grant execute on function public.is_admin(), public.whoami(), public.create_season(text,text,timestamptz,timestamptz,json),
  public.end_season(uuid), public.list_seasons(), public.current_season(), public.season_attempt(uuid,int,real,int) to authenticated;

-- ---------- Punkte & Rangliste ----------------------------------------
-- Punkte = alle Sterne aus Duellen (mit Gegner) und Seasons + 5 je gewonnenem Duell

create or replace function public.player_xp(p uuid) returns int
language sql stable security definer set search_path = public as $$
  select (
    coalesce((select sum(a.stars) from public.attempts a join public.games g on g.id = a.game_id
              where a.player = p and g.player_b is not null), 0)
    + coalesce((select sum(stars) from public.season_attempts where player = p), 0)
    + 5 * (select count(*) from public.games g
           where g.status = 'done' and g.player_b is not null and p in (g.player_a, g.player_b)
             and ( (g.forfeit_by is not null and g.forfeit_by <> p)
                or (g.forfeit_by is null and
                    coalesce((select sum(stars) from public.attempts where game_id = g.id and player = p), 0) >
                    coalesce((select sum(stars) from public.attempts where game_id = g.id and player <> p), 0)) ))
  )::int;
$$;

create or replace function public.leaderboard() returns json
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); res json;
begin
  with x as (
    select p.id, p.nickname, p.avatar, p.color, public.player_xp(p.id) as xp from public.profiles p
  ), r as (
    select *, rank() over (order by xp desc) as rk from x where xp > 0
  )
  select json_build_object(
    'top', coalesce((select json_agg(json_build_object('rank', rk, 'nickname', nickname, 'avatar', avatar,
                                                       'color', color, 'xp', xp, 'me', id = me) order by rk, nickname)
                     from (select * from r order by rk, nickname limit 50) t), '[]'::json),
    'me', json_build_object('xp', coalesce((select xp from x where id = me), 0),
                            'rank', (select rk from r where id = me),
                            'players', (select count(*) from r))
  ) into res;
  return res;
end $$;

revoke all on function public.player_xp(uuid), public.leaderboard() from public, anon;
grant execute on function public.leaderboard() to authenticated;

-- ---------- Feedback der Tester ---------------------------------------

create table if not exists public.feedback (
  id          bigint generated always as identity primary key,
  player      uuid references public.profiles(id) on delete set null,
  rating      int  check (rating between 1 and 5),
  turn_length text check (turn_length in ('kurz','richtig','lang')),
  fun         text[],
  message     text check (char_length(message) <= 2000),
  user_agent  text,
  created_at  timestamptz not null default now()
);
alter table public.feedback enable row level security;

create or replace function public.send_feedback(p_rating int, p_turn text, p_fun text[], p_message text, p_ua text) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Nicht angemeldet'; end if;
  if (select count(*) from public.feedback where player = me and created_at > now() - interval '1 day') >= 10 then
    raise exception 'Danke, für heute ist genug Feedback angekommen';
  end if;
  insert into public.feedback(player, rating, turn_length, fun, message, user_agent)
    values ((select id from public.profiles where id = me), p_rating, nullif(p_turn, ''), p_fun,
            nullif(left(trim(coalesce(p_message, '')), 2000), ''), left(p_ua, 300));
  return json_build_object('ok', true);
end $$;

-- Übersicht für den Admin (im Studio)
create or replace function public.list_feedback() returns json
language plpgsql stable security definer set search_path = public as $$
declare res json;
begin
  if not public.is_admin() then raise exception 'Nur für Admins'; end if;
  select json_build_object(
    'count', (select count(*) from public.feedback),
    'avg', (select round(avg(rating)::numeric, 1) from public.feedback),
    'turn', (select coalesce(json_object_agg(turn_length, n), '{}'::json)
             from (select turn_length, count(*) n from public.feedback where turn_length is not null group by turn_length) t),
    'fun', (select coalesce(json_object_agg(f, n), '{}'::json)
            from (select unnest(fun) f, count(*) n from public.feedback group by 1) t),
    'items', (select coalesce(json_agg(json_build_object('at', f.created_at, 'rating', f.rating, 'turn', f.turn_length,
                                                         'fun', f.fun, 'message', f.message, 'nickname', p.nickname)
                                       order by f.created_at desc), '[]'::json)
              from (select * from public.feedback order by created_at desc limit 200) f
              left join public.profiles p on p.id = f.player)
  ) into res;
  return res;
end $$;

revoke all on function public.send_feedback(int,text,text[],text,text), public.list_feedback() from public, anon;
grant execute on function public.send_feedback(int,text,text[],text,text), public.list_feedback() to authenticated;

-- ---------- Rundenzähler (anonym: nur Modus, Sterne, Zeit) ------------

create table if not exists public.plays (
  id          bigint generated always as identity primary key,
  player      uuid,
  mode        text not null check (mode in ('frei','satz','season','duell')),
  stars       int  check (stars between 0 and 3),
  created_at  timestamptz not null default now()
);
create index if not exists plays_time_idx on public.plays(created_at);
create index if not exists plays_player_idx on public.plays(player, created_at);
alter table public.plays enable row level security;   -- kein direkter Zugriff, nur über die Funktionen

create or replace function public.log_play(p_mode text, p_stars int) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or p_mode not in ('frei','satz','season','duell') then return; end if;
  if (select count(*) from public.plays where player = me and created_at > now() - interval '1 hour') >= 300 then return; end if;
  insert into public.plays(player, mode, stars) values (me, p_mode, case when p_stars between 0 and 3 then p_stars end);
end $$;

-- Statistik fürs Studio (nur Admin); Admin-Konten werden herausgerechnet
create or replace function public.admin_stats() returns json
language plpgsql stable security definer set search_path = public as $$
declare res json;
begin
  if not public.is_admin() then raise exception 'Nur für Admins'; end if;
  with p as (select * from public.plays where player is null or player not in (select uid from public.admins))
  select json_build_object(
    'plays_total',   (select count(*) from p),
    'plays_today',   (select count(*) from p where created_at >= date_trunc('day', now() at time zone 'Europe/Berlin') at time zone 'Europe/Berlin'),
    'plays_7',       (select count(*) from p where created_at > now() - interval '7 days'),
    'players_total', (select count(distinct player) from p),
    'players_7',     (select count(distinct player) from p where created_at > now() - interval '7 days'),
    'by_mode',       (select coalesce(json_object_agg(mode, n), '{}'::json) from (select mode, count(*) n from p group by mode) t),
    'days',          (select coalesce(json_agg(json_build_object('day', d::date::text, 'plays', coalesce(x.n, 0), 'players', coalesce(x.u, 0)) order by d), '[]'::json)
                      from generate_series((now() at time zone 'Europe/Berlin')::date - 13, (now() at time zone 'Europe/Berlin')::date, interval '1 day') d
                      left join (select (created_at at time zone 'Europe/Berlin')::date dd, count(*) n, count(distinct player) u from p group by 1) x on x.dd = d::date),
    'profiles_total',(select count(*) from public.profiles where id not in (select uid from public.admins)),
    'profiles_7',    (select count(*) from public.profiles where id not in (select uid from public.admins) and created_at > now() - interval '7 days'),
    'duel_attempts', (select count(*) from public.attempts where player not in (select uid from public.admins)),
    'season_attempts',(select count(*) from public.season_attempts where player not in (select uid from public.admins)),
    'own_plays',     (select count(*) from public.plays where player in (select uid from public.admins))
  ) into res;
  return res;
end $$;

revoke all on function public.log_play(text,int), public.admin_stats() from public, anon;
grant execute on function public.log_play(text,int), public.admin_stats() to authenticated;

-- ---------- Audio-Speicher -------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('audio', 'audio', false, 2097152, array['audio/wav'])
on conflict (id) do nothing;

drop policy if exists "Ollah Audio hochladen" on storage.objects;
create policy "Ollah Audio hochladen" on storage.objects for insert to authenticated
  with check (bucket_id = 'audio' and case when (storage.foldername(name))[1] = 'season' then public.is_admin()
                                           else public.is_player(((storage.foldername(name))[1])::uuid) end);

drop policy if exists "Ollah Audio lesen" on storage.objects;
create policy "Ollah Audio lesen" on storage.objects for select to authenticated
  using (bucket_id = 'audio' and case when (storage.foldername(name))[1] = 'season' then true
                                      else public.is_player(((storage.foldername(name))[1])::uuid) end);

-- ---------- Live-Aktualisierung --------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'games') then
    alter publication supabase_realtime add table public.games;
  end if;
end $$;
