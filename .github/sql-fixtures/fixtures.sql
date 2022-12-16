PGDMP  	        (    
            z            taiga #   14.5 (Ubuntu 14.5-0ubuntu0.22.04.1) #   14.5 (Ubuntu 14.5-0ubuntu0.22.04.1) �   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    1783935    taiga    DATABASE     Z   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.UTF-8';
    DROP DATABASE taiga;
                taiga    false                        3079    1784052    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            �           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            �           1247    1784404    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            �           1247    1784395    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            8           1255    1784465 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
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
       public          taiga    false            O           1255    1784482 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
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
       public          taiga    false            <           1255    1784466 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
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
       public          taiga    false            �            1259    1784420    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
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
       public         heap    taiga    false    1012    1012            E           1255    1784467 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
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
       public          taiga    false    245            N           1255    1784481 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
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
       public          taiga    false    1012            M           1255    1784480 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
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
       public          taiga    false    1012            F           1255    1784468 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
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
       public          taiga    false    1012            H           1255    1784470    procrastinate_notify_queue()    FUNCTION     
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
       public          taiga    false            G           1255    1784469 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
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
       public          taiga    false            K           1255    1784473 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            I           1255    1784471 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            J           1255    1784472 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
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
       public          taiga    false            L           1255    1784474 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
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
       public          taiga    false            �           3602    1784059    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
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
       public          taiga    false    2    2    2    2            �            1259    1784013 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    1784012    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    221            �            1259    1784021    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    1784020    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    223            �            1259    1784007    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    1784006    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    219            �            1259    1783986    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
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
       public         heap    taiga    false            �            1259    1783985    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    217            �            1259    1783978    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    1783977    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    215            �            1259    1783937    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    1783936    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    211            �            1259    1784233    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    1784061    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    1784060    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    225            �            1259    1784067    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    1784066     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    227            �            1259    1784091 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    1784090 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    229            �            1259    1784447    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    1015            �            1259    1784446    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    249            �           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    248            �            1259    1784419    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    245            �           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    244            �            1259    1784432    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    1784431 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    247            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    246            �            1259    1784484 3   project_references_239ed30285c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed30285c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed30285c911eda2acd3f54b4882f7;
       public          taiga    false            �            1259    1784485 3   project_references_239ed30c85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed30c85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed30c85c911eda2acd3f54b4882f7;
       public          taiga    false            �            1259    1784486 3   project_references_239ed31e85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed31e85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed31e85c911eda2acd3f54b4882f7;
       public          taiga    false            �            1259    1784487 3   project_references_239ed32885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed32885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed32885c911eda2acd3f54b4882f7;
       public          taiga    false            �            1259    1784488 3   project_references_239ed33385c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed33385c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed33385c911eda2acd3f54b4882f7;
       public          taiga    false            �            1259    1784489 3   project_references_239ed34385c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed34385c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed34385c911eda2acd3f54b4882f7;
       public          taiga    false                        1259    1784490 3   project_references_239ed35085c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed35085c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed35085c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784491 3   project_references_239ed35f85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed35f85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed35f85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784492 3   project_references_239ed36885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed36885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed36885c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784493 3   project_references_239ed37a85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed37a85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed37a85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784494 3   project_references_239ed38885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed38885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed38885c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784495 3   project_references_239ed39a85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed39a85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed39a85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784496 3   project_references_239ed3a585c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3a585c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3a585c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784497 3   project_references_239ed3b585c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3b585c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3b585c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784498 3   project_references_239ed3c085c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3c085c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3c085c911eda2acd3f54b4882f7;
       public          taiga    false            	           1259    1784499 3   project_references_239ed3cd85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3cd85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3cd85c911eda2acd3f54b4882f7;
       public          taiga    false            
           1259    1784500 3   project_references_239ed3df85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3df85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3df85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784501 3   project_references_239ed3ea85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3ea85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3ea85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784502 3   project_references_239ed3f385c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed3f385c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed3f385c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784503 3   project_references_239ed40485c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_239ed40485c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_239ed40485c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784504 3   project_references_25f7f62d85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f62d85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f62d85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784505 3   project_references_25f7f63685c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f63685c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f63685c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784506 3   project_references_25f7f63f85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f63f85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f63f85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784507 3   project_references_25f7f65a85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f65a85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f65a85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784508 3   project_references_25f7f66485c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f66485c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f66485c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784509 3   project_references_25f7f66e85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f66e85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f66e85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784510 3   project_references_25f7f67785c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_25f7f67785c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_25f7f67785c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784511 3   project_references_2725838e85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725838e85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725838e85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784512 3   project_references_2725839785c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725839785c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725839785c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784513 3   project_references_272583a185c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583a185c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583a185c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784514 3   project_references_272583ab85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583ab85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583ab85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784515 3   project_references_272583b585c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583b585c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583b585c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784516 3   project_references_272583bf85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583bf85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583bf85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784517 3   project_references_272583ce85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583ce85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583ce85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784518 3   project_references_272583d785c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583d785c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583d785c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784519 3   project_references_272583ea85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583ea85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583ea85c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784520 3   project_references_272583f485c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583f485c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583f485c911eda2acd3f54b4882f7;
       public          taiga    false                       1259    1784521 3   project_references_272583fe85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272583fe85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272583fe85c911eda2acd3f54b4882f7;
       public          taiga    false                        1259    1784522 3   project_references_2725840785c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725840785c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725840785c911eda2acd3f54b4882f7;
       public          taiga    false            !           1259    1784523 3   project_references_2725841585c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725841585c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725841585c911eda2acd3f54b4882f7;
       public          taiga    false            "           1259    1784524 3   project_references_2725841f85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725841f85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725841f85c911eda2acd3f54b4882f7;
       public          taiga    false            #           1259    1784525 3   project_references_2725842985c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725842985c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725842985c911eda2acd3f54b4882f7;
       public          taiga    false            $           1259    1784526 3   project_references_2725843885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725843885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725843885c911eda2acd3f54b4882f7;
       public          taiga    false            %           1259    1784527 3   project_references_2725844885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725844885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725844885c911eda2acd3f54b4882f7;
       public          taiga    false            &           1259    1784528 3   project_references_2725846885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725846885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725846885c911eda2acd3f54b4882f7;
       public          taiga    false            '           1259    1784529 3   project_references_2725847185c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725847185c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725847185c911eda2acd3f54b4882f7;
       public          taiga    false            (           1259    1784530 3   project_references_2725847a85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725847a85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725847a85c911eda2acd3f54b4882f7;
       public          taiga    false            )           1259    1784531 3   project_references_2725848385c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725848385c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725848385c911eda2acd3f54b4882f7;
       public          taiga    false            *           1259    1784532 3   project_references_2725848d85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725848d85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725848d85c911eda2acd3f54b4882f7;
       public          taiga    false            +           1259    1784533 3   project_references_2725849785c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2725849785c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2725849785c911eda2acd3f54b4882f7;
       public          taiga    false            ,           1259    1784534 3   project_references_272584a185c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_272584a185c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_272584a185c911eda2acd3f54b4882f7;
       public          taiga    false            -           1259    1784535 3   project_references_285809b185c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_285809b185c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_285809b185c911eda2acd3f54b4882f7;
       public          taiga    false            .           1259    1784536 3   project_references_285809bb85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_285809bb85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_285809bb85c911eda2acd3f54b4882f7;
       public          taiga    false            /           1259    1784537 3   project_references_285809c585c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_285809c585c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_285809c585c911eda2acd3f54b4882f7;
       public          taiga    false            0           1259    1784538 3   project_references_285809da85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_285809da85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_285809da85c911eda2acd3f54b4882f7;
       public          taiga    false            1           1259    1784539 3   project_references_29953dee85c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_29953dee85c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_29953dee85c911eda2acd3f54b4882f7;
       public          taiga    false            2           1259    1784540 3   project_references_29953df885c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_29953df885c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_29953df885c911eda2acd3f54b4882f7;
       public          taiga    false            3           1259    1784541 3   project_references_2e4e7c3285c911eda2acd3f54b4882f7    SEQUENCE     �   CREATE SEQUENCE public.project_references_2e4e7c3285c911eda2acd3f54b4882f7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_2e4e7c3285c911eda2acd3f54b4882f7;
       public          taiga    false            �            1259    1784187 &   projects_invitations_projectinvitation    TABLE     �  CREATE TABLE public.projects_invitations_projectinvitation (
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
 :   DROP TABLE public.projects_invitations_projectinvitation;
       public         heap    taiga    false            �            1259    1784148 &   projects_memberships_projectmembership    TABLE     �   CREATE TABLE public.projects_memberships_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 :   DROP TABLE public.projects_memberships_projectmembership;
       public         heap    taiga    false            �            1259    1784110    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    public_permissions text[],
    workspace_member_permissions text[],
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    1784117    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
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
       public         heap    taiga    false            �            1259    1784128    projects_roles_projectrole    TABLE       CREATE TABLE public.projects_roles_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 .   DROP TABLE public.projects_roles_projectrole;
       public         heap    taiga    false            �            1259    1784274    stories_story    TABLE     �  CREATE TABLE public.stories_story (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    version bigint NOT NULL,
    ref bigint NOT NULL,
    title character varying(500) NOT NULL,
    "order" numeric(16,10) NOT NULL,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL,
    CONSTRAINT stories_story_version_check CHECK ((version >= 0))
);
 !   DROP TABLE public.stories_story;
       public         heap    taiga    false            �            1259    1784319    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    1784310    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
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
       public         heap    taiga    false            �            1259    1783955    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    1783944 
   users_user    TABLE       CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    color integer NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    lang character varying(20) NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    1784242    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    1784249    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    1784362 *   workspaces_memberships_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 >   DROP TABLE public.workspaces_memberships_workspacemembership;
       public         heap    taiga    false            �            1259    1784342    workspaces_roles_workspacerole    TABLE       CREATE TABLE public.workspaces_roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_roles_workspacerole;
       public         heap    taiga    false            �            1259    1784105    workspaces_workspace    TABLE     *  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false            �           2604    1784450    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    248    249    249            �           2604    1784423    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    244    245    245            �           2604    1784435     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    247    246    247            7          0    1784013 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    221   �k      9          0    1784021    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    223   �k      5          0    1784007    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    219   �k      3          0    1783986    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    217   �o      1          0    1783978    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    215   �o      -          0    1783937    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    211   �p      F          0    1784233    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    236   ]s      ;          0    1784061    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    225   zs      =          0    1784067    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    227   �s      ?          0    1784091 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    229   �s      S          0    1784447    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    249   �s      O          0    1784420    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    245   �s      Q          0    1784432    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    247   t      E          0    1784187 &   projects_invitations_projectinvitation 
   TABLE DATA           �   COPY public.projects_invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    235   (t      D          0    1784148 &   projects_memberships_projectmembership 
   TABLE DATA           n   COPY public.projects_memberships_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    234   �z      A          0    1784110    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    231   ��      B          0    1784117    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    232   ��      C          0    1784128    projects_roles_projectrole 
   TABLE DATA           p   COPY public.projects_roles_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    233   ˘      I          0    1784274    stories_story 
   TABLE DATA           �   COPY public.stories_story (id, created_at, version, ref, title, "order", created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    239   ��      K          0    1784319    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    241   ��      J          0    1784310    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    240   ��      /          0    1783955    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    213   ��      .          0    1783944 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, color, is_active, is_superuser, full_name, accepted_terms, lang, date_joined, date_verification) FROM stdin;
    public          taiga    false    212   ��      G          0    1784242    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    237   D�      H          0    1784249    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    238   ��      M          0    1784362 *   workspaces_memberships_workspacemembership 
   TABLE DATA           t   COPY public.workspaces_memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    243   i      L          0    1784342    workspaces_roles_workspacerole 
   TABLE DATA           v   COPY public.workspaces_roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    242         @          0    1784105    workspaces_workspace 
   TABLE DATA           n   COPY public.workspaces_workspace (id, name, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    230   |      �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    220            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    222            �           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 92, true);
          public          taiga    false    218            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    216            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 23, true);
          public          taiga    false    214            �           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 35, true);
          public          taiga    false    210            �           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    224            �           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    226            �           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    228            �           0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    248            �           0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    244            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    246            �           0    0 3   project_references_239ed30285c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed30285c911eda2acd3f54b4882f7', 20, true);
          public          taiga    false    250            �           0    0 3   project_references_239ed30c85c911eda2acd3f54b4882f7    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_239ed30c85c911eda2acd3f54b4882f7', 6, true);
          public          taiga    false    251            �           0    0 3   project_references_239ed31e85c911eda2acd3f54b4882f7    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_239ed31e85c911eda2acd3f54b4882f7', 6, true);
          public          taiga    false    252            �           0    0 3   project_references_239ed32885c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed32885c911eda2acd3f54b4882f7', 20, true);
          public          taiga    false    253            �           0    0 3   project_references_239ed33385c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed33385c911eda2acd3f54b4882f7', 17, true);
          public          taiga    false    254            �           0    0 3   project_references_239ed34385c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed34385c911eda2acd3f54b4882f7', 20, true);
          public          taiga    false    255            �           0    0 3   project_references_239ed35085c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed35085c911eda2acd3f54b4882f7', 23, true);
          public          taiga    false    256            �           0    0 3   project_references_239ed35f85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed35f85c911eda2acd3f54b4882f7', 10, true);
          public          taiga    false    257            �           0    0 3   project_references_239ed36885c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed36885c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    258            �           0    0 3   project_references_239ed37a85c911eda2acd3f54b4882f7    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_239ed37a85c911eda2acd3f54b4882f7', 1, true);
          public          taiga    false    259            �           0    0 3   project_references_239ed38885c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed38885c911eda2acd3f54b4882f7', 24, true);
          public          taiga    false    260            �           0    0 3   project_references_239ed39a85c911eda2acd3f54b4882f7    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_239ed39a85c911eda2acd3f54b4882f7', 7, true);
          public          taiga    false    261            �           0    0 3   project_references_239ed3a585c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed3a585c911eda2acd3f54b4882f7', 14, true);
          public          taiga    false    262            �           0    0 3   project_references_239ed3b585c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed3b585c911eda2acd3f54b4882f7', 12, true);
          public          taiga    false    263            �           0    0 3   project_references_239ed3c085c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed3c085c911eda2acd3f54b4882f7', 16, true);
          public          taiga    false    264            �           0    0 3   project_references_239ed3cd85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed3cd85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    265            �           0    0 3   project_references_239ed3df85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed3df85c911eda2acd3f54b4882f7', 22, true);
          public          taiga    false    266            �           0    0 3   project_references_239ed3ea85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed3ea85c911eda2acd3f54b4882f7', 30, true);
          public          taiga    false    267            �           0    0 3   project_references_239ed3f385c911eda2acd3f54b4882f7    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_239ed3f385c911eda2acd3f54b4882f7', 2, true);
          public          taiga    false    268            �           0    0 3   project_references_239ed40485c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_239ed40485c911eda2acd3f54b4882f7', 18, true);
          public          taiga    false    269            �           0    0 3   project_references_25f7f62d85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f62d85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    270            �           0    0 3   project_references_25f7f63685c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f63685c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    271            �           0    0 3   project_references_25f7f63f85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f63f85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    272            �           0    0 3   project_references_25f7f65a85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f65a85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    273            �           0    0 3   project_references_25f7f66485c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f66485c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    274            �           0    0 3   project_references_25f7f66e85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f66e85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    275            �           0    0 3   project_references_25f7f67785c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_25f7f67785c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    276            �           0    0 3   project_references_2725838e85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725838e85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    277            �           0    0 3   project_references_2725839785c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725839785c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    278            �           0    0 3   project_references_272583a185c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583a185c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    279            �           0    0 3   project_references_272583ab85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583ab85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    280            �           0    0 3   project_references_272583b585c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583b585c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    281            �           0    0 3   project_references_272583bf85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583bf85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    282            �           0    0 3   project_references_272583ce85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583ce85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    283            �           0    0 3   project_references_272583d785c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583d785c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    284            �           0    0 3   project_references_272583ea85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583ea85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    285            �           0    0 3   project_references_272583f485c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583f485c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    286            �           0    0 3   project_references_272583fe85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272583fe85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    287            �           0    0 3   project_references_2725840785c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725840785c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    288            �           0    0 3   project_references_2725841585c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725841585c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    289            �           0    0 3   project_references_2725841f85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725841f85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    290            �           0    0 3   project_references_2725842985c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725842985c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    291            �           0    0 3   project_references_2725843885c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725843885c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    292            �           0    0 3   project_references_2725844885c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725844885c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    293            �           0    0 3   project_references_2725846885c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725846885c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    294            �           0    0 3   project_references_2725847185c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725847185c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    295            �           0    0 3   project_references_2725847a85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725847a85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    296            �           0    0 3   project_references_2725848385c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725848385c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    297            �           0    0 3   project_references_2725848d85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725848d85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    298            �           0    0 3   project_references_2725849785c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_2725849785c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    299            �           0    0 3   project_references_272584a185c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_272584a185c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    300            �           0    0 3   project_references_285809b185c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_285809b185c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    301            �           0    0 3   project_references_285809bb85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_285809bb85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    302            �           0    0 3   project_references_285809c585c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_285809c585c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    303            �           0    0 3   project_references_285809da85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_285809da85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    304            �           0    0 3   project_references_29953dee85c911eda2acd3f54b4882f7    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_29953dee85c911eda2acd3f54b4882f7', 1, false);
          public          taiga    false    305            �           0    0 3   project_references_29953df885c911eda2acd3f54b4882f7    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_29953df885c911eda2acd3f54b4882f7', 1000, true);
          public          taiga    false    306            �           0    0 3   project_references_2e4e7c3285c911eda2acd3f54b4882f7    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_2e4e7c3285c911eda2acd3f54b4882f7', 2000, true);
          public          taiga    false    307            �           2606    1784050    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    221            �           2606    1784036 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    223    223            �           2606    1784025 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    223            �           2606    1784017    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    221            �           2606    1784027 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    219    219            �           2606    1784011 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    219            �           2606    1783993 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    217            �           2606    1783984 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    215    215            �           2606    1783982 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    215            �           2606    1783943 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    211            3           2606    1784239 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    236            �           2606    1784065 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    225            �           2606    1784075 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    225    225            �           2606    1784073 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    227    227    227            �           2606    1784071 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    227                       2606    1784097 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    229                       2606    1784099 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    229            x           2606    1784453 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    249            n           2606    1784430 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    245            s           2606    1784438 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    247            u           2606    1784440 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    247    247    247            )           2606    1784191 R   projects_invitations_projectinvitation projects_invitations_projectinvitation_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_pkey;
       public            taiga    false    235            /           2606    1784196 b   projects_invitations_projectinvitation projects_invitations_projectinvitation_unique_project_email 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_unique_project_email UNIQUE (project_id, email);
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_unique_project_email;
       public            taiga    false    235    235                       2606    1784152 R   projects_memberships_projectmembership projects_memberships_projectmembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_pkey;
       public            taiga    false    234            "           2606    1784155 a   projects_memberships_projectmembership projects_memberships_projectmembership_unique_project_user 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_unique_project_user UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_unique_project_user;
       public            taiga    false    234    234            
           2606    1784116 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    231                       2606    1784123 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    232                       2606    1784125 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    232                       2606    1784134 :   projects_roles_projectrole projects_roles_projectrole_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_pkey;
       public            taiga    false    233                       2606    1784139 I   projects_roles_projectrole projects_roles_projectrole_unique_project_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_unique_project_name UNIQUE (project_id, name);
 s   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_unique_project_name;
       public            taiga    false    233    233                       2606    1784137 I   projects_roles_projectrole projects_roles_projectrole_unique_project_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_unique_project_slug UNIQUE (project_id, slug);
 s   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_unique_project_slug;
       public            taiga    false    233    233            B           2606    1784284 "   stories_story projects_unique_refs 
   CONSTRAINT     h   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT projects_unique_refs UNIQUE (project_id, ref);
 L   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT projects_unique_refs;
       public            taiga    false    239    239            F           2606    1784281     stories_story stories_story_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_pkey;
       public            taiga    false    239            V           2606    1784323 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    241            X           2606    1784325 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    241            Q           2606    1784318 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    240            S           2606    1784316 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    240            �           2606    1783961 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    213            �           2606    1783966 -   users_authdata users_authdata_unique_user_key 
   CONSTRAINT     p   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_unique_user_key UNIQUE (user_id, key);
 W   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_unique_user_key;
       public            taiga    false    213    213            �           2606    1783954    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    212            �           2606    1783950    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    212            �           2606    1783952 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    212            7           2606    1784248 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    237            :           2606    1784261 9   workflows_workflow workflows_workflow_unique_project_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_unique_project_name UNIQUE (project_id, name);
 c   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_unique_project_name;
       public            taiga    false    237    237            <           2606    1784259 9   workflows_workflow workflows_workflow_unique_project_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_unique_project_slug UNIQUE (project_id, slug);
 c   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_unique_project_slug;
       public            taiga    false    237    237            ?           2606    1784255 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    238            f           2606    1784366 Z   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_pkey;
       public            taiga    false    243            i           2606    1784369 j   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_unique_workspace_use 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_unique_workspace_use UNIQUE (workspace_id, user_id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_unique_workspace_use;
       public            taiga    false    243    243            [           2606    1784348 B   workspaces_roles_workspacerole workspaces_roles_workspacerole_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_pkey;
       public            taiga    false    242            _           2606    1784353 S   workspaces_roles_workspacerole workspaces_roles_workspacerole_unique_workspace_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_unique_workspace_name UNIQUE (workspace_id, name);
 }   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_unique_workspace_name;
       public            taiga    false    242    242            a           2606    1784351 S   workspaces_roles_workspacerole workspaces_roles_workspacerole_unique_workspace_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_unique_workspace_slug UNIQUE (workspace_id, slug);
 }   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_unique_workspace_slug;
       public            taiga    false    242    242                       2606    1784109 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    230            �           1259    1784051    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    221            �           1259    1784047 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    223            �           1259    1784048 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    223            �           1259    1784033 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    219            �           1259    1784004 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    217            �           1259    1784005 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    217            1           1259    1784241 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    236            4           1259    1784240 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    236            �           1259    1784078 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    225            �           1259    1784079 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    225            �           1259    1784076 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    225            �           1259    1784077 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    225            �           1259    1784087 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    227            �           1259    1784088 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    227            �           1259    1784089 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    227            �           1259    1784085 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    227            �           1259    1784086 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    227            v           1259    1784463     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    249            k           1259    1784462    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    245    1012    245    245            l           1259    1784460    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    245    1012    245            o           1259    1784461 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    245            p           1259    1784459 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    1012    245    245            q           1259    1784464 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    247            $           1259    1784192    projects_in_email_07fdb9_idx    INDEX     p   CREATE INDEX projects_in_email_07fdb9_idx ON public.projects_invitations_projectinvitation USING btree (email);
 0   DROP INDEX public.projects_in_email_07fdb9_idx;
       public            taiga    false    235            %           1259    1784194    projects_in_project_ac92b3_idx    INDEX     �   CREATE INDEX projects_in_project_ac92b3_idx ON public.projects_invitations_projectinvitation USING btree (project_id, user_id);
 2   DROP INDEX public.projects_in_project_ac92b3_idx;
       public            taiga    false    235    235            &           1259    1784193    projects_in_project_d7d2d6_idx    INDEX     ~   CREATE INDEX projects_in_project_d7d2d6_idx ON public.projects_invitations_projectinvitation USING btree (project_id, email);
 2   DROP INDEX public.projects_in_project_d7d2d6_idx;
       public            taiga    false    235    235            '           1259    1784227 =   projects_invitations_projectinvitation_invited_by_id_e41218dc    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_invited_by_id_e41218dc ON public.projects_invitations_projectinvitation USING btree (invited_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_invited_by_id_e41218dc;
       public            taiga    false    235            *           1259    1784228 :   projects_invitations_projectinvitation_project_id_8a729cae    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_project_id_8a729cae ON public.projects_invitations_projectinvitation USING btree (project_id);
 N   DROP INDEX public.projects_invitations_projectinvitation_project_id_8a729cae;
       public            taiga    false    235            +           1259    1784229 <   projects_invitations_projectinvitation_resent_by_id_68c580e8    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_resent_by_id_68c580e8 ON public.projects_invitations_projectinvitation USING btree (resent_by_id);
 P   DROP INDEX public.projects_invitations_projectinvitation_resent_by_id_68c580e8;
       public            taiga    false    235            ,           1259    1784230 =   projects_invitations_projectinvitation_revoked_by_id_8a8e629a    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_revoked_by_id_8a8e629a ON public.projects_invitations_projectinvitation USING btree (revoked_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_revoked_by_id_8a8e629a;
       public            taiga    false    235            -           1259    1784231 7   projects_invitations_projectinvitation_role_id_bb735b0e    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_role_id_bb735b0e ON public.projects_invitations_projectinvitation USING btree (role_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_role_id_bb735b0e;
       public            taiga    false    235            0           1259    1784232 7   projects_invitations_projectinvitation_user_id_995e9b1c    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_user_id_995e9b1c ON public.projects_invitations_projectinvitation USING btree (user_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_user_id_995e9b1c;
       public            taiga    false    235                       1259    1784153    projects_me_project_3bd46e_idx    INDEX     �   CREATE INDEX projects_me_project_3bd46e_idx ON public.projects_memberships_projectmembership USING btree (project_id, user_id);
 2   DROP INDEX public.projects_me_project_3bd46e_idx;
       public            taiga    false    234    234                       1259    1784171 :   projects_memberships_projectmembership_project_id_7592284f    INDEX     �   CREATE INDEX projects_memberships_projectmembership_project_id_7592284f ON public.projects_memberships_projectmembership USING btree (project_id);
 N   DROP INDEX public.projects_memberships_projectmembership_project_id_7592284f;
       public            taiga    false    234                        1259    1784172 7   projects_memberships_projectmembership_role_id_43773f6c    INDEX     �   CREATE INDEX projects_memberships_projectmembership_role_id_43773f6c ON public.projects_memberships_projectmembership USING btree (role_id);
 K   DROP INDEX public.projects_memberships_projectmembership_role_id_43773f6c;
       public            taiga    false    234            #           1259    1784173 7   projects_memberships_projectmembership_user_id_8a613b51    INDEX     �   CREATE INDEX projects_memberships_projectmembership_user_id_8a613b51 ON public.projects_memberships_projectmembership USING btree (user_id);
 K   DROP INDEX public.projects_memberships_projectmembership_user_id_8a613b51;
       public            taiga    false    234                       1259    1784126    projects_pr_slug_28d8d6_idx    INDEX     `   CREATE INDEX projects_pr_slug_28d8d6_idx ON public.projects_projecttemplate USING btree (slug);
 /   DROP INDEX public.projects_pr_slug_28d8d6_idx;
       public            taiga    false    232                       1259    1784185    projects_pr_workspa_2e7a5b_idx    INDEX     g   CREATE INDEX projects_pr_workspa_2e7a5b_idx ON public.projects_project USING btree (workspace_id, id);
 2   DROP INDEX public.projects_pr_workspa_2e7a5b_idx;
       public            taiga    false    231    231                       1259    1784179 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    231                       1259    1784186 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    231                       1259    1784127 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    232                       1259    1784135    projects_ro_project_63cac9_idx    INDEX     q   CREATE INDEX projects_ro_project_63cac9_idx ON public.projects_roles_projectrole USING btree (project_id, slug);
 2   DROP INDEX public.projects_ro_project_63cac9_idx;
       public            taiga    false    233    233                       1259    1784147 .   projects_roles_projectrole_project_id_4efc0342    INDEX     {   CREATE INDEX projects_roles_projectrole_project_id_4efc0342 ON public.projects_roles_projectrole USING btree (project_id);
 B   DROP INDEX public.projects_roles_projectrole_project_id_4efc0342;
       public            taiga    false    233                       1259    1784145 (   projects_roles_projectrole_slug_9eb663ce    INDEX     o   CREATE INDEX projects_roles_projectrole_slug_9eb663ce ON public.projects_roles_projectrole USING btree (slug);
 <   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce;
       public            taiga    false    233                       1259    1784146 -   projects_roles_projectrole_slug_9eb663ce_like    INDEX     �   CREATE INDEX projects_roles_projectrole_slug_9eb663ce_like ON public.projects_roles_projectrole USING btree (slug varchar_pattern_ops);
 A   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce_like;
       public            taiga    false    233            C           1259    1784282    stories_sto_project_840ba5_idx    INDEX     c   CREATE INDEX stories_sto_project_840ba5_idx ON public.stories_story USING btree (project_id, ref);
 2   DROP INDEX public.stories_sto_project_840ba5_idx;
       public            taiga    false    239    239            D           1259    1784306 $   stories_story_created_by_id_052bf6c8    INDEX     g   CREATE INDEX stories_story_created_by_id_052bf6c8 ON public.stories_story USING btree (created_by_id);
 8   DROP INDEX public.stories_story_created_by_id_052bf6c8;
       public            taiga    false    239            G           1259    1784307 !   stories_story_project_id_c78d9ba8    INDEX     a   CREATE INDEX stories_story_project_id_c78d9ba8 ON public.stories_story USING btree (project_id);
 5   DROP INDEX public.stories_story_project_id_c78d9ba8;
       public            taiga    false    239            H           1259    1784305    stories_story_ref_07544f5a    INDEX     S   CREATE INDEX stories_story_ref_07544f5a ON public.stories_story USING btree (ref);
 .   DROP INDEX public.stories_story_ref_07544f5a;
       public            taiga    false    239            I           1259    1784308     stories_story_status_id_15c8b6c9    INDEX     _   CREATE INDEX stories_story_status_id_15c8b6c9 ON public.stories_story USING btree (status_id);
 4   DROP INDEX public.stories_story_status_id_15c8b6c9;
       public            taiga    false    239            J           1259    1784309 "   stories_story_workflow_id_448ab642    INDEX     c   CREATE INDEX stories_story_workflow_id_448ab642 ON public.stories_story USING btree (workflow_id);
 6   DROP INDEX public.stories_story_workflow_id_448ab642;
       public            taiga    false    239            T           1259    1784329    tokens_deny_token_i_25cc28_idx    INDEX     e   CREATE INDEX tokens_deny_token_i_25cc28_idx ON public.tokens_denylistedtoken USING btree (token_id);
 2   DROP INDEX public.tokens_deny_token_i_25cc28_idx;
       public            taiga    false    241            K           1259    1784326    tokens_outs_content_1b2775_idx    INDEX     �   CREATE INDEX tokens_outs_content_1b2775_idx ON public.tokens_outstandingtoken USING btree (content_type_id, object_id, token_type);
 2   DROP INDEX public.tokens_outs_content_1b2775_idx;
       public            taiga    false    240    240    240            L           1259    1784328    tokens_outs_expires_ce645d_idx    INDEX     h   CREATE INDEX tokens_outs_expires_ce645d_idx ON public.tokens_outstandingtoken USING btree (expires_at);
 2   DROP INDEX public.tokens_outs_expires_ce645d_idx;
       public            taiga    false    240            M           1259    1784327    tokens_outs_jti_766f39_idx    INDEX     ]   CREATE INDEX tokens_outs_jti_766f39_idx ON public.tokens_outstandingtoken USING btree (jti);
 .   DROP INDEX public.tokens_outs_jti_766f39_idx;
       public            taiga    false    240            N           1259    1784336 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    240            O           1259    1784335 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    240            �           1259    1783964    users_authd_user_id_d24d4c_idx    INDEX     a   CREATE INDEX users_authd_user_id_d24d4c_idx ON public.users_authdata USING btree (user_id, key);
 2   DROP INDEX public.users_authd_user_id_d24d4c_idx;
       public            taiga    false    213    213            �           1259    1783974    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    213            �           1259    1783975     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    213            �           1259    1783976    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    213            �           1259    1783968    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    212            �           1259    1783963    users_user_email_6f2530_idx    INDEX     S   CREATE INDEX users_user_email_6f2530_idx ON public.users_user USING btree (email);
 /   DROP INDEX public.users_user_email_6f2530_idx;
       public            taiga    false    212            �           1259    1783962    users_user_usernam_65d164_idx    INDEX     X   CREATE INDEX users_user_usernam_65d164_idx ON public.users_user USING btree (username);
 1   DROP INDEX public.users_user_usernam_65d164_idx;
       public            taiga    false    212            �           1259    1783967 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    212            5           1259    1784257    workflows_w_project_5a96f0_idx    INDEX     i   CREATE INDEX workflows_w_project_5a96f0_idx ON public.workflows_workflow USING btree (project_id, slug);
 2   DROP INDEX public.workflows_w_project_5a96f0_idx;
       public            taiga    false    237    237            =           1259    1784256    workflows_w_workflo_b8ac5c_idx    INDEX     p   CREATE INDEX workflows_w_workflo_b8ac5c_idx ON public.workflows_workflowstatus USING btree (workflow_id, slug);
 2   DROP INDEX public.workflows_w_workflo_b8ac5c_idx;
       public            taiga    false    238    238            8           1259    1784267 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    237            @           1259    1784273 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    238            Y           1259    1784349    workspaces__workspa_2769b6_idx    INDEX     w   CREATE INDEX workspaces__workspa_2769b6_idx ON public.workspaces_roles_workspacerole USING btree (workspace_id, slug);
 2   DROP INDEX public.workspaces__workspa_2769b6_idx;
       public            taiga    false    242    242            c           1259    1784367    workspaces__workspa_e36c45_idx    INDEX     �   CREATE INDEX workspaces__workspa_e36c45_idx ON public.workspaces_memberships_workspacemembership USING btree (workspace_id, user_id);
 2   DROP INDEX public.workspaces__workspa_e36c45_idx;
       public            taiga    false    243    243            d           1259    1784387 0   workspaces_memberships_wor_workspace_id_fd6f07d4    INDEX     �   CREATE INDEX workspaces_memberships_wor_workspace_id_fd6f07d4 ON public.workspaces_memberships_workspacemembership USING btree (workspace_id);
 D   DROP INDEX public.workspaces_memberships_wor_workspace_id_fd6f07d4;
       public            taiga    false    243            g           1259    1784385 ;   workspaces_memberships_workspacemembership_role_id_4ea4e76e    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_role_id_4ea4e76e ON public.workspaces_memberships_workspacemembership USING btree (role_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_role_id_4ea4e76e;
       public            taiga    false    243            j           1259    1784386 ;   workspaces_memberships_workspacemembership_user_id_89b29e02    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_user_id_89b29e02 ON public.workspaces_memberships_workspacemembership USING btree (user_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_user_id_89b29e02;
       public            taiga    false    243            \           1259    1784359 ,   workspaces_roles_workspacerole_slug_6d21c03e    INDEX     w   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e ON public.workspaces_roles_workspacerole USING btree (slug);
 @   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e;
       public            taiga    false    242            ]           1259    1784360 1   workspaces_roles_workspacerole_slug_6d21c03e_like    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e_like ON public.workspaces_roles_workspacerole USING btree (slug varchar_pattern_ops);
 E   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e_like;
       public            taiga    false    242            b           1259    1784361 4   workspaces_roles_workspacerole_workspace_id_1aebcc14    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_workspace_id_1aebcc14 ON public.workspaces_roles_workspacerole USING btree (workspace_id);
 H   DROP INDEX public.workspaces_roles_workspacerole_workspace_id_1aebcc14;
       public            taiga    false    242                       1259    1784393 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    230            �           2620    1784475 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    245    1012    328    245            �           2620    1784479 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    245    332            �           2620    1784478 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    1012    331    245    245    245            �           2620    1784477 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    329    245    245    1012            �           2620    1784476 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    330    245    245            ~           2606    1784042 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    223    219    4067            }           2606    1784037 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    221    223    4072            |           2606    1784028 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    4058    219    215            z           2606    1783994 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    215    4058    217            {           2606    1783999 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    4042    217    212                       2606    1784080 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    225    227    4082            �           2606    1784100 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    4092    227    229            �           2606    1784454 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    245    249    4206            �           2606    1784441 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    4206    245    247            �           2606    1784197 _   projects_invitations_projectinvitation projects_invitations_invited_by_id_e41218dc_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use;
       public          taiga    false    4042    235    212            �           2606    1784202 \   projects_invitations_projectinvitation projects_invitations_project_id_8a729cae_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_;
       public          taiga    false    4106    235    231            �           2606    1784207 ^   projects_invitations_projectinvitation projects_invitations_resent_by_id_68c580e8_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use;
       public          taiga    false    4042    235    212            �           2606    1784212 _   projects_invitations_projectinvitation projects_invitations_revoked_by_id_8a8e629a_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use;
       public          taiga    false    4042    235    212            �           2606    1784217 Y   projects_invitations_projectinvitation projects_invitations_role_id_bb735b0e_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_;
       public          taiga    false    233    4116    235            �           2606    1784222 Y   projects_invitations_projectinvitation projects_invitations_user_id_995e9b1c_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use;
       public          taiga    false    235    212    4042            �           2606    1784156 \   projects_memberships_projectmembership projects_memberships_project_id_7592284f_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_;
       public          taiga    false    234    4106    231            �           2606    1784161 Y   projects_memberships_projectmembership projects_memberships_role_id_43773f6c_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_;
       public          taiga    false    234    4116    233            �           2606    1784166 Y   projects_memberships_projectmembership projects_memberships_user_id_8a613b51_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use;
       public          taiga    false    234    4042    212            �           2606    1784174 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    231    4042    212            �           2606    1784180 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    231    4102    230            �           2606    1784140 P   projects_roles_projectrole projects_roles_proje_project_id_4efc0342_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_;
       public          taiga    false    231    4106    233            �           2606    1784285 C   stories_story stories_story_created_by_id_052bf6c8_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id;
       public          taiga    false    212    4042    239            �           2606    1784290 F   stories_story stories_story_project_id_c78d9ba8_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id;
       public          taiga    false    239    231    4106            �           2606    1784295 M   stories_story stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id;
       public          taiga    false    238    239    4159            �           2606    1784300 I   stories_story stories_story_workflow_id_448ab642_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id;
       public          taiga    false    4151    239    237            �           2606    1784337 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    240    241    4179            �           2606    1784330 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    215    240    4058            y           2606    1783969 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    213    212    4042            �           2606    1784262 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    4106    231    237            �           2606    1784268 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    238    237    4151            �           2606    1784370 ]   workspaces_memberships_workspacemembership workspaces_membershi_role_id_4ea4e76e_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace;
       public          taiga    false    4187    242    243            �           2606    1784375 ]   workspaces_memberships_workspacemembership workspaces_membershi_user_id_89b29e02_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use;
       public          taiga    false    243    4042    212            �           2606    1784380 b   workspaces_memberships_workspacemembership workspaces_membershi_workspace_id_fd6f07d4_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace;
       public          taiga    false    243    230    4102            �           2606    1784354 V   workspaces_roles_workspacerole workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace;
       public          taiga    false    230    242    4102            �           2606    1784388 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    4042    212    230            7      xڋ���� � �      9      xڋ���� � �      5   �  x�m��r�0E��W��.5�u~#U)<(c���]���Ԣ�%�8���Q��0�8�e�f���~�ľ����x}曉Y����᣹��~���?'���C���i�Ǵm�2�|qA6T�� Kؖ�2L	ۡ(#�&����.��(���Y����E�:�hT	�����ip_n���[�E�,�kw)UEE(2H�ԇ���d�Z�sjH���f�߰vnp%UGՐ��b`0}A)��҉��赙U4N��Qj���]� {� ��n�_�o��7�؊�eߋq��h��q}\J��&Vhc�( ��i�;k��-_^v��<N�ˇ�E��ɺ[�%{�s1�&�L�P&M�Q��\�4�4���>m֌��]9\���L�%96]�Krd�2)W+���}-�����6{q}�Y��c t ,�AƂ7�DF:W©ԲX���*�z,�Jgu�D��Ce����>Te
����L��y��u{��Bi�oɪɷ��}@�o����rmy�w�a�����\�P��KY���@��|�9pd�	������Ua��y��/XQ��,�*��R��uƛy6I��0�&��{Y�V�\�@�6>�的 o��%mpj�a��O��d{Ԫ��xC6:ׂ'y.s�x����*mǣ�#�IS:M-mJF�irMy�7��6ה�yS�Ҧ<J��`������K����k�^�.`dS�w�@��˓�oY�;�)O��]�����	�3I�*�*�J2�q��9o��C�IK��"��.�'��g���-��@�����L��vLG?�ΰ�}��my��ٮ�y��d�F� �M��
Pd��2@�����m�����=dǆ���EX6K�9�a�S$\�Z��0���M��-�_��Q:nA��}����t�d�}I��O)�05��      3      xڋ���� � �      1     x�uQ�n� |f?�
8�T���6�إ����FJ��3�2,�����DC�X ��Գ��3�&xhf�K!G82���̆��H��ɇ+�3˨N+\�b�$I�2
O]�!����nb�*J��$�f��+�'Fٖ��+����ձ.j���Q��&V��ް�·n	W ��Ƒv�J*�O��ܾ����]5�ǐ�iL�S�/��θ�u���ˆn���̖2�80��L	7�δ��N}v/�-Bȩ�S�7e� ��Ee\���q�� ��݆      -   �  xڕ��n� �?���������Y&!�Є�6�m���8u�թ=Ɋd9�ǽ� �л�J)���mM�"> >���ˏz���Na�d��ڔΝ�"T |2b�o�
$ce-~����1��&�&�8c��=����W�2���}�5ϵ=��)�}ng�ŵ�bd�O��{5�f�bZ۸e���.n(��?��Qa�(��jV��ur�t.6���&�Mc�L��c��"JH�KzF�jL�q���*E
���@g�Ō?��ХeG5��� 0#�-��}��sgC�� 9Qp��<�?���@ʤ�h���`3C]*y��?�b_��b�4����NR4r�7|�U�ެ��Y.ljN�$�ɢm(%a�Q���^P��n���� ] 3t�"g���7��� U��x�ճ�[���LhrxZ�IZ"�eq����l�ih�ڜ��c�z��EKj��|��{&d�����������m)��]3	Ɇ�r��E�+��(���PoY�@V�*n\�o���6 �)-'��P6~-�ge5u�>���2���.��Z�o_|���d��_�Ӥw�<��4ͻ��t�����t\:�	H���e0���PQ!I��R������M���A
]�2�o��Q��'�_B)��>�v��GH^C      F      xڋ���� � �      ;      xڋ���� � �      =      xڋ���� � �      ?      xڋ���� � �      S      xڋ���� � �      O      xڋ���� � �      Q      xڋ���� � �      E   �  x����n7е��jp������`�$����J��u�q�E��d���H���R��K�)�HY�ˢ���u�f5!�������>�X>Z.�|����T��(�I	�^�zQ�7)>h���K�:�O�����Q�/Z�p�?Q:�����E�~��K�������=���w�R�~Q�+o��'ܟ���?��������,D�q��񽜅� �e�o���P��W�����!�6���O�ҿ��4�>T��.���0� ���G�VMï����!����@������e�����^��
���5���W�{�����~��
#e����_~@����_y� ~������ʗ��/����K�������:��W���?�p��O_۟8ǜU}�Q���贆uڲf�艳j��Y�ЬqX��	f�#�Z�Ĳ��r<T����ú��֬W���JL��#�JL�Y����)uV21�4���6�B�Q�po]3��XZ��H��Q�I�P�Y��w~��VO_$q2j'�����@.�X�:ߟ���m��Q��ƻ�}�;����`U�pQ�X;­ �
g�lo�L�>���0���_~��"xhz
?!�J��xhz
?�U�f�+�#�)���%m��z�w�"|ul��]-\lmN�W_a���=�M��}�EԨ�%����U����jx���f�޸��-m�ʏz�Շ~GL=]��#�g��Y��v���1�t���������,x(�,����F�2�J���a�·����þ7B�{�_`�_i�'�~�{� ~�u�B���/���u�J���w��ʟ��u~p���P�K�X�5����J�R��ȗԱ���n���#]?1g�~�<��~��~����:��cg���Y?1g���,?��s�o|��,|��'���N�* ��t�<�9�I�a���p���҇�>�����SVj��q����̛h�26�9���_\H��j����[�"j�JK5��j7���W��2}�%ƙ� ����ű2}�}���7�{V�˒�6����H�-�m��6�)|$�eM;�����3����lhu�i~��gK�t?�I�P�ˎui�wJ������|�g����,��|93����{+ߊ�WO�<���:x��>���c��ֳ��VN����Je7�9��>��D۠�e��^\�/�&E��8�4��J`�%m�)Ĳ���}�SV*k�c��gY|d��^Qo���$kU�"��=�5��=�g�"�9��~��g�_i|������O��|1Į��a��G�~�Ħ��Z�Y�H�/��������G�0�'f���v>�yJ na6�Ӽ��f�����:�2�B������)}
}�Q��8�����%�r�֤ p�Te������o���u8Qް��dw���9z(�T��|����8���z�����Ψ��]����(+��U�(����F�'�,[��|R��W�G�TK�k�(����(��Y��,���z�*��#O�[3�<�g���a�g��'�r��G�x�>��1�v������[#q����e�S��([f�7J�;�}#�7�v	��̶��V��~b�����|K������j�,��}�}�n-��G��keƞƿ���~ �h!�}��e�+̾���O�G���/x<����V�Y����5q��9�����vy~~�a�      D   �	  xڵ�K��8 �u�)f?ȀďH�Yf����0�rT��I�N�xI�$%�@;v,˗�f_�������ɴ�*����
_ ���'��į�M��]�_p_��� ��A ֢�4���Jk\܊�M�q��X�u��#޳b\9.�"0\��� ����G,bT����L��#�1��)��#�q�#v���t�ZO��@:�B
SćG���Mo�> F�9bs�!���^�����p��&�1q�)bO>�_I��:�`Y1�: f!�"��yb�"Q�պa<�Y��#���m@l�����`<K�X�1�y|�	@��=��b-8�i�h �"v-Ah K+S�k�G�XL����T<�gc�&���SZ6�x6V4�ץ�bϚ���X	���R�1 f-祊s@��2`���q|�B����u)��k֬��n�*���r/�fSĞ>���Ef�"�d7��VKiSĮ;o ۵��)bO����XpN�=+�߭0��]�ƧC�JVv�x{lR;q�[��_����(*^�f���c�Jܦ�=�Bp@|��2E���B�V�g�]�&���ΙǞ�B��fXd��SAd ��6E���%��W)�t�<v����$��=5O!.&�~K�X֬��7Ц3Į�4 n�6�cO�S����5*޲�<mb��SĞNHe@,J<E�yV��
�?���䦖�Y���������`��5��}r��J���qe�)bOr31N{����qm�[[�'vi�1c�l&���Л�MX��]$�W����cO#���1 ]���y���Y5o��c�z�bW�[���
1�M����[���
b�	-�/-�J/GX���d�(v�y�X�����%�����պ��g�u@�j�)bOYa@l�����X����5���cO�ҀX��N{j���(��5���i�x��VZmQ�d��u �>�%�=�x���D�Z�o�G�[���[�?&6%�"���m��}[�%�=w޶�"�<ȶ���l�س]�Ƿ+J���#N{k�oW0���|�wAvkퟘ&�=�b��c�����D����m@�ܟk�����2 ��:%ƞ�m��c�k�?���4B�6 n�8E�i��x{̭���O{��~�Q�$7�*�V˷���9�v�4q<7�~!�v����
���8��?�M��o����#�����Z���s�����wƳ�PE�"v��ss��$�=��y��?����w��*��@���<�2 nEm�����ؤ��q<KC$�!��c*8 ��/�c�q<k��D���T�^�O�
, 3ľy|�y�x���XKxR���?�2 n��щbW���t�W~�6b3c|z�0 F��53ūG����SĞt\��|�S���r6������į+�CB�	!��G���cs�Q��ܫ��z��R'>b*i�5.�*�3�O]�}�m@���`L@�Y7^���V?�|@l	�����'��+�b)�YQz�_W��Rˤy�8��b��ݤx�d�=h�򤊆�V���o�A�Ǔ�a�Ϟ�}	r`��xW��[V����*���9<�3!�����WyG�k+�^Q�i�8���[,V>k���~��=�L����+�����}	q�--�K����9 ��/k!�b�T���Ղ@����g�" ƬG�^�k���5o��oY!���}�I�ԨxOq<��R7)��kރZZ���ZըX�b�I\�(܋O�����?��3�oq�׬��"M���G�y������"M׺�s������iE��i�Vy*QqZ����ĭ^����Ɋ{К�3^�\���oq�\K��H?A�q�x@���J����KSkݬ8=��<���䦿? |_��(�d��𓼷�^K���R��,V�
ȟUGD5m�x�&T4*v5n�C�q{���4��.� �o#��m�*5��kV��?���*�}��G��	��%+��Rx��ָO>�����/q����Pb��S|VT|�-*^�b���B'&���b���v���X�1�¿?����#n���U���{��A�*ı�FO_K��5��DK��x��4�_w�u{�����{�����`X�i�\7^��Ro�J�KO�}�AGV���l��k���L���U'���y B�Y!^����rTlY!?��W)�]�=�?h����Z,���7�^�$��1!ķx ��S?�K<��Ay1^�b�V ��xð�V���ݘ�#޲b�Q\|-�>�# ��b����o�o--�ǀXT�`�
�m5�u-I��xO�߃<3g;=b����PT�y=���*��m��U��*�u��a^݃N�� �X�b��?����#n��#�N�%�R;��%��>�C%��,�*�?���}�����i�u@,\�W�x��\^ L���A�y�����!�$      A      x��\ے�F�}���+�u��M��c�^���l�D]�P� զ7���Hu��	�ꉍ�Z�����r�*��)r��F;�4Źc.�#�Rxa�z�u���[׿�Xy��u�W�M����Ž�i�]�go��jr����i]m�����}ݧŌ�vm�.�~�r��S�u�II-)W4e�m�4
˭g4���	"2�4�(���1)C��殙1�؜�9�%_r��5a���rQ����c�qJ�U�Y���t�M_�#���'}���]pk�ש
 q�վ^ݔqQu}�R_�6��j��m_o婢�>UuN��oMs_����k�:���������e���BS�����t4�*~��Rط#��v�����}�j�*��.x�k�����[�؈�VX�FU�����)��	��� ���n]���c�]�lR[���[�H�z���}���wn���,i}���]񮋊i��uH)�D���9���mj���X��~_\a�[��j(�mh���P5�*�]u_#���4�|�AP�S����ݧj�< �@�v-nWa�\%�ur1��f���z�"|� n
\a\�:\߻���3��γ�pk}�=���]	p��(�t�Fq��ڵ�n�^/�_:�z��}�K-���t;D���ޖ ��\(�V��k,�b&F�2�+6
���O,O L�	n����uۻg��㦂QU��m1�U�����HJ訶E��m�m��m�������7k����id��l�U������NH$d�*�=��Yzۯ3�9ҳ]ꥦ̓�d҉�|��d�}�H�1�L,3*	��:(��wD���O��"��Q��lf�j��z(�;�D}����p1�k����iS��]�M'7D�Ň���� O/ŒN�,yE��$Hb�
.'ƃd<,4	�F����bǡ�BS3�!eT��.L��M�N_w�oۻ�̷i_8�H���/�k�G��$%u�E"�w�HdQB`	#����k�T�T5׭�m|ﶡ�^��.�@��v�#�/���Ag���;p���]IextHFO�G�ji���l'�Q�t����<!��")AcT��"�&��WK�1f>@���15�R��8S;������ 0�����]�����\� ��5�3���m�����$9Յ&��RAu�R��z�d�8�iBԇ;ϳV�i!	s
�r'����E���#��_D�qX�D��Z�V}�b�N^/�6Y�~*3���r�Yݵ0��[p�:�m��"�~���Ç:�i�����)�Na�^ވ�sxT��?�W�_�T���	p`��o���A�#��5�:��'�όɗ"��,��]V�<�U�<�*�pYG6i�](hA����k
�G(�5k��&+��J�XNFIǭ�s)9�H��4����uj����v@ϻp_	��/�ۭ �����т��j�@�
�݂�?4m\TA誇�.��,�o�f���N�->��K*�R�L2P�������%�%�JD@�i,�DÝ�Ԑq��M�c�2��)�Na�����`�i�Ŧ�]⦉i=�.&W����'��S��`��K������i���]#�$���~̷*T�M{��֍�=�;U"p� �RA��F.-��s�R���m�[5�epf��T��C)����\�⸄G�X�B%�9��S�(������48F������2%,2>X�AIM�x&(R�|�d
�S�m��_�^7�ֺ���}L󦭑
҅���]1�����UŇGIq&��RI?Me;A��o���,��MH���W�ib�]�������U1��8�}p��?���`C\۬)��&��G��|BB���$�`)Hf�����W��*	t4�B�"��t
�8� b������B&��&ԯ6��@�`E}�q�}���j?� ����ȆBYu��v`��[wZ��re��Ny���݆��\-�fJ��ZH��@>	4O��&�Ί]��nv��:Y���n�[\5@(�R��"3"���LG��.,�	�G����{��MP��Yk(iP�b���M�uP���Z��y	qyݯ�.B�
�ApXTo��C7D�f�j��iSr�@�6b�q��ޝ$()� M��<-��?��jބf���v�B�M}:] ���p�?�,���|v�8=:�>=9�,�^gm������ߛu�fm��.����(bݶo�?���j�q�%JX���������){�e�39]��u�������p���tV6S)
�j�n��޾�N�h���=��qC%I�"�_J"���*;.� #�N�d�LL%�T�y�6;gA#�$ @R�<�H�w�Z�	xI9/%n�Ŧ��կ������	s�6�P� ��d@�U�g����Ii����Dr
ğ{�H�:d2���9�9I�xE�M�U�M���;���[���g�L�tKk��D�g�n�p����,��e�#+���:�Z�@��gW�̌�����WS�`�O���r��Z\&�.'�=�t<%�ϊ�fҀ\�D@>!�mε=��0#�dΎ��	Uɉ��(����G+`I1d��F�KɄ���IE"��M9�YS���-��T���>���5mʱ��*���i��m�{4���7h�yP���K��DB�e�'h��5L��S���H������Q� ��U�p��ѩ�鉸]t:���qLK�m_QK?UK3QKuF���/�)UJj�@ݎ*�e�b�	��Iֈ$�b�&Bp��[�J�q� ���p��+{���h��2"����^�$-#�{�I&�m�r�+��!8*X�D��Xa�R��qc���`T���"ly"l�|4G� -�]S�M�PDc��`JN �,M�A��1�e��1\��s��q�P=3=���׃-�̇�~z���`�`����Q-+�p90}tE�v�
4�`C�1�9M)ZEiŢfKA�F{�ڏ�����e�ɮ؟��ٖ���$R�1$���	�5�t�bS+�'��@"�?�\�S���Ri�F��x�
��Fs$�W*�i�H������A��'�PR �7KF�܄F���6 h�8�jL�"��!쳩w3ڈ�-�>x�Q��5e��IO��� 7c��96��B��4tC5�_���svB:��o���x̌����(�݂���.�O����	���Q��e!���>)PJ���o��N�=-�O����g;��(v7P����)�(�@��"���@Q��X��d���>�oN�9�y���H�n����e0ق�����[����@ռD����kQ�guRE�^۬�Р�NZ����/����4\���	�")C��c�225 )��O���I�Z'��s�ĳ�R�ky�,Pϵ�1��&��2���0bm8Ժ�9���B��e���u�3�NL���?	6a�nt���C�7��={���T��t`?�����Uwmif�ܦ�O-.�Vǵc�鳣��N!�B�	*_�y�γ.]�҄P:.�S��4��hJ��{����޻�>-���,<�.�Lg.e,�	>S"˞����s)�#��Z�<	T+����%Sf�v�	�]�A����r5���)�^���Q����g͢M9d>��ξj�m�Urݡtk��#�r�>�\V1��C��`n�f�U�)�/:�Շ#���|!԰�'�4eK�֜�H�Rs, �E�i�>,� Aj��K�b0d|���yCGm�H�m�~�n��g��4� Zf_�ڜ�&�}i���m���*���D��񥢣�2H%�4�����(��};��mn�д��Pu{P���žM�Ѷ�?T.��G�;5���|������Ƕ���ÀUj��g�SP�.�nB꺼/��e|�+��c@������Q-e ���4�t*Y|�b�&�,�\�<n��AI����W\�G8������.��OOR߻��L�A�	��caE@�ٖ��gS���Qv�|Є��g�7t0:����2��L@���=㙌�;��-̋�aX��N�?3�7�s�Q����|6u{�.��C��� �  �҆Y�~3��<�m�aU��� Q�q�G#���AZd*�E2*GdH\��de��h�$��^T����#��'����#�+��:���w�xU�x���w�u����~v�!s���ݪޕ6�R�oK�9�@a���<�G<�q�A�`>k�m��(և��hҦ �1"}J�9��0igK� �
:��Q*_K#������phK�?�-�v�yn�r�Ӫ�@n��w+��~�BjorF�mj��g�pr��"U&I����a7"��9k�HG��7��v&�}�V�����j��r�� 'O�6�ٛǖ�5�m�m�\�C�K��2=�F�ݺP�B���Oh.������ҧv�f�û�ے���RcB��}i�^���(j���*��A�'�f� b���`��e�PJ�T:_�G��5�B9;�;
{�U�nR��f�.���vHT��/�<���R2U�����mӦ0Ӈ�Zlb��~]��}i��9T���,_����E�%�)6֜q������ݘ8j|�`�ZT-i�/��[��]��	�����w��BY*oP��.�cU([Tߗʐs�](ݻUՕ>�RS^l_�J��#��y�Ӡl�~"rR�L@$_/��}�S��s���:
���8��[.OY%$�9;�����W��L ���G�T����}7�/;��/�?r�g�~I��}��� ��U:T�k��_�]I �      B   6  x�Ց_K�0ş�O��*m���	��胯s�ksW�d䦎"������ڞӜ��4W��cZ��	�;��q|�i�'i�6˲"Mݾq����K�V��X�ĸ`�]o��6��Դu�c8��p4��ܷ�r�fM��9���HhE��ş�����l��Kr������Z���\�Y���Y����H^N /� ��5��?�BMػ�-�<_6?@C���>��g�����ɂm	�~s��aP��ҍ��+c1�WޅI���é/�������B�PIh{�&�l�{�0�I��6Hn/nd��mE�!aU      C   �  x���MO�0�s�Y�f���I���'�&!�/�������M���ӊC�� r~��Ǣ�
%+�ZoRh�,��]LmV��^{�U�|ȋ��t=��\5�y��y7-?.nV˫��������gi�X��a��˼e��X�i}��l7��z����������������_�l���.�d�Gz��S�.�8o.�?OA�5� af�1!�#"��<GY e'�sĄ�<��#�H�#$T�<G��!�j�5�d�I����#�Z��cE��9GH�^�X�
��u$t=y�."�D�#$����#g�g��0��ǀ���y<B�h�s�Q:�!aϞc)�s�����1!OW����3���9"��>�����<�	��ՂTs��^���}��"�ȕy�ja�sԻ�l�(-o�{���j;�:gdDIZ��B��sTQ�#r|�i��Z�Q-ػ�"JI<D0����������}{;m����>�F��uR)m�0��@������̗7e�䗭�V=�����A�C��'�qV�/��I����y�g�S�[#e8�oz�떉�2_� �5�9Z���گ�k��wc�NL��stQ��	]g����q@H��BO�c@���s���#�1JD��sĄ�=�Qf�!�`�#�&��cE��9GH�^�&�����*&d�W3R��p�t
� �e"����F��8GL�~{���[��&$�=i�%�t
&��oZD�.3�:�ލQ�c׵�ӡPS��Cw��e�
5�y�*�(�[t(Ԕf�P)ߤC��,{�ZH�K
H����h'%�Pس�eb�zM��W���	{�QV�!�J�����+Q0!�J�����+Q�
��"��9� HI���Ğc�(3s��0Y��A��8GH�{�sD��8�}��ʅ���(�����=@�s�QF��	�..)��*�$��D���d2��[�      I      x�Խ�r�X�%z���?�
��;���i�ʟ�.GG�$A%�`�h��O���t�G@�t�����ʶ,%�ޙ�r�Z~��Ћ��F��o�W������o�`��0M�E��������O\o���
���"���x��]�=�m�/�E�^Ww��u�/����Z���z*�y^?޸�h
7��n]�󶬶ܹͪM1�?���	_f�o�M5/�ۮ�MS����ƽ/��~6+�ƥ�\͎�|9-�e{t�jO���H޺ӂ�`����}W.E]l[�vC��,�_��k|	�R+���vɿ�]9�����}�*���e����׾h�ۣ������e��7��v[��tC?��6|�6?�몥?5CVՆ��vM��^�3�k�����ܝ������"������-_�-�E��?��ؔ�m��Һ����ۺ-���U��kw��O��ŏ]Q���V;7�����O�y�T���F��m���D�pw�zW�����>��v�~=�q&7���O��������`�%��E_���Ǘs�?�a���d���ӡx��t�w�@I��>
ѿ�eM3�87�ݮ����KÒ\,,I��DY2��8��vU�+:�t��|T�ݺp�u������P��9E�o��7�ry���]�������$fi��%Aj�B��vQ՛\ߴ�ϴ��[�V[��t����+ܧ�>�8���̯�e�c�&YJl"綬)]�ê\�n=�ݜ�s7���bK����=C����eI$���/��H�,=�-.ͱ�C�l�V��Wx��j�)�H�Y��Ɲ��%�mYэ���PeU8������D*q����H�i��|��-7;z�o�o|����9^�CQ.W(��i���bI���C�g��+u�֝�O+�-܂�=.%�����t_��%W<\<����R]P����0��T�?Ra���D*s��(f���*#wSJ��Ŭ����������z���lr��T��UM'��]9��[��q?�ys+��[Ԣ�|����P��۞��.�6J�0�^`���fU��˖��H�U������~׍�h�@IA��m��(U��8BL��,	�$Ӑy�[T�5uk��\��s�݂iinܯ���)����>Ŏ�)*�P��7!7��uZ�*u2�;x��Ʊ�ջ�;�=R��GU����R.����Toͨ�jQ�SO�>6x�~Y��GF��9�9���������}��]�Ԗ�ॏ���!���?�Y���O����4Jy��X:�TzУy����~N�S.�s� �6�d�3��2N���с5�^��Z鷹�u7{j)� ��/(Ns
҂��5:w�f:p7��|Iy�)۽�Ӣ=Ŗ��䜅�����D�`/r�N��t��]޶��,+������E��鰢� <i �P���d�Kj��(��Q;��.�u����/M)�;�Q��tsM@c��f���0��?mA�e��I5�}�C��F���F���LP�E���dT�R#z�(m�p���EGQ��H�;ఊb����aM���S	L��	�0R��S*C(`�l%8�<g�v�Kw�i+T��f�o�������M袙�f�?���v_s�KY!�Q����z�þ��kft�9<�;>��r�h#i����`b��|�k�o�)ys�c-�ú�@m�ݿq��M%��:GeG�ܺhj�rqī�LA_������{���F~S�bF.z�%�ٖ�/e<j^��1���j��������~�R��/�	��<Vh)L�t�?T5eH;��gu��H�/����KB���/�J��u�?�t��]����v�ۜC�HmAU���lm���Xrk?ͧZ|�׏��P����rvH0�X�&^x.�l��!�/{\��ŎJ8�<T[���� �ܝ�m��b����a
���l�3����m]U�~	�#Ѓ��\c(��x�Eahf�r	�Y��6G��P��Jt	�^lHp�}���1�N� �Y.QGSSB-����Ώ�+���q>�QY�Q×��I?�c�F��L��b"E���'���;����G����Ќ�^!u����4؛�M��z����M<�b��.��? ^@��Fo�H}��XНC*���E���2\��[���$9�1_r���6�%���^)o@�(cځ�G.g%j���-�(�~gN�<Xq�q���?y�0����E9C�����2��5�?��q�v����r\:��M��Rr�S1�@oAڋ٪���y,As��Ք�20�y�!DS��8�=/B�b!�Ņx�2�=��AXD���ڌêr���C���U�k�Y	��\R�.��b
D("�?5͞��|^V.=��I�*z��6�@��1�roy<� f��N9F��Ty�`EV(-�c��l�4�k^Ӄ��0z�ES�׋j�6��l�Lp�D��޸w��G>�G�k���k��L�*��ȧԘ���_�)��E^��aU�qs/���i�����j�VLA�U�̡À?�Q����D��k*�i��X���"�����pۧ���oG�T̹c�RwJww�o>ZV& T�/yitf�N: :i&&i~޿�	�F�.dZ�F�_��V�I�b���ޠ�_���)���� ��Ix ��G��j�X�Ϣ���@]�Ib�蛜JP_��lE�c���b6�J�4��l_3˖[�#������w4�8=�j2�����G����Th���>t��8����kP'�2��V_��b�ꏵE�$0pQ��qe�(7�5��b)�����[r��n�[n�y8�#g���bQ��R�"a2͞�!�Si�](FԸS���#Uf�Juʉ�}�2D�K=|Q��s��+|��Bg^j8p_�n�5ں�7���H��q�	�Y���
�\,,�&��d3����Z?Q`�����T{��B�%C�?Jܼ��-߶����au���i!��EAm��� }c28[U��5E|~�A��y���
��b@t��,��c��J�f��$�����t^P�\ce�ظL�hC[u㾣&��.�����1/�����;��ܸ���h2 �q�Ė���O�� T��i�ru1��t�M�G�"�>O|��\�G���s�;���Qk�7�2�ە�`��Q:>�_����GӢԧ����@��q���u�d��o����؂B�Y�����%��2���#�<���7�yu�����`�@ <h����M%BO�����R��7�L�l�ూ�����[�����f��D��x�%aGo��O7n�������?:z�t)ӿR�����Ptn��4�-pF�{ ��h�����Z�,������5F�?H���V�ع���].�Usن�U�tm��7/�ÃN���3C�-������a�G3+�@)(m�S��{!���m�3D�k,,�#jq�evƗ:��Z[(�������s�Y���¡����J����d�]U�%W�rC�)q����!�]!h���8�M��9�s E\�6�b��������%v���q�ZV�aU�F�u�u��t���7e�ă�t��
ߵ�(\���Y�ܝt˪�~���.�8<kx�����\�Z�3\�k|��o鄲�y����i���4�Nm�B�+�A��f����]���?;Bx(x��8xI��;��D�?��z~b@r߹+�Z�
䩤&��*�g��q��6�ݰ�����g�l���+�X�f���S��з(G̥=o�r��5ӣ7H�3n�Oܭ��=>�"T�a�
l�{k���H%m͋)88握^����lSb+Q_G�I ��r/7���s+@�(.�9=�XwD�K��S�r῟1�����Q��B	f�I?d��rK��]�-��G���h�,��mlC=�f����R��9(O|#��e2` �����ߝ��)������El��>s������4�f.ӣ̬ʖˉ]Q�w�j�.��WLTB��!?R�ϥ[�F)�X��QJ?3s������p���n�f顖�˶� �*3e�:?_Y\�Y�G�A    �D���`����.r::Gĩ�����l[�Ii1o��^��Ra���i8�'���L�J��EcD����%ƿ�ӆ�ɼZ���ȔZ��@q���D+����@�Ev���֜%��.
q>�P�)��=�@���\�\����T��ib�-�<k��Z.�N�J�l�*��������X+�� �-/���L��J��1K3o��*e�r{�+R��
f�bY¯:?�Ơ���8��N ���h��w��'�0 �dL0 ��N7�ߋcǮ��@늽y��m}.��h@���D�S���fk:W�\���P��.������O�0M��T��7�զS��r�G��pz�S�7�3�+����(a�N���u|ʫ�Y�d'��7�̋�<����+J�
�������鞺#fCy�HNU: tQj����y�5�$5(Z�.�3Ӊ�
���(^�y��m�w8�t�%��TS�ܨ�S��nV����]?A�Ĥ;*#���B\׭N�}���3Í>�k��_�L��7n�b�4������w��7�ES��Jt�&�޸_�|��;3��<3�Ƨ�?>���$0�����!м�2��D�B��`��f�	�J�5~QtJC{��j�"'�q՗T��K����_��@!���.ٷ�FglI���·��w"�$bWB�
:i�
sL��������|@�b��W?-N�;,�HWp]�ӮkR�!�2�X�3X�T������ڧ3kM6���� ��o���BDf���3�h���#2?�A�JO)�R���h� ,��8��6�����E�?U��B��%g����+�@��~gf5�u�� ۚ�hz���W��c��" i@�`ڱ|�Tt>�`@�9:޽��M�2��8������s���Z�_z�/w.���Y�Z_x"_'JC�jK˞�����\Ç�O���,R��"�a�R?���B�emIF,Z��X$A2���nZ�\
���yDF u��<D�__ ���c��6s�Ν�S${��fٍ�:��	�rZ���Ay����`_��b��>�ʬ,Bbw�E�V�����6�RD�ӭ)��1C�>���"��-�\���A�I`��ou+g[��lٙ./ Ze{[��f"xb���S��+�Z�?j��Μ��9�ٲ�j�8x]�c�R�YZk����F���v���NtyU���/��+����d�Ih.��� ��⨻�s�9z�������p��+wI�?$q[�M�y��~��x~A%g�H���P��Ώ�O&#93q� %ir��>���7�
55S��X����E���W����D�?0��c/p�N�:X���ݸ��u_��͡�uÝ^��J{ɛD��[���V�KG�i�(ա
=���3��\�����!�2������j�b&�MQl�Aw�����գ_�N[EyZ��*5�	� ��� �X���_�O���xW�<|��r���/��4�x�E��x4T��z�Ǫ5�t
�R0�I��+�����
/�-�{� ����+�L r�C�e-ߕY��0�dk;i��r�����X��g���a�`��v����m������Ɖ����ĘE_�K0��$��JI�P�=�%�y��`���N$�b����g�X��s}��Y�R�yYb��F�gK��]ī���i1� r~8�N���u�;D~���^#�R'�,�f-3=���GV�ez�5���	���ٌ�yHu���B�I��y=��Ѣ�����.��Dj:�$K���{��˙Y^Z`�,Y�"?")4emzҰ�I��`�o.���1�����V���|�|B �2�q��m����~%���`W��{+�y���k�j���y��������<35���%Y	���HoXhhW�D	 ��{h9V	���[��e�5�xY���ů?�F�p�XN�����߰E���J��������-艳ˊ�tf[��n�ળ\�L�:��/jx����ڂ	j�\GGr[�+���^w�.,�d��:aF���ouK[�Մ�5]ܹ\jI.��h\�E��)�ê@((-�^����^alǫK,X&�"�מR�9��P�k��H]�g��/M�O80Oeqp����W1혬�R���VqM1R�,���T,|�@�k��p^�A�v=��a��Q�I2�K�� �o}��X����֌��a�_��ڣ�oٙ�z�vF$�R�!��)d�J�D`S�p�a+��HRk�.H�$M�t�WL�5;����}/��ʾ��J6Z�0�K�n�S��?ѽ���o̅:�*Ph�$^�����i��n �Ozצym(o�L�Rn��{pN��P�)��85t_�cQ7���{��0�HG�/�LB�㠿�3W�1�2U�	Y�%<���	O��>d�Q����;�[���?�?�Y�ZsVt��8:���y����5Z1�c���UY����'tx^�)��~t��{Q&=�b��1��TJu�!��;}q�Q�ᅡt��"v�� s}����[$P����W�O�p�jYp��E������kU]��������
р��_�]�,ޙF^g��>�*�NU�5��v5P2Ȍy��~�������@�.�����+���?�Ɲ:��:o�`�6b��l���Im?'b�3roz�jL +HeZ��|6+vV��C��s~�Q\�;���Ô:_�<�@'2�¤� �Ȃ=VUn�o��	�|���i�=�[�x��z��$�El�.'㯲���2~].�N�~�QbMT�7��)�Ċ�H2`)�z�Iu�V�a����s�|[�[[߷�+�qx���:d�4}E��ޕ́YΔ��tm'>�͕ܰ�rʧ]+u�!���"J&��Y	�	���}��Y'�:�8gU%]�W#rN�X���{������w�.>�z��)�ǆY��G�M�
�l-<>;��Ě��>�.�^�ȋ�eo��}S��%�i���o�'_;��!�h�y�� �ەg����]l,11��h�{O7O�y^>�����F�b�@���|?6ʬ��܋��ҍlF��V+*���)޶�|V|o$9�?�qj/m�|�Juc~h���N�{?�#�� ��6�э��V5UD��!l�D�I��FY�X	דe�#%�k�h�ס�Ī2�ٍ��S��s�+�Q3���s:?_~Q���)~I��*��a$6�V��w~��B�g9c��={���%�N$�
�%8��)�#� ���Ƶ�a����kf: ��]��=d$W����b}M�l��z�'ǗNp���gc��xj&�� ���q%Y
3K���:pŘ��iiȫ�6��,j��O�/��b���/�=�e��M��PcO���L0�W�C^׳%7��g��x�㬱���"��
�N�y�oZ�y�����yZ@33ՉFr;g�v���
�L�g�m�'����	����2�ڃ4�o�=Z�%	H�F��-��˪��`g��g�"|v\|�����A���،R(2.Q�"�l�D[11 �p���@
���������l�p��S�P�޴��5���>fـ��5�Oj�2��/fj�k����kQ�Fmn;\t쵏�b@@���L�7���?���-6��b�H� �'%�i�l̺�pkp����,h񥂖��`�ȋ�x���x�"k 건76q��{o��t7,��ړ묾]zA�
�/�[z>��uY4�2��)�t������R�͞�4�K�}������;��_�+�f�����zW5�����:��[=r=+�%$!��C�0�Rv�o� Ы|�ZȽ'�U�Xp;�vΠ�:?�U�{��d��%HK�4�I�L����5rn��A���2�t��V��d�K��;q�P$����/s>�/�(�/�M/	d����?,�z�Zч�*~B��j��մ'5�_��&B^/�ϴ���"6�XĂ��}F���)�Z%1<XJWs;����O�R@6�M��"*�}��Þ�O]mdET�d%��}���q��2S��Y0�;VY���1{�C�V<1��ȹ    ���@�<�x���V���� �ks��8�Ӗ���ߗ;0��,c
�z�AnV��|�;����GB�`E�iv��5oK���0��xY}p�+�8�Hh���;{����a�����a����u9+�˯�,���E3�(����"�`�t��,Gk_뾑��0���J�ܕ\k����c�<�eS6��Dj�Q=�
_��.�� )����#u�A^��A�p8��*>t����s�d~Y��IG�>�W�i�a�����]��x�{`��9U���5������O��UeA��ޤ��|@��4��o`�a�5�s��
��w�7�0�8�ɋ��`+@»Z��"�ko�,g���|�׎e�Z�M��P��H�"}��� Y��� ���R��7�h�r��)�������#i�1v-��
8��؟03}�p6 �id�[�Yi
���n�vu�l:d��5��d��yH܊D�3��
��KM� �:�?q�;��t��w�v&�mÚ�Rl���3���
�TR[��PI,K���Q^�����c�3IRq?/[W����~�p�F�$��1�k�}�т��r�l�T?7�-���y`��,mH�h��>Y=��W�׮d>����v��x�_�M.��d@��ؾv��K�`kޛ��h�2���[1c;;�<y�����H9�b~g�����g�p��WnV�0��������(�2���2����'YX�(iV>a1~�J�������'�ԯ��`��k/u�ʱr�탅q
�����b]<�"�,{��P���W�M��������]/�	�bA�t�0:5���V��1��������٥�z����E9Ե���)�\t����̲v?�f�j��a0�Z���ט�Ar0����C`0�L"�����ђ���,�L��3��p�@��:v�{��߸��
̔�J�����d!��Ͽ�%Z�X��԰)����ZO[ӟ Y����%E�@v���#�!���|S �V�g*�o��}u/�=o`�ϱ%���ee���ߵF�`2=� �6��?�T
�K�ΔC�~g�1x��e����q���X`Bq������d[�a6_!8���hb �w���xf�,н�Oy�fu���o�0v1=�֘��~�&�B��(����(\'_���>�,�;
��hL�D�W��44]��x<�S�N�-̟�9���O�����Vx~�|W:(�����i��8˺+̛�b�A^�aûP��^{�r,�~�-�ji]���d5��f�$��^6�"������ �'��l�	�b���P��S�>7��^�Qg/)_�������E����Ma�n�ra&��.s���(Bטn�m\�Y�H4�ޢ3t��e1[\,f��T��&~Gǀ����2��[N����~��o]�����s�3~����Ţ6�� C�^:������D��SÏ}D��-���X�yr�5j> Pi�YY���,��wm
C��u�;o�ָ^�Ps��T�_3U�����
_���i���� a]��Y]�]�R��_�
����‍W[��nx�:�+���b@��,0crL���3��,xOA�μ�%d�cqތ��B-�EԻf�F��R��K�Y��W�>UZ�aߚ��l���ⰾ^�Q��|��tGQs)o�����d=#�WJ_Ŭ�04�����fu9-�c��#A�.k����D#�T��E<�9C�	Z�q��$R(g �L3����!�X�fش�� 4��s�H��qW3 ���~�5W�rD2L�9����gj6 DI�Zk3]>E����g�)z��o`�b����t@8����t�5G_;r�������R��ݑO[�򆱕��U�]Y��{#�������8�vV}�Z�_�,D-�B[3|fP7SX�)*����چhUbAbq�^��{�����Đ⾬sl<��j��{MƞE�i�,
�-;�|�\��.��d@l��x�d�?責e��.�G�.�Ai$~>?'3��辩(�<1�-��'e�mW�9�8ꇙ�?����7�]����f������FtV����6�o������΍>���r����(���a�2*2J*:���B�ۮZ�I���ƚ�fO�8܂����f��	H5Ϣ���U���nv�{)��X;���Z���)ٹZ`HT��oI\,�x��NUXr#�����R;�B��;jcQU.r����������0b5���
���*�#����,}~"�zʮ
US��ZȚ߷�8���%��#H��sdNό�%�E�zZqK�gt\_vj�ڠ��M��?�Z����t�g:��*��Y.j+��|�0e:��ܟ�ϰ�T� ��RZ:��Rd؍R����e�mUsI�}��������`C�	��v�d	R�g��'�)ʨ���l��͜�ƚ���n�B*n��u��x������n��蠿�7��E@:<���;��f�������-B��V����1��]����}[m6�s׭u��~��9��g7�}��I�Y'����x3�W���;4��{�#�݀I�F���ޟ8��	?�׎Y�?f^[2<`�r��O�=�d��7W�����S3wb�+�Khٳ��AI|��3�L��L�VC�����'Z�iծ,I�@����51�e
=�E��e�X���{X!+�D���"�|M}h��@����B_�0����c�*0S����%NX��S)B��9�.�M��?1�����m��l�ֺ���xG���P���[�TY�K��ė��<9�
[�Y���ݒ���N�s�I^��k'c\��SqJ��s^�3��ӗ�h���v��%bE�g�R�4�Q�V�rs"b|�D	�B�����/N~����E�������X�A��T��`�a.8D���nE��ϝ��ҋ7���eQ�.���Cq��WT(B��X!�p9�,�5p5o�6rzYt��N> :I�M\?Yw�R��d�d&�i+�x���.:� '%��w�hkOk��-5 �TԶ�\ !%hK�����i��<ʧr��d���sk�?�
�~�,�)���t,jU�sQ�BS�*�)�1o�Ȭ򧲒�a+*��Fo�U����i�,B*���ם��v��F���C^T<`��T��Yt�m�<&]\��?��fwbG��o7����a9/6^c}��~������l@<bϳW�#j��a����d�+t�F��If�������.�O3|ob�R�4N�����λ�ϐ�5�ߨ�8�7�ǟ��b��U!����{ �����"���)�w�>�U�ڳhM�̽�/e��J�耍ǌ�_�0]��Xa�Ϸ@]HN�b�����\qg#f�(kQFmQc�|�S5撼����^���>|�#Ϣ�f[�+X���1Cz�i^�:ف0�����e�&i�.��ހ��q�!��Jޱ`�. �e�K@Z�ne!��A%*١�X�~������Q�z��Y�30�[�,��@����m�(ߋ��̠{�lL:)��h:ۃ�d44{ɤw���ς��3�,�KtW�K�$�O%�C��	H:��섪:�Խ,J�Ţ���� �l3~�-��l�m�2�<���n ��8E(%]�%��1�%���/�dr�HF"�d�U������K'L�F7���@6UE�ڦ���
�rOu�ʄݶ�BP&,&c��y������7�X|��~��idZ��#��X;aZ�́��"����Q��$#>�3�c4��Ú(�-v�ͯ�)L�.�N��P	O��J�\ۍ �(���ʝW�n&���h�?���S�hfp��`�+����K?�&�.u���@Lğ���U�O6�l�D�'�J2�0�����}޲q�����-��Ew۰�&�@����b>L���9Hᶆ%�pm�t	�k6q�^&C_�[��Vy�.]�Xf$�YEV19�'oBd/J(��y���}.�������7E Wys���eQ������@���=�0�^�0�A�-}�����iX��gN�1{[mv��5    j��m �3J�G��{I=�H$�lUU��c^�5o:����.�G���$��#<�ĥJC��ד�]+��f��+��x�O)����(�f��G�����^;� C~���ohG`����j>,b���#{8ȯ�v�e��w����f�;��У���	��'��^���G;�O�I�ϐ)�b������
-t���~..��QiA��J8)���4�7�Ř�O�s^;�ŀ�&���
Tn� J(z��'��gW����ߎ�@�!�ts߷��x��9���1�~G��[>�ɫ,!�́G�KO%���}	˵x�rb��4���x��O`J����`B���g����B�OA��7\��d�k6�/򜑥�m���O��[:��	&��)�	ً����
��[]:��T���6.x(�+*��7Ǧ-6�О��,���i��N��E��U:�OG����ˮ�m�.s����34q\������=�/�3|����b2 �Ib�s#�:^03�Jy�9��~�*�1�`| �u���+�/��� �J��ݛb	
3Ø.�����<e%f8�L�c��K�ҋP-�[}B�5�����˯���G��Ij�ۜO�Q("#
v'���dW���qGn
G�_򛊗��_��pt���1������!g>ɦ�!��̢��<�zY�݀�=ܴ�ea
/�p@�([����*�
���"TpT���K�Lt�X�G�C��#kg����a?��X��*��Æ��85܇�e1
.�x�N�4���'\ex��d��"����Q��I`P�D�{�.���ߋ��<�}��!��AZ��ʒ�u��NB�aud����s�\���54q��-�e��&Do��7�|�'�?��I�i�{G�L��+"ϕ�f܏����aWJ�!bs<D+xe[���,`|i��΂ꋫ��Q�Tc?������n]��,A���@b���@�FT��nʜ��9���ne9�=�+��3��-�v�쏻�IdH���.����z6QP��m�`Q]�(1\� (�Y���a�ܽ���if�u�s�oE�P�?�<I�T�At�*����}.k����}�EtWx��#����na`�3�*�-ض�g[q[U�.�=5��ʊ�w�|�ǭ?������|��/¸H���S��{��?��Y������"0<���QW������Nњ=���8�^���ܱ��Fa[��@�H���Y�L*��W\��{*]^0����Ms�f��Q:�]͎�ha�n�bK^Eʟ{^U_�-f����-�(x����M龍5��e�
��b#��%Dw��'�0Ve ���r���S�B���c�y���;�"�BP�Uy�h��|<���!|s�Ƌ�s��Β%t�i䑷�^�Q,с�{�Wv�>PXuޱ��fU[[qj�E���T���^��T�ď
Am��y�v�������4j�:ǢU�}K�щ��R�u�U�+a&l���x��b���.��QJ�o��{����B���Ly6L�g��,����L�g`�z�g��+Ă��V*��&]!�D�)�s5G�����X����# ��yo�����?�{~d����s�%d�����CƏ��n%�$qg�,���?�c+F+M&�0��\�5�����9op9-�����e�����J��<�/BZ,�� ��d�_l���z����v���Q>�du�ztc�ȫ��۞X�C®��#Jy""`�|���^�*Sh0�k�u�6���MV�eE�I�o��*o��R�HG�0�V�X�60WY�pd�P�hu?��y�>ω�=��5�����CU11�g1���_�p�菲��$2����G�gx�Iz�Bb�C�<r5I�'��Y�m]�h��zHb�E��+�Va],��g��Y�k���Ȇ��L��S�l� e��ת�(�O݈�'�;ɀ�$�q�Q�tu�U��7Տ.�t4b���P���[�\���
�af�:�e��Օ��Ϭt����E������i��i�ɫϢ8�a����ť�>���p�IhW��b��r>��Xc�����չLD_o�u���z'�B_�l��W<��v�:K�S�H�.,�O��#c�5}�jU�w�Lr��4l���6��3��p�1>[=��-7��.�<X���Wbf� R�pv����.��b��q�w��OT�=��=cw�ΧR���PΈ�$,�aI��*gܟ,bYs	Â�s��k�h>0�H�4X����5�Q�!�8�d���~,0y6N4S�'h�_��bYYB�{^��Ծ��w�N��	�k?Q�Q�n3�#C�,D���xKŢbaǿ"�[7�8�2�'�L�ƍ��rŗ��,��=����,�ж��	�`d���4;(*�"w c���Tԟ�GkYavI�d~�T֕�=�g;�9�����${���6UGR�D��淆���o?�7��p!��F?�C����~E���:޼�on�yg��N~l֎� ����u9;�D��q��a�qL�01�hV��V��*��B��9��Z�aMe�o�ʦ�H�?T�^d�!ބ��a�(�I2�����NX�;�t��7 �l�m�fɍ��\L^
Q��N Ɂ�#�Yy��G�U��jy*n$S7ى;?���TO�C��$�D��KQ�@��
��SF��c��A=Fe�W��dT˄�?1�~��`_z^�ͩ����O�K�",��)j��|A8%�T;5����Ye���c�+l��I4 z�$���㡻K��ؽ���䑟�t�ȗU�>?���׿?\��~`���u���D޼�Frn��BĪ�g�|Ց��d�*OQ: B���`�k���s�|ߖ�w1���W,	y�����F�Aa ���{����C[A����9�UG� t�U7�e�tJ�B���u�Q�fف���g1�����ߗ~��O�0�ɒ6�(ΪuU�d�����6�0������'��*��E�786TT#+�2���V�x���B�^F?<zR)����<E-��D��t{"i%K��~8%�����Ӿ�����,��1�c��)#��B��� |�t8w~�z���?��g����Nj��y��!^�g���~y�����E-���0�*�逰%q��`��33�J��c#�g\2�f��i�k���Xcz�
�=�#���碘F��~��.�NV��E���O�:����l> d�Ag}�������`�\#:��i݈A�?1�{힩�$3]�8o-AWez,��.,�����*&����	�o���[�"��7+��ռhnK�=-�`���\з;�s�M�*�{�9_��ș�>��qz�+ޙ��i�í�E
�R��&!~8���y�Xq?v:�p^+��#I�*\�F4�j��_%�?��'	��\��� ���Eм�MDt�[k�+pJLU� (�u
ɓ���]<YR_�M%,u��%ƻ�]F��ޘ�����L��Iβ��S9EܴX��R��	�~ȓ�U���oL���P�6���{ή���<�
��'d9b�QM-ɾ�v@�Բ�r*0fcK^!��>X��ˊ��l�ݸ�t�9 _�ӽq�ǣj�����z2��<�~��5�QlM�S�>	�����Cw�
�t�����k������b��F�ܧ֧��9��Aĉ��[uJ�(dn[~�L|��5��H�o r����1	&��	��ۥ���&�nܿc;ƈ�.E���o�RE�~6�K؟��N����[�C��#�(�bf���$ �˿�p�D��h]e΋�������x�J�'g�@�G_Sϟ�!�}�b�P�tf���dܬsF4�="s*[�1�c��O^}����b��/��(mfa�#'>�%�fԫ5�1Fܲ�g��>�]^��d�����#��/�M�K~S��G��O2�Y9ߘ�xjg+xR���3&���A��	��;we�f��n���(U*ۙ(Q�g7��b�Y�D�^�po2�){R.��7P���L/��hf�Ċ��)�ƅc���R拄!
��j���xa    ��a&��o0`�[�!�J7�r�V�h�x���_D�ψ��ED=�k�dW����řɘ�s�˜�W�����Tf�{۸��.��g�Ud ���e
㝂-��Va/���bQ�.��$L�U�[�U��������HV3�X�"u`�*dGxiy���Xq׌N��z�XO��[]�k�C�hp$i.�/�ɀ ��-���zmI��P��l��݊�W�m�e�L�U�d�h�0+�sD�'߽z��ÏiN̶�¬޲T�U�>��r������ L;�0!��s^�gHq��~��b?{�*�&�o�������{}��f.��>̬!!� �*>#��_�+�B*�8ˍ1MBg{��s�ny�n�����f����[���ٺ\<C����EG^G��岛W�;�+!^�gذ:���� �+�N�P���Ȕ,��u�ce/;�)���A~�P��Je|���(�VH��$�Ifk*m�n(�R��w%�8���}N�dz�o~2 �����2�� ��Y[>1�;b��h\����-
^2lA�0T��,�WO逰�IZ�á:��v�VG:��A�u"��.��y~�U>q�,��Y�Y~��.Z^�ɱ�֖�� ��V{v���TD��� �?ڲ��3b#ׅ�dY}?����0�1�`���1����
��yg�&*����d�%��*�:7��2_��7�^�/	��?ta�P�w~+צ�{KVζЍ�������:f�v�O����6�j�����,.Ƞ �Il��ʦ���Lٖ?��^c��qH� 	���0��Vգ���šՑX̬���:�a_C������S�nvX�����b!���4Ͳ�EX��ׯ��[hb�"Y�(�����*R����3~�7n~V��-��`���T�D�m��J]�F/� ߉�Lg�[[�{�Br��mU�B�bJH��/�/s���[��
���6*b�ff��+� �XR-@o85�*�R#׬3Vu+߷���*��)���w-!��w��(�-���q�3����Q��^Je��˼�ո�a��{��_Ԝ�( �u	�EXZ�FT�a��f�zE��᳄��f�׊�B`*W3C�e�@���\������x�&ίEwJU��@`� '�B�����'�c�q/�����n�pX
#L��e�bΌ9#��K�^`F�"L��.���DS�Ͳ9�n&��BF��9�E-��Y�l���,5��!ű8��D)u#U"��kr�T��/���;+��t`/Ρ�`β��9�$�	N��M��Oٛ��S��!��?�H;q({O�����}���.!A�WA<o�6Z�B)}"�|��f�"-oF�ߞ�\cU��?�ah�x�88V���
���hҜ�v��K��D�zv�r�|�
Dgm�����'� �Z�la�Q�|PI{�g���b���U�S�lg�mΓI�Ȁ�2��NC�3�T��Og�̧���$m��˕��K�_c7�=��v��E�x�so���'o{Ï�-o�)$f��~f�p��r�;\�d♶���]-�b��u�b�ϋS��[qڴ�+&\�uئ�.����5�բ�� �:��/��G�@8+�"�����PC���Kb7����02�hw���̴����M?	'���[�@�N8������t����K�l3��S��{���o�D )^n�Q��&��q}���p�Y���1�����En':L�٣'e�^(9G7[�hݔ?����l���f���0�ψ�_cX�#�afa���;��a#;}*� �a��ڦ7�n���q�v�IDl;����8(���iץ�T�-J��Jeqd�mú%'�`��WX�x���0=q6Μ[��LBV!*��%V+_�8O �� ���p������i1CKx^~�
���Y�؟dvc���5��0�i��s�5O��
F��aOPY�;�����G�$}�����[\��R
F��Z9�è"Kx�����]-�,<2���K�L�3��ט=�c̑ē����RY".3�j~<�[�v�b�*wf���n��Uxve+��3�茂$1@��!��E{��f���_���u�Σ]�*YL8�p���?E^�fV%�l�U�Z�OفR�<,G픁C�t���u�g5n�O�u^,�8b{d��`$��?ra�6�2'k�Wh�^�r�A���,��n-�O���eLK���͘�S�+�[n�^��N���~8�$���43�C~�|ä���3c�������R�`�?���?�e�=��8�ˊ��W�`Y�� 7�7X;��"�B�p��3ɧ'^W+�n����B�,���#�����x�Q���W�
J1�9��>��x��?���<�g�,���q̥�U3@u������`�e��)���U�-�)�_,��i=
��M
���_��ʴ������U�_1ӗm! ~�,gr��YU0��E���z���\>Ϭ�_����85��s��JM�q-�p�d���8A�u�/2�"AwU�i`t�}�[�ȮԘf���7���`k7���,U��'04�����+�� �U�dꌕxV�հ2#���sXQRW�5���~�i� k��|���v���Y�ڻ�f>U8a�;P^� lX��q���Pٛ��p�Y%M�.?�΍5ov�֬�QM����8҆�8��I�j����:c�, ޮ*�7"�bdy~S�{t�g�l����XpB릪(~�8R��!��Ȱ�� e�Z�-�T�VvU�M�T�sQ\�ѩ�y��Z��F��Hi�yV#$@�V4\d(��a~��݂�Zu,
��`"��@���fr �:x!.�忱5�#q��QQH��67��zF!�� OY���Kp��Mǌ��HF?~�3�'���%A�ݷ�\���L9�����ȱL7���,��=b�&g�t��|�d���^ҧ1�"���&A�C�8��d
�.�BC�
I�׉U��m�뺶��;v��Xj�`u�)��HNkL4	��7�6u�H\�{���ڰI�~a�">����z�X+��6�C�2�o]>�-$�S.��m�Ў�|���M�؋2�Z�9��j��o.6��Nk�TU����H��/Rg�.0��jWا�­�t$!��&��zZ�	 VV���KjZ��Ԗ�AaI/��K��}}C����{�,?�|�cE�Jy���.�.�{�<\:���jv�o(�.�ȬZE�I(��I�e��8�O-mu�-��*�f:��	"��$:�(
U����`�����}�]�Drt��!5	���/6��0`�G�
�n�m�y1S\^��}�s�j�=f�bG�O6w:�c��r�7�����W�(B��H��sM=��*��s�=ʺ�s�x��J�V�-Gc$�W~�4���ɿ!�7U��½p+��`�u�� h��2¿���wlf-��gg�ծ��u$�#�?�J82�Pa����P��ud�����`}%Qh����?�����D�8_��c��D��t�n�;�ZP��e3V��i$]G��K#z��J�izb�3�ʃe��-�#�Ց�?t��A'T�9�|���]��.�����A�����҃3�pq�ͅJrL[|��E�J?����:}㸕A�"i&-F�)/:���� �o�E�;:�6�!Y��0G��C{iz��#�y��٬���3�W֮g@�9:����c8���,�A>�� �~�LN.( FWk�/dꅹ��_�-��$-�r���:[�2�s Es$�AL/��D�ޒ��ݭP��B^O��X���5f��(i$%}��˼�@E�s_l�e)ow�ik��\�+�V	�j����S�F2���n�d��"��g#5���7��D)Ϻw�&�f|%�UQ�
3����8
���l���:���?��Ab�ع��L�;F���G�w�v	�s�_o�-5�ϗ�p4���G�p�G�(q�r�i�v������������t�Z����Ċ~��Te�[vVX�P�,`��2,,vvj����HE�y�`�\����Sjb    ��FJ1MF�逘B�Sc�9`���� '���Q��YΪ)�����;^��3rsblME��X��.@�K;�e�?f��c�I�b�ٹ��ʍS�����R>�dk�\Fr���f} ���=�]qs4l�)�;�{J��ȧ���8Sڃ�c���ΘXЭ���e�ē��� \Sa��:�����Ɇ8=m�)TaTnm`��Ї�e�kؘ�ݬ�،6@�R���)z������n㑬����|���=h�tJ=�J��u^npJ7�p���l�-�27�yU��3�\��^]�(e�3���l�mvz�ʺ���b��=v��7Sv��"n�^D��y����j�h#Ň�e��6�A��j m��	�UB���x�ʸy�_�3o��m��"�5�X�/�(� :)�d�{��c�\!(مTu9K�[MU����,��씖?�Od��]|�M9�c'&	c-�8�fr��$��de������oi��ל�
��[Z��z����h��޸�E�Tuɔ���S���u��ԟ7�#=D= /	M�i�dMzn���i�Q4�5���h��Zg��c�)��~�N:�d�q�R���P�pؖ�SjQ��N1s�����>�ڸl��섮�8��?��%��j�GX!���[�Na9mj�`:<���cU$�ۡ�;�h�)`��#�3��<-[��*	�/��1��H;�Z{�L1k�i幃��er�-3��n��:�Y�����p�:�i}�Q��~�q����uUU~�Q X��{�5:�a�M V��/z˓Ѧ
9���k�I�d�o��[$�q*@�b<�7��0��z�~Pj�a�����}�0�O��@��BȢwu�/���� �+q_�;N
}kl��OW�����¸�c#�ϲ�q���?ڢ�E�"7ϯT�4�x$�Ȱ?���^��2&q�,Vn�(�3�rXU���nDV�����o�7�
����ܦp�d]-�+�q>�p���46��@�A�B)�0Q)P�F"�@���7��qF�5;��� @�w�I�V��_�esފ2+j$�h� �>��X[M�;�X�-�+!�8�a[�*��@��/z������n��O�J�|?uٌG�&���,�mt=�;�SH<s,�0�^x�X�]�]N���A:�@]��$Z�ɸ����G9�T��Ǜz�\��λJ���.KkmE�K�<A���Q��H��u��5�g3��0�tjfM�x��8��y㾃C�:������)�v�H��@��#�y��NB��
��1�l��gRԞ؉��+j ~����q�"#O�0C�$}'l�Y������Kw�ڱ)F"��̗�[Yn��W5��+�i�2%���wS�G�Ug"�Y}�$>�����FI�T q��l/��&W�P
3�;��L.�y���Oc�q��yê�k���$H�^�i��>���X�Ұ����$j �oy���r/-S�$Ɂ,�4NL[���������y�]T�d
QCF7٪��Q�o>1�:��LF��.��-���̜;��!: ��D���P�%��v]Y'��k��X��;Y��)�����o�)�#�hF��'f�N���?*��k����#	<�;�5#��7�-}ֶF��P�D�/���
��s+`�ѥa.��� ��81��Cl���&e�7 	�������!�841���&O7)b��G�=��	�4K���N1Ek$Q0 Zil�pR�"��	��2�,����/�,��~=O�dͅ��p]��e3���1!u��SHP|GB������p��йK�:p�}#-�L4y��
��⪭��+~�,CbPp��u=��3Q��q����K�k,uĈ�YA,gA:�P/�[�T�E�Xg��<+`�Mu��� )����qoX��6�ȁޚ! Pz�.\��J�� Jq"e#���3���o`\��2��UT�a�i���-�E2x�L@F�(ŕ���Ȫ�Z\�}5"�0Ta���H&rQ4� ����K#��w��r�=4Z��y ��XM1�<�Dx,b�{�
��#��q���~��1v>�]��
Ծy}`��R0C�����d@|�(3+q�ľ��^���ތ�r�1b��,��H� �3��%���"��	�t����`0�S�"�*?%�2Ϻy]��B[�N��72B�;}:#9���^��Q��)�TwԜ8�C9��׋�s\X��J�̩����jqE�H���i��f0�8�E4$]�s'�r2�e��ʹ�S�G�hi�ϣ��Ϩq��vdN���8�o�A��*�щ���j���28��!�՝�i�ʟ�J�RP�l,�� �4M|s�|�.���p:����SD����M_��}n��F��.��M;U��,��Q�V6�T�?�RzX���~����	 ��)��������JY�����R~�ZW,��5O��n�#&}1ٛSĭ���~8!hn��s'��y���rZ�&��hd�OK&o��mZO̥`���yq���R���菠[Wڼ�_
�jYb}Q?W�U��?��v₠��Of�U�i�������jvzJ�����J!�,���H�p� �93Sf!� {*��P���3Q�.�< a���7��[y0��� [=YeZ���g�WF�������襀1`��Md��N�}�RW^�3�'pCC;ĂEB�ƫ�����/K��-{Y����ua;As>-̀cܮ��	Θ5�(�@�hŽU�]G�����[����l$3�h 2���L�"�~�\M'yh
�xr��2�V[���j��R�
�H��q�ݛ��M9���t��j��F�9���{�6��'t����ei��1�)�#!;�ހHƩ=����_�'�ū��˨|W�yc^3\�(x�����q<��&���RG�a���̽�
fʼ4�3�=���˓��2~��p�`@���2�]�t8q�ct{*�Q6�=^��6EV��nR�F���ဈe��(z��ݫD�(,�N��p�I���nM�e�e
�H�ٸ?��Ah�
<�߷����l�<�"(�݇�ڈ`<��WܑD(����!��X�$�SY�1J�Lɧ
,ߨҰ���GEB�">.�{�Go8�
�)d�jVXRb����Fd00���R�rT��L����3�s��gd�)w:��A��5�U�o	�bWn��☆U{v��'3���G��/m�"1���,1����X�s�=ᣌ�)P�H&Yq> <ahA�tu�/��
�N4���e�CR�ǌ��3��%W�i��}\��t]����XXM�ֱt�aMC?4aM�_t��-g���$�>��G��XZ���/�/��J��VT��&∧y�M����������F[�Q=Pt�o,�|@��8��[&"9��&��Tĥ���",���f�ax����>�55REA<Гy1�6/��ë���_1Z"Ʈ�`Q4�i;Ɩ�0�D�ȢZ��ls����ɼ��m�	+f	.Ȗ����l8 ��-%)n���@���CϹ�1��e� ���s�Eu:V���A�kWtE�@��7�ʭ���N���޹��X�k�S���F-�;(JU(۹ueAC��7��-��̷��7q>�( �`]4X�gZ�x��|&1�X*)t�b� ��1��H�J�Ӌ�Ih���+gv��|%���r������CP7��8�K2 ٌ��z�w>
�P�N��Ѹ��q�q=��n<�X� �	�3�_&�_�}�{�ZkHΊ-�p$?� 82���4^�ܲ���XC�g$��ZG7�'��cZ��¨) cQ_7��xo$]W2 �L����^�n*"��z v�� #��ǹ���B�|9B6L1�ja�[Ps:���;��w$�� D3��ئ��y�Q�JYj��U(��<�ފ�}�(�p���i$!�pf���K��h���c�e6��x�7d
�i@�憹c�%�?�< 񄬛�˼T|�f����@,Bsa!���V٠iS7f�Oq�1K�j�����Sp������E\G�>��GD}���ڎ�e�;�l���[��Q���2V�����T    ��@:6#��I;��8����ĩ9����bv���PwC٣��Æ�17J���\0(t�V�,ܯ���1k.R�/���ooq�
>pVS��L)�n��eCt����b].Y�n&��
��Ut�{ѠU�����4f([̸�^���χa�u��;�����o��2ޟ�5c��h�*:)k8��eW�9�z����o�PtB�;"�Hwdӑ$pf����H���!
%:�t���[����������ĩ?H��b<Z<�w~�a��5*3R���]`���j}\g�mX�G��,�����W.(�/���h(y�%������MY5!f�3�lz�E�t�7�[zҡ��A�D`����z#\A��̙h����n֭����u����1��� �ۭ�k! KO�l���u����uo84KɃ�i�!e"%�_+�tD����qS7.�CU)*k_Ex&T �(�J�<Jo2p�C?5��X��ڲ�N�k��>���T�6�)8Tci�gB�Y��燎1+4|U����%l�~�ZfS�8q�D3�C����V�M�Y���G3����~0�L��G�g`�b�R3��V��aw�לW>��HTPb��<?�h]xxK�M���U+��XZ{�� G�䲊��ÊO�H��I8��س�KB�K#b���R�v����[��K����c~@�F"�ND,
����j�s�`�]�F�'+�-v�_�]~d�N���l��;�5��f�#��p�@lG�-�zb���3�Zt��(6�5��OG"VЀ��񩌣�N���~�)����UvB�����O�;0��+����XW�^��	�Tv屳A���0��:���8�>���8�ت�x���6�v�k��Q�.��-`�e���;�A������ht��<s"���]����I�} jܱ��/���Fږ�h��K�"Cv'sW}hW֣��2dm4���b��V��)�W9s�-�B~�����0���'��Q�Nbx�{9X#|�#	g< �if�^� t�ٹ{�Y�,X2
��4n6��8\�`���>�Dί�b�\E��kO	�TI�t��Hd�2A �eG��Q6���8�f�έ�&o�.;W���!X�B����ܸ/�f~w�uT]�eO�C� ��e� !T2+�}Wl��w�agY����ڈxR�20���9پ=� R�Ce?X��7�j=ou�������+���ܳ+i��?eQK�,�j���x2�Ă%ޮ�G��TM"�	����RH��6�0�x:5�q�C&�5C�x��:�b`y`�.�7��l�]�:�F2MM��1=��5L�Oۧjm-�l�;2[�}�I!�_~��E�FBlM��I0I싘:_�f�v�;d�m��������Mx9!I� �Iw%`�� ��-��u���AC6�'��ܧ������t�9t/�8�sN�g�=���pH�)�	I}���BmF���9eӞX���E�遝o�V0Tk��c��N�`ed�v�H���YJa#���HsB��3)^U���d�N3���5�o��L��,�.���bF���d��+�@:�3��M�<�p��R�F)B�߷�C��yy�N-0�����h�����Щsj7°VU��0���S�hL0�j: mN�=G��"�|uC���np�G�@s���A�B߹���T������g��ϥ��K�R�����B�����>a: r���R����#�ATaiDO&A,IJ(�u���l8��l �e����B�m��s��ؙ���gX�i����VD���i�
^����VzL�G8G"���G��I�M\/�N���ܭ���%�z���0aX`��i���ѭyqa���W3@����!v���,��0�V�H��)��p�^����z`C7�JC�F"�����Ϗ,�-L�7����O��V�E9�w5��q�+_�;*K��RO����c�q�,N,�?L���ƸY�����U�B��L{b�v"�/f�bd��W��o�62�d�1���5���Ǚr�f���#_$�����p(�&o܏H�bW�k�y�d������
���&vJ��;�WJ���Ab;sU���ipS����<�x�0��՚3���1!���f#9�ɀ�&qj0�ȓq�Pj���%Э�}������oZ{��LaԚX{�8ڐ�?�Ob�_��w��̀����P��~�:Dv���Z�������eـ@��%�E��~� %��-8S�J��ڑ��Z�v����?��$��7�^�:\�X@�nW��Y�:5����$2�A� ����`Q�|�����|>g5HhC���nJbu�yI�b�x$��l@�,K*��߹X�a��v�J���x	��e%�cDj��S<���ƧS��F���h,��|@P��b'Q��Re�k�8Q֦��	�+r�3�1UtI����1�&Q�ρ�D�H���"�q�!M1��?�-2����e^���)*K�Ⱦ �{h�W�< T�4{]b^�ѐ`a�;�0z���eY����&����cn�:B�bC�&��s��"ɳ��%$�g�uRNH��hfc`U�n�Uq��7f���-�eX�al^Z#��>B�e�oe��Ӿ��s��f@6bn��Un�Հ� )�	)�%��D���(�ǬS��±�<-[8���3�X��5	�^�H��|[���|X�pė�)���#w�H�G���h�X�`��83:��Fܓ2�[�:~�	�ǈ=�d�DI$�q�x�F��ZI�B(G�{��q81��^�9oU5G,�{��=�	:Yl{ߑD���� ȍOd$� �Ʃoa��w>m)�{u��K�x�䲀�T�y>0�*d����d{�����e$7y .��q���Z�n�&u7�ƦP�C���i��Sj+��<<�7�'���5��c�ӳ*'ё̍��i�m"B�]�WvJy�	�c�/,�fEq�@�����섀��d�*��&YfGmq�9q��Y��ej�BG6������?*k��2Pn���,e> &M���*q�e�~�Y0�V8Ǒ�18R��c4�&M�y�X�hZ�_�G���`�i�Y͝8q>�VU�p�u�Yӈ�C�D8gG�U�|�#%�i��sJȉ�ىX9�����xm��J> +�({|9�O�d���Rq}�~C��0��ș���,�3ψ!g�cޚ�.�L��r:m};�J6�~���SL�DV$���:r|G2/���Y�&�%L��֪ȟĘ�8AY��F}�;�D�XFRG�GV�	�PMx<�ۊ��e� ���z�J!:*D��*�
������)J���;�d�Q�\�U�l��M�u.D���2:T����.�p�(R�Cݷ�E�/w����I��pf�:���P��^T+s���"	���m6��b��>���h������F*p
�U�u���g]t.�'yB|�X�9��VU��$���A������u��?H����P�n[nɶ�3��_P���$K�v�$mI�F����l�����;猈��>u���W��-�y��1/¿���� iV���etpT-c+���zY/k��(?��7G���?O$w����2�Q�<�ŵ��(S��)e}۟?����MPM���ַ|OmH�c|�z�|?�!1y�@�JH#��������А��}b��Q��3��C���1�8�v*vdL�7�ԧ
��D���Zu�(~K�O�����&>>�@��L���5iRy�9�{6	���u�pE���o�"@���l�4B':�*�un�S�&v��蕽������{$�����Ҡ1�P� a%"�Z%w��*��1YE����V���?��\u�i^�4n���o��q��4E���x��p -��$i5R�\c�1�Qc��h�[��" ~	d�/H�ne^�fSrM|���F��a�rb����(g�V��K�v�7Ɛ��-,^�ğ$�#ڷ�^�A1m^��D�N
L��^��u k5�    �����ō��f�*Զ�#"A�����������ko���H��#��%_�$��Nh�����D{���Y@��~
p���O�3M����,��7U��s�j�*�઼���O���4z-�n��c��*��@Ը�f��աCf-�3R��j��H���)6��ωn����֕���<�j/{��Tt�Ŭ�J�@�W�A�,O
o�T���u?�����j��uqD��h���[r{��ר$ir 6KT�3e�9�4�@=���;�Yą߲E�[۞�� ��"8 ^�)�rA��g9,�#��vϹg���6������#�P0��$9]���X���w��6].�s�'��
�B���-Ro�YU�8�@�`z2�Hd1�G�-%aGޛ/�O��[�CA��}O�!�I���NN:O�8��뙸a��}�L,�]�t�O���ׇ�Ľe�%���KJ����"��*Û9-��x�T&����i�~��F��b	���own�oV·f/VC�R�y�u8�~J���$p ��@�F!:�m��o;P���9�� �������Q��:�Q���9tmp�4�	/�&���E`	�$߁Y�˸���K�Xm��3M�V!���rک�.�qU :���u��q�8�����\c�����U	��[��4y@��XS���f^��9�%qir��@^��T?��%��|��]��~�@r>�w��e�!u���qAWv��ˡ�WI|�O�"�3�H8��׼yU��w���\-�.�Y}�Aϔ�1�͔������[��W���i��6F씉��ZN�;��<�bhũ����T�G ?+��  ��P��ӥ���48�����<�8��~��޽�X/m.�%�1^8������h��wLK�8�ڜGD	�T4Q���O퓐�0�"q���9S'��3��(^ 3�� }�յ����:���^�ne���a���h�JO�8��э�^S��c�����*��i�GO�ʌ���CB2��2ze�(Rp{�0s+�@���;��:-=�^�#RT(0�Q��b4CP�I�r���a���F�������#�`,� ���M�u�_<=K�$5m�?qe��_t+�te7nm����p�
���u�"Z�0�&oBM���-p���$c����*�����`�9��S���_���Gb@��uW�|t�C=�a����M�&�g5[�hC���=W2/M��@@��#����b�.#��_����V��{�k��̾���F�@�w� S������k�%��C�@l�@
;��/����*�*��g�w��x�?Fϰc���O�AY�Q�2���RG��StTS>d�Dkx�@�*@�I�DrH�Wd�������'$e��B0u�a2r��q��s��e�l"\7�v�9��B` �j�^A���#�\���|�,���r�K3�L�J�^0�b�o.��qY��2����g}M6G�e�Z�q��B���y�W��n{���^D7�F#��A���=�=�X��Eȍ��S6��~sx����3�5bI"e��*Sʬ�r�13H����5 p���a��&a��
�2�fJS?Ϥ�2U���aNh�3�OBa������[KX���~X�ȅ�,�nv�ݗ稉�4�O�5Z���$��'Hy��m$��~D�q5���72�5��&o��۹�6�uݑ�i
���<�r���+K2�J�i􍡈��	���h��Y�ih�͇H��V����	�: �w���;*Xe�����s7�}�Q)�Ǥs�=�P�~�l����ݫ ���)�O&���;b׊_�Z8���~�B%=����Cؓd�J����pn�߾if6��zZ�I�)���Yo�1P� of��1����������l?I@9���\4�RN�≍l����[��l"У��Ҟ	�/�{�zZ@�����,!����������#y��y�`kYszc=�+�J�6��5��"��Q�@D��E�+�:�e�ֱ 4�CoB��Ii�L�Uh���>s�bU	ʡ������͛ǯ%�6f�SR��խ��1Y��+�IjhOx䢙�&��f?,�F�?4f\�{N�_�/��o3(�.�"�5��J�xC�0�c��'(�VY��R���"���w�Lƭ[G�nI��9�
�'��БA j������&ߣ/�̸�2.�?B��e�U6.]Fo	��0O�~~Ʋ:����*�Ĺd�w�ǵȶ��8�Bg��ĩH�X�=,>���܂{6�F��O�D�Rd����{ٜ� ;�����6��q��Ҿ��WH*�ͽPak�'�k󏁫F72�~�o���R�c���~�B)���*�� �n%�wӛf���ZCz�v*3�n�s��D�Q	�b�1ă/R�De�c�NR}���!=�4��B�o���;щ�4��X�xŌ���Ԝ,�}՜~���?rDv�j�����q}�9�*�Z�L��z6�f�L���Uˇ6E`�f�0!/���1쏄��D�������P�G��e��/sE�-������_�nm���c�P�e�/�,zm6�*H��m���]�x��cl	�z���l ��[���3U�z~SNG8>��EN4�\!w�Ȕzsǐ�LӸ������Y�}I���w �Ex�x��rP�@��;F eY�+��~��q�p�#�{�.��Fe؇�� ��?�	w�׿���&9L��������x6�^b������>/�ت��+�W��a�;X]�t?�O�����t�t�G�
A%eڟ6���ʵ������B8�+����Q�J5���%n�>�&p�7���-��ϣ��,�*0�)�Ĝ=,��>���q�sZ��&�`�">����S.)l����Q��0�e���ό`�>�/�*���ϧ���޾t׉I!~ ���tg�5$�2�fp؉���e���@���p�;����fY�ҫx!�qe@�>�6��wxZ�i�$�>!����S��YԎ�V5�n���S�ڶ������&�;&Z� �p������|�~�I��ou���߬:fH���{�h�� ��,���4=Ʉr�Naȫp��w�f"�\���kb��V�a���$��1��aGy�y@�F�Qu����kÍ�;��x$:�n�
?>Ġ�(�	�"���b��I��b�#c���B k�캮3S�&IY����?8tg� ��b�d�Px��N�)���f>],�|i��:���r�m�ʑ�ɝ9�7).�WW�0Z�vyG��?�fR���;���zUR1�="��$	�3z�s��Qg�%��A=Q����"N��_)0�:����Odf-7�{T&��[��Q�ʽ֭2E���g�Do��Ǎ�;B<�S~s�9�&�H��c�E�-{�%e��4q9Q/ƴ�m!Nc4�,\���ž�����T.�A ���_���o�T�+��֗���F?�����R���f���W�ԑvtB��(�8{
��G�	m�U��.��-�pQ�@(�mqG�
��j��e��!����;�������v/��4?�;��~�7�USb�+$�cڪq��|y��0B�8�����H���h"
����t^9�Rq�G��A���)���}t�4ܬ���������۠�nU��� ��H��3��kDQX.iW������Xy���3�ŗ�bz�e�2ʪU6��� ]>�o�#\���g�ޯ������n,�@(��|ĸȖuaWlG"3s0,�l�3�2I��H��1��h�������=H������U�Mq���A�Gd���Y�[��ԉ���l9�O�MО�A����H��;*V�K{4�)�-�8u�'�˹�^�c��\E���:N=�$X���?$�O|�@^��"O��.�ďd����ᇄ
���#a�1We
D�ٮ�(S��!O�G��ty!F�k�vį�
�ĝ�eLdN;!"��Y(ϫ�PpQĩ�ᒴ�~����D�˩mNJG����)�7to!�*����ReU�W��V�1    5��� ��k���_�|DL�5l�P�@��m{G��4�=p��@�D� ��H�@�B��6:��g�T���B%*�r7/�!�	�#�B�I�q��eWG��j>S/L�r+��bFz;�A(O o��Hd��m��ɖ�$�҉u�9�E��Z�i�ԚD^0�?�(d���t,ko��dq���pG0�;m�zݑ{�-J��_�)�:*]o�J�!&��:}��
��w`�UR[�o�%ѻ=��Ab��6�b2�h�yM�����������<�ށ^V�H\���K���X��ㄈꕓg��:�O_�F�hB�/��,�D�����g�w �ps��̢���w���sO���D/�Q��Ŭ�f��]�|0�'�.hkR���l|`�i�m	�����Q�q�����y
��l n��;Pκ�I�IVDTHSk�O�{j��vՆ�ܭLd��qjrKKL�$Z�z���l�n�r5dP;�3Q��?2�z�s�H.j��h̠@��p/����5"NE����X���TXr���U�m�����͹F��+�S1��7���cO!=�萳&1f��_�(�U��A�l�:��i:t�gϟ�Z�b8�Ԙj��$����~�"RĢJ��6��鿿���`�B��Vw��<���"	<�_�!ˉ7s���Y��%�"� ��<TSZGx
IT���P���s�;*Z��K��������z���HtI������
��LXD��ȱ�f�qR�WG���l@�#%?s�D�~�Z�ѱyY�.vA��mWwԩH,:0���Q��b	b�,��=�"��t���i�������^����}J�ٶ<>��ʊ��O���K�6Y��s�����k�r +R�B�b^*z�����>�<���c�ե�I�ޮ��#�.�5&���zZ�5@��9����/n��Q� Z ���|�LҴ6Za�F�'�G(�r��޶U������<b��n�v��0�P*�@|T����~v�g�'%2�j̕@�a����M.x�I��~ 7�|��L���r��V�ib6�6��6'�`�Y8%C��zm��;
�ձߎE�1>=D�d96��u���=��Ju�Ѫ��: ���������_dJt�};p恔4���U��=y���|�Ab3�C����=4_H%�ddeG����]�6� �=�,�Q�P���xQl��q�2�+��ȫ���g;g�{����V�E����'��8y\�6�Q��x���'��ӋH�E4s$LE6��N�'�r|�1JX�i�;JX�=1��+a�|��?���Σ��r�E_Ͱ5�_��x���2�S	�_ 1�{Ql�����Ȫ�7�y�vq�N���E�>o�A�(3�~들NLnE++�Շxܿ0l��	�V�+��|�@
[�Qؼ��"�~k�� .�LL�y�Ԏ���׿hD���NA��h�]��4�t��1�]ށ<�u\Z�S�ї����X���8E��b��:$ z���X���Gђ@��;��")����H�`I�#��o��|c�Pm����HYUw��nwz+�"�4JӠ�Ik���<i�9�(��������j�Q�,���<�\��sQD_w���v�l�،HV���ka��#>~}�.��F�-��C)EM¬���nc'�	'{���,�C��w]'�Ux\@��{B���#��A}��#��{��a� �Q����Ǧ�����H�G�Bcko"�3c����c#�S*�N|���F..4�f�&?��i�<a��=vWr�J�?h�ѹ�W���b��&4$�ӷFǛ�i:h�*�"в�vd^��&Z��xE�_g����x��v�E-]+��i}D�"=�k�/�?OǏ�v�<T]C���EL����$>f���^��;�j����; �*^澚u��\_��=n�����p���C?��$�ha;�n�F�d��,���ʊY.�o8!�K�{"��$�D��o���ǵk	�1#�n�p��`�2���� �H��t�6���vy[U�ʺ�ҬA��M4���J��L�'SM%e=������;��:�_-I���2��$���H�;��:_�6�(��X�3Ɨ"'�Г|Ɯϯ�ݞ7�$�H���k毻oa���\5��l� �q�@+�@hLH��c��G��[P���� f|B�g҆�f�Fsmq�f��6L�(��ډ �� �M0Q�� x��?���"�L%Nm�8�q�~����w��P�4�������W��Mz7�X1�c�Y�@��*�^�e�&�b�?��z n��W) ��1�/^�c3C�$��5� �I�G��e'��+����J'Q9��p3���d"��E��C�1�%�����A������՚<���[���4����kD*���F-�,4FvtLs=lݏߍ/�S�����{u�U�X��#�?;�e��?���Ls��w���8ͥOe�'7=|��Ԝםt{�+	�E�'�g�'J@�8t��lK�������(q�R���`���i���p��مλ����;q����]D��I-�~R-�]o����3��I���j��S|�Oh�E��հHl�@N��������,��?��[DƲq����sW������u#�V0���˯�D�9�1"��eL����u����V�k-X�gforW�sR�2��h\�Q�j����D����uOvn�pXR� ��9���4��9��#�U��ʬUh1�VTD��E1x�m��
��{��M��W�V�Q�<N�B�bl4+��7��b��;����P'>�Jj�4>P�a���Ȟl�(\�vBUI��s��!Sj�����=T�`�8�����8as?F�°�ߦ�h�ƥ�*i�DbDc��Cj87ה�|�SP¬PAKJ|p�N( ��I��um��*�^˔�^�'1.Ѯwo0Kix'7�A��]<��@kҴ���爉�����B^+l�n�CZ�G�ɣ�Y���Ȱo�j��W#��@������Vs5��sM��K(���랄D��QLy���R��A�/�#���a}��CH6��Wb���y�pFwl����{c��b����2���	}��C���M\%�,���6O�mZ����
���4p!_������A)�c��dC�*|asG�����<�J&���=����f������_�0d'�?&�jiF�1N��+�y1�k#︋�V���ν��DH�8���������, φ�gO�#r��<��P�D�(�b���]��=(}�k���&\'�%�a������f���)7��"5���~P��~i��Ic>�s�S��NWh�{Qbm�[Ag�{� �r=���'1��.���?������n/�O�"(������`��\�H�Ƣ��fԄ�`y �}{G����۽D�ȸVb��L���j�p%�'�nJ*�h��8�
y�t�4&Cv,��+���¨p����U1�U�Ɔ��(�d�ύ0b5AG.�"al�d���ʓ��u���B�e1�}2�k}�$A߸���K�x?)V;�]�����]�C���u�cϡ<�+�$��8���y�-��e���_~�B�M��_�m��䂌NlaQ�@P���J^'ތ��ŷ��0B�b�?Wy��6��M�E�ι�t��(��O�K.{lj��5�GM\�������O u��/�̧��I�F��OL7���SFןg*I`�x����G�܁�y�?�4�(�&fFڰ]���K��-������:	�Fw��EU�&�΢ǭP3������s�N��z�!�Xi arh_&~�Q��o�|[�y$g�f�vt�8�"x��V�ۤYSک�%�@��~Y$^�^��(7�Ѹ,��SpMi����޽Ϯ�����>xW��6{���x�u�ּ��o	ߎ4|�@���Yg��ˑi.�����|���ߵ�����������ϡ^���;�~`YV�*zeI.F���8B��%)�
� ���'��u$Ϩ��/���:�sKK9�zsI�PU�n��r�݁���e��.u�w�L�tZ���5�9��%�ͭ�    �ưI��ۮ�#0h�,*	�H��u[�$��	����_���^�x�+^uD�z���M29��6��s��2��oങ�^I���FJ�j�5����qՇ�;�e�	Y�5�M������gw`��I���}�E�)���R�ƅܷ�g.�?=nB��+�?�Ld6ᑋ���|��d�9�i��G_匇!����%��)oS�EHm� 4kXm��-�p��$y��3F��~�(H�r�mQi��0'�����tq�w,��H���!i@�C}�'w��u]Y�k�L�o{W#MN�9-����%���F(O����%�v��4���}ɲ�c\��<w8��T�ca��k�8۔�.{�Va��l���Z�D�t�Ge�,�tg2�!]r_�p�k�y��#tػ`������7r��K�#�u��<IcYD�3QE w�O!s ��D+H�� ��ݟ�;S��ۮ9lm����J�;J�����.Kc�!Ŋ����+��V.Юư5�}�Ts�J�# trN��e�;\�j��^ %��(q��'b=���>aī�,�A�J:���e��n��>r��lc]>:�~X|�n�
Kz�1)L_��[�q�k�?W�38p��Ƒ;q���rf�.%�� ̣�-���s�Q� G�8K� �񫥣���S���u�Y�KqL�Ua� �jHl��B!�+?D��Ν��`���A����9����Z�N��H�e
�59�H0�[ ,۴�c�e~���P��.��0���r ��RR���=�G��H�I:�N���q�Z��F٭��������C�6���H��r���2���9����k{�S)��=琙Q݉��~��{�y��D�@l-
n��j��/�@@�}�׃����^�3֙:��G\�H!.�������D'�Л�?����cݕ��qY�ŨT({)ؤ* ?7�}��PȔ���D:��N �B}�6/3�A�!j��D��P���W�W�ɨӆ��䷲s�xp�PJze&����z*5M(6+�"A𓤲�?�,��^�#�B}�N7����8/��_5h�;02�2����󿄷.7���P�(L
��G{��&C�x�,�'�&q�����k�y9xЁ4i�k�^��_��Ul����g�^:��5x��۴��L����}���� 4��5'�OhP�@���|���!�+��;��O.$/�(���f����˪u��'ը�u�x<�����Y�pI���*���	ʋv�A��������&t�@6�7x�3]̋h�O�ƚ��|�2��Xp7���Ym'"�������[n��HT�בQp���Rq�A6$���k�T��H1�B])�HM���R�D���$$��H�%�����'(�Ny����X�Y �y}�b��ʞ.�1Gݙ2'W��Q�@(��|8��kI���Y�M�A��>�tjp�h@ �n�Q�,��	�ؙ�wԩ���ƕkG��v�i�bzi�}��,�1�v�������!F�/�0�v,��Kq�[{9������_�?Gb倳QN Ѫ/�sc:5�"�zp�č�c��TH���(�=��2Q�:ޕL_w�h�?ZW
��k��pN��#��_Ԓ��{�E������k�fGƻv�b�B�M�+�")r���#l�����|)j�),@��Mui�3�/�4d��1�(�EN�ѓ��l#�+���`���[�;fe���m���+X���RX�}�^�����bE�K�y�|��ڿPčP���H�M�eZ�^L�.�'���1a���DY���/���A��%pŬY�Ǽ3㈭�'0|P�0";���*+2�Ē4����F���T\ێ�}��z��""�|��s���Ox�����Js0F2����a�t�-ߞ��E��
Xq�\"�KX��B��
Rح$�>�q{�ֻ�_|0E��m�ƽ��ŜC�p��[�W&�� X�i�FK�JU�f�2h�K�'�$�ºu��@�6l��b��''�u��Aȓ�כ�+�O�?����4j ��쎱O�Z@C��,z�33y���7`���:H5^Ggs��1�{�[灜�w��,�������˔�P���cm�����ϝ۳�,O�|({���"�.��-k䩚�1���blg`�L����n�Y��Kćp���ϲ7/�3}���Ro걆��]���{_𿾰�
���!^�2���e�\Z %^l�Y.�>�o�O����ʙK9<��ʘ7a�/V4/6�e-���I)�ꎲ�q��*�	�._Kzu�F~b܄����3G��-$9�x�j?��=�e��X�6���S�_6u�J��iК-Tj�u����"J(�Q����Q����8eVd�.#���0���2���Ph�Ŝ�W:c4�x_�h��N�`+*X����L����4��.S�Vr�m;���N����a��x��Qk����Ѭ��J�7�U kr{GE�z��d}&O�E����cĿw�4�-�_�G�Ll'\݌3^=4����|��z�,�w�Nǥ��e�Ⱦ���ɲK-w_�c�'	c�����k/��5�"3��H��(�0�Np��SW]b��m��������y[��rOHէ�����ε� $�s���L�G�F��苼%Z�!����\�'N6��L`�8��Zl���Į�+�װ�m�b�T#3J��Fʐ��9_��TV�x6������6�`/l���) �
�=���-e0;.�fc�}����~,�4��ܱ��e�O�<����/u���GXA���xR�� l���u��y@���tY�u��/]V��͠҂�}�<{ss��Z��?�~��I#���B}y�����m�]ZF���H�ʞ�'`a�t1�%�*�P>�BeV��2M��)k��E�+�y/ވ���H��%b*���]<� ����;��Q�2�^��_ͪ^V�(�E���9^�����}ϧ<�O"-�[b<'�e'%��@骦k䙸z���Y���l O���]Y����:�����vOaC!�<,^)?F}�5"I�@@�X��͒�\�T�/O��L��|(pH�����h�Xp���k���
OR�=i�2{Xj��&9�T�����%�W�͞%�֐1�_�����`��Ȑǵ�;�
�{��'l�禆�Lr�袡�~̥k.GT7�g�|0�%?]��ȓM^�Q�;x�8H���$��{VN�π^��A�רe(O��l����
��
�%�wƯ���[�k���A ;y>��q�Y���[�\]�ҵ�%Dʯ4�2�<0�#�q喎?����+��O9�[�eX��<������i\�ElD�����0�l�r���q���b~X|�baa���j��u��)����膁��.����(j���Ϊ�5�π�p,�D�A�h8�1�<����U����:Ԫc����$��ϊU#��e�<2��L��O��},�_P������ZU ՚�&Y\�9f��EK�ˑ���9��DO��M�@-�����Ȁ���%y[Xj��:	98#i��(dN{�����u:~» _���rIQ��S$O��"�7�W��Ǩ�c�'���
-����Y�x��_ %ی��IJշ	�)��8�sG�oK�4z}q�s�fs���6���%�=S�B-�.|�0ڒr>����hi�g���_�9}'��{���LDP��)�<��/�p��Xi.�d�<�!E9�s�8�f/�#FK�	��:(��J	j(~��r>���3�e^D�c^���fܙ?�����QK�n�9�@>�H=.Wԍ-.�#��k���)���[����f�9LZ�y�0-�(����'�7�4�� ��(���/o����G�RId��������*�2|�b�V�����<��b��T��rm5�t+:j>�j��a���A��Ȫگ;h£��a����Nm'�x��f}%�Vs�ռ��?�/ӑ���л_1��o>Җ�Ub���|��zHj഍�]���hY�h��cf�DI�    2{(��oi�ԥ=.�8���dM�=M�,�k�_Q^�[����G����#/͔����<<�uٲ���H\�~M$�ܖ�C�z�w�PWM�W+T�T��FU�$������L�v1C�T����eq�v`�k�Dv�8��J��b�0����F|.�xw�&�e>`�����E�jEu@/����<F�IQ�~y�
��]ȶ���(A�޻���I�6�b�����H����||/K��#VE���o���s'��<F�M#��Ca�E0��+��ea,�j>җe�$E�G�@�U�V�ѽ�_\�����a).(P���e��@e��2i}�.]����c�񶥠p�b"�i�F?Nإ�|��T��'��A��%@���T�1��=Ｔ�������P{��1YO�����KE�v
B.���_��_*�;�˪eZۛ���ׂ���p:�׷"��/Ƴ��m��k5i��</ܻ��s��XW������]�2��֘bU�=qE������5����<]��ɸ?-eC��dݣzu �v>�/�>?--�Jݳ8ۊ�����U��m{}G�a1��&գ?�[R���`��Ҏ�2���4�J����d��j �Z�S5ao?,�LRp�]ǘL�a�H�@g���j6��G5$̓<�}a���r43�ϭ�p�����p�'�G�O0�r�\�	]��|����z�GI��3 �h�׻����OC��~�"(-bUܷh.?��Ğ=����^��ĹG}��L"9KD:��/��`�I8~:�A�Aw���U55Ҝ0� ��M��@SN*�׿d�!��O�w %C��U"� �Q�O��F튇N�9Zn�~�����87h�����@���|7O����{�\n�0����oͫ�`�2�d,2�K�=�!��s��>sL`�4�L ��|7��<1ϔ2��
d��^���92�2k&Nb�����Y �SZ�]�����V�Gl��&�e}���,�2v���J9�g�5�?ͱ�@��2�[5�ͫ�􌷲�ތ�=Zy�7�@K��'q���=!�l���LL�����J�
���u��me�	V��a���P��'��	b��Nb)��]���Ų���v	��Fz��'ٍB$Q�83��c�7�z�f�]�r�L����k�x�_���ȜM�XGIY?�]��MŚ�,J�������,�u^�����>�7K:6\��v��D�T�Zܛ�C�����D)�w�}���a�j�@;M�uf�Զ�����pʿ�$I��6/���ދ�A3��?�V}+�Gs����f�����"P��D��K�G��%���$F(Jq����X0�.��B8zQA*��-~2��/yn�����p��o�8z����PZ��m:��nT�c6��)��K�m3�{�Q�uA�2\7U ��z>�]dy�1�*��4G
[٠�bM"�"�i]=�.\[�Ǫ4RO=i���Ó���
�5R�� QQ?������5ѡ<�	j���Y�[�=���#����5C��%���G<�6z1~	��8c����!�G3x��;���(G�Y1ho:���\�PYj�D
9��D/T��f����C�^�y�_��V�~,�d_����\�z��ƞ\���_s��_�����X�Lf�� ��_��i�Z���9����@�V����??(�x����ʢoP["�V3̀6�1\��V�#�}>I���� <�t���������"�ѓ��9����e�`��J߰��^Z.p*��p=XP�E9��E􆡼PX���r�{�k1����ap��z�~�Mw&6�� ���&��Ŭ�B|)�5\�en�Xz:�@ƺs����[��z�B�7j��zԆ����*��D�0jF\��#x'�'���7qT]��ʹqY��>mU7���ϓI��4�u����5#rB������b��Iy��ᇰ��m�Cgl��t{cmB���b�*[�~��W�����3>T�J�ӓ?���Ή�y�pf��#w�%�5]U�#��͋�c>pi���[E����-�
�Vw�y�V���r�qgJ̠D/-�J�bׯ2N�U��#���Ջ���޶rF#K �x��9W�Y���.B	��6����$�[���P�o��b�����Њ6���)2I��~z%����dH���:v����6��=Ǚ��K:zB���a�Y�����~/|�W��T4d��wd��f�9�L��G�ȉ� ����G#�΍+U�%sDNlvq�"xe�^��݄�L ��z�T��ӑ\����a*��hBul!)X?_`Tn��U3>�$�E�RP�@���3�2I2/���m{[��q��͉r��\ڳdm����H����Q�xq���L�h���@����e��c=�H2��"��7��ƀ ���u�]��P�Xt��������2K<7�΢����
)9!2ۀ��{ZY���Ɯ�'w)H�4��3H,�O���^��u��?)�8����UR�=hnK� 3_���}�D��Qr��X=�4�$_pU(%3�N��7��.�����ա�z��O�b���-���5w�QB����C,:m%\�_!��(�6���Ǥ��M�l��n�S�ā<ޚ��~Y.˥�pJw�_������\�xG`zmg��B���`�m�.m3A�'	l�};�HF��07�!��Z�⪫���ڻ��0�����_zOAm}����E�w8%���۽}2�X0J�y��	�d ���Fⓘ
Sh�0	��r&a��5�V��xs���R����������'�0���h�.�?(H?_���� 6�]):�2L��~�s�-����K��������v����n�`2	Ww�D����k�"���I<�[�ԁGw�]��_��n�;֯��u���q���}�Q�D&yj�< �j��xߚ��5J���nl�ʺ�-�-s�If�8]�h@�����_�le��!�N4o�}p�>���m/���P�@�����A���&���_?ڄ��S���� (~����99��L�x��
dϟ T���b�X}Q�)�W�&S������xQ�@��|�J��tV�2�LGu������-yya����v������LZ�<�_�D�1���W���.q#�sp>�]�;#��f�d��W��D֧���Z2����D"�&�l�P���8x�u�W#���֜��8D/�_���ti"a�,vbʏ|`�ߵ�����I(�O�th�L����5��L7��!j9�n�S]F&�ĊI���r����P��p��6�A�w{��������nj���!�1D҆h�iį�j��n/���k�HV�[�ː�cv˞"�tׁ�gz̕�H�O��9��~�)+�������vq��bu���U^����E�c�#������8?��b3	,�@���xUyꛐ2�ՙ\z�G	�+��j~F��OTK��Yt����!'��E Z3��"�V�a-�#@��g�t�S��є��Tf>�]UER�~���p��ɓ���|db)� �B�н�_Zz�[��w<t�j�{�$�g�5,g(/���wU�o��e�V�7Q�q���$# �gt�"y�%L^h�!=��6\��SK��A����_Gyף C�8},�ؓ���C���	ۑ�-W*ok�<����_��ۀX�<U� џ�A�x�O���
Q�>����a �!��ۿy�hk"@��2�;����r�J)� m�|��t(\�D�-@��H042&,Y.�w:��m�Ջh9V�ל�^���Ȱ��?f������8z���Ż��H���E߹���:����7pke�6�b�'u�ƅ��q�?����|��-[���8X����Hr9%H�U������{��p&���j���N�p�ũ���"�J�oȁ�\)
�ʋ�0mT)	��^͇�k��􋳈���a�9��G�?=�E��.�����K���,��gr ��лez}�TUu+E<3��	c[���u�Σ?��Ħ݁F�Va.�!YK�UO�v1�"�!�b6k��u|��Cy    ����j>H]�˺��K\�?}�"P���y_�`Xm�����b�ݩ��,|8����Y~/d�K��u��Q�EZ�g�y�>�Q�$���0!�yV
z����Q�&����2z����y/���uYTenE��b7?��ӫ���k�5��0,A�S+:�Pv�3TI ��L�O���^ �t>�]��:.��u��C�E�綘��k�|c=�80��-�E�p+<$�'������ �'�j.��?W���,��@��i�EPFڪ=PULU����@4�P�@�y�j~�⪈�bO�����G�|�����YÄ�Q�@VS=�Bi\[�G�$�<�%>�� p����#��K��쭏����� ��r|�@�]3��Y�4G�,I#�qJ����m%���W����+�'�7�(�/�����XH�=G��4JHQ�@��z~��$�D�,�192��%�����0 !.ޏ��^p6�.���f
�Q��\K�%�_#�E��_Ȫ�K���337/f�p�����>u
m�y�zj\��Q ��v~�@%�5*����9�D������Q��jJҞ�:V��<���n��]�8���7_U�����d��B�r��g
��[�ܐjB���@����&�� ���d��^ί_R�~��ԑ�%>=��L_L*w�4m	�FqI� =�'z���E;�B�@�N(������Uϔ�Y���bNX�9������s$�]3&��5a�7�lN���,�~|�0��u2���9���Ƒ(!E�s$FJ��`�(��tW+0�g����<�}�@�^:�r�J�K��$�J��eLΟ(P�ļ�8ךe�$�be��`������Uy�{ M���R5�7��7����%�x�56ֳ���΅*��_�� ,�4	������_��Y�E2�޵>�TZ�y��������6Tٺ+:�`�����P��TT:��4\J�Q�@4h�bv��8�*{���Ğ�	ns>�����1��!^XK��.�g>��0���E�$�ʦJj���Z����F��7��fz�0w��9��͇��۶�S)���d��S�5��[���k~v��wgf �(~Wghj��zD�����%y�&��H�������8m�/6O���@�N}�l�F�����o9��n��M�S'��|�]�
|9���z>j�UY������M�b/��X/z@�b����4�\n��xy�����7�7�Q��hL%��I�@΀�h`R�G���2z;���)��_�73��(Z�I�(U ���|00��,��2�U�uP�n%����:�]̚���CO��;�5����"z��B�1�\�G �e]��O��$��)R�ۉ�u�?��.דr?�"<��O�m�lyn;P�E��>T %��I�Tf)���l�fШ(�[�Υ�[�64u�Ѳ@�1yP�@�[���a�Ej�J�E��/�|dI*X|�<X�ܝ����cߺ�X�2[��o ���|�0͗��@d��<p�p�-��%}8��p�rn�W�[�qT7-���m)��G(������/�H��ؘ�Z�{쾥�9t"y��$~�F\85��|x��|1��i��c����ޣ��Hգ���BguʦU!hh|�I���0�d���D���_�!l��)z��c�A}C}A/HFhr�Yl.�g�C���U$ l/q0�C
��|�f�(�6��شHK�c͊��I�Mő���&�<�@�l���[Z4�EH���o&�r.���E��~�e�6�0Y�M� ���m��i=�dY%��4#5&��R�6e�`%�Í�)�[d��81�5ٝ@���⩲u��I;���i���OO�p����f�������G�7�G��/�>�Kv�'��]@@'%���f>���e�e�2z���G�x��E�o|�IjXsR^>�T���D�4N-�.���CG_kD������'Mt7�YnLuF�#��׭%`P��n|�0��8���r���I��u�|	����^M��n?��/sjT����(U �����i����K�o�1��8������I���O��a�}��n$VAp���i���^�;�磬�L�6�լL2�e�9R2�5�ē�M9�`UZ>���ő�����`|�@����iV�9���ɳEl�a� O6�9�4h�f~�4��8h�ٿ�Ϭ�G󍼈��
���s��dJ̍(p#s���e�D�_
w�dt����6���ۮ9ܚ�^y�6xĢ¡�+�C���������^�2�w/=m���E�~�� �;ǟL;��h>*�'E��ZE��ĈW�	����0��لy�a@'�,��e�br��G=�lY{>��� �E�>I�Yܰ���S��n]�Cn����:��De3���,��b}���/�&��*2@`����Ǿ��AS�+!SR�Zd�38;�q�2�Z;͋���IG��C3�NK�i��U&oE��a�o�|�-��$�+-�ܻ���LqCu������h�=- &6�N8HJ+�-dU���=�H���lL�]
�n� ���O�8�7͜�)�����]�.�HY���\ǵ]�E&���I"�9&0���EE�IA(���A���d���ڊ���,�>^ԥ�>.*��hGI'��!��4��0��9
��,�v>W���O����9�A�\x���uGbB����	���^�ͳ<b=@�-�ሹ7����v}e�����-���@�|4��]��e}�}���ē켭���c���ܩ�����6?ę=̹���F0��uD��G����S�V�H�a�`�2d��	�[��AE�&%� �M��E ��v>�WTI6��u�J�!�Yz��f���.ψQ��y��	�L�`y�¿
�d<�·ꊺXfֶ�`�]�Ԟ��BTe�5��{�"ڢ��?آ}��t��)�p��Wd�͇��e���V��W��j�^b&c�_�*�
ˊ���3f�} kl>JW&i��}e}��O!4�m�˵xi{Q�ժk��-+nIt��V���͏A!���n>�V��d��2�>w��" ���W*��#���	�q3�i�M%�a�`J�2�W�|L�̗I���=`��8c�ݠ�yܗ���h��xd��
�Cb>W��87x��#l6�z
K=������_�&�;ָ�\�З��:J\(N?��G�K�%K��,�<���O�r� �P�����Q��,��o�"z�_���o)��	��u�&��@-�8�<}���Pa�k;�+k�X�`�lD�ې�����f���Y����Jd���s|����g�·��e���\�&EX�#@7 ��v�>,%	a�Q<!�X
qQ�@F���]��ﲎ��\;�?m���ev��l���o����Z��Ս
�+�<��|;I�:����w>_n!�|w'�j�;������o5!yO��κ s�iڵ�L%����lj�ރi��S��( ǟ���܏`�V����O�����;�04���!�/-��m+?���J.�:d���6�	��]�|0b�<q�|8�h�6��D�������
d��GQ�4M2�Q�e�= 6u�Ñ���g;��;�DU�=@�@s�SW�=3��LZ%X��x�5�L�T���w�ٿwv��m;�y�0|�@j<E����ڙ*��&t���Lʑ�(Q�gs�aI�<LO�4F��@���@hUfi�7d��x�J�������M�,i� 8A0�u+pFQ�@҇��!Ϫ����*��+�)K�uCw����͗��J�Λ�p��$��z�G���)te,��Qω.+�ͅ�bJ���^�1ƮV����b)CR�� Up:�b��g�j�M��#<N[��1�w-��ڋ��dx��j��2ό[��:� +V��(~8U?AE��!��G2�ދV�*�vaB��C�hƳ,��o���&º�L|�)�\�?8�� ��
ħl���zY��̪�����U5���)=�5���ۮ��2��X�cx�B���o�(d=����x謕������t�Tꦄ�V��U 
��|��Γ:�+���/�K�1ϗ    ^���V�[�\mjh���:�:m�S���S�D_9s�v ,�w4b���6n`�=,^]5�e�`��U��U.��uQe�]�u��,V��Ŝ��������S���(��qȺ�G˗:�ޟ܉�l�q��a����aW��:r,�C?Z+�Ha8���������IԹ[8�'�����W��@����"�)��x>��4�t����{>��	b �.bTDQ昷����Yyi��WP&�؈��'����ɩ�n��LG����F�x6AbDs�4#rڞ�K5�j�������u�)��"߀��0���0��O�����p{�[ܡ����xf�-.��
���ݹ�͢�#�,�����m�����f ����.����$���N��{�5?��b��P	�:5l���֫��[�"�a��f�Y<C���>���d,vi�%܏����Swt�C0�w0+�-Bf�-�8��ٟ���_V�Z���UBJ���Iik�=���_r�̍��jM�T�~�ƋS�ɞ;1�%i�@S�Wb�D)4�^�_e� �
_���U0���5ϊ��g�z���l`P=$hz���0�y�@�t>I'~�]����2��犷���o)��D�#���}��
��gJ���J�:�
�!F7�F��(��q; S�b�2��8/�d��9¿uŤX��ZK�DA�@
Z�/h�֩o�k��ljH�9��1���7�ٝ(OHy���)�8W8 _�zx8��<��Ű'�}�Ȑޱ� 1t`p{�;[�Xr���V%n�X�����pf��ɳ�=騧f�$Ǿ���b2�(��[3�nfV�d�7��Y�m������+E�ݓ(�a]G�،�'�t�Nw�y/����)�jv��x��`=_���A͢i`οlE���Q�d�ϕY��d��t��Z�>��}�+#9� ���:�W׎�ILZx�~t_��b�Ү�6I����,�BcmW>Y�
��LR���]�*,��<N�~ӧ�������e]UV�<z.ԮEl�ϖh�
�2�{� ���*�@�,�Et�j�+u� �r_"���/]���/���W:yI`��!�u|@�&	����_���2_ăb�X�
�
g<^�A��@x:����@��kĀ����D5R�vj�Q�"��U-��������@Kʵ���q��z'?�$FU�=��tMdC�;bs%���&�P����T/�_�:+�N,_�����׫�\���H��� ^m��Ƴ�JfW��>��x�q㗉��7
r�|X|��U�P5Te�}�H ?���$~;�A<@��wBY�@�m:�������S���`�3�(��V�i��}k��\J�O���3c�d��R��*|��@v��Ųh0ܦ���B�5P�K�D��LkQ�@^�|�.���t;y����3Uֱ[ws  w���3�d��"��1�,z=�$��n���ˮ��ߙ�d�>�px�A��s��K��cpI�y�G_8��%�p%����&y��^(�����w �3~>"��YZ��J��V��~VӹV�h#��RnT%d�͇��eYی?���I�IV��p�Ubj�F�+n�b`��t?P�@�|�-M�26�"��O����P�U���y�r.����P �j>L��E���Q�Nԋc(�����k"�S�@�a���s�-��ș4�Bj����E����b ��Z���;�J &�	�ׁ�P󱮴��� �$�F��ڪB�KK�F �=��5и^��R����m�@X�e �r>ޕ��x�'I�c&x�t?�>��|��R���bjn3{��}�*�+>F ��|P,��Ԥ�y���n�*�Wed�\�:nL14�"C�a�0g���Kz�&Tu\'�t��||,[�V�$�7�Z����k��^`�L�V�n�lA�d�%kJ�9�Z }~=��6�}��M^�����]����@�@t�FEq�����X�.��pE��;��݋�1�s̫Y`H"H���P�L�4�~�H����HW��ib���D&g��mQ���D�l0�(+�&��Jn|R���8ԭ�B��c]Y���_e�Z��I������ŗ����U�_v��A�$$ȁ[t��%� aE��2�����ʗ�ۭ�?��ASU�Z$��� �A�SM�h1�J9��F��B��ی)q�Cr'��Ͱ���������TXI�Wԕ�L�6`�NTn�����$��˂��2��#f��(��K���ح���s/`D#\ ��\�N��\X���J{�9��w�e��U�F��;�����>�{�,�l�)�~]&�j����o�NJ�jr�{='U����0dG�ꂲŁ\��a�<�ݯoeK#P�m@�݁?��B�$�{�p���n�O���|����������ŗ�hF<�}	M)�	�\��/b�b�t>�@�����#�a��oO4G���ڃq��7����B�z�F���f�Ow�/�KaR�����`��ݵ���S��#G�o	$�ȓ�e��/;�6h|A��I���ӭL�&r�ꏯ5��$��q>�����7�i=a{R� 1r�<k֗5n�r��2�"��`3��u�~J`z�	�
�]��ݎ=���ų롡P�`�&�-t�als<_J�������~Q5M�w�i����Ů!a؝����SW��d���0���M��:��c>Q��Г���D�2��������h�Hnq�@u$���>\��>u'z���kFcc���{���2P=�2L�n˺���ꀐ��{�|��/�֙*��'��3���|�8wm���E�(Ҙ�/�-��z��JS���l���q^�u�TF_5�w����N��$tuM�7��z�#������,m�T��4��}�@�89.�y�:V���
ċ��CG�Y\�U�a�n�hh�4#P�lL/]4p����[��w���g�&��-�O<����&(5�����N�H�g1؉B�j棝EV�=!�8z?, �f��*$�d+��+�k)���K�b������˒e��B��Ze�@J9-��e��Y=�^rj�+I�Z��� �S�>���x��'�h��q���M�B�iX�g������%8����J\�O�U�1#�U6��%W�m͗�w't��K��(HG�����MO�5�����ϡY!>4�Fxe��6����fl�ԛK�4;s?�<r��ʶ��L_	������B�\C৐�r��နX�m���E�Y�\���2qk�Ӆw�ɳ4z�En���,�u��4���7P�O_�ϭL@�z�vɣn�(h���4l!�D-ˢ�>��G�-Sq-DH��AxU��)� j��&�Փ{G�-��zj����{�@ނ�|к\.˥_�y�C%9�vnG��Ŷ�ٛ ����1��ٮf!L�}a|�:�
t2�ߠ=�s��i�;
\�^\�S ���4˕t�/"��o�n����7�}�+��]3�.������̨y?p��&���u�J ӹ���*e����^)�uu���p�nz&n���9$�Ah���_Dfo�0�F�e����� t�,��o�:z�\�pU��~�[a/N�,~�F�EʽjVPe�:e�Ψ` �����������=�.��92�K���޼�iۺ�V����b�CG[X����GG;7�Te�>7G��P��;*[f��lIf�}5Z���F qj?MXU������]�2ꒆ�PEyQ���X�4�t�/�j���4�=_&!P\cQ�O�b1X��z�.�moyE��h�(m����.�AF)�Hc-)l~�s������1E�)��g@_ ���1������΃��@�@k�'���n�=�n|��:�n�Kv��Q�M�쾟�\1޴�����>����5�rt̯Y���%+��"�NS?8�az3��J�1kv�5��6w,Z׈����G�bq�"��n�]W$���b������U���i��Go�,�.y}V'8a�J��M�9���x=a����!�~	�򨫵'����0����C�i�����aޒ��`�\�g7u    �턩�ȳ[�����~XS�ds#����IA���6���>�C7h{&���p"50�s=�8Dl{ib��oW46tݨ�x�����d�/a�WP�(I_߆v�)���@�������L�G<�lXόE��)_�x�񟺼( )Vwt�0s5�[!�}Vw��jyG%�ll*��˺3��y���QU)�����w�U��pb@#{�gs�����"�	�/F���?Z(���5RF��(���N���)�S�\��ō����	�(Y ��䎒��ї��앢A�&J2���C�&FR23lVh��g�i�2�a���NJ�{���PϡƁ�W��XzVb^G�C."<�����V�u�e8���_�0/ب:�s��}���(b�Q��Q�,�:�b}� 7b��G_����n���g�h��@�ԫ;p����j���f�rxpg����yq�t4{��}���L"�P�@juD]&����~f��Ԅ>�KB����GN�,�Qf�q��f�Q������0Ӣ0��D�NKX)��A-z����/���{/���/��c���ۏ�T��bg@���H�.:�1W��H���ww�+ ����>��n���
�f�-L�Q�PDT.��RC����/ӄ;%_{N�$q�Jq��y��"I���$�,��u:��A��z�c#�����<1�q�F���n�bJ�:� 1K�:�v�i��;?�6AI���3�"���i�;:s_J<��c��/؎U��d��h9>e��\&�@��;�U⓾�"���4tϒ}���z��0���0Y �;�U^�0E�(|��M ��{��p7c֌�0(-�&�B(�(��H�+E�9��T�����/��%��}ޟl�	��x#2���!S|e%!:��^ڙ"��x� �NJ��U�?�o�P�3�l��3�)c+�h��%de݁8�E���:�ML�	�y���4i��S�4U �h���A�2#��q�x͒k�\/F$����=j��5�n~��&���(!LG΢�ah��P�@�NV���j�-+{m�q�[�J,]��6�Dg��	�8D��@l���;��1F�$ze�$�融z�A��{ѭ���
FO��rVq���^����D�JV��aI��wy�Դ���ܫdX��rVIZ�fM����B��o�N�p���pсr�gc����&�:h�I�Ҏ��Gzڋ2o��|0�Jˤ2&Q�G�Ye:�/�W�m��"ʓ�	d���PV��SD��\qM��!�4w��PD����',w�~f���ĴV�a��^d|QKrp�*?�퍹��t�G��K4��29$C~�G#��0MaN����y���i��`�r�ێoĜ��iX�%�I�1`,k�������$@L�1I\�Cb��ٕ�1>Y��� �M�Szo� }%�.TP#,I&�����\��9�@=��3��l,�Ǩ>JC����A^�G��"O�۫,�Wz�AG�^p7�5�nr��s�����)8kK@��i4&&X��Q�������d�L�9�E�\I�A窬�ߴ��o��$�'��$�Ԣ\��Y�4�0��
�_+��͇9�:���e�1iL��B-�4�g��c��+�ɲ�����[χ3�e�xg�
.��a��XSa��Ѹ�����Ӄ��O�����!��*�<�4����H
RR�|��)���\���y��_<��'���k%Qr�9��g��M�������]��9�)+�3�uW�8�O����М��4�R�0���t�ٸ0�ݿ�Gכǯ٧v�7�A�;�:�Y��qځ�������� Ɂ�X��E�����>>uK8[��||�N�ڻ!UqD��D��+��xMQ	�u4�׹�s���H�׿PB���z�gQ)r->`�R���t�����w<�C=J�d�Ɓ��!�:O/H��I�B�0'}?O���xn�$�_����I�2�Ui�8��""�Z"N\χ��ȗ�eU'"�V	��*D ��k���hQ�@���0s]�㣰ʣ���d7m턿wr8)}��#�`�,g�����U	Mʗ�Y�C�u]$^Rѫ�Em_�TB���拏��E�f��Oܙ���f�����8�xYf�(We$n])������<8�G�2%�+H�BwynN��5x�
��Y�/\���?ҪH�'�]oD�۶��L\�j��e" ��LC��(] �x~�Ҫ𓍪��U�Eyi�w��W�)��-;4�r�wROO���]>_O���G�����A]Qn��u���/��׌��Q�Il�&�j\���꠬߭џ�ؙ`co|���_�+ �U ��M:���}�WG��x�ޘk��S�r�)K6�,��_�$��6�J��@�;�ܶ ��wX7�+T����acZQ������`5An�!������痳�*o-]��ӥ��g�gT[YM�� �I9؊ٕq�ri��:���9�ﮉ+�s }��n`��'6&-F]3
ȹ��{~Sίa����j�G�!��a�d|R�LG$8�h�h��Y'�񍷈�4���\���s?��/2���M�v�h�,�j~aӪ�L�Q�W��e�d"T�k��~�bB��l���_$1�_&����UD����W����e��W�
�P���-�����r�t(�����bHTbu�i����ʟ�U���vbI+�}ذ��@oPc�ҽl�Q�u C��j~�\��'V]G��^HA�"P���(J��[�nL�z�1`7H'����ed0�Y�/c]�������^��0T�	�rOo�-t
3�f@�s�� �4>D ��̮T/k���/$/�	:[�`=y"
L?O3Ҁ�b�:sg��0�������X�i�/�
�o*�IĬI�K��`ŌZT�Fb����i*>@ ��|�.I�*�-��*�� Ekۺ�f�˓�J]�!,���8�E�Q��A�$O�ʗ)�>�W��W��b�G{�����-W�0^��| .)��>ˣ��$���	�n����U=|${��~��<��(\��8���[R-+��+����Xxc��

�_���N��Rȶ���%u��`��,ӆ���Ba�0�Z�3Z��?�{�v;�A?=-�9�Y�G���A�#k����
X��}4�QN�<�G��?:.6����Pj��|�@��|�,M2�5T,��
޿L��K!>���5�X���m����K�
��o�i)�/:�+�kR�Wڣy6��AH����BTX�W�9�l�D��(�gy��,|�@��|L-u�EZ[%c�\{�!$�ĸ=��]�|� ����V��.mҦ�A�O�5:3K�"�;6N�/�������7꿄�GK/��I��9#����K��P�@�<�|�,�p)X���;��������sq����ٕn=xr��댴�я�&߹_�	F�R�@�
�|-���❊8�"�����nx�#&X*��2��@��Cs�<7�1B����38R�X��g��P�@��|�-[֥e�q��s�[�	���Ķ�S'x��k�0׃.�T�p�؟��1�,��X�
w)W�ȫ�"u���Uӂ��Ӌ�u�O�
������\�_�CCyx��߲��
F����	�|h^ M���=0� �NV�y1X��o�cn���S��^!q �O�|8.˓�ҷ7U�ʂG�d�5�ӞiYk0}c<�����c�.�S;�ˊ</�:�m\�:`��a���E�j�E�C�
����G鲲6&]�,#Z�m���◷�4䞜��	h��;�`��+dΰ��euR��o��ї�J^�uo��6�l�>�/�i�<j,鶲�S�.Y��$���$�9����k�{ Y����d���CI���p_���`L	�0\yt��@Öh���R��`]>-��^�S���Ahs!�M?�j'r��О�13'a��%��ǳ���1${�#��8��d9�s7D�����֡&V����`��-_���� ac	����k)?Q�9	Ą`9��Ӭ�k�E���y����V���    ���kx6�p���n���,1�%�X�-ǃ~��`�A��P��K`�i&�j��n�,�ܮ� ���z����#	{MOPp�P�@���`^$U��馏����!�:�ɬ����
�,WX<�,�����G�6��y�1�,�#�yYNk���#,?� �|�UƖ�9��4�5�8ͷd}�a�Ѝ�:Ib_+�g����[�����?>�n�-a��_j��lAi���Gu�]i*a9F�o5�KF�1/[���i9� uRG��,X�e�3Ro�WӗH W�x��5dYnG:�>/�2ȊŬu�Ѧ;�����'���s'~b�R��p^��ef{�4vǙ�e�iR�zˑ��[7bϒ��b���X�rr�������~i�u��x�N�#�"�(Io�r0��������y//����x���㑻�@N�U���δ��Z7�����b19^�����*�s��D�Ḣ���X)�e�WC1����Xq`T.�&�xI>�2|�������3��6LH�+|:Գ���U���X���*�S�_��{%F�?x�Z�{��m�=G�f��X]QOݕ`*�G3�q���mV�
�#d��	*T|x��"�����;�?�.N�:�	���%����e�\��Ʉ��L�ݑ������� �&Xm�=������M��}�t��)6��'B�%�x��f�_0�V�8�wT%�����W��V�s��S��!Pb������͝D���k�%E�e�iË�������8�M�?!��H��x���|�S�\�B�l9�4�u�F�l:�+�*�"�b�J��s#�i^��I�1�Scq�b?I�	V�]�$O�no��%!\�o��4%Q�@�GG.�3>\Ve�h��f�'y.�\]��	�J;��d������(P���b��@^�� ��$9Q���bi�&.e�ĖC��L��`\���:\��6|x^y-�;��_�dI�~�}��m��hp�����OE�Jѹ����ݣH��;�V�9Qdi�q��ܝIZw/�Hpo}a��s��R����m�����èA�i]���"�k�4���l:�,��.���E�	<
H~�(?TwZt2�-\K��^��n��dx(��Ҹ�wT��z�@�G�< �|��Y2�ԧ���(��~�ԧ�+1:���<e��2�!�EVDo��������%��&����Y������?`��TE�
��R��EKk�2���	al�~�����a���y��l�:�{4盄!_�?���2R��(ZY[H|�!��ߚ�B��b56~���I�lmt�Wi��UR@8e��i�Y\y�$�Ͷ�����67��� >�`�K��X�C�y��;����y˧�$�� ��Zۉw�I����_4��ӫ�YZ�Q�zZڋ��ѷf���=����uWFA�(I<�,�$5w�"O��Ʌ�L����[�|�b�*/��z�!�ȸK���n�gG�01���_�0�{�|�9��\�MO�e�r�iLmp��g�t�}���ع��Z��;5� �3�@��$nz��H�p�^Fb�	��F>��I��mn~����]�D?�S�9��B�+ɋ�W��9	`�e�L!�b����I,�^�����t�C!N_ ��p���m�Y�L���a�M&��na�� 5	C՜��X&*ad� ϓ@^�;pݼ���g��ĵ���=��Z��\WY����^�8DÐ��H���;��".�X=�ݳ�hH�3BCN�gڸ���7wJ���G[��l��;p]�˕6��Eԇ�h��y:"K�h�N�o���q��@a��f�pnQ��H#w���(39��]s��ҍ���a�����$<����ыf�ر	>�����U�6xr�c�}�yCI�v�NN�PxGT�]@�:�*z�ɓp0�Ƥ�c������Q�̓�ע����	��;���V� �[�'2R�1�����>�����{���	��a��o����{w��eⱟ��^�N�I�� ͐`�%����/٧)��Goe%�F����&L�<��3��u}ql�P^G�Ѹ�.�i�yH=�ٽT;l�?Z����=Ϟ79�}^r�݁ޖU�E��4z�7�s����L݂b���$��OpɔD�>�F�^�ߒ���$��� �J��/`}޷zE�)����쓌���a#2�>y-�����k��[}����MGe{��ʐ�٘ɘ���\��� �.]{c�uj�&G;�>t8��a�m&�h�[sS4�6R��WE|ZD8��<��X}� C:�{��Ѷu��-`�J�Mx9�A�/�QܸofNh� �'�0q~4�S�B�L,�K�<#���L_�r$ށ�We�X#\@������f���#�b��|@4�m�{��N���:�����N���V��TQ���eA�c��#b7"�:��z�(�%��@z*^��� �"�|��l\w���z���^\���3��p��Q���ZH������V������U0<$1�a���?��P� �ݹ1c�M�����/hA*\X�쫍���c��uV�""��Թg�`X5��A�o隤~u+���2yC�2^�Q�"N�YF���Ր���]8�$����x%�޸9�vmq2��Luf�zEQ�S%���ZB���1����O�-F�%��r��/2��v@����&�(��x4�r�_f¢�eB99W��;H^3-���9�ovغ"1���Ԯ_�>��{ky���D�>�0��l<p��R��r��v��P��\ln�~��W����o�Jش.g@æ����邶�Y��Hz�s-���1���r�&�4�ʦ�L;U8P�t��Y`�5=*��*'w��y���%���n�뷸�S�1N*t|F����c�+�H��;d�}�yV�S b���] �~�=Kh���i�v��'e��-��5�8 j�L�� �=,����{�*�ޏP0�x��!q���݀��#"��J�[�mԎ��(\ºo��JKG?�mP;l&aq����
>%�5_�.Jj�~�E��QQ9}��M��ǖ8����6��3�����C�9K�;�b7(� X��+Hyl�Q��tY�ra@4 ����r��=~?T���3y�č."D7WE骿<b f��ku���kA��5!��Q�Ϣy#;u�]�Ը׃ܲ2�!��(j^�i�Mߵ��jq�K�4�� �VF�ɏF�} ~����� �w��.-*�(a#�M\6�������N>I9��o=�4-+����[������ �w�;����c�0�6Yf��g��*��??E�^�ą�þ�p65ȏ�����F5�H�(�2�(Z ;�d�r�ʦ��e�e$VA*��̤_��Mis�f�J��5w'K����ך��W��w�i:�r�A�T
	N�dƺnN�_��-$�~lC\U��ء��e �쎚�Y�kZ�� 衻���bjD�yB��_��8Y7���f��j2�'�A�*��TᢚFONt��<%�1y鮽8�,x��i�J�R�$3Y�Q���s�\o��+�1��K�75��Y&w`�y�Z^cQ�{~���5�� ا6�g�t��U��\��*�'�+/����W@|���n�g�,t����uî�y��K���{�x�|b���6^qJ7���(]۲t��1b���� �	aŶ�8
9?�N�\��^𭠶��r?�u��e�?Fh͠}t?<f�ތLXi�����-|�?�5��h,??�$n���Rv��i ��/���|o��4��`�^���FT�A�3��"�J¸ �;��*��2�Vu���:�ٳYq��m�^JX9��-N��@����+>:��alܒ�5��0���u��@c�wUy�[?�n�T=_SD��ǫ@���趜��U�����D��X#:(����L,'�Y,�:!�,�|�] +����LKVe�ɀ�>��j�Se�dsO�g�m�'Q��!�9��3*��2�c,��S�+7Aa��ZI���[fr v�+����i]����X��U���vL�    ��E-9����8���U�R�i�^[w��#�K�n.tp}��B�N�_�@��P�*z&v=�>��3��RW	�ʄIH���@�s�<6�2�២��w`�U������ע/����o� � g	$�?y��>^�;N]�=I��VS#��n��^EY�>�@��; �:�=1�N�Q������<�;�1F��-�%�s�
����������'����fȃzrY�^Ӫ�jܚdK�1����m�tmy
�P��(�E��Ʈ"7o~�A9��Q"Q����R򲄓����Wa��sÒp���"��8w`�`�T�~V/�w�\����a�Lƽ�)N��A�����|`�%�ٛ�6G�����Y����W|�a`���X&�?⾨�`%�o�Jv�]w��4�Xb���x��f���Iw�~MO��v�*�R*��@�s��0r=�clRg���vg�L*ܢ�bϽ�;9�c����*�@A5�h�΋?��T��Eԇ��2���(h�f+h}�=�l������ukNh��w����:��o~G���j*�o�pKt��F:�Rp�ѵ8ڠ��}]�C��N��Z��Q�Cȵ{;�sz]F�E��6 Y��A�oƷP��,�Z��-�t�������.m��Q����*zC�P��S����_���o �z�l�	O���[�Q�������zq.�.��<#��|!Z�3x�~�/,��#���v�����f�;��4�$Mt;�/4���7�B]�67w��s�/�yRZ�nu{OL�7[�O�Q�<���t���uqv�"����f3����`�Nø��>p^�\N3~�68��:l ~b�ñ�
Ͼ�-��Xqd�����D9ͣ���G���N�m��=#��ݜ/|�����#�i4,Сl��f�xH���$�~��Pg�qS���B� �~̃�
գ^�P���z����i�;��vO�bkxlu�e{IL�dC��s�B��U���z����<����VA��:6;�Wɧq��
˝��;���K���v�}�`�r��%�&1���$��*�{����ER�V�:�(��ɪ9��W�g�|�I�cz�k����b�����W�����������E��h�-�]a9��@0����fGP諚PӨ��� #y����:p��5�{�, }�<h��Q&HV�����#��He4��A�ɡ��7b/�,�Ko�ǌ��0ݏ��usw����u�4ʳ�Z�Mẁ�GQ����_޺�H�������R��q�c�ޥO�S� � ؔ�೻7w������&��འ�B'<����@��;Р����$�C�A|�%�>u��p�|�ЂҌ��cd�U
��?5�,r�߁�Il�R�F����Wtq�x�KC�OW���,�R���?���˝;*��⬮A��t�>�z����´3D��A�w4��'��y<���x���k2��ZO_������)wD�����z�)�y���{�"������KOo߈)����`�B�B�������<xD_�{ւF�Vw����/0-$��ta1��Teo$˩9�f/	 �U�'�U]fPr<Ɓ�l�; ��4��2΢�t�Ob�(�"��o�:s2�UE�9T
�rZ���^i ���]5�S����ʣ���.=�SW{X�\���CU���Sw)��� ¨[~PWeYl@]\Do{Y�y B�:X#����F�u�sl�*�Y~W��ᤌKА�u�7��c�H��lR �)�"�1��w��qڟZU�-�!�֖ 5�=X�4SE�5��*KWDÕֹo���������G��(�e�$�Y5 �&��!`���Ub�V�,��C��Ev��b�T��1B&ײ��ݑ�gN���ɕ��ӝ�t&o٪o'^���ײ�����5�-���/"�N]��q�-�[~�83�/�\�t�wx<����._�s�S�0'x08�f�͕�1���	nb4����tx��*��~��E<_��t���yb�m21g�`����f�ʍ���������_�H}���Ic#f��"z�Xe~�� ݤūMa��g^���%�+�eE埠$z���'(�6���@^�Gq�R[�/t�|!�o9Ƣv��R�;.���6I�؀�@�`�2W�e���I�5����Ѕ�\I ��Ɨ�uMf:P&Y���-+�Q]gK7��4?1l��HȆ�,ܔzJ�M��x����C
��������<-����`�ɜpojf��6�X5�Ĕe�TM;��
�,�W��⩵tI�����~���y�*�J19׭z���`Iꛨ<���Ԑ�T�]�xZ'��b=���q����e�ހb3#=�wa�z
0�������������u���r
���mN�-?�a�Du'%���!�Cm�@�z|m�:M��ZG���F����E�Kom�	O��g�묻��9̚jV�<5�k��S�<���˅QG��d~�0c!D�͚<�7�So;n~���κ�P�P����beu^�&�����9unZ}�ޚ<�!t"��"�WWT�|���T��P��zD�6_��.�ԙ��A}�(�X"o[�[�!HR��g��B����
gÅ�@ٰ���-��I6�:�^9׶�bؿ9���!(
�>Ch�p<L^��,$*����d���_�RAմEJ��@�/@�y$�m���2������Ir뫳7�	4�-�Z�jf��Ա���<8$x��@^���Ǫ�&[K���N6inh�{2�8��'C<|G�"%��_��;Ǘi�p��_�)[�%�b+�K�%��[��K�Ns��<��蕫�)O������NdVzf�W���KFv�,�/ǣ�����2-��ܸj&i�F�N�S�Ђ�0�ET�G�z�$���a��xD1��*5�UZFO��-���kY�sc�p^"�f�������+�x}�m9�>����
+��!g�j\R��d��U�/�*z�ϖ�ϛxv�w��c�gQ	��l�|��@���8d�feߏ��7�|,V�Ԍkt6��Tԏ/:��"���^�L�������R���K���0Zsŀ�:ȣ#��5N�aROj|�#�<.�z����
�v(�q��_�=�e�뮄&G_�Z?	�ŭ�W��c�����
�����`���-|]HΘ%�9���#�������bH���h��y�+#q����G<�U o�x8ɲ|jOk�FT��5WU��82�8BQ�:�����&y��ֳdq�$�N�dl3��έjD�2��sOR7{�8�N^����hn�O�)�������n(���yG��?
��du�u���6���^١�����NT�jk1f��W�R��<4��p$ј���;�cK�-�)I�@wphd9x�}��]����SC��y�,0�9�c�q���<��<m�q��R1+�<h!5�Hb07v�~��P�.b"���R#L����z��xs�YݶFk��j�=݁�u<�_.3)K�7��D�b	�����,�^�G�=D(�]Ij[�8�h��o�X6g��Q�@��r<<�T��۲�w�����^���#���O�1ǰ�E��y�n�o\iɬ����xOѴ�[S���������^��N�V,�������S[��!����o��_�H�ɣZ�Kٜ��M�n%eKm��*�
 �z�M^�@+��7 ϶0����ߡ�k�]l0�n�<n0;��Jx�����ݎ]G�	V4�E����h-�o%�:�� ����m�Z8RH��=���2"�f=�sV��.��O��׻^�cu�4��bmګ�ځ�>�n�+��9��<�^��P�q���e�+�����f�#|�ݻ �]tDz�AGͿ��ڜ�pjc��Z� n��k���Q� ���λ�=���X�}�nN���J�Ճ_ܖ�<�$���#���֑`��0�f��'�NKϔ�
�Kˌ�GC�d�Q�e.lD�����	���Q��*��Q��P��3CGOg7�����%q�����T��z���l��.��_�<ivƯ~�8���٩"5,`4��Z�����_���]JȺ�\�Q����\[G�?(��86�UîP�P    &��;�4Ɋ�&�|�c�f.�I�4�M��ND=��>C8�0`�M���ZՁ���i:-�T����(0������\���A\�u	L��/�Fݷ��?���s�&�j
f���,V�;�[����y�҈ŅL7��JH7|�M@k��D+Sڡ:�Ɯ�\�yV��t�Y{T9O�/��fp"����{�|�=�
�4�Q�ks7J�PI �J�(T�X���d~o�&�*��ׅ�k��B�����IM{�z�2JơW�_X�yj��e�{Ą�DZ o�}*�̞�z����3�A 3Xx�=؝�j��g��q��S�iˋ^sޜ|*�P��ȉcR@=�V���h�Wzk�Yd�m�$5�j�����"���2��]ȫ���ͩ��9 �!F�c���Y�,�:,�ɠ*�(X������7v�f��E�HO�ٸ�e�C���U1+N�=X=3�vOv����$ňN��j��\��@�y���i��f�_��5hr5cr����z YB�4pJit�ä�||��v�(�>$%d���;JX��-�H(T�@�u6�R�b��Є$p&������V+{�n c7낭� 0��r�ށ��Y�T ^��FC�Ρ�B�K���bQ&a�$������:憺+��o<0�M���4�&\�Ӻ�|�SB�^���JzZP%�{ۭ�;���g����JEȋ<��fE�"Rd��⬾�]xm�j���g�^E�y�ƣnY�/���>��!��e�L2߫�D�x�rO�d6��msn�W����.>�@���RV�����5�r�iT���[c�!�P��(O(�x�.KҼ�ޭ(�7�ӹ����fE}����1%��΍(N �=��8U��;��d����bq8CV��YU��n�a(*�0Z�z<���Yj�	eQGo�>�����h�j���ϼWI��l�W*i���Z�M��
UN#ظ��h�@��sy�W]l~lzd�6T�M����F�����ti5�ǵ��a ��Q�"�2�ޣ��mI�p����X/�00�Ī�xVր��Z���i/ܾsqO���l�Y ��xt-��n�bI�Qu�lB�h��e 2�:��U�Y�%zxv�X�om#*�aeG�<[��(�����<�XT7��s<<���қ��Y��r4uV�c�z�qI����|��Oo���ӹݶ��o��[��1�dwT52V=Os5--��,��#m��M�u*M�,2:�̚���_�pa�:k�$�������Q�?�fk�!����,�ꎒ�����1���D(iv�9�&@}��h�Ғ�u�l�L�Z�F�F�2�`IF��i���bçH�<�˪$�z���^��1!�&���PDr�5��,�}�^�ȉR�������Ů��>�$+,�@�
 
q��^\gm�� ��~e
D�U߁��Y�7�e}~�gY�����4�mn��!���72:���y�^J졷
��F���j{���?�%�lv��E���Z���,�l
+�?�E�TmS���/'�4È�?#�P��k/;��$2���i@��^VCd��;󈞹Y���F�4���͟}����:�?\n����k��(���� ��Y�P�Bͣ�D0|�A(mN�v�C��
ܐy�':G�z<ڙO�G��hA�����f��q�:(K V%�⎲S/����bMC�\��FEdH n�u9fq�գM	}���lI	�Q?����<�3�lS%ѷ�� �dI��`*6B�<hI�d�Ofp���0A&�V�F泘��c��Y�#DM9����p�+Y ���d��T��N\tw�d�`�${��SG2ј[<Sf��rK5থ��ZZ~��zU��@�Z�L?{Ϛ�g�}ۏ��C��β��C
�"������;�����3&�@�a��G��K�H��B4�����sУ����!�S�0(�)R�&���b����r���?��&�x�.:��h�fç�7��z�b#�&�"B(��ք��Y7R|p"��UV�D�F�;ŧ`��{�n���Ti��-�HH�҇�n ��ϩEe��aN��O��}�@��b�� Ɩ��Ʊ�<��X�i 4��0��f<v�'0Z��0�^S0�D�A���v�� �ع��?����#��@E#w��i+�x����(b�����#�5�Xլ��{���nY�lĎn�*^�v�
d�،���4��U}4�� ~6���(�J��n4RP=��Dp���gj�;*VW�ܨ*#=�O�f�D��w��rȕ���&��f<:�g�16\�����g5ȇ{ԾW�Q���P~���*�聛��}�W�Ǡ+S(�dRA'm^1[�y�H���}�	P}j�*����n �m?�Փ��ф�D�ԌG��2�<%��F�X@��� ;j��X����u��r`_-�	af�h�̴�x��=��'y��K�����JC����Z���1:����[ZD1^��0�Q���P9>�@�;�/����R�I��1�����V�p�c�۶�l���:|@�4$�q�".ܯg�r��:󛆇�|�[n�{���]�5;�耟
c�~��X&4�����D��e$��Hg<�/�i�o�:3��B��(�ͩ�vn��f	�QՁ�V6���"˲ܿ�y����W�ɝ��)%�����dg'�<��W���a�.$=�,��f~Gͪ��s����^9�U�}�.'q�c@�iŐ��2�8���<.b߅��7l-�[�p�����,<}u��2!G[����˥�p�ȣ.�ւ!�O�Q�.8��Cp����o`�إ�G.����e�3w�.�� �*X���M4,U�L�Pl��E����%�v��)N��ڜp��_��cmTm�F�zp$^a\�(��_Q �צ��!ʧ(�+R�����'`����IF#���#E����� �:�=l���hU�џ�����rI���#<w&6Xɐ���ljªV2�4��BG�l<�X�ˬ"*�˽tG�;_\sr+b��~X�׊~~��)�V�q��;ꖧefu��G1K\3���ח�?8a�rw��Pc�O�7�s�u C��A��Β;
WU&r��I�y	�,�@���]q��:/�g�K�	q(N ��x��(��X��4uo�{y�2������O��b������l��<Z��G�)���%9�gwM�u��=}Q�@�g��,�8�z��ǌ�5�Ŭ�ach��	�t7�U$՚�� ��`�P0�����ya�;jX��!d��ڰMd�,K�݀��O|ӕ=�N��7�lR5�k�_���h�F�?��ah2��A�3�b}p�F��;Eo����5�|pգ��~�u�:Pm��}��V7����"}l"�z�{���3W�g��~m«v������NBA	��Fj �e�2&��Z{_Ah04v����h&������rl�G�*M*��#GaGcL]�+��`�9�-9���&S�(������� f�2����q�1�D]D�M�?���S�G���}S*k�!���Q	v���/.��ar����|�'	�߅���]�Cm��J2�-�z��Ȳ�k��ɋ	e�ѼJ���μUg{x�}�NӜ#Te�Zԫ��nf*���rM�D��ɻ��J36-��Ld ��)ۙ��&�#���y-��7�e�j��?���b�Eg������G#����mΨV��}�^�kӪUE������to�9J�ü]��8������4+K�F}���� �_\��
��6�Hu[��4�����z�g�݁~��%�w-�F�6d�\y9�"X�|t-s�A| ��ʛ��Z<��FR,�i����������J��q65/�S7�ZI��-��h�v�j�)w��Ș6�3>���Vq��gJ7��!��,��d~G!Ӻ���I�-��7�(5���	����w�f�&��T�n�]��O<�%s��tW2�H�lqG1�lꋙFOf�Fk�	_F߮c7Ɖy�^����@�.�Xy�H?��BT2���l<]�_Ģ��8�ǲw㔔q���&y��Tr���:���G�B��w����Tq��f��)> �����8�tE�yp��7�    83�Z�P�@��������_�E������?{�H���b15��8��|<�\&���O�~4�6�A�����G�.-}�����ڠ�`�ީ")��,Nf'��(f ��<���y��bVp�c����5Wd��b���9R���u���:zĦ��&�������+78�Z�v_8�ߢ��p9�F�RT-���|<�\�ybԮ*�F_�X
����M�
����9Q���gW^ΓWm�i?�?o# �\�3��O�5��b��Q�:+k�k��a���D���a��N�N�T�|����a�2K����$��5�˷�D�T(����^��Z5��sq�(�\��Zb�2/�UY��u� (2�)��@��͜��%����c<�V�qn&�U�E�^l1��NH�à������eqp�5Q$3�́�z�Q��H��Ly����%��:T,#+9�P�,�;p<�V����"q)�S�?�v{T!(~V�uj-fRFO6�+iW�8�����jZ��?U�蕄�9��s�y�x��%�v����s�"�r��=�->\Cu@�D�/3�0�i@�~I�w�����-\O���_�VH��0:r��p��R5�l{S���h��[qēo%�gB,�'\�Q�
��}nG$N�X
�dkB�KM����$����WC��\i����3�S�-?U{EنR+?5W��4��v�jy.`���3� Or G�x��]S�
�:���#˷������9d��WYV{���m���zkO��gY������(i ��x��J�zj�i:���w��>�;�-�#�;�}�U�V�h<�:a"ҼV���G����9U��U'�S�n
��dF,���]��htY�qJ���Ig� >�����ݜ�[��i ���xP�*��l�4��hO��t#@^�?W����N��|��
�t�y���0����{C�?�hb'. ��=���F�)�W��k�V���#;	@`u��/�0��	��ovT6FJ��W\;el���(�s��8����7� _���d܌����4Uj�'rd���7!ɇ"!lK��߆n��J��79<��H���^��J�6`fގ0���x$������4�,SNu#��{J܃�� 5���/�&Ì�x\�Jdmg�E�빡���zF�ܒDy� �=�*e������<�4����F���b�|M����X�s��mi�;4������3:OY��'�&�9��A#k��e�(�����pHO��ޚ��r��1�����Ť�����|�C�:�3Ȍ��D��;�7�Ƅ*�}��h�¼� oSw�]V+���FG��L�� o�c�-�z�3ʌoO�	��x?!qG�Z����<?aD/�g7�(7� ��b�)|xF���k�V�k��9��8��މ0���x轎�Ĵ®=�1�Z2t�J�F���)���������=������_8��:!;�qi��_А���|Y�<��D��i��f'C�[&ت�&�9Do�W�ƌ�GG����\ �(l��c�5��;�o'�|xn]��~VﰁGu!v�F1_���э��� CM�H�������z�ă��`�w<XeO�L���ad�(�&�H���5�%�%�b�֡N��7I��.�#���P� ��/g4���z��p1~�P�i��禎��St�c���#X��Y��<i�g�<���ъ�S'�|��QZ����4��uV�S=�F����|x���e���f�y��p��Q��>�GV�C	����������*Cz�Xn;f6t��e��@����h�xʻv�
�:�z�!FH�q�3�Ч�����ğ}�C`��E��ֵL.�ة?�`$4�$���6�˵�n��f��H�y�P�����\�ϔa�-�|4h�d����{��&�e?w�:����(��p�8gC� ���i�d�0�J���A�#֛��7�n�>]������r��E�{
�FuY$��3Y��l��<����RL>�*���ED8�Z�h�k��p���Mu=�̀����Ql���@�<__5P�i,�P�͟u� *���$��b�4*��J����6��tQlD�)&����-�eP:(i^d����{+qNS��͓���U�=�&pd�tyZ��{����Ϥ�?^�^C�3,&\?2p]=�oNB��6�dZ~ۗu
�}�^��vx
�ؽ�7 ��h�'hܳȥ3v��+�}G�e�Ou�� �9́�.�2	M��Ș�@h����U�eLY�Wl�+o2�7�٦1u���0S�r�k�搩��%l{BB��5��������I��Y�[#EFe�+,�w�Ak��.�^(,�>�y�����#��w�b9��Y�߬�� V!�G�gV?Y,D� �Ϊ�X&�F�����I�wY=�gj��Wj��h);�p��Sc{��:2�uŝ:�a�цm-*�j��d��?��џ�8�t;I��@��T����4�����bjob>�����km ��]䍭Q'�lq�p�M�/�K_����JL�cN�ڐ��h��HU���b���{ڦ�+O�:��/����B��@�AC�],���V��|:�u����	0`!O���I��PK[���c�&Y��n���6m+�)����u�yd�������6M��V�F�Tڻ���H�%w=\w<3`��!2���7��7F�|�,�#��pB� �S@~�ZN(p d�_���<��:s� 鹨���{�ə�],|(d��A���f���5}�� �P��r|�
�ޘ1W�G����julv�C�n��%�#�gW�2�br"V��S����ʋ���ª�kyR�<���JTe�`e�4��56���tl�����X6�?���ԕ�?�CL���0Z�>�nIj����W�\O��wl��;=q��b���2�A#)���G٨r��b�����P�U�X��:���f	�8Gm��#���J��^8��UǄ��}Mo�v��(K�%9W�vєlg��7i�	�����@�%�f�s�L��	y�n�"W��#-q~Fy��u	d�����%.ߚՑ��\@�4;A�	�JP�@��xP2I��__����ľ�w�܁�����=?��ɿZPJ��s��
�"ГQ�P���d��%�WE}���f�2�t�'��	�g����;q��xV���)n��z��"�f;�L�8.��*�a�sEc���O�zov� ?C	�0G��Q.�7��&ƕ��#���t��0�J��^�A��*��'#zAH�rJ�W��;�N�w��[�S*�e��;�<"9�~�F/�v�2�ݟ�q�����HLY�'�,��(Ý��|&A�����x.I�Jw3���΃�6�Z����L�l$�q�H����槠�jb��^�@P��poRf�g�i�(�T��U�_��	�`���2N)��Y��}���zUz�qҝrÎ�����{��'%�	-�Jn�6�fT�%=p��N<#$Rl6��s9N�I�XEI�ɬb`�,�>���	����MR9U�%b�#�ҙ�Q� KY�b��2�+}9EN�rj��UQ���?�~d�!ʝ�b�#��"���M^<th;��p��$�u�����4�nQ"#� V����֥YB�8����N +��s��.>�@
7@N�����*�N���}2s�w����Ϟ?�Y�3�L{��M��λ�}���m���C����u,;�����nҬ:/���ٮmD���Ua̿���nZ�qf�J9�@���7�D��z��O2��?kÇ�E
����	���*�C�&���_=�r<b���Ⱥ�2�t�R�y��j���I��*xpܓrzq��o:Le A|��Ȯ�꼧G�F�C}�N�<aW����=�o OQ�!�E�����V��[��i9�̒2��T���r��p�d��N�w7�|���r���r��z���%�/�I`<��eIj�U���+���F�v�,��JMv4�D�!�-ǃ�Y^��/S���� ���    p�Vj�YSo��Ub���afe<��,�o ��S���^ ����0"��H�IfU�{L��� �	I��=��D�q:��s\����Rz�jH1$��W��Ae����H���?��ف�\�u��'���=P�0�`���PY��=l�4zeA@��m)�\���f�YM�h1� ���	�)�x,O��G�T��~1�AT*�� ��mz?���U��=1�=�P�"�@�H�=��	��[N�C_yǕM>�0ؐ��Y�̺��צJ8����O#��n<���y���T����|蓌�\~C���>�b��A�[��x+/��iQ�E�����*���?B|@��9���'���d��������!����Ɣ�rI1��5�~L��J
��S�`�|N�I\\���g宆%�}�{mG	k����E��4rR�q_�3��$����7� |�34q��������6�6I������b�̤�h,�ݙ�7��ʦ!
J+�bLN"�0���H34;Կ�߃%�4�B��I��ȧn�|�YC��iJ/55�jY8��A���d�w��)F.<�����My'���*�(�x��z��"��0�o�1�v���P��u �Fp�Zr�{�U�;
U��U����K(gۥ��Ȼ��XսἪ.(�V��#��]M>3�WR��pe^y�檊-C۶v��UG���� �C��4��4_w��j��y�3@N3�rZ�Q�"�iU}�t���Q��s"#��l��d��'�@�A7��t�?L~k|<ɜ����Ƒ�)Q7�U����~�n���S���,����Bmܙ��	�P	�T�-J���[�R���d������}�u�H��J�R���x>�k�ν�?���"��A#J�BP�k��0�:����'��e��������ğ���j��'�v���*�v��㑭=rUO�7V��v�ɮk,0z]���W$,�g�D����@�H�~��N��N{����iǿ# љ����������YT�����{3q�I�2�ݏ����$K8;�<k�7:�`��m�e�cN:��F��́�jIl���D�}j�><�|�<��,Eq8 o�El۳������x�g��jx�:�g<���Y���:��ѷ�|�~�᥉i�}��׉F���^�<j~G��؇��I�ǯ��st|<�]���+���tw��)��'c$ӚM��e���r�*m>�|A�:���%�b�v�)�{((i?����~@��0��AWA�KՔ\h˾�t4k�����Kq�jUCR(�!�ڋtW���YCH��t?���e�����1���cj�tĝ+�d�}�q��i3;΅[�W���+Ư9�iZx�:e;��pw�!�7
'	�S��zK�Y�>ܪN)V{G�����u}hO������vj��h���?����;���>�@z��{�"��~�T��w����ж`S�u��j�d�� ���]+*�HpO�TVWF��蕞Q@ �#j"Y1W:j�~��--�o�YtzJ��\QUIn�ވB~�}��ԁ q|GU+/x���I�&�䠥Xh<{Wi
mm��^��i�
4h�6�N'�<�ޙ��A�U�-�"����Y��0<��ْM�q@�Q��D,�H3�%��b�V�B���X�T栝V+0���b>�����I�Ǭ��<l?I�6OP�f�A���5	80���`\/��w�n(������$�K��V�+�ʯ� ��@U���i�Seǅ���z�K���`�s���6u}F�B�&�uw'~X��WT�!%��:���>k��������	�2��*�i��CX�_�#v�����_�Sf:�KĢ�*P�;��',�o3�S4�"W�r�U}]�����L�<�r��{��>����D`~Q�nY,TJ��!N"N�׈�O(��w������.�ݝܾXG��.�q�:Lu�������ٹ�z�)�'Z��⍂2��W-E�finM���v��CL#�.�C+i�OЃ���lSae��-|_T+	���V�}��i���0B��T�f`���a^�-�$���(�tБ�F���"��x�=�R�p8���t)�8���ݜ-��4�v}\h��f�J��6��bU��4�s�T������"���JUDOͲ5��f��5z���a���$�͵��s�9"0�n�����M��a��s{c>�@���uQVe��2����d�زia$�>t�6�_f�݁���W��6������_�Ň��RY[Q��G�P$Ԓ;n���q�r|Im��d��8�Cp.�v(�n�4g׾�2s��w]Lr�8�c�P��ZY��~k*��7�YQ%C�9�����<0�
�x�~&��nN � ��_c==���%0A�
��;^�@n��˃�N|$u=��߀ �?G>��q9�n�a��|�znQ<�$�"I��X ��x<�]N�<�]N��������~u���V:]��P�@n�� w�ıA�ˎd�zB� O���`��%�-Ӷ���4R�zD>{[fv�O��O���Zo���/\�6���M�O������m˵��|½e��)��9����)Lb���Hs��8���8aϗ㞁aB!��tI-vezi�"h�ɼ9��\E�9�]�Yqe?�[6�,�W����-��9��0w /���A�f�)��8�>K ����%4% ��fy{�F���_�Y]����I��]���ߋ�-��xnH��;@N�AC�ǓÝ����6#\��r�q�%�we��Ua�L�����,��&�mru�r,;PS���"�gn<]�'��o_�S��1_�dL�#Y�e1��7�s�4-�g�}߿r�3��XD�8o%h�r&�$ ��HN"�}g(����}�iȉd�G��.O3��<�fAt��:i:I�*q0A)�Vﳭd ����P���Iofpd	�@�hO�^}㾻kͰK��̀��L��()ǣȖ8��I������t��[��qo�Q��K�H�I:���� V�2�I�:�X�=n|PkR
��:����iQ������� I��Yd�0��94l��&o�X��$�Sn<4_�����^Cݯ�m�����@Ӂ�{��ƨ����fm9���Ŵ.��4zcr�z����c���u'%��O�ͺ���)h��J���!�X9�bI�X
C]f�'���L�K�M��l�IS|�i%,o�)�W2~�S�Y�����^���iN�?{� �/=�@E ��u�Ac
�}f<�2-�B}1�R/+��~����Hc=��*�w��4L��H��֤'q�����7�[��%o�H��YC��Dv��!�3C�7?�/lu�x ��=��g��|�3��#�Öa�rn�mi3�ʿ��DN�g*�ߑ1��qt�7���mE*g���Ȍ|w�rώߦUY���E\GV�n>�o�֣o���i��x��H2hɵ�K���{+����ZU$�Y���4�L�)�Ȟ����k2(hs �!�r1<�;��q�����1����@��@���{��,S��Hb�%��o���4�6C�i_&��Y;��}v�>�@j8~�V�q�A�$�>�hIqG��=����4{��%Y��T%8�H]�H�b	�{L]e|{�š�U�#n�䚗��������'� �����i�^��S�W2���E�'�(s5:��+n�O��b<B̑G�����V)~��&z�<�
@������Y�*B�K�����~J�tIN]�0�+���ycՓ��K��<�푃�2�}b��r�Q����Y���*H��C$�JjsC3�Ǣ\��6(](���-��/+OJ��7	~3n��0i��xw�5&u�k@v�bƙ$�i�.	�����Цy���ġ4���ju����U��$���"l�tm)����椧
�ovH�Q���!b�ޛ�kL����m�\��V�#���^b�t�y�M�VbcA��+S:�ZX�$�1���z�vK��u���a�,��M    TD���=_��U�>�=_�)2����8�'�B:��<=6P��c�9ތ.��	���8���&�TwV�9u���Kx�����!��z�{.!#�qğ!� ��ib*�:)"api�@'l&���pO�EDf�H�n-�Uԏ�x9��ǯ��"-K�̒���:���;���𲈔�0P�K*�:�<���˲����-����9n/�6%x��4e������#�h��_�ծ;�l1����lV�*�i�/����<1�	]�ɨ^�
!��;y��<mUO+@[Ȩ�&����4��j�Q�~w���P�$�?
�d��+.0�`�^���ෳ�qP�^���lu�Ƒ4*�N<c�|a=��|�ԁ���;�$�z �Z��V���:M"чI��&j�9�N]]|�ܡڸ�5�P��*�쑍:�O"���lt�S� �4�O\��tH&BB��"Ɖ6�¡�HU�*6l��>���T��^��e|,=	[ ��r|i!���x�
}�vn�VYv��;x�~H�W5�F�� V}��aE��*�سL�<��v#2&g�2�1[C��o�p�9�c�f��=��˨��@ F�)[<�lUUT��e^���$wLC�@�6����?)�@7��S1�{F�O�~��ҍoM�i\e�ؤ%X�D��_�����$�"q��WW-ܼH!ziw�>�0�ѩB�dq�N��VE��h�E�ji�� Z��+gu#������gH��K\�o�:z/�`�$�Y�w�z���(Fo�e7��̅�,q��*Z�bV��y��bfI��S�M��Ԣ@WmF�0�i�h�h.MLc����;�xu �O���J���bQs��ƈ�B�G5pg��  (�&_q[�
2awnZ?�Φ�n<�&.�o��D���1nn;N���� ��i��� ����Xs��?󫭩�r')��,�*��׶ �Y	�����F�Fa0��0�A}�E���t��xm9�fI wI=�Xu�x{�,���yY����h��/h�01�mGNmOm#y�dPۦ�b��:�|��
�E��?aW �x'�m}�-�.MWR���ig���^��Mx�[O]Bw��Oz�*��C瀵�-�
�2h�w�y��v����"�~� 7�J��3G7w�6b��~ ���{���
;t/���l�I"�X�Ι�%�Aሄ	��qdi /v3�YM\����,��h��:q�RN�Z�=L�1]���?����ب��>Ȣ��>�D�6��(f�s�)Y�U��2��d;��O}�S�&L{���&�	PC)����㪰g�,��^��!䐪��n0�P�1|�#(u�V�^�d`'��ǥ��x�P�Q�c��
���?f7�7�5��Ժ3�����t/�~5�dm#rڐ�#V�X���d�.�FQ���z#H%����|�_}�;�a���_�;�@n���g��?j!%-������T|u�V��`�[�(	�����<�ŲO ���q�� =';h�v�ee�U*u��" �;v���t6�I���I}{	u���i����M�#�����@�	��r����A�Bf�/B$�����>�ԗ
�B���|�� ���y�"���XU�^3�۝���HS��ҵ�_�$�4)��XG_h
�t$�ɺ�xN�;V�dU�_�>D��T+���E��
�n��H�<��nɧZ��  �B�4'�	��DMѪ!ĩUe�>�ʙ�l>i��1
n3��ߏ��i�;�<��ۻjJ2�������Vf�O�aT��<��(Wz\i�?1@�J}���T�0�/��`<3��D�?L��7�b}�kX�y~�7���.��b�}�7�������3 )�s�Z�0&Koˊ�~��+��Vs�p���D�ɓ���&2Zq��0A4��x�U,2���±FD��\74��]����vA�L�~>��J�J���D�x�аc`�*,�k��=x��@��Ki��U$�N��m�%7�jyn轜��\�>�Šl#Š�Aܶ����R��uj��<�^ѾS�KD^3��x�^�zL^�~�diom� ��r�,D�c�ލ_)�y�Y�W���7β���ǀ"�;�����:*�d��v82/C��}����ar(l ��t�z)-��Z}�$I!�h$% _���p�$�'�
Fn4fנny ���RZe�W#�%s��Z_޶+��z4o�#��t��(�{۴��>�5�aQK �������t[���U����7�8)
m��\N������$n.)֦캸�����\&�p"��C�]��(b�e:�̒���XW5�Ǳ���m�1��u��V�8(�6���U6���D�'���Y�S�֊K͎�3�� re����G��9ob�bY��2K�8@���~�Mo����,h��NI这��✇ɻ�N�7�����͌�ܣ���f��l����Z�����!5qg̝y�O��a�����E�u[o)�9�C���4�@�zK�F����C�ǯ��,�����#3D�����Q����>x�,^�@^���gyl�Ua�h�JmkEK��No�7�I>���t%�\�2��ǚ���<q�H#M"Ĵn{@T�j�$��Mȫ6Mv��Iu�q���+�"��}�:PzZQ�;��U�گw�b�]��Tl<b��C���]=a��9.�  ��	���0wE>O�BM�DͲ@���q>�K��.��+|��Q兏{�� �ݜ���e1G��,�,�|5�.��<�I���W=�6[��-L��fXxؤƀ�J��&�7��N�͂�
S��u*Հ��}�D\�%��3���hZ�I�﮹y7�V/�{��b�{�ż��vx�*?������mw\�}	Ե�,6!I�{�3V�����g6��6�(0�o����p���ܿ����ɿ�ѽ��x�qa���)�y��U������Bc�\i�KV�6������Q�2�x 8ϓ�3P�:"������A����ý
� P䯭�8����9_����P���z#<-Z�l�|�S!8wo�h_`*��Q�v�"�|��1SP�s�z����?��7��oD�����7q��s�{��xN!��Bw�]��ss�P�D�'~��5�ߏx�L0+Zr�j�t1,j}���y�i���^�18��Z#�Z�[��ޱ�A�I#)��&������E9���荆&���V�����X���a�M?�4[<��G8��#�d2okv� Ϻ� �^�?��h��:����(v�b��n}�Xh�+?2-h�N�ۻ��l��-Ѧ�iҌ��f	�ѹ�%�r�F�b��i�Te.k!<���$��Dt1��a)&~�>�p���Rs>��#��*sI���1Ƴ(�_��.�V e�ҙl-Z��Hd��c���Ru}
�l��CƐ��D�A=!��/�@������]+nuL"%���Q��'��?)�����%bcng�ZJ���\㑨�(2oo\������DB����嚥@���@��@��pTQM���U�j{�^��g�Oy��<f��EY�ȡ+9�ƣRE�O=E��u&&7rfh"P�@��x詜VUnD�j�
��Z7߹�}�1�*HP��@D+j��37µ��`�20��$���a/.��9�I���59�*��&�8z+�}��.Z��3�(�����@���8Ǣ9�ŃU�X�_=�����a�2͋�^�*��0��И�!����4��xLde��2���VqKƃU��3���G��5R��:3@������G�-�(��y2b)�����h d�q*�.Ow�I�癆"���{���N@�w����~5��*��y� �'Hq��1eY�%��#ܰe�uo &��"�����q��WE��3���0��=E�A�Ã7|Zt�nk{w�v��#��5��)��LHY ��y 5?�VӴ�XiU��Q3�f��z�A�#�@*͠æ����VE ������˺��^=O�U�Q�&>��//-I黶']С�ʪ��bq���u[%T���_    {7HiY�p���놄d5y��	Ruf�@�g������ά7��E4��0��5�x���U����W	���}:������\���(�q?+z[p���SdH}ֽ��;���ӧ��=�%iA;a���~MV|�:|�qts$��kxX���m '�6��`�W�p�xd�ƹ�Wu4�P�*�O͒P����W�s�*{1�V�s��`�[kE���ƃ8.�0��
�ϧ���o$�i�q�D��kr���f��,���
,*5�
�����]��Tʪ�V�)�����Dp00�6���H'�E���d� �o����Tl<o�*3�U'�7y��Y�� ��b=���;'��EB���wݮ[f��@����hUU��<�i���KX
>*�n0���L�8��f���:8���Ģ䂞J1T1��d<hZO=��΢ON���J�\���8&0�3宇��0�E��x�������O�GoH���>�+��n�<3���nC���N��z6\
uH��C�u�+X�#*�e2��ՖHr���:�ԛ���bQԷ�>G��$�Q�:˲�8+�'��?�����r�����ݨ�����@�Y�$���:�ҩ�@B_
�����m���Aӷ�QB���]$��q��!@h���fBE��J�Y�R/(�§�ӗ��M�ҝo�%�	��cnA�����>n`���Y�\BE��\�Ӌ�7���[���xF���8��_1~�'�xW����,T<*�����F/�!fD]�qWc+�=�I^z���k���j��=���ӢK�tƀa��=VwL�)'����e�����oJ��Q�����J�'A������$1?Q�+���Z��UHӲԡ��g����>}��M8�x4=d������8�z�`o������cM��_����Q�2-/΢W��|&Y'ۇM�&�!J����������Z�܋����j<�b��Ӎ���;�7zz:�M>p�ò�Rv����슇(���Y�ӪZ�Q���ѿ�f�ٚd�J�O�iw�aW(fm���$��u	%��O`��i�*�U�YdM=�>D�%l�?p9�׶Eڛ�g����>U?�]��W*O�Dg�*���"�Tޡ��>hg?kW��5�g�rtx��@�����Yn�O�Vm6�.�ӑH(��N>k�tnQ�K��O+W3�\E\��{����s!MI17u��4ۥ�ݢ�]��bۇ�ՎG���=*��H
ja]��)�짽��O+�쎢��ىű;�N'̗�U��MI�zc,y��k��5b��{i ���~i���i����]�V֢�I�֝[����Nζb����/\XP=�f�@�ҟ�p-�(P�T
]�i��$�w��[/�m��	8���_�����W��I��js��W��N�ϻX��ĮS�`qyvٞic��ʆU�+�/}�~�չ��0ueΜq!p\��J���-ܽ���<���UQF��ǟBjV��UX�
�t���1�|k|���$F�p��u���)o��#���G��ɾ�e����]�mz�)/K|m���[�w�S���(�z��͕ֆ�\X���6B.�����4��&)�����~�bGą�(��[�yF���Lj+q?��蚬ࢊYU_r��W޴�OCH���G�~k_
wN�ډ��U����"K�|�Rf5=:��q>��0p�r<��L�����2z��L�*uPc~��+/���%��xL��Ӿ� `:�1c�7/����~Z�R&wT3�m����v`X�.�[ o���xƽ��By7�P?X���݇�Ko���Uo<�� �ǪWG_݀�:`:�Z�(�%5P�-��L�ɽ�x�����I�����+l�H���#���F��]s��wt�ЛF`"M�=w{�_wx,���g���痾ó�V��@h�T��P&6[�vO ����E-��ǖL8�jAD`��&������$�k�O$I�9eÀ�����/_.�ò�Yw:�$�N87w,!�pu��%�i3Z9�L�<-uFK܌�<$]�ޱJ������t����� �\�ç��$BCa'���K�������Ϥ�*[�$Y��S��M>�5���w*8�b�a�'ǂ]�#�0��;�?�h�0W���>?m�+ǃ�I�NSŎ�<�����Ɵ9�&��'rm�'�m��y��:<+f���gH0���p[MO����)qI�K��⧕w<h��崶�� k���;��V�7Zu;}���/]���Il<��~o8��ѻ���[��'��l�����Ǧ=飤� h���t�͹!|L��G��r����+]��C��])�q�4�cs$O���(����BU03����'$\۲j��'ҸD2���%6@��t�,i!ӟV���i�V�?눽]�1e��i��t㩷e���ok1'��MM'H��&�Sr=\�_���yU��yj��t���ϫ�V,�xT�t�m[A�&n���`!�g���?��Ȣ�2���t6����x6-�i�hG���45�1��i(���	�A�v�!�,��{3LZ���*��7[�
����hO ]��1�[�-�s�:={	�C�)]�S�1� �% ���x8&���� y�L�1&6�j��a����1
���C��*Z���t�D��fG�A_/�eh�.��xiQh-R�]%(R���9{��S�l�~��X�	�bT�Gd�*N}�$zeƑ���XA.�T�l���csuu������j<��Y=U�:M��p�Ust���YH�J����h��zB�M����2�x�5�ֹ���5����K%!Qgz��|@�	'�$��(ՌQ>���nL:�4v�=
������i7M5�͒,1�J
_e1 [u&QGG��oj4�ڂ��/-&2�n8ϩ���T�,n®��t�������fi��vi��W�`��[]ƾ0��M���|���W�i=x�ngڷsS��.gh�'�y��%��r�~6f�G�@��+ƅ}��=>���X��*U���\j��Pԏ/�ҍ��j��) �Q\���?�K�M5t���`{�:;��|�:Eڒ�l�:��V/'���Ysa�jAB�?NxB��Ϲ���N��O{D�c�Y��欗�曻C:�*�Z�X�E�zoBK7z*����q3k��FO�E:�^ӈl��s-~iA��4GʁQ�*b�$��,N�����V�W�U@��������O�qT�q�+��H�2��3՗GXϟ:�Ɍ}��Єx�[|��[���͹R�&1 ���.w"<-���<�i���guᝯ�i�����Y�rr����A�:�����M��ʼ�����z&��{�UP&���d�M�O�x�]]x.9�&�	�.�##I�:ArT�d�K�;���]`��~�͞2;C$��Ҙ>e�_���-���ޑ?�DUqa�vW|��:�׫�rqw����m�X�Q�b����_x��S����@�H,�O��v���apM��|ZW�in�H�g{�4<j�7�z��Ѭ���r䐜��!���T���<Ɋ\��,�Ԕ]�c�����i��t;�J��`.{ה?=?J�����B�w��9������ܸ�^U(�N�����~���T���r�Z3Fwm��h�̒��a5�
ę�0��Z�P[�]�k���ɂ_��9��ւ6쌧E�h�I�+��$4X�:�m0��p����v��ۿ�L9��Z�`���	m����� 
�9�G� 76"I0���ğG?���y�f*v�@?�I�Yϛ�\X~�%�?��'1�����0����M�'U�ĉ,��z��X��c���޳[�>��4�cѸ&'�����c�T��3yQ���ʣ����U_^�������R�e�7:�ѿӮ�����V�����qVD��ك1C�7�>Մ2�#�j��W��������U-��S�ߺ�{�j�_s9�������A��)QK���s�up��J�bƥk�垡=���$yb�a'�K��L�1�I����5�ء�����8Щ1
Z+K}    +D��G�Y�J �{w9��6�|����f�5~���Z��4��J�v����4k��,-mp?�T���n�;7���ʽ��yzb���GpS���Ψ���-z�a2��E~H[�_��tj�b��:m_2���@q�r<�}!�3��@���\��0p�z���H���wY}@{⺴�,1i&!3'�׬��^��ƿT9��0�z�6�H��H��4zt���w���N}����Z���{HƯ>��UY�R���}[s����3�~�������Ğ�g9q��/ 	��Ë4ʯ?{��ހ�Pe�:_2�ز���^�.���������ֵ�[/6W&wt�v��V۸y���+���x���G�g�ōdq𕁭4�5��ΉD0�Ɛޅ��&�v5�${s�i⼇-��ܤl�l��n8𞗳�4�Y�õ�M=)���&Ǹgu;��>h��
�ƌY��*I�_���ee�(:z�*��â0�I���U�ڹ�y�nȕ�FV��pĽ��ej�˂߱���v�]H��Ǵ{����j8f^ĳ��w1���R�Y�"�Z��kx�8M	�ⷩO/��8�	�giw��>=Ͳ9͆�E��F����G�=B��{��;���{B�Ѕz���xxI�cp���׏8��e����W�AaD��wV� ����3C�}v�!�d�[��;*��V��n�׏��`���tۤ��h�G5�,�8��鬂{c,2� ��N�8�=@���W��ER�M� �B�E���*7�vq�Kw8ZY����@�,��d��;$���"�R1Ć?��vIb���,��PJ�]�%��S�.�j��Ir;�b���<��yc9��ofKݡv7�qz�>�I'�Ѥ��p�ҍ`Q��s�ś�Y�bE��ܘ*$����aG3�<������}��A-��W�i�����eU3C,�$��nw���Y.P���B�M�2G�%�D�d���ސ2%:�Js#IX�����;��"�`�+y�d�����5��d�Vj��r�&�hq4?��S)�s��Z=�9��8�b�؏���]�g���B��)�I�
�>��}g;���%x	�gKw}�,񚮰�6��.���&�Q�G;^�t/�)!��$��ز[�I\��~��WKdy�g�4�%�u������D.On�7���eZ$�����P�M���}�X�0a#-o�wJ�a�c�򚸜�vSV�T�@ �(an��6h�a� [��r<n� yn΁H�%������ӛ�e�pp�r��ǵ�{��T��sӽu�ؙtAr�����Ⱥ7	���'�S�9Ӳ1~��45=\eVS+��d���=��xN�'oһs�ɶ��yԹ���g�Sc\�	�Ws<D����MW��6�6�p��,�* /�wR���uIY��U�FVǖ7ܛ��Q��i�~	�Z�L3^h���|Z�� ��dҪ��áಊ#�0���⡙������o����Xk]U�&!j�q�ȑv�:"�+�C�V�H�ȧզ���Ñ�j���Ao��U5a\Jzپ5��i�A���F�#���I���m������*�2.f�o�}(�N�	��j
D7����E<]Μ���BC���=��s���*Ve���ep�L2�!����8,TC��zh�6H
�>�?��?ҽ�!M D[mBU�=�]�|�����{�$qi��Q�u�C�ː�Ku�&�\ե�1um��Qt��AIb�2$N��U����H���f�<m����:'b*� �����U%�X�7��w� �J�*�2h{�%�!������s�N�@I�?6���&�?Z��%y�5���2 �ÛTJ������|�cC�3���S��q��s�h������h��1R�,� �pE=�0k	?��ٳZ��y8���ɜ<���I��v���I���X��ՎD�^���,õ{�����W��9t�P���Wt�a��H��J*��ԕ�)�e����c�oF�$2�1�kQ��M��o��ਊ�<#
�����7�y�8\LNq� 9B��9�����~��k4��z��*��|x�,��-Ԝ�����R��l|�3;/��0�NL��V�<3TC�ӎ�}ݩ�A_�ms��i��x�O�f"7����&�����Cc|>����ފWh]� �e�"DrM��e"�(
��7�e�?�0�Q���}[����atB�'n%!
�G�r<=���L���9/�^K,5��aC��;������xr�v�S�{�'�I�{��;��,��'7,�b��6��M���0�A>�Hi3����v�/��٤E��Ն/��E��$RX�(���fAV����ɹ�$÷S� ���j��\�ym�Tj5�R�N�'-��Os�U��8�C�8:��ULXhqw��[0���%�z�6W�I�wG	Ga����Y��*P�5���CMxq�hs�A�����	 !}6ش�f���G{=�hx�2��tJ.g�'�NE�YlEd�%�VE��l�7R4�Jcj�dͣ�����8l�꣌_��+素C<Z9���,�ܖ�e��v[lG\%��qgV�5��̓w˧��]�w�sg:)�Q�M�|�Bw�3���LF�e2��eVeV�8x�-�3�g�����b�]"g����>�^�e�Ӻ�V��-^�*�M�W&8|]]��V�s���[�}�,�[F�3:O%�'��e����R�l8R8�b��,������f��t�߻P%�;F@mN���,T���\&���B��_Q��*�����8�>DO'���#>��
-}�~�J>�;�V/�{�RŞ�<xo':M�[y����{M��*�ä��v���L�ޠ�����	�t��KM([�P�jPv���X�G�lV�л���J)����2;���-}Y����(T���Z���_yt��<�[jT�Q�$f,\V�Ƕ=��vGʵ�4)����z�뀒5����Z������F�ᑊͯ�X�ھ��%�[�`fW#ތ�W�I�C}�CO#i~�ŻbU7r���"���:rVQ��;tEG�\8a]��w�!����8�͞t�3�vGw!�c�:ۇ#06s{������;��Hc����i�*��A9�������s#�ǎFdD[�(3��v��׃�ڤ&�!nMsE��4��%�������4�I���� ���W���A ���=N��Νbs/�ҳ�:N:�؁��4�r���͟Ku( ���wE\�E�yK���;5u=�a�+ٯ��!���%�ʙ�Y��'���&x�%�@�_tn�D�T)f��,�i��h���(T��B��=�P>�~A�m	aWXpG�ς(ͤ�\cW�_^6&��EY2KT6V8̰�ꬮz>�A�Y�r�fU�W������b巁���+���3k�����}H,�yc�cGc.Cf@"�>	f�����d���l�ƋP�ͦ�d!1��������iQ>K�I���/�`�%d�n,I��ȯ)�'h�u�K@w�%��r�^�1��S�ߴ=U�
W�I���z���[��,W'r?����-,|���"�A}��]鶍���/t��T+B;q��	@{�9���^���FWW�ryYZ�]���^î "�
��B�gAn�}��� � +6yK@DK0/��ق�8��/��V�+ �"�rO"��o��6��)[��Ġv/b8�ٛ/d�/��5!,��E������
����7�%Ӭ�Td�
�U?7޺V�����ܹ�v(���d������{�S��綃�qͻOk�S3��W�Ze\%��8dٺ_�=j��	�w@yq�X% ���.|���Ęl��/6�`OO��\]�v�y���u��b�j��=ns}�/��-�2�w6-?��
tT=;��a�wy�~l�"AS��ź�{�F��~��KGT-��c]�jW�VU��~Ƚ&��P{r��Xה��X�ͥ�����pL:��7 �
7+TlZ#��n�+��״T��+��Ե=�]h1E��0v���.�/+u�@ų(7$Ͻ�[!�v��ܪzPؽy[�[v����g�+
��Uf����ͧP��Z����?;�d���� ���QUP��{�4�f����v��坤���-+    s���8x�RK�|��mTn�B�~��FW��{qU\uj8�e�(�nR��XU%qf�X��D_r$}�g�݇�g]�������X���Us����ޕ��	ħ�˶��6���7q ֳ䊊���4��'�{=�%\m�m�QU��z!o0����d���릿$�8��y�� Ç7iOW�V��V�zwJ�vy�tBÞ8 �(t5����~т�G®d���~���g�<��rV7�y}�I
������<�Ռ�����q�KK�7
��0��o2Ef������+��܂M�Ìcvwq*MK�\�c�MR���q�z��VQ�g�z�e��|+���mm�+�a�|�%	Ϡ�Y$��ss�k} ����A�T	$��&�=�,��!L}l1c�W2Sݼ�\]>�g���E�"�i���ŽkOC�n����(������[&��ve�[�pM᫹�F1�T#���R�� ]��~t������Xt�_l��p�x�^��g�:.��U���:Y֕�
�؏�j�0�2�o�僀��0��떏S��{�J��+
VE�n���ۋ�O���yˆ��X���[�j�n!vo�M֠������ �Q4�y<Z!�C�q�n���A�2#��mޕ,�=g=�;�$8��W/X�e�`�}a�3��0	48c�v8?2?{I�G����W�|��������9��O��g]���Hᴐ7���%��K���"��ԥ-���Fbq�3�
�k_����?�_i\�(چ�����!}������.�]�&:�,�{��Lr��e<3.�d��'�u㽘��/F{j�W<�yi��(��{�E��S�a��zӿO���)��u�4#no� �)XU���}]���~B���X�ֳ�r�Ͳ�p�8	,����/9p��@ש^܇�o3>���6��g�{iyE�R#BFq|�cf+Y`���; �b��ZJ.�a��������b�25W��0�vg�B0-d��-2ﮭ�����&��[�"(��G�����]*�Q��70,�A�U�`o�7�PĖPxT`�i4������n?�$yk+��f��[!k]�G�YQ���� �Q����H�)���'NBn��0�Z�G��b��U	�����p�	�fX�c��8�nǇK����=�I�KIga_���8����?�=�LI M�\��Gq^�L��̸�b�#z��~�DxE���?{+����╅���*@�k���c(������}�~.�l��9؃҅z���|�+�21}�-�<���G;"�+�y壔���*1�R�k�] >b���V���aUw�([���qJٮ���t���
lQ���Be�n���S�ڏ$	C'%m)^����A�/���U�����닮���wEɌv� �~Y �ñIDW^%:JT���ͤ2W@�eT��&Q@�x�}=؜=��fU3��
�4�)'��w����x���s�e��>��xz��xz�{3w~嗙=$�ԁ5/��I8��B8�U�
���Ef�%I��6>�C�JC�#�p�k�!��)Tt[�jK>���t��|#������D)��u�f�%)��g�{H��f��ԇK~>�H�;��v4q�D���P���PvU$�!�I|�ӣ�PX���{��_����HgֈY��I�Jǰ�٬�K�4�S|��
���a�D{y,�{��9�U(�݄gO�W�+�C�&�/��P3����p�$y���E/i �������4P��2���ʫ�/���:�_Q�2�о()���\_��ЃOL�{ܑ��)�ʯ�}>7!����Ш�A�ʷsU�^�	n�n��9���Isiܝ�f��8TN��s�����W�u�G�e�~�����f� 8h�L�85� ����-1m3)��bl��b�:�*�֠q~���}��s�� �k
�`z��*� ��X���5����zj4��1�P���[������,�{%6#x��A��W<XYY#������}T���D�sOх�JZ��2`TsRV�Ā4i$�}+)�i�_�����ɇP6c��.����5HϺ05�����b͸0����m�Ɲv�g`;| �'�4�q��@7?mO�2����C�i�#�ÁN�z���1}T�w߶w�Z5K~C|bE�FN*�~�X��bS3[<y�MXZ�QsœW�rkER�����1�Q�]�h���VG$�Y�p�>ך���27#�;�)�g!t�]8l��߄�����Ig��,)�Bx�7�'�`�r_���K�EE���>��슊dUi�g�?��� �p�yl�Yc��iF�ț��_�~�gI�P�/�b,���(T��eM����J����3�|^�<'9H"Zpb�N�c^���~��zz����6���p�7I�N�bՈ[E����GE�9�d�E>QˣPN�rZ�������;7̓7�0`EZTqFoC��9){s�&?��&�,�JQ_, oޢ%�|/g��;��>�f���P��&���8��\�k]K�Eğ��4�E�x`I� ��n�Bk�@�D�W�,.���֬��������+���R�m��/�΁�<�%�bҰuD��Jz�T��<�㋐��J��>��u����s7��"�����LS6 p�k��-���$3(���p�L��=��إkT��"4���ľ��7�S�A����]c�1��A��b�W<�Ej��QZ_m����ձ�	X��ήb�R����O�M���ph;ɢ���d3�7z����'���� >�l�L��>n2�"�9��s�ѭ�1V`�b~?�ou������in�QQ��� (�f҅P5�r�����M����wVƞĝ�8���pi��X։pT��L�+�n��$r��z���ȓ�M��� _��瑏��DC��ڵ+�}x�W�e�ɮEo��+�,	 �.�&��ܙ%n���1`����U��	p3�;0�ųG��@�6���4� �QE�$��zÉ��X�5���q���-�EI��Q�n�=/Y�k�[A%�:�r���u��	�j�:3��4�K�����qt�4l[��{oQ�\:��.�	��:�b9���ei�y��T��Άj�*k�S��7�v�b�W���eY !��@t��z?-�Z_�95ڰ�>7�猯�������(|mpM��PV
ߘ
m�Z�]wo�{����$�ܤt��da��lQT������X���Z�m�h��P�Lwp[�3��N(R~���
�[K_�2�x�m��Z����NH~(�¾����d����"}�v�`��_��}s����%��5�7�:��-]o�[�JV��]����^����s9��L��<ڑ�\�͖UV���HE����2Y��0L��D�`�����G�|�KɱD��9�Iڑ�ix�i{1�q��.������{���s3�9�;�/6��"F�^V��YL
ΎW�+��*/,�*�c<s��Ziô3/��c�7{�}{zE�΢ܷ!N����,�%��J��%��^gy��b>�T�2"� H��J�Pk�rt���[��\��LZ��VIvE%���9�<���pZ�uIJ���-\t%`���HEW�]\?�X�����JÇ�N˔m�O�+JZ�R�d��N��]�{��V�yn�g��B��ܔ�m�����[��nEͦ�v�M�#�ig�T#σ{�qO>[�0���s�$�<��P7�d���O5��BE6�vZ`�[p�#����
��zsOԄډ��^uNp���:�܅,%IVn��G�ż������LqZ�����>���c���L]��#��zE�Z��;���Dٿ��~� Vֵ���6Fx$�*ϸ��~Q���dXJK�e�� kU���m�EF��3�<�������g�2�����֕�ps>	���۫�����@��*�|n�T���JU6��N^o�x腼�p�b�G���N�.{��Q��:,_�wG��?����G0/n�N��iW��*��!`΋�ַ���pzz���fv(    ��O�B�mw�m!�B,������΄���������b�A�@/Z�K��u�����I���X�J�:����KӤ,���/�^�5�����|餘;�]ty����2O�{3�åi�����{1�\����;�t����f�� ���'�&�n%��b�<��F��hi��?Ҋ$�ggh��·����%�k���R7_��ݖ&Pg%;�>�߂�2�NG��/ F���|+���E�}�#$����e�>ϲ�c��u������ڐj��O����$h��og��Ĕ������]�-�^>��kJ�:�o�ݛx�����FP�8M��c���ɿ�ʯ>�LtD�,���݋ߖ|[N��x����Ե� �(�����d��,���)�����D��Yc(a��Bd#p|Xj��}p�g��ń��+j�C"�E�-�T��6��t8��V��7+���Ѓy�M�%ħ�'����%�Ezp�p0;������<�N<�l2/���1/�G6�g��l<p:����	(���3�{�x=e����c�)��޺ӪG[���a�,I��+��]����b��=?�v�w��8�=LfH�O�@E�[���/fo'$�f�5��&���t8���U��E|���5�tqG ��ے�'ʪ:�Y�C/�F��K�𡋐x8�V.*��3ۭ�Ӧ(���K���Y������o :m�kZ�ڳ�˥�5}U�Y��L
'��G����0��	Wm^�W���}8"��D��5�䶪�V��i�����=���}=�|��K�4d�<">L��gF �TXi���~`���Ю�ޅo�����";�����w���E�a{�k��3�u��b-Ap���^\��oT,Ꞟa���G:ţ�v�%MR�l=pl(<sߦJM?�+S�N�5�ѥ���e�Y�6�z4�K�_�,���>�Q ��h��-η�6�Z]�t��VZ�������'òa���6��H�#�.�4���a+�y9�6�4������%��Ȝ"��Į6�h�rh��>������
cf��"~�	!�Y�YU��������R[����+
��֍�I��r����Du�xV+�	��t��׊���b��2u�+��y��F�l�RG )'���#����I����2�v~�1k6 ^�J�;��d����0}a�Dw��͡㙔ӮXǻE�WT�p-�UQ{��gfׂ)��V;�<�����ci8p��!�{֖E@m��DXiԍ+:q�c@����(�2l�P��6�z����ROn(����*�<�	���M��(����x5i��I�#�
�H-H��I�: ��葡�y���o�J0
��B��9^ ���_2���-ocg��N�*.K�ʪ���=C��Ɏk�f�A<A�K���j�a<��lvE���k�(x��t_�Pf+�8:��˴V��X��w��m� e�!�|6�c_����^���F��Ƅ*Q=��^i��Vտ�65��(W{�`�_���;Rf��l��wo�1�M�H�)|��������݄��W5K�(Z����*�At6��m�,��4��_�.8�-�wb�P�i������h���s�>����޺�;�F�CL����������mt�YvE�R�R��w=n(�����^�MI����^��mV]\�X�>c6Z��L���"1˯(`Qu,D+���>��@��ͪ�3R���#Һ��YM&���CQ�i����9�#fye�?��@V�e�Õ�#�"D@R��a۾��V J4�g4�J6��7-r[U�[���qjbT'�Z6n���!}����@K���i���J6
˳Y�k�b����B򍗩��z�U��� ��"<��p���?��Vb�K+l�����d2Z��AQ��pOɆ�hy��6���?�j�������ob��9���Y��A�F�F6ˋ"2+?��]ϡ42�g痓{P`^�^D X��ҏ��(��T�/*Fٳ{,Q�i�����p-�fiQZ����Q������v$��e����N|��l8`d��^��3��>�l\��5$T(�DR|��дCa[�p�����Y�N��D�қp���&���Ɇ�n�Rr�k�e��HǦ�)
�L�d@��}5_oi^^�z��	�pR_��.������j���=�/���PƠ�Ђ��OE@�P��6p��e*J�6�gH�/Vׄն�^�{��Q��m+��"r��H!�!�L^hT����ޫ�K�`=���Y�kZn��yO�U�6�Xs�%�5���rY��i�L̲�8�=5��O�:Zf�0�>���Z������j�w��>���CB�Ȝ�ϱ�	]���]3`2m�|��vЙ�o<vv?�ߥ��˃ȃ�0p�@л�ό�n�#��Y������@Xys�Փ߆r%�ni���|"
�ٵdY=1a��w�%S(Oq��<��<YT���
�u��>#�䙆��}\U��E���0�͓+*U���L{�W��f��gr�8��:դ�hk>�,2�o�#7Z�T�OJXw��P�`o�
�vb�����a�� ��3C[�Ab.I���Q?M6`��l!���4�/��0h�~ڵ��:(��n tO8�1�ǔ&��&s䧙�8�v�t�&�o���B�$3v���Ç������%�5�l��$��HF�0�|�+��^�[�A���E@���8x�B��,f�3j��?`0'���`߆ae�]����,u��S�Iˇ�_���/7Kr�U=!!�t��!�@��xdl�����^�I_��6�pظȣ��Q��hY��fl�~w��s�d�@,*V�d4�Sy+i��LZ�р����b����bi��n��(0�c�����(�.�\i�,A���x�Mb����j �.�uU���p�$�%�q���E�9�@��}_��ӝw�3�<���r���\Z���8!"�)q:�<�0Oo����3>�֭��������vt��qI��{\1��ɉv�3�T^��k/^��{�)ྭ#o`�p���J4g��"�����6��xϼ��-����B��}$�q���5��=�����.�=�����ݸ*θ��\)�u��M��K�8 2��s�q���l�4�
|����������G��3��e���S>�]Sgm�����kO��içfO9������#"hn������$��AhC-B��ZnD��З1�[N��|��^.�tm��Gu�-�x���I4���(��c�2u
��i��RN����O9R��������	1�uK����;rꀼ���i��"xsR�q$Y���l#'����ߛϯ���x��$xY���(��5������|��QIf�IiG����Ḃ�I�2��]��Sړ#�{��a{��x;��63�t"tmN~b��N�r }��E�Y�A����D�[�W,Y�46wς��B��s�!h���^�8�0����e�F��!K(���
x�6�,zT�-D#حMN�-Ţ�^j�_�t�N���w�N�#�͍��j�*���1��Vv�N������q����k��E�#���܅��ǧ�g��i�&�F���j�'C�H̚@-���OW,^��+��8	�������4���z�}м����]lϝ���w᡿��_������@U����q�1!f@�u����|\5Ȕn��7��#a��� �8�9B1|cP�fY���,���)-����ʌ���GM��H`��f[�=��(7-�}БB�ӧ�V{P{�����ت7{�#���ŝ��#�~�r/�I����E��"�ӫT���SĆ)ˆ�΍��L',�_��D�z�+Y��Ԝ�ɅLW������>]�KC�F"��呷E��8_�������"��r�i��,	���"$��V�ݷ��$j��Y�v��1)�u���H�x�����`��'� #�s+��_<k�-�Z�z�s^ɻ��FA�^Q�����8k�;�,�����n^$�m��슪T�o���x������o3����<R    �X9<���T�F"V1|YPFI�>���K^�Aϭ�t���[���g�
(�mV��eZ+�̂�$ �-��
_��y������� �C�¹ �(�m �p����4�3<���Ǎ�f���������B��P����~ޡꓞ�!��p��L��?\q�����#i��O
�����Z2�s�A���"y�I|�����:ko�55w5�o�n��r�i�x�3I�?ܡ�'m��#��Ϊr��I^���Y呡$��O��͋\���)j6)�3�Կ4���E+F��.�'�o2	C�.`�t��� ���Z�r���n�J����A�X�Jf0Qʭ#ɴ$���ʦ3�D��"�*Q�؁/����v�l�O����R�7/tj:�'	��?e9t��!���W�h�Eu�"O��6^�F����E����>p,~!_M&3,��S@�
rd��F,��c�ǥ�I%U��A9q�%!��r��G�'�2��kL�(*4m��h�L]Q����5Mg��u�U��0���^V.��
y�lO�%��t���K��J7k�/%�.|���t6]ΞC`��W���E.)�mb-F��!"r��h&�]0��%��߅�"ٴ͑ ��iMhY,Gw�l����C���>���[�Nc#��rYh����s��t��ӡi�+���B�F���zhKy���R��S7��S�~�^�q�X4
O�v�H�-L&$'��褝�h���
��HO�Oc#ԭ�f�,dB�ج!����h�<��ƚt��݅?�x���=��K�>"�*;�T4^e������{�4	��vJ������-D��N Z��5P�;c��$��I8��q�����i|`syRX����4�b/�rѤ���D4>����|4�賈�@=���.F���l���]=�E�'9�;޵|�X&if�4H�_��R&�XŒ��Pĝp��fFZ>������3���HI�+�����w.�7*���]^�H�yB���{3����ڳ�J^j�s67�_a:��D&)F�7�W �U��>E�F�����k:߅���V)��4ĸ l��jM;���o���jͼ�6Յ�s�;��j%������$*n���w�/bp��P��6\`�����E��U�В�9:��c�>��=|�)�k��(δ#�x��p��r?Hixe64{�w��X%6gq�+�́�=6�̭L�+*��V̢�-`��s+?�"�A�������悽C6�8l�@���JU�wn�a��I�=ie�a�^5Rʌ��w�O�I�]����+�JF�����1�*Nr_�$��#54:̋�&->��6�����1�5���lڹ`�YkuE͊���h�gl�u ���2�B^_��՞����IVɬ���8˂�����!	�Y��Jח�	%b �����G�y��n�u�x����]Ry�E���3+5��Oba-�y���l��;�n"b�������gM����m�=����Qn��� �`既'F�����^�eTcZ��h^�p��Jg�YDV����d�<�'��<�3_`�UR�B����S��+��^8ߊV��W���&�^Ӥ�ʠ/��&%7�X����eb�m>���������a���u�;�(�`�<��?�� {ӕ�����^��^�2�#�5�|b�	W>p����[���ܗ@8W�≲h](ߛ���^��Ov�.�_;v�=���*��Fa�x8��R��`E���Y~JsO�~�*��2�0�M�72?�ʯx�*�ď�(�`�z2�d�e2�ʊ[������׳����3�;�����^�4V�kUՀN��4�G{3M����%��Nd�g�$�	I�}������`FP�`�t����i�2���	5
ج����s-�1݊���A�G�$���y��Y�95V�o��� Q1S����e"~�u��2���]Y�"��V)�Bf�يp���J��U��BK�p2܆��VY\YM��f�#j�0��λzq#l�<��I@�&��LGӌV��O8ʓ@s�젣A �PQ�iDF�oVW��y�Z���G&;�Eĉ�zӇc��p�)!̾��k]A/a��t�y�W0s"�m�m~�܆-Ku�Zĉ�V�,�	��?Z8�C+BPR�a,��0z�|� ��ý���f���x&�ˉ��7ΧM`ۨ�@f��7�y�氘wU�٥x|@t�����o�Дy� ?�;�P&ߥ����(卬��+��2��J>/��ۿ{p�z��a��+�e������7�x/t;w�������${u����t�nd��/�@��G���>h4���()�r�u�}#��kכK���!76i��N��E��NF01�0_��
^%��$\-��}��FV�zxެ�'�h`]�s���Mg>D�D�h�h��~E���z�O�~0�ky�����D*��5nj���"���_u�^���c\�Gba�QPw��-G��9݉�L�p����|��Aʯ��֫����_�CV��U�a�jA��"�N�ՙ֠s<t�
�*#�W��^Ux��иb���.��֝��Ӵ9�u��P,�J�D�l("OV�C�t��shq��c9���_�Wg9�e���(����h�p]Q��bj��<�}6r�&��jͮos�����h�h��.`:���š/1oA4��l�:^Ш���x�����}r/%���)�5[ݦ`�,~A^��o�+�I_���i�dx��$�u�w�8 �[qP�n�4�H��l�t�����U�vU8�ʦN�W)-Jd�[�V��a��fFQ�z�%�ha�J7� �R"m]�o�����Uˣ�k �<�a�h�AN}^�g��+� ! �T��nU��my�!�����]�ɿ��B,���w����Y���(|v7��E��]sw5��Ε�R$��6�G�j�,��t�u1�Te�܊2��|%RZ��dq��bB�]$�E���.)��e껷*�B3��'��	;$ $�^Ѫ�ٞ|��ѽҨդ�xf�u5�VQ��x��M�8�,^dوXpq� ���P�7���s���@�+霫���*�N%ͮM�3�[:VZ�Ë��|�r\F�;r���4/Z2�E	� ����������bE�k� ��Ԥ,��.���ڥ�_d�q��I�g�M))��#��UM������^��O�W�F�|�^��(f �p��IX�}9mN!�O�'�gyH�T������%�v2�RX/Qǉ���Bl��� ���o�!gR��
��X�{����c+}Y���1�/Y���[f�g9��VQD�Ņ^pG�݊�9�Lp�c4`܇ϽR�87k���m$j֫�5�gQ���<0I0"�:�K�G�����Y.�`��;��Gu��ʷ��Sm4�r>�����+�zE�`Bn͠?⒕�;�4]>�r�>\�T,'e"&�q(��A�8����
e��^5d�9��ؿh��\�'��r��L���@͊��͇�lqW�%Q_w�2t�A�>����(jۆar\,�tC��ې2̇nqV��DE��c!�Iy;-�DNe���#"��H�puqOd/��/����+�Te��g���$�`�[�j�!�\���8j�BX�7����0�Pم�����S��ὰ��N8[������t��p�(�����B?l�6G',�?6Ҁ`!�rx�mȡ=�6�-e� �{��Up�.�6z���{r���������q��{>茋8����/�ɷo����0� ϐ|w'7���lݳ��"T�d�®ݟ�wx�'-�h0�|8��.�̫�8xɸ+ю"$�:Њ��Nr��59r<C}nD�5a&�Y��ܫ$���R=a�k���y��{���Y��,��@����@o<��|8��DI���#����փy�UEE�r��9�Q��Y'�1]��x��Z�lP��64����$.#�.���E�a�Woy��7�\M���V8=1a5���h���p�3I���Wyp���[OcD؜/�<@���$�j�-eѯ	���
�w�3��f%�f�PnCH7    �|&Y�u� \�e^���(��]�v!U�� �����;p&��*�Q����]Z4ⶋ��.�NF�_|=�H|ʹ.����)i�_!�6��ʇ��ȃ6�L�4�$�r����TN���	׋�VEV�I�����Æ��դ#�x���p�3��ҔӮOq�(>��xQV!� ؔ���qI�RG>���v>�'1i�K,Pد��F?/ܐ\{I���/dY"�S�x�sG�ּ��Ee}GpB�~�� �'�oۅeQh�j��v��-@mjl�M�����yڸ�m�?� �����0ʐթJ�K��\�.�8E��[E�P�U��Wj$��-��3��#��5���4����7���6d��� t�Q\����CRi4u>�����$�0���P"��H�7ZN�,��L�������op��%�Z|�X(�)�/-đ�H���V�m<�s�����pp9u�qb�Y�iI����C��cY�!�����nA,H�>��]l�u����;NP�i����8oNa�쯙4�K��k�1�G;͕=N�m�4�GD���<�q�˱��c�z�FU\ǚӼ�b��e�;�xܼ���D�K��m_-�Θ�Bj7����fش�:�e\��Y˃/@�v^�bkj�S�M9�)~�k��H��Co�^������;U�&����}n�1�,�c�i���&�"�Wwt
V�!������xEvǼ�4+���wU�o#�g1(�fEU���~���J�!0I�������SS��9�e�vC��e��O+)4Bz�=� Gj���Œ^�%���6�v$�ȅ�l*�/���Y(�����1�{�ܗ���u��vۺ�X%�lW-�9|o��˽�b6BU/x��='�5���y�5�P�"���m����^J�ĵJ�4���6�o6�b�U/������[�b�չ����6V%��v�I�I�l�����f�[�`Jr8f�s�7�awa�VA6O�{���@����Y��ݍ>K�Ќf������\#������v�h��%$K{�ή3�SC��d�:�X��c1�Β(7�����D������&e�:��A���#���!��ZB_�s��C�uM��y2H���nZTW��g�@E����]�Lg�§���߭[1�$��xu��Wc�:ǳ�4�f�(	>P!�h�F���&��u�LGw�Ӟ�V���A2�wB'4�HO��>�i$��Y���a�gM��b�5���/T#�s��p�:��O�o��ݳ��+�X}�%�I�/�>kD�>��'���a�/5�o��� !Ml�Q��6H���PwV$�����+�kaؘN�I}jɺg���_֓��Y{b���}alYȜ���"�t�90���fe�7-IDGz�ux���������X��1r�0�� ���#ͺO������o�3���8��X��S	#��R`pAFh��Ę����"P$m�g��q�]�N0'X����m ����m%y�KZ�M���K�o�QT\��m�[�|s�� [8���e�+o�p9���$�Ċ$����?�J��W}u�o�I���Ng����aԬ��f9��]�RL�(��� �Y�3�H��m���ǟ8c�
V�!���O���d�fIa��}����~X'�}���:���Q��2��|V�6D;��*���/�þy�?!�J�f�����w�M���V��$ߍ;ӹ���؋�K�;��x�k�)n>s�ic A����#]���iIڅ!	~��ý��*�y��D6�c"��l߽�_�b�mr��h>�H� ���@���}����R�O�6�;�%�����iR�:ű�GQBG@�̄��dYu�����2~��@zGQJx��FU���i�2c`e�g��mv���D�C���|!;4Z������{Qn�ڵ�1׵0y�2��Y6L,�{��
���f���޺�r%�+w3��ڵ��%�:�ɣ�s�A���	�#��^�4y y+-Y�I��Bz����{C�����*���<�p����iW����-��$�,ILl��I����f�t|�s��� ��a�݉�q��x����6����k�<w��J���8��"^t������i D��E�%���w"Dx�:���N��mǸ��E\�9���ͫ�8�����W͒��@q7CN^���;m��p|L��X���:!�e�s��::�&h���S�\�u�{2�WѲ
�w��*
m��2�B �ڪ��<McI��~ot��r8�Wn��G|m7��Я^=5}CɎ����)�9��{����t�<��r8z_��{�ʀ�>>;O�J�2ܥ&��8����/2r��W��Pݝ
4���݇2��7�Q?�/��H�cW�G�d��,�d��_Q@XɌ t_F>1��฼L9�/�(3{�̂��4Z4�R�� R<��O}*ع��cV{���n�����f"��Oꉠ�B?M��@�S���P�I�3�y6�/��93 /��nƣ����Q��Y�����������&t�Q�FN;d�Ԙ縏S���1�p�x��AB��H��<��6?�ό�f����mV�TMǕ�@Y&j��l�_��F���h�l�]��Hi\;��y$7
zR���{%��Y���0$�8L��k;��E��|���(�4������#��ؙ�=�(|@!�y�%$�[�:��I%ȧ&�Gwv�R�S���q|���MG����p&i𝎆
���79m�&4��M�R�O=�,NND�V�����G�� =�<o�5<F�85 2���\���yU����!qj$�F��@Cn���۵����鮎�x�;�e:���b��T�+M�'e�0���sӼz�yG�θsoc9bs>I�[��vT��O%���n/!/�X�M�;��z��PO����w��o��dɱ�7�62��˦�Hgf��$Y��>b�U�K;�[�c{�V(<,�ayB�\w[0�FU��8�6�7NE�f�1A�<��1�A�)A�ꑽڦ�p� �\_ܚGj6)8?^ᆯ��*u-�ӱ�������aԳ߫��ѐ:G�R��͇���.P�\�j���#s��X?��Ӳ�G�Λ�ˏr�ũ�����	�ƃ��;)In���F�&�庨>"�JbWsA���8{�H`Fq�I�;���ڗQ�.+n�&�6��H�7@]�Y'�w�0G$�=Ī��s�Dn���ݣ��
2bxC�>�� V��8��?Q�Y@�n�%��^S���.�imE��c�kt�z�yj�KVo���m�a�>�I���,5�����Uf�dY��N5.n�F�Ԇ���Q4M�K�h�%����iř�1���;k����oz��T�5��1���)Գ��!�H�������`WiKVZe�Y�w8��C��{FN�8 �{N�$O_�������� -�u�����������X�M
j��v߾�y�c'o޿���T�H�B�-{M� Gk!A�=�����Cw*Z���b��s��F�̊$�A6������%Ɠ��d>ҵ��^��4tf$+J5�ja����Z(���OR���Aa�ASNs~[�zƁkȗTd|U��9
A�";@��M?����?�ILz����h�/J�5F}J����X����$H �r��j�,������A2�����3=�$��j�ҽ�C�᫅�JR8�Yp�C�&�b|C�A ���S	�xSV��pz#b�f�.��%>Y2I��wb*\�޼}4%�!;A�z�ySH��)�QSu�}ʗ29o���(����=d��d������^ 餺�ۤ��Q��6���*N�L -�E���2�H�]�}4���5��l�'�=�@�_�5Iu��r	�r+�kT���T3d��:�����S｡@�j7j�s[CP
�_C���̨�s�=z>���M:ٍ�7Gѫ4*�=D�&;Ջ�:1���}�[apM|�,/x�UE�K��9?y2�����\\\��X`��!    �� 1�������
X$�Ø�2���:� #�����c�w�vSG�Mo�+:J���)�X)����Ƀ����7�g�b�vq���Ï��%�<҅w']�ݬ	����܉@q��O�؎־�fW<�e羔E����  �Ɖ(vKX�w��ZV��>ȸ�`5Y�
�z�����4Ef���W�J�"�i�NF�MV��*Kg�)�dq��,���MK.�����캕T-1*5�w4<f5��Y<��a|��>9�$bH�Z��̞�3��j5�����s�D���s���V��Z	��=��	ւep�OA��̸/F�����u�ъ�+�S�3P�.����o�������B���Z�Y[@�Bz� ��Kpo�R�|j;�a�ը��f�T �D��BU���K}&���}R�;:e �_]L%������*��:S׈�m����=74�EO�l���$�.�'ey��b�4�m��]�P����G�鴒��\zW��|�YC�u�=�D����[
T�&�]�<\^ *��u��5��$:��^Ř
�>�$P
n_V@�i9Ep�hF���R�}9Id=hI��\��qz3L������\�so�O7���gUX	�������t9�7����Ӧ��2���d�J.-o��
��%�S����&2�Z�FWY�k` �Y�K�,��,�e�j���*�8��x&�m�<�J�lo�M�y�I�]H"�C	�4��i�T������᭲+
X���d����n蝐@���:\q+[/�-�UyS��Q�i��k��/��2����������+���x^�����~'*5��1��⪸�Rnp��b��?1"��H�1��a���P���mۭ��P�I���l�W�7%U��R�V��j��SW�������+jQ�%���3]����3���=1$�Ԯ��mV��#~�o���=Ə��-�9)�0��xUn�g�8��<
�	qq&�x��^�����|6�@�kb(�+J���z�����hD�)t�/G��B�t��V)�_-�5�Cl���Nh�"�?�����,�l���Z��r��.������؞�۠�ژ-(u0��$X��HG�&V��� � ���Et�Y$�!����U�Imb�r��J�����
�f��t����g����.pl	��hoL%�~u݅>���G0�e�V�'�G���cC>]��v��
9߅�"�Z�~@�>��Ig�b��W�0�u%LE�j2O�̮�`���	��"ttq�k�(�p-��]T�h��ų(��A�c[��[��[Y�0�o�gw{��N���D�۟s�¼g����W7��*�WT1)�@=σ�!Ȼ�:6��-��,�LI�`�iW�@���` .���ЉQ�i�e��JX]Q�"�����ǵ@�JmSI�C-��i��Zǆ6"� &���ѪuE�����ϼ��k3�2�a�b��;����)����n{S����OJ���_Q�,/�Q��3Rc�J�����r����:�>S���FRļb���
�pz�ֵ39a��dԸ�խ:�Ƌ+j\�<*f��6,0��x�ZR̵����W�ahU�ë�&)��ǺUM��j����j1i�9�+
���q�ш'r�N�v�h�kml�c�4�d�%�9���0�6�tP�V���enD�˱H�wzЛf]4P@r�B R/J	O�(c:/	��*����R�rvEŒޓ�*�v�6y3Oi(�L"zu��r�%���X�n�mܑetE݊�/��,��=���j+a��4f��z_A8@�5%cap��%ٸ��@f5�E}��_�G�o<��yW����	(s����S�N�|D��<C��bd"vj�@��'�e�������1��P�2���i�2
740L'�0b8d��>����%6�!BT.��q#.�P/b��T�AM�§���
�3/���&e�o3�N�~A�!W����4P�2�yL3E��a�ִ�D�=pW�tE�$6wU�ϓ,����Ԑ���=��D*\C�B
��(l؇�f9�?��yf�b+E��sL��W�wE��t�x82M��"��$��ӝ[wP_E�۰WzwQ�j\^��U����(��U��ai�-���u�Ҝ�)��&?��Q9��-��NW�se\ͬ�)�@cj�[+�/H;D_�#��	���0�q5,Ċ�>ɛ��Ҩ��;%���T8���d9-+t����+�����nF�X��rr���!
7�)	2�e��'ӕ�������+л�ݹ�T��	)lr\�'VSN%OM�$y��.[]虜��v>o���EQ�E`�Y�~u���s��I���6̉��>�Z��$��t��J��I�p0T6�����6;����"7��J�MG�����4Q������{%.�ay�J��|�m��}���iP]۩���zC_!��l��B�L1�����i+�B��M����G��8�u�^�Ww?<�X�?�r޽����?������{�	�/�k���S���( ���}�|(����/ ��^C>��I�M-�A-7�oCr��!�'������\o���(���H� k�{t��"bs�ޣ��e���5��0E���]J�w��v�E�W��*sr�qȚX7���Pxg�>}�SJݟ�?j�l�y�.����|�/!Xvf�|*�E���b�'�`3�ߘӷ���~gI�ۜ�H[h��rP�iu��r8�eIbN�IY�4��j��!x`h�칝�G����}��v'pz���	����9����Gyu�e|ܘc�����w����gO���J��ۿu��	��8�d�]R�Ӧe�X�)���JwVل\͂��e{|�����=�7$����%����~q�cB�:J���r��@�*��7���Ĳ^軨���п+�sZ�2)y�}��d!p���3ݣ4�W�.ݻ�qu��}f>�F>o��_��I�������P ?�t;B�ʬ��Y&��/ODO\ԝ��Y	�t_K��J�7|���#eP=��P��+=SE֣�(\M�h]���?�:�ǯnǡ��eLTe�����g�L�B�Rb��QK]︳�������p��I]ՊD��7P��=��
%r	�����ğ8�1���q<�3��~g2ח�N�uq'tP?�_ {��ƜZ�JZ61z��p�\\�m��c�IS�x8���~���=2�����VS���������U-�9�H�LL�+8�Z��)N;4�v��r��j��*��Yi3w�~S,�V���{9]\�]Q�VUt�j�*�ӎO_%�83d�#�.֗�{�������?yji�`/ݩ]l�3��*���s5|�Ʊ�-^�o<�ټp8�hƗ\*������z�̥}n4�|��{M�c��Ǉ6iW�V����8�Oy�� 9H�=��!�e��A�B95O�Kߦ[WR�Ze�4�8m_P_E�yZyD�K�M[T��6b�h�]K�Awp	[$�MֈZ!J�������#���[�V�ứ��U>��*�ߺ mw'K�f��[�9�Ç(д��ߨ@5�T5��m�|��T���G�=u�lg�S݃ui�S�����ˋ�l���Cc�Ό���=�"�{DJ�q�-���*b������l�a������ٞ�|j.�!�à��}ģB���U�ׂk-�t~�6�Z\]���s<�6��:|�Wy�}%�2���58� 8+x�P�P&+v���
+d��-(����w���������骸��y�z/�Uew$V�{cHz"�=9��3_m�}4�����i|h-�5��������OfyJ��EBP����V�W0I��"}�S��}���5��28%���`���P��W7<����%��1��+�_�bK*f�{�7����K@n�հ�]���������Z�ỗ$���v{�80�"��r2��u���Y��6�._����? �lR��{�ề$ϓ��,	>�4��ܙ3����+@hC֩�M|ٸ��)���
�����Q�	���4��s�t8��<|Y���<���,�    �Ҙ'5]�ϧ��Y
�LZ�� �� 7\U�/P�ɂ>U4[��үZ�	=ᚠdȜkH��N�M��Jݦ�t�D�Р��Wd����W��wl h��9bmB�CS#�������o�CS�ѫ�Q�iY֣�P��0t�e�o�"�W_�T�R}"I��4������=B&��BboZ��hG]=<M�<�Z��Ol��{�[�hڄx���c�s�=?�����tV�m����,��5\�'�l���{��2k�R����;��Z&B������3���6Ȯ�p85�C��n�Q_�ξ�J�@��bB��[4�ꅋK4$>F����t�����n��ȍ<�<C�V}�fvF�����:��n�\n}��s,,�76
����E�����&�=F��ñԴ���6>��$��x��l��^��>�� �Á�l��K�
����>���Em~�h`��[��b�(�
���Q�lf�
|Y=�s3쬫$�G(����<9�O��d�u��q�� ��n�ݿh�lB�i=1�+�p�.K�<�&$ʂϲ���oH*)'++�N8�Q��7��7����3�����!�t-4�x���ei��	��u��n
tIO�9����s;`�U��A*i�L��@SPv� ��|���6�д�?�r>SA��M2A�d�Sk9-|��<H8�o��䔌T9SV�~(�N,1^$�n������.���9�3�T�٪nr�Σ���y��x�R�jM��1�e��?=�B�.��>�	�K�샛��߷��ɽ�m%a@��x���W��v֥c���D������_Z�ɞ�}g4t��fy7GE�]<�E���a�F�9�n��ϭI�Rx����m|���P�i�����լȒ��)��\�����:I^o� 4�6��S�h��fKcr�`7����Dh�w��#>�I���h�p�5++[�FG{�g��$���yj��,��d�.3�j�w�$#��%r� BI��X���!�|�E&�L�Y��!�ܻg�,R�r�'�Á�c�-WG�Â`~T�[Q��ďUnG��$C�㰋���N��2�a�����>�����_�EzQ=�9�t���G�sƁd�ng)�G��\oDB�l�Hh�<$<Bh�� K�1m(�}c���+ÿ��ٺo�,����D�7T�Q7O����ɇ^H��wEZ�B\�Onu^g�p,<�L6��Q�	O�'b��G��0?St!�W4o�g��SO���WOm�2·��yW^��{��tn|��{�8?Y:W�(ʹ�h2��p�;O�;A�|~���i@�"��I��Vs�u=*�s��{�l����%s��,��ӕo�X� 5�� #�U��k>�΋���3q�h�f�M�t4�� �;�e	�#w�S�!�f,Zn^A�vШ������̍Q�ƹL#�\��_d���P�����i�;v�LQ�x����f/.�J�FQ��В̇�ۅ�5���E��]�����WH�mI��-�@�������y�5��\�TY���"��7�1��7lQV���e�o�p�Cgm����Q&8�,jC�Iw�'x�7��t>	�N���Z��I}>/�*.��U��(K���!��f
���7o���3�.-��i��� ��p�H��ؗi2s
&,4�d�Y���`��cs�:aJ���?�5O�7���<M�E�?�A��Cu����n��y��3��I�ٞZ��Y`�b��н{�{k`�[���B�~6��;|T����Ë"��W�m����#WP8<�ɗ�`�&���٨R�N�$;m`�,;'��7b�E�D�
k����r���.j��f�/\S����i+��U�_�s}zh	m*ͳ�FA9q�\\*%�_m�xU~m�$��ȡ9n�u��]�������sw]�/4��?���%�rex�ަ������\9l�{����t�6��F���vQ�q�O�$�*����9�
N����G�[B.[�@������8��3�~S�A���w�x��pp������$��X�E�Kә��-��Z���]��h�9Fk�!g�`�^����&=$G#^χ�e�fyj�˂w�o��>�EN�O!N�Ӻ���'�G(u��>�i܆��|8X]�e����}/$H0 ����vU��6R-n�-�;���E��
Z;���6p��p�L���7v���^�e�$����
�M'�O���(~��mOJm�F��M�>��']Q�,KL��&e�V�I�|LSU<(!��,��X:}�%��>@M�#B:�!M�0�����y�Q��
��Y<n�ZI"pF�slTd�ys|�X��Ⱦ�sŬ�U���`&]ԏFS\�Y�2�%V�tf |����6�����J�V\)}����P����s���o1�-+7AWV6�H�'�z����O�,��>���A�o�Z�[+�){h0��?j�Tp�+7g{�wƪ1|���1({ҿ�` �P��6����*�f���O �S���­���~�/
���c(�ՃF�@���*�b���i�c5�VY]c5$�hvf��ˡY8�A��M\f��cM�\OB4r���Rޑ�����6���A�*K#����h>���ߞA�T" w:w���3��l�${o��S&�=;�j��N�8�⦷��]�[��(#���6"�ss���-MR8e�jN \�
I��.���ﬦ,Z����>4��d�b.����YjQ�i6~��+�LYB$��y�*��v�_�	ي��j�ҜLG:�Z��"���L�2�uR��d�Yd9��IU��fQ��lB�$W��0KX4�|7��"�%�>�׮ı��ʮ�{�]w����;����P'o��e<��b5�xy��xI��Įlp�+�WN3^]��l~9`�"��5�oc���YG�?���ˑ���أr�]�Yr��2^�*�r���,��!|�]��#{�V��Ɬ۞5�m��1����l�m�l�xp���Ǿly�wn����I�s�9�z��}�	�Q��6N�e2�`qZz"PV?���d���d<Kď+�ml���$�gmf%yu�j��j�m��_���"����P����*�U�γ̆W+�
edU`0�_m��R�7$`����Kd>k|�i��=c�����P�|&���ˉ�yx�*$����LJ	�G�Z���U\�y�G�w��K���.�o�@�\o�`��w�n{�l��� 1�ƃ(���>�7^��U�b�N�8�Ё���]��(H-��Z��f�%���ʎ�#�X*���_>m�>ڀ��.vgb��<	��B�z�ױ��KJ���}��>���ݙ{����6D��zx��O�) yʔd,��ǯ����R,��#bp� �y���Jn#�{9<�(N���=�,0e��ܔheHo�w�L��,*���E­�����Q����e	�Ơ�M�=�����%���g��/�m{�,�I{�����T�����ɋ���ƺ�ţ�bm�� @��_��1?��ԓ��qW �q�!@��R�$ul���
5�P��y^�w��s`���uspא����^�1K�pG(.DB�h���AT�l1�Q�g����B ~�� �,[�!��=y��M�L�^ӟI��D�$��5/Q�{�c��R��]��HO���-�H@�)�D&P�#,E�1��;�e�h���pd1.�ԓ<r7s�&����1�Ao\{X�ס:�j���F��С����zy��	&�V�k�7tr�V#܌����l�	l����M>-�c4!v3FLfY�ע�,��:���/l����{ߘ������`��f�X%xz�j��ӫ��!M��al�#�IT��'���4W6al#ȝs{Y���"�J�T,!j!��;|��ף��p�1�{ q�i�qveH��z;{wM=��L����.C����F[3}L�)�Q�"	�X����B��_���e�/�Rx�1;� �|,�贀B�=Pɾ�a��N�0ٽ��������ǰ],.�%�rć/����    �/�����,0���g#��ej��X@ =�=/�0)�.t<���*5(ש�?��{��!?�IL��5ko0�AGQķ��m���I�H*��w�?�~�H�-eB`�8Lgݓ@���H0����zi"��	eM���c�On.��l�-��G)����
�OyG�~���F�=�J(�^'w��Nz�F�����\���ҧvI6��ߢB�ԹZ�:�!�?�3>:����f'��X��q��15������O�A0��ۆ��Z�g.�eU@��h&�a�G̓"/�v$~g�៚N(c	�:�EH��`�O�<&�̷��ћ�Ѳ����"����;��S�Hocn���IY�^�Y����wMx�Tt��G!�׭{�K|@u��]����,�%�L,4�@�^�_�kp4񒕕�� ��ޜm�'����f�_'������m���x{�����3�5J�O�f�'�A���AY��3 �Wݑ�_t��P�+~��K@��6��ꊺ�� ��
�I��`y�v�jyo*ќZ/����~eK$;��b���L�8���Kؠ�3ޖ{��4(��'^zt7�k�c-,�2п�='s�
��I�]R<�3A�{P���`���Z���G��8B=���}�`v��vN-�J�ωTd� ��k.��
YSg�i�>c�Vs��{��5$0%w_�]�6�\�#��I�$�r�r`��5I���C�{�r�A&�ō(����)*��,���Oݛ-�m-Y��x>A��R�-wK��Rŉ�H�E�H�M�*W?�������Q��Ӷ�rU�;s�Ċ��~��_l`[aA$�Nx^�p&��p�>M�̻��n�=�Yr�iD|H?> ��������/�F�C�f�}�i-�ǻ�;�UV�$�L� �0��֮�K�XHȡz�?�yR��h&C�pl8M��[_�Y�W5����f��}�<����^�zO�xi�������_�3����F�C�.>�I����MxG��ж�%�
�]�Ro��Q�������h�|^�w�Ta4��2�Ǿ{3%N��(�+1k<�^`7�F��^���=�DB��=�t8 	HC3 ��m%���*:��Ï���<v�پ�X�NW�<x��A<R��8]�e�ۆJSo��i��	:��!���_	���*4��G�<���ڋ/f����8uKb0~�z�LG�����[8k��PY[���E�jt�>�F���/��ޮ�h\N;�����w<�i���2��fs��.f�'U)��D�I�JQx�}Y�k���� �!�Ӣ�=�D��+��}�5���k��|�>u�jM|����8��A.7���7EV�xs�嫶7C�S����Ԣ�N���@,�o�<�K���[�,��m=������������nģ����� ����J��c��|���=�����g��{�c<��^�v��(}��ad7k�Շ��5ԫ3�}�Lm!�u��1���-d�L�"�.�+�>�8MWF#�@�vo.7�$���<8����In'Z��[L7Ol��?ݣ�9|¨<岽�PMk�6ރ��Q��w��b��[�V�9B��~����	��E��1$�i_|c��M���翹=.��bU��=��ȧ62����7h5�t-�[>�C�|O�FQ�I'�{�;P�(�72�Y�%���!����4k�*�s'�2T}T��Po��27b)�S�ɔ��ט����H(��1���͵��];WӮ���߯�V�XߨӸ�=qͨjU�8#� ]�O��D�m�{���r�6��&W8Yb;d���ſA}��Nnp��HJ��P��b|��f�h/��G�f�v���˭	�j�e�o�B��QBt�`�V������j��th��z�/������'6��6ms�[�/UP�����u�=�n���׿j�O�<)1�\')�����B�^�墍z2�j&T���qV�9U�g��c��|$#;*)�����ū�V�8y`���2y�'ժ~��L��.��tT��丸i�}Vu�7�g���g-�윰�	՟c3��°�}XATm&�{s����ռ�.wW_D� ��������}�@T��d��rp�8�G���h��`b�T�U�N�F�-�� Lm������}�M1}׭_R��I����i�����V����(�3~�(���ܹ�n������z&)|�F" ���g�h`�`8�_�ߍ�H�	�sV�#�{���I�͍{�O<���4e��y�"W�lR�LB<���m���6�;�����5�p@�?�I�[������#�}�T�z�jN<�f�e�EL�Nd��O+��e�b&w�~1Cff�_a��{oa�}�~�}��k4qqFw�ɽ���)	>��\��V�!֛Rߒ1#Di�Yl�0��4E�7/<ji�j�9c����H��[>�2�z浆�M+�F��pt<��$�����c���[�ޯ��{�$Q�;�i�y� w��J�:��`n/V�(��2��J;��u��V�<� �5��yo�>9����\��hס��|������9��o�}��(��JW_�L{ҀH�F��i�z�P��?�k�{{����U4���o�݁	�xf��ۄ�A�,O|�S�H�:h�4C�rwU��t�v�P� �����ܢc�����n�9�P�O{v�3U,P�J�$�%w��k=Zq���YQ�������)�*R�l��0|�<(L����\@�Ӟ�WY8m&�x��p9�¬�k:
�/��Yhj"�{��4댖�+U�O����Y�49�F��U��|��#pΤ]�V��s���ã(x۬�+yR� J���n�q�h`�>�IG�r��9������	�LJ��� �.*l}yjQ�I�bF7�p�����̲(	� 2�$�����Ɯ�q-]oG�"�NL�����P�Y�%�p8���y���*� �%kQ���P�ɒ�k`$J��hS�آYw���#�&��K#��-~4�t[���#��z��m�YU�He��m���]WX����h�~m����[���&�n>�Yx�5�p�.w}t��<�!�G����� Q?~sf���;����{M�+ie�2��g���
߷�dڱ��5c�B'��j��@v���+�{ /�'Qܬ�uK��8/r��2�	��X�Ұ�}��J
F �� `�\�e��[�tͅ�o��?��5�!��qPѵ4N�cݩ�<�r�;��ǖ��o���C$QԊ�rӚQ6�Un8�W$Q���a��O�3��.����^��:�&��]3��xE*�J��(�/w >�^�U��E�Z�{]�]�(�!��V��Il��@a�fel0B!�č�4��e�҅b���3�j7�>w;�;���u�m���E��Ƒ��8x��B���%̐TY���Z�)<`jK���� ��~�}M4�+���f1�8y����W���0�o�����܉j�&�z�j�p�b�R�w����*6N��p��
}�ϵŏ�bv�����'6o]��Nb���X���l��-��E�ev��Y�i���_����s�'4N�O�Z�{�f�Ig�eo���T=��Yxb3��
ڜ���ҧ�k|��(�+���m���1!���Gz�H�+�8�<,8�X� �΍?w�""�[�tyi>/�����5��[�N����
46��X�~hɌ���m�����;"f7f42��".�կ�}c��_�v�أ֟�37a�faf�}��R����
��v�����[���������P��e�d�n���-��� ��K��H,��&�l]%�E�@�i�m���ܤ��#Vn8>�^�$��|)�`Oxm|�|�.�C�B�e}�Py�O} ��*�ɣr�zZ��UnyG�̼=��
^I�hC��QN�y?�S��j�Բ`߭T����8O��xYPú���{�{>>�I��l��X�0.��<	��B�7��n&7�1F�fw<�7�S����q����:h!�"!�ӌ�yrD `�%�OKTo�[�Q߲�)%��o;�y��^�dD�    �ߙ4��{6�
?,N��_2�@7��;D-��GvfI�"@��B{{�>�B����[dv�'5�:W�FZ��(\4��&��Q�*�L���W�#�=/��>*�w��%�Rt0V=aR�.!Wb,B�`����:A�F�k4B���Q$�Jtxb����dtj��)�J'�-�3���NOd��M(dDS�C��������ب�I{v��S�Z{%��c��B7��DD�z�4f[.��\Q�#^`����f#V�*���P6��ju���t!��m/���I<��&�6�q�ؐ��yZ��~:��zAW���J��qO�� �3%	�G��y���pH�L�EahC��q΁k���v��rI�N�~VJFgo!d���q�@��Y��;*�������1 ��l�F�*�=z��0��qW��i��h��J��K�(���2�Y(l6�9F��o\��6�J��ܩ{�`���=���!��D~��K��p�թ��< �8���Uؿ�e`��xG�{U�4�@��,��	/�|7�K�aL�,��N�����"Β*�� zp=h��=/yr����pg��K_���o�t%7�/�S�y���`����&�q��E��wJ7��\/:�^[���&V�`�����
3���(xť�2�\�+,5W�%�*�2�ͭѹ����]��=�賈ll��HuYD^l��q@_���|�d�xX�۬��� 7{�=9�W�]n�u�=n�u˖OW�"p8m[�&�I�F�hL�����E���&�_��*�"$����h�o �y3"�D��7k����]����0�h���jY�'�F��M���3�}��y����CL+fծ�8Ϟl���Oe��xyG��,�ga�Vw2�b�D���/��X��]g	U�эl������=p�nv��:�<2e5�Q��r��p{������@LI$�{GO�$�=��kMR��.-�Z�	�t��nɇtM|�Z����7n�2Ab���vѿ�l���[sm��~��D�İ�-����q:mZ�h|�x8��=s��2�"��J�d;�h)�[B�rO�	���s���~�k�/н����?�a �0􆴘E�wG\�(�ش
��A��;\&_9��@Z�(\�,���In�N�b)��7IB4-�:�A�h�Q2/��4���,^��6�I����(G�*-d[p+�8��GGv57y���7At�Nj�d_iڢ�}7	tb7)$��K�g1�~ɽ
o�l�g�q0�VYXF�l1=��Jj�-[6��c�-v�^��2�%/�j>#�&��+$~J���4oD�o��H&�5!�UZh+L��1�@��r(�&����r�B΃���*w��� ς����)�⍴I��9M��!u�I�|_����?����f�)+Kp�Q��Ż�ö%Y}�pk�ib�h��̓��H�H��%!/�Q�����`�1�Ƶ�ȀV�i:��JJ� �6u�]�W >�����"Z|F)�JQъ>͙䜎+�3Gq��i��GɊ+���9�O�-ߟ��H얒jI��G��$g��w�{�c~E��ڼ�/�螒*\x���z�Eϻ��\�-�q8���1�R;�.�J�Ɣ�`"���	��z��YM���?d�N����Bl����y�������(>N�Xg�먪���A?�ufgO���2O4�a��[GV�{@ox������lM7��4#� �p�꛿xU��7^�$I��>Y.��Yy�`eP#{v(�j�a�����|I%��}j/��^�W�^ZD�-A�*�l���'N��C�	AkdO�D:��M�_��/�M���4�G5�O��j�ë�G��0x癖�H�>������a
?%�R��^Y!���?�,P�z������J�F� HU��UuS����Q�t�-���;Li�Z�ع�Nx����W�[5����y�>�S����hu��ױ
���q���Y���B�K^]��n���I��w�R����DaZ�]i.��>��vЩ�IY���7y������uk
�kGC)�DP�i�c�h�[/\T�����북��a���	���|�� �:�'/��Ҭ��&Ɋ�ty���XI(�̓*��m3�Ǩ̴Vv�h�i�W&��Ⱥ�<^y+� �(y��`ګ_}xĴ��1�(a:�΁T��ْ�E�%]	
�����t3��y{�]^o�gQM������,##�sƛ�j���٤��`<�^���(m���,m/mQd^G���Z�шү����u�!�ѧ���̔L�+m�h�ᕪ��3h�
a{6@��!i��a4������J�F;�xpe�0+�����W�BU���fܜ��"��/���d��ӑ��D���ؓ�~��&M2�tq�z�"
�,ucQ���}vg�r�E��_֝7r���G	A�������M�)���_=��m҇3�����8I��VE�#�č��A��d�3x�qp�O��E�+c�{��4�P��z�bR��|���칋7��"	�zyy/Ă�9�����d�e�(6�R��X\+;s	+������Y��Yj0v��G��H$
4�֨�@�ᶸ�3�̊L������a�gͥ,����޽O%}�~�Æ�,������ѫ�<�/�4�����>X5p�Ќ�����4�Bͷ����t<�t�]�}�GV��#;p]�����q�Zй�����Eݫ-�OR�5�X�[�B1Y��RM�1JR]��pv�<��nJ�zA3-�D�ֵ���E�Hc�����\WuJ$���=�v8�A֤N�f[�'l8�5��a������FS�z��%�7b&��p�3vW�5�E|��;�)��[��~�ēQDxZp�_�u���������.���r�m&a�{�`��%)V��PEJ�W�ǳk��z�����籚h�ÕIT��WE|s�;����"�D-S�߁��9aÍ���h�.�@����+^|J�To8���.�W�j���C`�5g����#���Aq��й�����&Q��WYk�[Fq�YvF�.��~1�lۻÎ1�$$�;�������gʃ3�M�,ˌ�Y��o҇�S�\��*�{e�M}�4~�V�D��'�F�-��Ť��l��K3N��{(��ߤ�HC�Ėo��&��!aס;)w�.��pM�a�ވ!�50K�Ty�>��4�a�HS�z��x�C�8���W�mP:�U����%�	�a���gE,�������6)l785;Nʲ(�(����wa0]�W���S��	���@�wִ5�~���lU���	 �7-/r�gp3Nݯy�D�o[�a�|�!��;�^/اc��3�o�Aۚ��x��d����(O����\�+z/�P{��I�H��K������|���R��hr���aA���l�-ĥ�f�gT��d�`����G���Z\��i7c��������!��߽E���+L˚��_��q���wԺܾ��32Q��&���Y��re�U����fѹ�V,2�[wb�I<�	�N�+��M�(j7)�.�<�	�E����U�H�:m������FD�b�M4{*�Rov�P��̈́5�������PS�Y^�f-L�����������յ�t�tUDC(sɣ�΋�>�I�9�d3b��(���U����lO`�d��bKH������A¦Y3S{/+�*|�!lR��f�Yj�o#ÒP�%�ܰ�E%��(ʴ�Ѷ\��eed�*q'�Ed�޸���m���2Ytl^u�R�-|�Q�x���p�2K��oy��;!�\(C�{�_Q�2cl�(�P�
�1���'��՝R��e�eUi��*�q�~�d0���h��GѶ�'�l�����o�PO/�F,Ã�5Fj���w���G�����v���#���9��Z���ki����I�wv_@��JP������pv�?��TBWAY��\��>7�{ϳ�Pc*�mq�I��zw��tm�4�U����?6��g>,��icb�x�ww1��]�$R������g���j��!`�w_C��4�Ѣ� �    `�	G?v#�5;�+.ު_�fH4��+������i�S�l����;�`��ʓ�+E����k��k��b#�I������GY����>`�����RS����>�޿�Cͦ�|��y{M�W��x�^x_&=F#$l�C�YUyKU�Օ����EK�>udn �~�֑���d�a��u=>-N���`��;�:)%2����{Bl� ��i�zݪ�������〜�Z���W�/>%J�� j�Y�����p��`)��_�׷���vn,��~�a�7��/8i�k[,��09,�E��!#�������%�r������P�c�za=ހ�8��a�Zq�B�L���Grn�an�!��f!+M��`k�����nt-�<�(ɝ�9e=�O�B1bp+�z�եn�	�j'���NC��޴Ng�F�'8��8>���4��Dv���e3J/E�,!,���ӵ.�}��Q���B�a%%6ŋgqk��p�6/��v�y�ծӼ!��m=6�#U�F%#ݝ5l��sO��H���*�۶5s�pf�u��pxk�.�s�?�8]+�w4k���2v%�
b�B� ײ�yv�ߦa�h�f�o��C��s��
d<��,��Ժo�VLK�?�U�������,��Bbj���?n�~i9ii�o�_MY�"i�>�w�w�,t\i8�Ϋ<��n��0�ˍ��P�ܳ9�U[�V��uVZ�an�sJb���ٙdU�VG�t�$�34�n4"Q��8��<�6�莥���,�B��#I��D��q�T3�~�y�O�{��AI���(�W��Ľ�4����,;��)nX�IwkI5Zm�#ш�2�@V�W��J�~nTc 1�'w���7���P������Z�@�o�iz�&}��;����E�z�c�$m�j�̷1 Eu�?C������tZ��h�����LLϘG�h�+c��g�/�&Lk�Ȇ�>�_V�G��_�׽{�>8]�  �=�km���F�@n6�_׷zJct���^\.����  ��z��������^�qne�|�l���YSXm��b1�>�F��?S1�w-�ǳ�kR7���ҾE��u-���9-�	<�/�N`m�7`�Z�ɬ$v�T�?�ɞ�| ���EU���Gq��\�4��}"^W�ۨ�Y��9�S6�#XO\�\���hs�Gы�����0Kb�Q�$��"��=��@ �q���b��C_�J��G��(S���{���R���q�y_�4�MӇT3��i�6J
�~�{�fX6�?۳��mw*��0��Vh���Y���ݢ��,xi8<.�85uBe�W2p��)������W�M]��0�$AI�}��X�ޤsY2�J.���ʰ��|�0�	�敐B�W�Ձ+&�V�
�~`�e�~��oIٱm��>�U��p&�`��FÑ��ux��GE�l^�:���^ ��� CA��>K�9&��FS��p|�,Ҵ��_�U��j�)r^������B�)��1�K�8^Ϫ%L՜ֆp��v8)B��V�����M�Awv��3����g���+����U��Tx�0� �vo1P䵱Gv�*or�B�Nj�hH4���4�.���($&�Zi�8ڷ�F������a�;���ͅ��j����5��(fUb/^��6�2�J
F{ʧmK����Q�h&�p�rO�Y�q|u��`��2��"YF�F��%��[��*1��ʁ[���I�J3��)8(i<��l8�Yeyޟf�v�pmÇ�|�
b�oa����	��h��޵�m���	}aA�}<¸�(+�Q���,̒�h84Za���q�.F�����	=�E"�*=ÒU�vC3��6߬�4)|Ur���([
=Q_ēWƻ��Qs������yp�>���ʳᲽv�餉���H�h86ZU����qal��]�?�:4gZ����❰°���5�FNE.��	M�~&�Um N�1J�ğ}%��X4�ۓ,i�O���z�*#j(�{dj�3(N�iU�E�Lz�7���,.��;�����U���� +��G��5����:Y�+d�$�ܴ*��N�fx��[Y/���q�����XV S�'l	?Y(��(�X�a�GukJ���Pv�S!�U�
����s?�]�g�D��$��_5g�&�'�����0�)F��p���~n�!���%M.�>�M�7�6q��x�=B��f	�ؚ��&у��4tX;��C����Ҥ$t����Xlݰqn֌1ӽ"�U��/K��30&@-,h�}7��n|u<��<6��f�#��yb�G#w��ؚ�����f�"w}�Ѝ�b�S��IM	,�����g�px]#m�|y��Mơj:��)�_�`s^]�g�����qb�y��aQ'F+8��s㙡�vU+�7�y��j��g�
����/>�U�/[��]�I
�M�����%"�򝳻fO�Ϥ��x(o���;1�Կi"��i�ʠD��wi�G� vyj����o����7��,I��?�܉4N�1N��?dy��[8(ڕ��VZ I[�U~�[��MF,ѓ��I���Տ=O�l>)i�/aR�~�J
��v�Ö%��^ە�c:n�����V-f��PiQs��v
�^�t�N:=·�4�#��N����D9ӈ��>�u��q��,4�i\�K�U�$��u�7��D��!�&?�����a���`3�@���1S�^�2�9�g4 9.���*OZLC�1�>�Z�_�R����^��Ű�[���-��(ݴZ��jx�4ɌܔF��z�GGez���M���N�}M~�M,��X[���q ]L̶x�5��<(�q=��qX��JN����r� /�n�e�}X��FzS	SO̒D'vn.�Ǩ�o�L�>�Y����rx��8�m�HZd
�	�p�5}�5��53R�-ȋ���4~X���<eo*�� �-�J�k����'�k�6��n��g8R'��!�i����,_����x�(��ڦ��G�:�,���x8&�U^�8�f`���vі+���A莪L�*52��]Q��&>2H���"q���ދ�8@��l��0���5��6���fE�KQ���q�c�쾼v�:D	�����&~ݶ�r<��4�U�E���(���:jq�S�J�T�̦���k!	�i-��Z<\�,B��d8:WQQ�۱�\18P��4��n����xw�e=� 8�< MG>���ˀFI_�!��О+ X�����[�V��Pgfe�/�*��f��ª����ʐEA��=]/±���U�C+��8�8�f\y�iqʍ�t$]}��PW�?�=6�.ݥ�8b$�?)0��>�$-�*��O����Q�6�fy)���+�u\�ㇰ�ڍb�p�9����&�a�$�R���b�F4����C�y�uS��lo��x�^��i�w�eڽ4���ݷ�\����	��Q��%BB0W0�9ʟ��B�'f)F5��c*uw��RhP���'MбX�X�X���3b�\�(2��H/2�Y��k�dL��_��$����&���������aCnGc��qB�x�43��5m�:U1�'Ē�X���j�j7Z�/���/͟U��]n4�%G2\N��	�n�h$v��Xմ�n�D�N�������z��qn��CsX���YD���p�8)�>�RN��5]k!���@�ORvة�p|��v/�$cш�ynD]z�i�F��P�I�����p�9��$��&˂Wtr��2�#��pޑj���㜮�d�<x��p9�4��Y|�%mL�@$YK��M�t�7�&��:�,���d8H�Fe��"C\m"��-`�:�������6=7����J���i�u���F	`>ਥ;���l'P�I��дd8���e��{U ��U���p-���:�IJ,��W���j�sз��ǧv]�{��l�x&�X����)I�C�iǡ�y|@�&�����:�=�,Tw�(P5�R2�M�"1�2��8&���,�[3���s�x�X�ݺ 	�5c*�F�'����N���i����q �,Ҷe    �����+<Ky �^��ԗ%��A�M�c�Y�U�ŕ'`)�S��f�"%t\M�_I!��yH�������'}�6Ҡ0����F<���Á���b��4��F��͠���xB�����ᦁ������j%��i�Q�dR��h�|:�̒�,L@��^�n�������-F\��t��D�4�Bi4
R:��Rw�',~��E�<�E����ܛ9�="炑�n��e�N�	��ME��$�<̽�-G���h���(�� v�DI&����p�1+w=ZIJ=�����]�8�2ô�'�~M64r�0@a斗֚3��@�Q�b�t8 ����)��%֠�X(�t�<=,>����q�d>�| ���n �r�R����{�0��������fm�J�cgye~�P����P������n�{4�jUAld��]a�q�3�p���=0���$���I�t<�ԋ
W�Pϥñ�<ʓ�Z�"
ޘ�H�]��B&$����lv)�~��#�9��@WW������k'H:������(b>1�Lha-��'��8��q����t�ݭ��[V��F��a�����(0oIV i�� -(=�P�uʺ�� �rך���,�_��~|-D@_,��t��V�|6��.L��gp DA�ũI�Dh��٭ SR��{X����\�����{Tx�;2�6ޭ>��c8ؓ�ek*I2V=����# 9fJ&w���tP4�FS r@Y!ރ�أ��Pۙ�����h�&��b��pS'DDF��u<p=&)�L����@��P�iW9�i8.�gE�����]�ؑ��\� nw^�����7�v�P��=��P�d.��p��lq��,�K�_��x���T�A-�!1َgs=���D�H�2�<��ȡU�g�h+d�N��i׈�Xk�
3���4�aX��*p��L���&dH#!Hߩ=��Ó� [���$��i�&HE�F��SӞ��/H,d��5��熈V1-5o<Tf8�ZDi�W@E|1��b�S;�hnTab@�$�7o��r�/��H�6[Y�4�qy��#�7M���E\ƥ�m|�g���D�4'�q�(�/'��͞��5��:�bMJ�ϰ(�i��V�2��q�[At�X��	��4]|������J�����Mu���?U(��d4�"��Y�[|^F�o��b�'�K|wHYֳҽ�//����E��ེۍ���v�4�6�y�}e��O�C���Ӡg�*�^p�$�1:G�a|�Vk�q-�e�z�E��`űo/j�fz��o��o�J���V֞8ƪ�6|P�x��p��U��W����n�)��ƸSƎW���&�X���#Oc15ś�B)�ɖ����12�rk�n�S?���Bgk�6��έ;��F��<ĝ�pt�����ޕy�i�}�D�X�~��x�S�B����/�����WɆC�e����e�O>�&�-}(�o����}-�qGGqfXHN�)�Auc3�_
u��>φ{e.S��m�G�I�-^b�k�&B�K֋�#� Q� Xh ���4$աmF��N��0��%�y�D��z!V��O;>�HHң����L��V ϲ��4��E�U�6Wa�I�ܰ1����F�K\n�����]~�^�<(�p����<��������ʧ���f��;b-~w_9$�;����/q������_�Z�}۲}6w>7iX��dǇ��X^�_V�<�2Fd��O�!����*e��ي�G,g(��P���|�H$V�4��KV�����wX���`�N;���M�H�gJ�^{+�	�>)�:��Ɯ+XW�n���I�F<,>�����
�PO��d�4�h�#V![��8fQa�XbՋ���h�$Kv�����ABj��~i�y�4�{�,��Qe|�+��jR�G���,3O��滉ET�j��]�
`���{[�{�o��jKx �m;!�雋R�3�Z��U�?%��K�e�Ʒw����Z�Pt�U2zn���2�{��O���Vd�8bi��g,{fPٮg]�3�w�ۯ��~&t��T5�l6ؔ�w���� �<x�,�m��m{j�z|O����R�p��cW?ۻ�:e���ñ�*�+?�U4�[k�(0ܣD�X��`DJ�0V����T�<�����Z�7s����ۭ���@�C�)��q�&&��ڋ	�]��\od�f��ɓ;�VU��X_A2H��|2���F�����lf�uҾz�v�85�e?�/մ �[��^��U9*w�3e�~�<�w��r�p8s�`�vw�Gڅp�!$�_��Z5�3��Z������_mMk�������tj4h�,h(	]6�]��^W�yPv��g�X�b��z�Nƨ�E����eh]��Hb>Pؙ<@��I��?@I� ���qkF��"0�{�/�P` /����5�v33�QU�Q3�s���� �>VA���fu�� ��[w#�P:���l� �6�=�x��p@�B�Idus��^�lN��,�k˲���Wa���a��~��x������g�[c�O�7���=5��ּc����tx����:�R��S,R���_1���}� V��o�� �J�c0z.�40�A�4�=qU�*F1s��<���->�cH�!���T�7]Z��~��c]�M
�!v��!���\;�Z��ː����j:n�8 xz�y�����7�K���k�B���5\�uj�T�w��̶�Z�y����e)�ҿ�E�^��I��A���Ѷ���&t�m��#ʕ��_,�XVY��[|�lo�ft�u�^L��Ͻ�A�c$g�̎��A���#w2_�Q���t�"t�EUj4$�$�� )�P�߶�� ��o#������v��/�_��ʻ���r&���KHVD�����Dgt�Ҟ��7)P�����O��Qi��R���]:���~T/�-�����\DR����{iLw]ҥ��l��^e���]�����<7"�n:���q&����FI7ݟ��7)�SO�!=�����!�=����{�����"
��d_���|=z�|�������3 |J�pa;2���lh���.!�3�ʜ��pm �x�j��G�gf�S�uk��x(B��4	Z�ݣk�@�x"i�5��] i��r��� ��	Z5�*}X��=�H�ԁ.t+�쾓�<������4j��W#\�-����2тP��ha^"9�� ��i�G#��w��y��"�����YJf�;�xQ�5�`�D@՚k]�<�l��Nz}�&�(���ĳK�(��|�g<4f�H�	5���n�p"�q ��V�u��!�/���2I%�Z��"w�@�ٮV��jܺ�$q����X/���_`�Dq�^���i�4���'�|���.�lE��z�!�Q`hb�q��y,G�;��"�R_�zyv)ʣ8^E���!YP`������SUٷ�8�MyK�l3Yw��E�����Ud6��ԜA@�Y�.ttB�{�_�v�i0V�s���S��}m\-� ��0���Wo�p�_�%p�2F�
�殑�M\�E桧�(	E(ޤ��x����L����;��&���4���%}ӆT���@�O NxJBy=�vx��+�R/>SAJy�^�U��*x�,���I��V���i�o�s�Nyx&�".l�:mZ��xW��{��Zq�%��h����h�����؈�}�\e�[����Ѣ����b	X����)̓*\܁�WIl�D��_��5wh`�ME2\���+	�9�2�W����Y\��_�e�7/4�D+֍�q���ĸ���q�!�_��&+��׀Cw���FӲ�럗��e��v��I���&��S���5�"8���Ѹ���t�d�����s�K���
���B�����Vd�"���?���P���܇�q�f~�@b��dB��6}���`ٹ�xM����h6|��PC��'��^����Rb����.V9��gP�m̘��ѳqH�ܶO$?��KHJ �[R������Uy���VJ    ~ǂV;��AR,Vw<�I���8� �36���ȑ���=�pH�Fv��pi���%/�[�)QeyGՊ�w�q;~�0`��R�Cv����x�ډrRp�h ������T�^�(�"��<�F�*�5�]��;�(���BM���*%��(Q^E�5,�w��YD{.�	r|�f&"�}���h?�eN�E��<���v�8Z�[y�MU�Y�q��5/nQz"����I�rk�]-9�	�LB�o��xZ�g3Z���$2ӱ"�A\W������_�!��>w�x�JPP�I���.��U��\I'�#��*٤�0��b��;���;0�q-_s�dFŦ�vOG�X3�bI^Z�b�D0؁Xf'��f׸*Ɇ�<���]����!���¥�-�u4e��4�#G5,�xZ�Ts3��i���"�A�%�k���!لK�GZw`�J�yT�
�J�y�)I&e��8�7[@%.zST�A,{��粩�_<]
/X�Ʊ/X|h6������Ʌ����H�9'�Q����V'�Zm��bU|G���3��̵i̡��F��\�Th�{�)߭��r��(�6lx���J�'w�jMW��բ脅�	c�7����;`�-��$x���v�S]L4�	�8���}/��b�w3�<�0)!U�k�j������"(�X��2�!0��e�_<�&e��(S����,���s��&p3�9�>���J��3��?�S�+ɝ�I#T�T��Ӄ�(n��#�����>2pR�6$��'w��HQ��i��=�r%r>�)<�5�H0
oS�U�Q�<Jla���g2�iΥ}ܕ�$�YIJ��?�{���xzov�h^O����f�~|��̓��v�{��%��6�=)� �h�͌�͆d��$�ɦm�5 ̀��d^���5�r��O�$������2���:$d�? �.h@�q��8��*�M�� Ӂ��nf�l!8�=E��T�&˔��=�(Ng�~n��a0R��d��I�I��I����hU�����%r���i�0Wk��+����W�h�Hu�Y�if�H�.r�妵7/�K�� �'�4��XPR!�L��(��b�tZ��r�z�y���z&�_u7GݏfnOӰ���+쌶�����6��pE+9�p�� �r�%�x��pgYV^ؘ���o\�q7�o��j��#w��R����R�;Mw���k�6�	�h��Ÿ�B�"�a���4�b��!N�����`�5�*���ǥ�w��U�徆y��;��p�K+��O¦eԸ�	�e�&b�H�@į=_`��M���9���<����������;'aq��${%5�&-�c�@�8�1fhld��x�Ny�X_I񆣝Q���@z=�D��;1�YW����i������>-��tZC����:��dY�K�@�J�ޝ��pOG�v/�lFu�GS�x��k�����vo	!�i{ͣkzԖa�C�}��`~��x�Wwmu��8R]M�;�K�u��V���-_�̓e'4΍�޸���d��.�䐼���w2��O%Q�'O��H�P/�c�I'�[�)��S��^d&Q���s2�r���������Z�f4�w��~�7�Le��:�#��i��è�Q��x���BA�,4sZ�'ڢB�G�y�3�R������Q~���������6�6�����Y��طԢ�[7�v��|������J@T��^���T4���yd1�E_�H>iL-��;�h�.Ajbc�����i�D	�z�+��? 9��9��y��	l=4r2�Aam<��;.<����Sl�n/�V8x�<a�cҳk��k��� nE����Q,~Y��h�y�A��f��q�>�]W-��?Sm�섹��㹽�$���M��g�,�,>m��ߡpO��|a/�V^�^�S��@
�O����q�6�l��]=|G�U���5	���.��>>��Wݺ�!Tf�"�����Éo�0&=D)|L�jܯ+�M�x6^Q�o�4N-��������S:����e��F��l^nG~��A��M"���0�܌��e���\"�*W���^ˁdV�l����"��&KB�ըs��(a��]~��÷Q&����A,���b���Kpּ�oxޮ5t��#�'�mZ��xu`GeZ�^�^�SNn�K+�A2et�cp!�9�I�_(_�i��G����q�*��p��!�=�B����VZ�G;�ʬ�tV���p)�p@�]I��F�gw���Mo�`��;�~$�P�j��EY4~�p�6�L-��C�q�����À�PB�^��K���X^�ВH��~(P��E�R���s��UeMZ�3C�t4֫��/,z�Sk�HP�c���C��S��x7Ǜ\�����h�H��c�q'�-��8x��\U�C��y��I�ۉ�r:1�җ�Q�iG��6G�pX:��3/O��Ȍr���K��E�ɚ_�Q�i��n���s\��g��i��! N�R����y��#�;�䓮��z��,�#�n��=C-ς[H�G��ٸ�z�Iv�Ky��@�P�tg�r8v��E�"���>3�;�j�T]���tV�hD��-`�?»���fً�镚�5׈�5+ީ�jQ�j�̉�	�Y��-�vĞ\���& (>����v��A���e��i�Ϫ2���l>��W�,M��.�74�=(ʹ�-�ñ�$-���&y|C�$�E���6�z���:Y4<^�o����������֓�`����$�BO�)`lz�� ]�E�ɀ���'Ԗ��_>�sv>�]�x��p0,)�,������|ܳjp��o�T�~Wͤ	�T��>��@��
6��.Ev�?A�hE�����|>೚��k]ɒ��*���8�Ź+����D����b'r[�i{�Ѵ���PXF�'"	�v�<LݯV0rnlM��T����/ZЙ�x���p,��ئ�"�<w�	�x�F�=�%���{� bA�r�(�J�A/\��$�#�e�[t�����>zхPX� ��q��çVyrE:��i8����8�ȃO?��k�"|�@Fv	(�b������!0�IUmZ1j�̓�����YQyg�i�Xn�����P���X	�h?���=a��E��];�W�y�:��NGQ⹪��(����x��p�,-�س�?1<y׿Zt>�٥yϪeS�7UB;�"jA;q�ꡊ��'�H���eiY�^تW�]%��Y�$F�����@D w�#i�?,$��2[�c@��&U�ea�g��wB�	xt�F�T��8'%OY���Y����T��ʶ��eQ��Ty��d�:̸�em�G�<V�jw��R�?kw�0�¢���3���>>�I+9{5����e�B��9���섹v�>
y×]�r|�.�,��o��7�ˉ�;؝��ܤAG����h]�&YaO��j1pj��B.�Z��49�g�)��ֽ��%1ᚔ����欆�tYVF�Q<�4��<E:R�`N�G�� �$�>�âh���	�0.�u�����ey\���2�aBvy�����5��y����s�M��V���R���{=]�F����|�?�Q+�F�L�hI$��|��{sKХW{TF�$�7���jG���awړ�e6e�����	m��M�n"����TX���zW���ٺ?�Z����Ww��)�#�zZ[p�pfl+T�[P|��x�}�̺����w{e�(����P��}<"�����_��?��]�p߼HӇ���
����Pٔ�1/��I������p44s��o��@�:n	3�X#|.��.ݓhq�����<,Q���sV�5�b/�+M�T�;�q��$\	�tw�.��ݐQI���Qr����y��ج'�#&9
�5 G��v����<�V�5.���9e���3}�ؼJS�~��4��b��Q����D�:�2��\�<�G�\<pX\h� #\�}O�Ԫ��*�IC�en4ڀtc� _�V�
�4�[oZ��#
�+�w��A2�Ѻi��    �#����nݫ�x[�p�{���t�%e��3�f$�L�z�P|��\��}��6�g�=���7��ޑS7��������F- g�M�$_ɏ|����mɹkge�%g�\��hs�?,̇��uح�{�А@9����x��߯�v�3���i�����;��W~���@��/W4p�ǉ�&=��C��l����>6�c���gvI͆��Y�)���78�{S���~g*�i�����3�zE���Ij�L���A�[��]^���TI�Uߪg./~�;S\)QhEǇ}v(�����K;+�Q�fz!J���e��p�;�ȧV����YhA��
:z�#5h��u�rk�(H|�PO��;�V��8��}�k��f&�I��=�3��6w�̼�Y�����+N(Ѐ���4��>h~,r�h>��w4�[83��"ƣ���s�h7�z8~����Q��p�5�y��z�ASp��c��lD�X�����I��t/7����R��6�Ue���M� �bak2هŧ�����=3��ǀ�r'F@G�<�EE��Ս�
��;*Z�tmU��ѠnK�h�Ũ�&�Ks�,��H���㟈�F��)Y��C޺��C�yf=���$L�����,"�$�%vP���[����x�Q�j$�uzG��¶����o�^=��Ο�-�l��[����u�;.Z�V�Fߵ%,^}��ݑ�+��������)�����<1x��k�^e�i��>��XP��1$��'�G����OR�f����텶껼"�j�*F���izp]z��/��p�ĵ�?i	�{Ċ;JX$Qe%LI�����A���Sa�2f�!�
t�c{�	,�9�M�x5?aǢ|DC�}l�n��z\�%���F�Ҍ.R��e~��w�2PQI����u6'J�ֱ�S�X�C)y�v"b���,�y����ށ�\''�������nH����.{�}�$gY��Ί�	D��^�F��|}��ٺ��]]��+�������t/�Q�<�|�Tf�k/���Pߺ �O��"�o���$�~�TCnڨ���L��¥Y[��7����GY���JL;x�F�[�wT�0�q�?����^9e�1��)>ռ4�AcT\g���)�,vO�U	�� >p�������79��z{X���@@&33_P�O5
9���x�\�Q�<�7�Fu�,�M�W�����{4�.��hw@�r��~��}�~����G5�Br�J�]�ed�Ce�T	�z�/֮�;<,��J1m��=MŎv�_�
W�H�X�]�qb�me5��jY�E�Ґ�!XV�(�E�m��IEg���Q�'F�
�S=f���b����+�ٽ�4��=�zj�O��^��o��;�uZ�|�]`3U*����b�X�=��V�}r�����,(��u�0��?|L�X6��"�^�e��}���%^��<u���O���{�π��J������{�N`w��~�O�����"m��K�,��]lx^��}�����<w�`�!���n�aA+-
��c%���������������'W����>/����k�-$��a/k��X<�����pDj3��-�a�ǡ�*�*á��=��`���}1�D�b�)�&y�����i�4�2V�y���>���-�J�y+7W�2�o\��d�!_���]���t����;��ʪ������ڊ9�]��z�@R�-|n�pIm�c)eŉ�+�(����_d�=��7X��E�$�S�*�8xE���'n�?L����_H��&rw��=�(פ��l{���I���y7�����x���D*�G�pF���o�|�+���h��f8�R�q껻8^�5a'c 6`����P9B�TG	�V[���t����B�%�e�tE����.�ѕ�(��z�8�l�,���6�۱->]]���{����=��""K1�rC
J7i(i:^�<N)��06]��g�_1y��;�t��@�4U<S��u~�1\{�`>~��Ul<�#�h"�f8�R��$�x�����p겿�\�����+ʀ�W��@��yd�6�	dUV��8��M{8]�f����
�=��<al���P�e͉,.���N���?Ԫ@4Z�����plVA}��%��k��FZᒈ��,�M�f�<�d7Á��5&F�,�0xw��sݫ���H�����ov0����W��1�ɇ��zC�Q�j�6��0^v��b�yy�~R�����G��s�J�`opg�mB�����R��<"B7�A���#SJ�I|���b�uW/�D�m���!�&E3Gkx7á����'I��b��R/y=� d�Տ�FQ��^E�6�bF��O����q1n�bp����S���%4B�~��ȕen>nB�4��4��&^��(������i����UG������� �uk�z0�5���"��4�E̐l&�~�3?�v�Ë�đ_�$`�/)����Օ,�n������)��%	��R>�?��擠=I>@�O	���5)RA�M~2i&�x��M5�ny�־&e�����q��*�@�>|?�*K���p�4Ʒ�>X�~-&�m}�(o�_n^Q�IY%��37��ib�.eR��6ʈ���u�p��.O�; a���7�r� �!{��a�p��&���-�4�<��6���-]'c�Lb%&��B\�Xw>�4�p/�
%fʕК`R�WJgdX:tBE��#ƻ�W���qb�e�~Y���B����� �^�˛��P~m�ë�=3���T��IR~�6�w�w�X_ҊL�6 H����߫���
�y}����#�xc~3�vI�uM��Ώ��ϰ60]~�6�5����i�����l�'M��:�4��p���ĬB�b[�܇ĮW�$E�&%��ƺY���:eE��f�g�?��G�E�E�^}��b�=�Q�t���0^�"*-êL�ࣩ*�
���e��b�2[�p�v%|��Aۂ7m��h��0^�2�= ��qA�X�R���W�x�Y��~A�7D'�pɂ��Q����dv �[>�u�v|X�V�dx����!V�>P���h9�M��(���͘�G�B|*�B��>i40(������h�L�2��/ӊ܆�)��i�i��2h�{� fW�hh��e8w��<��~�_�5�N��b#~�D��s�g��$O�f�6�㽠�A�8}�\����P�{�),��6���+.�`qg_'!�n(uS��{�����	�$�au=�{��BqY8x���,������{rV�(l̲�.J::1kٓ�A�9X��Fo��9�H��u�Be�)�q�[y��~�.�6�?~miK�n.5� $�m�A����7��k�'�e���s��� ��Z�|�M=¶�Yw3�������m;9��:�;袻l�G���5�� U-^�<	�$@���t� �4�ڻ� g���̘J'���t[��t�:���m�-������=ڋM�hP��_�1n4/�գQ'dR⹞tj�7��y�_c�%�g����9o�����S��7��w^`A,<��-Q"�#¯@i!mt�sC���3��ێK܃'�Ѻ'��M[�9��:|?~@.���}�� Y�Et��� �߱�` ����6c�����	��8�I}�\Ss�#?A��#ܝ-5܌��&��w7��i��_�|Ż�=,�_��!a@PB�]�X�v��y�t�6Z��2Q�e�e�yL����lw�9�l���x�D��C}�UY���g8�WE�ˠ�V��۩���NPO��aDGe�-'�(=l���p8`��I�������r�q��B���՞�D�ع��W�[��B����;\C_������CY�C�p#�t���8<�R4xL�!73nD�¯k&��-�������UG{����q����!�Z�k�*0l1�t�kx�Y	V�p�"�jV���#����i��Í���ل��;�/w�CI"t�k�o�Ջ�&�ܵ%;�C`��n�u�`V�
u�#����c��xD��:C��5    _��`�e�WXL�G���&�U�n: �`WGt�����������>����[+�U���I�iȌ����I���A���ǐ;[H�����d�\B�����c!}*�-t����>&~Q�6��MK�����6���V��7�Aۨ��G�h<!8�9����#j(���\�'�c��];�}:�Q����=�@����S;)ct�}��������Y���,$�/���(!�x>�����6@�Spc�Xw��Nr��i����:P�y�,�掂fyn�nV���؜#�7�DP�+7�m�+��[}���S�I��D��,u�����Rx���H9�=�����Z ��^vҟI0��}W}ʱE�;�|��Xyһ�R
��z���Y�����x4�� �G����p~��F̶EPFri�^�g�d��i�yL5V�0'r��iB�c|E�_�PW���F���� #��x.�!�[��;�˪L�~ʑ���a�����1P�'�Bҏ~���l$B���;�|���@Xc��LZ���\��=W�Qa�z_p6nԷ�w?����2�߀��D�Tz"����r	s/�����_F��*r�����w\�Q����q��<����v��K/m�n!���i�fA�h����E7�Xᰔg�Ӌ��B��7�t�p��Y���H�ɧ����;*�&���i���G1���5Hf|���;jP�?���J�Y*��QB��,ʈ�з�}�x��N��0�*K�tN��h��*I��w�y��ħ�+O��4{��BS�lyH~���D�+ �1cWhsw���,�	@����|�e�h X4|ǕdI��ˋ@�	$�Y���&���;��\��T��$�G���5��@���Uv�����+H�H����ǖJ�xF��v�rl���x�>5�q���eԎ�	����d2q��Zʨ����OZ���+ku���SqmLzR��Gq�ĮI��������l�-�{��!��o����ߝ �>�T�~PVǪ|�	x4�&�L�ܳ��2x�T�*d��]H6����SVD�6],�ӫ��/OT���e[��I���:��{��t?�/f������j�fӽ� U�������n�ӈ5�y�.���H�*-"k��0�_`��Ô@�/�#Z�Nt�w���QߙL
��#i�k]
7X�`������T8��e���o_��qo%SāBn2�3 ��J��W;�^�E~l�#�(e�g$b<\+�Sz4��%I>�Y�ޖ�p�>u��e`�EhPc@�^7K�ݴD��؇��UP<1��c�!zk��������$Xxt�P�x&�p�9M����E�:�@�5�M�،/�[2&<��WP_��6��l*΍Z���^��Ӓ��m��i��ݱE����0�����1�o`e�v̮hL�&��f=Ӣ���^���V�MX�>�R��w�و� �O4����"h�3Ӫ�~/��7� �	�0�ܹI�O�7������^Y��<^c)�Y��-��ff�E��E��ub�X�:�{r���[�E�L%U�Q��Go��s� ���_�aa�9S��r������[u�]5f�l��P'D����<,ީOS�Z��/�2Y���Q%��&���e|�=��iI��=vW[h��Z�ʌ8��ƛVP7!�ꖯ�f\J0��(?��}8��C���O�VK���	���	S3�XJ5��~\�!�m1�e<Q΢2+�u\�`��F�mT>�܆�G�3�sTҰ!)�����>�UG��$�RC��0`@�	��O2���ֽ$�%m<!G��S��W���&�Պ���`C������{�Ss�-�\�޹����������aeS��'��V���t�
�J?�O�H���<�t_T))LIJ�����^���HU��;$�s���V����n�?��F{lR�i&l�t��{���o���7�}�hj�e<����C�e�n�.�6Rh��Rn�k�.��hfxp28H�n�]��|����>�d|����I������Gy�����]YF9R�����Ё{���HR�������3�G4�:d��#��gEVz7����#t����HϪ+�H�7�Xu���ڷ(�_o�����%�g�����Y�}	S���v�/�R��T��,ۈ��PRpݧ0[�e<D�]�����h��|�"dd��%5����=@�(�:��rCFw��2�EH�2�)�QUxC�2$M���G���@��-��D�?�f1$�����v3���!�<I��?uE���K۲��'X�%W��<����;�
�'tHf�%̭��J�ֺn����-�>�O�Er�Wϊ(�����W�9�#��'��fz���>0�l~���f'��Y��� ��鰂1��~t���\^¾��.���N{ь��c���n�0PZ�KD(Z��A�����_����l�~	O�`-�7�и�gS��[�� �(�Y��.���<����)��*�����<+�� ȋm��IY�m��<��s�
�P��D-%<�� Ql���*��^�t <I�F���P��� �X8��"��]-�����stUa�M�C+�?�9HqwL�W<��\[����v�Z��P��p�S�M�|��H��f�N)�q��R��Џ~�ʸi�E�xb8��[Q��'���)T%M�@�7�'�������=�s��89"*�yB���YB�O ~y9szd����&/u���/yy>=;�^�D\KyR�ɖ~X�vb�i�g0:�/���Ȣs�Hԋ�:��j[�x��$/����(xg�bp�t1�|�ʺ�׈�l�܊�m{U+^�YĹ-���"�R�T��o��}
1	S����X��<0�d�������7W����_ Ei5X�7�(Lo�.0/���j�-��(�<\����I���g�Ti�'.ߣ:����P��[���� �y7�7�1��>��_�5�c�E��2����"�8f���QRա֧e���{����ȹWcOڬ�daR� E����td������<I�,�XY�ڽ��SC�cM�a��XF��O�/f�7,۴��x��Ǧ����^(��d#��w��U�t�v�}��O�׷k�C��� ^� �3T] �/�Q�({��<�9mB�x��p|�������{��΂��غV�FpU� ���@t�7ܪ����o\��/�K���CU�^v,�r؛�h]M�Q�V��xs�\�ƪ����_�8����C~ⰴ�� "N��u�Y�NAҴn.���d�����G�G��$�̊�Ɔ�"�ή��vwr��2�N�a]�>�#��Q�F��pԹ�"�A�0�+e�'��9�{Ҿ�E�o���8����^�E C�rmz6�nӟ}B"aZ
�"qw����<-C��%^�TS�gD>�B�k�[2]ZM���Ӷ=�}���z0���E�ť
����Z��T�>W�Q	���?\�A-���+|�-���o�^���jCr$�M��P�h{	��e�|C��-^\4a`�#z#��-�v����㾇���KP�X�4ύ�UQU��!(��kE
)&���F���=�Ș��QI=�Q�SϮv����� 
�C*�az��G�؍
���n�7iF>�8'?������ɟ��WP�!5,��_��iw\���������ʘF��X�#�K]�wya�,u��χ:��`�'�Qj��Y@���ೲ�������;9�����t�&f����pK���Uf����"�I�}�4��,IQz������,FԊ�~��C۳��cG�|�yI��U�Ted�,��p�4�=w[�R�����,�����JP�i�Gk���x���˴�*U�[Q�h�����(mWt��ŷR1�gd_�c�R�3M�c�U�A��蛼_/����=�P�"�Ѳv!����P%s���f�V�_#,�����Q�iA�-����iU侣�"�W���iOs`H��x�R��|(�"O�a�pL�*�8�[4���c�Ӻ�O�1J��u��v�v4��9�    Dg�|����ű=���"+	�A��?�$��W���k�w+ .(ܤ3�(�l��a��.*�\�������k�j.�0a���Ej{�R[�:M\�L�ʿ�fC+��R�!��B�yyjͫ����q��/�?��U�Z�_�:~����˾�R�4��0�XG1'5oCjh5"q�>����x8��l 5r�n b/������Y^�D�2���df[�������(n�|�L�u�H�=gAQx�"s��q�v��F{��c�!�2���N\�U�@�����ڶ�`�&��h�P�iu��h���*M3�F��#��~�){�q�?��v�zT�0� ��:m[yĦ���U.^���2C�����5�j@~QW�
���wO��}z;�R���4�G2飷��wܵ��El���;����GŗM��� _��A�ҵ��^(V��-��X��b�yjD�*����BO���x٣���U�J׬������� �镏M��B����$g���g4iy��ʛ.o��Ql�8�Bn�0�F��x��O�x'�(��T�����F��/"��ke�9�Tq�ţr�W��y����k��1֙��D&HN����+��D��u�����C�r����eb�27�o8��z�uW`�����}�,��\G���]��\�&U�G+W5�\i��ּ�I�[}���
E.�^įcE����Ю w�n�Q
����Y�������q�06�GFaԼ������
�7�Xq�a�x�/�Oo��u���
��]�غ7yX|F�y�^O�*Z*�%A?�3h�^�۝΢����}��m`���^|�Y%x�=�<��vv�-��ws���"'`��U�m��<��x
]�@H�W�p�b�i�1�2�M������?�Y^%�>I�7�L���蘁�B�9���컆..�^"�u߶�6�l����(p�<����ۻ��D�D�"�$�͋e�ןZ+���>O` �~�=�-�R���\�.��K�R�n��C\�׳�q`���7}��R����uku���C=�г���+�O��e��)��s�C��L�*oF+�bx���J]�
�#�]}�
�,�_&����+���0�JQ�Ij�x��rx����>�n��	Q��jiަn�!���B
r�C�&Q���X�P���yb����7J����K�8�\�S6���Rȩ���>S^������YaB>�S��F�6�,�F�G���뵤����M���NȔ��H4��!�N�{�}�"�J�����;4T�<n�#��<0��p�:I���/�4
���><Y�;���J�9��uʨ%U�>�&-�&bզ�8s����� H1�#�IW�Es�8�"��4����s��� Sk%eU���m�� ���0��c�Ӑ}�e'��Û�&�^h��L��ʹ��?�>Ǝ�GI[q�+�L�:�g�*�
/��}�-�k�*��vq2��k?�̆� MϹ�&6>[�$J�>���k5@�*)$���!w���B�(p�ݶ��teq�Ǆk?()��`%|RgQ����:�q鄭C1k����뛫�S'F(q47=�ROrk�!(����T;�2��ݜ���zA�zw��u�t8��w>��<4O��p�{��u��7�^Ek�%s��L;�H!CT�0�t�^}��Ps�ۙ1��jI�����90�|{Z^J�%�lN|=��C�r���0�	�8��oě(���U�X�<�I��e�(�E�i@oG�`9m.�׃��_Y3�?�n�Lڡ�xRǦA�u+�wL�v�x]S-�P݃�lA^��?�j޾�I����G�WyC��3bZ_5�{R�����C�bm���k[��Hb=͐H&�t3�L��ꆚ��ۖ�
ޜ5�,���͎L��|�� R���v�F�� I
pg��EY���=�O�W��!�hn���l{�E��q���.��#��d*j$��{s��o�-���LFL�� 1ی;$�w,�)v�ъ�xCq�ʡXY|�/N���ҡm�܋���8Ag�7�7'�:���#j�<#T�TA��z���#|�κR��Xj�Yd'�,	�r�P�����E�� ��n������$���P��ů�i*�Z�P��*l3�	���V�+`�&��`����4��t܅oxN�Q�Y��Rt�2�ƫ���BGSSH;�T�e�z�L�hh�g�73�Sv�oi_ҠM�� =� �+�"��f��a���:{�aR��uͪ�]<y�M�tqc&��ٍ��G6S>X�4�:}�=��g�s8Z��������b�"xkS�@���{R���<�Ѧ�kWǸ\4O���� ꖿz���m8.���[�>��b�+#[I�{l��A�0��{�K�O��}���j(�LVJ��"��od����[�W�T��T�%����!��d��ԫ	�¤o�l�B���Y+Jw[ԁq�[�-�E�@n�ۤ��O+1gq�K�3���]\� r>��k�;Wx�^$�(��ȓ�u��)���g�Y�ѴMm���dw��9~��X�Y!��"'�%H�;��9���Ev��:��u�u�|VQg ��K[v֔���S�g�����P9���Q� ���ĭ|�G�!	)qж܆%k�dCT�#^�,�V�R\@�i��l��W�+;��`gIi��<
���I�ϲ9P���o�g��
 O¤t:Za�
S5����^����Ri�*���thM�P��a���nS'i�/w��<X���h�Ǒ/f��Lt��ښp��Fo��z�+�(���V�<�E��Ze�ñ�4��"1��>�ǔ<��o�7�I���ُ�ם��<����%�52�E��dl���F��Z�>0=Eݓ��j������$7�E\�9,σ��ҵ���O�*����$��Z�h3��P��S��V�E H"� �*��+�V��<=��< �	}��UJ, ���������΢*�AH^���K�=2�ȥ�������8e�%Rϫ�O�!�����#N۬w�S��H/��M2M��y/2�.���j��F����{4���ڙ�i�8���Q�UЇR���c��nٓ��u�2ȟ����!�}�ѻg��d��Ϯ�p��F-�'��Γ�B��������,��h/�Ӎ�^Җ��Z���#������-뢴0G?�g��X��ԖFB�j�Д�UpD&n������d3<�����	Bn�	
\�z$)�8p�E�ԋ(�ݣ�<b� m`E�z=�R�\/�z&��nU���ߋ8x�����'��<�X����M��m�P�W�/�B�7��uR8@�@긹-��k/��n ��N K+on�8����o��ۺ��b+��O�b��&f��˩1/�S�Q}�b�lv/�]"�Ps���t��%�4!|�����fQ���̂o�jǫ�Uج�T���� ����v����������b�H��<�*�[tt�G�WLk?��Ԧ7�֌��A���ܜ*���*�T�ƺa�������g1��h�8��\�<��mvC�����E�is��8˦�<$��)GY�1|����,Nr��+����ĳwݝM.0<;j�����c#£$����v�K5 B�ٙ��W��3T'���'���FݳD�r��4�;�Ό'O����`���p���g0���0��Mx�zF���8��L��<�����ac�m��u��rZ�H-��%�s+�4z�3x��nC�ڍ��	�^u����`�(pm�0�0��߬���p�q��oO �7�"���ZT�!����]g��e���K;x�EߋN�t ~�Ϊ�:�0�W�sZs��Pƶ���u�r��w�����`S�טϜ�S�M[7��r�6j�� ���:i�óY�T��2�Q���� �����5j@���i��N��?sJQ�I7N�	�h8:YTUa=��(ʂ౒��썳��d�o�Ą��W�7#g���씉s%/a���9K����`	q\�ח��Zu�sf����(���?�~!�%����f���>�︃�P�^\�߂g���Ct�(�bs ~̽��ώ@k+�y5���8���ls$l�Br��    �:�7�WX�9@} ���F	�X7*�r1y�Y�t ��"���g>��� ���-�'�{������dl��fi���
(��ph;���y��s����G8����&�J����Qni�($M��y`���5���έ��-1z)Qj�	�)ֻn����@�Lp$����B��&����<��s��bo�τ��.n�qUFv�Uf������*y�Jo+�Ϭ�u!�����4�M9�«^�m���?k@j9�ϲ$�\-��A������|���#�4�EG�{�?ڤin��io������۳�E����J�+��.`��J��Mw%�e�8%��Ӣ�ǫ�U�nQ����-��Y�[S�U�<��û�PQk����lM��Z�oZ���.��p�=��2��SY��4�0\��9Bs�Bb"?_ r�36��-�U�<Y�Q��W��u�a�uI���L�����,�!<Y�7ԸL׆��+r����%��[u��@�(��OC����m�^����c���<�W7@�ET'v�QE�g���a�?[PS��-�c�J"�5I�f��� 39�X�p������8��F�|�@m�y�MW7@�E;���FСۼ6a/��=�T���=��4�EIl���6Ҥ3�h������.W��m�ʥ���G���z�z�o��Z*��^o�wŋ���n@��4�-�l�@��j;S���:�ъo�NN���\���yK�1C�n@�K����ʂ�j���{N���R�6r3������w�x�8sU�.�����$z�d;N��:�܅�Q��5/N������t6����L\W�a�<J���!U�Q����XѮ��٪R�9��Q�����*0~">����믆C�y\F�i�*�%�F~h��}��L2ֲؐ�El�^�4P���o��Âye���oL�%���~KcP��W�A�<K�#b+R����m��-�Nǳ���q��r��x��Y���<�1���Gٷ(���x��p,/7�����Q�[0T�u4fs��8NK�\p��	�v�|R����Ncͨ,n�_Xm���"����W�<�?W��LR���q�	�B;��XZ�㎽l�G���U�;�~�\l�Œ�&@��֥�{Ãb[�����G6JՆ�wE�}����zb@��;=Ê3|�v�'��10*�%���?p>.7$:�<�ʥDu��[G�5��\E�Q=9.m������G܅����;�.�H�@�,L�h8$W$e���<����Y��E3D7r���_ÀC/zҝX1Z���nE����֯�]O����F��2|o,8��M����A�h8�V�i���2�C'vWN���GV�ں* ��i\��4%\�k{� ���8
2���^��]]=��l9Z���nEǮA���k�%���5KZ��#����.��F��M�t�M�RU'3��żT8�ʴ3�����ؘl�4Q�e���\Kꡳ����T
��.�Ͱ����v�1?�S���W��A�I��Mq���7d�#���x��T���eɥϭfR�R��޴�X��ν�F�;l�k�Rة�3y��0^���c�Ȳ�,��z��*(gr�7��9D�5"�aG6�$�zi8�ޥt�~/"@R�ͼ�=��
�)���l��f�YE��΢L
�{�{�+�}�˻`�[�监���~�+�P\�
Vςe[E�+jKZ6�����a�xN��tgQk��BUfw+nÈsn��}/����h&'���H�'�&.3`ݷ���K�jV�.Ąw푂7s��%����<�p�L����創� �6��\.����4���dQ�qg���9����r$[�w�Y�i�f�he�u\�����%��6�*C�M8A\���<�3��V��5�!��>AO�9���%R�~�Bo��ܜ�=�W�B�S/,nZ������J+�3�h|b��3�	���A� Ȧ�ePdF6Q5�)d˫��ǖ�j~���U�pD���"��B�h�&�9~:������r+Fz�7;��pKF��;vm�8&}`��*���rEj9y��͹E�����
�����cJu��3]��nl%�gϝ 4<�}1���h�*�n(m���ȼ��фA�������I��=L�p��e�\`�1:/�'V�w�.���bNk�0��8�cw�ıCj��A-x�:`9�`B�κ�V����%c�n���c��h��J��V��4^��,�U��P�"J�; N�o`t"�����-7{��zHf�;`t?ȅ{�-�*�D���aY5�UO7~���VqzCU�t]v���i9c�6B��v����s#�{�Ex9�bث�!���'@l��.��n�=]U�
���:Y��d�3H�T�Se�1���[ o����S�8�������@��L�ёhC�
�����
b����m��Qbe�S���cV�'|���Jۃ�br��38(�$@vm��KW����4.��j��gA������,3[Ol�{{u�f�&��V�p �L�(�Ow�)�� =�dY3T�%8b�~B�)�������Xh)�����5��T�a��~�\5?��E�Q��>�Xۤ�s��ҫ>Kֶ�V8�7��1�I��eBū��7�q���-��@Y�kk����o;z"p�+zE�{nw���3��{���uN���Cf�$�fg2h�W���uh���n��a�q~���ڿs�ސ���l�'�;�q���JE���	5d.	�T�ó���M��8�J:��i����"0i�X���y������P�`ѵ���y���]��>WS�lJl�G1��:.o�`^���.�^Ϣ�+q~���"[��V�I[>&8j;d���7���`;��s���dمK۾%�⊒��vj5Fa�����3���1!�=@� � �c�I��e���煺�m���K����M�w��nU�F?��-m�a
=��X޻L��u�n��m덣�q��	r�7qZ������gON�����V��>7דU��OK��W7�:)�1��{鿖���菈�33��4ַ�}��צ/2�*�*�M8���%F���7W�R����h�iMUSd@�&X���u�#b8�L���J�b���hn�YFgu��}g�8�ݙ>?�"��g�֘�us�Z���\-ǁ(P��hE���_l^��tp�7C{a&mv[j� )t��T,`|���286��3�t��Ʋ�a��-6���nV'�/�}{���}?��O���4�����᫇��;�u@.����y�ْ�s�w�R�c#77�����d%QO���N+H��)�ĒL��e�m)�(O\˘�����e�=kOh���ӓ�r�wP2]@�^n�7��J 6o'��`�gAx����L��-�D�$�-��zsu�����KQm��{�C�o�ܶ0k��"M9��]��|�MB[y��f�Y���[T�vS�j�o:kx�:V���%���d�s����S�/t��a.�@��39K�
T���0�)b��h-h�e\߶��V��/��M������\����7r^h
�g{ת<\��{c4� ��V'v,h&l���k��?G�?���J�e��Z:�5���V}V��\4Q0��B�']��v�IT0�P�AI'(����-�f�4�!NfA��hET��^N��w�Ql�iAC�vgof]4*�s?im��jsÊ�����&��Aj�ZA:�c�GG�E�N9�ǲ�>�+@��	;�ɼӛ��1w��>b%~:��ǖU�	k9�a[VTq�朤���vOL��ϴ�9�LC=	�(���<�X�|��*�aV�i�[�2�`��,":���,2����U'�ι
�w�rP-؟Z2β3����B7!Go9#��v�48��B�G�;��,<�䆵Ue�:<&u���6ݸХ��5b���Oz�F#3%7lN��<�4
h�	vR�]K�C6yW�eR!�hB�*�ͯ��rb�Xgӥ7��m����5�� G�����<$�,�l��X�    yt^�Зyv�SQ�٬������&ղM��{�yvͺ���T�6G{5��R%0�u�J�whE5Pӎ���<u���ݹ�.t"��#�l
�A�1!�m�7.�m:�;--8���r�L��ۊԔwM4u�a8U���8t��p߽��l�F�Ļ�lɫAV�����EIa���c۝��u�ؐY�0
���5��踷�Y	�J�O>G�l��n7�y�f��Cɀ}ʄH�К�J���?�����/���oHd`�3��-�W��k��5�u�
��z9ؘY�{�עR;��˲������v&�Gy�,�&L��m�oW�l����/�T�+0C4�:/b!"�a��W�������]��8��գ�֓��*��5�i�[�v���r����hߞ�Y�`�0L��rG�$�P���8�.�����������f�gy�y��v�&��3�47�qs�&��^l��f@|���3�%�Ib!�I���;���4��SW�E��s:���Q��E`�imy��q�V�;�j���i��^
,崾F��᫓*�ѕ�>�Tf�Ҵ�z��&P`n`\��F�$��4�H��2i��;~�j������#��.�_�/����s�>��^)��pǃ��7���3_�:��L��f�hB�S���t�s]<��c�؁�"�������9x�mD"��V-�M���XCKJ�k���אM�7�	l��3��߱#x�K��XO|e{������)2d�7�'6q6�J�C��<i�Mlr��A���@�.�~v��cG��{�#pp��+��j�o���s��
��x�.�Ӌ2`mH�B��]��**�Xr�$,Z��9�;c��σ���rTiTz@'�@�;r�9��R3��R��\3����Co����?�bs��|uC��<q��0�*z����C�k�Z�G��g'��
o�u���Ǒ_bTY^&��Β�����:G��[��K�ʞG�̀��ųF��BZ8y�k��d3�(��wU֭���i���6�g�r]��2_��
Q��Ѧܼl�����#G곻��M�l�sC�6�6Ls�ef��P׼��w�r��E7S蔂Mi�ŬʴN������K���"����[�A�9�}X�l~�U��P��w���4Ĝ[�z�߻��*S�'$"�˴��M��u)��L�	2T� ʷ��WK��"A�x�+�G^UJW�XE���I�.i~���[���x.�8u�VA���6�p�>͵�)�O<�$Q�����0�&-�������"N��hI;���t��K*
��Ś��-��Jo�?�2w=l	�X`6uYd �?v������� ?��6P��;���Mt��&%��oLo@8���hR��+p��sh�ɮ3���A�&�X���$��>�;(�8��z���nzǻFn@8��-�s�'���T�D�C���"�����@�n��l�������<�*{|��!��[�N�]{�p9�8��E{�$w"���֪h���hf�?jY ��V~%�Z�����0뺰�-�����S�����B'�ݬS�j~ќ�.b%���JXbmu�cq�v�R.l>�,u����.��?�E�n�DȦ�6#!�Z^Y(�R}���$�m��w��[�Ȋ7
ae�ߢ��2ݕ���k�3����Ry1G�$#|�ޚ��3f��h.&�D�Ro�h]�Z3�\�S���W�E(䤦��A D�����*9�=vcF���1�F4k.�V���K֕�(AB�d����S%��2�	&�,�zC�8|���QKv+68�:qu���J�%�w�#�p>�1w8�YGq�Wy<�}lװ��a�;�܅�1XCr!��b7�����3��d�b6�}����#�aYE�9wN��͆ih��X���W��������������oH���+�h�8ؿ���A"IsY(�p|mۧMϼ4�hf&��E�wJ���x9��mv�8 �lm9��/�̃ṼϒE7�,/�=��7:�>E�/^$^�1�h�e�G�^�m�sT��Yb_�̈́��?lMӸ��4k�@��k�ii�YIW�}��w{k�����5��Pյ�	�%hC{~Z�3�{��x��\'R���ښ�2+�X?�]�1~Xq�VF�m�ȿ�B5Y�	o����M��y�=��B��nGk�A�Rk~h�ǚ�ˇ5�X)��6d�7TXS3���Ƙ�Ď��g�'�,=�7�����0L��B��<�z� /�t�pƓF�#t옺�Lu�,Rު"NJ�%P�Q�2V�,]9Ϯ�=2�>�T��䖆�5s���0����T�RN�5�}+y��I�:����R�qܳ-���}��B^����y�!����@���t�[�L��Z���hݴA
zw�k6��s=�3�֗��TN�=��Pom$uI��$����@�O&?W��S�[-���78r��=O/�ݜ�n�y�q�l߆x�H/�]�P#�}[����!�7�_�g������>�'�1=��j/s���_�߅l����R��m0)X6�(Ko8�Y�m{���[������Elx�hҊ�fܘe7T�,�5k��ѝ�F?�oƕd}Y$���	F.<iϚ�&L_8����.��M��B͗p���
�G���<.�l�v�N�v��"��$'>}.{ds�{����o΍v�}��M2IrS�;cZɸ�{+\�������U�rdD,��#{¥9�ˋ����O�f��j�?7��	6��-�yg���=^A[�5������YK�l#~Y|{=�co�S=�����oN�My�j鵽��)��ߝh&
��=R���E�A����D�}g�s�:q�*�~n�2-�=��4��ޓ�W~uj��Cي,����}�;<�t�n~<5j���Lx5��%�૳�.@Q��[Ӵ�W���&&p�[y88�\�,X�ΧÜ<���[hap�Dȸ�"~
�nǛćo�"J*�O�׶��5vR�e��t�Z.��N��|a$��%_]��W_�Wi�VYu�Y89��
X�ř�0̆/�ꪪ�7Q�����i�ϐ�!T	��l�1���Ǡ���F �$�R�O��w(��F[�e����(J�����zB������]k�>O��x���[��^X��bZ;�����bx�"v��2
4x���n��8��fi]�	�5�߬'���E�ش���������QZ���歆kQ�h�r�ZN����F��|�{5g��c+�ĩ�.7�@�8�B����L�<o�k��4�JOb(���*'�2���Vډrڑk4�Z�^���"�.+��K��s��U�k�:Ӻ�N+���Ӟj�v.4�wR63���=l�p���-��b^:a��:^aj}��R9�O頉�M��/��B���Hs�c�����㪓' �/k-��h���^���D��/�9��f��c&ú]fbU�_�s��I�8�kN�>p@�R2.զ�	p̨���Y͚�P�5�:Pv��ѵ;�����{l�i����!�h�A.Ӵ�o�,����΍��3]�M;�FPn^ѣ���n9�zO�R���b:*����4n�UE���РJ�=B��vq�Y<�g�D���E��/�X�~�I�Ë2n�̏�5�e|o�zqب4o���3�p`fEִy�yO��K ۇ\��<�"��MSg�74/͐����Q��.�Δt�r�O��/H�"��UgY'��β������%f|sU��='��b�MOq\�K@�֬C|?�<RY�yH��|x����e<𤨳�����݅��KQ�י¨���&�L���2Yt1//G��M��q�2�X2�J���'�6}���5]R�!�#Ώ,�A�<���X	v�Ӻ��T?�dA1��D��G��{�b�esy��oM��A.xh�������f�J3MN��4��f�����SV�oʋ�,/���(�pz�HW�D��p�4�U&��%r>�%|o��{>�3݇X�z&�G9��eԃ�8��e��
:"}xO�� @j ���܈Rf�0���ñ{4W�L24}��vyz���˹� �*��`^/�鯽��Jz�`i����    y1ɫ�Ƥ���Q��zx5�*���*��	�nIC��'xӘ\�}]�ʕ�k�)k<k��\�$Nr��TY�gKS?U����_-���T�+5��tP���X�iWc�A��p9I�ԧTy`��-���0>�ma�qIH�7<JNfl���9s�gX������i�Af�eRM;�=�V��0s��U�of����T�)���������s���g(���Q{~֤H[_@H�Xؙ�2����$O�ڍoU|��m5��#�vd���?`?��)U|��VMaq��b�L���XsRT�G���<�e]bt[�=��k�Y{*�O�Lb���tR%u���$�*�q
���Mڼoa� J�Da�=u�O.< ��PW�bN��3�_GA��̼H���o�7,;s��1b��SLH;�S��VC��3#�b8���I���:���u�����Aq��'{����ƽ�GΜ@���8*�w��58�*n��=í�`=��0��SG]Ң(_�<p�a��1�}���(d�O���e]V�Er4S��3A��S����5��7��_�;�^�\q�ۘj����N�nk%��6��JO�OԌ��B�����7��Ua����|�K��El�җ��\�]�4B��s{n�H$���T�W�:Y�O��n۵�
���!4�DNSN�����r�U^��;�w�xB�b8��VQ��Cu|��x�|�*�����=����}����E�~�<T��p '��4u�N]���˪��E�2.
@?��끘%�i���8q��>��������<l��@M��_��U��ruY ���!��g�j����� "�����v�d�b�6��q�,�S��������P���Ć�'�~7�ˑ��[�]�o֬���di�Wv���o����f���S�;��7����Yp�ⓖi��p8T�eP�2�����ɲ�K���̕�$���]&�cCv�����hi�������_�f�"q>Yq���Vv�̿U�'|R��x��p$%C�b�ꐪ��il���å7i�v�޸x�V�Q��7�����&�m?P1��(*W�,��#�h-� Ҳ��Ҩ���� �v�5?\)[:6�7���(2e=����JO{2�X�I$G���2Y{'W�<����ʪ���ʼ�|ʸ��]������D����|�a!^G\���j=)(�5�?�T�"���kx��A�R���<����O0��M���������U��ao]g����uE-ia/�p3�¾I��N��]��"�d���F�ŕ�5�r�%f>���E�5'~�#�Xf<��Fm�������	���њ�2��lU���mވhQ�=��i$i͸v�σ�]D�$I+W�8
��2s�1���%Q3�9���'���&�qsv��fy�, ��?�r�Hg��/���n�4��!/�-v�[��Cy^ml�b�F�	e0`�жyf�����5o6�p��/;��F�O��E>C/.�'PL��h�J�-�_O�T��Ι��͑%���f#�����DP��n���@��H��`�@�5S��F�X*�&�a�
�Ë�Y�=��'����'
@0vd��y��ǭ�"m���zAweqñ�Slǉi���xxt�Gj��<q�5��I6\����tF�.[�"�4������+0����H>����b�t@�k�J6n���+��%��σ0VV72/#ʲ��U�:"�f�!��l;Z�����MO]A-�%@���n�=�,��]���k�_�ENgR���"W�"�V�L?�'�?����^����A�`恄�Á�<�K'��"���P�<"�Kp��"	���]7��LHR�as�(�,��0�h�[�xC�*vC\o/K���;(G��x��J����L�:�G0�1�D���Lu��V�2��`��k�.[SN���o���o��O5@�2��V�
�9u9����L&��gn&���>Q@A��$���7�_}Ͼ;ێeZa�xSD{Cq��5,Id�ٽ�r��t�g�b�'�<���#?6�!(��t3�є�JW���8��7���ip�y}9����G)���}�t�`���ԲH+���բg�3=+��	�̪z���K�� ?��gɨ�ߵ��X�I��|4�CuRYT����I��BK�D��z�v�r�=�[ ��Fv	��DF~&�����L��5��!�3vR��k�X��Q����Ң��=�g�>zZ���;�<?��<�7 �e��N����88Y�O��]���S�n]/lEJa�<)
2��T� bVQ�Q��ވ� kV����%�[����pc�(ZQ��:�c(��o����"��"����f�e�L̸��3� ��6]H_���T5�wq\H��f������x\U��?�U��޺��,3��ܟ�j���̻�xp�/����گ�zRŃ��B�DP݀��f�wD��V+��ue�Ӡ�eM�y����0\���4��(p�h�(W�͍K�����ZNӷ��:����M+,���q�c��q�#y�:a�=5�b{a���Ҩ������.Oތ�f� d�Y���?�U3X����d~b��t�	���\�F�˸��$��۾@�qX���;H6[���v��%!��.J�!�x�*Xʙl-��(]�eU��4T/ y-��r7ĩ��D��M;>�w5��̃�8�I�f�Q~�Y, �!����`!�%����eR��M�c��7��\aL��F=r.L?kypw�;	�4ʣ;P�LF��[Qu�H�)Ƈ'h��2�4�
��ѣ���d�Ap�9�i�SX���Ñ�2�c���� qg�mB*���_��j�;e�"q�C�
��?Y������[gY��*���Lm5�y�n�BN��U��0!����v��^��4�9Z�QG�ʤ�K7s�525����)JM������AF!Q�[�E�)�y֞ V���=� c�j���.��׌�5_
vjV�K����^��k�n�{����OZ<��ˮE��Gs��5�'����xd�G�ߚ�ro1'!���U�چC��
\ {���q���do�	'�Q[���p6XP�+E\�h�h]?��[m(����l?�W�ӒI2n1F��Q�O�xU(w����#X����YRW�m�E܇�shs#$'L�>8�3F�l`��p�h�ѺŇ�@���]����ĕ.`>N�36{!ڶ��r�$0M�10��Ѻ0� Xa����N��O��%��.�oZy>P+��L�
��f5R���=�ΔM�/t�@D����!�
h�G�fq� ���T�	������_�֠���0���I]�����gNu�Xv��v��Dݏ�� *�o=���z8(]�e���)��c?�K}��\N����XGu�]��T���%���+Ϛ�����FI{�{&�Ъ���[ya/H�4]?\z�B�mN�J�i��W��4�qf|�4/L�~�9=ui��$_�t9U����(����2��o�cU�6������#�F�|m �d-�_�̫�oo˼!!��.�O]�0���At�����e��J�> 0b��9#A���%5�$0��x�"�,�ngI�h&����~봲9vb�tyj����3�eg=|%PVEY��
�������j2���{�*��2Ϣ�4�d�z8�_E��1�=�Yq��3���m�nٞ��c˘s��˘G��w�<nS�y�����ʌ|��I���i�՝��c��=�&�T�O��'3h+rZ3a�`�;�ř�q|�"w��aYݙxU��w�p�� +�w�ik}J�:U��J�jI)2���b�zO�WvT`"6$�zX�I!��0�z�6�ʢ�#F�i?5^r+��fooG-�e��9�Qc�,Ԥ�g#j�^�ʳԃ�YДƙ>j�Ȅ{�e�m���L�w�o��73?�#-?�I���T�𕀹u���`���^�`=ӟ.{џ�(��Ǔ��Q�֪̊��
.ś��b�	e���� r��ˣ�^N̟=�ѩ��C���L���Ie���ÐD��Bo$����d��\Z����."��    ,"��a��t��/��˿��z���q���cM�� X[Ɣr>%Ӷ���]�!�^��|��)&2�����بI��d�:�o�xؼ�
(���0��ޫ���	a�c٩��M+	��_Ș$��<��"P�ey���_���)ݖ�3{�L9PsLsp�!����_`����y�6f�f�lk�4�u�wW�C�R_��I��MA���c�;�;MY�h�
<�3��g�k��H��W��`�'m�F;\��eK�I��,xg�fI�,ٺq�]Q/Z�"s/c���de��@"1L(���)A��O3lP�� C1���T�>ص?�1N��]�/�_}�S� boZm��6�xr����k?��aq9X��<�:��dc~h��=�y6f~���\��'/\�ȼh���z����f	����w:�!�J�}��yњh�8�\��>���W��͕�t&����V�յ���9`(�>&�����]��h��_rYmn�%-K��C4�_��E^zJ\^x�Q��|5��+�,�'kd����{(��Y�i#�F����}]�*�U���D-�O���)ognj��6?L�c2���x�tO�8����3n��hq]�I�KX�B��M��}K��YP���T�h7+��E2?�W�ᕗi�\���h��7�����'%/㎮�͠���y�z��ɽ^ի�"�H��"%Q��EF9����ć���3)'�?@@%�i%�]��ҍ{�r~@,���G+_2�|iZ{��"��~q�F��(-�?JC�1�b ���X�W�>��ë�U���D9�?�b�z<1��L l!Z ξ��5RP�`�0M���T7؞I���{?���z~�Z�rv���!d��	�+�e��܅�$9��qo5�LJO�|�`��u�v�~���|�ӹG=O�bӞ���]��t�@	��W$=����� �x�KZ�R�A�3#��wU��M%H;K�=Q�����W�J�h5�9+�^ <Ԁ��?�ն��|^�����l��.���hi� �)���V>(�OB���<#�f�Q�+�h}5Tɲ�Ӯ2��
�/`�W�*��,�$�4 ��E�;4����4��Y�h���QJi�ᥩ�Wd��?�"Q�.�X���:eJ8N'�1�&���ސ��LU9�rq�%�.��=�����f���0AaH4���(tjc+8?��х;��z��^���;���+��=ňt��`���D��f	i!Ԏ�1�0ճ@�dM)�I.`����N*��������_�A
E<�hI5�����fu<l�K�9j�������bZ�f;Z�����̓��: )J�p���l��j:����$��,��[�(��$ЙkG�je�*�c�u���Z���<�.����eܛ޵5�2��ɔ�v�Ϯt�d�""'|/{�e�����v�G+�bx��$�s߁�:�k��d���&9��+�CY�X�W�B�j-�W�*2�)���9�6���E�&*&��� [�L���u�_=�Y���SE�/S|�+Ki4�G���ĭ�W�xU:������lP
�[��a��%�^,�[/^�%�r�̂�����M<�:�Cʴ9�٬���80����+}�4R֫��_&��·̃��k(?N^Z!)�)�\����fSvD@$_����!r�Ǵ��&YTy��t ��>��h�Y��)WO��Y�i���;ZÑ�$����2x��%�����FD}a�]��,�w�ԣ+�s��H�U�U�I��0iR����/��O�S(�bl<dR4[.6���8KeJf�zۊI�n����I2�P�X�����}�N)�p�.�����[�6�(VgKN�8�
���U2Z#�e��eR��\RgI�Г*�HzT�ÌJ����,.쩑��TP�U$�Z$B� �.��կ�  ��إQ�{�gefȦv������o�� ]��?Ԏ���@��>�q�4����HUH|m���;��������.��t�*�s}ȟ�6z	+����H/%^N-?�)k���}�á�4��`U�/��).�o�WF�����f�� fW?7ˋ�p�d&�r8�fe�U�U�#P�[�t#=��%�����b=��4��s�=���$�i��-i�E��$ �Gs"�mBfۢ�6g�Z�oG]�郲��d��L�bl6�����>����cwP�-��A��x��-�d8� ��?���k��1�rf�F�5��ٹݿP=i|!y���E��1����$�<�����'��#2�b�E���ǵUI�3$㱝vz����E\����LdCF�NI�sux��b�{T�uo{	����AJ
�=��"^Pܜ��*v� �������`ׂ��wa3-��u��-��rL}+�����6�l�(�������Ki�"��yj@ձ��g|tds�|*&zc�F	��>���F�K7m��tӸ}Die�9��c����(\��cp��4��"Dc�����'(�u8���y�WHU|P��n3	+��f;&�C9	�n�%7�f���F�ˇc�i�(W�2���i\�SH��v��_��+s�Y�b&��pX9��?u����;s\��0��=f�C�B2ddpq�o�1����)V��ɴ7p��2��P��=�t%����3���F,Ȥ+�t<�e8���Q�g�:
��%r�Άjp�a�_���C\�vWi�X���KY��p�8��:r'���z.�p](�Lb�&��Ex�0b�.l
���rGCVÁ�,�R/����i�!m�x�Ѿ���·--dڃ���>f}yR#����B�h�����]�1�y=�Ӄ�fN*��kn��@W�����2�k�Ŋo>)O�WZ:�G�����{��l튞�F�`�~��o�ry�
�D��3���M�~5� ��;ʝ��Վ��"�b��-I��:Y퀘�����V �5Q ≞��?Z/���ge�����8�KĄ�zPE�����}����P�F�8�2�ti*�Z&�L����Ye.P�t����^�daz�Y+�l������S�K�L͟���g�|1u.6<KO�`�L��y�V�!�<�3��y�=ge��<���N�x �,՛]1B O�J��!/a�8,a6��j8���yٻ���^�gv5~Y��݌��R��7_�8�l�ޅ�n�=p�Q�i
��L;i�t��h��j8؟�Q�5muX�{�t�^T�p1���o�^/�&��k� ^���$g��]�uH(t�b���3�f��6�K_ ir�X�#gX����
3�׷����� `��!�+XQ�gۋ�y�������>{ ����8�"x��`,��1�b��w_�n;e�����iCS|�UZؑ� 5p侉 $h�6;��cvG���T[1��)�T6��6!���\�,��@�����=�ň��A�T�	/��hz'p����<,[����f�ռ3\O�Gm\�FH�v��y<xf5|Ւ�O����3r�t�c������[vY�
�YX�j�cr��^���f�1,���;iV|:cp5|+��qe�mb~��{y�=�}�4�zɒZ���A�l*�	 �����v�<��u5|`�b�����	��^���v�[��w��.`ޱ֓����t^WyT�%RX��Eob,ߘ퍻�z�
o�X$�n��o�×A]�^�(�,[��8)zOi<,��o����r5�n���Mw���_g����F[���,�~ɫI��ǯ���S ���@&�[��AV�`u�
�;k�ݎ�qY]@9�����jK���]��3�-&9�|�
ÜjR�����6�H;Z�Lح��q�{23��VЩ!�R�~��%R�e�9����r&i�ck�C۷1u���q�q��P��B���/Ks� ���Z�m�O�����r�����b�K�`�a3�_�G}�3��L�i]����e�"��x�����#��"�޻���A�?�Qy~�����M�Y�V����4'XK�"��ugZ_Y'��M����{��K:$��t�N��	Lz}�����BQU��U�����H®n����˿�.Ÿ�    ��Y�PU����j\�I��~�\f�i���SϬ�]`<�˲7T�}N�>�l��8夬�d�����:+��&����io�^��\L\�Q
��
Vv��6h�QU:�$����n�kh�1u
c�?���Tt��*�(�!�2Ib�\�q�U^�J�w�&�ʭBF�6�U(�:X[S�I����5o.�"��!2��ށ^zKD�@�66�����B��Ǎ���W�(�����sI����~I�+���R�_ab؈����Z�5e~m�Mp�����a-�ף�uD�>�lU@�R�$O��I�)�_����.���NFG�7�z�m�'�/h_��YHN�E���aq`FbH��O ?��ϱ�4��[ӊ�SK��EFoek���3���V�x��+�ĘZ,ı�����̚�!N!�Xi��
c3%���N��ܜERy/;퓏גtH�S�Ҏ�{R.�hps���"����,�(�ZA�8N\�����+����$�|���xRú�~,<qb����'�K1���eYf�S��'�n3�
+Nd�:1�I���9O4b��3�g��p22�^�=![�q�N*c>�YXô�pX����������ӊf�[)Zo�ñ=�Pz_@����S�;��&ŘǛ׆c�U�g����j���K�z����	���yPz���~ū�e�U���W0��/H�yMz0Ǜ܆cӕK��ն
�J�b�c�{�=�|��e��E�o�hWm�u�_�Gl>�I���7��Ҭt�OI\3χ�����p��L��Ztr���������ϼo���&������c�UV�Β(I�����Q��@�F:��ñ=��ǔ~��6�VER96���ϻ�	�������p����u�!���@״��,������.��r(�ڬ������@6�?�`�� �\���S^����u��H/k�GI��-��^\ajM���\�Zހ�l�?�)�?�.,JG�C�?d����q���5!�I;s'��*��&|B�ɉ��;j~����,��e+A��;ˌd&��%�#�4�Rq�o��h�W�	�xŋh�s<��ʲ���$�<��%�Ȏh�q�H",��9�J\���D{����P^%,I�x6�R�M��<V�m<Ӯ�8rZI���JU_j&KO�6��Ǥ��G+�pp�6��C��,xc�B��@)�RU�B�@�\:/KG\�|U�Y�IyF��m8n]�u�B�$��M.x�M�m�l6�o�ܺ�&��8`��ώ�՛t������u�VoK@}5}3^�^����7;�} DvT0�e�%�_}䛔h8�]ge���.)�W��S>��樞=�k�--rI��2�{g�C�@b�,��a�pл.���k|�\a[��$ p����ެ�[�~�lw�?%K7��V�V��x]fE��I�ٞŉW:>�㴏�Y�Q2�m}K>u2�&�L��k]����%)�s"`�fBe&�v8��Ԟ���#g�K�ZIr�sJ���z��5�O';]��Vre��3�k��yݽ$ʳ�]�gR�RY�\dXoGXǗc�[���e�o����O����o���z���'�ٵ
@3�(i@�oWg�B�,� 6[Q�H�?���6�����I�;�Oi�}E�s�;�>�QG�X��3��f̑�9˾�3���*	�����VRϗ$��HL(~l΋�,O�i��{	��p\&�k��$�.�VlA���������H��tM[��zҸ�x������,ۛ�d/{P��~����*�<���S�=Y�Iwt�h�}^۬�\�y�f�@��l�B唺{����G�M�w�Y/P%��H����-�%�ߖ�	�3�
��<���)����"�f��ñ{:��+A��6x�ԝ�&�I�/MU���$-!	j]Pg��s��Y��L$�����o7���D��6�b�\�8���A�i<�K����u/H�I�=^�R�æe�jC�p�3����1Tq���m@H��Ōo���u��'L��󅕲�X6`H�b��	�~	��<�6�J���O��K�*qXo�pTw�Q?��q��.��\�g^�	�SG�<�ʘSȺM:y��{�&��eY���^f&/��ꙸ-�3;�{t�����R���k��u�n�,�)���[95������B��߅�]���u#m�e(�I@�,c<�T�d��Xƾg���Y��������ۊ}4�
��f|��\�i���'~$��жI~C����e�����J���O�f���#�2ړ�g�6� �i<S����pA+\�i%H!����AnN��e�����D܋�H�=�D��5:��ڰ�?b�c�T�w}:v[���'@�'�1�E\j��7Աp�}IV�w��l�9����'�7�ya;�M�=ڄ�T7�.�.*+��͓�{R��Ҿ�o�ۘ/��;��� KVS�sɱ=�䴱���Uk��PZ\�Q��|�U��A�Е�/���:��6�r�׈�י�	��E���q>���ޘ�M5���7�$in�rQ$nl���ۺ�O�S�_bu��1K/�֪ͮ$�tz'����{��mIř��(���ף��e޷���f~Z�!�D0�>W��������Vi�Z����\b�H�R]�k0@���5�t�<Zӑ��$I��wR��������{�?^N��;�d��.����k�̓�g���5H���Sw��NH1�E���ԕ�K�L���@�t�^��������w豄��U!��f��H�f�}�j��kO�guy�����qK�u�+��ݟh�KĄ8�pP��pc�9��_|�k�n?�#�q��:�[���5}|��lT�`�.��7�:�-�ٶVj%��|rTA�2c�u� S��>+6a�����I��;��!�|�'}z�;hÁ��M�.�歎V�}���v�^�N
�53������{��:E�Lu<���B$�*���0��B#�����9L㞼/ŧ�l+PY�~6K�Q�ͯ��r�a�m���������('m���i��0r�D=RX���8���J* �D}��ET�֥ħ����L{ECm#�8�5Bx�~�6N'��@\w�g�ʅ-^��DL�u��ع�ݙ���������9L�yj48��x/,r?ڣ�O����$����|U��bӈ�j����a
�����;����"z��˩�ϫ�P\�[ɯ�K��3) ��S�*��Ĺ�k��p&��4��f>�$ɋ෎6zg>�����(s`��T�r�\O�ٽ�I����䆚Ց<��A��~� �&*ާɆ�p�!�Yl0��D�g���h{�ϴ�:e���S�|9��7t�Y��o�;����Tо�ձ���]J������{��K@��:I�p.�LXb�$���ߚ��-�?̛<�3<���-e�-�_����A�Ӊ�{�CZ��p�!��?ݣ���.{�T�9��\~�a1ל]�����Y�(O�䌇1���'I���?�U��Vr�d�K�8k�"@6�)����3N-��3�� [nZw�ф(ivC�^�6u@���'�NSR���(�����#����-b�%)����M�oO�,NSw�(�Bg8�H�M�ƛ��7/��
O'<����d�lk^�c�I�
�y.w�8�z5�Ƞ\c�f�Զ�� &�vhE���IȨ�yǏe��mZ�P�*�l�"QR�$�9�V�O4�[p���ѬЙ�'=����rc}w����"�S>�F1�o��5�4xD�\ϴ���S'ۨ0zQ���G���� Qº���4!�yl[�N�L��j��Bػ\�J��_�? ��X�u$�Y Z㣳�dVM�Ӱ��ϥ�E2�n\��3���-��UW���RXԾG��_�N7*�!H�A(�u��$��[���b�������T��� &�	٠LI��q��ҋ��QS��Lz<G�Q���3ϼ��Ȃ/b�OCT�����I�T�X�v����O~�F̛`0��Wv?��G�b]�]Ϗ�O��ZU�{;~�5�(ҝ�N�Trm/����5���F��f�aMU$��*�����N�    v �o�P�[�?����� ��"���q��qZ�x��+�"��E|�$�|������5;��םz�3H�7�[�ڣ�E��o�m�p�ͱ	��D�Ę��?[�����ّ^D���[Y��bZ��xW���缅CQ0cy:r��X��[)Yu�X��v��/����d�~Ԛ�E�t=?��Uz���̌l�XF�SH�&_��ǲO���v����*�
�9�q��?���t.�^hZ:���Z��+4S�#v�k~�O:���O�n@��<�}Œ����rѱ��Q�J���pQ+>�W���,X<��{vD]�y���b��/1���-<d�:e�k�N �_�n�;3�1��#̈́l��b��}!�䧫߷(��N�q�f7 �u���,���/*{�?;a�;_�j9G�^�QE?�I��h��������ݰe�C&�Z/Y���\�Y��1T��KR�;6�*.�XB2T���I���ř�j[�l8��Fi�7ʥ4��n@������B�]���)���yv�e�������OkRJ�xsqC	�ܻK���hr�sE6�N�pi�?~b2�{4����*l��`�w~KS��r���uÑV�"�Y��O�Y�����O_x9�a�HU��KΪ��e���:�.����u7J���N��dM�87��A#4M��iyRR�x�n}C�*V�TQ�Ս�t���j ����x���QL�[�q�Z�Ǻ����'x�BO g�H��ӊYt֎���I$Dp}�����uw�	�:P�S�M5<eO.�5��=s,�'�y�	�?[�66{�'����d�c��핹S��X�	3���� +�KA����F�Ov$�j������	� �p�ׂ� $]o�z&��|���0	���pI�A@����Ŗ]7�J�O��ێ�|0�zm���Y�^���z�Y���*>A�s��m��ߛ��8A�ɀzy'
�P�_��:2� ����C}o��i͍k94b+$�3/���������(.Z=���d��ɠ�=�ղ:�J~�m�,����h>�?d��(���	��E�������J��4MF�ͤNC��6�K��[h.O.���tjn�8�X�<����d���45��y�, gY)����Zs�$pwK�*�c ko(L�s>�����ȚI��%��8��o��֍��@O~r��֥�J���+p��$[D!V9��;I6�L�*�3mU��E�l�u̹����:?���zg�����m���mV'���xio��N��0Z�M�".3�t����ʥ��z4\XR .�c�������ޤN���s�̪�Erb��O�2��$TU ��}f��y'�Ɇ0�?�J$pqJ�g.%Ā� ȡ�ԏ�W�	O�|5S�4�����]�r9�|8��q��
�@��L����2�'��s|����J8K�M�A�NCeًǟ~$�Y#9�:�&i4�e>i͢��B�:
\��kQ��4ҦǦ�S"Si�vK�7p�	�s�V dDN�f�y0.��kW���������H�b5�7�1 ��X���0��̘�1��YL
Z�fV�GS�Դ��Y���#Z|��h��C����ǖ�Pj(���&�P��Zaju��L�'���3��g>eͲ�H�eT��rP���Х�<��{�]�]�u$#���ś�0g�r,�|�$��3��������U�戔G[�"*�?Y��?��=�O�Z:�-��i�9Ƚ6���ܞb�ܸ�zZW���p86+��{��y�q�X�kw������C۶��$V�D"��2ldĈ$N-=sĩ@w2��L�����mV�I��bm�k���@�1���z�0�a̞'S�Q���.��dfI6�D�����	Ķ�����^�(��
����i^�m��+Ǭ!~/�u&5�px6����7��蟩E�(Li�Š��'�[�>?�y����<��̭:�Z�i�;qS_خV��|�\J6�"���d��y$���a�<Kg|������
Jا�H���p� 9��k����A�_���P��z��|8��E��n��N�[K)���Yo��Ϻ9] h�X�Ie���d�Aü�RG�M�$����M�r�6��sɀ��+C�ef�f+c�^Y�����������:I�!�Xe�B� �����{u[l�=�5�v2��*�c~y].�)����X'h;�- 9��
sf �n������������6z�36�+"��QSH��M6���%H G�2kQkz�*�]�	��-VG�
��D�V&zG:PZCh�(h��}�yh���Zh�̊��f7�Y�i9g�mƋ᨜yF�^{aF �jR�
�)%�:�RIX��,,���[��Q���*��ا	Ȥ���Oq��2���$d��Ċ�*{V���b1Q+�$�G�z��U�L������?P���R��}.'׎������2_����	Y�Њ2���4��m����t�� �t�K��[O9�f�BՓ������fEUy_I�[�T����T�y�� �������ӻhBh` ?����?�I������X�e�j��JB$�Z<{��>��#��D+�X��#��3)�1�ġg�
31��q��j��֊��Z��v�q|@�ѫ!���fv�(�ѽ��݂�׈��0��|>�Vn��z8xV&u����f�ڙg�QL�=u6�Z�t���>��q�\�l&v~�p8�̒�E�q<�E��Ȁ�:�9�Ց������S����7�+�̓�VG�ʼH3ȠV�?�D��Kyl�>���*�-	�N�>G�x�eA>��h�W�C�h�]
?(wٖ`@�#���$��U}�M
R� |��Ų��^�Q�[r%�z��	���xq�J�#����/�Q��������:u��ڬ�,f҂�#�*-s_�*`h(WtT��B�Ԛ��5���6�y�ɋTj&#W9�,�����n����U��j�9^��8v�Ti;���$����t~�ѓ�D�.�M
%Hk_Y�5��@U�A�7ھ�C�����(N��#�[,���ܣ`�*�4��K��Y�������=۱E�>�,�-Z�W�05>�3�����Q�޲;saRc]4;ӈ�vt����6MZ~t��:3r��D�t���z�Ie��|�{�5E陿]�c����hq�p�J@�qg3�
7�����hִ;5�(«p<;�~y��z �Ik���D��>i�F㰗Á�*�R?4%I�Ǌ�(���gj�qF2x�ȷ��.!�^t���s�_H߭{4�^jc�(�U��]}9��*�^4I�].��g]�Y�dJ�r8�[e]�bdH�a�!O�y���+�+������fɴ���^j�Aު�{<�$���|y]�o΢U�gF�2��
4O��}�zσ6^q�:++ߠ�w$C��9u9{	�c���i�#<C�'*(��^�s�v��ɐ�R���u������a�RG��wE|��N�as��ˌs�~�"�� ����*�A|,�#�u�Ğ�����;���P���BX��Y��S�L=�9O�Z"�f�X�l�L<&�`�B[��8���F��a�}R���җY�yp����l����Q�����c�o��<�+�-V�)&�ף�=?ӱ�4'fҤ�լg���m�<�=G&���d�Q��N�I�IRY\`��<X��K��ӣ��p���"������K|eY�jX�U����A�G�P��4!��Z��I�m����˿sD�� ����E~X����bs����n���e;�HŞ�˯l�+�
����+�3d��d�v�$����Ҫۄ�1���k����@��NC:�z;��!=T�\V!%�|�Ɵ�p�S��H*�#+Bd���v�q�p�C�P.o8�E�*�4	D<(×���i�E2��%Q�M�|�b�0m$���b�I��iM�Y���]a�ߠ �/����f�v��fدx�_�,Ԥ�#��ñ�J{ J����zs�����%D��E�<���1���F'YU4��F�,�<�ǫ��p]�E�΃�1��`Nk���#j    d3hߵJ��
a�b2/�Ϣ�X�p*��礳�xi+U|C=�ȭ%����U�	F���삍��=�(U]e^t�s��&�(��OU�_��ִb�Ɠ�w22���s�8+�0Qd�O�@��G��9#ŭ�<�+���/�@��}�"�rlZ���\k�ovr`']M�hUM�W5Β�_�U�&�B -�<�Ӻ�qɔӾ-��i\��Ok[~P�>�Xj��]�+��!W��V���W��*�ͳ�Q�P)d�#�O�~�_�|�s��-|��^p� o�X�i}����PW���K)���\�f�Ne~��2��|�^�.�)�&-S��f�9p��V�މ�WC��^�b���b
V��2�[��Lb2O���K&�E�̲D��0�v��8Z���%β*�%N���
�x�Ovz�����H,��ʀYpl͍��1W�ڤ2�o�jx���{�Y|��L�����xd]�z b�$�!�'�%{�W�����'իo�^]8Ǩ4˂S-!-����e/;����Ƽ:	���_j�
�mYh��c7-�1�pÉfQQ&�̘��{���X%̈��G�,7�W���-v�=��^��p|��i���Lz�,F+���b�Y�b��e�`H$�#u9'H�X9��͊Ѫ�^�*��48+k�'H�V�	e����6�O-��{_�Q�NȬY��)gR��5��H̪��f��NҶB!K���w$Z��A����������x�'�yv�U��..-��w$)�`�L,c������N�U氅��e�+�� G�`��w���at4��F�\�I%��h��~٦Q{ZY�UV+������`������7TL|�� �0NY���[��#����8aVo)���LB��o�{!��mk�=�L�DX=�O^���(�A_5ܦO�:�X��g�(��]�o���[�3�
-7V1�'9�qs��l��'D�^��Ʊy�x8���(�L��3�_��o�d�g��\�U+���,1�������OڳQ��6�aJ+M��w�Ű��8����w�vJ��C��*���!W�e�
ͫw�9޽�| �(���<
>x��I=��4��A��*P̲���[۠�,r��Kx����w��W��O���c�u�B�������a����|@m�������/�Hɏ��K��T��R%q�W�'�WiV$Ɨ6��td�]�����6��B���)
�ͮ}1��b"
>ɲݪ��r�t��z�@)prC��2u��<%�Ғ(��`o^�krA�*��z>��`Wv8@�����u�a녱���$�bw��3��������G�f��L G��^�u����'�ט�CL<�#	�QE�̑����a\���ڿc����g�&G뙊[�-O�: `���@>8&��'� ���@��
B��Gݻ-�m$[��x>A·˖lY�cYڒƊ��ٜ&���y���ʬ*�|�@��c��ѡ�JU�+ס>�ֺn$p����G�u���<���3����	4l���4��z
�QEj�v�6�Z���Qo��>�F*4|�Y�[êJ_��toxsw�tB�YI��:q�d���l�G��������XgYӟ>�T�:|eq岄�,���I�F4�6)�?�p���?]P�L&��j��R�tiʏohN9|��a���|V�9�p	���^7Kv�GӼ1��d�ֽ~�9�KN\��6�(���݊�{ϳ#���2I|og�F�Xޝ�~��������ǘ��+�.���ӻζiۗ~7����LѤc�{��x5 t���yf49��_�<��^}�o��ѥg�B>h�ۣ��_Ϊ!�S3��Sw<�E�k K�>u��a��_%�Tí����3��]4�[��f��>�I�82����	`Yeq�,ۍy���R����x���Q����N�=�8��j1��Jm��2��
����e���s�=j/*�5�Ռ䥯��d�<�A@�A��=�����8�}����� xX���
hcyűO��zM4���u��(>M|9Y.j$Ng��MU�L,�~�gi��S[�m����!b�u��'8�x�AR�)�J���yf�ÐQ�~症�o�J,pd����Zu�ڽN�J/��i��D��X�.yX���S��?��@j:|UQ�y#9H�
������4eMsx�4u�_��''<��5QP��@�A����5��s롥��zۂ�dP�vn���ޫ������yj����w��:U�J��h��a����<@G �5���?�/�;�,��ݠ1h�} #�)�&C؎#.�*%�B��+��w��t����/[l ��Ė@���k�>�%@������S|�bLz�ƙ(�w<�U�-,��?�6Pbx-!��ҾB��cJ�H
�lR�Ɉ%���ür�pI�����[�T��/$|�ף�N��JYc�6������酉b�@��V޵���,v-�
O+r�d[_��Q��k�i������B}-�������'?}��Ti�6,���tsy��F����`��@w�W��bdm�������Q����<X& %��2θ4�6��V<cQ؏�8�U�Ǜ����.[N�y6<��������5��z��M[��}w�M�aG�k�� � �D�/��?c6E+	���e���z�7�U2�AW_��i����+�G�\X���wO����6Z�b� O���x^n�w0qE^�W�&>�l�F��͋�3ʏ�4*�?]P���/f /�i�"�W)=�If�'}¢�*��Q��t
�hF`���2vu�I����N�*Z _�jp���ε�����G}��4��b������mC�X6�]D������[K��J ��}����q��y2W$b|����Te|\������ᛆ�H3�,(������^�ȅҪ����R ��3���5?Z�)�F�HM��`n{?wm�$��;���	W�5�21��;�̸rsv�,�Co�0W��r �{B#�+s⑆f��yY�-J?����A�ㆡ	@��� ��,� �?�4����x:�Ի��~i�8$��D�><�Cڧcc�J%�	������>�U2�~{�D@�����To��Wb�e4"Z5|��I��"	>��9�m�b9�
��l�K���@��"�'Ũ�;��a�;Sq_�5يK�;�Z�F*�DP��S�0�h���e�C�u���~����}�/�0��*�e �u�z��
L�Rmʫ�#1���3Ϣ�ln���ǲ^�&�ѱԗ�d=h�"s�X�iq������$ɲ̽�e|V�63m�{�D�w;3�5�zņ_�0|�p���h.M����!3�im�W�����Ī�hL����5�e|���P���� �o\�E�
W
�~F�Vj��a86�da�ϭ2�_y5�÷p�zj�o�]��yVN�0Ӧ�L�xs�2	~7gb#-�ճ�n����r��V�m]��C�.���nR�� J�g�wa-�����(!v�$�G�[��#�A�QZtQ*`�� ��חK�L:���"���ӪV����,��zaa_������l; �P���K�-�έ%�JJ2�di�9�L�1���As������ t2K�@E�Sj�-vi�b�����S�_���%����"����1�i���Mz����!��
sX��ܯ��AS�N���W��D�T�N �y_%V���:����/�iA��n��*�U���%Ҡ�Rx�Z�=)^^�v�qީ����>,�kO��Sf(XJ�`1�^��0	r�@Y�:��,�vϛ\�� ���`��р{X�DUa���ؒ�$iu	���{^�[��@�թfҿ'�q�x
F_���U�\���D �վ�\�$kD�&m.�S|j8 \|`�'5���U�
�J��������Ehc�"����	��m�Oc@�Y�r[���4����S�7ʻ��$�l��D�P.q����ݭ��Q�!Q���s��[�NJ[.Qd��nzS���;m�U�{�t��h_�?]Ȥ\    =Arn['
�`��0h��a�p���fś�#)�b��dEB5)'3H�(�ҥ�G	X�t i	�A��
��3�"�4�F�IZ qC
�'wZ��h�p=�0�&��p]K�o�5�,;%���X�y�_[WI,R��g�H��w�(�#R�ڪ�K?�2�8B���� �k�t����f�L����h�F�O&�258-�`ppp�2��"<�,0��ED#�"�?}
�Tl}G��*v�r��KDz֣�<c�����{[�=6�GC��5���˪�Ė�n�ZYľ�)ލ�aT�t�^�So[�$h�}����9Э�5��ͤqݙˑЌU���*�^_�H�,Nc����&����A9��o��4+��g�H��m�V��? ��x�O����-�;��g���������:����<C���]���{Y���ǀ��x��.�C�i��R�����Qʲ���y����%0��/A<�Ɛ����n E��)�he&��i�w���
:��2��lU���lq�4k##�������W���H�逃��6��e�ސT
Zl�X���K��q̴H|�K&�ǋ8u8��`��~'��SjJz�F�8G¾�#�t�����(W��p�4L�o�9RA����Qq�
=dwYA[���Y�d���Hd�.J)3��Yל�6�h3��8���5��{-m�\ށF�y���4̃w;j�u�"@")��QW6gr�ÿ��X�i���`���d�Y�
U@D{usho���x��畿�jr����w,]ݩ\�Z�g?7�c�r;'A�G3�{9�X|yZY�e���2x��%�*~($j���*x<�M� j,�i}$zZM�|"p�ݰ��O�-�D���צU��X����[�Q�ʝ��D���q5�n�,Ҥ��x���� Z�s�)
�G�a����`��(��kt��u����ua���?�T�O�.)X�j����ZV�SߥQ���]�`��o��5Ts j��G�<�b���Y�q�.�(HVЃ�L.�
�k-��z�Y.�Y�`	�u��͜�-�Щ?,��β���V�6�w�tl���&;�u��E�m����$+�P ��q���!o����+b'���J�����r*�qC^�����]�;z}Å�U$qbıo�|�Ԭ�5}G��nc�&n���̅�M�UTJLu��j�m ��	������|G����:�����l�T�~��,���Op4�X�es�l�B�'�w�
H⽘h�Z��,��p%�H��ʓo�<�a��@e����(����tS���x�	˒̃��
�(Ka&WJ��pn)��Q�'ϊ*K��@J�H��.�[��X�6M�'�TG�EV���,���%���s-�y�^��_�v]5܁�*`�n��H��n�^���^۽��u�4W�Y�l0�*���y���E�;����ўA�J�[@%0xFtk��aY3T�y|���}��M�6Z���effp�rȣ�%���{}G<�Z�i��e��Jh�~ًZ�V��ʋތ�A̴]�����,�=5���6�]�1��p�� _�"��(Ȯ���ɵ1��� �@�8>��3�^�Ms�L���4�-߃)�.[�J�z��lM����ֱ�5S0���6�'�g!D��lR\}4~�*���E��i<W���H�*��2�e��8��Ӣ�����˚�v�-Ÿh�ۓ��5��k~��:��j8���Q��8��o��?j�n�� �40T�؂m�c�h��}i��7kR���9��be�J�Z�K�eo=�"qd���8��MjxX|�dp�1�۳H�V77𱖓���ѐ�UuG-��/��4�ɇ���@	(����x��E'�9���W��fR���hV��ʓ� �&����:#go-.�̙s�o�!i�Νx7��h��Ĵ�{+�8�56�����^���;�,�<�3�������E����hV7���յ�,�hgn�H�ش��hĈ�@i���c\��7�����_��o��5@
ZhQl�����.�L#��u�<�?v4�<�E:��1^����,z T\����;	qh1\jW�[���=��-_g�/���c�~�<�Ww�x�l��0��ifH%bu�b�X��Eb�hJ>i�6*����a�n$K���@���`z����+וz�^ �y[^j��[f�*�b�Qo\� �쁟����h��z8��Gy�fI�	�)6��ͩ��D�0��#|w=�˓0�eI�_jq�>��	$���3w�����Z=�5�qC�Ҍ�qoM�[�n�D�PM?̇X��ϻ�
;*�F�ͯxUqb�}�Ŋju����|HM��i=�2����:7������5�А
��,����Đ-N9����t�����I�H�R����E�ګ���&�y%�t��������t�b�e�y%����i�jć��o��a�S�.si|��b�����9uW�b�؝�!c<�=�Y3Ǣ�0K�0�L���h��E��,�UL��m/��Q��F�k���?K��Ғ�d�LJ6����qB�^�V�qc�S��v0��,݈ZQ��2e��_�/�2�z�\���[��$u�S�۷�m}���v\�CbI�B��0�X�!�*�|�ʠ�����Bym7Ld��/)3�Ķ�Q�0Z��#m@��,6l�N��$����E�v�3���YQ�Q��߼g$o��F�$�
�s���w�0���Q�{���g'g���'d\�PY8�@'eǻT��E��~�H���������qL��U��@f�n�0��LR_�(���l�ԗ���	�#Vt([M�(!+�\pc�~Y�_~Z�HXz`����fY�{@���s�嬽5��n���F�ȁٻSX�h���ph���0uG]�����ZͰ���.�5m�4"E�&?��}��>�v3�2k=�,�*���q�iZ��Y��A�����E����݉��$�&��`���p�����e�`z��1��}aH�tz��5���J0��>��V�_���%�k����Jɰ>S��F."����p��?_��LAu6�>(�PGS[?3�c<�^�#����N�`�����p�dR���m���f�q�譀R'{���U���]��)/t�l��(�J�3ܸm�=�+,.��L���.x����Qz����2,s'�N�\�����r�0����єe�p%��g}&]�e�M��p����*v;�K0%	�V~R5�� T=z������]�@�X�I'���a�p@�L���liS�q�l[{,�d�#����|RB�����"�������6Ñ�2���U�E��{/fm���3�����|N�z���P���E���N�=F0M!V�;��ev �<i�J:�	��:�<���P�����jS�]�J�.��0f�[ ѕ ��\�6G���Q�O� ��;�t���f8 ZeV��1CR
ͳ��ٛ��w��<��V6m��hZ�f8�YVq:�{w]�͓�@Lu=Z���x?,��m�����K��i;��Q�p8�Og��f0N[�?{.Y�Ͻk.�g:�i$��t,״���ɹ��h�>š�YjZ5�u�j��E��$ى�+�̃��G7�$�"�@e���q������G�Z�{W?v��޾�,ٴ������ee~Σ$��$P�H��2�D'AB�y�!ͮ�JjYu����~�8�23}���u��rqƒ���LN��`g��=!TV��	9Y�9�K�"WW��$tC�a�/�7��G���l�5�h�T3𬊬t6jiV�2J�e'�L��$@��iԩ��|6H9�[;ބ��|@�S��0(�UC|����H] [���{�S���d4>�nֻ8#�m~�ګRl�<��9l/b]b5�q��LRL����� ����o˿���D��]�q"���+�&&�L�ûk(��4�^�6�X,)0a8�,���i[g�Y ���b_���#�b���p����,��qJW��u�=E{5���u���/2��u��OY��#ү��[~��Ă3�7ÊQ�@�B�c�1���[	}�~D��1Ssj�    ^�V�� �q�R�v�k؊	��h�4��k�1���E�Evǋ�н�.�>�:�J޶�܂��Q���RJ�����x���"�.�-��>�-�Q�k��T��y}oup�O���B�t�#�A��T/�A�n���@O9:��M3t��WR�>3�o\�ˡC�&<,ނ=F�u*jpa�I��a�ns4�B��ST���y|i����"A3G�Gů�p?\�\�}�o�5�X>�y0/'����!_��ʷ?���Mщ�YP7a��������$�9��_�n�Tc�^�ڲ%1o���%�������ν���46F��2?ʼ^��2'! �a�f���sq[|����k9�֧�K�&�D�qi=�9����В���y|?�]ʡ�=�>o{q�Ǚڀ��1�v��}��p����y��ȴ��g��I(��a�	�W9M��m��$��N�;bܨ-��k�dy���
Lv/>	=	i�m(�'�������G-�H�y���| �Cwh=������x���U��x"���?���:��ʻK��
9�s=]}b��r9�����h�q��Q�7�6$Aԟ�ԁ���2��ƆAռPVB�r`5��Iћф�h�㕕Q�F�<~�v>6$�6@�h�6�W���i�VM@��mK�I����M<��E��6;ςG��"O�I�^�O+*Z���nz��`��6��
�Y��8���t{�0m�4��ͮA��{:���?��;p�:OZ��ڷM:�ZU�y�^^oU$	��n3C�M��H�U^��F�4>,��f�ڀ������P}�Ƙ�v7<k��p�y��2x���"�d���w��F��n�]�4��M����.���N:�bҳn��"^�8�<:���Vvv��������-���()�
�j+��3*~�VYj��(�G�`:�1��ށP�f�Χ�����a����A��@ߠ����i^�X���I�$7�%���
�O�+�0h�����u�L�95v��ȼ��Jg��	���%�R\JD��^�o�R33 ����h�̯�����iŤ��P6��G/���P�Х2��d�� ħb>��X(-�	h��yD�l��u��ĥ�E�+G�̇Yb�Zm*����īQ��ϵ� �|���Y�,����������W0/�ޓ_�D_5<!(�(o���D?v1[K89Ӯ�Gcl��u+�2q�J�o��+�C{��=��.*�o�|d�&%0�獼Y�R����4��	TBD�( '-Yř&=���b�VF��Uɳ4tF�YX_w��)%�K���X
���O�Tg�ȵ�0�|����E)�٦�[=d��w�fn���f��!q�9�/�c���[=�lEi�u�� ��b��:�<�`���YVI��Br*��y���ծo��ap���=#)��%V���mMi�C���5�Dӻ=��y�>,�Y
��J�s�B8s�ڽx`s22О�c�y�[݌~���w��� ͽ|���e�QM�lV��e��F?��#�k��X=]p��|��xE�r�Ղ�u���b,�c籦!�b�����te.6��@����n��V�E:R�f�
+��t`[��S$��^�0������
�;�(��k��k�[8\qƱ;z>����㍣�7]q�~�U�s����Y�,+���{�l6�7�L�<4T��{�8��*����ހ�aX��[ة
���Q\�Z���X�.�ނ�>����p�b6�L�+�r]}f�����>Aҽ��$�>����=<��%f-�v&&7<d�7�R�5�x�L�X������Έ�/n>�"��r�Dt^�_Z[� 9f��:Y A�z�E�W�$,/7��7�<���vjz���5�?���|4��W�;.��˭8O3o[VT�[��gK�@Ț�y(w'����+�sB.�Y��e8|cE��y���B:�A��6b�qI�� �%������mՋi9�h5�������e�"�[��w��w��$�&��԰��_���O:�ף�l��&	�ػ��q��Z<�k2�͍���95��/�&�E*M��$q�x��2QY�i}M������(\���d��E&����9�G�r���Sf_R!9����xR�t3Z��/i�
>Wb��D�-�f6���\�����l�� +@T�TXr���h��ZqVsR�ьk�p��&I����,Ps�o8�j���Ñ6X�ImxG|��/s¥�*̓���Dggi�"	��T��%��ҩ����$��ـxΖ�,���p��!)���e���m����\K`(]��,�F$R�z<u�uT=�{�����眲l��F��r��j���I$U�ǲ4�9��5�$cp'�4�z6L��1�QB��O���������"�0�|mY�{�&��zI��M�d�9'(�I�2����MMA�T~�dJn�h�E9mh�h}8|q�F�Du5��M�NF(�ק�r�Ϝ�{�J"V�Z���"��Oi���R��q�4�b�R��-JZ��f=}�Mn�p=�γ�;*���gj��G�Wq�G���0�җ8��b�a�~4w6�Ɗ&�XnQ�'H�*Ҹ&�����YM�~MF+�p�3͊��!�$���羣y4�а �0�-��0gZ�;�$~f�K}3�$b Bd٪Ǹu��:CR������!�6Rf4ӯ���,x�e4�3�k�Yr��$�AD�)�V)V�(������wGb!����p�/���\ZU��v5˃7Xi;��$�-��-���*{��9�aԔ��Nf�Ra�;y ��J[F�1�,�뽪"x�,nx7�B�C�m�!����P���]�\��Wɲ��Ƨ��V��|>e4�C\�����uz�)�fh�_��5#���Y��#�36D��E�*�ee�Y�:��p@0K��p KU�tU���.囆���#��Mm���EƊ�4a�hf5-�s��-�eY���#��W[A�����^p��V�3����9�9h��I\�2oMɩ/��K�u��c��q8ޗ�U��F��d �

}�k�qKlD�M�u�:MR��YDږ�pH�<�e������,�Ł斖��V�9�з� �7M����y�wT��<C�zΗ�m�j6V�`���f�PG���S�L& �Ј�_�
cJ�M1D��B�+��H�5�;Lqȟܜk��_޽@�؜���PxVCO$�^�į0��)�B��[�Ƥ\����v�'9:���KK��|KL����%��݋My���l�9׭����[�vU����&��쳺ckv!|���Y�6�t���g��-�#���a��]�n�3-���[�b����I��uc��x]���?̯yOz����4�y��/�3<�Zr��;���Q��{���=S�5�h�9���ӂg.�M ��2X��b������󵘅�ais�=
W�,0ϸ�"!͕��*EY�$�:�K��œ��z��Y��h8����[ea�1��l�}���W��c�!k�L�4��d����lL�'eX�FZ����y^$���� .VϖߪN�<�զD��ߦCT���l��A��JB����8�]��i`���r8���A(L])��Q�okx��0�$�"�X��B�2�,d�e4i̫��,�(���M�}�8B�=�И,��'���,xei�G��z�M�>�:$�%a�s��Ȍ#"6>	���	H�m�YB	�^���G�p��i��%�	 �?�I��� �x8�X�NI�Eq������Y��L%�����ܘ���a5��ch���d�ơ�G}��ÈE�塓EI�{rʌԤ�/"�Â*z�m�hX�3����q�����"-�mD)_R�;3h(]ԛ��@<.�`X�I;����x8�W�Q�hY��H�����<P�J-�{
R%O"!�q-]hp`1cS��X�t~e<�+����e�o���K��ʺ>��G�(�JȪO�揶���uEY�۱>�8G'/�͏�1�y
�ݏ qrW^��t����X�I���U���]&���eQi��#����O�TI�Zc(&O�p����8��a    ϻc#^0��i
��m4�Ȭ�G�ha� �!k6i�?�|����=e�.�<����,�(��:r"�����g���q���t�≇C<e�;�@G�����c�P��A�v���IΦӣ��<�������A�2�p����b�$	�e�S^3XeQ�mi�dm��`�y���p�]Y�I��$��[H�B��<,�W��O��H�Q1�4U�������e�Cq�4�FpZ=:�t���U��z�b��dz|�5'�n�Ş��${Ua���ʂ7ͱ��Ϊ���`�T.3"-h�Y<JMe1rh���^[Xf�u�U�����6ey9;�����/r�g��X���VxU���ļ���|�=�n+T'�E�V�G�L��'nQ��b�ʃ���z��}e���|-lP�0�{�( �����9��!e�+��]��ve��m�r�l�wKRB���O�`��xQ�� &;�5�Ṽ:��Ȫ$.RIT�;1��r���J������wI��.� E�g��Y�:�IrG��2q�P7��i������O�Vu��d8>V�Q���[�:��魂ҝ���Fb��E]�D.�k;0?��([V�K0�Oz!��M�����B�z=���3�`���iK�;�U�.�(KL�� q�f����hϪ��{�OK8�;�j�}a�'�5���xo�p@�ʒ�y��>�	],OX|���?H.�F*�E!æ<��fd��Y���IyG���?_��IO}�)�vE��2bOj��M}'}�ƻ솣`Uf~����4����p�v����]]*�yjO�ݝ�%�Ӌ�K��
�:��RL��-\:`��g��'�5�"&E`=�5��Զ�J���0H,Y�Q�"�}?Q:Q�Bl7:��c����AΖ-
�g�>,�'�h�~2��(�V�T����L�֒��kMV{�.HNc연ZY�rb�d}G��ܝ���u�����7kĵ/ty8��k���B��U��
ZՍ8nZ�x�}���,��ڌ4
ޱwBO���Wnn�f�(�ȭ��7�Z%��'ه��<xO�0�U\��ư�"�z�|Y��I���,�XMY�h�Xz�Uf=�J�@9�k��BZ��m�S���V�����H	��� ��YJ�@��*J���_�!.�:�8����ȃ�]�nki_�l�iZ�~40�˪���}|��%ȁ���n�4��Χ���V�%d&�0�����	����`8 �J��lt���Ø&�����pHa�o&�i*���j�)Ib��"�h��@��s�*ĺe� ץ�`�n��?�E�8~o ��T}�䣓'��pY|S�M�:햍C|vobR�HO��O�vR��?]�����fQ�k[5�م(���")���᧿T�"�;*R��w��������1�I.X�����-�F��.��r�O�%���N �|��\�mNV�z� �jK�,{�Ɔn�5�F[�f���� >}G�z>���k�'	�������]O�%<Δ}��i�l:{��1��UF�U�g�	a`ή�%�ͦ�"���P��C�n�+��a�$v� C�w��wT�����a��'WUnM$�Gc��X��D���{|D.���ʝ�4@>ԓR����z5���<&��A�g%^�����kx�k���<d��%`%��h}G���U���N�c���K�0_�y�z'ӡO�Y֔e8A-L#������9H����t'g�zx���-9R��:�X/���r�Mj��I=x���O(*��Q��r��Y��Ɉ49�ٜ��^�<����'�j��ړT	�CJ�U��9ij�����U?��O8٤�����"���U��g���Ut���h��БRZ t^��EDܳv���.^�$	K�tf�����:�ҟ�fi�m�)��z���wT$�b��0Z�ي:�,�^��f8����*���7:���[z4l�OD�n\䒝w�����frG5+OI͊�*]��)"�+E3���ߑ�k^Zy=�%B9U�pW�Њŵ5#�-īNl5���N�4^u�$N��[�9ɕ{m��klM�ff@��)Y<z*�[y?!��_���:X�!�.ai�yt�EvGi��o��*��ۂ�7�����$�c�/@�R��v���;�p�$Y�{]��X&J�!Dl�v��e���6^�,
]l[��L���!�3{F�DX;F�a�+?�I+5Z�XwT*-�"���AF.��辳C�a��}ⴌ��{� M�g5>�I ���H8�hn�?)��x�ūB�m��@��|��O4Ph��u߲�g���O
!D�U�^����gy����7%ׅM}�	N>I5YYw]���t4"�|ҙn5Z��@X�"�mMn&�3�sj�/��[T��8o9���+��	�"yؽ�!�!L:�ţ�����-���Kd<�KG\ק�Ň�����5���q�>,~T�T�n�L�<�I���
3��5�2p� �i� �G�kq�W�����"��F�A8�</I]�\P�\\�i��y��b��ӧ?H�����$�y)�^e<02��S��$j���b�DhD,z�w�o�����7��	��?}�T�<�,"���f0��߅�r<���!����@�G^���jg@p�da	ZХ3wC'^���ֈ+[���ly�W��w�(B�fa���_��bƌy�j�'�L5XU��_˞K�A!V-���H��<�=D_���i%)�!�8_��~]TD��#��5uB��6��v[��"}mS�(z��[
;;2[�o�߸Ɔ���
K��~�?�Q�T�ܰgu�q�K��^��	��z�	#�gn#:��k���M�W�u٬]4�-S9%�Bs�:���r��.l�w��8d_M�.�"��ſ0?5{I��ĩ�@�9�$�J�+�y@�ezG1�k�.�"~;���0�X�����#�P""(6=���a���e%)�'HB�zc"l�S��I^R�쎊���_Lfr!��k�;�6��@9�7��L��0^�a��<��w.�q�����锻�Y͟>�X�S�Q�2��آ�l�r 83U0vVO-96�O8���H��X�G�^�Z�3
C�\Wc��?%��Z`Lt����6���$���3�M$gn ��oN���g +o-y8�C���g>R%F�9�L/Tl�����;lʅ���	+rwf�$����c�1D=�j ~}�흙D�;�B)4��V�F-�.��K{�|�53�	;�Q��1=�á�(�3oP�vh����L,{^ʛS{��J��<�O����ï��s�;��<x��bI��O�ScC��w�yC	�y�q_BN�nS��ɼ�,���i�{�aUeuǣ���m�*��^%q7`�˲\��߯�_h*4�m#^��lv�It��b��b��c/��|t}�%QB�f����K(�;$� ��n(P$M�n�=s$���H���_�c~W 8fh����[<�����|�S��ٞ|�VY�V{<*��;�ث(�j��V̻�𣫭����ͣv� �5xj����vp�6�0���V�<&���C��i�&V��ǵ��ZkxK������m�*�D�a�T�<�'&�+	)���־z��Q9ɏ�$��mR:�s�:�C����?�o�Y�AmI$k%�XѪ�T�`DH���a�68p h�\N���R*����q}�X��g�ka84	�/m�햴&����Z<�N�b��O
!e���8vwwV&f8hE^}q��Ҹc��j�tǂ�����LjKT�/|x��b�y^�0�����jj���=BT�i�Ne��޵J�
�u�t������"g�m�h�r���Xow^f��:i�1�Ÿ�;�M�uqӨ�3�D.�o�Ы1B�t*������n�}U5���<��2�!�{�t�X��W�\,M���jIi���q\��l+�7��^~6C�J����S�l���� ��@Bg��y���� |��ޕ�,Ք�����YQ���!Ki�u��#�S1�s5l�Mk��BU�
kH��    s�������Y~�Sv�o��-��G�~��v~jn�I���J/��C�d��tԞ�;؝ɛ&�cs�d
cg.$t�^� ��G�M��#K�G��=Q�
�9�/�����x_��-m�h8�Ye���b 	]ˑ�{v�����߈)T�08@]�Ң_;_[lϤl��������,���}�UhfO��G�ͣ
�զffB#! 崙B���!���so T��/̋eq�̄m"'i�\��8��� �O����65|h%P�|��V//��es��|}Uy�T"u�0���zs�&D�3fQ[Sg�Z�@@2�Jr�i~����*<�o�4�s�=��=��U�x�u���<�Ӧ���<;0g�_\�=�mKU*~|-�_�Gq ��W��`O�Y���{{��W�F��<΢+����^����f�H�����v��(.���m@��g� a�i'�L rC.��Y�P'�'Ǆ'�~��օ��(�"�N����̤��wNqU�%U|>��R}����)v7T�:A?���ϲQ�Ip��_�8�"�'wz�+�K7�ܱ�������$J
/T���^K��$�L�����݄A�Qm:Ӯ�� �.m�%K$]NEm.�ϩ]����8����\�#H�UC��9�E�^L�$�/�*����k'���y���>7	��)�?O���r�(�j�v��a"�;�t�?��R��Jz٢�!�3\�8��xA�aI�ݱ�&�*�ǣ�������<�J��J:G���Hg1(5o��۸A���N�X�����/R�4�+�0TY@R�e�k�-�jinx��jը7���ۚ~դ��l3Z��#�I��׮ʑ���lNm(�ΠM�ZsN�rYg����is�GV�@Y�i'�U6c�j8���U�w%U�Aӂ���1�w�E`��gٗ]S�C�����Y������)���@��_%K8�0�O�jm-�E�&����@{����q�%U�N>]�hkq��O9���&?��Q�~I��[���S�h�M�p�],yH걏�K�3���oG*g�0}���x&K�ǥ7���L�6w@m��ϔ��������Q3��� �Oߴ����k��̢�)�2x<��[���D+!����<���Oa+_c)j3G��'����l|�W�8��	���Z��^�+d���i���AG;l��UȽ��R���������H��膟e{�ݫ�FnEl�Or\�!Ӊ�E���1�B��#8�=��&����2<��}0�Y���pMcVt�,m�I7��k�bC�>A;�rK"/���1"����l���6�8��3�AI0��o�;R�(*�\���%�,�M%U{�fU�I1���q�Wμ�;"�:��sU��GJ��/��(I���o�@�mLŵQ��+��Tj9���Ś�0N�����n.{Org!�y����K�4.�8r���G*��`�+��9�ܻ�!.�;�$�G��7��a��:N�;y���=1����)NZ�����}U�Fi��*��71W���e����J}]R�;��T �GY����_g�Y��=����U&Ӧ6��ʹq'MfS�Wff��_�wNҵ.�qSX,���k��G���`���`i^V����i %���1�ih����M0? 	�3g*�Hi����<��"/v2�b=|3��q�7y��1��}�7h�XX|vќN:a�:;=plb�ҟ>_E�7��bӸ�c� f7/G3�RP��^d�T/M���}{=�#%�gsa`�NS8�r����㏝vo;^}��YRV��цaS��u��ܽhȈid��y�F��*N��_�������4�v���^u9�j�茪3�R!��_�!�T�G�D�:��w���u`�Bk�3V^pPj/���^7?�#Tw�Ta���;`��(7O=�1���/���6O�N9ܴر(��+~A+Jii�NkU>�P��i�������ԫ��������s8��eq�a'��������3�c*��*��b�o�GY��@yN���|K�[S$������fy%�w�"��j���qG��F�I�?<�j¢�Gul��0s�z8���Q�v�y��hL$�X�W��zM	�5=�\Q4-F=�ͪ4uT�<J���[u�%�����ű`���6��&韦�?}D�Tm8i�<�Y|���HYҫ��5�w[��*�{N��ٞ'��@~�,r��p�+�����e���xT{t�t�^�>aY�@�JfZ]����4k���Oe�>z�=V=˓�*���;�
�֐*���vO� �oЧ\�[�FL�NsRpo����]X�t���C,$v��~�HC��p�,Ϣ��(Q������Z�~�a�&�%�6-b4ߊ�p4+ϋЏQ|8J�+ B갽�v��Z��MZ9�ٲZ�&I�v�-�#Xy��9��+-�x1�ky����G�����R0�f�H>�JkB���{�p�3���\��*-cW�8�?����² �p���{�Z��p�%�?4Y�+��d�<��0o9�*�2J�G�xi�?�L��<���p�pǞ���q����zVǂƮ-�9êL�����K-�^��i������V�0݅�${�K���Lk�3�t9�,R��ژ~�W��]�[2�1��]q��� g�Զia��m��P),B �@��E�6h`�"G/�<.b�y�Y�]J۵v2Bx��B#[5~N�/t`^������3ң���JN�s�U��E^��-��Kv��?�^����+��zmjx��B�mR-�x.N�� [Q�q��"x�{��
��ݴ�.�(��b�DŽ����:\��0MS_��T�;��R�)�u�n1��'A�'�Zbi�z���}+7��B6�����Q�W�6�� �O�M�RN�����E��)k7X% �V�VA��o�+%gz񃙇�9�+�$L]�0x�+�''9\�}o�qQ?�Z��ժf����4��kA��T�^�>���ש�&�6XK0|i���zO:!���_�ʬ*J7$���uZ}��'$G�[D[�
ϒ1s�S�I��і��XYY�e��$��lV��"߲k��$AQ"`���"��t~�"������z[���2�r�9HR��u��*4>�nYVjxSw �X`\�PX�i-5G��X��ʪ*�wd�0��N�U�͟xnn|�֞�me�Ȱt�m3�������B�*�bp�Z�X�El��^0 �����z��$IZ���_G��b���h���?�ʵ�7'z{�<➔c���ةHf���jf�*�����tB�>���2�Ϻw��U=^���ӂu>;��]�>Wy��;K!�t�T�em��?AՐ(��,�$+�\w�^��;��j8fYE�9�	�hx��9���mkF.�{hlT�_M��z���%ìb6��p���M��ؤ>]���b{//�w�� a��X�I���4����e����ē2P=�y�xj�ZH�,�<TGM ��, \\:7["tf�&���G�c��#�U����[|������B������}��1]�zAߎ�n�Ē�d�j�dq���f%q%�K͸�3@������w/}�@�Sų��#&V�-,	tb��L����`�6��zƅS��
�Td��~�\�b�i�B_A��aƺ���s�o~�<F���Y��{�!��d�������]G�+�ݕ����G��n��6�����˵�h/��B�j�����
��J�U�Z�m��9���/��1_�?,�^ �
1ywB�=�~m���-����$�����S{�/��Ծ˭��s�]��!�~�d�"gF 9i�j��,����#��zX����6�\,�аJ���b�sw�u�m傶� 羙��$ �4W��s]�}c0tʔV����K�>P�!�Yf��)O�/��[����O�Q��(�� `Oβ�f��N*�aݿl�;�V�o]�^���)=d:)�3���j�����$�n�4ފ��G�ST���
��upY6���@����֏�\sk�d>&�/��<V���-���-M�v�.s�dN    4�6,������=�_;!��c$���j�����!m_�����y�4����	��N���e��������b�)��b'վ�{�ˮ{&y�z77���&�惚�oTZ�gRx�K���Ɠ��{s�_д���VK �@I�y��V����,u�h����Yv��P�,?�1��2��t�eY$@����3I����@2������3K:m��x��zxI�,q�JyZ�v��8<����KH�D�I��χe�%7g�'��Y�a=e��Hdo�Ӛ���=]5Ë\���`�e�ءX�d+-k�Ʈ��1�*�L�y�SW�ᕩ��r���
`�&Wn����_���w� W	o�/]�H���|��^!�j��Q�\�i9=�:\S���}M� ��륙��1ȕs]��A���z�Υ�G@�:^�8L<w&�x��P�̔X^'5��5X\`פ�,�c[7_��`����O
���kQ��~Q�����f�_xi�J���ᦹ3��f�oy1ߨ���7kz�xA5g�fBX]�Ң��r7mdI �������H2��A�ͺj���rf��B")}�&?,}ڸ64p#Dt
oF9�t��/�N�9����)Y�������tQ��Y��Ռ�fw\����$Z��h=�V%��Z�!K���ΆW��Rg֘g��{�.��0�97��kj������װf�<��|x�ʪ�<ʐ��^���"��
WZNMyQ�vӾ�j�����9�l0�kn��YQ����k/aB0cf���tA���#�I�A��T�����5<�//�N#J�A&�s��R����oW{16tSk�#~g���jɥ�;�вR��b2�eG��ݞn8�����ל�����Ss�/�����ڜ�.
M�"L9�+��	ds����	�i$��h��8���.?��Ǣޣ]�;�i�!0��s��k���-.�?݄�mE���9@��Ŭa>c]�a�D��a�b�E"��lI�W�L���>َ3�o*%����k)�3�h��z8`�q���BV_�Nq���NbUot�B��Loۀ@���w�n�3��,�
��^^xd1@��Ԉ�
S�Z�hڝ�r��(��-��@�pV�P�f���zQ���AЄ��_� d�[���$�1�Q��u�E�lj��`x.y�B�	�p��ӷ������yX
��c�qg��C�3�J2�$H�c�j��\7��������b�c~�i��vX�Y���4�	M�(��E����1Z��ӓKb�a�/(Ɓ���c�y]J�c&mtDy@����4�6b��u8�g=�]�3�Z��a���i-�~�����'��QW�OK����3��<���|*9�蚢P�����Dj�/��w����Fȳ��0�ߥ�b��֯��^�o�|6p�+ߘ~J����`�����ѫA!�yŜ$+�9D���u��k�"�ͬ{��2�����^��e�:�ȷ�"��Nx�4��@u
pv�`F򥘇xj=|M�>I:O^7~������/���֦��*9��aı��ǅ9$�����׻x��cQVy��&��׎F1I��P��Z����O��c)�y����q��C��,���g !�Y) �q-���;YVC�)U���&͑5�<���]@\eI��{y��ɯ�ԡ�Q���O��}ʿ���s�!� �@b�F~8�R�FS5�7I�G�����b&�1m���@F*���`:z/�!rx=��ܒ��T�nw�����h-m=���X�>��v�JƓx��;�G�	�m�U�����3!!�N�����X|;]l��d�kF! fs1e���,�,�}�y��qt$�`�Ùpm!(5�=����L>���_�*/Q�K�vh �8��J]����Ph5��$)<�P��#)q�[/Zo�u�*^<T���T� ��� v���楐-,���8�%p�s�I-y�����T�Y��@�$�8���}y�u졝:K�D��A�Y�@���o�X�%c��b���S�a�;����`���F�L��￀yg���V�jN�W�J��ɥC0����sq΀��X4�hjo8�,jbCA�DN3�JyT�W�˲�g��m	�[�N�	:�bf��.���p�9If����,Q�i5����<R7��{�$+�v����2=q�m4
E��~��#�9³@Z��I|��Z�Մ����G(�q}�:�rt牫)�̀vw�ϼ� ڿZӮ-���7���#"�x!p��m�/yaɗY6x�j��y�$�%/��W] �΋-w�V���� �{r�\
�[bu4Iѩ�Xj}
qW��I��$� o��V˩ۙ���F�o6]4wm��T.�]���5�����e��/��Y�p~�d/ĆN��wp�}��A�
Y�k�t�u�v�=�E6|u���v�h�At���u�_=�q���M�}�'w���<����%�Z3^�F{�
�{Zi��N�{��wf`�"e��#�\,ش{��&��xR�g�y���%�mOWs�n��i��Z�CY�lF��p�;5�`��,��X3�),L��\Ǘl���7�]b#b��$՝E�'}�F�V4�A�N���*IwZ��^��Z�?�����YW2=	�Xt��6H"z_1Ӓf8���I�;��@P�-�n�5%�C�UvQk#Rw�!�5.
~������ժbw�a ʾ�	S�}��D�l�-����T�7�7r3ZM�����e|@�f�k����F����l�=�=�o�x_��
�Ĥ��܄w���b��4fI9ט5^����#�O�LN�U��g3X�V+�Gg����iV�&-ic��\]�� =��<5�ݖJ���_j>���vU��v�n5��+Fe���Vwn�;���O��L�$_M�D�%�P\�m��:�%�b�?�m�Ί��%��2�#Z���~��� I��'h����Զ�wg�Me�(GANU*.���5�"hҋ�p�Sh���;�^���ͧ�~'�AA`<�
�Y�gj���FY��i��G^6��k��>I�aSgx#b�������
��8���x��~��J�Ac�'��Yz�H�o��a{V^\3��ǒ{��\pES@nHl(������<�)��b&E��<xKhi����}X|�^~��t��K&cͲ�<��53���n����!2]�����$	$،}�T�H%ˋ�fb�� @ض�̼3�yf�[�,�o?t`_=MpG���bs��T��A�cHY"(-�yh���r�L�Ѩr��&��(͸�bÓ�w%JMK5���<f�MyG1��;U�]��TX<mP���m���Ƽ���X�j�f8h�i䓄�(q�k,@��pL��gu}�8�/
s��Rh�ܸ�ו��V�l5�)ۖ#=P1�|}��7N"����>�Uk�6}�n��4���ɚB[�Ց�iզ87�`�,��0�Tn�l������w������b�t9�M�k:��Fƞ�x:�|�;�=7-���9ޘv`a�����)�p�wd�M_��e���~�ŴR�z�>��f8R��a�#1�8�N����'���M��;B.Th?,�>����n���PV��Ƌ8��!�Y�_�$x���<�-�YѤUR$��#�,�)Uo��3 /����,a��$�u�]=�Q�&݌��3o���˪�6�$�\�x��J��x��,Aq0�S�L�̤>w��UR���ʂ_�nV��� J����zm�A�boRM������)���˱+h5��m�^�t�?��������R��,�1�u���I���;�Y����P�7o���Y%��V�'�	-�����s.2���t�ucڃ�k��e<�E�%�29�<��|����z�}TlaC��H$s ��ړ�ֽU'H&J����u8x��ʵ�����^�{\H�E���ZZ'|�07K�4%`܃#���~v˝�P������"�i-X妗۪��l����<H�}� >�/~'-s[̽P�b6�Q��N�V<�M]��Ol{ȯ*��*5�$,��5��& ���:Z��A�kO.�Bɂr�+���W�H����`e�����    �-�p==��(�4H��i�pd��ph:�Ӣ����hf�T���s��S��o�^�2�ʹR�G�_0w��������.h/�|s:~!s[�_f�-�����V��٣9>�arGi�ȹ��_�bې�vV�9&U!��j�>i�#�����-'�{r~�3��p�:K�_�t5���.���5���W!��<���X���Y2�� ��,��u��Q��H�Әʢ�]㍛�_��3�<x�^f���v�� ��_LLE���}f>�Yv�0���Ee��i�a�.+��c�7��h^Q�����RG@���p��D걼.�D���c�&�:S @3m�E���Z߈�ЎUI��4���mK�w=�m�MLﰮh7��:v���ZnNt��>j�v)�I��ԏ�����q��u�֕�D[�բ���X�QQˆ���ߞ�4�^؜v��nk�k]�,���Ǯ=������ �����B;迏� ��s>��,���p�� K���Ba|c�#<]i/�� ����=�Ʊ�>`l�!��VÙμ�~�xXO�7`m�IO�p�ږw�6M���6�a���
2 �������{���{y�rʾ�71�2�W��/��gϩ�՝v˚�V���a�[�:�ɦ�����^����]����\��h	-�4�Q���v=��"EdW�6�T1A�\�4��� BGo��p�z.`���|�j}/���%\�1���Pھ-�r6��C�.�f��z���-�Lz6SE˗��R2�g��:3�!_BJ�	0cX��&ӾXb�d; ����� _����39F8��$��8o�:5��c<~r�ddf<��q�2��q2��X;��7O"0X�b��:\�Q�,���T�V|ɑJ�2a;S���i'u�G�P��S�:ۇ"2�:���v�h~��|cN�~��<��u��#��e9�w��'��v��c��5�R�	��B��ȱ�|_�E��T����\lZ�Pt+gp�"n�K�7�d��_�O�m}��G�H�i��OEO�r�~`�$j�Tz��g70@E��N�I�,�2�Ub�/ͦ�����g��'5���j����'�27 ~R�� -��Gk ������D�M���H��+�*j��j&�u8|[��Q��S�(
�=Րyz��uQd
�IŎb��'�a�p�|�+1�3���Xy���(>�;1c��֩!�X���	p9{c']"mvt�b�n*>�:�cT�q�n�(	���s(2kt�13���o�Э��xK���D,=��#���[cM�hx,禸69/������d��&�c}Q$�C��4Pc��2�G�����<t��K]8���F����,ݴ#�h���}EQ$�%��������^noh��{˅���k�h����d�7.����ǃ��p��S>+��c�ݱ�(�2u]�o.7������I��rj�'^�PY�9�&y�u;�zMjA���Dޱ�(�إQ|ӧF1!�!�N�tTۢ�T�:Vx��d4�'�c�P�E����*�%��ISA�Y^�$�-y�QU���Y��p�m<��"R	�����v.�L��xPE����������zmC�4�渁z�&� d��v�O�$��"��)bS����?�H悺-���`�ln�M�+=��EʙD�q���qM�:��{oi��ԺqppG��0�`ϩ牞5jh���E�� x:n:=�Gުut�
���̭����؛�����u�Ps?��/�Hv>v�C��5�����'i�1ae$k O�?;��h��2��)yNj�����3����\�vC�=����1q����GY�#�>������0R�&��ctX>���uy
�Y�/�iT�����:k�d�rx��y�R�4�+�nr��S��B��ƫ}�}m�'DTD-����m��|��!���;pU���*3�����<gG��
Sͤ����ðrI�E_�����N�|Ƭ���ܳ	�o��J/�;���ke���h��s��O9Z=�;�E�»���=�,�Q)����7���O��K�PO13��B�#�b�
�]����8a~t�H��ꎚVI��4��ѵ�)�?O
Rz�{VqWu4|E�Gfta���A����:�*]7�����w� �"�`�����{�w�#��d���\��3��0(�Vhg��n(Է�U��hrLS�a�K�xR��h��u4|m��a�I8Ɗ�8��$�E��#��I/���t�i�x��s}G����o`������_pd}R!a�����/��V'�S�aI�I�����7�5�x�WsG���H]���Թ;�iХ�㿰�ƾXM�MY�b^�u4�Γ(s�fE\��R��Wڴ`�T��/qP�+o��;��)�S�+	��ݱ�Ӓ�G�����bfQ�.�$޺����e'�װq#0j���JK����@�O�c9)-c{qђz*���<LqtGi���I|�a ]�<�1���2�8T��?�y,-��r�FU��8��� =�v/XO�J:r�UX�cs+�6�9��!��%9yC.���f���Q��M5�G4c�:N�(r�8?�"I�7��+cB��; ���`)v��8Y�I���h�t��Q���(h	���kȫ��uA�f`8�{�ܾb�R!dJ=��1Z��>�,�*�av@��5<�V��@,Q.g�neD�;{W�p3a����ˋ�.7}�R�e�K���M�)��xVܲ��Tl�;���&����ra��s�[J�����~а���N3��M�A=,�iQK�m�W�^ Q2�tYom���v�9"�Ls���j�ГY�%��𫞙�hᙩ)�ƧY��aa^��ˁn�¡T;M5��(*�����&�xc8wo�V������Z7	`6O����h0R|ԙ�e���"��� �!�2a[r]���f|������h�I|�i����e�2:Έ'#�� 6�7&�|q.����w_�W�]T���ju���WS�g�:;/	��E=���{��ER�{�4ۭ���#l�D"�<ctO܁��`��<���C���u~�T����tƻi��@�(w�E:F\ol�OO�/>�xh��V�l���8����V�@F�;��"�U�o�8�HU;[u>��c�VM�IL�'=GA�;@Т�+��H��CHq�Z��Q�>�{��#v�,P4�����LR�HK��3���Ґi����G�C0F̻���n����$���?�)k8i.�o� h��.q�HSs���܃�Z���a'~/�Q�W?�I�����hV���z�8���]|����T�o������QgǙߡ%�a��Q���2ݜSa׊�hv	��2�Q�����<�y��eU�k��"�%�ՔӭRG�zL��g������d�a�_�2�`��4	��=KR��c�؊��)褕m1�$wT*���EZԘ�ZT�KTS�_�@�ב���OI���0ף��[�4K�L�6��MUH��Tn\�>,>���t�YZ�L�_��y*�Q�P_I�-ӳ�,0����S�A�t7������;�kzj6{�<��?�p�������F�he�͸��)���Y E�x��yC��Փ)���B��HL<Nz��<K��Y�!��nX� w*O�����E�e�y&mjG`$�a�"����� 6dxP�Gc���֝d�
�)�q����N�4V���dC�B�[�tָu��Q�,)ݩ�E�G=�\�=)8_/4�՟�C<��Ǭ��wԩ2���S��KH��.o|w3G���X�)��U�T�IΨ��+�q*\�t`���oq����E��5f��x�ɀ���I�?�A�y�|�5�Ƒ�m���זvMm�L�&nY���+fN�-�AwM�����b���2����|��WŃU)��PX`@r޷%nO���BT�_���g��d�Һ�E^�f�����8�z�d"� �h���e�)0W�Eb���Z��ٴ���Џ���4��b*�4�����йvm�����\��isD�k����E�ޢ-3�hgs~��j��E�R����zI�F�&/���0� ��:h!AF��U�����*�y����aU��!�|OW    �'��5V4�F���C��X�v��B�������t�Ѩ����Ќrݦ���s@���M /��Z�H8ZG�����Y��ĳIr��ؾ�^�YpmW/k"��U���&F����*���;��%^R���w�����,��ꚓ��6Bs�{`yG=��E�Y�h��}����A�E�1W$)9_q�я���ˢ�� 	'���"Mz��Y�.o�U�6vL����n:���yPL�X�I{��@��eʓ�i޳*x��n�� `g��$a���W%ʤ ������ږ�rk^ή�6լ紩-����zV�1������i0� 怵�T��JX2�Dt񕗖�T�-�n_M��%=���j0r�W���<r�p��\y�GF�(�����Ck:�`����j\�4��.�	3aD\��B�D�~p�>�c���ixGˤt$��C;���rUC3��`�V�^����ϟ�hI��X��7�G�����2��KG�ފ���\�c��[ӊ[��I��X�Q��+����ر�Tk�τ��ށ��y�b9�9ӄKSm�)�c��`��3�f�V��S�Dg�X2�=޳x�? ��Y�cUu�����,4�<k�����1�O���u/�����Ç.�v.�2�7K��C�n�)���,穦{4��I��_뛙?�G�;��,ݤ%�S�w��EQz��ERa�t��q��8k��Vn�y|�l*���5���N��5K>-�q4Vwz]F��c�e���Q����>M_E' ��_{�y'4��=�����G`���:�i�^sg����e8^!�c�e��~R��[X�l[�J��2A}k���G�v7�5���5�6�b4�I:&-�0�J�	��aC���G�Ĵ��B�Ύ&�x�6���h��	��V
��g�;t4�%ځm�m%��tǚ})I����m��{}%5û���ܕ�^�<��t8�W���w5H�����b���q����R$,�.�z��ܚ�0+@������%�<{Sq�v՘�<�c��(`�Ǳ��(��7F>�"`c�a��C�h�vs&�+������`���#~�m�h��f�w�50c'}-GSj���,J��޹{Y���#k��Vd촦�9�����#P�����������"���:�p����ؓ��" K�ܬ�������U��ώ$�4dJ�Z�q�4m��h#U�Q����T��oJA��ss���A�bb��=Jқ�����J�,�y�eYtG᪤�/���k�j!6����'�#u�,�Iܠ�zG�<1��A[�.)��Z4d�i9��l84W��7�(�`2'�꩕�<?�ڼ��u��>�4�����M}9�����U,���Lr� �f5�b��Q��KRJ��n��ԫ�R<qt�"��՟���MˆpU{У��o=+�e�����^�6_����?��sl��e$�mL���$>�@��Q���^Oe�X�f���k�Ť��Y�'�����AB���Z��v>K����j��i�H�,!4I�k+h���J�BWN�Yɇ��	
��Fid�K�ME� }礢^��J	r���d�BD�I���~��2ol��7�Yr��xiZ3�pCe+�BV��5'�gr�+�l|���E-�mT�|	,B�v����=;�V���i��;�C�U���L�/ͪ�M����2*�VV`@^�v�#S�y�I�<�M�YqG��<vM��tjV��`�#i�=�@z���YSw� %Y�¢t��QN:Í�N����m��$I���+�4����k�l[-��vec��P 1.�0_��#3�=O̈1���D������'��.�.�欱�Fe���)�<�
H������%��c�����ی�+�#���6Y6�3Z]%o����>�w4_�g�S�cG��4��=�S9J`�o�cٕ�����,�cK[�'T���F�����ε5��.�g�¢8t[w�2���Py%��X1����ջ��|F��p����e4�����cF�5z/� !�8,��Y��J���	��{|�6g�'�&/�kC��p1�1���d����f��j�(�k�\�ҵ��P�:��L^���91��C�F�=��h���/���a�3�����C����M�N"Ƕqs[D�e��jHO���p���L��<���E���E7gۗ�jW�Y�@6Y�]����<@�Ts�k腽�܍�ݷ�7��N�ٺ�r|Bm�IІfO����ʍ)�����qs�G���ո5�u� ���gS�E�k��m�(��R��N�}ww�o2f
Z#X�>,��{f�`r�l3�e�?�� �' �e]�2��9���'c[ z�IgX��}�Z=����� �3���3Q�K��[����5U�;��l 0�{�ۙ�!���ě�4��H�C��e�Cg���'`�UZ�M�&W�+��$�QL;;<ᡣ(�8Á��Y�/! ��<	��L��$���E�����*{���I>�+A���&oV��l
��)���V�*�-M71�XT��'l����X��޴dۍu���v&��Uw�����`�Dw�74焓���&f����̵���`�i��K��x��Me�zxn؈Qw�<�fٝ�"�B�W���ZJOV��Dv��u�J7$2�3|��l�Ey��~)$����&+f� -�4� �xM���q��ƒ�$p�Ti��Iط�`�6�arS�D1L�@3�����*�8�zg�Q�����<�� D�q���~2��9|�;�!]�&yd��4��d���6��A�b���bW'6�D�9`�M^�DJ%�/YZUiJ�%8�C�ؽ�׍L�nR	p)q=��#�n�PQ�&�U��Y��lU�W-�dA�S�s�I}�ͳ�D�G�c�tƎ)�� !�G!��Lw1Ń1��k�����T�o���w1��E����+�wv�"��'�����go��%��eU��I+�o�:ڕ� �$n���mu�E�^�I��#��Q��c�Y���v��Um2�j���T�jTN��.M��\��cL�
NX<�i2��y�˜�!`���"j����܁|�*�����*�ë��E��:�J�6Åa�l\��&��JF^!k�Uډ�������#3�5{�m�Rq�pc��=;I������]��c/ ĭӆ �x�H�^�J%��x&8�x
ŏ�7��ڐ�Cϒw�u
0u/�c����j�aaf1b
7V��kfռ�����q?��L��+�Ɖ`a��oߕ�,�_���I���� ���9��7�?�A�%��tT�>�GOg6�霌+���t6n鰨X��)��#�ʴ=��������Y�Y�*[>�l�;:= ]O�	6?�݃�i׬h踅p�#]�a�f��Lse�<�Sr����.�7zD�����+��j2fu�W�&Wu���uI�x�'�$r�\7c��Ar�?�����v��p)��Zr��h���ݰ�H���خ� @�	�rMx��3
,�e�r3z/�����y���|z���1L�k�J5������;ێ�֛�O�y�}���%k��'1���m{�b�R-�v;H��Z��f������<��L�Ne�����S���?���3�_�;rб��|�҅���m��0��漎�C�$M>�0@�He��{7����IЎ;�9Y�ri2��b��
V$��1ATa��,�eצ����?�rR�y(o�|��]_�ˈԈ��}ezC�R�l{u9-��L�[8�?ډ��j��c|�w{� �������}�C��3Z�uw�jj�dךQi���~�S&���T��?q1���Y��`�� =���A�|���2�	���=.�r���7����d�`�,��b�CD����4�n�1�W������'��[����?�U�{���-������D�uI�"� �x����i�������K:R�qq=ځv�D�=1k{Q�#;����m]e|��
��t͝�
T$x-�[w��9������,g���ԉ����47~����#2���    `���&ȑ}�naFKc��
��{��2�4���4��hM���v{e>��%-F�]{� ��[�/w�Qa��O���}�]���%�U�Ih�H�cl�����n�/E_<p���_�69__�~�ܿ+"�;)�{�$s������h�fJw'~w4���¯ۂ�6�V���!m:�h����P�*�*�WXD����9��a�Ñ|M��v��Yh\�k���A�kDFd,ey%����L��bO�I�������h�����h������ld73n��K0:� &�rY٘����)T��K�4�4qdo���Ԧ���p��ls�RԍA��
]�8��X��I�r\0('`����?�@��t�͟r9�3J0:a~"+ռ��{Uj��%-�<C�[��ę��4���^�*����Y�b�&��*gW�&�6�-����ݳ�H)�Zt.Q��ZM^=gK��zI�����]�%eL�fo�LRi�z'tl1�!~K��z��h��?HK�'��}kV�qw�g�$�[���,l?"�*���g1���"��-�(Pw>��9�p{+�?�BGa�j��輪����7)�ӽ��qї�lPR1�ϲ:�=qe�zt��&�V�H�l���$��&�V	�e�$W�zS%n8^�^�W�
Q9�X������Ɉ�Jd~��[�	rb���L�{��/��Yǋv���*á�,�:�_u򁤬9��ݜ>����ha!�H�j�ҋZ���D��ެj&q@J�Dv��!1����v<�S��&�{�:'1�n6s�3�'�GL�m�A07E��
ٶ,�E���5��a�|\W�v��&��ص��Uк5ւ�����Ⱥ^�*�V��W��E�R���-��V,���)��s��i, ?���'�Ų�������P݆�\y�,�P7�0�ѳ�^�mAv��{%"�Z�\n��W�9f�͝'���-뚾z٣�:�ʋqY�-O>�Z;�2p}���q�xXz�=�_��B����/���k��lef�U���}$/���C����@���4������!]J�@���B�%����S�՝����*Zn~��z�=���o��ݭ7>�������&�Ѕ�8�-�V�B�Dt�+HE�T,eTR�L��\݊<��nF��� �\Ϟ����=���Q��#�әy/�A�IJ�=��`�}��CTj��5%��nt|^} ����b^5�ư���a
���ݞ��hu3bb�r�Hrd���)���c��ŕ$T�^�o�u ��p82o���]gU�e�qb�Dy��:Ʀr8�X���U���<���J�\q&�^\�;��]�.*�H�V��#���Tg�v3�5��7-�נά�K�|� ��=.��u1	%z���h����#��p��cwZ	�༽��'��f/��߈��R� $7����t��ɗ�n���VG#���D>V�����"�N�eU�����n�xZ�Q��8[��ÍE�Vqm��A�c��`�`������r�ѐ���yghRV�*Gr��̜n~Qz����b�dr���Q��x[�q���|��օ�mϕ�f3�E.�Nt�d4�$�4��-��[�.�vQI@�����=�����ދMYɞ�ЁOs���Z�|h߯ȲU�N�W�������n~�}��N��A���+��l=C9�-�r��1��JN� W��F��՛L�����앱����S��=��u�Žf�'��+e�S/������9�f�*_I�1�-�iL��"���o�v��v����n:�$�s�[�' �(W��v��2����l��r8�[Nʼ
�R^"玼C5G>;x�t���y�|j�_J�� ڂf���1��E,��!Z�z˴i�x�V�[H�"p�d��;R5%��w"�*s�r�ˈu�s�~{���_T�x����y�ۨ�u�Ȩ�h�; ��MO���5��Y����Q�Dñ߲h\+J�$L�Y*���O1�~�4^x�\��F���1S���<>�]0�-��F�u1���)����H�hM�����7%'��W9lK6�����icήtAٓzv���i��X����d�`�/Kk����\aP�i7e(���=���ƒ�<�K�J��c2����k��#\�>�h������Yn.���m���sk%�����q�CRj�HW��	4<�������wYu����#��`�>w>����v�|����˅��^�G�����Ô���e]�!O�.&�ȧ�C�������c�A�}9l����m�����h��'�>OU��V�t��"M��n�G�M��\y��ތ>E�
��nGi���)A��x)NӚQ���a�o�n҈V�+�#�դL��ɒ=JHJ�4�X�:Ǭ��U�w���IL����|{*�?�Y�˪��V�j8�\�㪌%͓��=�B!`O3K�),p�H���� mǺ���t����{�;A/kN�/������|�C��M�A�����h�u$*M�KK&	��G�7r]*p/�CbU����ܶv��r��`ޛ���u�௞\�<9���8]E�.�����$������!jc��B�0u?Ԯ�J�y��h�bC�2�C�D�]�e
�?��<a�Y�\�����XC�s��w��ʿdJ��$x��'�qd��?��j�Ҽ��Ŵ���Fo��h����G����$�f�qB��s�K17���)�=RJ��Kcw, ���t��.'^�U��Sw�;�c!���zd��*�B]���0������?�1�ΰ8.�y"�'�+h�Mp�m������{�h�m2n0no�˓Uf`�Fpܢ������_���v_.X06�'WO�g*֝��eb1~���FI����w��S^B�C��ܭ�C��Y�����c��Q2��o?����LT&kR%����U��+(}�;�{?��U
 c�x�*��hњ	�/}@��@�!諆�êl\5���?����y�C�7� zm5�����G�#e���x�����捶��EW����T�	�͋u^u�|>���Z�}��p�G�)��~X��
!�w�'���B�h��Ȉ�Vt:�AG���;o<m��5T����لY ߾k	���B��\]�U��K^���8�=�l��晞D�w���M�nb8�%^�v�`K�ٕ�k^}Ĕ�W�P���/'ɗ���stӊ��%;UJI2�pg��VM`�����Qկ>�~M>�t�&�VRC���]/�c�f�QI���ø����1�ǻ���&�Q�㋋e<�4��������ȰJ}%Hj��k,�.�}�c�{���ִ�K�6!��Gr��ө�7��^G3֒,8=�	�����֠h$=��l����"5�e&!��ov�X�ܼU#����:��: }|�.ˌ?_�3|�Vi�k�2K�:��`�:�;9�=C�'���<��A�=���=���)��a�K՞Pղ�
�2O�p
���{�#*oc��X ���g%_3�׋`/�B,av%��]U���Z	:?L�]���w1��JX^�dt���Y�˲�����N(R�T�,��0���4�,W4����w����++���b�^�T?�Z\�:?�rU/y��"��� ���&ƣ�zD��������a�@�������Z^����q7\����/���M�t`�޻m�m���w܏{b�Y������N��T��X�$_�A˓������XB�@�:����P�-��[i�����,/��=_{\��Ʃ�F�ի�P�t-�v�y?�d=#��U���,��u�kϫ��,�e��g��',�q���$y�,�L��mz �������z=��?�g3��d4^qzo������8��{��
ޯ���i2�[�����g������Fqs��U�]h���;8��,��m��Bܐ���t	�±[���傛1虹�	Q� e�v���F��O@E�q��Ʒʓ?�t��e>	
����[� �.:�g��' �M�S�UP�j��J_
�*�L��]ȪM��O�    ���ɭ ��.�ٽ�9w\\��p'���M`�v_�;�>Z�N7Gm=]��>�V���r�@��R�o��ȫB�b�����#v��-�qB8��pȮEr�� ˙�&V��@�S<v=4�l7D�����e�#g y����r;����$��*p�`�! �"�ٝ�C�>���w��(t`�|{��w99w�(�ʯcR��>7UO�P�ɛ�)B^X}��`ֶO
���V}:l��+p�=��w�$��	d=��O^ǣa��;=+�i���=�����{b�j��#�kj�?r��Xw
���ט�4&g9�dޫ����:��[uq�����rE�Ί�i&��/F ��y���g�VЬ�O"x�q�5x�����̩X�lL�L��@D�Bk�w0��c�n��a$gSe�8\���/q,{#���r��޸+����C��"�H�iMԉ���[����p�Ь&8?o-�Z�ۍ{E�Gs�������Z�U�u����	�\U�v3�F���!�pOM�Z_p0�������:�V�� s=I�h�^��?�܁�u����q(��b~����M���*]�~>����P�r��v��$2^���)��9��-X�:��~!T��#i��v�ٸ��Ό����Nd�CSBe��!V�ɘ�%�}��An��<��=�pe�e�py��q;jI����(�V�����AH}l.+9=������q�p�N�7��#����G,�TÆ�����9J�J�~R��g�+؊�q�錄��`��6�<-�Xݗ�g��c�jiS�V�� �g*���}����|�e^�=."�.B%}*��_��ŉ6Ѿϴ�j	����������	t�����AU2RD$Ou�b��h�o`��R'����"��W(ᷤ�9F3�7�aч���I8���w~�Z�?�����d�Y������Nڊ:��JݝP����׵;�3C����,*���.�=|)}P^���?���2_�~8��J=|���:�j�"��Yu����wcF�[3�,c�z�/��~��D��60��1O�ǝg��W��o�'����2y�9�CI���'<�}��ƯI[��q���HKL�e �P�Fϰ��E�ng�X��	e��x�U�ɢ�M6'��{���G�����`�I��1[wA��IT3|YT�i4�:yGSg2�@i>��%��] |���&;�\E�"A�$Ƥ}Ƶ�����;56r�or��I2� ��
.D��ޟ�J�eq/�h.ζ}k���41����q$��b�$��d�!��o�$ͼ"�p��aa,'��G��C������V��{�WX�ÛI򉪦Gt�*��FA��Ye�7�P��β)O�Q�6�Fi�)R�v:���C�<��RF�d�i���q3���zqm1ܰݸ�5(7�n���=��C��]7���\~MWZ�Ͱ�S��g]����� �L�߉�4�<�1�������npܙ�����/�����o(?��a�f�:/
��n�����W�x�^�ݑ�-��o�ݢ����f_p�P��xZ��h<�M��%I���)ϒܙ��۳a��	[�r\��zj2S���5D��dG����7�u�;�vA �����?񪘌v��J_��f�� q.�32"M���y�,�e9g��ve�Kk��-�F9� ���U&�vg�{cW�O��ǐ5��\�'�4�q�M���8G?�b�M;bJ�����{9��ۄ:�6�B�f �1Am���W�l����q�lM���,�v��3:�+��{c��ܱ��K76*{�q]�9߅pZ]U�ޅP'߶�e�"����F������t+��z9�'�ի��z' ��8�X�$���/oZ����޵E5����7�	���ַ��­[_
ݜ ��Y��ux�~��d�1�S�x[���&��er3b��ʓ̴C���up	�0׺*�:o�܆�lۅ���:ïM�O��	
��-��x��㢋�]��	�j��'U�]O�j�G&�؏s�A>�{���O<�*c�gZ�����Fs�="����X��'��MQ�:f�o�*FVJ']�{ggغ݌>t����nV���恚��D���:�C��Ԧ�����ڀw����)�wE2�k�d���5�k�kXH��.�=��o����g�L�P�"�JچI��������ƿ��7��AT�;���xF���|�u����	嫲,>te򖞜�R}���屓��1D�z�B�������dQ����60 BŪ�IY0�b��b�nY���߮�t�VVm$��3���e[�P�rt��$o�O%�I���
�6�?��w3��]����`�>��e�܏���%�+;��n�eQ/�V��&�j���,�PT7hH/��9Œ�h%gN-�T��Z���"�Y��:�����^��M��6�1���=\۞7�V05�s=�?��{D�E�06��_X��:���9�pe^4�p���Kc���3G5��l�G�a���Yg�|�u�#�i�ם�	$�0���-c�{�i�
{f��e��U[{�z�:f���drj�?�f"`vQ$�ߌ�l_���F��L��1�H����~�[�Xm���_��}�h@pws�3�i�o�$wCii`�a��f���#�݆� Цƽ�f�W���`�|N�Q ���W=|�=���ٶ'<�M/�	d�=�������Ed�^Q����H;l�#�M��a��L��v�E�w�����C �Q��(w�@"����,��|'��ZUuk�'�S~`�,�"�6�uIm�H8郎aD���o�YT�e�Eh
��t�L�>��=UF¯q,��������As)2-p�ђ�gAf^���ϯh�?$��'Ɂ�]�ӓs��}���H[O &; �.[�\�B�s�?�$�N>Ɖ<�G:����1�汫5sR��2�N�����cJ���T���֚�,��������q�"U���uXN����&O�@)l&E�gTܺ�ڀ�rN�9R���~�j�ɧ#�vK�s���;�Z�$��*���xy�ù\x�_������.N(DS��fu�03�BB�3w�lɚ�,��F�ǥ��y���L�����*����&���qP�<)?B�mWJ��H���a�&�P��H?���;�91r���9���_�������;��2��<���L0��}�������2��Y���Sg��`
��h�L�5?V�i�"�n��V^ǚ|:�o�l���a��7�N��o��}�F8oV�g�:����	u)��y�L���ނ`�������'��ܦn+y���p����s�v����}��?��'s������}p"�N��n8��>�9�,�S���n&z ��7�2�w��{Ab��]zvLd1�6T��L�u`�)�nulv#�,Z��/����дc[q9�Gʓ�h�೅ո��h��`���J��W�-�)�E���3}������ᢿ���r$�{�/�����߀4����Ś��+nJ����J�EҚ���o<)�[C�0I&�WrK����gg+�	ˑ2�'����v�]��0����5��f�-���		���r�4�'�F�e������%��M�A��==k���n�ݣ�o�N��cL灪	���̔h&�o\��L<�c�/����(%�'�?u�e����\�ਸW|i����!
���c��c�,f^݀��hXD����4�읠Z�m����C�:=a�T�u`L6i��F��=��*z��^�O��� �^n�a��찻g�.ʾ=߾|z�V�����I���C�Rf����5���=����_�������7�[~Pxg|�wӺ�̊���OOX6UYQ�'1O��u���/?o�vK}�Q--�d�9���O���U̮�9a���x�n��Iv�zg[O�N�_��o�{�E�_��
/7!+�e
��P�"�!2X �e�ͯc�2=a�T�{����II��wb�3|�����:$��:��އ���8���o��	K�:ˋ�:W��M0𩶠��Ρ�E3L��_.����Dg�5�/��x��5��l��    ��G�Z^Wpz�j�.��ߑ���n��z�2]���HQ!�?�ה?�`H��H����$i�Yv�)Y����E�~q)�	��2_��ѻn�vu�y�ͅ���*^���l���	��O��a�7�\,p,1�"&
�4�9����A3Z��L�C�:=�wWF�[�	�nZ"��.�hk�4��(�[`���e�
*�>0�A����A��d�U�}��Q��z�}�A	b����N��:A��qdC�cLzu�/�=��h���$ח���F's�܂8SqԼ;6}b�z-р���`��_,~�]!Q��#kPU�M�tABH�H�}�������s~Qʳ폦�p�񤊽v��d�`)�и'j*kL����"�6dw�ǐ	��1��坉V��>��Nzy�$��"iO(���0Lp�8v=Q� QbT�����Cp ��!�wA�<�J�	Y�tk+$����Ct�|��7��Gг{6`�D��:���&���?�Φ�Q~� |m�s��Z��-	��t՚�ǋtǩ-H���B��\�_)���}�;��c�7]��T��4>�Y��a7�8��d��L��>R��\֦�l��l<� �t$�M�'\�t������.�p�b�w3���Z�r��گ�kg�,���lrB��޾4sô7��ð��J�Ó,�Y��N�g����JS�M|����߆b[ߘ��^�n,�E���̲�I�q]Y���S/�i�x}1�
��К�Z��3�5t?qז`�@P�i(q}��~�Fc�!~,eQ���?�O(r�GFWV'����UB�lQ3Eo'֔�뎾�������d��E5��50>dV�P������?�b�?/��^Z"֩��n?�N%x��������yV/Y�N&�2���-)�o�[��I7�X/���c%�n�lx��j��ϧv�U'T�эM>I�m6��{V��ܐ����|iv��яo�����:�f��y��P�"yoid⌺s��CMɔ�4`��d1����х�/����o5gZ����p��v/ՑO�3<�XAyҺ'�s##M�v]�p3���l�o۹���C�)�E}<��v����k��T�h��{FӺ3d���"��~)�}/	a�p���+��m�D왬��E������h�M�杘��o�)��)tU����l�Z�w��������^�*c(���?0'�>�Eķcъ��k��'���Go�W�w揄�>x�5aT�Nw���/q���hޖ6z��!��g������tA_J�[�jw�"B��L���@̎�ʼ��n����5��L���t����n��Ļ��5���|R"�u���_���_�z����tf���m/oVm�R�z��#.dc&��9�h	��L_t!w����̯L���R'��<у�)G-�8 �O"$H�����v�h�iQ҃X��m*�(�au/��<_uO��ʲ���ظyX���V�	n�0)z{ Udġ{��Nl��g����fpO����^�zٽ���I��j2ICQ�q��9��x��q���+�vV���g��$<d~HUg=&R1Iޅ]/^γd�ɸdޣ?�%5����%���EW �󡘟 `5e���"M���F1�q���L�cǧ܄��v�������e%�g��Ñ-7��yhe��N�0�Ə\���,rر���2�Y�6�pͦ��Pfj���t��!3Hv��v&�4#�Ulq��z�E
����(���\�#�h�u3z3�uOP�A��M4�ȋQj��.���łAa��$dk�Ҍ�������M����W��ģ��:�.�hd�F=�L}��i�|�����������?Ih7}�%]`�Mϗ�x�ٜ,����IZ���"O(׉鮀o�9���^q��N��D��.ʍ���H�EZ��l�O-K�]���|8�8ɚ���B��na2��eQ~��yr����Ζrݒ��ˇ���o�-�̒�X ?��PN͇#��"���lt=�o�[`�.5����~5�`!�=kzA�_
|��qt�m�D(�h�h�J�V�Jr#�����{Q%��oi�p+��?C&̪����Ā����3����,�E	�g,f=����	İ�Nn{cVP��[���8L��u���{���9�&y�0�&�©��U�`��?�Z�r��[V��w9���KR>X��:������Փ2<K�8�}��H=ޖ�X݌>�{
�hk+��,�5����\4��9�7�f=�<�I���}.<�5�fG��؂���!-J�fa�哺��J��v:���p�ib<�#�e�U�yב������e�N�{Ć������Wf�7>!�0*��%�"���C`h� �=����mL�d�w���f�������cQ/:��g�χ#�i6#I�'�Ս��17���3��X[Ym��H`����}7E�-Y@���]�8|M�|�e�|�A@&���(�F4�Yj�����)��p���p05-�2$"6e�z��J����wa��.BAi�?�n�H�Yu2pн:z��ILҞ2�#���	�VV�����i@���kZM�,��U�!����Dh��C@���܇p�W�|g[7^M�
I�MYC2rGc�u�O7#f��a�G�Z�KD�X򚒏�������yK&|�c,ouA��p$6m��$��M�w����N6xe��LZq?�	J�޶^��2d L�<���^�,i��|a/jiQ��*���$��Z�B.]nI)�/�쭖��V�V���3�\�.��ei�G�}冎(T0-��L��pn���wz/�����[�dpò_t�8�����#U�sm�+)�MT9�9���n��K8e�X]t�(Φ�솃tYQTy,S�xՌb~ڰ����%��u;Ƙ���ϥ��D���&�-b�R/o<ﲂ�*A��]1�$b��K�d. g�)<֍��)>>B��aIs��գrN�Z��#�Jf��֝�|�Wg�7������}��j�������x�����eя��[��_e��e*�V\'<_�O��/��E�j��/��W��������m�=Ϊˮ���n�ßY�d1�����`��R�����(W�5��[�������H�"�����5��������e7J�T��Y����VE��́:9�yR%����"���O���L➊U����,Yw��;7D��뀼��8k�^�I�n�H���m��(�ވ��CJ������������a�|2N�
���oR����ǟ�>*g$C~o��l��.ۅ��_~6�n8���Ym�:�8�mf�۴+K�'���#�=}-�`������3��:��k�n���S5�5d�zO�k<�~����>�W��g�V���·-�M�b���'_�'>�f�"�������س���c�k`3���#��}y�7Ÿ&Ɔ�L]7��*ӫ�7Hk[+�y�v�K)g���[��y�9o^_�Bn�z��
���O�F�WA���$��_+�l��>�3����&�-0�V>�$v�;[��^�&�x��<��e�|�M;B�gF�w!z˵��t3�/�Q�������pd:/�**��I��m/OԮH!Y%x���O��3n�h�|++:�|d�ÍckBy#�L���^�����S�f§�d��HT8"�J�2G��I�Hp��g=��غ�p�:o\͂��Βv����/�d.�ek�3�,����NP��nnF>�{�h1�G7���T��V�2>䮾�\x6�g1�.�դ�`��3�G��Ǹ5���X2�0濙�f�� ݚ �ߩ ���NOǩ�h���S���b8�]�W�P�"y�����a=�Y�����$����G�a	 ���vKn�l+��S�K���K�ㆹ@�iU[`�����~���!�"��F-;���m7d���Qk��b����1�3~��/� ��9n��\(�}$����>b�j�{�`�7 �B��^�)���ʦR��r�;tf�d�U��ә
��=�p�/��m,����u���-�ﲛC�֢{���A^k2*�r'B�*|0 �  �d�2����R��9?���#����K�"����QW�5O[�E�����y|��mc&���cJ�!��?�� m.�� ���ju�婋矗2�~;����"�"4������E^�뛆�$�����}�$�,������4�7���J������U}���p\������f��	�����lܯ<�����������ph��E�f���\QJ�;����Q��-���5����W��t9���ޤi���ph�O�:��u�i�?��1�e<8���q��a�����A(T@/�l�L��&& ⲅ��4{P�H	;d�~�o'���Üi&�zh��	h�F?����mPC��˔���G3��$�b��F̀�=�V��i=Z�8n$ռ��Q��-�n�}&z�;�Sp�����sC��v���;��D>ѐP$ؙ��j4���u����;�l��4�_�)>ѓ+y����l�V��&g<)�f��Ӧ]L�OzwW&F�*@q,�e���&�[��y��irw�*�|�}�Rc�/l#�ޣ�T�`������F,�"l���:�×��r��h���AMk�"b��g�U�3�^f�,�rQ�k~6���UAYey��4e�F+�䠠6�0��=>!��p{�˱zG����,�v�ͼw'2B-km�-q���?��3�&&˞�ݭ� �����/@31���4�^&�q�1%7���\�\�O�(��]* ��܇�7�i��:F���6U�m�f�K�^w���^N=K��%�^���'��z�A;/�v�F��:8O�Ể���<�U�em���	�-��g�s�$F�f�7�9FS���.�bW���#��x�G�]S'�Z�E�
%
WV
�kٽ1�6�<���țC�m �V]g3���I^��h`�f�Y�&͘`�r]S�`���������|<��Һ��-���8��,������p���+7KtQ˙��я����f1��      K      xڋ���� � �      J      xڋ���� � �      /      xڋ���� � �      .   @	  xڍ�]o�� ���_�wMۙ�a`'o�AEA%or�|˗�������tڶY���5kf<�b�G�)Ca�A���W�n0UgP���K`o�LM��q6�ӌ��M�9�hruV�~O4cG����zt���O��	�g�}�A�r�O,v�'=��F���R>�w4�"�<�ne���->;y� �����ʪ���h��I���B؃�'��D�@������������1�ű��6�|��1M�:�2�9��L�f*aH3W0K8��K���������BĦ `;���+�-���(��]/�p���y��=1*C���DO�� �I��4�Y�~�����7���8�H��	̗�����y��ss���5�Ԫ��^4�,"��ل;O�ya�X��7q_��-~6M��K.YorJ�N�"�.��Xz
F+������<�����u�gu@���AZ~��̚7�_��R�e.u#�7�_��[�7�o��gWm�zZ�7�&Lh�a�L'7X�m�:�*�7"�����^V��'�
�Չ�̺��-���O9D�-O_3\:�i������yFv��vz��N!4�;M��j��*���D��6^���+w�Z�6r}u���>?7�&K��Z�Vf���0��/M��MԛI)�{J�^��Ƨkjg�2�A�E]2ϧ�@-+~}�I�l~�u�����\2����{b���[��~��}w�>T������{s��*O�7oc��~�!��W��I�,'tV"�8>)����7�pJ��A���4���T;�!�ل��W�0x�5�}�z���P�E؛�i�Ty����:UN�H��mX������ZR��?\�k���xT�m��ܙ�HHnj��x�el�C4ݫ�/U�-��^�Qꕝ&�GS]��g,\�N��/�!�=��u��|FւW�\[6ǁB��P�KZ~�*�ezݝ�����&��M�ʹ�>%�"M2-�3M��I.H(����/n���Z.��t~���Q�!�.�些�@�j� KR(i͙�{�z��{|C�^�E�k_?��Wt'���Kv\�#�~�\&���Ȏ�E\��o�i�����r]⢖�V��>8=�4�E���}�3�;2 �>��]$^ٛzIҵ����.�]�<��m��2�r ��DČ9�{d�N3�+�Ӂӎa'�)^7	>�FEeZ�'H�h��ކ�c���qTDNoeA'��4:Yg�hg�V9x�,���4W@�f�V�9�9��3%��E9�UfK=��,P-㠝�y��gQ�a�?��)��C9��k��4���jd��Ya�\s���ƍd�7Ӑ�Oٕ����1���xTq7[�ơ^�A~���g�)��ȳ��v��[�2��.�K��s�xd;�+9��>j���TZ�FG3b����j$,j�5���Q�e�d$�pa��F9r�3��8���6b�Ib;^�=#� ع�f#
e5���,f7p�ٴ�WH�oD`�Q��Z]0�&l׵2n�A�7���0��Q߰���{{��m%����j��4d��Mb���H�AȮ�)}���a���"�9�W��G����+�\�J��J�>%�ѽ.�6{�,f�|cy~O�1e�Sy�G\y���j�]�=u�ГK,Q���\��p������$Z�C�� �SU�Һ6pg��g3������J߱�����V�W:vq7��S좊2�7�;7U��֞�:7�3�p��������q<�'��ƫ�e��x�,���j$��1��X�#8#ζ���W<�=���~n�Z�E�k�Ӆ	�pg��h���CiX�?���a�ϰON{#�g�d�u=	i'�C�-^�@�"�R�=BEp��n ��կ����g�(��t�"/�f̰�=?A@��P���z���\��-����4��die`��y��u|T�
���|qG6��%�M��:�*/�[�,�S�I�Uթ�h���Uz��3�f�<���>���8%���u�CM�t\�<yT+K֎Cr���yܞ ��6�ܳ�/�0�����^��Y�j}-��:`�A��w�j37���e��������z�x��&6�2ӯ5�-vy�Q����Nh���yݰCq�vv�&��� ����+��j��=�_��`'���a�QDV���z���&����FDV"Ie)6J2�f�.�]:q��>5��{&�6}d�/����)B�ΓM5ӓ3����ǧڟ�V*�eQ�����yul�^0���T	���n�ॴ�y|�d�ͤ>2�;&���dD �9��+�:���t=h�0\2�՗�k�x�*r�h�����ah�췣e�Q6ߨ"���L�m&��I�1�_�t'����W�����_ZY�*      G   �  xڕ�;n�0�z}E����D	H�ܿ��[.��f+�F$����Y⨧���&m�VԮ��ʏ���������
��x>�Xu �xR�Q;�JԐH5@UVUD��T��$���=���V6R�P�kAz�l��RmP;�vDl^�Ws�j�:�[`�-�l&���N�Lu�S��W^)��_ ���T���SUa���H56@M�TrZٳ�fsg�e3._�9j%z��@z��/Ԋ�ڔT�G�ɪP�]pD@ªP���@2`l� ����+��ҽ��}�k"*�^7+�z2�ꁼ��.D�*PC'�P UYU5�jB�L�W�Q�U��%�j	�Z���7ن�nC�m����P�H���uRP�H�6y�5���!v�����Ium��ԙG ��]�_�>ގ��8p      H   _  xڥ�ю�����������\&�Qi6�ʬ�7�1`��TS-��N���՛F��[������L}e���YԮ+�23��3!\�Yi۬+z�e�����5�����z���S�K����[2��� �]����y��&w�%Ø�>.��R���:��[~)�CpE������e�m(��m#\)I�R �"�6FV���M�Ƹ-k�A�]�m��bmC)=o�i�(�	����H�X��mC\��V5�6F�����!�V�m] T`#�������q˂�]J��lcdiK)i����%Rʐ*��c�$��WI�[9�v�!�>�6D6y�m,Eж1.��������c�6�¯m�[�k�F��:dmCd���~mcܚ�mB��1riKii��am75�6F�����!n���-�W�!�6F�����߆�� mw9B��1riKQ�m��س�t�.��#Ǟ�`)���e{��^ғ@�>�'�R���W�z��KrU
#�^��R��RW�y��j�&�;��m�dgLiXۇ\�W}YUr}C�P�*I�#�$�BUI�kY�5BmBlC�6�6����*H�J"T`#�H�XJIۆ�ڑ�u�P� ���#mc)���qi�D�AY���6�6��ж!n%Iە@�E�m��"mc)��}ĭ�6�!�J�o0��*E�#�J)�U)�[K�v�|�u`#�H�X��mc܆�mjb"w�����F�V���B�e�m�\E��Rm���mP�<�6D����ۆ�l�l�jЄTI�[%��JBܶ m��� �YG��RJ�6��؞�Cjoғ`�؞K�{���$R{���#��$X
ߓ@\��������!r̽"Eж1�!m�B�lcdiKih�W�侭r�P�m��o�)��rֶE�m�m���چRo�
��V� Ԁ~$G��`
�oc\I��JJ��o���~L��m�۱�[��BlC�>�6��K��ۆ�-i�hj`#�H�XJOۆ���� j�m�kK�mCܒ�]B��9�6��ۆ�y}[U
�\�ɑ׷���6�u����!���cmC)��q+Ҷ)�	����H�X��mC�Z����� ������(�6�e�ܑ��*�.0H�=s�R�3w���V��Nr$�VI,���G\�M^7�����M�#l)�m�۳�@m��Y�چR$o�֤�� T`#7������q;G��:��؆�.��������u��Ľ�����nrĽ"��wCp[�v�P����چRz���)W�������O_$�O_$R��/��U���Ӝ>�_����>.QVR�*U^�Rrf��dO.y^~mcTU�T��
��-}>/ʞ޲u�7q�)J&N헔��ח�yN���4'�:�֙�Sj*X ��I�1L�<����}Q�վ�~��vN.�5{�&��ˊ�ܯK�طԯL7���վe�c�	��P�����r�������Տ��h+�*�����O�m����`��jc�E���~�c:;۞ӗq��֎�}�ݧ�h-+E�O��� ]z{����e�=&��@kM~����qvSj���u�${L6G���Jn[�߹�Nv~��p�����)������ϓ��]�y}٬�R�����g.���ttv��%�g�q�	U����������ҥkAo�q����UA.���~u7������eN��,{�6���}ɤ��+��_�)}rO����e�=&�C�*��b��ʲ����fK�ʺ���_;����F7�G��o	���[�FSM\�xz�]���l�.ާ�}���T�������y�k�&�6�)i�i�L�e�YPF��:f���|����7�2��;�,&�MSe���_�_]:���kr��ln6�:7����5����� �=^7�f](A���<����f�m��휜�I��l�ֺ���������m��us��UYp���d�6����>��b�JS��ޯ�Y�e��nLN��y�?��\���zt���cz{���O�Y���Mpaȭ�9���nN�.G���if��>��2�Ty��5��uN';���u���V���;>����kW��|<L���":��'��0���0v��:��m��+���G��)}=_����-��ӆ�e���gG�ok����2�~�n���`K��?|���?,�C�      M   �  xڭ��n�8�u��$�(^�,��o���SDgӐ���P?��˦;�����[���6a�oǸ7T�K~@x���Wo�F��������C���!@��M�|�3����~>�H�UȾ�Ub���Ž�U��y��ϸ����L���F�����G�;���b���%�V&�<b���	�+zěC��#ָ���2�U����q����x�w�xz�W\�<dY��,��w�n&m��̵��yv����1���#�� p�y��k9=b�bGBl�q�e��!��pH_���A.�س�L���/��U�	q|�{y[Ğ�7�س��-.dZrŜeb��;Ƚ����=;H��g� .6[�[�o�#��y�i��s�^u���i���� *�ebN��۲V�Ү��?����/�&���>�&�w\�x/[BL��A|�L<b�g�8��{y[Ӧ��L}�=!(_e�#!&����>��}Z������$4e`�I�zR���X��"*����S� ����V�VxN�;$�̰��lq�GBl�me��%N�ci֧�P�Vx��{"�5	i�{�8���[T����X;D�[�8��Eq���Q&N�cm�e�D>�;JhP�KB.q"+�k|���X?^�Dk��ĉ|l(4�oǮ��c{<c���˩I�L�y��_	�]���-!��A�k��=6�-�����{�Ǿ�2�H�����Z&Ƅ�,*��Ĕ��(�,sl���}�Y&��c�/5.;��zM�^zn�Υ>q<#�G^�vWXUw�1bf��ط���t��;�o�[Y��K�'��JQ�Y&��c�͢�Y&N�c���7�7��E��]M����Ldc�4��fR*\]Mg"���ke��>q"����&U��'��cjc�{���Z&ƄX��#�[�8��6r��ͪz��x:��v*��{�Xb���β�<�Xb��2q<�G�Ů��τ�䥓�,��u���襑��d�UM�g<�<��e�Ү�3����k�2��n�:6]�+!旓��ƳJ|����?Gk����tL
}�?|5��Đ�/ZN�cC�lG��=	�D86��e�x8�vǊ\�4]��'��"Q���%!N��2p<�}��y��� ��bе�'>��3!Fk�2�3�K����X�%�e��%�gc���o�|k��9�u&Ĩk��,;E��WB|�����}�4Z<����c��'�Ch��[ٗ�߉钋!�Vػu��4�b+���H�!�`�������W+�!؁�<bK����!<�#(��h'!������0*��d���]T\�{A������[L��K�O����=b����3�=C`U�}b��IU�"����b��Y�Z���ثf��c\�Q�b���<�����G��j<�G,q1���g���K��g�ˬ�QUc���bi�K���j�KB�la�S�ƌ�2+�W�	=b����e9�.����	�	/�me��_q1�ﶊg��L|8�q� ���{���G<b��y��FՍ��M���X&��y,	��o-b.s�)i�hc7���(�s�g�o��]���<�H�[`��Ճib3G��>~Ŕ��4~�0滃�3�z�[X�܇��X��GB����3����������b��      L   e  xڭ��n#!�s�.Ya���VZ��N�$m2Mڬ�ݗf�!'j$NM���7`�z���S�k�Яl�u�2��������x���t8����V�c����O����V`��Ɛbe�^M+����?rXW`5�"p ���Wص�xZ��k�����!@�#���f �O1�D�u��KmQ!^y3\m���B�}�42���	^�p���D�E�����%�0�S!DS5Ҭ�����*�@���J\T�g��͘GxͰB�h���,�t"|#����uI���
q/��5��ڥ!CTm�� �G�t)��T�N����;N�]���R�j���*Uڏ,�R�U�e��$�A(*m��[�"4��f-B4U[%�/� �R��+�Χ.ՠD@e���9l�2`i)�Q�U��6^�K�.�4U�	X"�
���o�CaٻT�j�DOڧ���t��
�J�L�$]T��m��&5��4��b�W3xP�3�y�F ��#%ś�Cj�D�/*�����,"����!y�U��4�@��85/�A��𶿌�c�^��,rD��1�ף�/�yq�ʾgiۧk��8��Zb�!\��ı2�`%����e���=����)�@�����K�+�8���x�$<�E��D`���㨆K���W!d�k� �X�b0(�������Eć.��AT3�c���@F"�U�L� '�U���e�H�� ~�6	z��BUA(ZVIe]�]���9�`b��V�eW�a���E�8Q������+�k��������yq��ޏ����<���*Ef�}��e�bM��p��A���yw���!�֩>c� ~�xxx��/�      @   �  xڥػr�6�Z~
�����˖ٙ�[�L����@��<} �NBEN:�O��?��Sf\M�+��LA��KmUԬ��Z�F�+|?�й��ѡ�3���}-���}<�Ŕ�T!��1���#�Zc�&`��\m�*��k�':aY���?;�2��.��ƈ�6�����ӏϐ�p�d%X�Y�]V� ��5�w���ލ�B���~t]<0�b8%0�p�f��-�տ��~^������q��_�F�o��c�U�-�)X�,"B+8X��d�`7y�U�نޥ�?��9�kk�f)T��`XR����B�[��z��ɞ��0��6N��1����@%�Q���+e�,�-V�V�c�}�yo��ű��.�;����Bk�*��bk��*W��0� W���=�&�y*�a���^��t�nڠ/�,\o�6E9����p�<��k*`*�\��P�U�=��;���ms;��?uS���k�1��&%*f�na���_��W���~x�ч&�jґ�CMU3ߤ�-_�v6mʟ�W�}��r��h�xJ�p7m���k�[���w�t/5�ծM���_�#O��T�V����w[��z�.�gG���m���SO)�pk�LH>�t�s�㗮�Ν��W��#��q��5�����EEfa6��>J��p�K�46����$�w�ix�
�%���	,w��C��(�<Wi�F�*ӱ��T��l	�B]^i��X����0��P!��+�j,�l�n�����l[��s��L�:���J�&�Y�d����JgKߤ�>'����BY� ��3����G`ѨF��{��4@���%���W��B�eڽ�����D돑�� �f�<3u����)�Qkf��/W��B��At*uV���/�l�0��1~��J��T��en�j���u�q���I5�LPJ�s�n��ni�zQ���Z�&��f���Q^��.}z���;���n�~Ǧ�M��J��2I��U�~��{{�-���$�Ǯ|�^�-	z�,�,NU�0ߟ0��ľ���{N֋(±"����r7Y�O�/����G:.��Ӓ�)�r��?��ߤ[`��N����ȶ����O��2���3WU�;�@�H6C�ø*Dz�P��}����|�N;\�$f�{U�^d��j�1��A׷�����oU����mj�7����EhI�1�'r��2�%��[=�׍�vz.����������Tm%W�ј��j�x������7\ͯ�     