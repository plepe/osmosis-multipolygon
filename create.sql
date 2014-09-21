-- point
drop table if exists osm_point;
create table osm_point (
  id		text		not null,
  tags		hstore		null,
  primary key(id)
);
select AddGeometryColumn('osm_point', 'way', 4326, 'POINT', 2);

-- ways -> osm_line and osm_polygon
drop table if exists osm_line;
create table osm_line (
  id		text		not null,
  tags		hstore		null,
  primary key(id)
);
select AddGeometryColumn('osm_line', 'way', 4326, 'LINESTRING', 2);

drop table if exists osm_polygon;
create table osm_polygon (
  id		text		not null,
  rel_id		text		null,
  tags		hstore		null,
  primary key(id)
);
select AddGeometryColumn('osm_polygon', 'way', 4326, 'GEOMETRY', 2);
alter table osm_polygon
  add column	member_ids		text[]		null,
  add column	member_roles		text[]		null;

-- rel
drop table if exists osm_rel;
create table osm_rel (
  id		text		not null,
  tags		hstore		null,
  primary key(id)
);
select AddGeometryColumn('osm_rel', 'way', 4326, 'GEOMETRY', 2);
alter table osm_rel
  add column	member_ids		text[]		null,
  add column	member_roles		text[]		null;

create table osm_template_with_type (
  id    text            not null,
  tags  hstore          default ''::hstore,
  way   geometry        not null,
  type  hstore          default ''::hstore
);

-- osm_all_* build the osm_all view
-- drop all views
drop view if exists osm_all;

drop view if exists osm_poipoly;
drop view if exists osm_allrel;
drop view if exists osm_linepoly;

drop view if exists osm_all_point;
drop view if exists osm_all_line;
drop view if exists osm_all_polygon;
drop view if exists osm_all_rel;

-- osm_all_point
create view osm_all_point as (
  select
    "id",
    'type=>node, form=>point'::hstore as "type",
    "tags",
    "way" as "way",
    "way" as "way_point",
    ST_MakeLine("way", "way") as "way_line",
    ST_MakePolygon(ST_MakeLine(Array["way", "way", "way", "way"])) as "way_polygon"
  from osm_point
);

-- osm_all_line
create view osm_all_line as (
  select
    "id",
    'type=>way, form=>line'::hstore as "type",
    "tags",
    "way" as "way",
    ST_Line_Interpolate_Point("way", 0.5) as "way_point",
    "way" as "way_line",
    null::geometry as "way_polygon"
  from osm_line
);

-- osm_all_polygon
create view osm_all_polygon as (
  select
    "id",
    (CASE
      WHEN rel_id is not null THEN 'type=>rel, form=>polygon'::hstore 
      ELSE 'type=>way, form=>polygon'::hstore 
    END) as "type",
    "tags",
    "way" as "way",
    ST_Centroid("way") as "way_point",
    ST_Boundary("way") as "way_line",
    "way" as "way_polygon"
  from osm_polygon
);

-- osm_all_rel
create view osm_all_rel as (
  select
    "id",
    'type=>rel, form=>special'::hstore as "type",
    "tags",
    "way" as "way",
    ST_CollectionExtract("way", 1) as "way_point",
    ST_CollectionExtract("way", 2) as "way_line",
    ST_CollectionExtract("way", 3) as "way_polygon"
  from osm_rel
);

-- osm_all
create view osm_all as (
  select * from osm_all_point
  union all
  select * from osm_all_line
  union all
  select * from osm_all_polygon
  union all
  select * from osm_all_rel
);

-- osm_poipoly
create view osm_poipoly as (
  select * from osm_all_point
  union all
  select * from osm_all_polygon
);

-- osm_linepoly
create view osm_linepoly as (
  select * from osm_all_line
  union all
  select * from osm_all_polygon
);

-- osm_all_rel
create view osm_allrel as (
  select * from osm_all_polygon
  union all
  select * from osm_all_rel
);

-- osm_rel_members
drop view if exists osm_rel_members;
create view osm_rel_members as (
  select
    osm_rel.id,
    osm_line.id as member_id,
    osm_rel.member_ids as rel_member_ids,
    member_role,
    osm_rel.tags as tags,
    osm_line.tags as member_tags,
    osm_rel.way as osm_way,
    osm_line.way as member_way
  from (
    select
      osm_rel.*,
      unnest(member_ids) as member_id,
      unnest(member_roles) as member_role
    from osm_rel) osm_rel
    join osm_line
      on osm_line.id=osm_rel.member_id
);
