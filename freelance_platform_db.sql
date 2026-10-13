--
-- PostgreSQL database dump
--

\restrict f6hK228UEArZokrF5XwvC3YKhoWODEpaE26mL3JK2Eq8qkN8A4Xt9igt7tctuRK

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-10-13 21:12:02

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 270 (class 1255 OID 16785)
-- Name: count_active_jobs(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.count_active_jobs(p_client_id integer) RETURNS bigint
    LANGUAGE sql STABLE
    AS $$
    SELECT COUNT(*)
    FROM jobs
    WHERE client_id = p_client_id
      AND deleted_at IS NULL;
$$;


ALTER FUNCTION public.count_active_jobs(p_client_id integer) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 16786)
-- Name: count_active_proposals(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.count_active_proposals(p_job_id integer) RETURNS bigint
    LANGUAGE sql STABLE
    AS $$
    SELECT COUNT(*)
    FROM proposals
    WHERE job_id = p_job_id
      AND deleted_at IS NULL;
$$;


ALTER FUNCTION public.count_active_proposals(p_job_id integer) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 24614)
-- Name: create_contract(integer, timestamp with time zone, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.create_contract(IN p_proposal_id integer, IN p_start_date timestamp with time zone, IN p_price numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_job_id INTEGER;
    v_freelancer_id INTEGER;
    v_client_id INTEGER;
BEGIN
    IF p_price IS NULL OR p_price < 0 THEN
        RAISE EXCEPTION 'The contract price should be greater than or equal to 0.';
    END IF;

    SELECT
        p.job_id,
        p.freelancer_id,
        j.client_id
    INTO
        v_job_id,
        v_freelancer_id,
        v_client_id
    FROM proposals p
    JOIN jobs j ON j.id = p.job_id
    JOIN freelancer_profiles f ON f.id = p.freelancer_id
    JOIN client_profiles c ON c.id = j.client_id
    WHERE p.id = p_proposal_id
      AND p.deleted_at IS NULL
      AND j.deleted_at IS NULL
      AND f.deleted_at IS NULL
      AND c.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to conclude the contract: the active offer, vacancy, or profile of one of the participants was not found or has been deleted.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM contracts
        WHERE proposal_id = p_proposal_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'There is an active contract for this proposal.';
    END IF;

    INSERT INTO contracts (
        job_id,
        proposal_id,
        client_id,
        freelancer_id,
        start_date,
        price
    )
    VALUES (
        v_job_id,
        p_proposal_id,
        v_client_id,
        v_freelancer_id,
        p_start_date,
        p_price
    );
END;
$$;


ALTER PROCEDURE public.create_contract(IN p_proposal_id integer, IN p_start_date timestamp with time zone, IN p_price numeric) OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 24602)
-- Name: create_job(integer, integer, character varying, numeric, character varying, integer, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.create_job(IN p_client_id integer, IN p_category_id integer, IN p_title character varying, IN p_price numeric, IN p_employment_type character varying, IN p_freelancers_count integer, IN p_description text, OUT p_job_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM client_profiles
        WHERE id = p_client_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'The active client profile % is not found.',
            p_client_id;
    END IF;

    IF p_price IS NULL OR p_price <= 0 THEN
        RAISE EXCEPTION
            'The vacancy price should be greater than or equal 0.';
    END IF;

    INSERT INTO jobs (
        client_id,
        category_id,
        title,
        price,
        employment_type,
        freelancers_count,
        description
    )
    VALUES (
        p_client_id,
        p_category_id,
        p_title,
        p_price,
        p_employment_type,
        p_freelancers_count,
        p_description
    )
    RETURNING id INTO p_job_id;
END;
$$;


ALTER PROCEDURE public.create_job(IN p_client_id integer, IN p_category_id integer, IN p_title character varying, IN p_price numeric, IN p_employment_type character varying, IN p_freelancers_count integer, IN p_description text, OUT p_job_id integer) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 16787)
-- Name: get_freelancer_rating(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_freelancer_rating(p_freelancer_id integer) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
    SELECT ROUND(AVG(r.client_rating)::NUMERIC, 2)
    FROM contracts c
    JOIN reviews r ON r.contract_id = c.id
    WHERE c.freelancer_id = p_freelancer_id
      AND c.deleted_at IS NULL
      AND r.client_rating IS NOT NULL;
$$;


ALTER FUNCTION public.get_freelancer_rating(p_freelancer_id integer) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 16792)
-- Name: notify_client_new_proposal(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_client_new_proposal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_client_user_id INTEGER;
BEGIN
    SELECT cp.user_id
    INTO v_client_user_id
    FROM jobs j
    JOIN client_profiles cp ON cp.id = j.client_id
    WHERE j.id = NEW.job_id;

    IF v_client_user_id IS NOT NULL THEN
        INSERT INTO notifications (
            user_id,
            message
        )
        VALUES (
            v_client_user_id,
            'A new proposal has been received for your vacancy.'
                || NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_client_new_proposal() OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 16794)
-- Name: notify_freelancer_new_interview(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_freelancer_new_interview() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_freelancer_user_id INTEGER;
BEGIN
    SELECT fp.user_id
    INTO v_freelancer_user_id
    FROM proposals p
    JOIN freelancer_profiles fp
        ON fp.id = p.freelancer_id
    WHERE p.id = NEW.proposal_id;

    IF v_freelancer_user_id IS NOT NULL THEN
        INSERT INTO notifications (
            user_id,
            message
        )
        VALUES (
            v_freelancer_user_id,
            'The interview is scheduled. The vacancy №'
                || NEW.job_id
                || ', the round №'
                || NEW.round_number
        );
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_freelancer_new_interview() OWNER TO postgres;

--
-- TOC entry 269 (class 1255 OID 16779)
-- Name: schedule_interview(integer, integer, integer, timestamp without time zone, character varying, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.schedule_interview(IN p_job_id integer, IN p_proposal_id integer, IN p_round_number integer, IN p_interview_date timestamp without time zone, IN p_link character varying, IN p_message text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_round_number IS NULL OR p_round_number <= 0 THEN
        RAISE EXCEPTION 'The round number should be greater than 0.';
    END IF;

    IF p_interview_date IS NULL THEN
        RAISE EXCEPTION 'The interview date is necessary.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM proposals
        WHERE id = p_proposal_id
          AND job_id = p_job_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'The proposal does not apply to the specified vacancy.';
    END IF;

    INSERT INTO interviews (
        job_id,
        proposal_id,
        round_number,
        interview_date,
        link,
        message_for_freelancer
    )
    VALUES (
        p_job_id,
        p_proposal_id,
        p_round_number,
        p_interview_date,
        p_link,
        p_message
    );
END;
$$;


ALTER PROCEDURE public.schedule_interview(IN p_job_id integer, IN p_proposal_id integer, IN p_round_number integer, IN p_interview_date timestamp without time zone, IN p_link character varying, IN p_message text) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 16788)
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

--
-- TOC entry 271 (class 1255 OID 24603)
-- Name: submit_proposal(integer, integer, numeric, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.submit_proposal(IN p_job_id integer, IN p_freelancer_id integer, IN p_price numeric, IN p_cover_letter text, OUT p_proposal_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_price IS NULL OR p_price <= 0 THEN
        RAISE EXCEPTION
            'The proposal price should be greater than or equal 0.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM jobs
        WHERE id = p_job_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'The active vacancy % is not found.', p_job_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM freelancer_profiles
        WHERE id = p_freelancer_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'The active freelancer profile % is not found.',
            p_freelancer_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM proposals
        WHERE job_id = p_job_id
          AND freelancer_id = p_freelancer_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'The active proposal for this vacancy already exists.';
    END IF;

    INSERT INTO proposals (
        job_id,
        freelancer_id,
        price,
        cover_letter
    )
    VALUES (
        p_job_id,
        p_freelancer_id,
        p_price,
        p_cover_letter
    )
    RETURNING id INTO p_proposal_id;
END;
$$;


ALTER PROCEDURE public.submit_proposal(IN p_job_id integer, IN p_freelancer_id integer, IN p_price numeric, IN p_cover_letter text, OUT p_proposal_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16413)
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16461)
-- Name: client_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.client_profiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    company_name character varying(255) NOT NULL,
    hiring_percentage numeric(5,2),
    avg_hourly_rate numeric(12,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    updated_by integer,
    deleted_at timestamp without time zone,
    CONSTRAINT client_profiles_avg_hourly_rate_check CHECK ((avg_hourly_rate >= (0)::numeric)),
    CONSTRAINT client_profiles_hiring_percentage_check CHECK (((hiring_percentage >= (0)::numeric) AND (hiring_percentage <= (100)::numeric)))
);


ALTER TABLE public.client_profiles OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16533)
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    id integer NOT NULL,
    client_id integer NOT NULL,
    category_id integer,
    title character varying(255) NOT NULL,
    price numeric(12,2) NOT NULL,
    employment_type character varying(30),
    freelancers_count integer,
    description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    updated_by integer,
    deleted_at timestamp without time zone,
    CONSTRAINT chk_jobs_price_non_negative CHECK ((price >= (0)::numeric)),
    CONSTRAINT jobs_freelancers_count_check CHECK ((freelancers_count > 0))
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 24589)
-- Name: active_jobs_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.active_jobs_view AS
 SELECT j.id AS job_id,
    j.title,
    j.description,
    j.price,
    j.employment_type,
    j.freelancers_count,
    j.created_at,
    cp.id AS client_id,
    cp.company_name,
    cat.id AS category_id,
    cat.name AS category_name
   FROM ((public.jobs j
     JOIN public.client_profiles cp ON ((cp.id = j.client_id)))
     LEFT JOIN public.categories cat ON ((cat.id = j.category_id)))
  WHERE ((j.deleted_at IS NULL) AND (cp.deleted_at IS NULL));


ALTER VIEW public.active_jobs_view OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16486)
-- Name: freelancer_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.freelancer_profiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    hourly_rate numeric(12,2),
    education text,
    category_id integer,
    employment_type character varying(30),
    description text,
    portfolio text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    updated_by integer,
    deleted_at timestamp without time zone,
    CONSTRAINT freelancer_profiles_hourly_rate_check CHECK ((hourly_rate >= (0)::numeric))
);


ALTER TABLE public.freelancer_profiles OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16583)
-- Name: proposals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposals (
    id integer NOT NULL,
    job_id integer NOT NULL,
    freelancer_id integer NOT NULL,
    price numeric(12,2) NOT NULL,
    cover_letter text,
    submitted_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone,
    CONSTRAINT chk_proposals_price_non_negative CHECK ((price >= (0)::numeric))
);


ALTER TABLE public.proposals OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16435)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    role_id integer NOT NULL,
    email character varying(254) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    country character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    updated_by integer,
    deleted_at timestamp without time zone
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 24584)
-- Name: active_proposals_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.active_proposals_view AS
 SELECT p.id AS proposal_id,
    p.job_id,
    j.title AS job_title,
    p.freelancer_id,
    u.first_name,
    u.last_name,
    p.price AS proposed_price,
    p.cover_letter,
    p.submitted_at
   FROM (((public.proposals p
     JOIN public.jobs j ON ((j.id = p.job_id)))
     JOIN public.freelancer_profiles fp ON ((fp.id = p.freelancer_id)))
     JOIN public.users u ON ((u.id = fp.user_id)))
  WHERE ((p.deleted_at IS NULL) AND (j.deleted_at IS NULL) AND (fp.deleted_at IS NULL) AND (u.deleted_at IS NULL));


