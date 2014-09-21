CREATE OR REPLACE FUNCTION assemble_multipolygon(bigint) RETURNS boolean AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  geom geometry;
  tags hstore;
  outer_tags hstore;
  outer_equal boolean;
  tmp hstore;
  outer_members bigint[];
  members record;
BEGIN

  -- get list of outer members
  outer_members:=(select array_agg(member_id) from relation_members where relation_id=id and member_type='W' and member_role in ('outer', 'exclave') group by relation_id);

  -- no outer members? use all members without role as outer members
  if array_upper(outer_members, 1) is null then
    outer_members:=(select array_agg(member_id) from relation_members where relation_id=id and member_type='W' and member_role='' group by relation_id);
  end if;

  -- still no outer members? -> ignore
  if array_upper(outer_members, 1) is null then
    return false;
  end if;

  -- tags
  tags:=(select tags from relations where relations.id=id);

  -- check if type is correct
  if tags->'type' not in ('multipolygon', 'boundary') then
    raise notice 'relation % is neither multipolygon nor boundary!', id;
    return false;
  end if;

  -- generate multipolygon geometry
  geom:=build_multipolygon(
    (select array_agg((select linestring from ways where ways.id=outer_members[i])) from generate_series(1, array_upper(outer_members, 1)) i),
    (select array_agg((select linestring from ways where ways.id=member_id)) from relation_members where relation_id=id and member_type='W' and member_role in ('inner', 'enclave') group by relation_id));

  -- of geometry is not valid, then return false
  if geom is null or ST_IsEmpty(geom) then
    return false;
  end if;

  -- check if all outer polygons are equal
  outer_equal=true;
  outer_tags=way_assemble_tags(outer_members[1]);
  for i in 2..array_upper(outer_members, 1) loop
    if way_assemble_tags(outer_members[i])!=outer_tags then
      outer_equal=false;
    end if;
  end loop;

  -- if all outer polygons have equal tags (or only one outer polygon),
  -- check if multipolygon doesn't have (relevant) tags. Then we can import
  -- tags and delete outer way(s) from multipolygons

  -- delete not relevant tags ('created_by' has already been removed)
  tmp:=delete(tags, Array['type', 'source']);

  -- multipolygon has no relevant tags
  if array_upper(akeys(tmp), 1) is null then
    -- ... if outer polygons are not equal ignore multipolygons
    if not outer_equal then
      return false;
    end if;
    
    -- else use tags from outer polygon(s) and delete from multipolygons
    tags:=tags_merge(tags, way_assemble_tags(outer_members[1]));
    for i in 1..array_upper(outer_members, 1) loop
      delete from multipolygons where multipolygons.id='W'||(outer_members[i]);
    end loop;
  end if;

  -- if no tags (beside 'type'), return
  if array_upper(akeys(delete(tags, 'type')), 1)=0 then
    return false;
  end if;

  -- raise notice 'assemble_multipolygon(%)', id;

  -- get members
  select array_agg(member_type || member_id) as ids, array_agg(member_role) as roles into members from relation_members where relation_id=id group by relation_id;

  -- okay, insert
  insert into multipolygons
    values (
      id,
      tags,
      geom
    );

  return true;
END;
$$ LANGUAGE plpgsql;
