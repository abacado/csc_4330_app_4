-- Pocket Arcade: run once in a new Supabase project's SQL Editor.
-- Safe to rerun. Does not delete player data.
begin;

create table if not exists public.game_results (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  game_id text not null check (game_id in ('chess','checkers','sudoku','word_search','tic_tac_toe','memory')),
  outcome text not null check (outcome in ('win','loss','draw','completed')),
  mode text not null check (mode in ('solo','local','online')),
  completed_at timestamptz not null default now()
);
create index if not exists game_results_user_time on public.game_results(user_id, completed_at desc);
alter table public.game_results enable row level security;
revoke all on public.game_results from anon, authenticated;
grant select, insert on public.game_results to authenticated;
drop policy if exists results_read_own on public.game_results;
create policy results_read_own on public.game_results for select to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists results_insert_local on public.game_results;
create policy results_insert_local on public.game_results for insert to authenticated
  with check ((select auth.uid()) = user_id and mode in ('solo','local'));

create table if not exists public.rooms (
  code text primary key check (code ~ '^[A-F0-9]{6}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  guest_id uuid references auth.users(id) on delete cascade,
  board text[] not null default array['','','','','','','','',''],
  turn text not null default 'X' check (turn in ('X','O')),
  status text not null default 'waiting' check (status in ('waiting','playing','finished')),
  winner text check (winner in ('X','O')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  check (guest_id is null or guest_id <> host_id),
  check (array_length(board, 1) = 9)
);
create index if not exists rooms_host_created on public.rooms(host_id, created_at desc);
alter table public.rooms enable row level security;
revoke all on public.rooms from anon, authenticated;
grant select on public.rooms to authenticated;
drop policy if exists rooms_read_members on public.rooms;
create policy rooms_read_members on public.rooms for select to authenticated
  using (((select auth.uid()) = host_id or (select auth.uid()) = guest_id) and expires_at > now());

create or replace function public.create_room() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid();
  created public.rooms;
  room_count integer;
begin
  if player is null then raise exception 'Sign in first'; end if;
  -- Serialize room creation per guest so the simple cap cannot be raced.
  perform pg_advisory_xact_lock(hashtextextended(player::text, 0));
  select count(*) into room_count from public.rooms where host_id = player and created_at > now() - interval '1 hour';
  if room_count >= 30 then raise exception 'Room limit reached. Try again later'; end if;
  for attempt in 1..10 loop
    begin
      insert into public.rooms(code, host_id)
        values (upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)), player)
        returning * into created;
      return to_jsonb(created);
    exception when unique_violation then
      -- Retry a code collision without overwriting an existing room.
      null;
    end;
  end loop;
  raise exception 'Could not allocate a room';
end;
$$;

