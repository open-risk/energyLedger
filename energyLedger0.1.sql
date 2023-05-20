-- Copyright (c) 2023 Open Risk (https://www.openriskmanagement.com)
-- PostgreSQL database dump of energyLedger
-- Version 0.1
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpython3u IS 'PL/Python3U untrusted procedural language';

--
-- Checking the First Law of Thermodynamics
--

CREATE FUNCTION public.check_first_law() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                DECLARE
                    energy_sum DECIMAL(13, 2);
                    t_type INTEGER;
                BEGIN
                    IF (TG_OP = 'INSERT') THEN
                        SELECT type INTO t_type FROM transaction WHERE NEW.transaction_id = id; 
                        IF (t_type = 1) THEN
                        SELECT SUM(ENERGY) INTO energy_sum FROM (
                            SELECT sum(transaction_leg.physical_energy) AS ENERGY
                            FROM transaction_leg, account WHERE transaction_id = NEW.transaction_id AND account_id = account.id AND (account.type = 'AS')
                            UNION
                            SELECT sum(transaction_leg.embodied_energy) AS ENERGY
                            FROM transaction_leg, account WHERE transaction_id = NEW.transaction_id AND account_id = account.id AND (account.type = 'AS')
                        ) AS TMP1;
                        ELSE
                            energy_sum = 0;
                        END IF;
                    ELSE
                        SELECT type INTO t_type FROM transaction WHERE OLD.transaction_id = id; 
                        IF (t_type = 1) THEN
                        SELECT SUM(ENERGY) INTO energy_sum FROM (
                            SELECT sum(transaction_leg.physical_energy) AS ENERGY
                            FROM transaction_leg, account WHERE transaction_id = OLD.transaction_id AND account_id = account.id AND (account.type = 'AS')
                            UNION
                            SELECT sum(transaction_leg.embodied_energy) AS ENERGY
                            FROM transaction_leg, account WHERE transaction_id = OLD.transaction_id AND account_id = account.id AND (account.type = 'AS')
                        ) AS TMP2;  
                        ELSE
                            energy_sum = 0;
                        END IF;                                          
                    END IF;                    
                    IF energy_sum != 0 THEN
                        RAISE EXCEPTION 'Energy conservation violation for internal transaction: %', energy_sum;
                    END IF;
                    RETURN NEW;
                END;
                $$;


ALTER FUNCTION public.check_first_law() OWNER TO postgres;

--
-- Checking Balance Equations
--

CREATE FUNCTION public.check_kirchhoff_law() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                DECLARE
                    monetary_sum DECIMAL(13, 2);
                    physical_sum DECIMAL(13, 2);
                    embodied_sum DECIMAL(13, 2);
                BEGIN
                    IF (TG_OP = 'INSERT') THEN
                        SELECT SUM(monetary_amount) INTO monetary_sum FROM transaction_leg WHERE transaction_id = NEW.transaction_id;
                        SELECT SUM(physical_energy) INTO physical_sum FROM transaction_leg WHERE transaction_id = NEW.transaction_id;     
                        SELECT SUM(embodied_energy) INTO embodied_sum FROM transaction_leg WHERE transaction_id = NEW.transaction_id;
                    ELSE
                        SELECT SUM(monetary_amount) INTO monetary_sum FROM transaction_leg WHERE transaction_id = OLD.transaction_id;
                        SELECT SUM(physical_energy) INTO physical_sum FROM transaction_leg WHERE transaction_id = OLD.transaction_id;     
                        SELECT SUM(embodied_energy) INTO embodied_sum FROM transaction_leg WHERE transaction_id = OLD.transaction_id;     
                    END IF;
                    IF monetary_sum != 0 THEN
                        RAISE EXCEPTION 'Sum of transaction monetary amounts must be 0, not %', monetary_sum;
                    END IF;
                    IF physical_sum != 0 THEN
                        RAISE EXCEPTION 'Sum of transaction physical energy amounts must be 0, not %', physical_sum;
                    END IF;
                    IF embodied_sum != 0 THEN
                        RAISE EXCEPTION 'Sum of transaction embodied energy amounts must be 0, not %', embodied_sum;
                    END IF;                    
                    RETURN NEW;
                END;
                $$;


ALTER FUNCTION public.check_kirchhoff_law() OWNER TO postgres;

--
-- Check Entropy Law
--

CREATE FUNCTION public.check_second_law() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                DECLARE
                    embodied_energy_sum DECIMAL(13, 2);
                    t_type INTEGER;
                BEGIN
                    IF (TG_OP = 'INSERT') THEN
                        SELECT type INTO t_type FROM transaction WHERE NEW.transaction_id = id; 
                        IF (t_type = 1) THEN
                        SELECT SUM(ENERGY) INTO embodied_energy_sum FROM (
                            SELECT sum(transaction_leg.embodied_energy) AS ENERGY
                            FROM transaction_leg, account WHERE transaction_id = NEW.transaction_id AND account_id = account.id AND (account.type = 'AS')
                        ) AS TMP1;
                        ELSE
                            embodied_energy_sum = 0;
                        END IF;
                    ELSE
                        SELECT type INTO t_type FROM transaction WHERE OLD.transaction_id = id; 
                        IF (t_type = 1) THEN
                        SELECT SUM(ENERGY) INTO embodied_energy_sum FROM (
                            SELECT sum(transaction_leg.embodied_energy) AS ENERGY
                            FROM transaction_leg, account WHERE transaction_id = OLD.transaction_id AND account_id = account.id AND (account.type = 'AS')
                        ) AS TMP2;  
                        ELSE
                            embodied_energy_sum = 0;
                        END IF;                                          
                    END IF;                    
                    IF embodied_energy_sum < 0 THEN
                        RAISE EXCEPTION 'Embodied Energy decrease for internal transaction: %', embodied_energy_sum;
                    END IF;
                    RETURN NEW;
                END;
                $$;


ALTER FUNCTION public.check_second_law() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account; Type: TABLE
--

CREATE TABLE public.account (
    id integer NOT NULL,
    name text,
    code text,
    symbol text,
    type text NOT NULL
);


ALTER TABLE public.account OWNER TO postgres;

CREATE SEQUENCE public.account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_id_seq OWNER TO postgres;

ALTER SEQUENCE public.account_id_seq OWNED BY public.account.id;


--
-- Name: transaction; Type: TABLE
--

CREATE TABLE public.transaction (
    id integer NOT NULL,
    type integer NOT NULL,
    "timestamp" timestamp without time zone,
    date date,
    descriptions text
);


ALTER TABLE public.transaction OWNER TO postgres;

CREATE SEQUENCE public.transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_id_seq OWNER TO postgres;


ALTER SEQUENCE public.transaction_id_seq OWNED BY public.transaction.id;

--
-- Name: transaction_leg; Type: TABLE
--

CREATE TABLE public.transaction_leg (
    id integer NOT NULL,
    monetary_amount double precision,
    physical_energy double precision,
    embodied_energy double precision,
    account_id integer,
    transaction_id integer,
    description text
);


ALTER TABLE public.transaction_leg OWNER TO postgres;

--
-- Name: transaction_leg_id_seq; Type: SEQUENCE
--

CREATE SEQUENCE public.transaction_leg_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_leg_id_seq OWNER TO postgres;
ALTER SEQUENCE public.transaction_leg_id_seq OWNED BY public.transaction_leg.id;
ALTER TABLE ONLY public.account ALTER COLUMN id SET DEFAULT nextval('public.account_id_seq'::regclass);
ALTER TABLE ONLY public.transaction ALTER COLUMN id SET DEFAULT nextval('public.transaction_id_seq'::regclass);
ALTER TABLE ONLY public.transaction_leg ALTER COLUMN id SET DEFAULT nextval('public.transaction_leg_id_seq'::regclass);


--
-- Data for Name: account; Type: TABLE DATA
--

COPY public.account (id, name, code, symbol, type) FROM stdin;
1	Cash	A01	C	AS
2	Factory	A02	F	AS
3	Energy Stock	A03	S	AS
4	Raw Materials	A04	M	AS
5	Inventory	A05	I	AS
6	Accounts Payable	A06	P	LI
7	Bank Loan	A07	L	LI
8	Equity	A08	K	EQ
\.


--
-- Data for Name: transaction; Type: TABLE DATA
--

COPY public.transaction (id, type, "timestamp", date, descriptions) FROM stdin;
1	0	2023-05-17 21:23:52.470828	2023-01-02	Initial Equity Transaction
2	0	2023-05-17 21:23:52.470836	2023-01-03	Acquire Facilities
3	0	2023-05-17 21:23:52.470837	2023-01-04	Acquire Raw Materials on Credit
4	0	2023-05-17 21:23:52.470838	2023-01-05	Self-Produce Solar Energy
5	0	2023-05-17 21:23:52.470839	2023-01-06	Procure Grid Electrical Energy
6	1	2023-05-17 21:23:52.47084	2023-01-07	Produce Widgets (Material Processes)
7	1	2023-05-17 21:23:52.470841	2023-01-08	Produce Widgets (Energy Processes)
8	0	2023-05-17 21:23:52.470842	2023-01-09	Widget Sale
9	0	2023-05-17 21:23:52.470843	2023-01-10	Debt Repayment
10	0	2023-05-17 21:23:52.470844	2023-01-11	New Bank Loan
\.


--
-- Data for Name: transaction_leg; Type: TABLE DATA
--

COPY public.transaction_leg (id, monetary_amount, physical_energy, embodied_energy, account_id, transaction_id, description) FROM stdin;
859247	50	0	0	1	1	Credit Cash Account
164114	-50	0	0	8	1	Credit Equity Account
162218	-10	0	0	1	2	Debit Cash Account
175965	10	0	100	2	2	Credit Facility Account
981974	0	0	-100	8	2	Credit Equity Account
534663	15	0	150	4	3	Credit Materials Account
911946	-15	0	-45	6	3	Credit Payables Account
351063	0	0	-105	8	3	Credit Equity Account
480586	-5	0	0	1	4	Debit Cash Account
361799	20	30	0	3	4	Credit Energy Stock Account
966174	-15	-30	0	8	4	Credit Equity Account
693193	-12	0	0	1	5	Debit Cash Account
508398	12	60	0	3	5	Credit Energy Stock Account
935170	0	-60	0	8	5	Credit Equity Account
289994	-32	-90	0	3	6	Debit Energy Stock
467727	-15	0	-150	4	6	Debit Material Stock
67649	47	90	150	5	6	Credit Inventory Account
926470	0	-90	0	5	7	Debit Inventory Physical Energy
809936	0	0	90	5	7	Credit Inventory Embodied Energy
112822	0	90	0	8	7	Credit Equity Physical Energy
23231	0	0	-90	8	7	Debit Equity Embodied Energy
280646	60	0	0	1	8	Credit Widget Cash Receipts
855569	-47	0	-240	5	8	Debit Inventory Sale
573488	-13	0	240	8	8	Debit Equity Cash Receipt
430011	-15	0	0	1	9	Debit Cash for Debt Repayment
708639	15	0	45	6	9	Credit Accounts Payable
170095	0	0	-45	8	9	Debit Equity Cash Receipt
925153	32	0	0	1	10	Credit Cash from Loan
152243	-32	0	-41.02564102564102	7	10	Credit Loan Liability
928018	0	0	41.02564102564102	8	10	Debit Equity Cash Receipt
\.


SELECT pg_catalog.setval('public.account_id_seq', 8, true);
SELECT pg_catalog.setval('public.transaction_id_seq', 1, false);
SELECT pg_catalog.setval('public.transaction_leg_id_seq', 7, true);


--
-- Name: account account_pkey; Type: CONSTRAINT
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: transaction_leg transaction_leg_pkey; Type: CONSTRAINT
--

ALTER TABLE ONLY public.transaction_leg
    ADD CONSTRAINT transaction_leg_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_pkey; Type: CONSTRAINT
--

ALTER TABLE ONLY public.transaction
    ADD CONSTRAINT transaction_pkey PRIMARY KEY (id);


--
-- Name: transaction_leg balance_trigger; Type: TRIGGER
--

CREATE CONSTRAINT TRIGGER balance_trigger AFTER INSERT OR DELETE OR UPDATE ON public.transaction_leg DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.check_kirchhoff_law();


--
-- Name: transaction_leg energy_trigger; Type: TRIGGER
--

CREATE CONSTRAINT TRIGGER energy_trigger AFTER INSERT OR DELETE OR UPDATE ON public.transaction_leg DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.check_first_law();

--
-- Name: transaction_leg entropy_trigger; Type: TRIGGER
--

CREATE CONSTRAINT TRIGGER entropy_trigger AFTER INSERT OR DELETE OR UPDATE ON public.transaction_leg DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.check_second_law();


--
-- Name: transaction_leg fk_account; Type: FK CONSTRAINT
--

ALTER TABLE ONLY public.transaction_leg
    ADD CONSTRAINT fk_account FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: transaction_leg fk_transaction; Type: FK CONSTRAINT
--

ALTER TABLE ONLY public.transaction_leg
    ADD CONSTRAINT fk_transaction FOREIGN KEY (transaction_id) REFERENCES public.transaction(id);

