create or replace function make_multipolygon(
  rel_id bigint,
  src_id bigint[],
  src_geom geometry[])
returns geometry
as $$
declare
  todo		geometry[];
  done		geometry[];
  cur		geometry;
  cur1		geometry;
begin
  done:=Array[]::geometry[];

  -- empty array
  if src_geom is null or array_lower(src_geom, 1) is null then
    return null;
  end if;

  -- first find all closed geometries in array and push into done
  for i in array_lower(src_geom, 1)..array_upper(src_geom, 1) loop
    if src_geom[i] is null then
      raise notice 'MP %, way %: got null geometry', rel_id, src_id[i];
    elsif ST_NPoints(src_geom[i])>3 then
      if (ST_IsClosed(src_geom[i])) then
        done:=array_append(done, ST_MakePolygon(src_geom[i]));
      elsif not ST_IsValid(src_geom[i]) then
        raise notice 'MP %, way %: ignore invalid line', rel_id, src_id[i];
      else
        todo:=array_append(todo, src_geom[i]);
      end if;
    end if;
  end loop;

  -- merge all other geometries together
  begin
    cur:=ST_LineMerge(ST_GeomFromEWKT(ST_AsEWKT(ST_Collect(todo))));
  exception when others then
    raise notice 'MP %: error merging lines', rel_id;
    return null;
  end;

  -- if those build a closed geometry
  if ST_NumGeometries(cur) is null then
    if ST_IsClosed(cur) and ST_NPoints(cur)>3 then
      done:=array_append(done, ST_MakePolygon(cur));
    end if;
  else
  -- several geometries? check each of them ...
    for i in 1..ST_NumGeometries(cur) loop
      cur1:=ST_GeometryN(cur, i);
      if ST_IsClosed(cur1) and ST_NPoints(cur1)>3 then
	done:=array_append(done, ST_MakePolygon(cur1));
      end if;
    end loop;
  end if;

  -- if done is empty, return null
  if array_upper(done, 1) is null then
    return null;
  end if;

  -- we are done :)
  return ST_Collect(done);
end;
$$ language 'plpgsql';
