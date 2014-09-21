-- Merge an array of tags, e.g.
-- tags_merge({'a=>b, b=>c;d', 'c=>d, a=>f, b=>x'})
--   -> 'a=>b;f b=>c;d;x c=>d'
create or replace function tags_merge(hstore[])
returns hstore
as $$
declare
  src       alias for $1;
  collect   hstore;
  keys      text[];
  i         int;
  j         int;
  t         text;
begin
  if src is null then
    return null;
  end if;

  collect:=''::hstore;

  for i in array_lower(src, 1)..array_upper(src, 1) loop
    keys:=akeys(src[i]);
    if keys is not null and array_lower(keys, 1) is not null then
      for j in array_lower(keys, 1)..array_upper(keys, 1) loop
	t:=collect->keys[j];
	if(t is null) then
	  t:=src[i]->keys[j];
	else
	  t:=substring(t||';'||(src[i]->keys[j]), 0, 4096);
	end if;

	collect:=collect|| (keys[j]=>t);
      end loop;
    end if;
  end loop;

  keys:=akeys(collect);
  if array_lower(keys, 1) is null then
    return ''::hstore;
  end if;

  for j in array_lower(keys, 1)..array_upper(keys, 1) loop
      collect:=collect|| (keys[j]=>
        array_to_string(array_unique(split_semicolon(collect->keys[j])), ';'));
  end loop;

  return collect;
end;
$$ language 'plpgsql';

create or replace function tags_merge(hstore, hstore)
returns hstore
as $$
declare
  src1      alias for $1;
  src2      alias for $2;
begin
  return tags_merge(Array[src1, src2]);
end;
$$ language 'plpgsql';
