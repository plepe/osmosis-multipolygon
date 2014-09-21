CREATE OR REPLACE FUNCTION osmosisUpdate() RETURNS void AS $$
DECLARE
  num_rows  int;
BEGIN
  raise notice 'called osmosisUpdate()';

  ---- simplify table actions ----
  -- mark all ways as 'n' which were implicitly changed (because nodes of the
  -- way were changed)
  insert into actions
   (select
      'W' as "data_type",
      'n' as "action",
      way_nodes.way_id as "id"
    from
      actions node_actions
      left join way_nodes
        on way_nodes.node_id=node_actions.id
      left join actions way_actions
        on way_nodes.way_id=way_actions.id and way_actions.data_type='W'
    where
      node_actions.data_type='N' and
      way_nodes.way_id is not null and
      way_actions.id is null
    group by
      way_nodes.way_id);

  -- mark all relations as 'n' which were implicitly changed (because nodes of
  -- the relation were changed)
  insert into actions
   (select
      'R' as "data_type",
      'n' as "action",
      relation_members.relation_id as "id"
    from
      actions node_actions
      left join relation_members
        on relation_members.member_id=node_actions.id and
	  relation_members.member_type='N'
      left join actions rel_actions
        on relation_members.relation_id=rel_actions.id and
	  rel_actions.data_type='R'
    where
      node_actions.data_type='N' and
      relation_members.relation_id is not null and
      rel_actions.id is null
    group by
      relation_members.relation_id);

  -- mark all relations as 'w' which were implicitly changed (because ways of
  -- the relation were changed)
  insert into actions
   (select
      'R' as "data_type",
      'w' as "action",
      relation_members.relation_id as "id"
    from
      actions way_actions
      left join relation_members
        on relation_members.member_id=way_actions.id and
	  relation_members.member_type='W'
      left join actions rel_actions
        on relation_members.relation_id=rel_actions.id and
	  rel_actions.data_type='R'
    where
      way_actions.data_type='W' and
      relation_members.relation_id is not null and
      rel_actions.id is null
    group by
      relation_members.relation_id);

  -- we should also mark relations where relations were changed, but currently
  -- we don't do recursive relations
  raise notice 'calculated implicit changes';

  raise notice E'statistics:\n%', (select array_to_string(array_agg(stat.text), E'\n') from (select data_type || E'\t' || action || E'\t' || count(id) as text from actions group by data_type, action order by data_type, action) stat);

  delete from multipolygons using
    (select id from actions where data_type='R') actions
  where multipolygons.id=actions.id;

  GET DIAGNOSTICS num_rows = ROW_COUNT;
  raise notice 'deleted from multipolygons (%)', num_rows;

  -- insert changed/created multipolygons
  select count(*) into num_rows from
      (select actions.id from actions
	join relations on
	  relations.id=actions.id
	where
	  data_type='R' and
	  action not in ('D') and
	  (relations.tags @> 'type=>multipolygon' or relations.tags @> 'type=>boundary')) actions
      where
	assemble_multipolygon(actions.id);

  raise notice 'inserted to multipolygons (%)', num_rows;

  raise notice 'finished osmosisUpdate()';
END;
$$ LANGUAGE plpgsql;
