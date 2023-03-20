drop table if exists public.shipping_country_rates  cascade;
drop table if exists public.shipping_agreement      cascade;
drop table if exists public.shipping_transfer       cascade;
drop table if exists public.shipping_info           cascade;
drop table if exists public.shipping_status         cascade;
drop table if exists public.shipping_datamart       cascade;

--создаем справочник стоимости доставки в страны shipping_country_rates
create table public.shipping_country_rates(
  id 							serial,
  shipping_country 				text,
  shipping_country_base_rate 	numeric(14,3),
  primary key (id)
);

--создаем справочник тарифов доставки вендора по договору sheeping_agreement
create table public.shipping_agreement(
  agreement_id 				bigint,
  agreement_number 			text,
  agreement_rate 			numeric(3,2),
  agreement_commission 		numeric(5,3),
  primary key (agreement_id)
);

--создаем справочник о типах доставки shipping_transfer
create table public.shipping_transfer(
  id						serial,
  transfer_type 			text,
  transfer_model 			text,
  shipping_transfer_rate  	numeric(4,3),
  primary key(id)
);

--создаем справочник комиссий по странам shipping_info
create table public.shipping_info(
  shipping_id					bigint unique, --в задании условие на уникальность поля
  shipping_plan_datetime		timestamp,
  payment_amount				numeric(14,2),
  vendor_id						bigint,
  shipping_transfer_id			bigint,
  shipping_agreement_id 		bigint,
  shipping_country_rate_id		bigint,
  foreign key (shipping_transfer_id) 		references shipping_transfer(id),
  foreign key (shipping_agreement_id) 		references shipping_agreement(agreement_id),
  foreign key (shipping_country_rate_id)	references shipping_country_rates(id)
);

--создаем таблицу статусов доставки shipping_status
create table public.shipping_status(
  shipping_id						bigint unique,	--в задании условие на уникальность поля
  status							text,
  state								text,
  shipping_start_fact_datetime		timestamp,
  shipping_end_fact_datetime		timestamp							
);									
  
create table public.shipping_datamart(
  shipping_id					bigint unique,                              -- гранулярность - shipping_id
  vendor_id						bigint not null,
  transfer_type					text   not null,
  full_day_at_shipping			bigint, 						            -- полные дни доставки
  is_delay						smallint 	
  	check(is_delay >= 0 and is_delay <= 1) not null,                        -- по условию 1,0
  is_shipping_finish			smallint 						            -- статус доставки
  	check(is_shipping_finish >= 0 and is_shipping_finish <= 1) not null,    -- по условию 1,0
  delay_day_at_shipping			bigint not null,							-- кол-во дней просрочки доставки
  payment_amount 				numeric(14,2) not null,
  vat							numeric(14,2) not null,					    -- итоговый налог на доставку
  profit						numeric(14,2) not null					    -- итоговый доход компании с доставки
);

-- заполняем справочник стоимости доставки shipping_country_rates
insert into public.shipping_country_rates
(shipping_country, shipping_country_base_rate)
select distinct shipping_country, shipping_country_base_rate
from public.shipping;

-- проверяем заполнение
-- select * from public.shipping_country_rates limit 10;

-- заполняем справочник тарифов доставки shipping_agreement
insert into public.shipping_agreement
(agreement_id, agreement_number, agreement_rate, agreement_commission)
select distinct
	(regexp_split_to_array(vendor_agreement_description, ':'))[1]::bigint,
	(regexp_split_to_array(vendor_agreement_description, ':'))[2],
	(regexp_split_to_array(vendor_agreement_description, ':'))[3]::numeric(3,2),
	(regexp_split_to_array(vendor_agreement_description, ':'))[4]::numeric(5,3)
from public.shipping s;

-- проверяем заполнение
-- select * from public.shipping_agreement limit 10;

-- заполняем справочник типов доставки shipping_transfer
insert into public.shipping_transfer 
(transfer_type, transfer_model, shipping_transfer_rate)
select distinct
	(regexp_split_to_array(shipping_transfer_description, ':'))[1],
	(regexp_split_to_array(shipping_transfer_description, ':'))[2],
	shipping_transfer_rate
from public.shipping;

-- проверяем заполнение
-- select * from public.shipping_transfer limit 10;

-- выводим статистику по кол-ву строк и уникальных shipping_id
-- проверим правильность создания shipping_info по этим данным
-- select count(*) as total_rows, count(distinct shippingid) as unique_shipping_id from shipping;

