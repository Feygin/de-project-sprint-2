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