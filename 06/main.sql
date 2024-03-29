-- Setup
create table if not exists input_lines (
  line_number integer generated by default as identity,
  text text not null,
  constraint input_lines_pkey primary key (line_number)
);

-- \copy input_lines (text) from 'example';
\copy input_lines (text) from 'input';

create aggregate multiply(bigint) (
  sfunc = int8mul,
  stype = bigint
);

-- Part 1
with
parsed_inputs as
(
    select content[1] as header,
           cast (number as integer),
           race_number
      from input_lines,
           regexp_match(text, '(.*):\s+(.*)') as content,
           unnest(regexp_split_to_array(content[2], '\s+'))
             with ordinality
             as t(number, race_number)
),
parsed_inputs_ordered as
(
    select *
      from parsed_inputs
  order by race_number,
           case header
           when 'Time' then 1
           when 'Distance' then 2
           end
),
races as (
  select race_number,
         fields[1] as race_time,
         fields[2] as record_distance
    from (
             select race_number,
                    array_agg(number) as fields
               from parsed_inputs_ordered
           group by race_number
         )
),
hold_options as (
             select *,
                    (hold_time * travel_time) as distance
               from races,
                    generate_series(1, (race_time - 1)) as hold_time
  left join lateral (
                      select (race_time - hold_time) as travel_time
                    )
                 on true
),
ways_to_win as (
    select race_number,
           count(*) as ways_to_win
      from hold_options
     where distance > record_distance
  group by race_number
)
select multiply(ways_to_win) as result
  from ways_to_win
;

-- Part 2
create view part_2_race_details as (
  with
  parsed_inputs as
  (
      select content[1] as header,
             cast (replace(content[2], ' ', '') as bigint) as number
        from input_lines,
             regexp_match(text, '(.*):\s+(.*)') as content
  )
  select time.number as race_time,
         distance.number as record_distance
    from parsed_inputs as time,
         parsed_inputs as distance
   where time.header = 'Time'
     and distance.header = 'Distance'
);

-- ** Naïve Solution
with
hold_options as (
             select *,
                    (hold_time * travel_time) as distance
               from part_2_race_details,
                    generate_series(1, (race_time - 1)) as hold_time
  left join lateral (
                      select (race_time - hold_time) as travel_time
                    )
                 on true
)
select count(*) as result
  from hold_options
 where distance > record_distance
;

-- ** Quadratic Equation - Efficient
with
equation_inner as
(
  select race_time,
         sqrt(power(race_time, 2) - (4 * record_distance)) as equation_inner
    from part_2_race_details
),
equation_solutions as
(
  select ceil((race_time - equation_inner) / 2) as lower,
         floor((race_time + equation_inner) / 2) as upper
    from equation_inner
)
select (upper - lower) + 1 as result
  from equation_solutions
;

drop aggregate multiply(bigint);
drop table input_lines cascade;