ALTER VIEW public.active_proposals_view OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16412)
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.categories ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 16460)
-- Name: client_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.client_profiles ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.client_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 244 (class 1259 OID 16693)
-- Name: contract_milestones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contract_milestones (
    id integer NOT NULL,
    contract_id integer NOT NULL,
    title character varying(255) NOT NULL,
    amount numeric(12,2) NOT NULL,
    due_date timestamp without time zone,
    status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    CONSTRAINT contract_milestones_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT contract_milestones_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.contract_milestones OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16692)
-- Name: contract_milestones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.contract_milestones ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.contract_milestones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 242 (class 1259 OID 16662)
-- Name: contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contracts (
    id integer NOT NULL,
    job_id integer NOT NULL,
    proposal_id integer NOT NULL,
    client_id integer NOT NULL,
    freelancer_id integer NOT NULL,
    start_date timestamp without time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    updated_by integer,
    deleted_at timestamp without time zone,
    CONSTRAINT chk_contracts_price_non_negative CHECK ((price >= (0)::numeric))
);


ALTER TABLE public.contracts OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 16661)
-- Name: contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.contracts ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 229 (class 1259 OID 16485)
-- Name: freelancer_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.freelancer_profiles ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.freelancer_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 16515)
-- Name: freelancer_skills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.freelancer_skills (
    freelancer_id integer NOT NULL,
    skill_id integer NOT NULL
);


