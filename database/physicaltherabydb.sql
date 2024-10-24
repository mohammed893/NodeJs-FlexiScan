--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.0

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

--
-- Name: physicaltherapydb; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE physicaltherapydb WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'English_United States.1252';


ALTER DATABASE physicaltherapydb OWNER TO postgres;

\connect physicaltherapydb

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

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: action_type_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.action_type_enum AS ENUM (
    'booking',
    'cancellation',
    'rescheduling'
);


ALTER TYPE public.action_type_enum OWNER TO postgres;

--
-- Name: appointment_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.appointment_status AS ENUM (
    'canceled',
    'scheduled',
    'completed'
);


ALTER TYPE public.appointment_status OWNER TO postgres;

--
-- Name: consultation_type_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.consultation_type_enum AS ENUM (
    'video call',
    'phone call'
);


ALTER TYPE public.consultation_type_enum OWNER TO postgres;

--
-- Name: payment_method_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_method_enum AS ENUM (
    'credit card',
    'cash',
    'fawry'
);


ALTER TYPE public.payment_method_enum OWNER TO postgres;

--
-- Name: payment_status_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_status_enum AS ENUM (
    'paid',
    'pending',
    'failed'
);


ALTER TYPE public.payment_status_enum OWNER TO postgres;

--
-- Name: weekdays; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.weekdays AS ENUM (
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
);


ALTER TYPE public.weekdays OWNER TO postgres;

--
-- Name: book_appointment(integer, integer, integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.book_appointment(p_patient_id integer, p_doctor_id integer, p_slot_id integer, p_appointment_date date) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    slot_exists BOOLEAN;
    appointment_exists BOOLEAN;
BEGIN
    -- Check if the selected slot exists for the doctor in the time_slots table
    SELECT EXISTS (
        SELECT 1
        FROM time_slots
        WHERE time_slot_id = p_slot_id AND time_slots.doctor_id = p_doctor_id  -- Using parameter
        for update
    ) INTO slot_exists;

    -- If the slot exists, proceed
    IF slot_exists THEN

        -- Check if there is an existing appointment for the selected slot, date, and status
        SELECT EXISTS (
            SELECT 1
            FROM appointments
            WHERE slot_id = p_slot_id
            AND appointment_date = p_appointment_date
            AND appointments.status = 'scheduled'
        ) INTO appointment_exists;

        -- If no appointment exists and the appointment date is in the future, proceed with the booking
        IF NOT appointment_exists AND p_appointment_date > NOW()::DATE THEN
            -- Insert a new appointment into the appointments table
            INSERT INTO appointments (
                doctor_id, patient_id, slot_id, appointment_date, 
                status, created_at, updated_at
            )
            VALUES (
                p_doctor_id,  -- Using parameter
                p_patient_id,  -- Using parameter
                p_slot_id,     -- Using parameter
                p_appointment_date,  -- Using parameter
                'scheduled',
                NOW(),
                NOW()
            );

            RETURN TRUE; -- Booking successful
        ELSE
            RETURN FALSE; -- Slot is already reserved or date is invalid
        END IF;
    ELSE
        RETURN FALSE; -- Slot is unavailable or not valid
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'An error occurred: %', SQLERRM;
        RETURN FALSE; -- Indicate booking failed due to an error
END;
$$;


ALTER FUNCTION public.book_appointment(p_patient_id integer, p_doctor_id integer, p_slot_id integer, p_appointment_date date) OWNER TO postgres;

SET default_tablespace = '';

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    doctor_id integer NOT NULL,
    patient_id integer NOT NULL,
    slot_id integer NOT NULL,
    status public.appointment_status NOT NULL,
    cancellation_reason text,
    cancellation_timestamp timestamp without time zone,
    consultation_notes text,
    appointment_date date NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT cancellation_data_check CHECK ((((status = 'canceled'::public.appointment_status) AND (cancellation_reason IS NOT NULL) AND (cancellation_timestamp IS NOT NULL)) OR ((status <> 'canceled'::public.appointment_status) AND (cancellation_reason IS NULL) AND (cancellation_timestamp IS NULL))))
)
PARTITION BY RANGE (appointment_date);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.appointments_appointment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.appointments_appointment_id_seq OWNER TO postgres;

--
-- Name: billings_billing_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.billings_billing_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.billings_billing_id_seq OWNER TO postgres;

SET default_table_access_method = heap;

