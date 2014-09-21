select
  assemble_multipolygon(id)
from relations
where tags @> 'type=>multipolygon' or tags @> 'type=>boundary';