ALTER TABLE public.freelancer_skills OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16634)
-- Name: interviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.interviews (
    id integer NOT NULL,
    job_id integer NOT NULL,
    proposal_id integer NOT NULL,
    round_number integer NOT NULL,
    interview_date timestamp without time zone NOT NULL,
    link character varying(2048),
    message_for_freelancer text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone,
    CONSTRAINT interviews_round_number_check CHECK ((round_number > 0))
);


ALTER TABLE public.interviews OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16633)
-- Name: interviews_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.interviews ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.interviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 234 (class 1259 OID 16565)
-- Name: job_skills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_skills (
    job_id integer NOT NULL,
    skill_id integer NOT NULL
);


ALTER TABLE public.job_skills OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16532)
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.jobs ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 248 (class 1259 OID 16733)
-- Name: mentorships; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mentorships (
    id integer NOT NULL,
    mentor_id integer NOT NULL,
    mentee_id integer NOT NULL,
    price numeric(12,2),
    start_date timestamp without time zone NOT NULL,
    CONSTRAINT chk_mentorship_different_users CHECK ((mentor_id <> mentee_id)),
    CONSTRAINT mentorships_price_check CHECK ((price >= (0)::numeric))
);


ALTER TABLE public.mentorships OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 16732)
-- Name: mentorships_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.mentorships ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.mentorships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 250 (class 1259 OID 16755)
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 16754)
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.notifications ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 235 (class 1259 OID 16582)
-- Name: proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.proposals ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.proposals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 246 (class 1259 OID 16712)
-- Name: reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reviews (
    id integer NOT NULL,
    contract_id integer NOT NULL,
    client_review text,
    client_rating integer,
    freelancer_review text,
    freelancer_rating integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT reviews_client_rating_check CHECK (((client_rating >= 1) AND (client_rating <= 5))),
    CONSTRAINT reviews_freelancer_rating_check CHECK (((freelancer_rating >= 1) AND (freelancer_rating <= 5)))
);


ALTER TABLE public.reviews OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16711)
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.reviews ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 16401)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(30) NOT NULL,
    description text
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16400)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 16425)
-- Name: skills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.skills (
    id integer NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.skills OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16424)
-- Name: skills_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.skills ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 238 (class 1259 OID 16612)
-- Name: test_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_tasks (
    id integer NOT NULL,
    job_id integer NOT NULL,
    proposal_id integer,
    task_number character varying(50),
    description text,
    deadline timestamp without time zone,
    result text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone
);


ALTER TABLE public.test_tasks OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16611)
-- Name: test_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.test_tasks ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.test_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 225 (class 1259 OID 16434)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 5220 (class 0 OID 16413)
-- Dependencies: 222
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categories (id, name, description) FROM stdin;
1	Web Development	Website and web application development
2	UI/UX Design	User interface and user experience design
3	Data Science	Data analysis and machine learning
4	Mobile Development	Mobile application development
5	Content Writing	Articles, documentation and copywriting
\.


--
-- TOC entry 5226 (class 0 OID 16461)
-- Dependencies: 228
-- Data for Name: client_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.client_profiles (id, user_id, company_name, hiring_percentage, avg_hourly_rate, created_at, updated_at, updated_by, deleted_at) FROM stdin;
1	2	Maple Leaf Creative	85.00	52.00	2026-10-11 13:54:56.959251	\N	\N	\N
2	3	Northstar Digital	60.00	38.50	2026-10-11 13:54:56.959251	\N	\N	\N
3	4	BrightTech Solutions	75.00	45.00	2026-10-11 13:54:56.959251	\N	\N	\N
\.


