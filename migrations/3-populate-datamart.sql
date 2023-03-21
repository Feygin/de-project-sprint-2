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