CREATE OR REPLACE FUNCTION assemble_multipolygon(bigint) RETURNS boolean AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  geom geometry;
  tags hstore;
  outer_tags hstore;
  outer_tags_relevant hstore;
  outer_equal boolean;
  tmp hstore;
  outer_members bigint[];
  members record;
  has_outer_tags boolean := false;
  non_relevant_tags text[] := '{source,source:ref,source_ref,note,comment,created_by,converted_by,fixme,FIXME,description,attribution}'::text[];
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
  tags:=(select relations.tags from relations where relations.id=id);

  -- check if type is correct
  if tags->'type' not in ('multipolygon', 'boundary') then
    raise notice 'relation % is neither multipolygon nor boundary!', id;
    return false;
  end if;

  -- generate multipolygon geometry
  geom:=build_multipolygon(
    (select array_agg((select linestring from ways where ways.id=outer_id)) from unnest(outer_members) outer_id),
    (select array_agg((select linestring from ways where ways.id=member_id)) from relation_members where relation_id=id and member_type='W' and member_role in ('inner', 'enclave') group by relation_id));

  -- of geometry is not valid, then return false
  if geom is null or ST_IsEmpty(geom) then
    return false;
  end if;

  -- check if all outer polygons are equal
  outer_equal=true;
  outer_tags=(select ways.tags from ways where ways.id=outer_members[1]);
  outer_tags_relevant := delete(outer_tags, non_relevant_tags);

  for i in 2..array_upper(outer_members, 1) loop
    if (select delete(ways.tags, non_relevant_tags) from ways where ways.id=outer_members[i])!=outer_tags_relevant then
      outer_equal=false;
    end if;
  end loop;

  -- if all outer polygons have equal tags (or only one outer polygon),
  -- check if multipolygon doesn't have (relevant) tags. Then we can import
  -- tags and delete outer way(s) from multipolygons

  -- delete not relevant tags ('created_by' has already been removed)
  tmp:=delete(delete(tags, non_relevant_tags), 'type');

  -- multipolygon has no relevant tags
  if array_upper(akeys(tmp), 1) is null then
    -- ... if outer polygons are not equal ignore multipolygons
    if not outer_equal then
      return false;
    end if;
    
    -- else use tags from outer polygon(s)
    tags:=tags_merge(tags, outer_tags);
    has_outer_tags := true;
  end if;

  -- raise notice 'assemble_multipolygon(%)', id;

  -- okay, insert
  insert into multipolygons
    values (
      id,
      tags,
      has_outer_tags,
      geom
    );

  return true;
END;
$$ LANGUAGE plpgsql;
