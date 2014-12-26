v0.3    release 2014-12-26
--------------------------
* added a 'hide_outer_ways' column. an array of bigint with the IDs of all (outer) ways which should be hidden from rendering (because the tags were taken from these ways or the tags of the outer ways and the relation itself are equal). null, if no ways should be hidden.
* Bugfixes; thanks to Peter Kunath for his contribution

v0.2    release 2014-09-24
--------------------------
* added a 'has_outer_tags' column. true if tags of outer ways has been mixed into the tags of the multipolygon.
* extend list of non-relevant tags; also use non-relevant tag check on outer ways.

v0.1    release 2014-09-21
--------------------------
Based on old OpenStreetBrowser code, stripped to multipolygons and adapted to osmosis pgsnapshot and Postgis 2.0.
