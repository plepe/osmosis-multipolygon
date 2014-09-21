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

HISTORY
=======
These scripts are based on some OpenStreetBrowser code, which added
multipolygon support for the osmosis pgsimple database schema. See
https://github.com/plepe/OpenStreetBrowser-database for details.
