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
  -- in contrast to simply calling ST_Collect/ST_Union, 
  -- this function generates closed geometries only (otherwise null is returned)
  todo:=Array[]::geometry[];
  done:=Array[]::geometry[];

  -- empty array
  if src_geom is null or array_lower(src_geom, 1) is null then
    return null;
  end if;

  -- first find all closed geometries in array and push into done
  for i in array_lower(src_geom, 1)..array_upper(src_geom, 1) loop
    if src_geom[i] is null then
      -- raise notice 'got null geometry, index %', i;
    elsif ST_NPoints(src_geom[i])<2 or not ST_IsValid(src_geom[i]) then
      raise notice 'MP %, way %: ignore invalid line', rel_id, src_id[i];
    elsif ST_IsClosed(src_geom[i]) then
      if ST_NPoints(src_geom[i])>3 then
        done:=array_append(done, ST_MakePolygon(src_geom[i]));
      else
        raise notice 'MP %, way %: ignore degenerated area', rel_id, src_id[i];
      end if;
    else
      todo:=array_append(todo, src_geom[i]);
    end if;
  end loop;

  -- geometries in the todo list?
  if array_length(todo, 1) is not null then
    -- merge all other geometries together
    begin
      cur:=ST_LineMerge(ST_Collect(todo));
      exception when others then
        raise notice 'MP %: error merging lines', rel_id;
        return null;
    end;

    if ST_NumGeometries(cur) is null then
      -- cur might be a single linestring -> check if it is a valid polygon
      if ST_IsClosed(cur) and ST_NPoints(cur) > 3 then
        done:=array_append(done, ST_MakePolygon(cur));
      else
        raise notice 'MP %: merging remaining lines -> not closed', rel_id;
      end if;

    else
      -- check each geometry whether it is closed
      for i in 1..ST_NumGeometries(cur) loop
        cur1:=ST_GeometryN(cur, i);
        if ST_IsClosed(cur1) then
          if ST_NPoints(cur1)>3 then
            done:=array_append(done, ST_MakePolygon(cur1));
          else
            raise notice 'MP %: ignore degenerated area', rel_id;
          end if;
        end if;
      end loop;
    end if;
  end if;

  -- we are done :)
  if array_length(done, 1) is not null then
    return ST_Collect(done);
  else
    return null;
  end if;
end;
$$ language 'plpgsql';