--
-- TOC entry 5242 (class 0 OID 16693)
-- Dependencies: 244
-- Data for Name: contract_milestones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contract_milestones (id, contract_id, title, amount, due_date, status) FROM stdin;
1	2	High-fidelity UI design	1200.00	2026-11-10 18:00:00	in_progress
2	2	User research and wireframes	450.00	2026-10-15 18:00:00	completed
3	1	Product catalog and shopping cart	1200.00	2026-11-05 18:00:00	in_progress
4	1	Checkout and final delivery	1500.00	2026-11-25 18:00:00	pending
5	1	Requirements and project setup	500.00	2026-10-10 18:00:00	completed
\.


--
-- TOC entry 5240 (class 0 OID 16662)
-- Dependencies: 242
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (id, job_id, proposal_id, client_id, freelancer_id, start_date, price, created_at, updated_at, updated_by, deleted_at) FROM stdin;
1	1	1	3	1	2026-10-01 09:00:00	3200.00	2026-10-11 16:22:32.818827	\N	\N	\N
2	4	4	2	2	2026-10-05 09:00:00	1650.00	2026-10-11 16:22:32.818827	\N	\N	\N
3	7	6	2	5	2026-10-11 00:00:00	450.00	2026-10-11 21:12:52.228513	\N	\N	\N
4	14	12	2	4	2026-10-12 22:03:40.037384	2900.00	2026-10-12 22:03:40.041995	\N	\N	\N
5	16	14	2	4	2026-10-13 20:44:16.755258	2900.00	2026-10-13 20:44:16.757004	\N	\N	\N
\.


--
-- TOC entry 5228 (class 0 OID 16486)
-- Dependencies: 230
-- Data for Name: freelancer_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.freelancer_profiles (id, user_id, hourly_rate, education, category_id, employment_type, description, portfolio, created_at, updated_at, updated_by, deleted_at) FROM stdin;
1	9	45.00	BSc in Computer Science	1	Freelance	Full-stack developer specializing in modern web applications.	https://example.com/oliver-portfolio	2026-10-11 13:54:56.959251	\N	\N	\N
2	8	40.00	BA in Graphic Design	2	Part-time	UI/UX designer focused on accessible and user-friendly interfaces.	https://example.com/mia-portfolio	2026-10-11 13:54:56.959251	\N	\N	\N
3	7	55.00	MSc in Data Science	3	Freelance	Data scientist experienced in analytics and machine learning.	https://example.com/noah-portfolio	2026-10-11 13:54:56.959251	\N	\N	\N
4	6	48.00	BSc in Software Engineering	4	Full-time	Mobile developer building Android and cross-platform applications.	https://example.com/sophia-portfolio	2026-10-11 13:54:56.959251	\N	\N	\N
5	5	32.00	BA in English Literature	5	Part-time	Technical writer creating clear documentation and SEO-friendly content.	https://example.com/liam-portfolio	2026-10-11 13:54:56.959251	\N	\N	\N
\.


--
-- TOC entry 5229 (class 0 OID 16515)
-- Dependencies: 231
-- Data for Name: freelancer_skills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.freelancer_skills (freelancer_id, skill_id) FROM stdin;
1	15
1	4
1	3
1	2
1	1
2	8
2	7
2	6
3	10
3	9
3	4
3	1
4	12
4	11
4	4
5	14
5	13
\.


--
-- TOC entry 5238 (class 0 OID 16634)
-- Dependencies: 240
-- Data for Name: interviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.interviews (id, job_id, proposal_id, round_number, interview_date, link, message_for_freelancer, created_at, updated_at, deleted_at) FROM stdin;
1	2	2	1	2026-11-20 14:00:00	https://example.com/meet/data-interview	Please prepare to discuss your analytics workflow and previous projects.	2026-10-11 16:22:32.818827	\N	\N
2	4	4	1	2026-11-21 10:30:00	https://example.com/meet/design-interview	Please bring two examples of your design work.	2026-10-11 16:22:32.818827	\N	\N
\.


--
-- TOC entry 5232 (class 0 OID 16565)
-- Dependencies: 234
-- Data for Name: job_skills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.job_skills (job_id, skill_id) FROM stdin;
2	1
1	2
1	3
2	4
1	4
1	6
4	7
4	8
2	10
5	11
5	12
3	13
3	14
\.


