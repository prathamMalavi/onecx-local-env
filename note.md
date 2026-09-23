This is the table we need to add a value in this table can we 
SELECT * FROM public.theme_override
ORDER BY guid ASC 

We need to add
guid
[PKI character varying (255)
theme—id
character varying (255)
character varying (255)
value
character varying (255)

type CSS
value is "p-toast { z-index: 1102 !important; }"


docker exec postgresdb psql -U postgres -d onecx_theme -c "
INSERT INTO public.theme_override (guid, theme_id, type, value)
SELECT gen_random_uuid()::varchar, guid, 'CSS', 'p-toast { z-index: 1102 !important; }'
FROM public.theme
ON CONFLICT (theme_id, type) DO UPDATE SET value = EXCLUDED.value;
"


docker exec postgresdb psql -U postgres -d onecx_theme -c "SELECT * FROM public.theme_override ORDER BY theme_id;"


DELETE FROM public.theme_override
WHERE type = 'CSS'
  AND value = 'p-toast { z-index: 1102 !important; }';


docker exec postgresdb psql -U postgres -d onecx_theme -c "DELETE FROM public.theme_override WHERE type = 'CSS' AND value = 'p-toast { z-index: 1102 !important; }';"





"overrides":[{"type":"CSS","value":"p-toast { z-index: 1102; }"}],

"overrides":[{"type":"CSS","value":"p-toast { z-index: 1102; }"}],"operator":true,"