--
-- Name: billings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.billings (
    billing_id integer DEFAULT nextval('public.billings_billing_id_seq'::regclass) NOT NULL,
    patient_id integer NOT NULL,
    doctor_id integer NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    billing_date timestamp with time zone NOT NULL,
    payment_status public.payment_status_enum NOT NULL,
    payment_method public.payment_method_enum NOT NULL,
    notes character varying(255),
    appointment_date date NOT NULL
);


ALTER TABLE public.billings OWNER TO postgres;

--
-- Name: bookinghistory_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bookinghistory_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bookinghistory_history_id_seq OWNER TO postgres;

--
-- Name: booking_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.booking_history (
    history_id integer DEFAULT nextval('public.bookinghistory_history_id_seq'::regclass) NOT NULL,
    action_type public.action_type_enum NOT NULL,
    old_date date NOT NULL,
    old_start_time time without time zone NOT NULL,
    old_end_time time without time zone NOT NULL,
    new_date time without time zone NOT NULL,
    new_start_time time without time zone NOT NULL,
    new_end_time time without time zone NOT NULL,
    cancellation_reason text,
    action_date timestamp without time zone DEFAULT now(),
    patient_id integer NOT NULL,
    doctor_id integer NOT NULL,
    appointment_date date NOT NULL
);


ALTER TABLE public.booking_history OWNER TO postgres;

--
-- Name: consultationrecords_conultation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.consultationrecords_conultation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.consultationrecords_conultation_id_seq OWNER TO postgres;

--
-- Name: consultation_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.consultation_records (
    consultation integer DEFAULT nextval('public.consultationrecords_conultation_id_seq'::regclass) NOT NULL,
    doctor_id integer,
    patient_id integer,
    consultation_note text NOT NULL,
    prescription text NOT NULL,
    follow_up_date timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    appointment_date date NOT NULL
);


ALTER TABLE public.consultation_records OWNER TO postgres;

--
-- Name: doctors_doctor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.doctors_doctor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.doctors_doctor_id_seq OWNER TO postgres;

--
-- Name: doctors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctors (
    full_name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    date_of_birth date NOT NULL,
    gender character varying(20) NOT NULL,
    phone_number text NOT NULL,
    age integer NOT NULL,
    hospital text,
    national_id bigint NOT NULL,
    verification_image_url text NOT NULL,
    doctor_id integer DEFAULT nextval('public.doctors_doctor_id_seq'::regclass) NOT NULL,
    timezone character varying(50) NOT NULL,
    consultation_type public.consultation_type_enum NOT NULL,
    specialization character varying(255) NOT NULL,
    experience integer NOT NULL,
    slot_duration interval NOT NULL,
    working_hours jsonb NOT NULL,
    available_days jsonb NOT NULL,
    CONSTRAINT experience_check CHECK ((experience >= 0))
);


ALTER TABLE public.doctors OWNER TO postgres;

--
-- Name: patients_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patients_patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.patients_patient_id_seq OWNER TO postgres;

--
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    patient_id integer DEFAULT nextval('public.patients_patient_id_seq'::regclass) NOT NULL,
    full_name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    date_of_birth date NOT NULL,
    gender character varying(10) NOT NULL,
    phone_number text NOT NULL,
    follow_up boolean NOT NULL,
    insurance_id text,
    primary_doctor_id integer
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- Name: time_slots_time_slot_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.time_slots_time_slot_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.time_slots_time_slot_id_seq OWNER TO postgres;

--
-- Name: time_slots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.time_slots (
    time_slot_id integer DEFAULT nextval('public.time_slots_time_slot_id_seq'::regclass) NOT NULL,
    doctor_id integer NOT NULL,
    slot_start_time time without time zone NOT NULL,
    slot_end_time time without time zone NOT NULL,
    slot_duration interval NOT NULL,
    working_days public.weekdays[] NOT NULL,
    is_available boolean NOT NULL
);


ALTER TABLE public.time_slots OWNER TO postgres;

--
-- Data for Name: billings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.billings (billing_id, patient_id, doctor_id, total_amount, billing_date, payment_status, payment_method, notes, appointment_date) FROM stdin;
\.


--
-- Data for Name: booking_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.booking_history (history_id, action_type, old_date, old_start_time, old_end_time, new_date, new_start_time, new_end_time, cancellation_reason, action_date, patient_id, doctor_id, appointment_date) FROM stdin;
\.


--
-- Data for Name: consultation_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.consultation_records (consultation, doctor_id, patient_id, consultation_note, prescription, follow_up_date, created_at, updated_at, appointment_date) FROM stdin;
\.