--
-- TOC entry 5231 (class 0 OID 16533)
-- Dependencies: 233
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jobs (id, client_id, category_id, title, price, employment_type, freelancers_count, description, created_at, updated_at, updated_by, deleted_at) FROM stdin;
1	3	1	Build an E-commerce Website	3500.00	contract	1	Develop a responsive online store with product pages, shopping cart, and secure checkout.	2026-10-11 16:21:28.251029	\N	\N	\N
2	3	3	Customer Analytics Dashboard	2200.00	contract	1	Build a dashboard that helps the business understand customer behavior and sales trends.	2026-10-11 16:21:28.251029	\N	\N	\N
3	1	5	Write Technical Documentation	900.00	contract	1	Prepare clear technical documentation and onboarding guides for a software product.	2026-10-11 16:21:28.251029	\N	\N	\N
4	2	2	Redesign a SaaS Application	1800.00	contract	1	Improve the user experience and create a consistent design system for a SaaS platform.	2026-10-11 16:21:28.251029	\N	\N	\N
5	2	4	Create a Habit Tracking App	4200.00	contract	2	Develop a mobile application for tracking habits, setting goals, and viewing progress.	2026-10-11 16:21:28.251029	\N	\N	\N
6	2	5	Test C# Job	500.00	Full-time	1	Test job created from C#	2026-10-11 20:57:45.042052	\N	\N	\N
7	2	5	Test C# Job	500.00	Full-time	1	Test job created from C#	2026-10-11 20:58:25.840049	\N	\N	\N
8	2	5	Test C# Job	500.00	Full-time	1	Test job created from C#	2026-10-11 20:59:58.598786	\N	\N	\N
9	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-12 21:37:35.753645	\N	\N	\N
10	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-12 21:41:45.908996	\N	\N	\N
11	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-12 21:55:25.01543	\N	\N	\N
12	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-12 21:55:39.817593	\N	\N	\N
13	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-12 21:59:40.885092	\N	\N	\N
14	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-12 22:03:40.023209	\N	\N	\N
15	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-13 20:41:38.303394	\N	\N	\N
16	2	1	Fullstack .NET & PostgreSQL Developer	3000.00	Remote	1	Backend development utilizing ADO.NET and complex database constraints.	2026-10-13 20:44:16.739521	\N	\N	\N
\.


--
-- TOC entry 5246 (class 0 OID 16733)
-- Dependencies: 248
-- Data for Name: mentorships; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mentorships (id, mentor_id, mentee_id, price, start_date) FROM stdin;
1	3	1	60.00	2026-10-12 12:00:00
\.


--
-- TOC entry 5248 (class 0 OID 16755)
-- Dependencies: 250
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, message, is_read, created_at) FROM stdin;
1	4	A new proposal has been received for your vacancy.1	f	2026-10-11 16:21:28.251029
2	4	A new proposal has been received for your vacancy.2	f	2026-10-11 16:21:28.251029
3	2	A new proposal has been received for your vacancy.3	f	2026-10-11 16:21:28.251029
4	3	A new proposal has been received for your vacancy.4	f	2026-10-11 16:21:28.251029
5	3	A new proposal has been received for your vacancy.5	f	2026-10-11 16:21:28.251029
6	7	The interview is scheduled. The vacancy №2, the round №1	f	2026-10-11 16:22:32.818827
7	8	The interview is scheduled. The vacancy №4, the round №1	f	2026-10-11 16:22:32.818827
8	9	Welcome to Freelance Platform! Complete your portfolio to attract clients.	f	2026-10-11 16:22:32.818827
9	4	Welcome to Freelance Platform! Your client profile is ready.	f	2026-10-11 16:22:32.818827
10	7	You have an upcoming interview for Customer Analytics Dashboard.	f	2026-10-11 16:22:32.818827
11	3	A new proposal has been received for your vacancy.6	f	2026-10-11 21:07:23.400162
12	3	A new proposal has been received for your vacancy.7	f	2026-10-12 21:37:35.77032
13	3	A new proposal has been received for your vacancy.8	f	2026-10-12 21:41:45.917151
14	3	A new proposal has been received for your vacancy.9	f	2026-10-12 21:55:25.023321
15	3	A new proposal has been received for your vacancy.10	f	2026-10-12 21:55:39.8236
16	3	A new proposal has been received for your vacancy.11	f	2026-10-12 21:59:40.893912
17	3	A new proposal has been received for your vacancy.12	f	2026-10-12 22:03:40.029468
18	3	A new proposal has been received for your vacancy.13	f	2026-10-13 20:41:38.320526
19	3	A new proposal has been received for your vacancy.14	f	2026-10-13 20:44:16.747171
\.


--
-- TOC entry 5234 (class 0 OID 16583)
-- Dependencies: 236
-- Data for Name: proposals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposals (id, job_id, freelancer_id, price, cover_letter, submitted_at, updated_at, deleted_at) FROM stdin;
1	1	1	3200.00	I have experience building responsive e-commerce platforms with React and PostgreSQL. I can deliver a maintainable solution with a smooth checkout experience.	2026-10-11 16:21:28.251029	\N	\N
2	2	3	2000.00	I specialize in Python, data analysis, and machine learning. I can build a clear dashboard with meaningful business metrics.	2026-10-11 16:21:28.251029	\N	\N
3	3	5	800.00	I can turn complex technical concepts into clear documentation, onboarding guides, and practical examples.	2026-10-11 16:21:28.251029	\N	\N
4	4	2	1650.00	I can improve your product experience through user research, Figma prototypes, and a consistent design system.	2026-10-11 16:21:28.251029	\N	\N
5	5	4	3900.00	I develop mobile applications with a focus on usability, reliable performance, and maintainable code.	2026-10-11 16:21:28.251029	\N	\N
6	7	5	450.00	Test proposal from C#	2026-10-11 21:07:23.400162	\N	\N
7	9	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-12 21:37:35.77032	\N	\N
8	10	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-12 21:41:45.917151	\N	\N
9	11	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-12 21:55:25.023321	\N	\N
10	12	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-12 21:55:39.8236	\N	\N
11	13	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-12 21:59:40.893912	\N	\N
12	14	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-12 22:03:40.029468	\N	\N
13	15	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-13 20:41:38.320526	\N	\N
14	16	4	2900.00	I have extensive experience in relational database design and C#.	2026-10-13 20:44:16.747171	\N	\N
\.


