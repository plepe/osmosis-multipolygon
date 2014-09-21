drop table if exists multipolygons;
create table multipolygons (
  id		bigint		not null,
  tags		hstore		null,
  primary key(id)
);
select AddGeometryColumn('multipolygons', 'way', 4326, 'GEOMETRY', 2);
