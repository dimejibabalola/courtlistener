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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: documents_search_vector_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.documents_search_vector_refresh() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('simple',  coalesce(NEW.primary_citation, '')), 'A') ||
    setweight(to_tsvector('simple',  coalesce(NEW.docket_number, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.summary, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(NEW.holding, '')), 'B') ||
    setweight(to_tsvector('english', left(coalesce(NEW.full_text, ''), 800000)), 'C');
  RETURN NEW;
END $$;


--
-- Name: uploaded_documents_search_vector_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uploaded_documents_search_vector_refresh() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', left(coalesce(NEW.extracted_text, ''), 800000)), 'C');
  RETURN NEW;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ai_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_conversations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    context_type character varying,
    context_id bigint,
    title character varying,
    provider character varying,
    model character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_conversations_id_seq OWNED BY public.ai_conversations.id;


--
-- Name: ai_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_messages (
    id bigint NOT NULL,
    ai_conversation_id bigint NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    content text NOT NULL,
    sources jsonb DEFAULT '[]'::jsonb NOT NULL,
    provider character varying,
    model character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_messages_id_seq OWNED BY public.ai_messages.id;


--
-- Name: annotations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.annotations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    document_id bigint NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    quote text,
    body text,
    color character varying DEFAULT 'yellow'::character varying NOT NULL,
    start_offset integer,
    end_offset integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.annotations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.annotations_id_seq OWNED BY public.annotations.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: attorneys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attorneys (
    id bigint NOT NULL,
    name character varying NOT NULL,
    firm_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: attorneys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attorneys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attorneys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attorneys_id_seq OWNED BY public.attorneys.id;


--
-- Name: brief_analyses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brief_analyses (
    id bigint NOT NULL,
    uploaded_document_id bigint NOT NULL,
    user_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    authorities_count integer DEFAULT 0 NOT NULL,
    clean_count integer DEFAULT 0 NOT NULL,
    cautionary_count integer DEFAULT 0 NOT NULL,
    negative_count integer DEFAULT 0 NOT NULL,
    unmatched_count integer DEFAULT 0 NOT NULL,
    error_message character varying,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: brief_analyses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.brief_analyses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: brief_analyses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.brief_analyses_id_seq OWNED BY public.brief_analyses.id;


--
-- Name: brief_citations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brief_citations (
    id bigint NOT NULL,
    brief_analysis_id bigint NOT NULL,
    document_id bigint,
    resolved_from_id bigint,
    "position" integer DEFAULT 0 NOT NULL,
    raw_cite character varying NOT NULL,
    normalized_cite character varying,
    kind integer DEFAULT 0 NOT NULL,
    pin_cite character varying,
    context text,
    status integer DEFAULT 0 NOT NULL,
    treatment_status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: brief_citations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.brief_citations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: brief_citations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.brief_citations_id_seq OWNED BY public.brief_citations.id;


--
-- Name: case_attorneys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_attorneys (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    attorney_id bigint NOT NULL,
    representing integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: case_attorneys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_attorneys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_attorneys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_attorneys_id_seq OWNED BY public.case_attorneys.id;


--
-- Name: case_judges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_judges (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    judge_id bigint NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: case_judges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_judges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_judges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_judges_id_seq OWNED BY public.case_judges.id;


--
-- Name: case_parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.case_parties (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    party_id bigint NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: case_parties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.case_parties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_parties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.case_parties_id_seq OWNED BY public.case_parties.id;


--
-- Name: citations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.citations (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    raw character varying NOT NULL,
    normalized character varying NOT NULL,
    volume integer,
    reporter character varying,
    page integer,
    kind integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: citations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.citations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: citations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.citations_id_seq OWNED BY public.citations.id;


--
-- Name: citing_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.citing_references (
    id bigint NOT NULL,
    citing_document_id bigint NOT NULL,
    cited_document_id bigint NOT NULL,
    treatment integer DEFAULT 0 NOT NULL,
    depth integer DEFAULT 1 NOT NULL,
    pin_cite character varying,
    passage text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: citing_references_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.citing_references_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: citing_references_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.citing_references_id_seq OWNED BY public.citing_references.id;


--
-- Name: courts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    abbreviation character varying,
    slug character varying NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    jurisdiction_id bigint NOT NULL,
    parent_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: courts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.courts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: courts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.courts_id_seq OWNED BY public.courts.id;


--
-- Name: document_chunks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_chunks (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    content text NOT NULL,
    embedding public.vector(384),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: document_chunks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_chunks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_chunks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_chunks_id_seq OWNED BY public.document_chunks.id;


--
-- Name: document_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_views (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    document_id bigint NOT NULL,
    views_count integer DEFAULT 1 NOT NULL,
    last_viewed_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: document_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_views_id_seq OWNED BY public.document_views.id;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id bigint NOT NULL,
    type character varying NOT NULL,
    title character varying NOT NULL,
    slug character varying NOT NULL,
    primary_citation character varying,
    jurisdiction_id bigint,
    court_id bigint,
    decided_on date,
    argued_on date,
    docket_number character varying,
    full_text text,
    summary text,
    issue text,
    holding text,
    key_facts jsonb DEFAULT '[]'::jsonb NOT NULL,
    disposition character varying,
    practice_area character varying,
    source_url character varying,
    source_name character varying,
    primary_topic_id bigint,
    author_judge_id bigint,
    panel_text character varying,
    lower_court_id bigint,
    lower_court_docket character varying,
    treatment_status integer DEFAULT 0 NOT NULL,
    cited_by_count integer DEFAULT 0 NOT NULL,
    cites_count integer DEFAULT 0 NOT NULL,
    headnotes_count integer DEFAULT 0 NOT NULL,
    search_vector tsvector,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drafts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    matter_id bigint,
    document_id bigint,
    title character varying NOT NULL,
    body text,
    tone character varying DEFAULT 'neutral'::character varying NOT NULL,
    archived_at timestamp(6) without time zone,
    trashed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.drafts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.drafts_id_seq OWNED BY public.drafts.id;


--
-- Name: folder_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folder_items (
    id bigint NOT NULL,
    folder_id bigint NOT NULL,
    item_type character varying NOT NULL,
    item_id bigint NOT NULL,
    added_by_id bigint,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: folder_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.folder_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: folder_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.folder_items_id_seq OWNED BY public.folder_items.id;


--
-- Name: folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folders (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    matter_id bigint,
    parent_id bigint,
    name character varying NOT NULL,
    shared boolean DEFAULT false NOT NULL,
    items_count integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) without time zone,
    trashed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.folders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.folders_id_seq OWNED BY public.folders.id;


--
-- Name: headnote_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.headnote_topics (
    id bigint NOT NULL,
    headnote_id bigint NOT NULL,
    topic_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: headnote_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.headnote_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: headnote_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.headnote_topics_id_seq OWNED BY public.headnote_topics.id;


--
-- Name: headnotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.headnotes (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    number integer NOT NULL,
    text text NOT NULL,
    embedding public.vector(384),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: headnotes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.headnotes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: headnotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.headnotes_id_seq OWNED BY public.headnotes.id;


--
-- Name: judges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.judges (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    court_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: judges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.judges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: judges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.judges_id_seq OWNED BY public.judges.id;


--
-- Name: jurisdictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jurisdictions (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    parent_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: jurisdictions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jurisdictions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jurisdictions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jurisdictions_id_seq OWNED BY public.jurisdictions.id;


--
-- Name: matters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matters (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    organization_id bigint,
    name character varying NOT NULL,
    matter_number character varying,
    description text,
    status integer DEFAULT 0 NOT NULL,
    archived_at timestamp(6) without time zone,
    trashed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: matters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matters_id_seq OWNED BY public.matters.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    title character varying NOT NULL,
    body text,
    url character varying,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parties (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: parties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parties_id_seq OWNED BY public.parties.id;


--
-- Name: pins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pins (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    document_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pins_id_seq OWNED BY public.pins.id;


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_searches (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying NOT NULL,
    query character varying NOT NULL,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    alerts_enabled boolean DEFAULT false NOT NULL,
    last_run_at timestamp(6) without time zone,
    last_results_count integer,
    seen_document_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: saved_searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_searches_id_seq OWNED BY public.saved_searches.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: search_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_histories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    query character varying NOT NULL,
    query_type character varying,
    filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    results_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: search_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.search_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: search_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.search_histories_id_seq OWNED BY public.search_histories.id;


--
-- Name: topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topics (
    id bigint NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    parent_id bigint,
    depth integer DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    headnotes_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topics_id_seq OWNED BY public.topics.id;


--
-- Name: uploaded_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploaded_documents (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    matter_id bigint,
    title character varying NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    ocr_method character varying,
    extracted_text text,
    pages_count integer,
    error_message character varying,
    archived_at timestamp(6) without time zone,
    trashed_at timestamp(6) without time zone,
    search_vector tsvector,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: uploaded_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uploaded_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploaded_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uploaded_documents_id_seq OWNED BY public.uploaded_documents.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    full_name character varying DEFAULT ''::character varying NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    organization_id bigint,
    ai_provider character varying DEFAULT 'local'::character varying NOT NULL,
    ai_model character varying,
    anthropic_api_key_ciphertext text,
    openai_api_key_ciphertext text,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deepseek_api_key text
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: ai_conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations ALTER COLUMN id SET DEFAULT nextval('public.ai_conversations_id_seq'::regclass);


--
-- Name: ai_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_messages ALTER COLUMN id SET DEFAULT nextval('public.ai_messages_id_seq'::regclass);


--
-- Name: annotations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotations ALTER COLUMN id SET DEFAULT nextval('public.annotations_id_seq'::regclass);


--
-- Name: attorneys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attorneys ALTER COLUMN id SET DEFAULT nextval('public.attorneys_id_seq'::regclass);


--
-- Name: brief_analyses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_analyses ALTER COLUMN id SET DEFAULT nextval('public.brief_analyses_id_seq'::regclass);


--
-- Name: brief_citations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_citations ALTER COLUMN id SET DEFAULT nextval('public.brief_citations_id_seq'::regclass);


--
-- Name: case_attorneys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attorneys ALTER COLUMN id SET DEFAULT nextval('public.case_attorneys_id_seq'::regclass);


--
-- Name: case_judges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_judges ALTER COLUMN id SET DEFAULT nextval('public.case_judges_id_seq'::regclass);


--
-- Name: case_parties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_parties ALTER COLUMN id SET DEFAULT nextval('public.case_parties_id_seq'::regclass);


--
-- Name: citations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations ALTER COLUMN id SET DEFAULT nextval('public.citations_id_seq'::regclass);


--
-- Name: citing_references id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citing_references ALTER COLUMN id SET DEFAULT nextval('public.citing_references_id_seq'::regclass);


--
-- Name: courts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts ALTER COLUMN id SET DEFAULT nextval('public.courts_id_seq'::regclass);


--
-- Name: document_chunks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_chunks ALTER COLUMN id SET DEFAULT nextval('public.document_chunks_id_seq'::regclass);


--
-- Name: document_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_views ALTER COLUMN id SET DEFAULT nextval('public.document_views_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: drafts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts ALTER COLUMN id SET DEFAULT nextval('public.drafts_id_seq'::regclass);


--
-- Name: folder_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_items ALTER COLUMN id SET DEFAULT nextval('public.folder_items_id_seq'::regclass);


--
-- Name: folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders ALTER COLUMN id SET DEFAULT nextval('public.folders_id_seq'::regclass);


--
-- Name: headnote_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnote_topics ALTER COLUMN id SET DEFAULT nextval('public.headnote_topics_id_seq'::regclass);


--
-- Name: headnotes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnotes ALTER COLUMN id SET DEFAULT nextval('public.headnotes_id_seq'::regclass);


--
-- Name: judges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.judges ALTER COLUMN id SET DEFAULT nextval('public.judges_id_seq'::regclass);


--
-- Name: jurisdictions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jurisdictions ALTER COLUMN id SET DEFAULT nextval('public.jurisdictions_id_seq'::regclass);


--
-- Name: matters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matters ALTER COLUMN id SET DEFAULT nextval('public.matters_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: parties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parties ALTER COLUMN id SET DEFAULT nextval('public.parties_id_seq'::regclass);


--
-- Name: pins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pins ALTER COLUMN id SET DEFAULT nextval('public.pins_id_seq'::regclass);


--
-- Name: saved_searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches ALTER COLUMN id SET DEFAULT nextval('public.saved_searches_id_seq'::regclass);


--
-- Name: search_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_histories ALTER COLUMN id SET DEFAULT nextval('public.search_histories_id_seq'::regclass);


--
-- Name: topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics ALTER COLUMN id SET DEFAULT nextval('public.topics_id_seq'::regclass);


--
-- Name: uploaded_documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_documents ALTER COLUMN id SET DEFAULT nextval('public.uploaded_documents_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ai_conversations ai_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations
    ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id);


--
-- Name: ai_messages ai_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_messages
    ADD CONSTRAINT ai_messages_pkey PRIMARY KEY (id);


--
-- Name: annotations annotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotations
    ADD CONSTRAINT annotations_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: attorneys attorneys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attorneys
    ADD CONSTRAINT attorneys_pkey PRIMARY KEY (id);


--
-- Name: brief_analyses brief_analyses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_analyses
    ADD CONSTRAINT brief_analyses_pkey PRIMARY KEY (id);


--
-- Name: brief_citations brief_citations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_citations
    ADD CONSTRAINT brief_citations_pkey PRIMARY KEY (id);


--
-- Name: case_attorneys case_attorneys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attorneys
    ADD CONSTRAINT case_attorneys_pkey PRIMARY KEY (id);


--
-- Name: case_judges case_judges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_judges
    ADD CONSTRAINT case_judges_pkey PRIMARY KEY (id);


--
-- Name: case_parties case_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_parties
    ADD CONSTRAINT case_parties_pkey PRIMARY KEY (id);


--
-- Name: citations citations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT citations_pkey PRIMARY KEY (id);


--
-- Name: citing_references citing_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citing_references
    ADD CONSTRAINT citing_references_pkey PRIMARY KEY (id);


--
-- Name: courts courts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_pkey PRIMARY KEY (id);


--
-- Name: document_chunks document_chunks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_chunks
    ADD CONSTRAINT document_chunks_pkey PRIMARY KEY (id);


--
-- Name: document_views document_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_views
    ADD CONSTRAINT document_views_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: drafts drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts
    ADD CONSTRAINT drafts_pkey PRIMARY KEY (id);


--
-- Name: folder_items folder_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_items
    ADD CONSTRAINT folder_items_pkey PRIMARY KEY (id);


--
-- Name: folders folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_pkey PRIMARY KEY (id);


--
-- Name: headnote_topics headnote_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnote_topics
    ADD CONSTRAINT headnote_topics_pkey PRIMARY KEY (id);


--
-- Name: headnotes headnotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnotes
    ADD CONSTRAINT headnotes_pkey PRIMARY KEY (id);


--
-- Name: judges judges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.judges
    ADD CONSTRAINT judges_pkey PRIMARY KEY (id);


--
-- Name: jurisdictions jurisdictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jurisdictions
    ADD CONSTRAINT jurisdictions_pkey PRIMARY KEY (id);


--
-- Name: matters matters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matters
    ADD CONSTRAINT matters_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: parties parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parties
    ADD CONSTRAINT parties_pkey PRIMARY KEY (id);


--
-- Name: pins pins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pins
    ADD CONSTRAINT pins_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: search_histories search_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_histories
    ADD CONSTRAINT search_histories_pkey PRIMARY KEY (id);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: uploaded_documents uploaded_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_documents
    ADD CONSTRAINT uploaded_documents_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_ai_conversations_on_context; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_conversations_on_context ON public.ai_conversations USING btree (context_type, context_id);


--
-- Name: index_ai_conversations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_conversations_on_user_id ON public.ai_conversations USING btree (user_id);


--
-- Name: index_ai_messages_on_ai_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_messages_on_ai_conversation_id ON public.ai_messages USING btree (ai_conversation_id);


--
-- Name: index_annotations_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_document_id ON public.annotations USING btree (document_id);


--
-- Name: index_annotations_on_document_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_document_id_and_user_id ON public.annotations USING btree (document_id, user_id);


--
-- Name: index_annotations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_user_id ON public.annotations USING btree (user_id);


--
-- Name: index_brief_analyses_on_uploaded_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brief_analyses_on_uploaded_document_id ON public.brief_analyses USING btree (uploaded_document_id);


--
-- Name: index_brief_analyses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brief_analyses_on_user_id ON public.brief_analyses USING btree (user_id);


--
-- Name: index_brief_citations_on_brief_analysis_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brief_citations_on_brief_analysis_id ON public.brief_citations USING btree (brief_analysis_id);


--
-- Name: index_brief_citations_on_brief_analysis_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brief_citations_on_brief_analysis_id_and_position ON public.brief_citations USING btree (brief_analysis_id, "position");


--
-- Name: index_brief_citations_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brief_citations_on_document_id ON public.brief_citations USING btree (document_id);


--
-- Name: index_brief_citations_on_resolved_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brief_citations_on_resolved_from_id ON public.brief_citations USING btree (resolved_from_id);


--
-- Name: index_case_attorneys_on_attorney_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_attorneys_on_attorney_id ON public.case_attorneys USING btree (attorney_id);


--
-- Name: index_case_attorneys_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_attorneys_on_document_id ON public.case_attorneys USING btree (document_id);


--
-- Name: index_case_attorneys_on_document_id_and_attorney_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_case_attorneys_on_document_id_and_attorney_id ON public.case_attorneys USING btree (document_id, attorney_id);


--
-- Name: index_case_judges_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_judges_on_document_id ON public.case_judges USING btree (document_id);


--
-- Name: index_case_judges_on_document_id_and_judge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_case_judges_on_document_id_and_judge_id ON public.case_judges USING btree (document_id, judge_id);


--
-- Name: index_case_judges_on_judge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_judges_on_judge_id ON public.case_judges USING btree (judge_id);


--
-- Name: index_case_parties_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_parties_on_document_id ON public.case_parties USING btree (document_id);


--
-- Name: index_case_parties_on_document_id_and_party_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_case_parties_on_document_id_and_party_id ON public.case_parties USING btree (document_id, party_id);


--
-- Name: index_case_parties_on_party_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_case_parties_on_party_id ON public.case_parties USING btree (party_id);


--
-- Name: index_citations_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_citations_on_document_id ON public.citations USING btree (document_id);


--
-- Name: index_citations_on_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_citations_on_normalized ON public.citations USING btree (normalized);


--
-- Name: index_citations_on_reporter_and_volume_and_page; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_citations_on_reporter_and_volume_and_page ON public.citations USING btree (reporter, volume, page);


--
-- Name: index_citing_references_on_cited_and_treatment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_citing_references_on_cited_and_treatment ON public.citing_references USING btree (cited_document_id, treatment);


--
-- Name: index_citing_references_on_cited_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_citing_references_on_cited_document_id ON public.citing_references USING btree (cited_document_id);


--
-- Name: index_citing_references_on_citing_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_citing_references_on_citing_document_id ON public.citing_references USING btree (citing_document_id);


--
-- Name: index_citing_references_on_edge; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_citing_references_on_edge ON public.citing_references USING btree (citing_document_id, cited_document_id);


--
-- Name: index_courts_on_jurisdiction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_courts_on_jurisdiction_id ON public.courts USING btree (jurisdiction_id);


--
-- Name: index_courts_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_courts_on_parent_id ON public.courts USING btree (parent_id);


--
-- Name: index_courts_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_courts_on_slug ON public.courts USING btree (slug);


--
-- Name: index_document_chunks_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_chunks_on_document_id ON public.document_chunks USING btree (document_id);


--
-- Name: index_document_chunks_on_document_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_chunks_on_document_id_and_position ON public.document_chunks USING btree (document_id, "position");


--
-- Name: index_document_chunks_on_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_chunks_on_embedding ON public.document_chunks USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: index_document_views_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_views_on_document_id ON public.document_views USING btree (document_id);


--
-- Name: index_document_views_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_views_on_user_id ON public.document_views USING btree (user_id);


--
-- Name: index_document_views_on_user_id_and_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_views_on_user_id_and_document_id ON public.document_views USING btree (user_id, document_id);


--
-- Name: index_document_views_on_user_id_and_last_viewed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_views_on_user_id_and_last_viewed_at ON public.document_views USING btree (user_id, last_viewed_at);


--
-- Name: index_documents_on_author_judge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_author_judge_id ON public.documents USING btree (author_judge_id);


--
-- Name: index_documents_on_cited_by_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_cited_by_count ON public.documents USING btree (cited_by_count);


--
-- Name: index_documents_on_court_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_court_id ON public.documents USING btree (court_id);


--
-- Name: index_documents_on_decided_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_decided_on ON public.documents USING btree (decided_on);


--
-- Name: index_documents_on_docket_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_docket_number ON public.documents USING btree (docket_number);


--
-- Name: index_documents_on_jurisdiction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_jurisdiction_id ON public.documents USING btree (jurisdiction_id);


--
-- Name: index_documents_on_lower_court_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_lower_court_id ON public.documents USING btree (lower_court_id);


--
-- Name: index_documents_on_practice_area; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_practice_area ON public.documents USING btree (practice_area);


--
-- Name: index_documents_on_primary_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_primary_topic_id ON public.documents USING btree (primary_topic_id);


--
-- Name: index_documents_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_search_vector ON public.documents USING gin (search_vector);


--
-- Name: index_documents_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_documents_on_slug ON public.documents USING btree (slug);


--
-- Name: index_documents_on_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_title_trgm ON public.documents USING gin (title public.gin_trgm_ops);


--
-- Name: index_documents_on_treatment_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_treatment_status ON public.documents USING btree (treatment_status);


--
-- Name: index_documents_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_type ON public.documents USING btree (type);


--
-- Name: index_drafts_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_drafts_on_document_id ON public.drafts USING btree (document_id);


--
-- Name: index_drafts_on_matter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_drafts_on_matter_id ON public.drafts USING btree (matter_id);


--
-- Name: index_drafts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_drafts_on_user_id ON public.drafts USING btree (user_id);


--
-- Name: index_folder_items_on_added_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_folder_items_on_added_by_id ON public.folder_items USING btree (added_by_id);


--
-- Name: index_folder_items_on_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_folder_items_on_folder_id ON public.folder_items USING btree (folder_id);


--
-- Name: index_folder_items_on_folder_id_and_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_folder_items_on_folder_id_and_item_type_and_item_id ON public.folder_items USING btree (folder_id, item_type, item_id);


--
-- Name: index_folder_items_on_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_folder_items_on_item ON public.folder_items USING btree (item_type, item_id);


--
-- Name: index_folders_on_matter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_folders_on_matter_id ON public.folders USING btree (matter_id);


--
-- Name: index_folders_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_folders_on_parent_id ON public.folders USING btree (parent_id);


--
-- Name: index_folders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_folders_on_user_id ON public.folders USING btree (user_id);


--
-- Name: index_headnote_topics_on_headnote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_headnote_topics_on_headnote_id ON public.headnote_topics USING btree (headnote_id);


--
-- Name: index_headnote_topics_on_headnote_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_headnote_topics_on_headnote_id_and_topic_id ON public.headnote_topics USING btree (headnote_id, topic_id);


--
-- Name: index_headnote_topics_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_headnote_topics_on_topic_id ON public.headnote_topics USING btree (topic_id);


--
-- Name: index_headnotes_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_headnotes_on_document_id ON public.headnotes USING btree (document_id);


--
-- Name: index_headnotes_on_document_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_headnotes_on_document_id_and_number ON public.headnotes USING btree (document_id, number);


--
-- Name: index_headnotes_on_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_headnotes_on_embedding ON public.headnotes USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: index_judges_on_court_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_judges_on_court_id ON public.judges USING btree (court_id);


--
-- Name: index_judges_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_judges_on_slug ON public.judges USING btree (slug);


--
-- Name: index_jurisdictions_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jurisdictions_on_parent_id ON public.jurisdictions USING btree (parent_id);


--
-- Name: index_jurisdictions_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_jurisdictions_on_slug ON public.jurisdictions USING btree (slug);


--
-- Name: index_matters_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matters_on_organization_id ON public.matters USING btree (organization_id);


--
-- Name: index_matters_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matters_on_user_id ON public.matters USING btree (user_id);


--
-- Name: index_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id ON public.notifications USING btree (user_id);


--
-- Name: index_notifications_on_user_id_and_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_read_at ON public.notifications USING btree (user_id, read_at);


--
-- Name: index_organizations_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_slug ON public.organizations USING btree (slug);


--
-- Name: index_pins_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pins_on_document_id ON public.pins USING btree (document_id);


--
-- Name: index_pins_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pins_on_user_id ON public.pins USING btree (user_id);


--
-- Name: index_pins_on_user_id_and_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pins_on_user_id_and_document_id ON public.pins USING btree (user_id, document_id);


--
-- Name: index_saved_searches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_searches_on_user_id ON public.saved_searches USING btree (user_id);


--
-- Name: index_search_histories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_histories_on_user_id ON public.search_histories USING btree (user_id);


--
-- Name: index_search_histories_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_histories_on_user_id_and_created_at ON public.search_histories USING btree (user_id, created_at);


--
-- Name: index_topics_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topics_on_code ON public.topics USING btree (code);


--
-- Name: index_topics_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_parent_id ON public.topics USING btree (parent_id);


--
-- Name: index_topics_on_parent_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_parent_id_and_position ON public.topics USING btree (parent_id, "position");


--
-- Name: index_uploaded_documents_on_matter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploaded_documents_on_matter_id ON public.uploaded_documents USING btree (matter_id);


--
-- Name: index_uploaded_documents_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploaded_documents_on_search_vector ON public.uploaded_documents USING gin (search_vector);


--
-- Name: index_uploaded_documents_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploaded_documents_on_user_id ON public.uploaded_documents USING btree (user_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_organization_id ON public.users USING btree (organization_id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: documents documents_search_vector_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER documents_search_vector_trigger BEFORE INSERT OR UPDATE OF title, primary_citation, docket_number, summary, holding, full_text ON public.documents FOR EACH ROW EXECUTE FUNCTION public.documents_search_vector_refresh();


--
-- Name: uploaded_documents uploaded_documents_search_vector_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER uploaded_documents_search_vector_trigger BEFORE INSERT OR UPDATE OF title, extracted_text ON public.uploaded_documents FOR EACH ROW EXECUTE FUNCTION public.uploaded_documents_search_vector_refresh();


--
-- Name: drafts fk_rails_00bb1b57f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts
    ADD CONSTRAINT fk_rails_00bb1b57f7 FOREIGN KEY (matter_id) REFERENCES public.matters(id);


--
-- Name: folder_items fk_rails_04e517fb7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_items
    ADD CONSTRAINT fk_rails_04e517fb7f FOREIGN KEY (added_by_id) REFERENCES public.users(id);


--
-- Name: search_histories fk_rails_0bd337aaf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_histories
    ADD CONSTRAINT fk_rails_0bd337aaf0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: courts fk_rails_0f3e8fe822; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT fk_rails_0f3e8fe822 FOREIGN KEY (parent_id) REFERENCES public.courts(id);


--
-- Name: documents fk_rails_12f623ce17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_12f623ce17 FOREIGN KEY (court_id) REFERENCES public.courts(id);


--
-- Name: headnote_topics fk_rails_1ad739f590; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnote_topics
    ADD CONSTRAINT fk_rails_1ad739f590 FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: brief_citations fk_rails_1b9e5cf592; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_citations
    ADD CONSTRAINT fk_rails_1b9e5cf592 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: folders fk_rails_2a04d378cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT fk_rails_2a04d378cf FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: folder_items fk_rails_2fd5d1d78f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folder_items
    ADD CONSTRAINT fk_rails_2fd5d1d78f FOREIGN KEY (folder_id) REFERENCES public.folders(id);


--
-- Name: documents fk_rails_338c7a8ec6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_338c7a8ec6 FOREIGN KEY (author_judge_id) REFERENCES public.judges(id);


--
-- Name: annotations fk_rails_4043df79bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotations
    ADD CONSTRAINT fk_rails_4043df79bf FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: brief_citations fk_rails_4107913dc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_citations
    ADD CONSTRAINT fk_rails_4107913dc4 FOREIGN KEY (resolved_from_id) REFERENCES public.brief_citations(id);


--
-- Name: case_judges fk_rails_4472ea1d49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_judges
    ADD CONSTRAINT fk_rails_4472ea1d49 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: ai_messages fk_rails_4a646eee8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_messages
    ADD CONSTRAINT fk_rails_4a646eee8b FOREIGN KEY (ai_conversation_id) REFERENCES public.ai_conversations(id);


--
-- Name: pins fk_rails_51b0c024f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pins
    ADD CONSTRAINT fk_rails_51b0c024f1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: folders fk_rails_58e285f76e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT fk_rails_58e285f76e FOREIGN KEY (parent_id) REFERENCES public.folders(id);


--
-- Name: annotations fk_rails_5b32aef115; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotations
    ADD CONSTRAINT fk_rails_5b32aef115 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: brief_analyses fk_rails_5da2b1c136; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_analyses
    ADD CONSTRAINT fk_rails_5da2b1c136 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: judges fk_rails_5def75e07f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.judges
    ADD CONSTRAINT fk_rails_5def75e07f FOREIGN KEY (court_id) REFERENCES public.courts(id);


--
-- Name: topics fk_rails_5f3c091f12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT fk_rails_5f3c091f12 FOREIGN KEY (parent_id) REFERENCES public.topics(id);


--
-- Name: case_attorneys fk_rails_62f53d875a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attorneys
    ADD CONSTRAINT fk_rails_62f53d875a FOREIGN KEY (attorney_id) REFERENCES public.attorneys(id);


--
-- Name: saved_searches fk_rails_63c5382842; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT fk_rails_63c5382842 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: citations fk_rails_6411aa5d97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT fk_rails_6411aa5d97 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: citing_references fk_rails_653bb7ef41; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citing_references
    ADD CONSTRAINT fk_rails_653bb7ef41 FOREIGN KEY (citing_document_id) REFERENCES public.documents(id);


--
-- Name: matters fk_rails_67d9096e54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matters
    ADD CONSTRAINT fk_rails_67d9096e54 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: uploaded_documents fk_rails_6ebf301b0c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_documents
    ADD CONSTRAINT fk_rails_6ebf301b0c FOREIGN KEY (matter_id) REFERENCES public.matters(id);


--
-- Name: jurisdictions fk_rails_739f46700f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jurisdictions
    ADD CONSTRAINT fk_rails_739f46700f FOREIGN KEY (parent_id) REFERENCES public.jurisdictions(id);


--
-- Name: documents fk_rails_78618bd4cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_78618bd4cc FOREIGN KEY (jurisdiction_id) REFERENCES public.jurisdictions(id);


--
-- Name: pins fk_rails_7995e4e9a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pins
    ADD CONSTRAINT fk_rails_7995e4e9a6 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: headnotes fk_rails_7d66cbc8b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnotes
    ADD CONSTRAINT fk_rails_7d66cbc8b8 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: case_parties fk_rails_8428f1cbc5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_parties
    ADD CONSTRAINT fk_rails_8428f1cbc5 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: citing_references fk_rails_865cac5e8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citing_references
    ADD CONSTRAINT fk_rails_865cac5e8b FOREIGN KEY (cited_document_id) REFERENCES public.documents(id);


--
-- Name: courts fk_rails_872735f6d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT fk_rails_872735f6d9 FOREIGN KEY (jurisdiction_id) REFERENCES public.jurisdictions(id);


--
-- Name: drafts fk_rails_976b64226f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts
    ADD CONSTRAINT fk_rails_976b64226f FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: document_chunks fk_rails_99b41ada32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_chunks
    ADD CONSTRAINT fk_rails_99b41ada32 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: documents fk_rails_9cc03943af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_9cc03943af FOREIGN KEY (primary_topic_id) REFERENCES public.topics(id);


--
-- Name: document_views fk_rails_a4855043ec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_views
    ADD CONSTRAINT fk_rails_a4855043ec FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: documents fk_rails_aa45d98fce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_aa45d98fce FOREIGN KEY (lower_court_id) REFERENCES public.courts(id);


--
-- Name: brief_analyses fk_rails_ac44a6c681; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_analyses
    ADD CONSTRAINT fk_rails_ac44a6c681 FOREIGN KEY (uploaded_document_id) REFERENCES public.uploaded_documents(id);


--
-- Name: uploaded_documents fk_rails_af1cd03c21; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_documents
    ADD CONSTRAINT fk_rails_af1cd03c21 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications fk_rails_b080fb4855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_b080fb4855 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: drafts fk_rails_ba38003ed4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts
    ADD CONSTRAINT fk_rails_ba38003ed4 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_views fk_rails_bc8ec6dc33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_views
    ADD CONSTRAINT fk_rails_bc8ec6dc33 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: case_judges fk_rails_c0b5f28f5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_judges
    ADD CONSTRAINT fk_rails_c0b5f28f5d FOREIGN KEY (judge_id) REFERENCES public.judges(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: case_parties fk_rails_d26b295ab8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_parties
    ADD CONSTRAINT fk_rails_d26b295ab8 FOREIGN KEY (party_id) REFERENCES public.parties(id);


--
-- Name: users fk_rails_d7b9ff90af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_d7b9ff90af FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: case_attorneys fk_rails_def457fc9a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.case_attorneys
    ADD CONSTRAINT fk_rails_def457fc9a FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: folders fk_rails_e8ac47b1f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT fk_rails_e8ac47b1f5 FOREIGN KEY (matter_id) REFERENCES public.matters(id);


--
-- Name: matters fk_rails_ecd975b36b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matters
    ADD CONSTRAINT fk_rails_ecd975b36b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: ai_conversations fk_rails_faada8ac9a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_conversations
    ADD CONSTRAINT fk_rails_faada8ac9a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: brief_citations fk_rails_fae0e6b5c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brief_citations
    ADD CONSTRAINT fk_rails_fae0e6b5c3 FOREIGN KEY (brief_analysis_id) REFERENCES public.brief_analyses(id);


--
-- Name: headnote_topics fk_rails_fb8fdee526; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.headnote_topics
    ADD CONSTRAINT fk_rails_fb8fdee526 FOREIGN KEY (headnote_id) REFERENCES public.headnotes(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260613030000'),
('20260613020000'),
('20260612201648'),
('20260612001200'),
('20260612001100'),
('20260612001000'),
('20260612000900'),
('20260612000800'),
('20260612000700'),
('20260612000600'),
('20260612000500'),
('20260612000400'),
('20260612000300'),
('20260612000200'),
('20260612000100');