--
-- TOC entry 5244 (class 0 OID 16712)
-- Dependencies: 246
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reviews (id, contract_id, client_review, client_rating, freelancer_review, freelancer_rating, created_at, updated_at) FROM stdin;
1	1	Oliver communicated clearly and delivered a strong project foundation.	5	The client provided clear requirements and timely feedback.	5	2026-10-11 16:22:32.818827	\N
2	2	Mia created a clean and intuitive interface. The collaboration was smooth.	5	The project goals were well defined and communication was professional.	4	2026-10-11 16:22:32.818827	\N
\.


--
-- TOC entry 5218 (class 0 OID 16401)
-- Dependencies: 220
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, name, description) FROM stdin;
1	admin	Platform administrator
2	client	User who publishes jobs
3	freelancer	User who provides freelance services
\.


--
-- TOC entry 5222 (class 0 OID 16425)
-- Dependencies: 224
-- Data for Name: skills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.skills (id, name) FROM stdin;
1	Python
2	JavaScript
3	React
4	PostgreSQL
5	HTML
6	CSS
7	Figma
8	UI Design
9	Machine Learning
10	Data Analysis
11	Java
12	Kotlin
13	Technical Writing
14	SEO
15	Docker
\.


--
-- TOC entry 5236 (class 0 OID 16612)
-- Dependencies: 238
-- Data for Name: test_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_tasks (id, job_id, proposal_id, task_number, description, deadline, result, created_at, updated_at, deleted_at) FROM stdin;
1	2	2	DATA-TEST-001	Analyze a sample sales dataset and summarize three key trends.	2026-11-18 18:00:00	\N	2026-10-11 16:22:32.818827	\N	\N
2	1	1	WEB-TEST-001	Create a responsive product listing page with filtering.	2026-11-15 18:00:00	Submitted a working React prototype.	2026-10-11 16:22:32.818827	\N	\N
\.


--
-- TOC entry 5224 (class 0 OID 16435)
-- Dependencies: 226
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, role_id, email, password_hash, first_name, last_name, country, created_at, updated_at, updated_by, deleted_at) FROM stdin;
1	1	admin@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Alex	Morgan	United States	2026-10-11 13:54:56.959251	\N	\N	\N
2	2	emily.brown@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Emily	Brown	Canada	2026-10-11 13:54:56.959251	\N	\N	\N
3	2	david.wilson@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	David	Wilson	United Kingdom	2026-10-11 13:54:56.959251	\N	\N	\N
4	2	sarah.johnson@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Sarah	Johnson	United States	2026-10-11 13:54:56.959251	\N	\N	\N
5	3	liam.taylor@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Liam	Taylor	Ireland	2026-10-11 13:54:56.959251	\N	\N	\N
6	3	sophia.wilson@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Sophia	Wilson	Australia	2026-10-11 13:54:56.959251	\N	\N	\N
7	3	noah.miller@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Noah	Miller	Canada	2026-10-11 13:54:56.959251	\N	\N	\N
8	3	mia.davis@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Mia	Davis	United States	2026-10-11 13:54:56.959251	\N	\N	\N
9	3	oliver.smith@example.com	TEST_ONLY_NOT_A_REAL_PASSWORD_HASH	Oliver	Smith	United Kingdom	2026-10-11 13:54:56.959251	\N	\N	\N
\.


--
-- TOC entry 5254 (class 0 OID 0)
-- Dependencies: 221
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categories_id_seq', 5, true);


--
-- TOC entry 5255 (class 0 OID 0)
-- Dependencies: 227
-- Name: client_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.client_profiles_id_seq', 3, true);


--
-- TOC entry 5256 (class 0 OID 0)
-- Dependencies: 243
-- Name: contract_milestones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contract_milestones_id_seq', 5, true);


--
-- TOC entry 5257 (class 0 OID 0)
-- Dependencies: 241
-- Name: contracts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contracts_id_seq', 5, true);


--
-- TOC entry 5258 (class 0 OID 0)
-- Dependencies: 229
-- Name: freelancer_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.freelancer_profiles_id_seq', 5, true);


--
-- TOC entry 5259 (class 0 OID 0)
-- Dependencies: 239
-- Name: interviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.interviews_id_seq', 2, true);


--
-- TOC entry 5260 (class 0 OID 0)
-- Dependencies: 232
-- Name: jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.jobs_id_seq', 16, true);


--
-- TOC entry 5261 (class 0 OID 0)
-- Dependencies: 247
-- Name: mentorships_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mentorships_id_seq', 1, true);


--
-- TOC entry 5262 (class 0 OID 0)
-- Dependencies: 249
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 19, true);


--
-- TOC entry 5263 (class 0 OID 0)
-- Dependencies: 235
-- Name: proposals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposals_id_seq', 14, true);


--
-- TOC entry 5264 (class 0 OID 0)
-- Dependencies: 245
-- Name: reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reviews_id_seq', 2, true);


--
-- TOC entry 5265 (class 0 OID 0)
-- Dependencies: 219
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 3, true);


--
-- TOC entry 5266 (class 0 OID 0)
-- Dependencies: 223
-- Name: skills_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.skills_id_seq', 15, true);


--
-- TOC entry 5267 (class 0 OID 0)
-- Dependencies: 237
-- Name: test_tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_tasks_id_seq', 2, true);


