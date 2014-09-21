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

create or replace function split_semicolon(text)
  returns text[]
  as $$
declare
  str alias for $1;
begin
  return string_to_array(str, ';');
end;
$$ language 'plpgsql' immutable;
CREATE OR REPLACE FUNCTION array_unique(text[])
RETURNS text[]
AS $$
declare
-- src   int[]=array_sort($1);
src   alias for $1;
src_i int:=1;
ret   text[];
ret_i int:=1;
found bool;
begin
  while src_i<=array_upper(src, 1) loop
    ret_i:=1;
    found:=false;

    if src[src_i] is null then
      found:=true;
    end if;

    while (ret_i<=array_upper(ret, 1)) and not found loop
      if src[src_i]=ret[ret_i] then
	found:=true;
      end if;
      ret_i:=ret_i+1;
    end loop;

    if found=false then
      ret=array_append(ret, src[src_i]);
    end if;

    src_i:=src_i+1;
  end loop;
  return ret;
end
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION array_unique(int[])
RETURNS int[]
AS $$
declare
-- src   int[]=array_sort($1);
arr alias for $1;
src   int[];
index int:=1;
ret   int[];
last  int:=0;
begin
src=array_sort(arr);
while src[index]>0
  loop
    if src[index]<>last then
      ret=array_append(ret, src[index]);
      last:=src[index];
    end if;
    index:=index+1;
  end loop;

return ret;
end;
$$ language 'plpgsql';
