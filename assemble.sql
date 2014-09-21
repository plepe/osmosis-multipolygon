-- node
select assemble_point(id) from nodes;

create index osm_point_tags on osm_point using gin(tags);
create index osm_point_way  on osm_point using gist(way);
create index osm_point_way_tags on osm_point using gist(way, tags);

-- way -> osm_line and osm_polygon
select assemble_way(id) from ways;

create index osm_line_tags on osm_line using gin(tags);
create index osm_line_way  on osm_line using gist(way);
create index osm_line_way_tags on osm_line using gist(way, tags);

-- rel -> osm_rel
select assemble_rel(id) from relations;

create index osm_rel_tags on osm_rel using gin(tags);
create index osm_rel_way  on osm_rel using gist(way);
create index osm_rel_way_tags on osm_rel using gist(way, tags);
create index osm_rel_members_idx on osm_rel using gin(member_ids);

-- rel -> osm_polygon
select
  assemble_multipolygon(relation_id)
from relation_tags
where k='type' and v in ('multipolygon', 'boundary');

create index osm_polygon_rel_id on osm_polygon(rel_id);
create index osm_polygon_tags on osm_polygon using gin(tags);
create index osm_polygon_way  on osm_polygon using gist(way);
create index osm_polygon_way_tags on osm_polygon using gist(way, tags);
create index osm_polygon_members_idx on osm_polygon using gin(member_ids);
