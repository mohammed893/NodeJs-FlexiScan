-- PostgreSQL database dump

-- Create a database if it doesn't exist
CREATE DATABASE physicaltheraby;

-- Connect to the created database
\c physicaltheraby;

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

-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

-- Name: doctors_doctor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres

CREATE SEQUENCE public.doctors_doctor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.doctors_doctor_id_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

-- Name: doctors; Type: TABLE; Schema: public; Owner: postgres

CREATE TABLE public.doctors (
    full_name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    date_of_birth date NOT NULL,
    gender character varying(6) NOT NULL,
    phone_number text NOT NULL,
    age integer NOT NULL,
    hospital text,
    national_id integer NOT NULL,
    verification_image_url text,
    doctor_id integer DEFAULT nextval('public.doctors_doctor_id_seq'::regclass) NOT NULL
);

ALTER TABLE public.doctors OWNER TO postgres;

-- Name: patients_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres

CREATE SEQUENCE public.patients_patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.patients_patient_id_seq OWNER TO postgres;

-- Name: patients; Type: TABLE; Schema: public; Owner: postgres

CREATE TABLE public.patients (
    patient_id integer DEFAULT nextval('public.patients_patient_id_seq'::regclass) NOT NULL,
    full_name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    date_of_birth date NOT NULL,
    gender character varying(6) NOT NULL,
    phone_number text NOT NULL,
    follow_up boolean NOT NULL
);

ALTER TABLE public.patients OWNER TO postgres;

-- Data for Name: doctors; Type: TABLE DATA; Schema: public; Owner: postgres

-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres

-- Name: doctors_doctor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres

SELECT pg_catalog.setval('public.doctors_doctor_id_seq', 1, false);

-- Name: patients_patient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres

SELECT pg_catalog.setval('public.patients_patient_id_seq', 1, false);

-- Name: doctors doctors_doctor_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_doctor_id_pkey PRIMARY KEY (doctor_id);

-- Name: doctors doctors_national_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_national_id_key UNIQUE (national_id);

-- Name: patients patients_patien_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_patien_id_pkey PRIMARY KEY (patient_id);

-- PostgreSQL database dump complete