-- заполняем справочник комиссий по странам shipping_info
insert into public.shipping_info
(shipping_id, shipping_plan_datetime, payment_amount, vendor_id,
shipping_transfer_id, shipping_agreement_id, shipping_country_rate_id)
select distinct
	s.shippingid,
	s.shipping_plan_datetime,
	s.payment_amount,
	s.vendorid,
	st.id,
	sa.agreement_id,
	scr.id
from (
  select
  	*,
  	(regexp_split_to_array(vendor_agreement_description, ':'))[1]::bigint  		 as agreement_id, -- блок shipping_agreement
	(regexp_split_to_array(vendor_agreement_description, ':'))[2]  				 as agreement_number,
	(regexp_split_to_array(vendor_agreement_description, ':'))[3]::numeric(3,2)  as agreement_rate,
	(regexp_split_to_array(vendor_agreement_description, ':'))[4]::numeric(5,3)  as agreement_comission,
	(regexp_split_to_array(shipping_transfer_description, ':'))[1] 				 as transfer_type, -- блок shipping_transfer
	(regexp_split_to_array(shipping_transfer_description, ':'))[2] 				 as transfer_model
  from public.shipping
) s
join shipping_country_rates scr
	on  s.shipping_country = scr.shipping_country
		and s.shipping_country_base_rate = scr.shipping_country_base_rate
join shipping_agreement sa
	on  s.agreement_id 			  = sa.agreement_id
		and s.agreement_number 	  = sa.agreement_number
		and s.agreement_rate 	  = sa.agreement_rate
		and s.agreement_comission = sa.agreement_commission
join shipping_transfer st
	on  s.transfer_type 		  = st.transfer_type
		and s.transfer_model 	  = st.transfer_model;

-- заполняем таблицу shipping_status
insert into public.shipping_status
(shipping_id, status, state, 
 shipping_start_fact_datetime, shipping_end_fact_datetime)
with shipping_status as (   
  select distinct
	  shippingid,
	  status,
	  state
  from (
	select
		*,
		row_number() over(partition by shippingid order by state_datetime desc) as row_num -- вспомогательное поле, чтобы найти последний статус
	from shipping
  ) t
  where row_num = 1 -- оставляем строку с последней датой статуса
),

shipping_dates as (
  select
  	shippingid,
  	max(shipping_start_fact_datetime) as shipping_start_fact_datetime,
  	max(shipping_end_fact_datetime) as shipping_end_fact_datetime
  from (
	select
		shippingid,
		case when state = 'booked' then state_datetime else null end as shipping_start_fact_datetime, -- оставляем даты для требуемых статусов
		case when state = 'recieved' then state_datetime else null end as shipping_end_fact_datetime
	from shipping s
  ) t
  group by shippingid   -- получаем 1 строку для shipping_id
)

select                  -- объединяем промежуточные результаты
	sd.shippingid,
  	status,
  	state,
  	shipping_start_fact_datetime,
  	shipping_end_fact_datetime
from shipping_dates sd join shipping_status st
  	on sd.shippingid = st.shippingid;

-- проверяем вставку
-- select * from shipping_status limit 10;

-- наполняем витрину данными
insert into public.shipping_datamart 
(shipping_id, vendor_id, transfer_type, full_day_at_shipping,
 is_delay, is_shipping_finish, delay_day_at_shipping, 
 payment_amount, vat, profit
)
select
	si.shipping_id,
	si.vendor_id,
	st.transfer_type,
	ss.shipping_end_fact_datetime::date                                     -- если не доставлено, то показатель зануляется
		- ss.shipping_start_fact_datetime::date as full_day_at_shipping,
	(coalesce(ss.shipping_end_fact_datetime, '1900-01-01'::date)            -- по условию в поле должны быть только 1 и 0
	 	> si.shipping_plan_datetime)::integer as is_delay,
	case when ss.status = 'finished' then 1 else 0 end as is_shipping_finish,
	case 
		when coalesce(ss.shipping_end_fact_datetime, '1900-01-01'::date)    -- по условию в поле должны быть только 1 и 0
				> si.shipping_plan_datetime 
		then ss.shipping_end_fact_datetime::date - si.shipping_plan_datetime::date
		else 0
	end as delay_day_at_shipping,
	si.payment_amount,
	si.payment_amount * (scr.shipping_country_base_rate 
		+ sa.agreement_rate + st.shipping_transfer_rate) as vat,
	si.payment_amount * sa.agreement_commission as profit
from shipping_info si                                       -- денормализуем справочники
join shipping_transfer st
	on si.shipping_transfer_id 		= st.id
join shipping_country_rates scr
	on si.shipping_country_rate_id 	= scr.id
join shipping_agreement sa
	on si.shipping_agreement_id 	= sa.agreement_id
join shipping_status ss
	on si.shipping_id 				= ss.shipping_id;




