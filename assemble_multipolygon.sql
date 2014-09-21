CREATE OR REPLACE FUNCTION way_get_geom(bigint) RETURNS geometry AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  ret text;
BEGIN
  ret:=(select (CASE WHEN count(*)>1 THEN cast(MakeLine(geom) as text) ELSE null::text END) from (select * from way_nodes join nodes on way_nodes.node_id=nodes.id where way_nodes.way_id=id order by sequence_id) c group by way_id);
  -- perform cache_insert('W'||way_id, 'geom', ret);

  return ret;
END;
$$ LANGUAGE plpgsql volatile;

CREATE OR REPLACE FUNCTION rel_get_geom(bigint, int) RETURNS geometry AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  rec alias for $2;
  geom_arr_nodes geometry[];
  geom_arr_ways  geometry[];
  geom_arr_ways1 geometry[];
  geom_nodes     geometry;
  geom_ways      geometry;
  o		 int;
  -- geom_rels  geometry[];
BEGIN
  --if rec>0 then
  --  return null;
  --end if;

  geom_arr_nodes:=(select to_array(geom) from nodes where nodes.id in (select member_id from relation_members where relation_id=id and member_type='N'));

  geom_arr_ways:=(select to_array(geom) as geom from (select
            coalesce(
              (select distinct way from osm_line where osm_line.id='W'||member_id),
              (select distinct way from osm_polygon where osm_polygon.id='W'||member_id),
	      way_get_geom(member_id)
	    ) as geom from (select member_id from relation_members where relation_id=id and member_type='W') x) x1 where x1.geom is not null);
  --geom_rels:=(select ST_Collect(rel_get_geom(relations.id, rec+1)) from relations where relations.id in (select member_id from relation_members where relation_id=id and member_type='R'));

  if array_upper(geom_arr_nodes, 1) is not null then
    geom_nodes:=ST_Collect(geom_arr_nodes);
  end if;

  geom_ways:=null::geometry;
  if array_lower(geom_arr_ways, 1) is not null then
    geom_ways:=ST_Collect(geom_arr_ways);
  end if;

  -- raise notice 'rel_get_geom(%, %)', id, rec;

  return ST_Collect(geom_nodes, geom_ways);
END;
$$ LANGUAGE plpgsql stable;

CREATE OR REPLACE FUNCTION node_assemble_tags(bigint) RETURNS hstore AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
BEGIN
  -- raise notice 'node_assemble_tags(%)', id;
  return
    (select
	array_to_hstore(to_textarray(k), to_textarray(v))
      from node_tags
      where id=node_id and k!='created_by'
      group by node_id);
END;
$$ LANGUAGE plpgsql stable;

CREATE OR REPLACE FUNCTION way_assemble_tags(bigint) RETURNS hstore AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
BEGIN
  -- raise notice 'way_assemble_tags(%)', id;
  return
    (select
	array_to_hstore(to_textarray(k), to_textarray(v))
      from way_tags
      where id=way_id and k!='created_by'
      group by way_id);
END;
$$ LANGUAGE plpgsql stable;

CREATE OR REPLACE FUNCTION rel_assemble_tags(bigint) RETURNS hstore AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
BEGIN
  -- raise notice 'rel_assemble_tags(%)', id;
  return
    (select
	array_to_hstore(to_textarray(k), to_textarray(v))
      from relation_tags
      where id=relation_id and k!='created_by'
      group by relation_id);
END;
$$ LANGUAGE plpgsql stable;

CREATE OR REPLACE FUNCTION assemble_point(bigint) RETURNS boolean AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  geom geometry;
  tags hstore;
BEGIN
  -- get tags
  tags:=node_assemble_tags(id);

  -- if no tags, return
  if array_upper(akeys(tags), 1) is null then
    return false;
  end if;

  -- get geometry
  geom:=(select nodes.geom from nodes where nodes.id=id);

  -- ignore poles
  if abs(Y(geom))=90 then
    return false;
  end if;

  -- raise notice 'assemble_point(%)', id;

  -- okay, insert
  insert into osm_point
    values (
      'N'||id,
      tags,
      geom
    );

  return true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION assemble_way(bigint) RETURNS boolean AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  geom geometry;
  tags hstore;
