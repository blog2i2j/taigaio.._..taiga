PGDMP  	         8                z           taiga    12.3 (Debian 12.3-1.pgdg100+1)    14.3 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    8595335    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    8595459    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            �           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2                       1247    8595782    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false                       1247    8595772    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            �            1255    8595847 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
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
       public          taiga    false                       1255    8595864 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
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
       public          taiga    false            �            1255    8595848 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
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
       public          taiga    false            �            1259    8595799    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
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
       public         heap    taiga    false    770    770            �            1255    8595849 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
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
       public          taiga    false    237                       1255    8595863 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
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
       public          taiga    false    770                       1255    8595862 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
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
       public          taiga    false    770            �            1255    8595850 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
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
       public          taiga    false    770            �            1255    8595852    procrastinate_notify_queue()    FUNCTION     
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
       public          taiga    false            �            1255    8595851 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
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
       public          taiga    false            
           1255    8595855 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false                       1255    8595853 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            	           1255    8595854 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
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
       public          taiga    false                       1255    8595856 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
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
       public          taiga    false            >           3602    8595466    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
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
       public          taiga    false    2    2    2    2            �            1259    8595419 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    8595417    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    8595428    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    8595426    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    8595412    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    8595410    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    8595389    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
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
       public         heap    taiga    false            �            1259    8595387    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    8595380    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    8595378    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    8595338    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    8595336    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    204            �            1259    8595700    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    8595469    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    8595467    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    8595476    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    8595474     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    8595501 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    8595499 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    222            �            1259    8595657    invitations_projectinvitation    TABLE     �  CREATE TABLE public.invitations_projectinvitation (
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
       public         heap    taiga    false            �            1259    8595829    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    773            �            1259    8595827    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    241            �           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    240            �            1259    8595797    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    237            �           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    236            �            1259    8595813    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    8595811 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    239            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    238            �            1259    8595573    projects_project    TABLE     �  CREATE TABLE public.projects_project (
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
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    8595601    projects_projectmembership    TABLE     �   CREATE TABLE public.projects_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 .   DROP TABLE public.projects_projectmembership;
       public         heap    taiga    false            �            1259    8595593    projects_projectrole    TABLE     	  CREATE TABLE public.projects_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 (   DROP TABLE public.projects_projectrole;
       public         heap    taiga    false            �            1259    8595583    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb,
    workflows jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            �            1259    8595720    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    8595710    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
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
       public         heap    taiga    false            �            1259    8595358    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb NOT NULL,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    8595346 
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
       public         heap    taiga    false            �            1259    8595739    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    8595747    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    8595515    workspaces_workspace    TABLE     T  CREATE TABLE public.workspaces_workspace (
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
       public         heap    taiga    false            �            1259    8595530    workspaces_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_workspacemembership;
       public         heap    taiga    false            �            1259    8595522    workspaces_workspacerole    TABLE       CREATE TABLE public.workspaces_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 ,   DROP TABLE public.workspaces_workspacerole;
       public         heap    taiga    false            �           2604    8595832    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    241    240    241            �           2604    8595802    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    236    237    237            �           2604    8595816     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    238    239    239            �          0    8595419 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    214   ��      �          0    8595428    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    216   ��      �          0    8595412    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    212   ף      �          0    8595389    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    210   T�      �          0    8595380    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    208   q�      �          0    8595338    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    204   v�      �          0    8595700    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    231   Ǫ      �          0    8595469    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    218   �      �          0    8595476    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    220   �      �          0    8595501 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    222   �      �          0    8595657    invitations_projectinvitation 
   TABLE DATA           �   COPY public.invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    230   ;�      �          0    8595829    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    241   ݳ      �          0    8595799    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    237   ��      �          0    8595813    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    239   �      �          0    8595573    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, slug, description, color, logo, created_at, modified_at, anon_permissions, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    226   4�      �          0    8595601    projects_projectmembership 
   TABLE DATA           b   COPY public.projects_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    229   ��      �          0    8595593    projects_projectrole 
   TABLE DATA           j   COPY public.projects_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    228   ��      �          0    8595583    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    227   �      �          0    8595720    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    233   <�      �          0    8595710    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    232   Y�      �          0    8595358    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    206   v�      �          0    8595346 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, date_joined, date_verification) FROM stdin;
    public          taiga    false    205   ��      �          0    8595739    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    234   ��      �          0    8595747    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    235   \�      �          0    8595515    workspaces_workspace 
   TABLE DATA           t   COPY public.workspaces_workspace (id, name, slug, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    223   U�      �          0    8595530    workspaces_workspacemembership 
   TABLE DATA           h   COPY public.workspaces_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    225   U�      �          0    8595522    workspaces_workspacerole 
   TABLE DATA           p   COPY public.workspaces_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    224   ��      �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    213            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    215            �           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 88, true);
          public          taiga    false    211            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    209            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 22, true);
          public          taiga    false    207                        0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 28, true);
          public          taiga    false    203                       0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    217                       0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    219                       0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    221                       0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    240                       0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    236                       0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    238            �           2606    8595457    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    214            �           2606    8595443 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    216    216            �           2606    8595432 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    216            �           2606    8595423    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    214            �           2606    8595434 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    212    212            �           2606    8595416 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    212            �           2606    8595397 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    210            �           2606    8595386 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    208    208            �           2606    8595384 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    208            �           2606    8595345 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    204                       2606    8595707 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    231            �           2606    8595473 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    218            �           2606    8595484 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    218    218            �           2606    8595482 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    220    220    220            �           2606    8595480 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    220            �           2606    8595507 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    222            �           2606    8595509 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    222            �           2606    8595663 Z   invitations_projectinvitation invitations_projectinvitation_email_project_id_b248b6c9_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_email_project_id_b248b6c9_uniq UNIQUE (email, project_id);
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_email_project_id_b248b6c9_uniq;
       public            taiga    false    230    230            �           2606    8595661 @   invitations_projectinvitation invitations_projectinvitation_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_pkey;
       public            taiga    false    230            '           2606    8595835 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    241                       2606    8595810 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    237            "           2606    8595819 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    239            $           2606    8595821 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    239    239    239            �           2606    8595580 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    226            �           2606    8595582 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    226            �           2606    8595605 :   projects_projectmembership projects_projectmembership_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_pkey;
       public            taiga    false    229            �           2606    8595635 V   projects_projectmembership projects_projectmembership_user_id_project_id_95c79910_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_user_id_project_id_95c79910_uniq UNIQUE (user_id, project_id);
 �   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_user_id_project_id_95c79910_uniq;
       public            taiga    false    229    229            �           2606    8595600 .   projects_projectrole projects_projectrole_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_pkey;
       public            taiga    false    228            �           2606    8595625 G   projects_projectrole projects_projectrole_slug_project_id_4d3edd11_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_slug_project_id_4d3edd11_uniq UNIQUE (slug, project_id);
 q   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_slug_project_id_4d3edd11_uniq;
       public            taiga    false    228    228            �           2606    8595590 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    227            �           2606    8595592 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    227                       2606    8595724 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    233                       2606    8595726 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    233            	           2606    8595719 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    232                       2606    8595717 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    232            �           2606    8595369 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    206    206            �           2606    8595365 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    206            �           2606    8595357    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    205            �           2606    8595353    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    205            �           2606    8595355 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    205                       2606    8595746 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    234                       2606    8595756 C   workflows_workflow workflows_workflow_slug_project_id_80394f0d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq UNIQUE (slug, project_id);
 m   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq;
       public            taiga    false    234    234                       2606    8595754 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    235                       2606    8595764 P   workflows_workflowstatus workflows_workflowstatus_slug_workflow_id_06486b8e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq UNIQUE (slug, workflow_id);
 z   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq;
       public            taiga    false    235    235            �           2606    8595519 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    223            �           2606    8595521 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    223            �           2606    8595553 Z   workspaces_workspacemembership workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq;
       public            taiga    false    225    225            �           2606    8595534 B   workspaces_workspacemembership workspaces_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacemembership_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacemembership_pkey;
       public            taiga    false    225            �           2606    8595529 6   workspaces_workspacerole workspaces_workspacerole_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workspaces_workspacerole
    ADD CONSTRAINT workspaces_workspacerole_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workspaces_workspacerole DROP CONSTRAINT workspaces_workspacerole_pkey;
       public            taiga    false    224            �           2606    8595543 Q   workspaces_workspacerole workspaces_workspacerole_slug_workspace_id_a006f230_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacerole
    ADD CONSTRAINT workspaces_workspacerole_slug_workspace_id_a006f230_uniq UNIQUE (slug, workspace_id);
 {   ALTER TABLE ONLY public.workspaces_workspacerole DROP CONSTRAINT workspaces_workspacerole_slug_workspace_id_a006f230_uniq;
       public            taiga    false    224    224            �           1259    8595458    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    214            �           1259    8595454 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    216            �           1259    8595455 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    216            �           1259    8595440 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    212            �           1259    8595408 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    210            �           1259    8595409 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    210                       1259    8595709 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    231                       1259    8595708 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    231            �           1259    8595487 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    218            �           1259    8595488 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    218            �           1259    8595485 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    218            �           1259    8595486 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    218            �           1259    8595496 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    220            �           1259    8595497 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    220            �           1259    8595498 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    220            �           1259    8595494 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    220            �           1259    8595495 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    220            �           1259    8595694 4   invitations_projectinvitation_invited_by_id_016c910f    INDEX     �   CREATE INDEX invitations_projectinvitation_invited_by_id_016c910f ON public.invitations_projectinvitation USING btree (invited_by_id);
 H   DROP INDEX public.invitations_projectinvitation_invited_by_id_016c910f;
       public            taiga    false    230            �           1259    8595695 1   invitations_projectinvitation_project_id_a48f4dcf    INDEX     �   CREATE INDEX invitations_projectinvitation_project_id_a48f4dcf ON public.invitations_projectinvitation USING btree (project_id);
 E   DROP INDEX public.invitations_projectinvitation_project_id_a48f4dcf;
       public            taiga    false    230            �           1259    8595696 3   invitations_projectinvitation_resent_by_id_b715caff    INDEX     �   CREATE INDEX invitations_projectinvitation_resent_by_id_b715caff ON public.invitations_projectinvitation USING btree (resent_by_id);
 G   DROP INDEX public.invitations_projectinvitation_resent_by_id_b715caff;
       public            taiga    false    230            �           1259    8595697 4   invitations_projectinvitation_revoked_by_id_e180a546    INDEX     �   CREATE INDEX invitations_projectinvitation_revoked_by_id_e180a546 ON public.invitations_projectinvitation USING btree (revoked_by_id);
 H   DROP INDEX public.invitations_projectinvitation_revoked_by_id_e180a546;
       public            taiga    false    230                        1259    8595698 .   invitations_projectinvitation_role_id_d4a584ff    INDEX     {   CREATE INDEX invitations_projectinvitation_role_id_d4a584ff ON public.invitations_projectinvitation USING btree (role_id);
 B   DROP INDEX public.invitations_projectinvitation_role_id_d4a584ff;
       public            taiga    false    230                       1259    8595699 .   invitations_projectinvitation_user_id_3fc27ac1    INDEX     {   CREATE INDEX invitations_projectinvitation_user_id_3fc27ac1 ON public.invitations_projectinvitation USING btree (user_id);
 B   DROP INDEX public.invitations_projectinvitation_user_id_3fc27ac1;
       public            taiga    false    230            %           1259    8595845     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    241                       1259    8595844    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    770    237    237    237                       1259    8595842    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    770    237    237                       1259    8595843 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    237                       1259    8595841 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    237    237    770                        1259    8595846 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    239            �           1259    8595621 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    226    226            �           1259    8595655 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    226            �           1259    8595622 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    226            �           1259    8595656 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    226            �           1259    8595651 .   projects_projectmembership_project_id_ec39ff46    INDEX     {   CREATE INDEX projects_projectmembership_project_id_ec39ff46 ON public.projects_projectmembership USING btree (project_id);
 B   DROP INDEX public.projects_projectmembership_project_id_ec39ff46;
       public            taiga    false    229            �           1259    8595652 +   projects_projectmembership_role_id_af989934    INDEX     u   CREATE INDEX projects_projectmembership_role_id_af989934 ON public.projects_projectmembership USING btree (role_id);
 ?   DROP INDEX public.projects_projectmembership_role_id_af989934;
       public            taiga    false    229            �           1259    8595653 +   projects_projectmembership_user_id_aed8d123    INDEX     u   CREATE INDEX projects_projectmembership_user_id_aed8d123 ON public.projects_projectmembership USING btree (user_id);
 ?   DROP INDEX public.projects_projectmembership_user_id_aed8d123;
       public            taiga    false    229            �           1259    8595633 (   projects_projectrole_project_id_0ec3c923    INDEX     o   CREATE INDEX projects_projectrole_project_id_0ec3c923 ON public.projects_projectrole USING btree (project_id);
 <   DROP INDEX public.projects_projectrole_project_id_0ec3c923;
       public            taiga    false    228            �           1259    8595631 "   projects_projectrole_slug_c6fb5583    INDEX     c   CREATE INDEX projects_projectrole_slug_c6fb5583 ON public.projects_projectrole USING btree (slug);
 6   DROP INDEX public.projects_projectrole_slug_c6fb5583;
       public            taiga    false    228            �           1259    8595632 '   projects_projectrole_slug_c6fb5583_like    INDEX     |   CREATE INDEX projects_projectrole_slug_c6fb5583_like ON public.projects_projectrole USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.projects_projectrole_slug_c6fb5583_like;
       public            taiga    false    228            �           1259    8595623 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    227                       1259    8595733 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    232                       1259    8595732 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    232            �           1259    8595375    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    206            �           1259    8595376     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    206            �           1259    8595377    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    206            �           1259    8595367    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    205            �           1259    8595366 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    205                       1259    8595762 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    234                       1259    8595770 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    235            �           1259    8595540 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    223    223            �           1259    8595572 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    223            �           1259    8595541 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    223            �           1259    8595569 /   workspaces_workspacemembership_role_id_41db0600    INDEX     }   CREATE INDEX workspaces_workspacemembership_role_id_41db0600 ON public.workspaces_workspacemembership USING btree (role_id);
 C   DROP INDEX public.workspaces_workspacemembership_role_id_41db0600;
       public            taiga    false    225            �           1259    8595570 /   workspaces_workspacemembership_user_id_091e94f3    INDEX     }   CREATE INDEX workspaces_workspacemembership_user_id_091e94f3 ON public.workspaces_workspacemembership USING btree (user_id);
 C   DROP INDEX public.workspaces_workspacemembership_user_id_091e94f3;
       public            taiga    false    225            �           1259    8595571 4   workspaces_workspacemembership_workspace_id_d634b215    INDEX     �   CREATE INDEX workspaces_workspacemembership_workspace_id_d634b215 ON public.workspaces_workspacemembership USING btree (workspace_id);
 H   DROP INDEX public.workspaces_workspacemembership_workspace_id_d634b215;
       public            taiga    false    225            �           1259    8595549 &   workspaces_workspacerole_slug_5195ab3f    INDEX     k   CREATE INDEX workspaces_workspacerole_slug_5195ab3f ON public.workspaces_workspacerole USING btree (slug);
 :   DROP INDEX public.workspaces_workspacerole_slug_5195ab3f;
       public            taiga    false    224            �           1259    8595550 +   workspaces_workspacerole_slug_5195ab3f_like    INDEX     �   CREATE INDEX workspaces_workspacerole_slug_5195ab3f_like ON public.workspaces_workspacerole USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.workspaces_workspacerole_slug_5195ab3f_like;
       public            taiga    false    224            �           1259    8595551 .   workspaces_workspacerole_workspace_id_04ff6ace    INDEX     {   CREATE INDEX workspaces_workspacerole_workspace_id_04ff6ace ON public.workspaces_workspacerole USING btree (workspace_id);
 B   DROP INDEX public.workspaces_workspacerole_workspace_id_04ff6ace;
       public            taiga    false    224            G           2620    8595857 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    251    237    237    770            K           2620    8595861 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    237    267            J           2620    8595860 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    237    266    237    237    770            I           2620    8595859 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    770    237    237    264            H           2620    8595858 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    237    237    265            -           2606    8595449 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    212    2983    216            ,           2606    8595444 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    214    2988    216            +           2606    8595435 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    208    2974    212            )           2606    8595398 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    208    210    2974            *           2606    8595403 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    205    2960    210            .           2606    8595489 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    220    2998    218            /           2606    8595510 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    222    3008    220            ;           2606    8595664 V   invitations_projectinvitation invitations_projecti_invited_by_id_016c910f_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_invited_by_id_016c910f_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_invited_by_id_016c910f_fk_users_use;
       public          taiga    false    230    2960    205            <           2606    8595669 S   invitations_projectinvitation invitations_projecti_project_id_a48f4dcf_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_project_id_a48f4dcf_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 }   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_project_id_a48f4dcf_fk_projects_;
       public          taiga    false    3040    230    226            =           2606    8595674 U   invitations_projectinvitation invitations_projecti_resent_by_id_b715caff_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_resent_by_id_b715caff_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
    ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_resent_by_id_b715caff_fk_users_use;
       public          taiga    false    205    2960    230            >           2606    8595679 V   invitations_projectinvitation invitations_projecti_revoked_by_id_e180a546_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_revoked_by_id_e180a546_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_revoked_by_id_e180a546_fk_users_use;
       public          taiga    false    230    2960    205            ?           2606    8595684 P   invitations_projectinvitation invitations_projecti_role_id_d4a584ff_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projecti_role_id_d4a584ff_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projecti_role_id_d4a584ff_fk_projects_;
       public          taiga    false    230    3051    228            @           2606    8595689 ]   invitations_projectinvitation invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.invitations_projectinvitation
    ADD CONSTRAINT invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.invitations_projectinvitation DROP CONSTRAINT invitations_projectinvitation_user_id_3fc27ac1_fk_users_user_id;
       public          taiga    false    2960    205    230            F           2606    8595836 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    237    241    3101            E           2606    8595822 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    3101    237    239            5           2606    8595611 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    205    2960    226            6           2606    8595616 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    226    3019    223            8           2606    8595636 P   projects_projectmembership projects_projectmemb_project_id_ec39ff46_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmemb_project_id_ec39ff46_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmemb_project_id_ec39ff46_fk_projects_;
       public          taiga    false    3040    226    229            9           2606    8595641 M   projects_projectmembership projects_projectmemb_role_id_af989934_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmemb_role_id_af989934_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmemb_role_id_af989934_fk_projects_;
       public          taiga    false    228    3051    229            :           2606    8595646 W   projects_projectmembership projects_projectmembership_user_id_aed8d123_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmembership
    ADD CONSTRAINT projects_projectmembership_user_id_aed8d123_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_projectmembership DROP CONSTRAINT projects_projectmembership_user_id_aed8d123_fk_users_user_id;
       public          taiga    false    229    2960    205            7           2606    8595626 T   projects_projectrole projects_projectrole_project_id_0ec3c923_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectrole
    ADD CONSTRAINT projects_projectrole_project_id_0ec3c923_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.projects_projectrole DROP CONSTRAINT projects_projectrole_project_id_0ec3c923_fk_projects_project_id;
       public          taiga    false    228    3040    226            B           2606    8595734 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    233    3083    232            A           2606    8595727 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    208    232    2974            (           2606    8595370 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    2960    206    205            C           2606    8595757 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    234    3040    226            D           2606    8595765 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    3089    234    235            0           2606    8595535 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    223    2960    205            2           2606    8595554 Q   workspaces_workspacemembership workspaces_workspace_role_id_41db0600_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_role_id_41db0600_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_role_id_41db0600_fk_workspace;
       public          taiga    false    3024    224    225            3           2606    8595559 Q   workspaces_workspacemembership workspaces_workspace_user_id_091e94f3_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use;
       public          taiga    false    225    205    2960            1           2606    8595544 P   workspaces_workspacerole workspaces_workspace_workspace_id_04ff6ace_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacerole
    ADD CONSTRAINT workspaces_workspace_workspace_id_04ff6ace_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workspaces_workspacerole DROP CONSTRAINT workspaces_workspace_workspace_id_04ff6ace_fk_workspace;
       public          taiga    false    3019    223    224            4           2606    8595564 V   workspaces_workspacemembership workspaces_workspace_workspace_id_d634b215_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_workspace_id_d634b215_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_workspace_id_d634b215_fk_workspace;
       public          taiga    false    225    3019    223            �      xڋ���� � �      �      xڋ���� � �      �   m  x�m�ێ�0E������{���*&�	m���|����`�=Z;��s��a��2+9�B}��	v,��K�
/5x{�]ƬY%x��Q>�Jp�J�Z㟓���s���7^����}ZfVj߰�[�%���CW�ZS`� JH�	��[޷彲J꿹���۷^���c�2�8@[���<�{q�z�7������Q1+�}��N�l�rZ-P��ۥ��f���Q-0V�cW�
��rXy	R�J��k����p���N���d
��^��	@Ժ
�A�X��򔬣��/۬�ľ&�e�]&7�>#���ᯙ/������V��.a�W�|#�{a^�ۑ|��e�)IӾ�Ӹn�_yS�j^Y�Wd��V#s0��ra��;�!]lT(�Z��:޺ts˼�3�$EmC�&A���%�Ab�(�D�LG!��>�u�k�h���\�-L�N8��$�p�D��p��6ׂ&iw�F4L{a�O��(v� }�y._LT~��g�$��0rC&��HgCF3�8?����bW�z�L�DҬ�ΩB&2v�&��H��ڴ�HI�}�?�c���OV��Mv�i��,g����ɂp��|œ��0��]nL�o��7oɸ�m[�d�a-�����<�գ50a������[2���.%�IP+P�Ej����[��8�8��B-��񳚯/l�uޑQ��y%����&i�5���X��Q���iWrt!���6B�7���� ��\ЖK�0ù�����ּ���X�/�y��4{�]�-E�̞rwfC�xe���2["L�z�_�0=Yi>�~��d�h��%�GX+,�!!�"pMjY��K��geI���۬z��[�?�}�W��gJFq�¿~p�����      �      xڋ���� � �      �   �   x�uP[n�0��3T��.7��~��[��s�&+��ǠH�����A(���} �L�^%��2�`�d�K��2��A��Ս<�^1��xpP����LS�g�U:GGpZ�<�e�m��J9�P#<�͂��!@\hc����1���;�p�²)�W6�l�^��A���x|M�B[#�$^���"�4�6t#x�����,�OEo��/��u��Xr�X�B�!h���Z_�G�� �d��      �   A  xڍ��n� ������U+��,+!���m\����HJ��#�&R✏�3�1n�Ɇ�Aa���@ OH>a���/����X������!�!��h�(���4��ݰ.a�,�ћt���p�����j3G�M�.3h*�f�1ȍ�t���>t��'����E�Cf���w5�:?у��2JP�"�D��?���)E�BVh�E�hC�)7�OԽ�ҝ��_�(F���*�\Q9���u��'S0�z���?��Cp�W�gtf�yZ.�6w�������@�g�Dʨtvm"�e �T��V�a:ך��T�bC�A�v���AT�����aZqrќ�b߅�JR?,ڄ�)u��7
�+��<nÀ�^)\Ë���d��c�_�D.�#�b��U�3���.lm�V�TӾ�_%��,1�X3�u<���B�a�I�^�xI������ɐ�J4�>�M��o٥����"$M2����U�@�,�h�M,ŭ+Iۧ(��t�-�~�r
ҍ�dm�V�>�E*$.x3�k\V���+2�D�f����R4�X}�����鍗u�w��?��      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �  x�͜ώ7�����b��(*�<A����� �}�e�,�M;��e��0`̠�]_S$")�B�9�+�_�x�e�k�'Pȱ���s����������~}������ㅀ���oH?��CH�(�;��|�i�;���Z��OY1��SfP��_����kop�~(��}��?f���t
_��OX�~����G�T�?��
7�-t�G�!�u�O�'����I��#�R��)�,��g�ҡ������~�t|,I��~�Q�C_>����`����8Z?ėS��� ?t���Gn|�_N���~���"!|�������ۿ����^~�������?������O\��ׯ������z�HC���>&�d���%Oώ�`\��7zv}��g+~���<{N>��?tl�������G�/�=�a?�1>����1�q;��:H�'ú���-�hA\�z���.g���g��o�O��Y=�z@� �r]�>?�0O~>��{��mr=�$���O�������l�/���{`K��:z6Ax(��H-��m&R]�
;:�F/w��96�>��c+~�r|�cW����h�����8�nL�Sf~��AR?�Io�2�{�6�"���2��`8�c��6�o`~�v%4�H�����7U�C�k�&>ŗr|[�<A΅��4��#��k�����(�6�x���tk6ϸ�A
k��aK�F��֢�~!OI����6I�y�����%��
d!�"Ԇ��r�7ǎ���ѱ0�N�w��'�95[�m%��\<;jZ�������F�VI�<�0������tI�1/�r.�}��}�70�-�I�trX�^n`{[�9JA��O���G��R�U�!�C+{�I3�U
ե
���9��3� ߶��Kw�a����e����zBm���������Y�����ؠ&�f���ri�%���U�L���m C�D��7�7��U�x����;,~��'��<��AH��/P���(i&����33x�>�瘮�ž�s-ω�ϻ��5�9���8����H�s�7���<�g��Æ�k���)݇�y�w�Я�O����-�K���v��Ko�o�䤒-�����x|S)'M�0�yHV��z�7jީ/����p���J9i�-px.��m��8���f-I���q�؞�mv�W	��X�L��g�J�yw\�	�ܙ<��&�[�3^o}[��T;xV�?'���4�[
�k�_a�w��E\kl�$ŇV�D>xџt���>��i:�7�ǌ{.��
O�U|t����vcx�&�e���>1R�T>q,�Q�ꇞ�?�p=�mŋht��f���A�{��oT|{����_�6��2v*�q�9�s�O�w�3�q��N2�l�I��3_�o�j�̞�ˊ�p��ʇ���������
�6Wb�|�a��>���϶�)��q��K���q�����3�q�v��X(�
�ӈB�M���a��X�Q���7���W�l�+}z��٩e�k�>7s�ϐ/����&�l	~��1>Ʀ��6��<��rI@��t���C�%���1�m`��n�����sH��^�_�o�k��:8N(�w5�K�MI]p��9��L7���f4��^C�3�ߔ�$P3�$�����2��_�Sz��݀ޖ����}	���T�YG� �]x}�{tRR�� �<ݶ�1�5�l��U�����B*3يρp�k=��zw��k&x6�>��I�G��U��۬\b}[��sxU�1��mru�d�z�
r��o��cY��3�����7
����XW���X�Ʒ��9���o��lb��<f�k=(}Jt����%,(��G�g�>�)��gr��\�>�����*W�|Wb8VN���<mp3���K�����L7�7鵭÷�cuU�˾]~	�-lB�rU��cb����j)+'W�Z �}�F�!WKm�������ַ���r��)؊��;��[�[����w�7��T�D'/��P�hا���*�4���F_������jX��Qѩ�zNw0��+%rK�rmN�N�yvL7�;ЛRzMMȳ���?=~�ѱY,��)�����%���e�=$kP��%���&=W˚׻���O���=���ٳg������V�|���ӿ�%y�      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      x��\Ys�Hr~��
�{J����^���8v��9��G8�$!�  �f;�ߝR$��fdG"�I����e!�Ql������M�!���2ō(��mӮ+_�Cc�O�f�]%�$A'	Ra���)�v��*�P��n��j@�ءj[��((�a��.	�N���ӜQ��	�I)���?��QZ/��7�
�[|K雨�ю�T*��k�m`q����ص��ֱ�����:����?�BY���I�a��D��`���f(wU����t�}�Â.��,�")F����`u.�@R�8J-��
�q^�D�b�'� !**\t��]�/�i0�d
�,��MX')���:<�N��ZWُB��ahר���k��ծ��(�+%t���ܯz/鶋��V5�aL�����u�>�NZ5���%x�J1[�e|�M�R�<o�'r<M�s�9u��|��mm��@��6���Ŧ췛����m�ͣz����!���n]�h� �ʳd�����T�7�ü�r#���N��C��,mh�������S��J]k��Z���×�_ZW�n�|�:�b]��
�+���.����TCNz�%��Ƃ�	W:J�y�Up��8���<��R21����o�B~e�&��Q���vA�4!�K^tI�X?UD�ѣ"�ܳOk�>6C}(�lٯ�-Df��u}W��!6 [�[���Pq'l�
}N�|�aA�1A�fI'��V���K|����3�#L�Nq1N%I��K#&mB��d���M�J����_��������>�l�c����J�О�{(~��j(�u�]�Kw�v��js�*��G=� Lv({�Sj���D}���b5	'�󴐨'B��i��si!J�m8�V�+Fj��DcN�qt{�뺎����Z�J��P_����_���3��)�]�/�P\�SŇl:2�.���P�2rk��rYj������&��p��į=���U��
PHm��\�)�b{��.:袃bb�4.��[Zpב/��t��֮�D���o!�)��%�pĶ��Q�1|<��Q�)����H�DtBB���a$���O8��L��	��(��*�ہ�A�����1#�ܦH?�lg3�u�m]V�MאRG؊�$E�=��{x��P|���e�5'�Zf��q��I}�����}�~ 4��Ǫ\g��r�_�s�1�M��%!�r�T$ܫ�`5ޫ`��J�#A�� 6�ܩ�P�c3i�R�c��5�aN��|u�sd�k����ʿvv������dQ�Gt�Aˣ�uв����Ň��6���h �B�w�&
�W�_U�`��9��lv��`N{@�[p��=@l�!~��8	.�[a���\p
C���FHP"0�,�YʞepE��j.<$�Y!9�N�.wY!T���K�:;�W@q����,G�rd��K/�P�~�Hl*�_�`����� {M���?m���c]���E\�_�����)j��e�s��J$�9	!���+�����*<6\�f|�}�P�$�^��+k�]�ʾ�U�|"�3�z���Y�:��\o`��Xέ^C�y�?�]�L���1W��f�";�E8)��Ш���ƥ-~���)��ZmJ��u�d�O@�Nl`ׂϲ���b������'�R�*�&�L����Gqb3}��pʮ�9��k�ʇ��;ZF.Tl5�Y=�@����#�Y�i�*B䕐������Fv���1�M��U�����ت�XB��֣K>��)�.܂â���քs�!D�?I�[@#˭��;���^LP����4ɠ��I)�1f#�C:g� ��s6�ľ����&���M��j�p��N�ǈ����ީu[��=�]ۮ˝��CHU�.����ɵha1���B4�c����Sp�V������m�@�8%$%mɍj�	 9�J���Xx�	��9�oo���4�Ύ�إA0vƱ���rt�ϻh�{�S-pylʀ���ł֡�N���61��d�႐iR��b����M�x)�F����lU�*A4R(�=9/�Sp�QuQBϔP��~�(mߖ�6҂�D�Wm�l�/��Vw凾�B+�b���3ٹ
,(�,�Y*ٛPd�ϣ蓔��L�B�� a���\���lo��Y]��s�W������=P�63�O��?�^?T�X���?Gh�� -l�Tf�z��SC���u����Ed�gR�0��I ��4X
�ka�@�v�y+ ]`ƣMb:'����	 e_�^�������7�{�U�M̏]��j��p���C?d��p3J��S�v���՟�������X�1 �P���f`�L.-�^�1�� %0g�y�ɧT�>`�zK�����"���rm�����%K5y��ϡ�Anwe߯7@7uc�:o�~n�j}_��AS.�d�
h����6�$�7R-�p�Ds�9�.����@����@���u��@����"@�>�.?���(�qh-39���q�/�u��ቮ�@�z��a�Ha �=�X a��\$*P�L�:����3���בQX�ӊL������S/tl������:�t�����#��U:�G�>[����?��ǋ�+�ǧ׌��W�G�I��v~�y�;�˟�:�E�B]�B��K׺��X�Ɲhe7نi��W yh�]]��o�n���VL�ʅdӠC����ŭd���h���@E�9�}���	Ƹ�gmXWͷ��)��:ni]�!	e�/� +e8$ϝ6�Dhh�Pf5�D�,zm�!:E�I^��P�'op����r��緲��X���IOf�>�,�t���m��z��{�U��J*{���MV��r��G�$3�q=�""l�z��IQǔ(�Y�5��4�.���T��5�㳠�T�_�P���i��ߖ����%6��
Y��Z#&�X�����9b��w0>b�Ѿ�;ۼ�G�����Zj�d�$h�,x��R�Hn艢J,��'D`:�A䧝�M褓A��'��b���U��+F|J�r�6|���� >�>�j�ꮪ���~��Ri)�{a
�A���u,�^鐸��Yc��2�ȕ�1g|`��g�Z�'�� k(3�9�:��DeX�(�,��w)���藣�IE0�\;H�y����ڵ���r����W�}"c1�&�R��m��!���/kרc�ӻW�]��v��L*Y����]$1s+�j��v��g�j�o�Vf�]su���[���	[�����������<�������q���22�>� \NQ��w�A�ѯ��3�#���V�LzU��8�0�$a�' Mzז0fh`&D�4�7�����b�Pn7��F�i0�.�������9:2}
L�nD�� N5��f� �o#�:����󤝎�>�W��j�v��"���(j���Ebp@�;(ѫ��$H��ᣫp��6����+�27izrٌ����\oJ3�4y���l��Gw��ڮn�R�I�7��R<`MI��*x1{�z��v޾c{�&l�������M ��Z��p	~��A1H�NYΜQ.�`b_�0�=�6�s+4'xP���W��vױU�}�|o��V.Ā��.|�� �����0)(�������A3"(KeI�`��Gbo����R���;�yn.F��È�[l���<\g!:
�F!:	�����s��5�3KV"��?{�^v�9r��=!�z��������`2J"���|<�����/�����4Q@���7l'��&u�P��T{�cUin,$Y/���d��߼`:�.h�e�]�}xx��rΐ�Փ��g�'�	4��<G3��x/�&2�����KX�x9�����ϊ/BX_)�Ӷ��j>rf������{�0�������ħI Aa.�܀M2%X�Vd��ɤ�1�fI`9��	�J�cd4�hF���L�`�˽�s���-�#�3̕�g}bȳ}��3�>5�پk�����E�˱d�TdrWz4�~��Ynl�f.�p'n^k �J��� �  n��RX�X�q�R����{�&X� ��c�Ia�9�K��o.�	g�)c��'BJ�aj�%,z;3o�c?��1��D@��1��G��1Tyb8o��p�����G5�=����n�㐑��dx�]��q�.����8I�G�}\܏�v��q,�\U�e7���އ�\�������+�����)'�s�J	h���L�'�;J�$<�(}>n��jfO,�B��~�̑���Q�O�H}�o�7��D��zT8����ˮ�h�GtJW[�P6�ve�C^U�q��σ��rm���M����;i�O>DjN�*��m�OFY���B� ��'\8=�U
A�a��Od&�({2~aޯ�C�*�9;x37�s��:�w����m����E[��}�=�I	�ϧ�p,(��Ǭ���A�l�q�q����CE����I(��|�r�vC�_Ŧ\�u�+��UWv��a�������:�S]u��\[X��!�E����X��� FBp�2�\R㣐�J�Lz���~�є6S�"�RN�5QA70c�K��'*�������)�˩�gG���y��@��e�ԏ��v�H��vU�����S�F����g�|v6b ����N��Ol]6js{��F�O�C�,Y��@���'�f*A�1aʻ��M��d�a.��0�I��M�
�8��%K~n�-U���\��zx��P��D�_��.ǃH�����/A痠�KP�m��/���g�b���<5>n��tNfb��b���a�xG���6Q�u�� ���ć�2BQ=��U�8�=+�'J�J	m��|�Ov����o��8��]���l�Y�z<�	n�����>O}vcRz/�\5	&����#�L�2�ݟ�n�s���?=�=j�݁t��#A�`?��v�j�)�mWM�w�&�MbRf��ݡ{F��H��M�yJ�b�N2��g�F-�D���Sl�l�_��u>?��y�wX�\��u�F�a	�2t�g��8�Ι'�'��31�mY���ےnz;t��젤_#��#��I=�pp�o��S��ڹ<��><ΰm�b�Ͽ�����פA����9
䀩�qrF{�)�3�ƹd����<E��	�?]���2\O� �R���������|8��M!������C���|:��+t�����?4yJ��	mS���=�Ħ���L���V��y@ntp%����#�����H�DQ�&� \�e�fT�x8e���LN��G���e�<��f�&���S�'���ڧ� J��#��RDW�謈v�/�����xn����2�V�+���_����t-X%�_*!�)�/��jE�	�mI9�N��P<�f��Ħ�uB8�L���ԄP��-e����K��MIٳV�b,H���k=��0�y��7��/p_�      �   �  xڭ�Ir9F��S���
	�Yz���Gh�U��M�8�eg�O� ��3���8&��q��e���i�L�@ ���W�?��D��9��C�c��~��P,���J�1���C��3�T:]��3pN!JK��c:��m�L}�8S�����L�b�i�M{��zk�plN��36���c�qA���j�}ic�.2�Ƭ��ZdYK��L�(��+B����'#Ѝ�Ys�&�ʐ�6Vdn�{{E���X���y:V�_?V�q�i{ɥ�[d� N�rD��.6�^���0�3�f��y>VYɛx���إ_��jtz���E���&��G��Z������y�e��@�]�e�#b�P<���\v� f��M����C��n��wr&��n#3������J� d��'�.��&A:!f�R\"O
��do����4��+��z�E^+1�910��mX��+!9
Lj.���ycjĈ�Лx/���.�٢ěxKm����� �q�^<,c��᜘�
7��6	�"W�Fo���nh^��_O}��f���G��(://2wL�#UL�.�"C�ޫx��A.�G&~�+~�[]޴�(N�$�Oʼ��NS[
3�)�zwѴH���{n,�^T�0$oo����肘�gX���a�Pn��T�SE���iBY���i�Xm�qk�}�c�ܙx�+zl!]#~���^��IÅ##�	q,.z~�
�"�a���wԱ�0Z8�@,@��i�����8x���^xE"��[�3��I�ͨpA��ٛx�1�ܣ\K��
<n�.�8z���wd��.R�Z������Qt�i��!�)�^�:ۅ[c�t ��;m��c����#�Mb��>��\x�Rśx/�����.go�͒g�>o�)�&���J����+vS#V.7~,�՛x�1���<k��#G�ثy��!@��7�)��V��.����U��<[M��{ɭ���{ k�əxSV��/�4��c:"N-���0Ƽ N�ϩ��Ӫ����o���k��䖄)zoI��̋�?S�M�S!��ryʖ�&6��u�� �<rE�9�s��� �1��q^j�K� � g��{��i���Ǐ��>V~��.^1\�<d
���{�7!�s��'ą�pi��T�76V"u&ޓ�֯��n&0ho�
!��.���7�V�Npq������}�W�l��t)W:�@(�s$���) �&�������4���I1~�����ivMh���5��ju&-�T����z��D���(�Y졁��G6F�~���P��XaѰo��%s$g�=?FT��A���a����rq����+6#�Lk�b�����[���I�ű�������t*B8�
�+ �(�$��Uτ)��5�P6F�炩#񞍋NLĉ������.���S:"��|\�����w"�F���a��L@���:�',~L�,w;����pJI��bO5i�.�����J�}h�9q&�Nm��R�`�\B�͹?��7�V��OcBVy�P�I<HV�c/�T��,*��x/W"���������	K��8tw��Ěx��:�#�J�d���\��P�V�n�{�F�7�����o��O���h-ȣ܈��Z_�D5�RR+�%/Q����K��X�S�#����K�řt"��ؙx����b�)����{ٍÐ��&��n�K���
%���
+zq�#��L�#����H.�y\��\a�X����*s�]�<�N��czwL݈���c� V|��l�x������=�O3貛�c$n�Y}B\�C�c��������[��?W-/�8[τ�N����2.r�D���k2y(��T�T�����*�6¤�FI!YX�x��=��$N��]��9+�q�p܀�X:~Jt)�qS�uf��ƽ���k�^�$�ޒ��k�q|e��0�K<�T܊xFJ��ƕJ�vN�	�����q��e��{�R��<'N�^��Y�+�5e�����p��4�QUu%�N+�.6�69'V�xD\("x�ؔR�繂b�^�����ԡ܇��[�}y�WG��+�ă�ŏͨ���ہ�8�r�Al.6f��pA�_q�	<�����+g
υX��'//��W�ﮉ���� #����	q�m���gm���ہ�*��f��P]�P��\�q��[��l����~���ȿ�;5+��y���ǽVL^���.ږR�++��D��7��9.q7Hq�����ͼ�j�l�Pr)�7^���+A����p1�H�a�rze�`)�o�H&�\���X҅OdU9#�}��ݰ����.���������aҘ]F3�<.��t�K�f�Ua��cR\�nFK��q��{��<B.}��^���I�V��7��ϯT|�5�;c��=�Ut
b�դ{������k�ҘV�b�^������yr|������v��j}�y���yA����w05�H�c�\����Xn{�J7��Y<�XcLZω��W|�ۀ�O	��F$���Ѿ[����ya~�3�\V��7m�j����>�C?[���ҨR�ŏ����ڣC����.�����=�Ϗd8�q��w�W;����jg�Wh)#kY�R�8'N�N���|V�w����5�c@KjqӴ���"r!�J^� �\q�1��۩����o�$f��Ĉ�s.�K�5�³�2[Z+��v��Y�V�]q��g5�.]g���x{ވ�����c�a]�����XZ��j����:�E�P�����]L<!:'��ėxƂK����^1�g�	����9�y�ŻG<�%��x�*Lj�39։Q��\�Ξ�?7/��w��&�)����繍21=N1s��[���=-�H� <"��s�]O��`�/�蠧��:U�^ц�K:�h�m\�wؽI�1�t\R�q�������u<�������d"d��QB��5�q�燥F,��������6��ׯ_��H��      �   �  x�͜�k7ǟ�K��F�Hz,J�K��2Ҍb;n�Ӧ��IRJ�f�@2~9��E��w��!�I�Hs�c���1
i�t̡f	�j���=�\���?�����@���/b�����y{s#�O{��ZN��nn�j���������}��W��x��S��3O�����߇x8�r��󹗼�n�Hϒ�(�厮/�~)
8,3�л��T��<�a�X%��]�a�J�ȳ
�R�w=$�Ƞ���Y��ӻKE��6v���b�&(��X]TN�ZE��\��kA%�.�c=l��y'�A��U�D��0Q��ݟ/	e�3}��:��P���E������u�H2Hq���� �xף��S%���YŶ^%���D<���$+�t���"���y��"^A%ɼǻF��H�]�VYTˢų�0Q �9��+i���]�WF����]�����v#�<�W6
I��w=���U�%{��B�������J�T��x��H�k�w����EϝDrk�燉"c���RBD�d��~e���=��L�J"K<�sE�4Ļ�(q{MRI�|���cg�J��k���J�ݹy�lc�<o/~���O��?�W�˻�fҗ�14�PSݭ+<�k����y�������Z�7�.������|�m�8���^���5o���������7o�
��&;#�@����5�	*	Bj��
��}�D�zl*I��̵��P�:X1�w7GR �J�%�gӵP�%y/��HЛJ2(z;lXS��b�R[�If���vE_�Ϗ�k�٠��-G����S���TI$�.�(&$�[�3
��&��燍���]���z�f�8�璱�b�0��s��4O8��>�m����>?8O��c�s|e��g��[�jf˝Jȟ�:�:h��Z��MT���s�l��-\�^���(d�����=6�-�)���H�,j�]�a��Y���j.*Z'fp���b���wW�rQ��'F�DWk�`0��(q�,Y���L�I�G��O ؝�X�S�;I*�G��;b�~$��Gl
䦒TJ�y#f�'�Fͻ�Ŗ�J�
�g���.��z�1��Z~#aF�:� �ף��A%�Uɳ&��/{_Qxv�-K��/\�(6'P��KL�u�>��������.e�5U��Z��o��.QI$T�z�(��?ලd��Y�
	����F�x-����m�$*z��6����W��$����g=LS���}�՛jY���-$a ��c?]���FR��P�P������?�cM�      �   )  x�͑QK�0���_��&i���	��胯s��rWd䦎!��mbS�wChsN�87��k��#�2{�:;���WՒ�~��׼�7��e�PRg��B�¢f�]oHr��ł�vM�a��7�h�S���������sB�$�4�����u�s{�j������K������Q��(CD�C� ����=�FmZ���X��W;@K���6��go(6S���ȁ�����ԣܛ�D�;c6�WqII��V�Xg�f'k�Di���Ԏ9�$g5˹7� t$�	�����o�y��I�      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   :  xڍ�[��� ��_�o�Ѫ
�d'��EE�KvrR@q���������s��nu�;�0&�׵j���:.�O���6�O;էV_�+p����Gvj2���8��8a��m��B49���K�>�'� ����� l���O�bG� �F9 %�H]����aٖ��<KbxV�'�[��ر��[��J?
�2'e�7��lA�'+�D��C��;=~�{�XF�G�LA��4�u����iվ\F�Ќ�4��l%Ց6����%ε�2��tp�����_�7���q���,���SAsx��$�Hǡq�x�oZ�Ǥ5

�ހ� ͿKhA��c2�#2� ��Ҿ���}++��o�k�R��u�4�iy�����Գޤ���Sz3��ea*�Jw�-:6�/-�?Zfi����EAE�/5��(�O5��A�`͘���� ;!h��g��^�z61娗�����p8��sO��<:��a��5��؀��0��Q3��+�h�6i�8�ax�=��	ڹ����ʙ��a`)�ƁU�V%���e7����4����9�����e�j"w��l�	/9�-~�NIZ�%v�o���e��˰�oΡ���y�N�bb�u-�=�H�+w ��dV��V��E��r޼�,�M}���w^Z��eAK���4)�4��假C���g���%:?�n3ܼZ�D�ui���Zs��U/:�bAĄ1�lX���;�t�Mӻ��_��ŏç��津�^S�����k�E8b�����S���`-�������3��
Kʎ�%��2V��\���]��O�{�������)�J��$	h��6� ytxx��ӄ#W����Ȕ��-O_xm��j$�7���(�:Wo�L��S��K�����{�V� �n>:z	n�1hu*��Qmx  ���]<UgktY�.Me3���9�>o��i���z<��(5�M��˝]I`�Ď��u�h�>@�-~���)�c�(p1�4��̪Im������q��>��4�hۊ?,�q0ղ��ҋ\�#;�k����{9h��74ܗ���B��K�@�r��r+蒦���9�G���u�=W�'�畫�<��e]cw d�V"^�fe����GG� S���_=J�8�4%��
_��/�M�yF���1�}��LقQ�"jW�i'ȶ�H�m�
t�ɴ���P�Ww~�k޲��&���;$���S;uj�;M��I^��(Al��i����VE��v�W�1�'Ǻ�cf#l�'o�I�ə��9�m���X=kś/���!��u�����V/"v���퀦y0OkV�~�ǑQ���c�x�e���3�����PmO)B�2<�Å���x>�"}y�� 2l3�����u�Q$%NNI�Yh^<(l3��,��]����\����:��=��.�.�L�±��4\�{J�D�9��2Ժ�cB���J$���k�x?M�����AN?��/Q\G� �N�͈�������a� c����t]M)��h�%�����@�n��g_6+vXr�t�w�e�ƿ����}�/����&�� <��$��j���Xݍ������`X�Z�zc63k���$ֽ-�"���T[�J�~�@ ��~�M>oҌ4��$m�~��(��7̨��$�^��d\��d�����ld�w�x��w�']0Uc�g;�Q^�LA4�h��@�y�|{hD˒M1���G�ڔ� !�!)���<�x�Ү�h1�����l��a��7�11���^��>�E�<Dk��X��aA.���Ww��^���n�}��g�$ MW�i�>�4��O==%��`?�e��%U��h�������DD���h+UK~�cϋ�yBI��"�P�nuﴄi>��N됤j
����4�f{�z�8���¯�����@	�ue.eE	g�������z7r�`��ep9���Q�;=[�E\�	9)�;��y1�e�Ƿ�0ך�;-���<�	�� N�R2��.�lJ8��Iۙkq!]eϑ�k�^�h��c�H⌸{�]���M�&�^��b�W���	$i<��a��� ��fH}o�u���_t�h      �   o  xڕ�1�d9D���B�C��k������UFů��L�8�
����kθ_���x����>~�����5?��! �o�|�H�U�樨;ZԐaZP��j,�U]N�*�	)�9'(w�)q+�I�|4��Yխԝ֢
���'vw�1Ȋ
�X;wC+�,ZQU͢C��5I�E��ԉ�o��9*�ڠ���ϴ�V ����^U9��cw���*o1D������|e<8n�[HTuCZTϽ����|С.�1wEM�Nf�g�-�[��&V�E,�ЁU]�(sc�nD��U�=;uUE��c5���5v���cg�w�P�J����S��e��2ag��͌T�j	�JB�.Ty���d������w�j̀SR�c�:����ª[wkH�[w=U�^	ou�x������n��%�+t��:*ǾS�o��Rk��i��G�d��C��hX�t�ֆIuZ�d�@#oly��VԸ�Hޡz�*�U�u����-f@�~��N��[��\1���\��"�M}�ܡ��'x	x��֘8oI=o�G�J��Ձ��P�vV3��X��-�S���.�ܹqJ������ՙ�<���=�v��V���id��A��������?�[��      �   �  xڥ���]��c�)�2���ĉ�N�d�p�5v�ooj;��@\�`�9�+L��a���k�~�v�mӓӷZ� ��Q����������e������_�E����E_�n�����߿�}�d�>%�������/���~��˿�����`����_~�n_��o��P�̫g��NR�:�d�m�l��mHeI�����U��U�N�m��Ƭ/nC*11�m�[VL$��jp�5v���� �f��A�&��wF9Ƹ�k4�ZFW�m�<L��mL�bʜ����"�>1�v�ڧ�n����mLE�h\$���,3q���W�G��Fg���5���T;v�m��j�Z�Z���ֻ�nC��~ZۘJ�\���:�,y�C�n|:;�&A��.l�OkS����g�!n��d�{C=5�T���� ��~�6��Ϧ�$�U���U�4�z�ﱳnc�[i=����:�6Ľ��e��ST|�RY�ra���6��5*�6�Mۜ}�?�Ӎ<^|�Yze#	Hnu=����
�[�w�y��MR�}�S��6D^������&��W��b���\���v{T�m����nc*9��eI��u�ʸ�1Yu�W:�nC��zY۠J�V9�!��H"fi�Ԫ�͒ y.{�I �$���~��SKa�K51�m�|��DP���"	�5��t7�F�z҈lM���쓠*�T8�nneP�vn����ڍ�n@�)��mL����)�1�i��?���I��u݋t������<�ېJ	�C�܆�w�I���� �w�8�� 1r^�$�R7)��xS�n�!ɫ�oR��J�)��*G�!�6KN����zCr��K�+@�\Sy���*cr'@�\e2��ξNp��T����+͗i��V_����#L���=��g8C���D{�$�Jߋt�T"I��˥���
$����T����An�eRnߊ1��3���W|�$�ʽ�pY���?b�����.��s�O�m�|���\TY1M�����v���G��Y�?�U���J{�I ��nv�qS��D��Rե���H�O~�c*9��E��42g��5��w�m}�nC����mP�:�~v�Z����k/	˥�$lM�W?��6�rb5�m�������6�l��z$׷=@PEK�zI��I���a��[��ƺ��u��H�خ\����r^LMb)��]j;��q�s��qEUN^\$��-���m�Ke�����G���mP�ع$�ճ�������n�[�%A�QOkS����1�i��f��u������F>��'�1���
��V��(�������R���Ja�&��T��J��eI��n'���g��N�nt��$ �7{9���ڇ� �9�@�$#�Y����K��Y_jP��ѩHr����m��S����j���r�܆���9�zo(�����FV� y�=�mTe�?�r���s��� 3�K���lJ���emc*MF�&e w������g�Y�Ar���mLeZ��6Ƶ��)�a��=�+�6Fn!�dIPez'4~r�Z�P�6�_˥�Ɲ�$ y��й�*g.Kb�6d0��\�i�����N�@rO�eR���JfI���w���KJ�.U��q$[y�'Uvʒ9��	�fy�������{����m�S|� A�:��`ܼ��έW�Z�6��Ar���mLe��U�w��1����rw�CN`���V%����nW
�n5f
|oha�K5�l���&-��$�J���I��J �I���ӲKͲ�S�(�Y�$�ʭ�)��?������VqK�      �   �  xڥX�r�8]�_�eR�p��ewլ{1�ـ (��C&Hk쯟KZ��D ��E�%�[�sp��J9�F���29g�c�=�L�T��{�
k:���hjӾ'ΗśoMV�p@s �@��̍݉Ŕ"��	�?���3MS��aC%�|祱Bdf��W*���eI]�MU5h2e�qλ���� �ۮ�����0t�n��	����C��C��&EL��
>��Vu�
L���қpHlY�c@�v�j�δ�GY@N�b�o1h�A��������&\E��&�l�,�k���f1h׵�E�4'_��������*:_���k�	C�a�Z(���c'#�S�uT� �ғk��I��6׊�n�LՓ����W�� �A$^�}�w<BVj�	P�'�\�,�kR�wbYJQ[_���'�?�>�v��@�����o�%�iRjN�
T�1��ئ�i�SͿ5�` �R���Mކ�(�@3�. �u��mL��j� �N����Xb�K޴U��CH�=��\kd@ф�
n�ë����]Cep�Ƥ 9W�6)>'�l���I�\�#5s����k)jN���� (����*��I�S�5[[V�C��e��QS��-���.]b�S瘽E�TH����ő��X��b��ms��0�ϯ$�
*ylN��!�2
PI&_H*�ZK�TX*�L;?��z�R\�y{����~���nb�m���|6߱�̅�:�Ka*'_���R��7�}����Zk��dZ�}�4#h߽���-%0�'�b��f8wk�0Msc��}�f��\���y���a���VEsH�<س��Kg�:'q���2P����׍;��0�16�>����S"]��$e�1���Oר�P3v���m\�0Ջ��Tޗw/���k���_'t<�����J��q/|�۔b��˦x/�����%,'#t�f��=<���\�T�q�S�֖�vEF�k{�L{L|���]+	�aZ�g�0��C�(KrY`�P�Q5"�V7��M��9[��֟���X��k����"vW��ts���!����L��m ���D����. �����\�ˮA�'���ѫ_��5}�c'Z���	S���O+�4�E�����W��J�M{P�~g�4�ڙfͣn̞����c�\1����0i�2�`L��a��2��?��F�����V¡8>lZ��R�q�#��������땦�vt����Gr0�ﶁ�H~�'"bN�ԁ���|��9ß�[�1a����e�05"���o������=G����0I��/�&,�E��1P���]U���8��{e�Ù�(�������~�rN��W�8��$������I�p�Ƴ�6�8"�BS����]��&^�yHz���� 
y��M�R��j�/d��*�tͤG�84��.�޳�����u���K1Z|Ŷ�0o�٦���?��$2"pt��)�W���k�p; �J&�
�L珜��̹��<��M�������O%�^�]v~���3���HO�D��! 5Vc�F���Z�Х#��VS��ٻo��4R�@�{r���%�B��'% ᥈���(bVD�;u��awB �s���e11�cF�jRx+����}��>�S|� >����N�4��K^�Y���/%�#$�|��HʦI�'Ӕ�p8|3�G_�;�F�SLNc��~�:��Zӵ��9x����T�z:��P����Uτ���P-���0������OOO��Z.D      �   �  xڭ�I��8�ו��}#�D�u������C�ћB�R{C��G�D��{s�/�C�{�*C�K K�,��" ��B���I�f�fPH�o���<"]\�xD�RS�ʟʹ���C�z6(M�>1��&6���
�P�"��>4���X�h�
�����I	hia��(��"�C,)c}���]��Y�����8�U���MG��"V�����r�ř�&6�Z^!�*���W9R
�t_�Uă*&[��u��=�6� �#u� �\�,��u���B7�(�,L�!X�V�>PV��8� ����&�)�R� v�T��S�����L�8�;�\�UV1��(����{�+b���QR~l��@}�8UJKb����@�`�:7�c�1]0�*�L�2XFޅ��ؑ�N ^�-]4F�Yw�o�"r��w�xy\矴"n
�-�p����H2�e���j����uEL�u?I�)�b��e�����.���"3�׊)m��|z����,uM���~�<��y�R`�����
��~l�8(��T!ll��-H<s��J�RId?�t���t�L���L��Y�϶���!�.o�q����)�q�+��31�gED�8q�	�j���()ц�C�#g�p�X�j:<tc�0q����OLL�?R���ڼ�|��m?�(32��+�6/2_����|&B�s}��[�'�F���A���2�&߰q(Iǈ�C� ���4�fX1GfX��聺���Ǟa�+����I�KY����ȋw:��,l�qE�8�n!�$�z����P�8y1�K�VLGθA*�cĊ��b#��Py$v:� 	|�8Tlƈ�"3[r�O�^��_3���P�K�8y!b�tx���ΥB,�D..��di���n��^^��q��`��S.6�AbZ��f
9�yH~l!�e�q�%�bwzF����?]�\u���O9�O�"��ǈ[9�1&�6�c�W)����l�8v�"�D���2Aβ��$HlFr@̜}��!=j'6V��ȋ�q�x$�۞V�F�A�:�Ǚ1ˎ�c�⊨�,@`����#�4�?�ݡ��Ez̏#�u�� �%$��<Ϝ��j3F̌x`��9N����zB�9Ɇ�cuE�X���Y
�8VW��?K7ğFoc!$��#!U�:� �ȼ����BHՑ���̦���p�'�lh��Ux�W
�q���g"�C�v��;��6,�qL*Bĥ"��(n�܄�C;7��	�i�ƶAB�����!�gs,�#��ЎP��'� A���nÏV<�C�QTĈ[J�F��ġ�$�JQ�a�8��bĝ��qʼ��b���r ��,5EV݂đU��n�͞U����+�|�ؤ����oM�;���s�y��ע��"2K�Mb�&�l��+�Ǌ��/���IZqI�Z���L|K�k��	��/��vE�i��r�G$N�ظA��VX.^����&&��cĝk�'V����� �Wlܦ\�x���}b�4�7�t@�Wl!�p%,��4�ƭ��;~<F�V^1���#/�����}�Yy�+a�$�W���	!�q�+"�>�e�������	��L�`u)�V�}�pD�M<;���q�O���N��9J�o���RV�9�������p�����ˠ��ĵ�	��s��q�W�]9���*�-��;2_)�q��z�������Ė�o���7��Vĳ�ߞVLb3��+^{o��Bܳ��+\�x��m���;6}tX���
z���K����d�K�o'����:!w�UF�7⮱d��	�	�ϗ�]Ly�8w��wD�t~��E�2(H��2�r��^��Q��K�y� $\h�<	�V���jN��)�}Y:��ؠ�As����?߿~��/��      �     xڭ�Kn+7E��^T��"9��� A�'ǒmI������n*� d7@����K��l�G�E?"��(Eӣ�3(�ڛ���x8.׳\_�;�~���8��_���ߗW���2�S��(����i����:P�<� 59�
3Ɉ UʺK�G>�|������>ߺ
�?��jUL��2�b��2��Fhcqn(h�
E'<"0dc�d��_�>��#�AX1O��x�-�NC#��,S	��='���	���6�����K͈UAS�Sep�n��a(�h�ܜ�oe�� ��xb)�؃Р��g�*�"AO5B����G��Ԍ��z�Y�!�bJ�z�����r����b�:��L-M� ���|NyD�F �%������	,Y�MF�w����FlF���hx�ֲ�&�c���"nniҮ�V�I��7῎Oϗ.�ך��
"C���� �k��'��F%!��
��7�Rc1�i[�~����܇���
BYRse ��&�ȬF�y�`j4R�B:� (,j����W���f�:�:֘�F��{<
C�QF��~��j�%l�Ij�r��Q��v[� '��؅p������@f�#�&eiɈzx=rХ�P.S	�Rlp�R�p�8$Ђa�?^N��t!�Ne-DBCf��{�oF$Hj��.)��6�!]?>��xY0��H��=�f��ٻ�&��a����{���U�20�a�dX��}���3wJ1adD���֯O��d�2(��S�aDQ��75�&pK����-#<��u�L�k�-m�Ì� �6^�_��ᨭ��A��/癃|m��>-E�#�(2"0�e���G<�,}��FCY#���D��%�"C����1&�L%��c�F��7"�9�8���۵o�>�\H�)������\2��{=s��
H�e�P�ӈ��a��-�=�.b��/�*%�Zex�]�_�ߛ��"�aj������@�I87�JBX��m�����^�]�D�k ������_Q��N     