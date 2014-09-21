drop table if exists multipolygons;
create table multipolygons (
  id		bigint		not null,
  tags		hstore		null,
  primary key(id)
);
select AddGeometryColumn('multipolygons', 'geom', 4326, 'GEOMETRY', 2);

CREATE INDEX multipolygons_geom_tags on multipolygons using gist(geom, tags);