BEGIN
  -- get tags
  tags:=way_assemble_tags(id);

  -- if no tags, return
  if array_upper(akeys(tags), 1) is null then
    return false;
  end if;

  -- get geometry
  geom:=way_get_geom(id);

  if geom is null or (not ST_IsValid(geom)) then
    -- raise notice 'assemble_way(%) -> not valid', id;

    return false;
  elsif (IsClosed(geom)) and NPoints(geom)>3 then
    -- raise notice 'assemble_way(%) -> polygon', id;

    insert into osm_polygon
      values (
	'W'||id,
	null,
	tags,
	ST_MakePolygon(geom)
      );
  else
    -- raise notice 'assemble_way(%) -> line', id;

    insert into osm_line
      values (
	'W'||id,
	tags,
	geom
      );
  end if;

  return true;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION assemble_rel(bigint) RETURNS boolean AS $$
#variable_conflict use_variable
DECLARE
  id alias for $1;
  geom geometry;
  geom_nodes geometry;
  geom_ways  geometry;
  tags hstore;
  outer_members bigint[];
  members record;
BEGIN
  -- get tags
  tags:=rel_assemble_tags(id);

  -- if no tags, return
  if array_upper(akeys(tags), 1) is null then
    return false;
  end if;

  -- don't assemble multipolygons ...
  if tags->'type' in ('multipolygon', 'boundary') then
    return false;
  end if;

  -- get geometry
  geom:=rel_get_geom(id, 0);

  -- get members
  select to_textarray(member_type || member_id) as ids, to_textarray(member_role) as roles into members from 
  (select * from relation_members where relation_id=id order by sequence_id) rm
  group by relation_id;

  -- raise notice 'assemble_rel(%)', id;

  -- okay, insert
  insert into osm_rel
    values (
      'R'||id,
      tags,
      geom,
      members.ids,
      members.roles
    );

  return true;
END;
$$ LANGUAGE plpgsql;

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
  outer_members:=(select to_intarray(member_id) from relation_members where relation_id=id and member_type='W' and member_role in ('outer', 'exclave') group by relation_id);

  -- no outer members? use all members without role as outer members
  if array_upper(outer_members, 1) is null then
    outer_members:=(select to_intarray(member_id) from relation_members where relation_id=id and member_type='W' and member_role='' group by relation_id);
  end if;

  -- still no outer members? -> ignore
  if array_upper(outer_members, 1) is null then
    return false;
  end if;

  -- tags
  tags:=rel_assemble_tags(id);

  -- check if type is correct
  if tags->'type' not in ('multipolygon', 'boundary') then
    raise notice 'relation % is neither multipolygon nor boundary!', id;
    return false;
  end if;

  -- generate multipolygon geometry
  geom:=build_multipolygon(
    (select to_array(way_get_geom(outer_members[i])) from generate_series(1, array_upper(outer_members, 1)) i),
    (select to_array(way_get_geom(member_id)) from relation_members where relation_id=id and member_type='W' and member_role in ('inner', 'enclave') group by relation_id));

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
  -- tags and delete outer way(s) from osm_polygon

  -- delete not relevant tags ('created_by' has already been removed)
  tmp:=delete(tags, Array['type', 'source']);

  -- multipolygon has no relevant tags
  if array_upper(akeys(tmp), 1) is null then
    -- ... if outer polygons are not equal ignore multipolygons
    if not outer_equal then
      return false;
    end if;
    
    -- else use tags from outer polygon(s) and delete from osm_polygon
    tags:=tags_merge(tags, way_assemble_tags(outer_members[1]));
    for i in 1..array_upper(outer_members, 1) loop
      delete from osm_polygon where osm_polygon.id='W'||(outer_members[i]);
    end loop;
  end if;

  -- if no tags (beside 'type'), return
  if array_upper(akeys(delete(tags, 'type')), 1)=0 then
    return false;
  end if;

  -- raise notice 'assemble_multipolygon(%)', id;

  -- get members
  select to_textarray(member_type || member_id) as ids, to_textarray(member_role) as roles into members from relation_members where relation_id=id group by relation_id;

  -- okay, insert
  insert into osm_polygon
    values (
      'R'||id,
      'R'||id,
      tags,
      geom,
      members.ids,
      members.roles
    );

  return true;
END;
$$ LANGUAGE plpgsql;
