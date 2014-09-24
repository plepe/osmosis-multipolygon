This database functions add a 'multipolygons' to an osmosis pgsnapshot database
schema.

INSTALL
=======
* First import your database using osmosis. Make sure that the 'ways' table has
  linestrings.
* Load the database functions:
```sh
psql -f assemble_multipolygon.sql
psql -f build_multipolygon.sql
psql -f make_multipolygon.sql
psql -f tags_merge.sql
psql -f update.sql
psql -f create.sql
psql -f assemble.sql
```
* The 'osmosisUpdate' database function will be overridden, so that changesets
  can be imported to the database and the multipolygons table will
  automatically be updated.

DATA
====
The 'multipolygons' table looks like this:

id | tags | has_outer_tags | geom
------------|---------------|--------------------------|-----------------
 75 | "name"=>"Untere Alte Donau", "type"=>"multipolygon", "water"=>"oxbow", "natural"=>"water" | f | 0103000020E61000000...
 11154 | "name"=>"Rossauer Kaserne", "type"=>"multipolygon", "source"=>"wien.gv.at", "alt_name"=>"Rudolfskaserne", "building"=>"yes", "military"=>"barracks", "wikipedia:de"=>"Rossauer Kaserne" | f | 0103000020E61000000...
 27945 | "name"=>"HLTW13", "type"=>"multipolygon", "amenity"=>"school", "building"=>"yes", "created_by"=>"Potlatch 0.10b" | t | 0103000020E61000000...

Table colums:

name | type | description
-----|------|-------------
id | *bigint* | ID of the relation which defines this multipolygon
tags | *hstore* | A hstore (a key-value datatype) containing all tags of the multipolygon, either of the relation itself or mixed with the tags of the outer polygon(s) (see has_outer_tags).
has_outer_tags | *boolean* | A boolean indicating whether the tags of the relation itself has been used (false) or if the tags of the outer polygon(s) has been mixed into it.
geom | *geometry* | The geometry of the object.

HISTORY
=======
These scripts are based on some OpenStreetBrowser code, which added
multipolygon support for the osmosis pgsimple database schema. See
https://github.com/plepe/OpenStreetBrowser-database for details.

It's actually pretty old code, which I'm not too proud of. But it does its job
and maybe it can help someone.
