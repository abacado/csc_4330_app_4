-- Run after setup.sql against an isolated test database; everything rolls back.
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
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  room := public.create_room();
  code := room->>'code';
  if room->>'status' <> 'waiting' then raise exception 'New room must wait'; end if;
  rejected := false;
  begin perform public.play_move(code, 0); exception when others then rejected := true; end;
  if not rejected then raise exception 'Cannot move before guest joins'; end if;

  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  select count(*) into total from public.rooms;
  if total <> 0 then raise exception 'Outsider could read room'; end if;
  room := public.join_room(lower(code));
  if room->>'status' <> 'playing' then raise exception 'Joined room must start'; end if;
  rejected := false;
  begin perform public.play_move(code, 4); exception when others then rejected := true; end;
  if not rejected then raise exception 'O cannot move first'; end if;

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
  rejected := false;
  begin perform public.join_room(code); exception when others then rejected := true; end;
  if not rejected then raise exception 'Third player joined full room'; end if;
  rejected := false;
  begin perform public.play_move(code, 0); exception when others then rejected := true; end;
  if not rejected then raise exception 'Outsider played move'; end if;

  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  rejected := false;
  begin update public.rooms set winner = 'X'; exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Client directly modified rooms'; end if;
  rejected := false;
  begin
    insert into public.game_results values(gen_random_uuid(), auth.uid(), 'tic_tac_toe', 'win', 'online', now());
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Client forged online result'; end if;
  rejected := false;
  begin perform public.play_move(code, 9); exception when others then rejected := true; end;
  if not rejected then raise exception 'Out-of-range move accepted'; end if;
  perform public.play_move(code, 0);
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  rejected := false;
  begin perform public.play_move(code, 0); exception when others then rejected := true; end;
  if not rejected then raise exception 'Occupied cell accepted'; end if;
  perform public.play_move(code, 3);
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  perform public.play_move(code, 1);
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform public.play_move(code, 4);
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  room := public.play_move(code, 2);
  if room->>'winner' <> 'X' or room->>'status' <> 'finished' then raise exception 'Win not detected'; end if;
  select count(*) into total from public.game_results where outcome = 'win';
  if total <> 1 then raise exception 'Winner missing result'; end if;
  select count(*) into total from public.game_results;
  if total <> 1 then raise exception 'Player can read another result'; end if;
  rejected := false;
  begin perform public.play_move(code, 8); exception when others then rejected := true; end;
  if not rejected then raise exception 'Finished match accepted move'; end if;
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  select count(*) into total from public.game_results where outcome = 'loss';
  if total <> 1 then raise exception 'Loser missing result'; end if;
  raise notice 'PASS: room lifecycle, turn validation, occupancy, bounds, outsider rejection, RLS, and results';
end;
$$;

do $$
declare
  room jsonb;
  code text;
  moves integer[] := array[0,1,2,4,3,5,7,6,8];
  player text;
  total integer;
  rejected boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  room := public.create_room();
  code := room->>'code';
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform public.join_room(code);
  for i in 1..9 loop
    player := case when i % 2 = 1 then '11111111-1111-1111-1111-111111111111'
      else '22222222-2222-2222-2222-222222222222' end;
    perform set_config('request.jwt.claim.sub', player, true);
    room := public.play_move(code, moves[i]);
  end loop;
  if room->>'status' <> 'finished' or room->>'winner' is not null then raise exception 'Draw not detected'; end if;
  select count(*) into total from public.game_results where outcome = 'draw';
  if total <> 1 then raise exception 'Host missing draw result'; end if;
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  select count(*) into total from public.game_results where outcome = 'draw';
  if total <> 1 then raise exception 'Guest missing draw result'; end if;
  begin
    insert into public.game_results values(gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'memory', 'completed', 'solo', now());
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Guest forged another players result'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  rejected := false;
  begin perform public.create_room(); exception when others then rejected := true; end;
  if not rejected then raise exception 'Unauthenticated room creation accepted'; end if;
  raise notice 'PASS: draws, guest result ownership, missing identity rejection';
end;
$$;

reset role;
update public.rooms set expires_at = now() - interval '1 second';
select set_config('test.expired_code', (select code from public.rooms limit 1), true);
set local role authenticated;
do $$
declare rejected boolean := false; total integer;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  select count(*) into total from public.rooms;
  if total <> 0 then raise exception 'Expired rooms are readable'; end if;
  begin perform public.join_room(current_setting('test.expired_code')); exception when others then rejected := true; end;
  if not rejected then raise exception 'Expired room accepted join'; end if;
  raise notice 'PASS: expired rooms reject reads and joins';
end;
$$;
rollback;
