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
    overlapping_appointment BOOLEAN;
BEGIN
    -- Check if the selected slot exists for the doctor in the time_slots table
    SELECT EXISTS (
        SELECT 1
        FROM time_slots
        WHERE time_slot_id = p_slot_id AND time_slots.doctor_id = p_doctor_id
    ) INTO slot_exists;

    -- If the slot exists, proceed
    IF slot_exists THEN
        -- Check if there is an existing appointment for the selected slot, date, and status
        SELECT EXISTS (
            SELECT 1
            FROM appointments
            WHERE slot_id = p_slot_id
            AND appointment_date = p_appointment_date
            AND status = 'scheduled'
        ) INTO appointment_exists;

        -- Check if the patient has any overlapping appointments on the same day
        SELECT EXISTS (
            SELECT 1
            FROM appointments a
            JOIN time_slots ts ON a.slot_id = ts.time_slot_id
            WHERE a.patient_id = p_patient_id
            AND a.appointment_date = p_appointment_date
            AND a.status = 'scheduled'
            AND (
                ts.slot_start_time < (SELECT slot_end_time FROM time_slots WHERE time_slot_id = p_slot_id)
                AND ts.slot_end_time > (SELECT slot_start_time FROM time_slots WHERE time_slot_id = p_slot_id)
            )
        ) INTO overlapping_appointment;

        -- Proceed only if there is no existing appointment for the slot and no time overlap
        IF NOT appointment_exists AND NOT overlapping_appointment AND p_appointment_date > NOW()::DATE THEN
            -- Insert a new appointment into the appointments table
            INSERT INTO appointments (
                doctor_id, patient_id, slot_id, appointment_date, status, created_at, updated_at
            )
            VALUES (
                p_doctor_id,
                p_patient_id,
                p_slot_id,
                p_appointment_date,
                'scheduled',
                NOW(),
                NOW()
            );
            RETURN TRUE; -- Booking successful
        ELSE
            RETURN FALSE; -- Slot is already reserved or overlaps
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
    cancellation_timestamp timestamp with time zone,
    consultation_notes text,
    appointment_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
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

SET default_table_access_method = heap;

--
-- Name: appointments_nov_2024; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments_nov_2024 (
    doctor_id integer NOT NULL,
    patient_id integer NOT NULL,
    slot_id integer NOT NULL,
    status public.appointment_status NOT NULL,
    cancellation_reason text,
    cancellation_timestamp timestamp with time zone,
    consultation_notes text,
    appointment_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT cancellation_data_check CHECK ((((status = 'canceled'::public.appointment_status) AND (cancellation_reason IS NOT NULL) AND (cancellation_timestamp IS NOT NULL)) OR ((status <> 'canceled'::public.appointment_status) AND (cancellation_reason IS NULL) AND (cancellation_timestamp IS NULL))))
);


ALTER TABLE public.appointments_nov_2024 OWNER TO postgres;

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
-- Name: appointments_nov_2024; Type: TABLE ATTACH; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments ATTACH PARTITION public.appointments_nov_2024 FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');


--
-- Name: appointments unique_appointment; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT unique_appointment UNIQUE (doctor_id, patient_id, slot_id, appointment_date);


--
-- Name: appointments_nov_2024 appointments_nov_2024_doctor_id_patient_id_slot_id_appointm_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments_nov_2024
    ADD CONSTRAINT appointments_nov_2024_doctor_id_patient_id_slot_id_appointm_key UNIQUE (doctor_id, patient_id, slot_id, appointment_date);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (doctor_id, patient_id, appointment_date);


--
-- Name: appointments_nov_2024 appointments_nov_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments_nov_2024
    ADD CONSTRAINT appointments_nov_2024_pkey PRIMARY KEY (doctor_id, patient_id, appointment_date);


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
-- Name: idx_appointments_appointment_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_appointment_date ON ONLY public.appointments USING btree (doctor_id, appointment_date);


--
-- Name: appointments_nov_2024_doctor_id_appointment_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointments_nov_2024_doctor_id_appointment_date_idx ON public.appointments_nov_2024 USING btree (doctor_id, appointment_date);


--
-- Name: idx_appointments_patient_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_patient_date ON ONLY public.appointments USING btree (patient_id, appointment_date);


--
-- Name: appointments_nov_2024_patient_id_appointment_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointments_nov_2024_patient_id_appointment_date_idx ON public.appointments_nov_2024 USING btree (patient_id, appointment_date);


--
-- Name: idx_appointments_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_appointments_status ON ONLY public.appointments USING btree (status);


--
-- Name: appointments_nov_2024_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointments_nov_2024_status_idx ON public.appointments_nov_2024 USING btree (status);


--
-- Name: idx_time_slots; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_time_slots ON public.time_slots USING btree (doctor_id, slot_start_time);


--
-- Name: appointments_nov_2024_doctor_id_appointment_date_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_appointments_appointment_date ATTACH PARTITION public.appointments_nov_2024_doctor_id_appointment_date_idx;


--
-- Name: appointments_nov_2024_doctor_id_patient_id_slot_id_appointm_key; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.unique_appointment ATTACH PARTITION public.appointments_nov_2024_doctor_id_patient_id_slot_id_appointm_key;


--
-- Name: appointments_nov_2024_patient_id_appointment_date_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_appointments_patient_date ATTACH PARTITION public.appointments_nov_2024_patient_id_appointment_date_idx;


--
-- Name: appointments_nov_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.appointments_pkey ATTACH PARTITION public.appointments_nov_2024_pkey;


--
-- Name: appointments_nov_2024_status_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.idx_appointments_status ATTACH PARTITION public.appointments_nov_2024_status_idx;


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