--
-- Data for Name: doctors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.doctors (full_name, email, password, date_of_birth, gender, phone_number, age, hospital, national_id, verification_image_url, doctor_id, timezone, consultation_type, specialization, experience, slot_duration, working_hours, available_days) FROM stdin;
Dr. John Doe	doctor.email@example.com	securepassword	1979-04-23	male	555-1234-567	45	General Hospital	1234904	http://example.com/verification_image.jpg	1	Africa/Cairo	video call	Cardiology	20	00:30:00	{"end": "17:00", "start": "09:00"}	["Monday", "Wednesday", "Friday"]
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (patient_id, full_name, email, password, date_of_birth, gender, phone_number, follow_up, insurance_id, primary_doctor_id) FROM stdin;
1	John Doe	patient.email@example.com	securepassword	1990-05-15	male	555-9876-543	t	INS123456	1
\.


--
-- Data for Name: time_slots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.time_slots (time_slot_id, doctor_id, slot_start_time, slot_end_time, slot_duration, working_days, is_available) FROM stdin;
5	1	14:00:00	14:30:00	00:30:00	{Wednesday,Sunday,Monday}	t
6	1	14:30:00	15:00:00	00:30:00	{Wednesday,Sunday,Monday}	t
7	1	15:00:00	15:30:00	00:30:00	{Wednesday,Sunday,Monday}	t
8	1	15:30:00	16:00:00	00:30:00	{Wednesday,Sunday,Monday}	t
\.


--
-- Name: appointments_appointment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointments_appointment_id_seq', 4, true);


--
-- Name: billings_billing_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.billings_billing_id_seq', 1, false);


--
-- Name: bookinghistory_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bookinghistory_history_id_seq', 1, false);


--
-- Name: consultationrecords_conultation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.consultationrecords_conultation_id_seq', 1, false);


--
-- Name: doctors_doctor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.doctors_doctor_id_seq', 2, true);


--
-- Name: patients_patient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patients_patient_id_seq', 14, true);


--
-- Name: time_slots_time_slot_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.time_slots_time_slot_id_seq', 8, true);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (doctor_id, patient_id, appointment_date);


--
-- Name: booking_history booking_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking_history
    ADD CONSTRAINT booking_history_pkey PRIMARY KEY (history_id);


--
-- Name: consultation_records consultation_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consultation_records
    ADD CONSTRAINT consultation_records_pkey PRIMARY KEY (consultation);


--
-- Name: doctors doctors_doctor_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_doctor_id_pkey PRIMARY KEY (doctor_id);


--
-- Name: doctors doctors_national_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_national_id_key UNIQUE (national_id);


--
-- Name: patients patients_insurance__id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_insurance__id UNIQUE (insurance_id);


--
-- Name: patients patients_patien_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_patien_id_pkey PRIMARY KEY (patient_id);


--
-- Name: billings pk_billing; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.billings
    ADD CONSTRAINT pk_billing PRIMARY KEY (billing_id);


--
-- Name: time_slots time_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_pkey PRIMARY KEY (time_slot_id);


--
-- Name: appointments unique_appointment; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT unique_appointment UNIQUE (doctor_id, patient_id, slot_id, appointment_date);


--
-- Name: idx_appointments_appointment_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_appointment_date ON ONLY public.appointments USING btree (doctor_id, appointment_date);


--
-- Name: idx_appointments_patient_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_patient_date ON ONLY public.appointments USING btree (patient_id, appointment_date);


--
-- Name: idx_appointments_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_status ON ONLY public.appointments USING btree (status);


--
-- Name: idx_time_slots; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_time_slots ON public.time_slots USING btree (doctor_id, slot_start_time);


--
-- Name: appointments appointments_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: appointments appointments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: appointments appointments_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.time_slots(time_slot_id);


--
-- Name: booking_history bookinghistory_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking_history
    ADD CONSTRAINT bookinghistory_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: booking_history bookinghistory_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking_history
    ADD CONSTRAINT bookinghistory_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: consultation_records consultation_records_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consultation_records
    ADD CONSTRAINT consultation_records_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: consultation_records consultation_records_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consultation_records
    ADD CONSTRAINT consultation_records_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: billings fk_doctor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.billings
    ADD CONSTRAINT fk_doctor FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- Name: billings fk_patient; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.billings
    ADD CONSTRAINT fk_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- Name: patients patients_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_doctor_id_fkey FOREIGN KEY (primary_doctor_id) REFERENCES public.doctors(doctor_id);


--
-- Name: time_slots time_slots_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id);


--
-- PostgreSQL database dump complete
--

