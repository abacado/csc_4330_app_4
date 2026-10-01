-- Run after setup.sql against an isolated test database; everything rolls back.
-- The server only checks room membership/turn order for chess (full rule
-- legality lives client-side in the shared Dart engine), so these fens are
-- illustrative placeholders, not legally-verified positions.
begin;
insert into auth.users(id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333');
set local role authenticated;

do $$
declare
  room jsonb;
  code text;
  total integer;
  rejected boolean;
  fen_start text := 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  fen_after_white text := 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
  fen_after_black text := 'rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  room := public.create_chess_room();
  code := room->>'code';
  if room->>'status' <> 'waiting' then raise exception 'New room must wait'; end if;
  if room->>'fen' <> fen_start then raise exception 'New room must start at the standard position'; end if;
  rejected := false;
  begin perform public.play_chess_move(code, fen_after_white, 'playing', null); exception when others then rejected := true; end;
  if not rejected then raise exception 'Cannot move before guest joins'; end if;

  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  select count(*) into total from public.chess_rooms;
  if total <> 0 then raise exception 'Outsider could read room'; end if;
  room := public.join_chess_room(lower(code));
  if room->>'status' <> 'playing' then raise exception 'Joined room must start'; end if;
  rejected := false;
  begin perform public.play_chess_move(code, fen_after_black, 'playing', null); exception when others then rejected := true; end;
  if not rejected then raise exception 'Black cannot move before White'; end if;

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
  rejected := false;
  begin perform public.join_chess_room(code); exception when others then rejected := true; end;
  if not rejected then raise exception 'Third player joined full room'; end if;
  rejected := false;
  begin perform public.play_chess_move(code, fen_after_white, 'playing', null); exception when others then rejected := true; end;
  if not rejected then raise exception 'Outsider played move'; end if;

  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  rejected := false;
  begin update public.chess_rooms set winner = 'white'; exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Client directly modified chess_rooms'; end if;
  rejected := false;
  begin
    insert into public.game_results values(gen_random_uuid(), auth.uid(), 'chess', 'win', 'online', now());
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Client forged online result'; end if;
  rejected := false;
  begin perform public.play_chess_move(code, fen_start, 'playing', null); exception when others then rejected := true; end;
  if not rejected then raise exception 'No-op move accepted'; end if;
  room := public.play_chess_move(code, fen_after_white, 'playing', null);
  if room->>'fen' <> fen_after_white then raise exception 'White move not stored'; end if;
  rejected := false;
  begin perform public.play_chess_move(code, fen_after_black, 'playing', null); exception when others then rejected := true; end;
  if not rejected then raise exception 'White cannot move twice in a row'; end if;

  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  room := public.play_chess_move(code, fen_after_black, 'finished', 'white');
  if room->>'winner' <> 'white' or room->>'status' <> 'finished' then raise exception 'Win not stored'; end if;
  select count(*) into total from public.game_results where outcome = 'win';
  if total <> 1 then raise exception 'Winner missing result'; end if;
  select count(*) into total from public.game_results where outcome = 'loss';
  if total <> 1 then raise exception 'Loser missing result'; end if;
  rejected := false;
  begin perform public.play_chess_move(code, fen_start, 'playing', null); exception when others then rejected := true; end;
  if not rejected then raise exception 'Finished match accepted move'; end if;
  raise notice 'PASS: chess room lifecycle, turn validation, outsider rejection, RLS, and results';
end;
$$;

reset role;
update public.chess_rooms set expires_at = now() - interval '1 second';
select set_config('test.expired_chess_code', (select code from public.chess_rooms limit 1), true);
set local role authenticated;
do $$
declare rejected boolean := false; total integer;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  select count(*) into total from public.chess_rooms;
  if total <> 0 then raise exception 'Expired chess rooms are readable'; end if;
  begin perform public.join_chess_room(current_setting('test.expired_chess_code')); exception when others then rejected := true; end;
  if not rejected then raise exception 'Expired chess room accepted join'; end if;
  raise notice 'PASS: expired chess rooms reject reads and joins';
end;
$$;
rollback;