create or replace function public.join_room(room_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid();
  room public.rooms;
begin
  if player is null then raise exception 'Sign in first'; end if;
  select * into room from public.rooms where code = upper(trim(room_code)) for update;
  if not found or room.expires_at <= now() then raise exception 'Room unavailable'; end if;
  if player = room.host_id or player = room.guest_id then return to_jsonb(room); end if;
  if room.guest_id is not null or room.status <> 'waiting' then raise exception 'Room unavailable'; end if;
  update public.rooms set guest_id = player, status = 'playing' where code = room.code returning * into room;
  return to_jsonb(room);
end;
$$;

create or replace function public.play_move(room_code text, cell_index integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid();
  room public.rooms;
  mark text;
  line integer[];
  win_lines integer[][] := array[[1,2,3],[4,5,6],[7,8,9],[1,4,7],[2,5,8],[3,6,9],[1,5,9],[3,5,7]];
begin
  if player is null then raise exception 'Sign in first'; end if;
  if cell_index is null or cell_index < 0 or cell_index > 8 then raise exception 'Invalid cell'; end if;
  select * into room from public.rooms where code = upper(trim(room_code)) for update;
  if not found or room.expires_at <= now() then raise exception 'Room unavailable'; end if;
  if player = room.host_id then mark := 'X';
  elsif player = room.guest_id then mark := 'O';
  else raise exception 'Room unavailable'; end if;
  if room.status <> 'playing' or room.turn <> mark then raise exception 'Not your turn'; end if;
  if room.board[cell_index + 1] <> '' then raise exception 'Cell already taken'; end if;
  room.board[cell_index + 1] := mark;
  foreach line slice 1 in array win_lines loop
    if room.board[line[1]] = mark and room.board[line[2]] = mark and room.board[line[3]] = mark then
      room.winner := mark;
      room.status := 'finished';
      exit;
    end if;
  end loop;
  if room.status <> 'finished' and not ('' = any(room.board)) then room.status := 'finished'; end if;
  if room.status <> 'finished' then room.turn := case when mark = 'X' then 'O' else 'X' end; end if;
  update public.rooms set board = room.board, turn = room.turn, status = room.status, winner = room.winner
    where code = room.code;
  if room.status = 'finished' then
    insert into public.game_results(id, user_id, game_id, outcome, mode) values
      (gen_random_uuid(), room.host_id, 'tic_tac_toe', case when room.winner is null then 'draw' when room.winner = 'X' then 'win' else 'loss' end, 'online'),
      (gen_random_uuid(), room.guest_id, 'tic_tac_toe', case when room.winner is null then 'draw' when room.winner = 'O' then 'win' else 'loss' end, 'online');
  end if;
  return to_jsonb(room);
end;
$$;

revoke all on function public.create_room() from public, anon, authenticated;
revoke all on function public.join_room(text) from public, anon, authenticated;
revoke all on function public.play_move(text, integer) from public, anon, authenticated;
grant execute on function public.create_room() to authenticated;
grant execute on function public.join_room(text) to authenticated;
grant execute on function public.play_move(text, integer) to authenticated;

-- Chess rooms store the position as FEN. Full legal-move/checkmate
-- validation lives in the shared Dart engine on both clients; the server
-- only enforces membership, turn order, and that a move actually happened,
-- then trusts the client-reported status/winner to close out the game.
create table if not exists public.chess_rooms (
  code text primary key check (code ~ '^[A-F0-9]{6}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  guest_id uuid references auth.users(id) on delete cascade,
  fen text not null default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  status text not null default 'waiting' check (status in ('waiting','playing','finished')),
  winner text check (winner in ('white','black')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  check (guest_id is null or guest_id <> host_id)
);
create index if not exists chess_rooms_host_created on public.chess_rooms(host_id, created_at desc);
alter table public.chess_rooms enable row level security;
revoke all on public.chess_rooms from anon, authenticated;
grant select on public.chess_rooms to authenticated;
drop policy if exists chess_rooms_read_members on public.chess_rooms;
create policy chess_rooms_read_members on public.chess_rooms for select to authenticated
  using (((select auth.uid()) = host_id or (select auth.uid()) = guest_id) and expires_at > now());

create or replace function public.create_chess_room() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid();
  created public.chess_rooms;
  room_count integer;
begin
  if player is null then raise exception 'Sign in first'; end if;
  perform pg_advisory_xact_lock(hashtextextended(player::text, 1));
  select count(*) into room_count from public.chess_rooms where host_id = player and created_at > now() - interval '1 hour';
  if room_count >= 30 then raise exception 'Room limit reached. Try again later'; end if;
  for attempt in 1..10 loop
    begin
      insert into public.chess_rooms(code, host_id)
        values (upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)), player)
        returning * into created;
      return to_jsonb(created);
    exception when unique_violation then
      null;
    end;
  end loop;
  raise exception 'Could not allocate a room';
end;
$$;

create or replace function public.join_chess_room(room_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid();
  room public.chess_rooms;
begin
  if player is null then raise exception 'Sign in first'; end if;
  select * into room from public.chess_rooms where code = upper(trim(room_code)) for update;
  if not found or room.expires_at <= now() then raise exception 'Room unavailable'; end if;
  if player = room.host_id or player = room.guest_id then return to_jsonb(room); end if;
  if room.guest_id is not null or room.status <> 'waiting' then raise exception 'Room unavailable'; end if;
  update public.chess_rooms set guest_id = player, status = 'playing' where code = room.code returning * into room;
  return to_jsonb(room);
end;
$$;

create or replace function public.play_chess_move(room_code text, new_fen text, new_status text, new_winner text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid();
  room public.chess_rooms;
  mover_color text;
  active_color text;
begin
  if player is null then raise exception 'Sign in first'; end if;
  if new_status not in ('playing','finished') then raise exception 'Invalid status'; end if;
  if new_winner is not null and new_winner not in ('white','black') then raise exception 'Invalid winner'; end if;
  select * into room from public.chess_rooms where code = upper(trim(room_code)) for update;
  if not found or room.expires_at <= now() then raise exception 'Room unavailable'; end if;
  if room.status <> 'playing' then raise exception 'Game not active'; end if;
  if player = room.host_id then mover_color := 'white';
  elsif player = room.guest_id then mover_color := 'black';
  else raise exception 'Room unavailable'; end if;
  active_color := case when split_part(room.fen, ' ', 2) = 'w' then 'white' else 'black' end;
  if mover_color <> active_color then raise exception 'Not your turn'; end if;
  if new_fen is null or new_fen = room.fen then raise exception 'Invalid move'; end if;
  update public.chess_rooms set fen = new_fen, status = new_status, winner = new_winner
    where code = room.code returning * into room;
  if room.status = 'finished' then
    insert into public.game_results(id, user_id, game_id, outcome, mode) values
      (gen_random_uuid(), room.host_id, 'chess', case when room.winner is null then 'draw' when room.winner = 'white' then 'win' else 'loss' end, 'online'),
      (gen_random_uuid(), room.guest_id, 'chess', case when room.winner is null then 'draw' when room.winner = 'black' then 'win' else 'loss' end, 'online');
  end if;
  return to_jsonb(room);
end;
$$;

revoke all on function public.create_chess_room() from public, anon, authenticated;
revoke all on function public.join_chess_room(text) from public, anon, authenticated;
revoke all on function public.play_chess_move(text, text, text, text) from public, anon, authenticated;
grant execute on function public.create_chess_room() to authenticated;
grant execute on function public.join_chess_room(text) to authenticated;
grant execute on function public.play_chess_move(text, text, text, text) to authenticated;
commit;
