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

CREATE DATABASE physicaltherapydb WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'English_United States.1252';


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

-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

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
    v_slot_start_time TIME;
    v_slot_end_time TIME;
BEGIN
    -- Lock the slot to ensure it's not booked by another transaction and retrieve start and end times
    SELECT EXISTS (
        SELECT 1
        FROM time_slots
        WHERE time_slot_id = p_slot_id 
          AND doctor_id = p_doctor_id
        FOR UPDATE
    ) INTO slot_exists;

    -- If the slot does not exist, exit early
    IF NOT slot_exists THEN
        RETURN FALSE;
    END IF;

    -- Getting slot start and end times
    SELECT slot_start_time, slot_end_time
    INTO v_slot_start_time, v_slot_end_time
    FROM time_slots
    WHERE time_slot_id = p_slot_id;

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
              ts.slot_start_time < v_slot_end_time
              AND ts.slot_end_time > v_slot_start_time
          )
    ) INTO overlapping_appointment;

    -- Proceed only if there is no existing appointment and no time overlap
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

        -- Log the booking action in booking_history
        INSERT INTO booking_history (
            doctor_id,
            patient_id,
            appointment_date,
            old_start_time,
            old_end_time,
            action_type,
            action_date
        )
        VALUES (
            p_doctor_id,
            p_patient_id,
            p_appointment_date,
            v_slot_start_time,
            v_slot_end_time,
            'booking',
            CURRENT_TIMESTAMP
        );
        RETURN TRUE; -- Booking successful
    ELSE
        RETURN FALSE; -- Slot is already reserved or overlaps
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'An error occurred: %', SQLERRM;
        RETURN FALSE; -- Indicate booking failed due to an error
END;
$$;


ALTER FUNCTION public.book_appointment(p_patient_id integer, p_doctor_id integer, p_slot_id integer, p_appointment_date date) OWNER TO postgres;

