create or replace function make_multipolygon(geometry[])
returns geometry
as $$
declare
  src		alias for $1;
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
  if src is null or array_lower(src, 1) is null then
    return null;
  end if;

  -- first find all closed geometries in array and push into done
  for i in array_lower(src, 1)..array_upper(src, 1) loop
    if src[i] is null then
      -- raise notice 'got null geometry, index %', i;
    elsif not ST_IsValid(src[i]) then
      raise notice 'ignore invalid line %', i;
    elsif ST_IsClosed(src[i]) then
      if ST_NPoints(src[i])>3 then
        done:=array_append(done, ST_MakePolygon(src[i]));
      else
        raise notice 'ignore degenerated area %', i;
      end if;
    else
      todo:=array_append(todo, src[i]);
    end if;
  end loop;

  -- geometries in the todo list?
  if array_length(todo, 1) is not null then
    -- merge all other geometries together
    begin
      cur:=ST_LineMerge(ST_GeomFromEWKT(ST_AsEWKT(ST_Collect(todo))));
      exception when others then
        raise notice 'error merging lines';
        return null;
    end;
    -- check each geometry whether it is closed
    for i in 1..ST_NumGeometries(cur) loop
      cur1:=ST_GeometryN(cur, i);
      if ST_IsClosed(cur1) then
	if ST_NPoints(cur1)>3 then
	  done:=array_append(done, ST_MakePolygon(cur1));
        else
          raise notice 'ignore degenerated area';
        end if;
      end if;
    end loop;
  end if;

  -- we are done :)
  if array_length(done, 1) is not null then
    return ST_Collect(done);
  else
    return null;
  end if;
end;
$$ language 'plpgsql';
