begin;
insert into auth.users(id) values
('11111111-1111-1111-1111-111111111111'),
('22222222-2222-2222-2222-222222222222'),
('33333333-3333-3333-3333-333333333333');
-- Fixtures exercise forced jumps, promotion and blocked opponents.
do $$
declare b integer[] := array_fill(0,array[64]);
begin
 b[18] := 1; b[27] := -1; b[45] := -1; b[2] := 1;
 insert into public.checkers_rooms(code,host_id,guest_id,board,status) values
 ('AAA001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',b,'playing');
 b := array_fill(0,array[64]); b[43] := 1; b[52] := -1; b[54] := -1;
 insert into public.checkers_rooms(code,host_id,guest_id,board,status) values
 ('AAA002','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',b,'playing');
 b := array_fill(0,array[64]); b[36] := 2; b[2] := -1;
 insert into public.checkers_rooms(code,host_id,guest_id,board,status) values
 ('AAA003','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',b,'playing');
 insert into public.checkers_rooms(code,host_id,board,expires_at) values
 ('AAA004','11111111-1111-1111-1111-111111111111',b,now()-interval '1 minute');
end;
$$;
set local role authenticated;
do $$
declare room jsonb; v_code text; rejected boolean; total integer;
begin
 perform set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
 room := public.create_checkers_room(); v_code := room->>'code';
 if room->>'status' <> 'waiting' or jsonb_array_length(room->'board') <> 64 then raise exception 'Bad initial room'; end if;
 select count(*) into total from jsonb_array_elements(room->'board') p where p='1'::jsonb;
 if total <> 12 then raise exception 'Expected 12 black pieces'; end if;
 select count(*) into total from jsonb_array_elements(room->'board') p where p='-1'::jsonb;
 if total <> 12 then raise exception 'Expected 12 red pieces'; end if;
 rejected:=false; begin perform public.play_checkers_move(v_code,17,24,0); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Moved before join'; end if;
 perform set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
 if exists(select 1 from public.checkers_rooms r where r.code=v_code) then raise exception 'Outsider read room'; end if;
 room:=public.join_checkers_room(lower(v_code));
 if room->>'status'<>'playing' then raise exception 'Join failed'; end if;
 rejected:=false; begin perform public.play_checkers_move(v_code,40,33,0); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Red moved first'; end if;
 perform set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
 rejected:=false; begin perform public.join_checkers_room(v_code); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Third player joined'; end if;
 rejected:=false; begin perform public.play_checkers_move(v_code,17,24,0); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Outsider moved'; end if;
 perform set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
 rejected:=false; begin update public.checkers_rooms set winner='black'; exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'Direct update allowed'; end if;
 rejected:=false; begin perform public.play_checkers_move(v_code,17,40,0); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Illegal move accepted'; end if;
 rejected:=false; begin perform public.play_checkers_move(v_code,17,24,99); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Stale revision accepted'; end if;
 room:=public.play_checkers_move(v_code,17,24,0);
 if room->>'turn'<>'red' or room->>'revision'<>'1' or room->'board'->>24<>'1' then raise exception 'Simple move failed'; end if;
 perform set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
 room:=public.play_checkers_move(v_code,40,33,1);
 if room->>'turn'<>'black' then raise exception 'Red move failed'; end if;
 perform set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
 rejected:=false; begin perform public.play_checkers_move('AAA001',1,8,0); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Mandatory jump ignored'; end if;
 room:=public.play_checkers_move('AAA001',17,35,0);
 if room->>'jumper'<>'35' or room->>'turn'<>'black' then raise exception 'Multiple jump lost turn'; end if;
 rejected:=false; begin perform public.play_checkers_move('AAA001',1,8,1); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Changed piece during jump'; end if;
 rejected:=false; begin perform public.play_checkers_move('AAA001',35,53,0); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Old multiple-jump request accepted'; end if;
 room:=public.play_checkers_move('AAA001',35,53,1);
 if room->>'status'<>'finished' or room->>'winner'<>'black' then raise exception 'Win not detected'; end if;
 select count(*) into total from public.game_results where game_id='checkers' and outcome='win';
 if total<>1 then raise exception 'Host win not recorded'; end if;
 rejected:=false; begin perform public.play_checkers_move('AAA001',53,60,2); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Finished game accepts moves'; end if;
 perform set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
 select count(*) into total from public.game_results where game_id='checkers';
 if total<>1 or not exists(select 1 from public.game_results where game_id='checkers' and outcome='loss') then raise exception 'Guest result visibility incorrect'; end if;
 perform set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
 room:=public.play_checkers_move('AAA002',42,60,0);
 if room->'board'->>60<>'2' or room->>'turn'<>'red' or room->>'jumper' is not null then raise exception 'Crowning must end turn'; end if;
 room:=public.play_checkers_move('AAA003',35,26,0);
 if room->>'status'<>'finished' then raise exception 'Blocked opponent should lose'; end if;
 rejected:=false; begin perform public.join_checkers_room('AAA004'); exception when others then rejected:=true; end;
 if not rejected then raise exception 'Expired room join allowed'; end if;
 if exists(select 1 from public.checkers_rooms where checkers_rooms.code='AAA004') then raise exception 'Expired room visible'; end if;
 raise notice 'PASS: Checkers rooms, rules, multi-jumps, revision checks, results and RLS';
end;
$$;
rollback;