--
-- TOC entry 5268 (class 0 OID 0)
-- Dependencies: 225
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 9, true);


--
-- TOC entry 4983 (class 2606 OID 16423)
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- TOC entry 4985 (class 2606 OID 16421)
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- TOC entry 4994 (class 2606 OID 16472)
-- Name: client_profiles client_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_pkey PRIMARY KEY (id);


--
-- TOC entry 5025 (class 2606 OID 16705)
-- Name: contract_milestones contract_milestones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_milestones
    ADD CONSTRAINT contract_milestones_pkey PRIMARY KEY (id);


--
-- TOC entry 5021 (class 2606 OID 16676)
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- TOC entry 4997 (class 2606 OID 16497)
-- Name: freelancer_profiles freelancer_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_profiles
    ADD CONSTRAINT freelancer_profiles_pkey PRIMARY KEY (id);


--
-- TOC entry 5000 (class 2606 OID 16521)
-- Name: freelancer_skills freelancer_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_skills
    ADD CONSTRAINT freelancer_skills_pkey PRIMARY KEY (freelancer_id, skill_id);


--
-- TOC entry 5018 (class 2606 OID 16648)
-- Name: interviews interviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT interviews_pkey PRIMARY KEY (id);


--
-- TOC entry 5007 (class 2606 OID 16571)
-- Name: job_skills job_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_skills
    ADD CONSTRAINT job_skills_pkey PRIMARY KEY (job_id, skill_id);


--
-- TOC entry 5003 (class 2606 OID 16547)
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- TOC entry 5031 (class 2606 OID 16743)
-- Name: mentorships mentorships_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mentorships
    ADD CONSTRAINT mentorships_pkey PRIMARY KEY (id);


--
-- TOC entry 5034 (class 2606 OID 16768)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 5009 (class 2606 OID 16596)
-- Name: proposals proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_pkey PRIMARY KEY (id);


--
-- TOC entry 5027 (class 2606 OID 16726)
-- Name: reviews reviews_contract_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_contract_id_key UNIQUE (contract_id);


--
-- TOC entry 5029 (class 2606 OID 16724)
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- TOC entry 4979 (class 2606 OID 16411)
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- TOC entry 4981 (class 2606 OID 16409)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 4987 (class 2606 OID 16433)
-- Name: skills skills_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_name_key UNIQUE (name);


--
-- TOC entry 4989 (class 2606 OID 16431)
-- Name: skills skills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_pkey PRIMARY KEY (id);


--
-- TOC entry 5016 (class 2606 OID 16622)
-- Name: test_tasks test_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_tasks
    ADD CONSTRAINT test_tasks_pkey PRIMARY KEY (id);


--
-- TOC entry 5005 (class 2606 OID 16549)
-- Name: jobs uq_jobs_id_client; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT uq_jobs_id_client UNIQUE (id, client_id);


--
-- TOC entry 5012 (class 2606 OID 16598)
-- Name: proposals uq_proposals_id_job; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT uq_proposals_id_job UNIQUE (id, job_id);


--
-- TOC entry 5014 (class 2606 OID 16600)
-- Name: proposals uq_proposals_id_job_freelancer; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT uq_proposals_id_job_freelancer UNIQUE (id, job_id, freelancer_id);


--
-- TOC entry 4992 (class 2606 OID 16447)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4995 (class 1259 OID 24616)
-- Name: client_profiles_user_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX client_profiles_user_active_idx ON public.client_profiles USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- TOC entry 4998 (class 1259 OID 24617)
-- Name: freelancer_profiles_user_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX freelancer_profiles_user_active_idx ON public.freelancer_profiles USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- TOC entry 5022 (class 1259 OID 16806)
-- Name: idx_contracts_client_start_btree; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_client_start_btree ON public.contracts USING btree (client_id, start_date DESC);


--
-- TOC entry 5001 (class 1259 OID 16808)
-- Name: idx_jobs_search_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_jobs_search_gin ON public.jobs USING gin (to_tsvector('english'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text))));


--
-- TOC entry 5032 (class 1259 OID 16807)
-- Name: idx_notifications_user_read_date_btree; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_read_date_btree ON public.notifications USING btree (user_id, is_read, created_at DESC);


--
-- TOC entry 5019 (class 1259 OID 24618)
-- Name: interviews_proposal_round_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX interviews_proposal_round_active_idx ON public.interviews USING btree (proposal_id, round_number) WHERE (deleted_at IS NULL);


--
-- TOC entry 5023 (class 1259 OID 24613)
-- Name: uq_contracts_active_proposal; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uq_contracts_active_proposal ON public.contracts USING btree (proposal_id) WHERE (deleted_at IS NULL);


--
-- TOC entry 5010 (class 1259 OID 24612)
-- Name: uq_proposals_active_job_freelancer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX uq_proposals_active_job_freelancer ON public.proposals USING btree (job_id, freelancer_id) WHERE (deleted_at IS NULL);


--
-- TOC entry 4990 (class 1259 OID 24615)
-- Name: users_email_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_email_active_idx ON public.users USING btree (email) WHERE (deleted_at IS NULL);


--
-- TOC entry 5067 (class 2620 OID 16791)
-- Name: contracts trg_contracts_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_contracts_updated_at BEFORE UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5066 (class 2620 OID 16795)
-- Name: interviews trg_interview_notification; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_interview_notification AFTER INSERT ON public.interviews FOR EACH ROW EXECUTE FUNCTION public.notify_freelancer_new_interview();