--
-- Name: cancel_appointment(integer, integer, integer, date, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancel_appointment(p_slot_id integer, p_doctor_id integer, p_patient_id integer, p_appointment_date date, p_cancellation_reason text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE 
    appointment_exists BOOLEAN;
    v_slot_start_time TIME;
    v_slot_end_time TIME;
BEGIN
    -- Check if the appointment exists
    SELECT EXISTS (
        SELECT 1 
        FROM appointments AS a
        WHERE a.doctor_id = p_doctor_id
          AND a.patient_id = p_patient_id
          AND a.slot_id = p_slot_id
          AND a.appointment_date = p_appointment_date
          AND a.status = 'scheduled'
        FOR UPDATE
    ) INTO appointment_exists;
    
    -- If the appointment doesn't exist, return FALSE
    IF NOT appointment_exists THEN
        RETURN FALSE;
    END IF;
    
    -- Getting the slot start and end times
    SELECT slot_start_time, slot_end_time
    INTO v_slot_start_time, v_slot_end_time
    FROM time_slots
    WHERE time_slot_id = p_slot_id;

    
    -- If the appointment exists, update the appointment to be canceled
    UPDATE appointments
    SET status = 'canceled',
        cancellation_reason = p_cancellation_reason,
        cancellation_timestamp = CURRENT_TIMESTAMP
    WHERE doctor_id = p_doctor_id
      AND patient_id = p_patient_id
      AND slot_id = p_slot_id
      AND appointment_date = p_appointment_date;
    
    -- Log the cancellation in booking_history
    INSERT INTO booking_history (
        doctor_id,
        patient_id,
        appointment_date,
        old_start_time,
        old_end_time,
        action_type,
        action_date,
        cancellation_reason
    )
    VALUES (
        p_doctor_id,
        p_patient_id,
        p_appointment_date,
        v_slot_start_time,
        v_slot_end_time,
        'cancellation',
        CURRENT_TIMESTAMP,
        p_cancellation_reason
    );
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.cancel_appointment(p_slot_id integer, p_doctor_id integer, p_patient_id integer, p_appointment_date date, p_cancellation_reason text) OWNER TO postgres;

--
-- Name: reschedule_appointment(integer, integer, integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reschedule_appointment(p_old_slot_id integer, p_new_slot_id integer, p_doctor_id integer, p_patient_id integer, p_old_date date, p_new_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_slot_available BOOLEAN;
    v_old_slot_start_time TIME;
    v_old_slot_end_time TIME;
    v_new_slot_start_time TIME;
    v_new_slot_end_time TIME;
BEGIN
    -- Check if the old appointment exists and is scheduled, with row-level locking
    IF NOT EXISTS (
        SELECT 1 
        FROM appointments AS a
        WHERE a.doctor_id = p_doctor_id
          AND a.patient_id = p_patient_id
          AND a.appointment_date = p_old_date
          AND a.slot_id = p_old_slot_id
          AND a.status = 'scheduled'
        FOR UPDATE
    ) THEN
        RETURN 'Appointment not found or already rescheduled/canceled.';
    END IF;
     
    -- Check if the new time slot is available on the new date
    SELECT NOT EXISTS (
        SELECT 1
        FROM appointments AS a
        WHERE a.doctor_id = p_doctor_id
          AND a.slot_id = p_new_slot_id
          AND a.appointment_date = p_new_date
          AND a.status = 'scheduled'
    ) INTO v_slot_available;
    
    -- If the new slot is not available, return an error message
    IF NOT v_slot_available THEN
        RETURN 'The new time slot is already booked.';
    END IF;

    -- Getting the start and end times for the old and new slots
    SELECT slot_start_time, slot_end_time
    INTO v_old_slot_start_time, v_old_slot_end_time
    FROM time_slots
    WHERE time_slot_id = p_old_slot_id;
    
    SELECT slot_start_time, slot_end_time
    INTO v_new_slot_start_time, v_new_slot_end_time
    FROM time_slots
    WHERE time_slot_id = p_new_slot_id;
    
    -- Update the appointment with the new slot and date
    UPDATE appointments
    SET slot_id = p_new_slot_id,
        appointment_date = p_new_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE doctor_id = p_doctor_id
      AND patient_id = p_patient_id
      AND appointment_date = p_old_date
      AND slot_id = p_old_slot_id;
      
    -- Log the rescheduling action in booking_history
    INSERT INTO booking_history(
        doctor_id,
        patient_id,
        appointment_date,
        old_start_time,
        old_end_time,
        new_date,
        new_start_time,
        new_end_time,
        action_type,
        action_date
    )
    VALUES (
        p_doctor_id,
        p_patient_id,
        p_old_date,
        v_old_slot_start_time,
        v_old_slot_end_time,
        p_new_date,
        v_new_slot_start_time,
        v_new_slot_end_time,
        'rescheduling',
        CURRENT_TIMESTAMP
    );
    
    RETURN 'Appointment successfully rescheduled.';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'An error occurred: %', SQLERRM;
        RETURN 'An error occurred while rescheduling the appointment.';
END;
$$;


ALTER FUNCTION public.reschedule_appointment(p_old_slot_id integer, p_new_slot_id integer, p_doctor_id integer, p_patient_id integer, p_old_date date, p_new_date date) OWNER TO postgres;

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
    consultation_type public.consultation_type_enum NOT NULL,
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
    old_start_time time without time zone NOT NULL,
    old_end_time time without time zone NOT NULL,
    new_start_time time without time zone,
    new_end_time time without time zone,
    cancellation_reason text,
    action_date timestamp with time zone DEFAULT now(),
    patient_id integer NOT NULL,
    doctor_id integer NOT NULL,
    appointment_date date NOT NULL,
    new_date date
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
    consultation_id integer DEFAULT nextval('public.consultationrecords_conultation_id_seq'::regclass) NOT NULL,
    doctor_id integer NOT NULL,
    patient_id integer NOT NULL,
    consultation_note text,
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
    date_of_birth date,
    gender character varying(20),
    phone_number text NOT NULL,
    age integer,
    hospital text,
    national_id bigint NOT NULL,
    verification_image_url text,
    doctor_id integer DEFAULT nextval('public.doctors_doctor_id_seq'::regclass) NOT NULL,
    timezone character varying(50),
    specialization character varying(255),
    experience integer,
    slot_duration interval,
    working_hours jsonb,
    available_days jsonb,
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
    date_of_birth date,
    gender character varying(10) NOT NULL,
    phone_number text,
    follow_up boolean,
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
    ADD CONSTRAINT consultation_records_pkey PRIMARY KEY (consultation_id);


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
-- Name: doctors unique_doctors_email; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT unique_doctors_email UNIQUE (email);


--
-- Name: patients unique_patients_email; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT unique_patients_email UNIQUE (email);


--
-- Name: consultation_records_doctor_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX consultation_records_doctor_id_idx ON public.consultation_records USING btree (doctor_id);


--
-- Name: consultation_records_patient_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX consultation_records_patient_id_idx ON public.consultation_records USING btree (patient_id);


--
-- Name: doctors_experience_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX doctors_experience_idx ON public.doctors USING btree (experience);


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
-- Name: idx_booking_history_action_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_booking_history_action_date ON public.booking_history USING btree (action_date);


--
-- Name: idx_booking_history_action_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_booking_history_action_type ON public.booking_history USING btree (action_type);


--
-- Name: idx_booking_history_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_booking_history_date ON public.booking_history USING btree (appointment_date);


--
-- Name: idx_time_slots; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_time_slots ON public.time_slots USING btree (doctor_id, slot_start_time);


--
-- Name: payment_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX payment_status_idx ON public.billings USING btree (payment_status);


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
    ADD CONSTRAINT time_slots_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(doctor_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

