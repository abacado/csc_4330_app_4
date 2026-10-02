-- Pocket Arcade: run once in a new Supabase project's SQL Editor.
-- Safe to rerun. Does not delete player data.
begin;

create table if not exists public.game_results (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  game_id text not null check (game_id in ('chess','checkers','sudoku','word_search','tic_tac_toe','memory','minesweeper')),
  outcome text not null check (outcome in ('win','loss','draw','completed')),
  mode text not null check (mode in ('solo','local','online')),
  completed_at timestamptz not null default now()
);
alter table public.game_results add column if not exists moves jsonb;
alter table public.game_results drop constraint if exists game_results_game_id_check;
alter table public.game_results add constraint game_results_game_id_check
  check (game_id in ('chess','checkers','sudoku','word_search','tic_tac_toe','memory','minesweeper'));
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
-- Checkers boards use 0=empty, 1=black, 2=black king, -1=red, -2=red king.
-- All rules are validated on the server; clients submit only source/destination.
create table if not exists public.checkers_rooms (
  code text primary key check (code ~ '^[A-F0-9]{6}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  guest_id uuid references auth.users(id) on delete cascade,
  board integer[] not null check (array_length(board,1) = 64),
  turn text not null default 'black' check (turn in ('black','red')),
  jumper integer check (jumper between 0 and 63),
  revision integer not null default 0,
  status text not null default 'waiting' check (status in ('waiting','playing','finished')),
  winner text check (winner in ('black','red')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  check (guest_id is null or guest_id <> host_id)
);
create index if not exists checkers_rooms_host_created on public.checkers_rooms(host_id, created_at desc);
alter table public.checkers_rooms enable row level security;
revoke all on public.checkers_rooms from anon, authenticated;
grant select on public.checkers_rooms to authenticated;
drop policy if exists checkers_rooms_read_members on public.checkers_rooms;
create policy checkers_rooms_read_members on public.checkers_rooms for select to authenticated
  using (((select auth.uid()) = host_id or (select auth.uid()) = guest_id) and expires_at > now());

-- Internal move generation, with board wrapping and direction checks.
create or replace function public.checkers_moves(b integer[], side text, forced integer)
returns table(src integer, dst integer, captured integer)
language plpgsql immutable set search_path = '' as $$
declare
  i integer; dr integer; dc integer; r integer; c integer; nr integer; nc integer;
  lr integer; lc integer; p integer; target integer;
  sign integer := case when side = 'black' then 1 else -1 end;
begin
  for i in 0..63 loop
    p := b[i+1];
    if p * sign <= 0 or (forced is not null and forced <> i) then continue; end if;
    r := i / 8; c := i % 8;
    foreach dr in array array[-1,1] loop
      if abs(p) = 1 and dr <> sign then continue; end if;
      foreach dc in array array[-1,1] loop
        nr := r + dr; nc := c + dc;
        if nr < 0 or nr > 7 or nc < 0 or nc > 7 then continue; end if;
        target := b[nr*8+nc+1];
        if target = 0 and forced is null then
          src := i; dst := nr*8+nc; captured := null; return next;
        elsif target * sign < 0 then
          lr := nr+dr; lc := nc+dc;
          if lr between 0 and 7 and lc between 0 and 7 and b[lr*8+lc+1] = 0 then
            src := i; dst := lr*8+lc; captured := nr*8+nc; return next;
          end if;
        end if;
      end loop;
    end loop;
  end loop;
end;
$$;
revoke all on function public.checkers_moves(integer[],text,integer) from public, anon, authenticated;

create or replace function public.create_checkers_room() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid(); created public.checkers_rooms; b integer[] := array_fill(0,array[64]);
  i integer;
begin
  if player is null then raise exception 'Sign in first'; end if;
  perform pg_advisory_xact_lock(hashtextextended(player::text, 2));
  if (select count(*) from public.checkers_rooms where host_id = player and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Room limit reached. Try again later';
  end if;
  for i in 0..63 loop
    if (i/8+i%8)%2=1 then
      if i/8 < 3 then b[i+1] := 1; elsif i/8 > 4 then b[i+1] := -1; end if;
    end if;
  end loop;
  for attempt in 1..10 loop
    begin
      insert into public.checkers_rooms(code,host_id,board)
        values(upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),player,b) returning * into created;
      return to_jsonb(created);
    exception when unique_violation then null;
    end;
  end loop;
  raise exception 'Could not allocate a room';
end;
$$;

create or replace function public.join_checkers_room(room_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare player uuid := auth.uid(); room public.checkers_rooms;
begin
  if player is null then raise exception 'Sign in first'; end if;
  select * into room from public.checkers_rooms where code = upper(trim(room_code)) for update;
  if not found or room.expires_at <= now() then raise exception 'Room unavailable'; end if;
  if player = room.host_id or player = room.guest_id then return to_jsonb(room); end if;
  if room.guest_id is not null or room.status <> 'waiting' then raise exception 'Room unavailable'; end if;
  update public.checkers_rooms set guest_id = player, status = 'playing' where code = room.code returning * into room;
  return to_jsonb(room);
end;
$$;

create or replace function public.play_checkers_move(room_code text, from_square integer, to_square integer, expected_revision integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  player uuid := auth.uid(); room public.checkers_rooms; mover text; jumped integer;
  piece integer; crowned boolean; jump_available boolean;
begin
  if player is null then raise exception 'Sign in first'; end if;
  if from_square is null or to_square is null or from_square not between 0 and 63 or to_square not between 0 and 63 then
    raise exception 'Invalid square';
  end if;
  select * into room from public.checkers_rooms where code = upper(trim(room_code)) for update;
  if not found or room.expires_at <= now() then raise exception 'Room unavailable'; end if;
  if player = room.host_id then mover := 'black';
  elsif player = room.guest_id then mover := 'red';
  else raise exception 'Room unavailable'; end if;
  if room.status <> 'playing' or room.turn <> mover then raise exception 'Not your turn'; end if;
  if expected_revision is distinct from room.revision then raise exception 'Position changed; refresh the room'; end if;
  select m.captured into jumped from public.checkers_moves(room.board,room.turn,room.jumper) m
    where m.src = from_square and m.dst = to_square;
  if not found then raise exception 'Illegal move'; end if;
  select exists(select 1 from public.checkers_moves(room.board,room.turn,room.jumper) m where m.captured is not null) into jump_available;
  if jump_available and jumped is null then raise exception 'A jump is required'; end if;
  piece := room.board[from_square+1];
  room.board[from_square+1] := 0;
  if jumped is not null then room.board[jumped+1] := 0; end if;
  crowned := abs(piece)=1 and ((piece=1 and to_square/8=7) or (piece=-1 and to_square/8=0));
  room.board[to_square+1] := case when crowned then piece*2 else piece end;
  room.jumper := null;
  if jumped is not null and not crowned and exists(select 1 from public.checkers_moves(room.board,room.turn,to_square)) then
    room.jumper := to_square;
  else
    room.turn := case when room.turn='black' then 'red' else 'black' end;
    if not exists(select 1 from public.checkers_moves(room.board,room.turn,null)) then
      room.status := 'finished'; room.winner := mover;
    end if;
  end if;
  update public.checkers_rooms set board=room.board,turn=room.turn,jumper=room.jumper,
    revision=room.revision+1,status=room.status,winner=room.winner where code=room.code returning * into room;
  if room.status='finished' then
    insert into public.game_results(id,user_id,game_id,outcome,mode) values
      (gen_random_uuid(),room.host_id,'checkers',case when room.winner='black' then 'win' else 'loss' end,'online'),
      (gen_random_uuid(),room.guest_id,'checkers',case when room.winner='red' then 'win' else 'loss' end,'online');
  end if;
  return to_jsonb(room);
end;
$$;
revoke all on function public.create_checkers_room() from public,anon,authenticated;
revoke all on function public.join_checkers_room(text) from public,anon,authenticated;
revoke all on function public.play_checkers_move(text,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.create_checkers_room() to authenticated;
grant execute on function public.join_checkers_room(text) to authenticated;
grant execute on function public.play_checkers_move(text,integer,integer,integer) to authenticated;

commit;