--
-- TOC entry 5064 (class 2620 OID 16793)
-- Name: proposals trg_proposal_notification; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_proposal_notification AFTER INSERT ON public.proposals FOR EACH ROW EXECUTE FUNCTION public.notify_client_new_proposal();


--
-- TOC entry 5065 (class 2620 OID 16790)
-- Name: proposals trg_proposals_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_proposals_updated_at BEFORE UPDATE ON public.proposals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5063 (class 2620 OID 16789)
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5037 (class 2606 OID 16480)
-- Name: client_profiles client_profiles_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 5038 (class 2606 OID 16475)
-- Name: client_profiles client_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5058 (class 2606 OID 16706)
-- Name: contract_milestones contract_milestones_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_milestones
    ADD CONSTRAINT contract_milestones_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- TOC entry 5055 (class 2606 OID 16677)
-- Name: contracts contracts_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 5056 (class 2606 OID 16682)
-- Name: contracts fk_contracts_job_client; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT fk_contracts_job_client FOREIGN KEY (job_id, client_id) REFERENCES public.jobs(id, client_id);


--
-- TOC entry 5057 (class 2606 OID 16687)
-- Name: contracts fk_contracts_proposal_job_freelancer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT fk_contracts_proposal_job_freelancer FOREIGN KEY (proposal_id, job_id, freelancer_id) REFERENCES public.proposals(id, job_id, freelancer_id);


--
-- TOC entry 5053 (class 2606 OID 16656)
-- Name: interviews fk_interviews_proposal_job; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT fk_interviews_proposal_job FOREIGN KEY (proposal_id, job_id) REFERENCES public.proposals(id, job_id);


--
-- TOC entry 5051 (class 2606 OID 16628)
-- Name: test_tasks fk_test_tasks_proposal_job; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_tasks
    ADD CONSTRAINT fk_test_tasks_proposal_job FOREIGN KEY (proposal_id, job_id) REFERENCES public.proposals(id, job_id);


--
-- TOC entry 5039 (class 2606 OID 16505)
-- Name: freelancer_profiles freelancer_profiles_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_profiles
    ADD CONSTRAINT freelancer_profiles_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- TOC entry 5040 (class 2606 OID 16510)
-- Name: freelancer_profiles freelancer_profiles_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_profiles
    ADD CONSTRAINT freelancer_profiles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 5041 (class 2606 OID 16500)
-- Name: freelancer_profiles freelancer_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_profiles
    ADD CONSTRAINT freelancer_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5042 (class 2606 OID 16522)
-- Name: freelancer_skills freelancer_skills_freelancer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_skills
    ADD CONSTRAINT freelancer_skills_freelancer_id_fkey FOREIGN KEY (freelancer_id) REFERENCES public.freelancer_profiles(id);


--
-- TOC entry 5043 (class 2606 OID 16527)
-- Name: freelancer_skills freelancer_skills_skill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.freelancer_skills
    ADD CONSTRAINT freelancer_skills_skill_id_fkey FOREIGN KEY (skill_id) REFERENCES public.skills(id);


--
-- TOC entry 5054 (class 2606 OID 16651)
-- Name: interviews interviews_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT interviews_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- TOC entry 5047 (class 2606 OID 16572)
-- Name: job_skills job_skills_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_skills
    ADD CONSTRAINT job_skills_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- TOC entry 5048 (class 2606 OID 16577)
-- Name: job_skills job_skills_skill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_skills
    ADD CONSTRAINT job_skills_skill_id_fkey FOREIGN KEY (skill_id) REFERENCES public.skills(id);


--
-- TOC entry 5044 (class 2606 OID 16555)
-- Name: jobs jobs_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- TOC entry 5045 (class 2606 OID 16550)
-- Name: jobs jobs_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.client_profiles(id);


--
-- TOC entry 5046 (class 2606 OID 16560)
-- Name: jobs jobs_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- TOC entry 5060 (class 2606 OID 16749)
-- Name: mentorships mentorships_mentee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mentorships
    ADD CONSTRAINT mentorships_mentee_id_fkey FOREIGN KEY (mentee_id) REFERENCES public.freelancer_profiles(id);


--
-- TOC entry 5061 (class 2606 OID 16744)
-- Name: mentorships mentorships_mentor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mentorships
    ADD CONSTRAINT mentorships_mentor_id_fkey FOREIGN KEY (mentor_id) REFERENCES public.freelancer_profiles(id);


--
-- TOC entry 5062 (class 2606 OID 16769)
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5049 (class 2606 OID 16606)
-- Name: proposals proposals_freelancer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_freelancer_id_fkey FOREIGN KEY (freelancer_id) REFERENCES public.freelancer_profiles(id);


--
-- TOC entry 5050 (class 2606 OID 16601)
-- Name: proposals proposals_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- TOC entry 5059 (class 2606 OID 16727)
-- Name: reviews reviews_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- TOC entry 5052 (class 2606 OID 16623)
-- Name: test_tasks test_tasks_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_tasks
    ADD CONSTRAINT test_tasks_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- TOC entry 5035 (class 2606 OID 16450)
-- Name: users users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- TOC entry 5036 (class 2606 OID 16455)
-- Name: users users_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


-- Completed on 2026-10-13 21:12:02

--
-- PostgreSQL database dump complete
--

\unrestrict f6hK228UEArZokrF5XwvC3YKhoWODEpaE26mL3JK2Eq8qkN8A4Xt9igt7tctuRK

