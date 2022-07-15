PGDMP  	    8            	        z           taiga    14.3    14.3 �    j           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            k           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            l           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            m           1262    1834746    taiga    DATABASE     Z   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.UTF-8';
    DROP DATABASE taiga;
                postgres    false                        3079    1834860    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            n           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            �           1247    1835142    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          bameda    false            �           1247    1835132    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          bameda    false            �            1255    1835203 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone);
       public          bameda    false                       1255    1835220 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint);
       public          bameda    false            �            1255    1835204 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb);
       public          bameda    false            �            1259    1835158    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status public.procrastinate_job_status DEFAULT 'todo'::public.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);
 &   DROP TABLE public.procrastinate_jobs;
       public         heap    bameda    false    942    942                       1255    1835205 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;
 V   DROP FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]);
       public          bameda    false    242                       1255    1835219 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;
 k   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status);
       public          bameda    false    942                       1255    1835218 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone);
       public          bameda    false    942            	           1255    1835206 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean);
       public          bameda    false    942                       1255    1835208    procrastinate_notify_queue()    FUNCTION     
  CREATE FUNCTION public.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.procrastinate_notify_queue();
       public          bameda    false            
           1255    1835207 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;
 a   DROP FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone);
       public          bameda    false                       1255    1835211 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          bameda    false                       1255    1835209 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          bameda    false                       1255    1835210 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_update();
       public          bameda    false                       1255    1835212 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;
 =   DROP FUNCTION public.procrastinate_unlink_periodic_defers();
       public          bameda    false            n           3602    1834867    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR uint WITH simple;
 7   DROP TEXT SEARCH CONFIGURATION public.simple_unaccent;
       public          bameda    false    2    2    2    2            �            1259    1834821 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    bameda    false            �            1259    1834820    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    221            �            1259    1834829    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    bameda    false            �            1259    1834828    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    223            �            1259    1834815    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    bameda    false            �            1259    1834814    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    219            �            1259    1834794    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id uuid NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    bameda    false            �            1259    1834793    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    217            �            1259    1834786    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    bameda    false            �            1259    1834785    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    215            �            1259    1834748    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    bameda    false            �            1259    1834747    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    211            �            1259    1835094    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    bameda    false            �            1259    1834869    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    bameda    false            �            1259    1834868    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    225            �            1259    1834875    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    bameda    false            �            1259    1834874     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    227            �            1259    1834899 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    bameda    false            �            1259    1834898 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          bameda    false    229            �            1259    1835051    invitations_projectinvitation    TABLE     �  CREATE TABLE public.invitations_projectinvitation (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    num_emails_sent integer NOT NULL,
    resent_at timestamp with time zone,
    revoked_at timestamp with time zone,
    invited_by_id uuid,
    project_id uuid NOT NULL,
    resent_by_id uuid,
    revoked_by_id uuid,
    role_id uuid NOT NULL,
    user_id uuid
);
 1   DROP TABLE public.invitations_projectinvitation;
       public         heap    bameda    false            �            1259    1835185    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    bameda    false    945            �            1259    1835184    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          bameda    false    246            o           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          bameda    false    245            �            1259    1835157    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          bameda    false    242            p           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          bameda    false    241            �            1259    1835170    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    bameda    false            �            1259    1835169 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          bameda    false    244            q           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          bameda    false    243            �            1259    1834970    projects_project    TABLE       CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    slug character varying(250) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    anon_permissions text[],
    public_permissions text[],
    workspace_member_permissions text[],
    creation_template_id uuid,
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    bameda    false            �            1259    1834995    projects_projectmembership    TABLE     �   CREATE TABLE public.projects_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 .   DROP TABLE public.projects_projectmembership;
       public         heap    bameda    false            �            1259    1834988    projects_projectrole    TABLE     	  CREATE TABLE public.projects_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 (   DROP TABLE public.projects_projectrole;
       public         heap    bameda    false            �            1259    1834979    projects_projecttemplate    TABLE     �  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    bameda    false            �            1259    1835112    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    bameda    false            �            1259    1835103    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
    id uuid NOT NULL,
    object_id uuid,
    jti character varying(255) NOT NULL,
    token_type text NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    content_type_id integer
);
 +   DROP TABLE public.tokens_outstandingtoken;
       public         heap    bameda    false            �            1259    1834766    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb NOT NULL,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    bameda    false            �            1259    1834755 
   users_user    TABLE     �  CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    bameda    false            �            1259    1834913    workspaces_workspace    TABLE     T  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    bameda    false            �            1259    1834927    workspaces_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_workspacemembership;
       public         heap    bameda    false            �            1259    1834920    workspaces_workspacerole    TABLE       CREATE TABLE public.workspaces_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 ,   DROP TABLE public.workspaces_workspacerole;
       public         heap    bameda    false            �           2604    1835188    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          bameda    false    245    246    246            �           2604    1835161    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          bameda    false    242    241    242            �           2604    1835173     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          bameda    false    243    244    244            N          0    1834821 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          bameda    false    221   ��      P          0    1834829    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          bameda    false    223   ��      L          0    1834815    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          bameda    false    219   ĕ      J          0    1834794    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          bameda    false    217   ��      H          0    1834786    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          bameda    false    215   �      D          0    1834748    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          bameda    false    211   	�      _          0    1835094    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          bameda    false    238   .�      R          0    1834869    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          bameda    false    225   K�      T          0    1834875    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          bameda    false    227   h�      V          0    1834899 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          bameda    false    229   ��      ^          0    1835051    invitations_projectinvitation 
   TABLE DATA           �   COPY public.invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          bameda    false    237   ��      g          0    1835185    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          bameda    false    246   ǩ      c          0    1835158    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          bameda    false    242   �      e          0    1835170    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          bameda    false    244   �      Z          0    1834970    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, slug, description, color, logo, created_at, modified_at, anon_permissions, public_permissions, workspace_member_permissions, creation_template_id, owner_id, workspace_id) FROM stdin;
    public          bameda    false    233   �      ]          0    1834995    projects_projectmembership 
   TABLE DATA           b   COPY public.projects_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          bameda    false    236   �      \          0    1834988    projects_projectrole 
   TABLE DATA           j   COPY public.projects_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          bameda    false    235   o�      [          0    1834979    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, description, "order", created_at, modified_at, default_owner_role, roles) FROM stdin;
    public          bameda    false    234   ��      a          0    1835112    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          bameda    false    240   ��      `          0    1835103    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          bameda    false    239   ��      F          0    1834766    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          bameda    false    213   ��      E          0    1834755 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, date_joined, date_verification) FROM stdin;
    public          bameda    false    212   ��      W          0    1834913    workspaces_workspace 
   TABLE DATA           t   COPY public.workspaces_workspace (id, name, slug, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          bameda    false    230   j�      Y          0    1834927    workspaces_workspacemembership 
   TABLE DATA           h   COPY public.workspaces_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          bameda    false    232   �      X          0    1834920    workspaces_workspacerole 
   TABLE DATA           p   COPY public.workspaces_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          bameda    false    231   ��      r           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          bameda    false    220            s           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          bameda    false    222            t           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 80, true);
          public          bameda    false    218            u           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          bameda    false    216            v           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 20, true);
          public          bameda    false    214            w           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 26, true);
          public          bameda    false    210            x           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          bameda    false    224            y           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          bameda    false    226            z           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          bameda    false    228            {           0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          bameda    false    245            |           0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          bameda    false    241            }           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          bameda    false    243                        2606    1834858    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            bameda    false    221            %           2606    1834844 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            bameda    false    223    223            (           2606    1834833 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            bameda    false    223            "           2606    1834825    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            bameda    false    221                       2606    1834835 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            bameda    false    219    219                       2606    1834819 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            bameda    false    219                       2606    1834801 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            bameda    false    217                       2606    1834792 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            bameda    false    215    215                       2606    1834790 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            bameda    false    215                       2606    1834754 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            bameda    false    211            {           2606    1835100 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            bameda    false    238            ,           2606    1834873 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            bameda    false    225            0           2606    1834883 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            bameda    false    225    225            2           2606    1834881 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            bameda    false    227    227    227            6           2606    1834879 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            bameda    false    227            ;           2606    1834905 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            bameda    false    229            =           2606    1834907 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            bameda    false    229            p           2606    1835057 Z   invitations_projectinvitation invitations_projectinvitation_email_project_id_b248b6c9_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_email_project_id_b248b6c9_uniq UNIQUE (email, project_id);
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_email_project_id_b248b6c9_uniq;
       public            bameda    false    237    237            s           2606    1835055 @   invitations_projectinvitation invitations_projectinvitation_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_pkey;
       public            bameda    false    237            �           2606    1835191 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            bameda    false    246            �           2606    1835168 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            bameda    false    242            �           2606    1835176 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            bameda    false    244            �           2606    1835178 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            bameda    false    244    244    244            W           2606    1834976 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            bameda    false    233            Z           2606    1834978 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            bameda    false    233            i           2606    1834999 :   projects_projectmembership projects_projectmembership_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_pkey;
       public            bameda    false    236            n           2606    1835029 V   projects_projectmembership projects_projectmembership_user_id_project_id_95c79910_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_user_id_project_id_95c79910_uniq UNIQUE (user_id, project_id);
 �   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_user_id_project_id_95c79910_uniq;
       public            bameda    false    236    236            b           2606    1834994 .   projects_projectrole projects_projectrole_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_pkey;
       public            bameda    false    235            g           2606    1835019 G   projects_projectrole projects_projectrole_slug_project_id_4d3edd11_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_slug_project_id_4d3edd11_uniq UNIQUE (slug, project_id);
 q   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_slug_project_id_4d3edd11_uniq;
       public            bameda    false    235    235            ]           2606    1834985 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            bameda    false    234            `           2606    1834987 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            bameda    false    234            �           2606    1835116 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            bameda    false    240            �           2606    1835118 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            bameda    false    240            �           2606    1835111 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            bameda    false    239            �           2606    1835109 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            bameda    false    239                       2606    1834776 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            bameda    false    213    213                       2606    1834772 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            bameda    false    213                       2606    1834765    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            bameda    false    212                       2606    1834761    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            bameda    false    212            	           2606    1834763 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            bameda    false    212            A           2606    1834917 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            bameda    false    230            D           2606    1834919 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            bameda    false    230            M           2606    1834950 Z   workspaces_workspacemembership workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq;
       public            bameda    false    232    232            O           2606    1834931 B   workspaces_workspacemembership workspaces_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacemembership_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacemembership_pkey;
       public            bameda    false    232            F           2606    1834926 6   workspaces_workspacerole workspaces_workspacerole_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workspaces_workspacerole
    ADD CONSTRAINT workspaces_workspacerole_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workspaces_workspacerole DROP CONSTRAINT workspaces_workspacerole_pkey;
       public            bameda    false    231            J           2606    1834940 Q   workspaces_workspacerole workspaces_workspacerole_slug_workspace_id_a006f230_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacerole
    ADD CONSTRAINT workspaces_workspacerole_slug_workspace_id_a006f230_uniq UNIQUE (slug, workspace_id);
 {   ALTER TABLE ONLY public.workspaces_workspacerole DROP CONSTRAINT workspaces_workspacerole_slug_workspace_id_a006f230_uniq;
       public            bameda    false    231    231                       1259    1834859    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            bameda    false    221            #           1259    1834855 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            bameda    false    223            &           1259    1834856 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            bameda    false    223                       1259    1834841 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            bameda    false    219                       1259    1834812 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            bameda    false    217                       1259    1834813 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            bameda    false    217            y           1259    1835102 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            bameda    false    238            |           1259    1835101 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            bameda    false    238            )           1259    1834886 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            bameda    false    225            *           1259    1834887 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            bameda    false    225            -           1259    1834884 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            bameda    false    225            .           1259    1834885 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            bameda    false    225            3           1259    1834895 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            bameda    false    227            4           1259    1834896 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            bameda    false    227            7           1259    1834897 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            bameda    false    227            8           1259    1834893 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            bameda    false    227            9           1259    1834894 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            bameda    false    227            q           1259    1835088 4   invitations_projectinvitation_invited_by_id_016c910f    INDEX     �   CREATE INDEX invitations_projectinvitation_invited_by_id_016c910f ON public.invitations_projectinvitation USING btree (invited_by_id);
 H   DROP INDEX public.invitations_projectinvitation_invited_by_id_016c910f;
       public            bameda    false    237            t           1259    1835089 1   invitations_projectinvitation_project_id_a48f4dcf    INDEX     �   CREATE INDEX invitations_projectinvitation_project_id_a48f4dcf ON public.invitations_projectinvitation USING btree (project_id);
 E   DROP INDEX public.invitations_projectinvitation_project_id_a48f4dcf;
       public            bameda    false    237            u           1259    1835090 3   invitations_projectinvitation_resent_by_id_b715caff    INDEX     �   CREATE INDEX invitations_projectinvitation_resent_by_id_b715caff ON public.invitations_projectinvitation USING btree (resent_by_id);
 G   DROP INDEX public.invitations_projectinvitation_resent_by_id_b715caff;
       public            bameda    false    237            v           1259    1835091 4   invitations_projectinvitation_revoked_by_id_e180a546    INDEX     �   CREATE INDEX invitations_projectinvitation_revoked_by_id_e180a546 ON public.invitations_projectinvitation USING btree (revoked_by_id);
 H   DROP INDEX public.invitations_projectinvitation_revoked_by_id_e180a546;
       public            bameda    false    237            w           1259    1835092 .   invitations_projectinvitation_role_id_d4a584ff    INDEX     {   CREATE INDEX invitations_projectinvitation_role_id_d4a584ff ON public.invitations_projectinvitation USING btree (role_id);
 B   DROP INDEX public.invitations_projectinvitation_role_id_d4a584ff;
       public            bameda    false    237            x           1259    1835093 .   invitations_projectinvitation_user_id_3fc27ac1    INDEX     {   CREATE INDEX invitations_projectinvitation_user_id_3fc27ac1 ON public.invitations_projectinvitation USING btree (user_id);
 B   DROP INDEX public.invitations_projectinvitation_user_id_3fc27ac1;
       public            bameda    false    237            �           1259    1835201     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            bameda    false    246            �           1259    1835200    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            bameda    false    242    242    242    942            �           1259    1835198    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            bameda    false    242    942    242            �           1259    1835199 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            bameda    false    242            �           1259    1835197 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            bameda    false    942    242    242            �           1259    1835202 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            bameda    false    244            S           1259    1835048 .   projects_project_creation_template_id_b5a97819    INDEX     {   CREATE INDEX projects_project_creation_template_id_b5a97819 ON public.projects_project USING btree (creation_template_id);
 B   DROP INDEX public.projects_project_creation_template_id_b5a97819;
       public            bameda    false    233            T           1259    1835015 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            bameda    false    233    233            U           1259    1835049 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            bameda    false    233            X           1259    1835016 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            bameda    false    233            [           1259    1835050 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            bameda    false    233            j           1259    1835045 .   projects_projectmembership_project_id_ec39ff46    INDEX     {   CREATE INDEX projects_projectmembership_project_id_ec39ff46 ON public.projects_projectmembership USING btree (project_id);
 B   DROP INDEX public.projects_projectmembership_project_id_ec39ff46;
       public            bameda    false    236            k           1259    1835046 +   projects_projectmembership_role_id_af989934    INDEX     u   CREATE INDEX projects_projectmembership_role_id_af989934 ON public.projects_projectmembership USING btree (role_id);
 ?   DROP INDEX public.projects_projectmembership_role_id_af989934;
       public            bameda    false    236            l           1259    1835047 +   projects_projectmembership_user_id_aed8d123    INDEX     u   CREATE INDEX projects_projectmembership_user_id_aed8d123 ON public.projects_projectmembership USING btree (user_id);
 ?   DROP INDEX public.projects_projectmembership_user_id_aed8d123;
       public            bameda    false    236            c           1259    1835027 (   projects_projectrole_project_id_0ec3c923    INDEX     o   CREATE INDEX projects_projectrole_project_id_0ec3c923 ON public.projects_projectrole USING btree (project_id);
 <   DROP INDEX public.projects_projectrole_project_id_0ec3c923;
       public            bameda    false    235            d           1259    1835025 "   projects_projectrole_slug_c6fb5583    INDEX     c   CREATE INDEX projects_projectrole_slug_c6fb5583 ON public.projects_projectrole USING btree (slug);
 6   DROP INDEX public.projects_projectrole_slug_c6fb5583;
       public            bameda    false    235            e           1259    1835026 '   projects_projectrole_slug_c6fb5583_like    INDEX     |   CREATE INDEX projects_projectrole_slug_c6fb5583_like ON public.projects_projectrole USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.projects_projectrole_slug_c6fb5583_like;
       public            bameda    false    235            ^           1259    1835017 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            bameda    false    234            }           1259    1835125 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            bameda    false    239            ~           1259    1835124 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            bameda    false    239            
           1259    1834782    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            bameda    false    213                       1259    1834783     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            bameda    false    213                       1259    1834784    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            bameda    false    213                       1259    1834774    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            bameda    false    212                       1259    1834773 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            bameda    false    212            >           1259    1834937 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            bameda    false    230    230            ?           1259    1834969 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            bameda    false    230            B           1259    1834938 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            bameda    false    230            P           1259    1834966 /   workspaces_workspacemembership_role_id_41db0600    INDEX     }   CREATE INDEX workspaces_workspacemembership_role_id_41db0600 ON public.workspaces_workspacemembership USING btree (role_id);
 C   DROP INDEX public.workspaces_workspacemembership_role_id_41db0600;
       public            bameda    false    232            Q           1259    1834967 /   workspaces_workspacemembership_user_id_091e94f3    INDEX     }   CREATE INDEX workspaces_workspacemembership_user_id_091e94f3 ON public.workspaces_workspacemembership USING btree (user_id);
 C   DROP INDEX public.workspaces_workspacemembership_user_id_091e94f3;
       public            bameda    false    232            R           1259    1834968 4   workspaces_workspacemembership_workspace_id_d634b215    INDEX     �   CREATE INDEX workspaces_workspacemembership_workspace_id_d634b215 ON public.workspaces_workspacemembership USING btree (workspace_id);
 H   DROP INDEX public.workspaces_workspacemembership_workspace_id_d634b215;
       public            bameda    false    232            G           1259    1834946 &   workspaces_workspacerole_slug_5195ab3f    INDEX     k   CREATE INDEX workspaces_workspacerole_slug_5195ab3f ON public.workspaces_workspacerole USING btree (slug);
 :   DROP INDEX public.workspaces_workspacerole_slug_5195ab3f;
       public            bameda    false    231            H           1259    1834947 +   workspaces_workspacerole_slug_5195ab3f_like    INDEX     �   CREATE INDEX workspaces_workspacerole_slug_5195ab3f_like ON public.workspaces_workspacerole USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.workspaces_workspacerole_slug_5195ab3f_like;
       public            bameda    false    231            K           1259    1834948 .   workspaces_workspacerole_workspace_id_04ff6ace    INDEX     {   CREATE INDEX workspaces_workspacerole_workspace_id_04ff6ace ON public.workspaces_workspacerole USING btree (workspace_id);
 B   DROP INDEX public.workspaces_workspacerole_workspace_id_04ff6ace;
       public            bameda    false    231            �           2620    1835213 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          bameda    false    242    267    942    242            �           2620    1835217 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          bameda    false    271    242            �           2620    1835216 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          bameda    false    942    242    242    270    242            �           2620    1835215 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          bameda    false    942    268    242    242            �           2620    1835214 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          bameda    false    269    242    242            �           2606    1834850 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          bameda    false    219    223    3357            �           2606    1834845 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          bameda    false    3362    223    221            �           2606    1834836 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          bameda    false    219    215    3348            �           2606    1834802 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          bameda    false    3348    217    215            �           2606    1834807 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          bameda    false    217    212    3334            �           2606    1834888 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          bameda    false    225    3372    227            �           2606    1834908 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          bameda    false    3382    229    227            �           2606    1835058 V   invitations_projectinvitation invitations_projecti_invited_by_id_016c910f_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_invited_by_id_016c910f_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_invited_by_id_016c910f_fk_users_use;
       public          bameda    false    237    212    3334            �           2606    1835063 S   invitations_projectinvitation invitations_projecti_project_id_a48f4dcf_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_project_id_a48f4dcf_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 }   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_project_id_a48f4dcf_fk_projects_;
       public          bameda    false    233    237    3415            �           2606    1835068 U   invitations_projectinvitation invitations_projecti_resent_by_id_b715caff_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_resent_by_id_b715caff_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
    ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_resent_by_id_b715caff_fk_users_use;
       public          bameda    false    212    237    3334            �           2606    1835073 V   invitations_projectinvitation invitations_projecti_revoked_by_id_e180a546_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_revoked_by_id_e180a546_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_revoked_by_id_e180a546_fk_users_use;
       public          bameda    false    3334    212    237            �           2606    1835078 P   invitations_projectinvitation invitations_projecti_role_id_d4a584ff_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_role_id_d4a584ff_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_role_id_d4a584ff_fk_projects_;
       public          bameda    false    237    3426    235            �           2606    1835083 ]   invitations_projectinvitation invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id;
       public          bameda    false    237    3334    212            �           2606    1835192 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          bameda    false    246    3466    242            �           2606    1835179 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          bameda    false    3466    244    242            �           2606    1835000 L   projects_project projects_project_creation_template_id_b5a97819_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_creation_template_id_b5a97819_fk_projects_ FOREIGN KEY (creation_template_id) REFERENCES public.projects_projecttemplate(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_creation_template_id_b5a97819_fk_projects_;
       public          bameda    false    234    233    3421            �           2606    1835005 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          bameda    false    3334    233    212            �           2606    1835010 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          bameda    false    233    230    3393            �           2606    1835030 P   projects_projectmembership projects_projectmemb_project_id_ec39ff46_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmemb_project_id_ec39ff46_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmemb_project_id_ec39ff46_fk_projects_;
       public          bameda    false    236    233    3415            �           2606    1835035 M   projects_projectmembership projects_projectmemb_role_id_af989934_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmemb_role_id_af989934_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmemb_role_id_af989934_fk_projects_;
       public          bameda    false    235    3426    236            �           2606    1835040 W   projects_projectmembership projects_projectmembership_user_id_aed8d123_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_user_id_aed8d123_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_user_id_aed8d123_fk_users_user_id;
       public          bameda    false    3334    236    212            �           2606    1835020 T   projects_projectrole projects_projectrole_project_id_0ec3c923_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_project_id_0ec3c923_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_project_id_0ec3c923_fk_projects_project_id;
       public          bameda    false    3415    235    233            �           2606    1835126 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          bameda    false    239    240    3458            �           2606    1835119 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          bameda    false    215    3348    239            �           2606    1834777 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          bameda    false    212    213    3334            �           2606    1834932 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          bameda    false    212    230    3334            �           2606    1834951 Q   workspaces_workspacemembership workspaces_workspace_role_id_41db0600_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_role_id_41db0600_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_role_id_41db0600_fk_workspace;
       public          bameda    false    231    232    3398            �           2606    1834956 Q   workspaces_workspacemembership workspaces_workspace_user_id_091e94f3_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use;
       public          bameda    false    232    212    3334            �           2606    1834941 P   workspaces_workspacerole workspaces_workspace_workspace_id_04ff6ace_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacerole
    ADD CONSTRAINT workspaces_workspace_workspace_id_04ff6ace_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workspaces_workspacerole DROP CONSTRAINT workspaces_workspace_workspace_id_04ff6ace_fk_workspace;
       public          bameda    false    230    231    3393            �           2606    1834961 V   workspaces_workspacemembership workspaces_workspace_workspace_id_d634b215_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_workspace_id_d634b215_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_workspace_id_d634b215_fk_workspace;
       public          bameda    false    3393    230    232            N      xڋ���� � �      P      xڋ���� � �      L   $  x�m�A��0E���`�!��k�4���0� �[}�	v�����������w7�]���i�f����M����_��vT���o���]�W������?9�k0�Gx�h��fy�:LcV:_�Pg� �۠�`�ؖE�4��얷ez�Y��o����E�F���!%��Y�q�<�[��z�Ovr�[*}B�H��}�$'&Ϭ��Sc���V�a��h�t�j̐؎]Ћ1�
XY�CNiG�n�=-���]MvvN�Z�b
�#/@� Jn��ݏ�����ez����۞*�I�8��L�t���ϴ	���<I�x��Y��0g���'�*ҍD���:�N�1_�����Y��y�����.���W���LxZL�!c�A0B��3* ��(��9?:�~���U�&EJ�r�A�OE�Cİ�t��ݎZc+w3��T�@�6>P����l���A����ud��.�n��9�B&e7�F2,{a����(v��%j:�_����h�6�U��2)�bX��ʰl��2n*���<���,��������Їc*�	1� KO���s��Oyʻ���}g�L�W����U-�Zp�¨�d��Ԏ�av���i�^v����-�ӧy_V�����bn�92��b��QjGa��A�,��T�f�y�5}�W7�SDLt*E�����T��EA��T�U�B<���Z�-ڿ��J5b\	qD��d*|�Ȍ��#�'��_Ϗ�����}C5b�HZ���,�s(H�\[���4���fe!��H5mR��>��?�$���X��-%q��~)��6~l      J      xڋ���� � �      H   �   x�uP[n�0��3T��.7����!���&]�t?ER&D�6�:&��0E{H��q1���t9��;0ֻ C��FqO����*ɴ��'��[:ǁ��V��/��w	ϐr��VeH����`��h�M9Ԭ��ڂ?N�N�̆?
iE�yz���t��5H�x����`]�&�H��88Q��r62~i_�%7�"cɵ0:��'�f�h��I�#��o<��y      D     xڍ�ю� ���S��f8��<�&�Q�eG��N�~�:�������9��9M���0�D��F�;��,��W���\V?1 5n�f��:�=J"1����n{;�P�g	�K@u�W�M�.F�):��v��*$3؝Q�I�t��{�O�9;ۤ~�YBp�Y���᫚���_Ԡ{�����G���$�y�(@�.�F�{Bn"��z��:3��_��JH�3J.�jF�(�k�mR(�D������(��1�;�Ų�@��`��N���eSkS�Ě3��N�3Y�L��Jeמ@`N6��K��ζ::J`��Ϋބ�OO��k�J�]hb՜-�9�����$�Y�% %���/�3���4��H�7�����1d�����!���LXukjI3�Ǧޭ�ٕ�ߜ��}۾H"-"^�����y�߆�kLLi�Ț�����$�o�@���n�7�8��,��B��ߦ�;d�e{Ev�بc)nS	 /{
f�붌����5����UIR���x8�g��e      _      xڋ���� � �      R      xڋ���� � �      T      xڋ���� � �      V      xڋ���� � �      ^     x�͝ێ������}0��ɽ�'�'�����$���4�I���nuɍ�m��Ѯ�oD�?)J2�g@�o�5���F�����������������BJ�?K����o�����0��1�*�w�?���?�?&���͗D����"�q�@9����uI)o�Gvϋ5[���1I��4|��~����<�o���IE_ڿn>�H��sp�}���>��_>�̪l�ׇp�<`N|)U�����Sշ��)|��k�)	�%�� �?{�o��3�N��o�E�[��|;��C���h���7f|k�D�%S|;�{/>�Á��S�n��C�l�������0���o�y��G�-����w�q���~ �}��tK�mJl�T�n�˯�������~���Wp9�ן:����R(0�֝GEg�|2�u�!Ww�
[� ��r�ͩi-��5���կ�o�Z$r<��Q3d+&6�)���=.�?���g������n����	:�.:��L�rk�����íY���5�#8x�\��8��lm;�>c0>k	���㔰�1,U�Ow��.�}ir)����?�w��`�����J�>ӫ�}Lb̢��歫:l3�X�"6��v����ԭ�F�E�O� �X�n�*��MElBg�ؾy��r<|z���cy�/9l�CSo�A���
S,�RHz>���k߹��^BM��j�p��Y�,��(7O�#��C�W�X!��˘=�ҩ��ف���/��:�bP�9�b�B�*���#~��4�fш��Q�j��w+��Y�$ٺ�������K��D_$T�'�pF�5����|�"Ug�rN��Xc����3���[X`��T_�($?�����
sL�%]���+�gT_�g� ����ŧm��M�E�F�Z/@?��PU�;F_g�t���U��Q�U�'5�m�-�ف��>�����	�x�4�������t�����0��,�q��w�l��Ǔ	MMYz�g�i:�_ ����gY��cv|��̳�r-7Ō#|�~O�i:RlQ,�&�S�����k��D����+�*eu�HӐ&�?dMҹouˬa�?�͑9��E�'5M÷x9���!�:��)�aj^{ǻV�A8�ģ(Ӂ�;p.+��	͹y�T�$�4qN�6|~5�WZ��1��ض�Ţ]���̪�����c�\U�\P0�	�����ʠ�1rKz�oR��G�07��KFO��,�)�m�޿+a+P����o�E�)�mp��upd��l��T�9{�.h-:38�=�Qt�p����4��I�(�$�L��y��4��ņ�/�L��I�0�cy�b],�%�s�Ꮏ��Ն�e�4��f�V�'� �X�
!(-c�-I�E��ϻm	W�8���H�i�L��pƿ�T`!��PK���xz���m��LzW�|���W��	�I7?����R�2,a��V,%�xNSſ���Nu	�`�J�&+����zv����ֳ)��N��q����o* �?&��9й�g���[��4K÷���i��t&�Զ���� ��fI��b�S�_g��q������Ut��)����
�oL��&D=F�}��vzĽ�5O*����ܔ`m�t����t5%ꈶ���lg�O�e�E4J��|���������2��Ų,0�M�YR���Ѣ��p�Դf��D�s�<e؍޺����!*�.�S�X��|�a�iNn+Y85>1k����}�������xgo6���|n��L���Q�f��]�?�����p��Q�V�?D��w*e��.��T&��w�`���L�W���T*���[�.�JE�%|n�0���
�?�]�V$b�abGM������c5v��/%xJ�4���+�?�:6����#3�=XoOyu����I�����3��=Ҍ�ʓB������wF.��5��ytq&�7|^`�ǂzKPeC�7i������?��(�aF�tzZ�~LѰ�����H��*��	��-�ep��CՌ������P��� ��sL�}2n�����no��̜b�g���O��
3L�ƐEr�0S�5|����A�]^1������"p�T�E"ӔZ5l�#�؃�7�`Xn�2w���̚�D���j6��lwSr���6x^�?�W2�(:�2�)�rӛy	��\ɑ��V�uf)�Û�V¹"�$4��YV�K&~�i?�j�h⏊O��tz~5�7ZJcN��A5-:�8���5�{j�W�Z.�;g��v
�����צ�&�P��(��m2�^K�k�ǎ���|~�ށ�E6ډ]����AS�r�c��Zm��r�WrAG�,�	��Y�h�/�8�QV�9J/�(- ތ��L��v���@wFNW�q����lAyZ.�̜E���K��&m_֕���''m����ò�Cq�&O%`L��l�}D��w��b+ȕ��?l0���%\�T����7�_�?T.>��F���:>���M��h�9H �� �&%�d8�o��1J��E��[�;����#G+:�(��eB����H;��Lb-�ܖ�����P</�s['���O��~
����Q��=�9��!h��)<u�}H�d��M� �9�����%�?8��qbZl2�A�������}��ЏE�䢈�\�L��w�ݹj�����K�����#\��!��!��L�����]���ႆ�L��s�K�*q*i��Ұ��A��3ܜ�8�]�;�󓹞P��Z�ص��N��������K�L��V�*VMu+w|���)��&��R`�R,���c����E������`�1�RJ2�2p����e�jn��U�'4%k�F�^�`�CF�Eq�;�Z�ѻ�����6�D��S�:��ޗ+��]�^����?H {��X\�7n�ؿJZ�Y/����ktN�E����S���"���M���@1O)��o���c�&j�AlҼ���IE��q�S4Q'��)@���i���K��M��śY;�h��c�Ƙ���M�i������Oɋ����Eu�^x~��;}�)|o����蠊�w�ۇ)Q�@����5��{�c��i�G`�u���Λ$/��G��+6R��7���┘B��c��t����b��^�2qS�fv���wA\"Ԅ�Sl>����utk�x�:�R�^?����/E.������;{��*6�$/���	������K��z'�j��4#Y�)���dA�uB:����·��A���G�(�g����璵����rU�,��2�h�������i8X'�7�#��ָ��/�?�lS�      g      xڋ���� � �      c      xڋ���� � �      e      xڋ���� � �      Z      x��\Ys�ȑ~��
��K���[{=ޘ{vv<��F8b�N�Pj�����$!�r��`&!����B�w$D�Q) Bb@V���W�}�j�vS�2�����n���$AG	:JP��:u�ϱ�C,�цҷuەU��U���� Ŷk���}���aTr�J�0OQb̵�)Q�=	�X����Ic�6�3�R8jA��v�S��FؔD��_3v�5�T���RN������/?�E�bp��n�l�Dɘ8G�;�|Om�0�$�g�׮�{��R�mʯ�kˡ�cgK_u~W��i����Z訅��1~M���%(7C�T�绂����V�:�d0!�{��0a^��<��KQ--��H���D��+xfKxg�1��>��T�|���*�)�X���>�}����ҵ��nP]5 W׆���j��E	M��T	��z������U5�0�|�]�C�h˭篚U����Jqj�`"��q�!:�p�1 �Jﳠƒ�}��F�u"�9�I�b�$�� H��0u[���2�O�f�W	F:��f~����v�W0G����)6e�����w],�'54SCs5��/v����n���+ϒ)���A��2�D��
,�Ӂ/���S����re��c%\��nq2!1�
��0N!�P�Ŝsbfi�yy������ t.��w��Т����7~�AJ����"M4�T5��4U�+��u���ױ��S��vX�E�.�����Ր��(n�#f.�2r��N�@���5��Kh�fާ$�����ra��aW�k�4�G�m�mDyrd��� ���"�PD'E��n�s���}�`�~�� ��[�w�w!�d+8��	Ew���з����e)7��<�x-���SA^�©��8���4=\����M_Af�>�}�O�Е:h��s����j=��ͦ��S�K|H�3$�u��AW�xW�8�Y�	���}Nةk7���ƌ2��"� ��C=1ʊYQ��\!��
S���+D-��i�3�\ ��p1�$���z 5���Ggo��؀w~�k��:k�/;��ſ�-�����)W]�\>C�ꎴR�HW�ط�p-�x�:������Ns��P'~U|�b��:�4?ӟz ��� D��V�fU�:�R!P�b7�A/:�E��s���t+>;R�1���{� ����K�H����j
�1s�
�a21i?Ub���p�����]��fX��ۺ�6�:n y�Z�G)�h.EU=<�E�s�����6�j�!�č��u�C|~_��@k�����d�#TK�ig�
�^�,��i�Yj�|�;�gTH]���H�H:7@!�ʔ������rk��laO:訃VT�t���X��}�d�y`�M ��=���y]��J�pW�۸1�5�K�e)�f*�I���:5�L�ӄ)��p�F?c��]��r���A�N���X|�T<�,�Q��r4�#p�z�*>9�X��hKW>�M��7��^��ݕ�م��C�ȅ�h��O�|���7� �@=V�#�6a�A�Q(�9f�I�7�8�e�q�&�����QƖ)�rL�k� �S�`{m�@��*9 �}ms�Y�]W�S�Tl�w���S��ڡ�<��{`?emw�uٷ���~�¥H� Ho�B�5s�R��5�I����� )J���ߋ�����.�ֻ1ϵ�Bc<�E8*�+4*��=wrS�91��!-ڔ���O���6@Y����S���f�m!=�2<���FR��{ˠ����q]"�R��ÜD��@8x��,b���)7Z�h�{�'5�X-��D��$N��h;���z�P��,�}Q���]os� �l�/���*:��bw�@g4�@��q-%+Tc!_G�%d��v��aG�TP�m[८����T���h�k��z�����v
2(��,@k���#�P�2-�
�8��dlSL��ܒ8a���-�C���Е�ֳ\�W��#ݬMH�^ىK"f%Sv����+��B���#����G�d�"G�z�<<�i�e׶����@�SUo��~��i|ojqO�L�Ѽ<%b�ˌ�M�vQq�1�	\&! �裩�djN(Щ%����j��SoO�:$�	z��L�a~���}�cc�RB�Ϗ�i,��xRA�b��[�� 4�������	����#�����S��}����h��UP���I�*@9P�IFXGA�w�CZ�X`�x�+�S%䢏g�����lff˃N_�t\SL��r��	���n�K�Z�J�#��[�9�� LV�^�Ѕz�?>�-��-M�Iȯ�6��64m7���O}��n�9���43_r��_��'�S^1��xh1\r���)�����H9�B��p�p�n�+���/.�d�4﵌0PdfK�j	8z&��"n.�܏��B�a;���a��b������꡶M��R��v�����6��ϻ�?�=e?T�� ���Fhe�rms�Tf0����ҵ���J�_�!���W/��>8L�p.Z��LCr�`Bʡ�H[8�(!~�+ƒ|y�mް��Y�$r՝E4�3�E�m������JE]������u�<�}?dnx3N'���<��A��m��U��=��U^<����'3d
�Ж�>��e����'��gn*�Hh�bmȌ;]0����(�i�6��
m�{�u�{�M��5�}*�&����k��Pl�#@J0�m�D�H��P��욄�a֢H�.˚ϔLu��m*�x
ڋ m_�[?��M�9�	�q!Gl�?�����gx��*КSk
iS�K���@!0��R'�$���S���#@ Fb$�Ȭ���!�rk�Y�CA�-΅4gG�J�?��W�����Z�8��
ڊ*��|�/����?��ǃ�'���ό��O�W�UO`���okwc�
�g�P�
z]��ֱ/������ ��⧱�k,!�`��iU���B���A�-m=vQ�l� �N�JF��	� U�Ѝ��=1�:m�w��5�B-�.B2�I@(�.�SC�)oIg����
�2���L��Lۇ�@z 9
���[��@�p	�ڰ��_�ǷH~밄7)[(7���4�y����� �����BK$���M�$Zl�LGƣ���|��f���/$u6�`.�r`���8�y����3�٭Ow�:�1�#�C��o߆�i������4.��2 �uc�����F�k�C�b�/��д��*����~�؜�c(�-8�]��t�����#	�f�o�߀��pp��>�v_�	�	
��"o!f
ıT�5�C�8N���5�׈�1��>ԫX� ִSt��tr��@#f1�Ry�Uv�������Р\��\]��m��JTfP�x�22}���zc�֓JG��*��P>,�dH ��(0����s��3�^8hԣ`ybby�����'H?4;q��䳛2k�S8��
�U��|#�r�X;�M�9t�D*���-�=KNxAB����^`�eD0��ҁ���+p2 ��p�T��S8kg�H���:�S��Q�iވ�:�ǹ(q?�K�|��<��8$T3%#��y��38MJ�p��+x
��Y��B(������U�	��O��S�v��L�x����XyE}�#F��6��C�)�0K�%�f��/�U!A�{�<�&�魵�o���i��0_�3�������x�����B秱���A��}�ky�#" �ZSE�RΦ��b^b����]1A����c�3_�\�ȫ�L�F���X�ݷ`wjr�Ճ�B�x�d����E��c��#��	"�D��!%/<��ͷK^����"� ��m"���f�	�h^�b�zv&zM~��D��n����Dܤ�|r����^�����Zs�O)s� �J�"V�$�g�3��e)0���괌5�\R��5�T�?����(.�̒��+����9Arm���ͼ���s�z�j�N?��4s�x�  ���Y�".o��K��S��%׳K^d෇�ࢄ�t1���F��6���KV&̕��ח<6���= �  ���1����틔J�e�4�~tD����0SR����axh6�8M�5���8��u�'b0e�az1�Yl��q��O#�~�su��8�A�X4
�Qǟ�v�\�.�c�װ�J�>��.��+�Gvq��A����<��	+9�V$+|`�	7���U �c&��\���p��6�a�nP17�T:ύ�ԴN�Y�c�.	(߬+"S�`=y4��o�W��믌�5�v8����Y����h���X�eX��`a�v������s�1����0@ꅒ�S��83��@E;)�+̀�/��(�K����J9�D �iau��9��&����ϊ7�(���K���������(�?�u߰�{��X��-j~�{mN0LX�m����"a+�Q��$�@k��+�fj��"H����8'���%���H\������g�>;AV�0���g'螛���h��fV����=�(6б�U��ƞD�,�RH�=uQI��ND:�Y$N
p�W�.�V��,4x�í.9� �Y)s5��ՊLo�;k�ҹy���۬���}���m3"�bl2L�n%�%ӳl�إ�B��nt�D/�s� ��;�~���P���K��~(�T]���2�h�C�_�~<̿�8�e�b�+>�F@�ێ�Xy3����ㆮ�9���j(ms��x�CY�w�� 
�cIJ� �vЈ[Ý�Iټ94iF��[�O�ik��B�����K���ݖ�ln�\.���rn�.�����
�"����g�Ӿ͓�p�r�4W@'���so�O������m5�e�����l���<׿�6��U�7��ˍ}�M��{9��*��3�Hi\	` ���!Ia����y$y��P=PM,V��WL ��&�lJ��v��2�'>��/��E����9G�������S���`֧.���8<��c���y��a:˂R��J�|l�m��qzw�c�7[�<S�yW�y~y+���y�r����%��@U]��M��6�
�Ħ��<gw���5K}�Azc<��:��l��3r�/�)�V���K[�.P5��/;�_�]<`����A��eҏc��^�	�'�U���+�O)�lW-�HT�v�{ k����s7Y���2~;�%�6:��V*j�W�*I�9�M�78!�%u B� \���^�Q��Z���ﵘ\���W���Y����jH1U�y�e��z8�c(ݸ�(oE��Ʈ�}q��G��#�����h���c�˺k��<U���7-�3}�?n�3�q�]�����V,������a�0vIB;�qǈ7D+P�",�2�q3��T����B�¡/V��]uP$r���z�
�f>�a��Jh��&J��}Tu���,d�lz�)��S���l��Ȫz��n�2��>w��-_�hI>OG������k[7��h�|�/6o̟0j����)<����ۍ�ym޻����a�C~J�bJ ��S J0{���6L��g���>��zDfXo�P�Zh���Z�y����_���(��yL|X��u�"�i|4��2 m�Y \4��X�kl�"�\�1�����b1�瘩�Ty�c(_o��:�sc�잆�*�;SB�G������P�ǽ]�-�e�������d�L �,&�t�c�1�FS��$��XkmU�6A�'��WR���/�4HoM};3@+�f3��ʧ�7����4N�� ��b?�U�DMTPe??��&o�8dE�Tpcf�)�M.3w�d�ђS���w~xKL2&c�HęG����AA ��X��,W!?ۂB�{�x��
��X ���X�<�8ے�4񗱐�/κ�����oG�])��":+�m�+��L=>ݡ��e��+w�eVQ=Ua&�Z0LX$�*凕LZYtP�C;$@/��c�9�sʱL� ���&��1�Ju�A�����!�.�,e�J�Y>��q��(� ��\I�����r��w��?�MTv      ]      xڭ�K��n@ǯWṣ:H� ��O�����S�B���`���B!A ~���1�X���$U�n��O�?A�#�C�7��A����ǌ�v�ʣ�;�E ���V[����>�������/�S����!�w�B���=J�d�y�L \�[}y�!������c�Ywތi�.bH��M!寈g��o�O�X#�0�\�N\S��p+�x�� &�S�ňO��x���e	��8qhy��.
q�4��W`1��֊NHE��gZt�S��Yw�ȒN��،��˘���CT��1��&���^�X����LT���sc��@<�$�;��Z��G��'cub�Ӟi�����7�@���>�VW��01EL��e+����ā�E�*�xS�<H�a�c�')�4�o�I�X�\��8��xs�w���x�J���Z�KN���G���V��	
j�O���^��:,H��X�4��B1wj�ϲ�o%�<�<!���w���V��S���>�1g�t_��e$r�r�!���$�ɸga�����k�%$q	9�&v����kE�� }G��Aw\�Q(�CC�p���':�2=����$O�T�~l�)b�woW�ɗN����z��,��ɖ
'v�cK��)��������%4�`\C��8/�k�L����b��&vy��a�<OC�7p���1ӖUt���O�6��6����g�.<9M�S
5�b�W�I=���4��G�G0���	�!��"��߲��(4,��z�B��'�?G�*�&�dR�:b�W4�����H�h{�	�O����4�YF+j����4�/ʜ�X��=+/f��X�S��d �FL#�qT��3{\ !�/��5AYN���WZ�c5G�o���"1܉y6؈ˊh�g|fܤ�`t0��v�pm�������� ��#��N��KY�ޛ�����ĕC5�z��Lƭ��hJ�$y@!c���15�Wl�ȁh�7��[1���q���2ɤ�䉎�H��0�3R�0+��\=�%$:-c���K�ޮfZb��4�/ɛ�1�kxLE.|���ɸ)�ۀ��Z7u9uS�,cZa$S�*��r��&�ٶ�f6���y�Q��%'��d&<�ы��Ya&��.��ibߺ[ꥻy-O�M���l�a��X3d��+\�4����f7�3yd�j���˸��3��<}+j���A�
�G���Zw#�t�����؊��x�.�M<"L�'�֬󺈃�`��0�f}-"%^�1b_�O�����v��H_�x`jLCT�:mj\�!>z�iJ[&��@ǉ��� u��p,bM��W�3f�I#�3�F��s��!ƫ�rةƤ�����&��E�sy4��I��!�|��#vB�u�ќWW���O�/8e�h^
���ն]�����Lt߲Y[mj���=���ic��7].	cJ§�}��5����<Z�9\� Nb�ݦf�l�f�f�ƞ�Q�m�c�N�&�F�j3=7L��ⴈ}Q��ُ��=�)��Į�t�l�.A�g<.cgL�Bn&�/�1n2����ڪ1���Q�t����
ˤx�)#I 9M�K��*��&<��_{�c��5�����12��IF|�?fŤx��3��+b�yZ����gM&aq�qI��ab��c�������r|Nƾ8hE�h�]y�R��4�˺Ͱȶ�@�Ș�m^�.�	�r�2�SS�6��+o�^�iB/��@�����"�AM����O�sFnS5RL�Y==�)�pX�@#	q��O��lfi����=S��W8��X8毈W���:�\�ۤ����;�S�o/=5�3ib��9��Z7W�]+|2��i�����BO*���#vY��#�S����c�x��;�W4]=���ȃ̜�9�ʱz�Bm`��Į�xAsd�U��/g�l0�-��H��l{wj<l<H��"&.x�����˘����2]�L�}D��4e͎�C�)�W2.P��ӕ��L�dYh�:���8��\MXǈ���BS�h���D�J�&���.���$	� �=[x���L�)'0��q�yZ5^�B�:��@�{���ib��hq���԰�p��?F�ty-M�(����W3�9��[+���qx�����LE��܉��h�tZ+|���sgyV^��k�/�q�VyxH�z��H�l�l����M�θ�>=VoE͞���1�ib_
2z4��<;���T������]�P��2JH��TRF8L��cM�Mg�,Zb�k�霌}d�C;uD�V������}a�dvyt�9~5a�ib_�b�{��S=N�:3v�����jw�{����W��9bW�Bk�B/��b�˸�I���ռ�i\Z3}O)�#�"�9rܘ]Ĕ�8�kOaEj�F�	6%���>�4�0�Q�#��~�8���a[�9�1�ي��S�|�J�#v��	�Yy�S'��+�8���W���:�3xES�������-�dRi�S
�b9-c�YiT1���H|k�B��1��[){ᐏa[�>�%�d|^G
B�H�^�ER�i��a3�+�2��*�C�V9�"�8"!RU��V,��v�LۉE�36i�g{���I��g��rQ���θ��i`��ъ�?��>�
�$g��v�WW�jv�J��
��ud�I�ش���p���(�ܩO��J�i�rk�hJ��(Y}6���b�b(������X�=Z;�C�r���Z�m���R������
��<T(�t��l����)y���:�7����l"��>��"].fn�Ǥ�(�l"Uى�=t�)
#��z�{�[.���Fh+��U��\��x�6�6�4��D�&��p�m-7Cutf��R}&b������&~��y��J�7�s��+�4�Sm]x�����<�E�v�\ܺ��"��鿝�?�q
�$�Q��XŻ$4P��N��w�UG2�2*�^����ք�ό)�����1}i�
L���s/T���΀ۦ�O+�i��z�1��捤𶚛
l��fޘ����h&�b�|�Fs�J�D���1:�~/+q"�ĺ�m�[��H���咧<�1e0)�Z=��Ư�%UsQ�ό[ʍmOp���+#��I�3�v�T��Uz~&��؜�	<��?J�#N���<s���f/�=�VbM��;c��%c�׍���c��#�3����(E	���.bVn���V�pʸ�47<ȳ�^Sx.�X65a�[Ix�z~��UMs�����ǯ�۴�wG��l6'�Q&LG+�qj�#q��֋��s�OI��L�K������X� �Vޘ#�sg�G3M�g�:�C�9��RH�R���x�˲Eϴ�����
��q���AF��g|�PJю�	�̸�So,�;�_C��+�&@�!<q���/�kn���	�h�G��D�����qIh~ţt'~�����Xx��Rb��1�)S,�?2.2�G��ͨ�j�lh���X���8ꎰ"���E,�����6sL2� �}���xb3�;�s�������3=���y��?)�vү1��EW`���"�8�6Z�ٓ�(ӡS��q����
���F���*J����;.��!^2^c��^���g����.ϸ%V>��y�	�6_c9l���$��l�C#t�SR�`�.�wX��$��-m���i'+�3k�jNs��,W@�$n����~��)��ڊ�)�A�k���9f;�wm��^T�kZ����K��Tb�����D�̹(���mk��QzMT�LE�\b����W�MΖʳ�[��	[B1��ڱ��0�f_{(�d<���s��Ѝ�����+�K^��K���z�v�e��ٌ�g,��� �#_�]��X]��gT`#����^�`�?�Ay�S�&����?sI��K'��6��qӤM�a�ԟ��+Z�����S^�[N�ySQM����&����a��� _����1'1�Ŷa;!9z�d�=Kǝ�42�dT����x�����ʣ����c�h����[7�=%��)�7�%�`O���L�>,�� ����N�n���� d{��.<�M�[�9 B  �1�����Xc�����tʸ�f{�1��8�k�����d���5gBs��2��L�غ�X�M����h3���x�dV���:6�&P����Z1��NB�wJ|2V�f���1�v���c��<��
e����� ���m.�^���kB/jٌ�`�H�+�f;��p�Q�j����lњ��L�К�-5!t3^��ǊM�)��V�8u��އ���TlխM���Ti'0�eC�&󉈧�S&[�m�W4�_��i��m���K���z�=X��QP�I]�3���Q�)�$�$ ~V�/�� �b���6/fFЄ��Q0�;��_���_�l�M�      \   _  x�͜Ao%���o?K�J�H�� ��� =((��8�]�ޤE���y�f3|Z$�%�}�<xf~�'%��&��A�b��.FwMZ����������������E��.�����������{�}��z=z�0���G?���׿׳�������Oǟ��t������.��xI�š��nR�s����@{g�:�%�����������?�.s��� g
��<������orL\I� ��(�\�E!��N'U<�̛,E�$`\I��3�4��آИ�p���c0F8�~?<a!ɇ��-+��J���R>SPs�BlgO�1���#�I�w���� ���$wz`�h<=���P Ig�ҋ+=�(ʌ)��(jt�G��$U,$��T3<�/=�(�a�\��! �<U��H����scr���h�L�GP��1�ى��s%Qm��Wz�P�X�'����?F��Ӊ�J�rA�T���E:�\�)��#��yj�"+ɑH��$��c���9�I<���� �؍�ϴ��v4����(%�I|r�����5&\H�9l!����(��dQ�;=f0NL�T~4�V�T~0OzlQ@�x�*� ��P8���0ĺ��H�w+/��En�GS��*zd�hJ�8�J2c1�9��c��f-l�����A<�4��f���(��z{qU�ڣ��h�v&w�V����c���EH�eMWzlQ���d�I���s� q%i�f8�՗;3@k&i��]��S1�J�P_IP�Y^ ���آH�MU�� ������$b^Hr8B��Ʈ�=
�i� $�;���2L�BZI�H&���G�����춮�ǯI�U��B�Y�)�϶��9�Wm|���j�����Ϳ���?.�s����9|�<9�B�9!3>�k�l��p���7�I�<���/�ף��%ӻ�"||���k"�4������?�����8?�v|��}�s~	F�9�6�H��V���7��$w�f[Iz`�B�nR��d�[wz4�3��h� $2�Y1��G}1���s(&m�ݣ� �[+�$��	���t�(��lJ�X�%�;�h��/���J�Wz�P	e�-+�]Il�0AL�Z��$�i���ee�l#mN�ƫ��r��d�0�3��c�"$�n��N�#�'�7�J�Y�I��+=�((2�I����
����rsi�9Hr�'W��E!�ub��N�R�0��w.$5@6�x[�{a=�(�j0c:���i�N9�h%iZLE6uv��E��Y��b'Ý�����7�(W�u�=rU2ޤЬfC�5��c�0�sRa��LS0��:o] s���!���H(�q�#�[IJ"�7���d�����q��N��MԏK_�A��7N�j�ݣ(*��ӣ��.�/A�ؚYAiH��آ�h�8�Ӄ+CR�2I��`?���c�b��	���c0�T��$���#lN�[�����8��G5��R!ǌ+I�,v��-d~b[ׁ*j��c�����t�h]���Rl�>��]�J���]�(��3mS�J�Td87���>���ȑ�rqW�%�%�NY��0��5p~�۹Θ=��p�펙��k�&�$s����vSGS���
�-$)��y����Ac%i��R�=�����lݍ(
��A_I��ǐ���?�(��� �\�5Rh��l��8��iѩp����آ�1�X�rW�VB6%v�P�[v+�p��F�A<8������k�����%�֟�c��U2�Q���4SݛSW�֢-֔�J�-�Q��]��f�ԃ�4��e���n���\���(f#�+����3�9�(+�j3E��]uklQ̨�f[5��g�d�K�/Xք8s�/�q���C�y�`���e�Mf�6�	���܃���P|��W�^�^��      [   �  x��Pێ�@}&_a�Z@�&i��>��~�v�r�̅�����^eW��<�ϱ}��\_��g{U��MrY+�AS���:�h�������"���]`�a �'=���5��K��	)�F�
� ��,ceQD�0Bͳ���/�a2�Gg����㖼ϠsV�h'���َ�/,����Ζ���\=	�G�WZM��l分�����a!'�V��h��MT$uR��>/�y]CuleS}+�>���Kꘗ���Cuj�c�?�CL���$�R�����HH��R��>&��HX'�1Sq,���7�D̴V�S���;7���{>�g����ӵZ�	�cQ�h+dw����ycs�����np���Ed/3�[~"C�{����٭?��P������g�����6$M      a      xڋ���� � �      `      xڋ���� � �      F      xڋ���� � �      E   x  x�}�Y��J��O�w�[�Xk��\T�!'yS@�������eF{ƶU�����W���9.�_�c�rM@կf<S��h:K�l�=l��to�ф	#z�����'�(��[���p�S�y���)��oP�'���Ї �(�Fc�b\��u� �;0�Nݼްѥ���~�q����wA�%8�����/��d��|� �����8|���VYFut:�\m��+��(���)�#���l�����su4��E?1r���q�|yP�y�o�F[�vX��Ze}�)I�������	���M�$�)H}rB�N	�j �'���k�)���c5NG�#�6�B�]�X�ئ��Og(���ڎN"�/��Hp�;�⾥�-�gx���:����_
x���a�x�1��������x�}�1yt��
����ۂÚ�miܢۃ�������>L�5�ˠo�i��7��'���)�#��J��5���k����-���u;�B��W��{4tk7<9}f�T��/�dҌ��,
���'b��1����������ڳ9Ů��k�� ���h���s�K����G�5��'�?�S�+�f8��tT�ӃuL� L�
�������H�4[wYg8��]O��|���va�]W/�(@���h����R�-�H�P�(��$������]ϋlN��<�b(u�l�4��%�}Z��J���V��-aN^{8���L���S�]=4��� z�p�K��,|;qB���Q�?�@�B��3Q�p�7���m{C{c�x��5ONO������u��ی�̦�(���D]v��V����0mq��C�K���o�������4�qQ�T�5H�\<�y��G����Mqy43�lJ�ጸ��7�4N^���k�a!:'� �>'��Y���Ǳ4�p��A�<��艇� _f[�8Z �<�ϩ�m	�Hi�GV'[õ��k��-�8^w�dۚ��mN�:շZt�l?=�I�ƃ)K��A�z��$A2��s˲�Wa�\�܍�#�n�����S�,u>�ȁ�\�P5��A;���_���1��BJ��}��Ex�n.xm�sxncR<���Y/)��A2���J-����՛N׃����X�.�(ʪ-�JW�Y<���B��i�n�W����ط#�����{�8���Tu�ա�PD�<�B���4'+��QY�u�,��.�'��8�S�I�f�1��'� �$��̔W�(9�D]He�������<$�?�vS�ĉS���̯��8@�r����g7j��2����"�i2͈�-U���3h9c���5s���wx�F�$���9�� <s��"���(���5�-�d��ۻ'"���2�LO��"�*�6"3��8ԛ�5)���Bv�h��Eu���qc4I�x��2�ɧ"�v"�PD������ܨ��O���8B�
9݁�e��]t4ʘ�3�+��T+ݙ.(KŎ������'�ɇP�b�����X���E�z����fy����!�� M�/Ԗ�HUɚ~�i�`����ͭ8����`2��~
���'h`� ��l���'o=A�+�ƀ���޳�(�9~���j�p8�&�������+��Lg��ޤR�n|�B� �f�<,�ֺ_�g;e"�]n�����@-Y�X��(.ūǥvo7#�}�	�o���4���!�� b9�e�U��v�i�^C]�­��M��������d�Q3�,���v���[���׃6�΂�vz�;̑=�2��avsy�R�"���g�,���g����v�6� �k��O�VY�[f��m�O7����J�cT7�]>��N
��s�ڙ%�Y" ����G����a�s����Q��])!Q��C#0/��Sj��h}��A�S�}�����3gN �^���9��V���Nf}E�rV&��G׼#���}�;���qpT�A�9~�RO�, �3� �/O�޶`I���x�����[�s�5g��u8�,^^�c��M������Y5�<e9�&�N��:��7��G"���Q��R��Z}ގ��	�X�u�i:�D/�0�a����񕪙H�*�K6X�<灱۱��rm����v��|>͋�ǥ��e!���'�u��c�jO��YI��������Ǐ���][      W   �  xڕ�ˮ۶���Sh����[��ΰ��l���#�v��?K�%S��zk-����B1�1�F ���3d��6ݹ�
g{���hj۞�̗�ѷ6-}wO@s
�<�����PL)�a�����)!	��a�R5D�K�˄b��T�t��s�p�e�d^!���UY��d˃G6�|�u�Z�\���� i(LC{$�-`o�s��B�t�`6���p<L�R�%ܡ.��v�+��![g�j�޶�G��n�A9h�A���FG�K���ɳ<�,��	�V=`qNLb�N.����]���J���Q�Z��G��}����P���4���߷�t#���TʸgZ+�'�^��2:�$ynZQ����P;Iה�A�ݭ{�A���]���?k���QUSq9�J��P%��Er���E��(E�|"��O��$�η�5A �4Ec �8�K�ϱ�f�V4F �KSs3�E�U�a}��ؔ�p�z�-\rj��n4�-�=� ȟ�0���1ʊEйy �\��Xt�œbɛ�J�����K:����ESݢ��ż_
i�km�nŧv�"��va�0n�W���1W�H��߻~�~��&�HWn���TS�EmWCq�n]J�1c��і���GM���à�|�nݯ9����R��1G��D�gf��׸�|�,Lz�ڶ��>L�	g|~ ݌PV�tudBj&���D�x�1Lr%Ux�y춙0ԇ خ v�����|=,)Y�{�����~4斃��1����ذ��9e�E�r�"/r傒0)d�e���o��Zk�do[�۪�G�As������r�(&s8�,���n������+e9���0w�֏�ټucq��i-�2f����E*��d�kt��t1�r�L�Tj�_��\�Pt�1�<���&"Na���}���jj�㧙{({�XNuȗӕ1�����s����Q�rql�'�9iyأ�9�j;rͣd��'�����p��WK�a������%l'ch��,����j+���|�q� �	'	N��00|����V����*�~$>�W���t�nڌ�0���O�h��m0F2�Ѱ���"�"��E/�+������`;׾�;V�آ��9(�Y6�������V`�$�`��U�p�����<ry��E#|�{�V>+�&����o��T���*	ݓ�5	��ʔ}��:���K�d�K`9�D��
�YUџ��o��Դ�߸����f�S���7C#�e�3�2�����	�W�%��$,�S��^��0��fx
o{W����%��I�1�F�tz�y��W^���ug�:!{1��i�=����y���~�/�9�[��������oH9FC��>&��b�q�k�9��^ �,;�L��1�F(1B����B>F����Z�.�+Pm���) a|��G{���LU�+���9,$�;e"U؆�����}|?|��+h�YU��~O���٨8>d�)	~P���d�s�(�!ϕ�d����/qI�%�5�#_�&7�U:�ͪG��<4�=�A�.�<{ڋ�X�Z�W���4�,<k�g,�W��w�<AF G��ׄ?�����t? �OG�p�#̴�r1nd��mNI�MF�����+	 ����}����A�#�\�d�|���-ߵf�?�5��|1�ă\:ʽ6�.�eٜ|�u�m��o!t�b2[�Y�B��Ё(U�O�)R�\��cdM�u�/I؂��>��v���)�aL�+�4���!"[��f<�����OT^�n/br���~!��sG�e\�k�ɘ\�I��]���4醇hx8|8�����Ⱥ<&�c)iT���t�3�+�������yۺ\ǳ2����pW�Y��j�pq��V�g�i�rfl��������˗�=��      Y   �
  xڝ�K�8�םS�~*)� A��2>���&�[S�_J�q�O� MM��#��y��ޏ����?���_�����O�����)��������#J��t��(��������ʮ^>�N�N��$���c}�7���!a��%���R8?tui>#�1E>H�ۈ��3��x ��ҋ�Z�f�G�J<{�^�ⓒ7bJ-������I9�Ғ� �)�����4�0��3����x#f7F>k��+	��8���d\���U�Ց�')d^xf��J�E�����"fMU�G�Fψ9�;�H����|�r߉��z�/��%�6��$cy2u#�묳�˨m#V/���
�V�'!�"M\���K�aN�q��"��RB(���جw��]a��֌��i/�)g��w\y=��/c/�e�lyX��V�Y|%h܈��d��qt������n�pq�!���O
�{�Cúy�?O�ίTTB��G+z]*bT�?$�I�����s�0�2�� �$�ĳ�d˗ͻ�(T�����f
޼��7buu���Zb�0Ix���R?cy�?"��M��+*�-�h�դKr3&Ή�˻���{ɴ��D)�墳m��^�>�la#��c6N�#DV��
%]�9?����pv:�.�e@zV��
�+4:�q�K�&����_�ge/�n.Pcm������əLh%x�+�"͘���''&ep[~���p��q�N����Ms�4�?ވ��4����TGW���a'�dM,��~��o��X���!�h���v�V��bC9�m�@�4�u�m"u��\�FfD�!�O~�Cz��`={�4b
.2^��2F*S�)��r!&�A�Ei�x�9ie�q�w���|v&�)=�
�xDbk�ָ&>UM1�+0���6�AĒ\�A�e�qG\9�X@����+���Wh�a��B�!���wՔ��F�2�3_���φ�="�-
��X	��bz�2�\�7�1���G��dn�3�O=,����2`�v�����]7��t�t.��֝$�8�?v�	1O��is�ĈV�����>!؋E��:Gg��/��
�7:���!�Ņ���4$�\g�Vd���ó�#f1�.�F�9%4<��ڌ_G�����b�� by����*r�(���B4��.~��t�� ī
��n��vw	A�y�u:B,O�)u㍧�g�f���� kzw�b0Fcą�mh(B��N�c�#4��� �7�t1�p��+��G�%7���	#f��˝?���X:�53i��5��C��h�8j��v������<л!�����(���3>�
d���<�8�>�d&����3}*bC^F�LW�� .�����9�� ��#�Ks�_'�'
1}�4��c�)����฼�bl��a{1D�X��#i,sCF�%���-�	 �.э!:��0�:�ل���G���3<d�^ֿ3u��B1�$81(c�X�T�"�!��g��V�0�!�^��c�8�h��N=B|4�oc�"VoK��B(~Fy�j��jE�ZTM �!��|c�I#�E��g��҃X�bH+0�ѫI6�	����{��F���G�K��]@�%���#�+��^)U�6�[���=��U(�I�#�+G���Z!���e�Ayc��96�c���HCĘ���c�g5.�!Jc��PK2'��!�H���!b̵ač�ݔ�qN�oc�"0s1R$|�
Op`��W�m�� ��)�X��Y+c�SS�ψx��ٽe��[��2��#��URFj����`����kf�B�"�<�(�1�*0�X�¿�Drc���n��x��h
�#�S�;Z���"�Յ��bZ�B�*7�51�@�5��9�]��},��s�����6��mͺ�Ѽ�����I?;���ֵ=?���W�0-7��ls�(w�15F�'�a�O�������'�"j'k�(~���4m���yt'YI�)�
҆U�+���x���<z�-�Ξ�0�\��q���ws#�ކ�x3W�8��?��g�:��*�����H�]� q����;���&�=NXGx�&�}��q,-�K�C݈u{	�0��fwz/�ooedz$c�8�P���^��#���{r3�ao��G2N�p2�Q�F�T�9N!���M�ٶ*��gz���l��}�ę_�C&��ua�qP�����-������-���ua������ۧg�5�b��&�z|l��U��b%�AjB�q�&��Y�/�����꧉�~�h�d�1��pu���9�R��~�\�X�5eZG8on���YF,��R��� N_��U'��Ya�ln��A��d~[@�_9��%����bZ�ᡌ!���^�v�X�+�A��f�cًD�u=���}���[Y�k_�w颦��~��^Y��ɸ/9��Yu�V:��nGQ���E�[���yY͸��P`�m���U�n�U�i��1�d�-��\���g�u��9��߈��C���� �����8����3��Ӱ�~Y�8�W�31�9��_#�uD�՘��O�{�3�N�7���c� >B7��L�YI�C��Ȥ]�
@�V�ႚ5k��-dt��h�Ch)�n�#��>���{�0����:�Ct8�jQ~;�uD����[��O�2m�M��Iq^����FE�\Ag�Md���:"uo���Bc)}��#������Ǐ����      X     xڥ��N�7���{��;�{��JU~���,,T��f6s���O
B�����k;&��T�-��nr�����~�������/'��x:���?����������'��V) �kc/S/%�_.�.���@���PPT�,E� ������@+p�;䝘�����������~����6��e7������53K��PD�C�4�h�}���56B� ��y�C�)�@p�ہ�����!�s��"�����b>�6�Mbot��0X��=��f���lE���Tx"p
�pH��������6�Ta[ �A$�A$�$+BMW���s��0`���dP�L#`�y���\�B��d,������e��Q�.�qth�jMȗ@H.����{D0&�2���H�Pq#�1@o�^�Y��THہx�x��u�"�heM�.���\�Ӛ�Q]��9�Ӡ���`t���"�ڨA"�CR~&�:��  o"B�g�a/=bD�?~͡�����4Q&�D��0CM&X#�Za�&QZ���)0�A��v ��b9nW�%mZE샀j(gܚ��X����%��H%퍡μk�Q��M�)�w)z� �u���T��������d��]솲�a�Dk�C���B�3AA�5�]J��jRHX���4�K�i����@�p���!u�r�@�pu��c�X��Z�ծ����֤gƠ��d��RA��(/9�~`M�9�^�}Epr������)lC���P�B�e�J��GC���NT�f��sE$Öa�s^2G#VS�d���6��W&��d/봹�G<���oC�2�լ�A`���'�ĵ���֝��#k��3A�[7�]y`8�o�mg/2� UP���ĀP[57HyK������Zb���﷗oO����a�΢�k2�:9I�A����$C��Q�+��������!�B�� B����̚��-��r�|?8�b�|�X�77���z�՛�M��r��L$�Đ,��]��t%��t�����[Y��h쐴����v��"C]lÀ1�y�ޤ��"�ӷӏ��&k�,wA$Nu���R6���N��21[;tK�D ���_�kZ9h�c�P,���P>�e/��8\LѢ�T	�n�,�r�<~=JA��Z�[$@}~�o	ǵ=;d��o�l�\�g�����!Cs�}��9���x�G���/�6!��*j;�!c�N��[�W��-��r,�F�)2fJ`�<]٨Nx��>lBp�p�ağ�������`;     