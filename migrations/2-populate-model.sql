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