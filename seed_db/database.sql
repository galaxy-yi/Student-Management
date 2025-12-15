--
-- PostgreSQL database dump
--

\restrict JzgW4bm0QYTVaTgxgIseiZhXCzdytFwjVs88RCd0UweCOeQSSWGduxH7yu3weEP

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

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
-- Name: get_dashboard_data(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_dashboard_data(_user_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
    _user_role_id INTEGER;

    _student_count_current_year INTEGER;
    _student_count_previous_year INTEGER;
    _student_value_comparison INTEGER;
    _student_perc_comparison FLOAT;

    _teacher_count_current_year INTEGER;
    _teacher_count_previous_year INTEGER;
    _teacher_value_comparison INTEGER;
    _teacher_perc_comparison FLOAT;

    _parent_count_current_year INTEGER;
    _parent_count_previous_year INTEGER;
    _parent_value_comparison INTEGER;
    _parent_perc_comparison FLOAT;

    _notices_data JSONB;
    _leave_policies_data JSONB;
    _leave_histories_data JSONB;
    _celebrations_data JSONB;
    _one_month_leave_data JSONB;
BEGIN
    -- user check
    IF NOT EXISTS(SELECT 1 FROM users u WHERE u.id = _user_id) THEN
        RAISE EXCEPTION 'User does not exist';
    END IF;

    SELECT role_id FROM users u WHERE u.id = _user_id into _user_role_id;
    IF _user_role_id IS NULL THEN
        RAISE EXCEPTION 'Role does not exist';
    END IF;

    --student
    IF _user_role_id = 1 THEN
        SELECT COUNT(*) INTO _student_count_current_year
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t1.role_id = 3
        AND EXTRACT(YEAR FROM t2.admission_dt) = EXTRACT(YEAR FROM CURRENT_DATE);

        SELECT COUNT(*) INTO _student_count_previous_year
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t1.role_id = 3
        AND EXTRACT(YEAR FROM t2.admission_dt) = EXTRACT(YEAR FROM CURRENT_DATE) - 1;

        _student_value_comparison := _student_count_current_year - _student_count_previous_year;
        IF _student_count_previous_year = 0 THEN
            _student_perc_comparison := 0;
        ELSE
            _student_perc_comparison := (_student_value_comparison::FLOAT / _student_count_previous_year) * 100;
        END IF;

        --teacher
        SELECT COUNT(*) INTO _teacher_count_current_year
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t1.role_id = 2
        AND EXTRACT(YEAR FROM t2.join_dt) = EXTRACT(YEAR FROM CURRENT_DATE);

        SELECT COUNT(*) INTO _teacher_count_previous_year
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t1.role_id = 2
        AND EXTRACT(YEAR FROM t2.join_dt) = EXTRACT(YEAR FROM CURRENT_DATE) - 1;

        _teacher_value_comparison := _teacher_count_current_year - _teacher_count_previous_year;
        IF _teacher_count_previous_year = 0 THEN
            _teacher_perc_comparison := 0;
        ELSE
            _teacher_perc_comparison := (_teacher_value_comparison::FLOAT / _teacher_count_previous_year) * 100;
        END IF;

        --parents
        SELECT COUNT(*) INTO _parent_count_current_year
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t1.role_id = 4
        AND EXTRACT(YEAR FROM t2.join_dt) = EXTRACT(YEAR FROM CURRENT_DATE);

        SELECT COUNT(*) INTO _parent_count_previous_year
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t1.role_id = 4
        AND EXTRACT(YEAR FROM t2.join_dt) = EXTRACT(YEAR FROM CURRENT_DATE) - 1;

        _parent_value_comparison := _parent_count_current_year - _parent_count_previous_year;
        IF _parent_count_previous_year = 0 THEN
            _parent_perc_comparison := 0;
        ELSE
            _parent_perc_comparison := (_parent_value_comparison::FLOAT / _parent_count_previous_year) * 100;
        END IF;
    ELSE
        _student_count_current_year := 0::INTEGER;
        _student_perc_comparison := 0::FLOAT;
        _student_value_comparison := 0::INTEGER;

        _teacher_count_current_year := 0::INTEGER;
        _teacher_perc_comparison := 0::FLOAT;
        _teacher_value_comparison := 0::INTEGER;

        _parent_count_current_year := 0::INTEGER;
        _parent_perc_comparison := 0::FLOAT;
        _parent_value_comparison := 0::INTEGER;
    END IF;

    -- get notices
    SELECT
        COALESCE(JSON_AGG(row_to_json(t)), '[]'::json)
    INTO _notices_data
    FROM (
        SELECT *
        FROM get_notices(_user_id) AS t
        LIMIT 5
    ) AS t;


    --leave polices
    WITH _leave_policies_query AS (
        SELECT
            t2.id,
            t2.name,
            COALESCE(SUM(
                CASE WHEN t3.status = 2 THEN
                    EXTRACT(DAY FROM age(t3.to_dt + INTERVAL '1 day', t3.from_dt))
                ELSE 0
                END
            ), 0) AS "totalDaysUsed"
        FROM user_leave_policy t1
        JOIN leave_policies t2 ON t1.leave_policy_id = t2.id
        LEFT JOIN user_leaves t3 ON t1.leave_policy_id = t3.leave_policy_id
        WHERE t1.user_id = _user_id
        GROUP BY t2.id, t2.name
    )
    SELECT
        COALESCE(JSON_AGG(row_to_json(t)), '[]'::json)
    INTO _leave_policies_data
    FROM _leave_policies_query AS t;


    --leave history
    WITH _leave_history_query AS (
        SELECT
            t1.id,
            t2.name AS policy,
            t1.leave_policy_id AS "policyId",
            t1.from_dt AS "from",
            t1.to_dt AS "to",
            t1.note,
            t3.name AS status,
            t1.submitted_dt AS "submitted",
            t1.updated_dt AS "updated",
            t1.approved_dt AS "approved",
            t4.name AS approver,
            t5.name AS user,
            EXTRACT(DAY FROM age(t1.to_dt + INTERVAL '1 day', t1.from_dt)) AS days
        FROM user_leaves t1
        JOIN leave_policies t2 ON t1.leave_policy_id = t2.id
        JOIN leave_status t3 ON t1.status = t3.id
        LEFT JOIN users t4 ON t1.approver_id = t4.id
        JOIN users t5 ON t1.user_id = t5.id
        WHERE (
            _user_role_id = 1
            And 1=1
        ) OR (
            _user_role_id != 1
            AND t1.user_id = _user_id
        )
        ORDER BY submitted_dt DESC
        LIMIT 5
    )
    SELECT
        COALESCE(JSON_AGG(row_to_json(t)), '[]'::json)
    INTO _leave_histories_data
    FROM _leave_history_query AS t;


    --celebrations
    WITH _celebrations AS (
        SELECT 
            t1.id AS "userId", 
            t1.name AS user, 
            'Happy Birthday!' AS event, 
            t2.dob AS "eventDate"
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE t2.dob IS NOT NULL
        AND (
            t2.dob + (EXTRACT(YEAR FROM age(now(), t2.dob)) + 1) * INTERVAL '1 year'
            BETWEEN now() AND now() + INTERVAL '90 days'
        )

        UNION ALL

        SELECT 
            t1.id AS "userId", 
            t1.name AS user, 
            'Happy ' ||
                CASE
                    WHEN t1.role_id = 3 THEN
                        EXTRACT(YEAR FROM age(now(), t2.admission_dt))
                    ELSE
                        EXTRACT(YEAR FROM age(now(), t2.join_dt))
                END || ' Anniversary!' AS event, 
            CASE
                WHEN t1.role_id = 3 THEN
                    t2.admission_dt
                ELSE
                    t2.join_dt
            END AS "eventDate"
        FROM users t1
        JOIN user_profiles t2 ON t1.id = t2.user_id
        WHERE 
        (
            t1.role_id = 3 
            AND t2.admission_dt IS NOT NULL 
            AND age(now(), t2.admission_dt) >= INTERVAL '1 year'
            AND (
                (t2.admission_dt +
                (EXTRACT(YEAR FROM age(now(), t2.admission_dt)) + 1 ) * INTERVAL '1 year')
                BETWEEN now() AND now() + '90 days'
            )
        )
        OR 
        (
            t1.role_id != 3 
            AND t2.join_dt IS NOT NULL 
            AND age(now(), t2.join_dt) >= INTERVAL '1 year'
            AND (
                (t2.join_dt +
                (EXTRACT(YEAR FROM age(now(), t2.join_dt)) + 1 ) * INTERVAL '1 year')
                BETWEEN now() AND now() + '90 days'
            )
        )
    )
    SELECT
        COALESCE(JSON_AGG(row_to_json(t) ORDER BY TO_CHAR(t."eventDate", 'MM-DD') ), '[]'::json)
    INTO _celebrations_data
    FROM _celebrations AS t;


    --who is out this week
    WITH _month_dates AS (
        SELECT 
            DATE_TRUNC('day', now()) AS day_start, 
            DATE_TRUNC('day', now()) + INTERVAL '30 days' AS day_end
    )
    SELECT
        COALESCE(JSON_AGG(row_to_json(t)), '[]'::json)
    INTO _one_month_leave_data
    FROM (
        SELECT
            t1.id AS "userId",
            t1.name AS user,
            t2.from_dt AS "fromDate",
            t2.to_dt AS "toDate",
            t3.name AS "leaveType"
        FROM users t1
        JOIN user_leaves t2 ON t1.id = t2.user_id
        JOIN leave_policies t3 ON t2.leave_policy_id = t3.id
        JOIN _month_dates t4
        ON
            t2.from_dt <= t4.day_end
            AND t2.to_dt >= t4.day_start
        WHERE t2.status = 2
    )t;

    -- Build and return the final JSON object
    RETURN JSON_BUILD_OBJECT(
        'students', JSON_BUILD_OBJECT(
            'totalNumberCurrentYear', _student_count_current_year,
            'totalNumberPercInComparisonFromPrevYear', _student_perc_comparison,
            'totalNumberValueInComparisonFromPrevYear', _student_value_comparison
        ),
        'teachers', JSON_BUILD_OBJECT(
            'totalNumberCurrentYear', _teacher_count_current_year,
            'totalNumberPercInComparisonFromPrevYear', _teacher_perc_comparison,
            'totalNumberValueInComparisonFromPrevYear', _teacher_value_comparison
        ),
        'parents', JSON_BUILD_OBJECT(
            'totalNumberCurrentYear', _parent_count_current_year,
            'totalNumberPercInComparisonFromPrevYear', _parent_perc_comparison,
            'totalNumberValueInComparisonFromPrevYear', _parent_value_comparison
        ),
        'notices', _notices_data,
        'leavePolicies', _leave_policies_data,
        'leaveHistory', _leave_histories_data,
        'celebrations', _celebrations_data,
        'oneMonthLeave', _one_month_leave_data
    );
END;
$$;


ALTER FUNCTION public.get_dashboard_data(_user_id integer) OWNER TO postgres;

--
-- Name: get_notices(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_notices(_user_id integer) RETURNS TABLE(id integer, title character varying, description character varying, "authorId" integer, "createdDate" timestamp without time zone, "updatedDate" timestamp without time zone, author character varying, "reviewerName" character varying, "reviewedDate" timestamp without time zone, status character varying, "statusId" integer, "whoHasAccess" text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    _user_role_id INTEGER;
BEGIN    
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = _user_id) THEN
        RAISE EXCEPTION 'User does not exist';
    END IF;

    SELECT role_id FROM users u WHERE u.id = _user_id INTO _user_role_id;
    IF _user_role_id IS NULL THEN
        RAISE EXCEPTION 'Role does not exist';
    END IF;

    RETURN QUERY
    SELECT
        t1.id,
        t1.title,
        t1.description,
        t1.author_id AS "authorId",
        t1.created_dt AS "createdDate",
        t1.updated_dt AS "updatedDate",
        t2.name AS author,
        t4.name AS "reviewerName",
        t1.reviewed_dt AS "reviewedDate",
        t3.alias AS "status",
        t1.status AS "statusId",
        NULL AS "whoHasAccess"
    FROM notices t1
    LEFT JOIN users t2 ON t1.author_id = t2.id
    LEFT JOIN notice_status t3 ON t1.status = t3.id
    LEFT JOIN users t4 ON t1.reviewer_id = t4.id
    WHERE (
        _user_role_id = 1
        AND (
            t1.author_id = _user_id
            OR (
                t1.status != 1
                AND t1.author_id != _user_id
            )
        )
    )
    OR (
        _user_role_id != 1
        AND (
            t1.status != 6
            AND (
                t1.author_id = _user_id
                OR (
                    t1.status = 5
                    AND (
                        t1.recipient_type = 'EV'
                        OR (
                            t1.recipient_type = 'SP'
                            AND (
                                (
                                    t1.recipient_role_id = 2
                                    AND _user_role_id = 2
                                    AND (
                                        t1.recipient_first_field IS NULL
                                        OR t1.recipient_first_field = ''
                                        OR EXISTS (
                                            SELECT 1
                                            FROM user_profiles u
                                            JOIN users t5 ON u.user_id = t5.id
                                            WHERE u.department_id = (t1.recipient_first_field)::INTEGER
                                            AND t5.id = _user_id AND t5.role_id = _user_role_id
                                        )
                                    )
                                )
                                OR (
                                    t1.recipient_role_id = 3
                                    AND _user_role_id = 3
                                    AND (
                                        t1.recipient_first_field IS NULL
                                        OR t1.recipient_first_field = ''
                                        OR EXISTS (
                                            SELECT 1
                                            FROM user_profiles u
                                            JOIN users t5 ON u.user_id = t5.id
                                            WHERE u.class_name = t1.recipient_first_field
                                            AND t5.id = _user_id AND t5.role_id = _user_role_id
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
    ORDER BY t1.created_dt DESC;
END;
$$;


ALTER FUNCTION public.get_notices(_user_id integer) OWNER TO postgres;

--
-- Name: staff_add_update(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.staff_add_update(data jsonb) RETURNS TABLE("userId" integer, status boolean, message text, description text)
    LANGUAGE plpgsql
    AS $$

DECLARE
    _operationType VARCHAR(10);

    _userId INTEGER;
    _name TEXT;
    _role INTEGER;
    _gender TEXT;
    _maritalStatus TEXT;
    _phone TEXT;
    _email TEXT;
    _dob DATE;
    _joinDate DATE;
    _qualification TEXT;
    _experience TEXT;
    _currentAddress TEXT;
    _permanentAddress TEXT;
    _fatherName TEXT;
    _motherName TEXT;
    _emergencyPhone TEXT;
    _systemAccess BOOLEAN;
    _reporterId INTEGER;
BEGIN
    _userId := COALESCE((data ->>'id')::INTEGER, (data ->>'userId')::INTEGER, NULL);
    _name := COALESCE(data->>'name', NULL);
    _role := COALESCE((data->>'role')::INTEGER, NULL);
    _gender := COALESCE(data->>'gender', NULL);
    _maritalStatus := COALESCE(data->>'maritalStatus', NULL);
    _phone := COALESCE(data->>'phone', NULL);
    _email := COALESCE(data->>'email', NULL);
    _dob := COALESCE((data->>'dob')::DATE, NULL);
    _joinDate := COALESCE((data->>'joinDate')::DATE, NULL);
    _qualification := COALESCE(data->>'qualification', NULL);
    _experience := COALESCE(data->>'experience', NULL);
    _currentAddress := COALESCE(data->>'currentAddress', NULL);
    _permanentAddress := COALESCE(data->>'permanentAddress', NULL);
    _fatherName := COALESCE(data->>'fatherName', NULL);
    _motherName := COALESCE(data->>'motherName', NULL);
    _emergencyPhone := COALESCE(data->>'emergencyPhone', NULL);
    _systemAccess := COALESCE((data->>'systemAccess')::BOOLEAN, NULL);
    _reporterId := COALESCE((data->>'reporterId')::INTEGER, NULL);

    IF _userId IS NULL THEN
        _operationType := 'add';
    ELSE
        _operationType := 'update';
    END IF;

    IF _role = 3 THEN
        RETURN QUERY
        SELECT NULL::INTEGER, false, 'Student cannot be staff', NULL::TEXT;
        RETURN;
    END IF;

    IF NOT EXISTS(SELECT 1 FROM users WHERE id = _userId) THEN

        IF EXISTS(SELECT 1 FROM users WHERE email = _email) THEN
        RETURN QUERY
            SELECT NULL::INTEGER, false, 'Email already exists', NULL::TEXT;
        RETURN;
        END IF;

        INSERT INTO users (name,email,role_id,created_dt,reporter_id)
        VALUES (_name,_email,_role,now(),_reporterId) RETURNING id INTO _userId;

        INSERT INTO user_profiles
        (user_id, gender, marital_status, phone,dob,join_dt,qualification,experience,current_address,permanent_address,father_name,mother_name,emergency_phone)
        VALUES
        (_userId,_gender,_maritalStatus,_phone,_dob,_joinDate,_qualification,_experience,_currentAddress,_permanentAddress,_fatherName,_motherName,_emergencyPhone);

        RETURN QUERY
            SELECT _userId, true, 'Staff added successfully', NULL;
        RETURN;
    END IF;


    --update user tables
    UPDATE users
    SET
        name = _name,
        email = _email,
        role_id = _role,
        is_active = _systemAccess,
        reporter_id = _reporterId,
        updated_dt = now()
    WHERE id = _userId;

    UPDATE user_profiles
    SET
        gender = _gender,
        marital_status = _maritalStatus,
        phone = _phone,
        dob = _dob,
        join_dt = _joinDate,
        qualification = _qualification,
        experience = _experience,
        current_address = _currentAddress,
        permanent_address = _permanentAddress, 
        father_name = _fatherName,
        mother_name = _motherName,
        emergency_phone = _emergencyPhone
    WHERE user_id = _userId;

    RETURN QUERY
        SELECT _userId, true, 'Staff updated successfully', NULL;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY
            SELECT _userId::INTEGER, false, 'Unable to ' || _operationType || ' staff', SQLERRM;
END;
$$;


ALTER FUNCTION public.staff_add_update(data jsonb) OWNER TO postgres;

--
-- Name: student_add_update(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.student_add_update(data jsonb) RETURNS TABLE("userId" integer, status boolean, message text, description text)
    LANGUAGE plpgsql
    AS $$

DECLARE
    _operationType VARCHAR(10);
    _reporterId INTEGER;

    _userId INTEGER;
    _name TEXT;
    _roleId INTEGER;
    _gender TEXT;
    _phone TEXT;
    _email TEXT;
    _dob DATE;
    _currentAddress TEXT;
    _permanentAddress TEXT;
    _fatherName TEXT;
    _fatherPhone TEXT;
    _motherName TEXT;
    _motherPhone TEXT;
    _guardianName TEXT;
    _guardianPhone TEXT;
    _relationOfGuardian TEXT;
    _systemAccess BOOLEAN;
    _className TEXT;
    _sectionName TEXT;
    _admissionDt DATE;
    _roll INTEGER;
BEGIN
    _roleId = 3;
    _userId := COALESCE((data ->>'id')::INTEGER, (data ->>'userId')::INTEGER, NULL);
    _name := COALESCE(data->>'name', NULL);
    _gender := COALESCE(data->>'gender', NULL);
    _phone := COALESCE(data->>'phone', NULL);
    _email := COALESCE(data->>'email', NULL);
    _dob := COALESCE((data->>'dob')::DATE, NULL);
    _currentAddress := COALESCE(data->>'currentAddress', NULL);
    _permanentAddress := COALESCE(data->>'permanentAddress', NULL);
    _fatherName := COALESCE(data->>'fatherName', NULL);
    _fatherPhone := COALESCE(data->>'fatherPhone', NULL);
    _motherName := COALESCE(data->>'motherName', NULL);
    _motherPhone := COALESCE(data->>'motherPhone', NULL);
    _guardianName := COALESCE(data->>'guardianName', NULL);
    _guardianPhone := COALESCE(data->>'guardianPhone', NULL);
    _relationOfGuardian := COALESCE(data->>'relationOfGuardian', NULL);
    _systemAccess := COALESCE((data->>'systemAccess')::BOOLEAN, NULL);
    _className := COALESCE(data->>'class', NULL);
    _sectionName := COALESCE(data->>'section', NULL);
    _admissionDt := COALESCE((data->>'admissionDate')::DATE, NULL);
    _roll := COALESCE((data->>'roll')::INTEGER, NULL);

    IF _userId IS NULL THEN
        _operationType := 'add';
    ELSE
        _operationType := 'update';
    END IF;

    SELECT teacher_id
    FROM class_teachers
    WHERE class_name = _className AND section_name = _sectionName
    INTO _reporterId;

    IF _reporterId IS NULL THEN
        SELECT id from users WHERE role_id = 1 ORDER BY id ASC LIMIT 1 INTO _reporterId;
    END IF;

    IF NOT EXISTS(SELECT 1 FROM users WHERE id = _userId) THEN

        IF EXISTS(SELECT 1 FROM users WHERE email = _email) THEN
        RETURN QUERY
            SELECT NULL::INTEGER, false, 'Email already exists', NULL::TEXT;
        RETURN;
        END IF;

        INSERT INTO users (name,email,role_id,created_dt,reporter_id)
        VALUES (_name,_email,_roleId,now(),_reporterId) RETURNING id INTO _userId;

        INSERT INTO user_profiles
        (user_id,gender,phone,dob,admission_dt,class_name,section_name,roll,current_address,permanent_address,father_name,father_phone,mother_name,mother_phone,guardian_name,guardian_phone,relation_of_guardian)
        VALUES
        (_userId,_gender,_phone,_dob,_admissionDt,_className,_sectionName,_roll,_currentAddress,_permanentAddress,_fatherName,_fatherPhone,_motherName,_motherPhone,_guardianName,_guardianPhone,_relationOfGuardian);

        RETURN QUERY
            SELECT _userId, true, 'Student added successfully', NULL;
        RETURN;
    END IF;


    -- Check email uniqueness for update operation
    IF EXISTS(SELECT 1 FROM users WHERE email = _email AND id != _userId) THEN
        RETURN QUERY
            SELECT _userId::INTEGER, false, 'Email already exists', NULL::TEXT;
        RETURN;
    END IF;

    --update user tables
    UPDATE users
    SET
        name = _name,
        email = _email,
        role_id = _roleId,
        is_active = _systemAccess,
        updated_dt = now()
    WHERE id = _userId;

    UPDATE user_profiles
    SET
        gender = _gender,
        phone = _phone,
        dob = _dob,
        admission_dt = _admissionDt,
        class_name = _className,
        section_name  =_sectionName,
        roll = _roll,
        current_address = _currentAddress,
        permanent_address = _permanentAddress, 
        father_name = _fatherName,
        father_phone = _fatherPhone,
        mother_name = _motherName,
        mother_phone = _motherPhone,
        guardian_name = _guardianName,
        guardian_phone = _guardianPhone,
        relation_of_guardian = _relationOfGuardian
    WHERE user_id = _userId;

    RETURN QUERY
        SELECT _userId, true , 'Student updated successfully', NULL;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY
            SELECT _userId::INTEGER, false, 'Unable to ' || _operationType || ' student', SQLERRM;
END;
$$;


ALTER FUNCTION public.student_add_update(data jsonb) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_controls; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.access_controls (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    path character varying(100) DEFAULT NULL::character varying,
    icon character varying(100) DEFAULT NULL::character varying,
    parent_path character varying(100) DEFAULT NULL::character varying,
    hierarchy_id integer,
    type character varying(50) DEFAULT NULL::character varying,
    method character varying(10) DEFAULT NULL::character varying
);


ALTER TABLE public.access_controls OWNER TO postgres;

--
-- Name: access_controls_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.access_controls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.access_controls_id_seq OWNER TO postgres;

--
-- Name: access_controls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.access_controls_id_seq OWNED BY public.access_controls.id;


--
-- Name: class_teachers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.class_teachers (
    id integer NOT NULL,
    teacher_id integer,
    class_name character varying(50),
    section_name character varying(30)
);


ALTER TABLE public.class_teachers OWNER TO postgres;

--
-- Name: class_teachers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.class_teachers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.class_teachers_id_seq OWNER TO postgres;

--
-- Name: class_teachers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.class_teachers_id_seq OWNED BY public.class_teachers.id;


--
-- Name: classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classes (
    id integer NOT NULL,
    name character varying(50),
    sections character varying(50)
);


ALTER TABLE public.classes OWNER TO postgres;

--
-- Name: classes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.classes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.classes_id_seq OWNER TO postgres;

--
-- Name: classes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.classes_id_seq OWNED BY public.classes.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.departments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.departments_id_seq OWNER TO postgres;

--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: leave_policies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.leave_policies (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    is_active boolean DEFAULT true
);


ALTER TABLE public.leave_policies OWNER TO postgres;

--
-- Name: leave_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.leave_policies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.leave_policies_id_seq OWNER TO postgres;

--
-- Name: leave_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.leave_policies_id_seq OWNED BY public.leave_policies.id;


--
-- Name: leave_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.leave_status (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.leave_status OWNER TO postgres;

--
-- Name: leave_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.leave_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.leave_status_id_seq OWNER TO postgres;

--
-- Name: leave_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.leave_status_id_seq OWNED BY public.leave_status.id;


--
-- Name: notice_recipient_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notice_recipient_types (
    id integer NOT NULL,
    role_id integer,
    primary_dependent_name character varying(100) DEFAULT NULL::character varying,
    primary_dependent_select character varying(100) DEFAULT NULL::character varying
);


ALTER TABLE public.notice_recipient_types OWNER TO postgres;

--
-- Name: notice_recipient_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notice_recipient_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notice_recipient_types_id_seq OWNER TO postgres;

--
-- Name: notice_recipient_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notice_recipient_types_id_seq OWNED BY public.notice_recipient_types.id;


--
-- Name: notice_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notice_status (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    alias character varying(50) NOT NULL
);


ALTER TABLE public.notice_status OWNER TO postgres;

--
-- Name: notice_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notice_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notice_status_id_seq OWNER TO postgres;

--
-- Name: notice_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notice_status_id_seq OWNED BY public.notice_status.id;


--
-- Name: notices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notices (
    id integer NOT NULL,
    author_id integer,
    title character varying(100) NOT NULL,
    description character varying(400) NOT NULL,
    status integer,
    created_dt timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_dt timestamp without time zone,
    reviewed_dt timestamp without time zone,
    reviewer_id integer,
    recipient_type character varying(20) NOT NULL,
    recipient_role_id integer,
    recipient_first_field character varying(20) DEFAULT NULL::character varying
);


ALTER TABLE public.notices OWNER TO postgres;

--
-- Name: notices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notices_id_seq OWNER TO postgres;

--
-- Name: notices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notices_id_seq OWNED BY public.notices.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    role_id integer,
    access_control_id integer,
    type character varying(20) DEFAULT NULL::character varying
);


ALTER TABLE public.permissions OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.permissions_id_seq OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(50),
    is_active boolean DEFAULT true,
    is_editable boolean DEFAULT true
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_id_seq OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: sections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sections (
    id integer NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.sections OWNER TO postgres;

--
-- Name: sections_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sections_id_seq OWNER TO postgres;

--
-- Name: sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sections_id_seq OWNED BY public.sections.id;


--
-- Name: user_leave_policy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_leave_policy (
    id integer NOT NULL,
    user_id integer,
    leave_policy_id integer
);


ALTER TABLE public.user_leave_policy OWNER TO postgres;

--
-- Name: user_leave_policy_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_leave_policy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_leave_policy_id_seq OWNER TO postgres;

--
-- Name: user_leave_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_leave_policy_id_seq OWNED BY public.user_leave_policy.id;


--
-- Name: user_leaves; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_leaves (
    id integer NOT NULL,
    user_id integer NOT NULL,
    leave_policy_id integer,
    from_dt date NOT NULL,
    to_dt date NOT NULL,
    note character varying(100),
    submitted_dt timestamp without time zone,
    updated_dt timestamp without time zone,
    approved_dt timestamp without time zone,
    approver_id integer,
    status integer
);


ALTER TABLE public.user_leaves OWNER TO postgres;

--
-- Name: user_leaves_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_leaves_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_leaves_id_seq OWNER TO postgres;

--
-- Name: user_leaves_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_leaves_id_seq OWNED BY public.user_leaves.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_profiles (
    user_id integer NOT NULL,
    gender character varying(10) DEFAULT NULL::character varying,
    marital_status character varying(50) DEFAULT NULL::character varying,
    join_dt date,
    qualification character varying(100) DEFAULT NULL::character varying,
    experience character varying(100) DEFAULT NULL::character varying,
    dob date,
    phone character varying(20) DEFAULT NULL::character varying,
    class_name character varying(50) DEFAULT NULL::character varying,
    section_name character varying(50) DEFAULT NULL::character varying,
    roll integer,
    department_id integer,
    admission_dt date,
    father_name character varying(50) DEFAULT NULL::character varying,
    father_phone character varying(20) DEFAULT NULL::character varying,
    mother_name character varying(50) DEFAULT NULL::character varying,
    mother_phone character varying(20) DEFAULT NULL::character varying,
    guardian_name character varying(50) DEFAULT NULL::character varying,
    guardian_phone character varying(20) DEFAULT NULL::character varying,
    emergency_phone character varying(20) DEFAULT NULL::character varying,
    relation_of_guardian character varying(30) DEFAULT NULL::character varying,
    current_address character varying(50) DEFAULT NULL::character varying,
    permanent_address character varying(50) DEFAULT NULL::character varying,
    created_dt timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_dt timestamp without time zone
);


ALTER TABLE public.user_profiles OWNER TO postgres;

--
-- Name: user_refresh_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_refresh_tokens (
    id integer NOT NULL,
    token text NOT NULL,
    user_id integer,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


ALTER TABLE public.user_refresh_tokens OWNER TO postgres;

--
-- Name: user_refresh_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_refresh_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_refresh_tokens_id_seq OWNER TO postgres;

--
-- Name: user_refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_refresh_tokens_id_seq OWNED BY public.user_refresh_tokens.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(100) NOT NULL,
    password character varying(255) DEFAULT NULL::character varying,
    last_login timestamp without time zone,
    role_id integer,
    created_dt timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_dt timestamp without time zone,
    leave_policy_id integer,
    is_active boolean DEFAULT false,
    reporter_id integer,
    status_last_reviewed_dt timestamp without time zone,
    status_last_reviewer_id integer,
    is_email_verified boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: access_controls id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access_controls ALTER COLUMN id SET DEFAULT nextval('public.access_controls_id_seq'::regclass);


--
-- Name: class_teachers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_teachers ALTER COLUMN id SET DEFAULT nextval('public.class_teachers_id_seq'::regclass);


--
-- Name: classes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes ALTER COLUMN id SET DEFAULT nextval('public.classes_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: leave_policies id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_policies ALTER COLUMN id SET DEFAULT nextval('public.leave_policies_id_seq'::regclass);


--
-- Name: leave_status id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_status ALTER COLUMN id SET DEFAULT nextval('public.leave_status_id_seq'::regclass);


--
-- Name: notice_recipient_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_recipient_types ALTER COLUMN id SET DEFAULT nextval('public.notice_recipient_types_id_seq'::regclass);


--
-- Name: notice_status id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_status ALTER COLUMN id SET DEFAULT nextval('public.notice_status_id_seq'::regclass);


--
-- Name: notices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notices ALTER COLUMN id SET DEFAULT nextval('public.notices_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: sections id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sections ALTER COLUMN id SET DEFAULT nextval('public.sections_id_seq'::regclass);


--
-- Name: user_leave_policy id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leave_policy ALTER COLUMN id SET DEFAULT nextval('public.user_leave_policy_id_seq'::regclass);


--
-- Name: user_leaves id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leaves ALTER COLUMN id SET DEFAULT nextval('public.user_leaves_id_seq'::regclass);


--
-- Name: user_refresh_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_refresh_tokens ALTER COLUMN id SET DEFAULT nextval('public.user_refresh_tokens_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: access_controls; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.access_controls VALUES (1, 'Get my account detail', 'account', NULL, NULL, NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (2, 'Get permissions', '/api/v1/permissions', NULL, NULL, NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (3, 'Get teachers', '/api/v1/teachers', NULL, NULL, NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (4, 'Dashoard', '', NULL, NULL, NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (5, 'Get dashboard data', '/api/v1/dashboard', NULL, '', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (6, 'Resend email verification', '/api/v1/auth/resend-email-verification', NULL, NULL, NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (7, 'Resend password setup link', '/api/v1/auth/resend-pwd-setup-link', NULL, NULL, NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (8, 'Reset password', '/api/v1/auth/reset-pwd', NULL, NULL, NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (9, 'Leave', 'leave_parent', 'leave.svg', NULL, 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (10, 'Leave Define', 'leave/define', NULL, 'leave_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (11, 'Leave Request', 'leave/request', NULL, 'leave_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (12, 'Pending Leave Request', 'leave/pending', NULL, 'leave_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (13, 'Add leave policy', '/api/v1/leave/policies', NULL, 'leave_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (14, 'Get all leave policies', '/api/v1/leave/policies', NULL, 'leave_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (15, 'Get my leave policies', '/api/v1/leave/policies/me', NULL, 'leave_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (16, 'Update leave policy', '/api/v1/leave/policies/:id', NULL, 'leave_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (17, 'Handle policy status', '/api/v1/leave/policies/:id/status', NULL, 'leave_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (18, 'Add user to policy', '/api/v1/leave/policies/:id/users', NULL, 'leave_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (19, 'Get policy users', '/api/v1/leave/policies/:id/users', NULL, 'leave_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (20, 'Remove user from policy', '/api/v1/leave/policies/:id/users', NULL, 'leave_parent', NULL, 'api', 'DELETE');
INSERT INTO public.access_controls VALUES (21, 'Get policy eligible users', '/api/v1/leave/policies/eligible-users', NULL, 'leave_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (22, 'Get user leave history', '/api/v1/leave/request', NULL, 'leave_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (23, 'Create new leave request', '/api/v1/leave/request', NULL, 'leave_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (24, 'Update leave request', '/api/v1/leave/request/:id', NULL, 'leave_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (25, 'Delete leave request', '/api/v1/leave/request/:id', NULL, 'leave_parent', NULL, 'api', 'DELETE');
INSERT INTO public.access_controls VALUES (26, 'Get pending leave requests', '/api/v1/leave/pending', NULL, 'leave_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (27, 'Handle leave request status', '/api/v1/leave/pending/:id/status', NULL, 'leave_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (28, 'Academics', 'academics_parent', 'academics.svg', NULL, 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (29, 'Classes', 'classes', NULL, 'academics_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (30, 'Class Teachers', 'class-teachers', NULL, 'academics_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (31, 'Sections', 'sections', NULL, 'academics_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (32, 'Classes Edit', 'classes/edit/:id', NULL, 'academics_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (33, 'Class Teachers Edit', 'class-teachers/edit/:id', NULL, 'academics_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (34, 'Get all classes', '/api/v1/classes', NULL, 'academics_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (35, 'Get class detail', '/api/v1/classes/:id', NULL, 'academics_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (36, 'Add new class', '/api/v1/classes', NULL, 'academics_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (37, 'Update class detail', '/api/v1/classes/:id', NULL, 'academics_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (38, 'Delete class', '/api/v1/classes/:id', NULL, 'academics_parent', NULL, 'api', 'DELETE');
INSERT INTO public.access_controls VALUES (39, 'Get class with teacher details', '/api/v1/class-teachers', NULL, 'academics_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (40, 'Add class teacher', '/api/v1/class-teachers', NULL, 'academics_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (41, 'Get class teacher detail', '/api/v1/class-teachers/:id', NULL, 'academics_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (42, 'Update class teacher detail', '/api/v1/class-teachers/:id', NULL, 'academics_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (43, 'Section Edit', 'sections/edit/:id', NULL, 'academics_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (44, 'Get all sections', '/api/v1/sections', NULL, 'academics_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (45, 'Add new section', '/api/v1/sections', NULL, 'academics_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (46, 'Get section detail', '/api/v1/sections/:id', NULL, 'academics_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (47, 'Update section detail', '/api/v1/sections/:id', NULL, 'academics_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (48, 'Delete section', '/api/v1/sections/:id', NULL, 'academics_parent', NULL, 'api', 'DELETE');
INSERT INTO public.access_controls VALUES (49, 'Students', 'students_parent', 'students.svg', NULL, 4, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (50, 'Student List', 'students', NULL, 'students_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (51, 'Add Student', 'students/add', NULL, 'students_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (52, 'View Student', 'students/:id', NULL, 'students_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (53, 'Edit Student', 'students/edit/:id', NULL, 'students_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (54, 'Get students', '/api/v1/students', NULL, 'students_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (55, 'Add new student', '/api/v1/students', NULL, 'students_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (56, 'Get student detail', '/api/v1/students/:id', NULL, 'students_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (57, 'Handle student status', '/api/v1/students/:id/status', NULL, 'students_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (58, 'Update student detail', '/api/v1/students/:id', NULL, 'students_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (59, 'Communication', 'communication_parent', 'communication.svg', NULL, 5, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (60, 'Notice Board', 'notices', NULL, 'communication_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (61, 'Add Notice', 'notices/add', NULL, 'communication_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (62, 'Manage Notices', 'notices/manage', NULL, 'communication_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (63, 'Notice Recipients', 'notices/recipients', NULL, 'communication_parent', 4, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (64, 'View Notice', 'notices/:id', NULL, 'communication_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (65, 'Edit Notice', 'notices/edit/:id', NULL, 'communication_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (66, 'Edit Recipient', 'notices/recipients/edit/:id', NULL, 'communication_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (67, 'Get notice recipient list', '/api/v1/notices/recipients/list', NULL, 'communication_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (68, 'Get notice recipients', '/api/v1/notices/recipients', NULL, 'communication_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (69, 'Get notice recipient detail', '/api/v1/notices/recipients/:id', NULL, 'communication_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (70, 'Add new notice recipient', '/api/v1/notices/recipients', NULL, 'communication_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (71, 'Update notice recipient detail', '/api/v1/notices/recipients/:id', NULL, 'communication_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (72, 'Delete notice recipient detail', '/api/v1/notices/recipients/:id', NULL, 'communication_parent', NULL, 'api', 'DELETE');
INSERT INTO public.access_controls VALUES (73, 'Handle notice status', '/api/v1/notices/:id/status', NULL, 'communication_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (74, 'Get notice detail', '/api/v1/notices/:id', NULL, 'communication_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (75, 'Get all notices', '/api/v1/notices', NULL, 'communication_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (76, 'Add new notice', '/api/v1/notices', NULL, 'communication_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (77, 'Update notice detail', '/api/v1/notices/:id', NULL, 'communication_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (78, 'Human Resource', 'hr_parent', 'hr.svg', NULL, 6, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (79, 'Staff List', 'staffs', NULL, 'hr_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (80, 'Add Staff', 'staffs/add', NULL, 'hr_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (81, 'Departments', 'departments', NULL, 'hr_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (82, 'View Staffs', 'staffs/:id', NULL, 'hr_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (83, 'Edit Staff', 'staffs/edit/:id', NULL, 'hr_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (84, 'Get all staffs', '/api/v1/staffs', NULL, 'hr_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (85, 'Add new staff', '/api/v1/staffs', NULL, 'hr_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (86, 'Get staff detail', '/api/v1/staffs/:id', NULL, 'hr_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (87, 'Update staff detail', '/api/v1/staffs/:id', NULL, 'hr_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (88, 'Handle staff status', '/api/v1/staffs/:id/status', NULL, 'hr_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (89, 'Edit Department', 'departments/edit/id', NULL, 'hr_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (90, 'Get all departments', '/api/v1/departments', NULL, 'hr_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (91, 'Add new department', '/api/v1/departments', NULL, 'hr_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (92, 'Get department detail', '/api/v1/departments/:id', NULL, 'hr_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (93, 'Update department detail', '/api/v1/departments/:id', NULL, 'hr_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (94, 'Delete department', '/api/v1/departments/:id', NULL, 'hr_parent', NULL, 'api', 'DELETE');
INSERT INTO public.access_controls VALUES (95, 'Access Setting', 'access_setting_parent', 'rolesAndPermissions.svg', NULL, 7, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (96, 'Roles & Permissions', 'roles-and-permissions', NULL, 'access_setting_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (97, 'Get all roles', '/api/v1/roles', NULL, 'access_setting_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (98, 'Add new role', '/api/v1/roles', NULL, 'access_setting_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (99, 'Switch user role', '/api/v1/roles/switch', NULL, 'access_setting_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (100, 'Update role', '/api/v1/roles/:id', NULL, 'access_setting_parent', NULL, 'api', 'PUT');
INSERT INTO public.access_controls VALUES (101, 'Handle role status', '/api/v1/roles/:id/status', NULL, 'access_setting_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (102, 'Get role detail', '/api/v1/roles/:id', NULL, 'access_setting_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (103, 'Get role permissions', '/api/v1/roles/:id/permissions', NULL, 'access_setting_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (104, 'Add role permissions', '/api/v1/roles/:id/permissions', NULL, 'access_setting_parent', NULL, 'api', 'POST');
INSERT INTO public.access_controls VALUES (105, 'Get role users', '/api/v1/roles/:id/users', NULL, 'access_setting_parent', NULL, 'api', 'GET');
INSERT INTO public.access_controls VALUES (106, 'Get my account detail', 'account', NULL, NULL, NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (109, 'Dashoard', '', NULL, NULL, NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (114, 'Leave', 'leave_parent', 'leave.svg', NULL, 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (115, 'Leave Define', 'leave/define', NULL, 'leave_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (116, 'Leave Request', 'leave/request', NULL, 'leave_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (117, 'Pending Leave Request', 'leave/pending', NULL, 'leave_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (133, 'Academics', 'academics_parent', 'academics.svg', NULL, 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (134, 'Classes', 'classes', NULL, 'academics_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (135, 'Class Teachers', 'class-teachers', NULL, 'academics_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (136, 'Sections', 'sections', NULL, 'academics_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (137, 'Classes Edit', 'classes/edit/:id', NULL, 'academics_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (138, 'Class Teachers Edit', 'class-teachers/edit/:id', NULL, 'academics_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (148, 'Section Edit', 'sections/edit/:id', NULL, 'academics_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (154, 'Students', 'students_parent', 'students.svg', NULL, 4, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (155, 'Student List', 'students', NULL, 'students_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (156, 'Add Student', 'students/add', NULL, 'students_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (157, 'View Student', 'students/:id', NULL, 'students_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (158, 'Edit Student', 'students/edit/:id', NULL, 'students_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (164, 'Communication', 'communication_parent', 'communication.svg', NULL, 5, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (165, 'Notice Board', 'notices', NULL, 'communication_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (166, 'Add Notice', 'notices/add', NULL, 'communication_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (167, 'Manage Notices', 'notices/manage', NULL, 'communication_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (168, 'Notice Recipients', 'notices/recipients', NULL, 'communication_parent', 4, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (169, 'View Notice', 'notices/:id', NULL, 'communication_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (170, 'Edit Notice', 'notices/edit/:id', NULL, 'communication_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (171, 'Edit Recipient', 'notices/recipients/edit/:id', NULL, 'communication_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (183, 'Human Resource', 'hr_parent', 'hr.svg', NULL, 6, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (184, 'Staff List', 'staffs', NULL, 'hr_parent', 1, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (185, 'Add Staff', 'staffs/add', NULL, 'hr_parent', 2, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (186, 'Departments', 'departments', NULL, 'hr_parent', 3, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (187, 'View Staffs', 'staffs/:id', NULL, 'hr_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (188, 'Edit Staff', 'staffs/edit/:id', NULL, 'hr_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (194, 'Edit Department', 'departments/edit/id', NULL, 'hr_parent', NULL, 'screen', NULL);
INSERT INTO public.access_controls VALUES (200, 'Access Setting', 'access_setting_parent', 'rolesAndPermissions.svg', NULL, 7, 'menu-screen', NULL);
INSERT INTO public.access_controls VALUES (201, 'Roles & Permissions', 'roles-and-permissions', NULL, 'access_setting_parent', 1, 'menu-screen', NULL);


--
-- Data for Name: class_teachers; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.classes VALUES (1, '10th', 'A,B,C');
INSERT INTO public.classes VALUES (2, '11th', 'A,B');
INSERT INTO public.classes VALUES (3, '12th', 'A,B,C');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.departments VALUES (1, 'Mathematics');
INSERT INTO public.departments VALUES (2, 'Science');
INSERT INTO public.departments VALUES (3, 'English');
INSERT INTO public.departments VALUES (4, 'History');


--
-- Data for Name: leave_policies; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: leave_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.leave_status VALUES (1, 'On Review');
INSERT INTO public.leave_status VALUES (2, 'Approved');
INSERT INTO public.leave_status VALUES (3, 'Cancelled');


--
-- Data for Name: notice_recipient_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: notice_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.notice_status VALUES (1, 'Draft', 'Draft');
INSERT INTO public.notice_status VALUES (2, 'Submit for Review', 'Approval Pending');
INSERT INTO public.notice_status VALUES (3, 'Submit for Deletion', 'Delete Pending');
INSERT INTO public.notice_status VALUES (4, 'Reject', 'Rejected');
INSERT INTO public.notice_status VALUES (5, 'Approve', 'Approved');
INSERT INTO public.notice_status VALUES (6, 'Delete', 'Deleted');


--
-- Data for Name: notices; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.notices VALUES (1, 1, 'title1', 'des1', 1, '2025-12-15 22:49:00.813', NULL, NULL, NULL, 'EV', 0, '');


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.roles VALUES (1, 'Admin', true, false);
INSERT INTO public.roles VALUES (2, 'Teacher', true, false);
INSERT INTO public.roles VALUES (3, 'Student', true, false);


--
-- Data for Name: sections; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.sections VALUES (1, 'A');
INSERT INTO public.sections VALUES (2, 'B');
INSERT INTO public.sections VALUES (3, 'C');


--
-- Data for Name: user_leave_policy; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: user_leaves; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: user_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.user_profiles VALUES (1, 'Male', 'Married', NULL, NULL, NULL, '2024-08-05', '4759746607', NULL, NULL, NULL, NULL, NULL, 'stut', NULL, 'lancy', NULL, NULL, NULL, '79374304', NULL, NULL, NULL, '2025-12-15 14:10:55.222685', NULL);
INSERT INTO public.user_profiles VALUES (13, 'male', NULL, NULL, NULL, NULL, '2005-01-15', '13800138001', '10th', 'A', NULL, NULL, NULL, '张父', '13900139000', NULL, NULL, NULL, NULL, NULL, NULL, '北京市朝阳区', NULL, '2025-12-16 00:33:54.226408', NULL);
INSERT INTO public.user_profiles VALUES (14, 'male', NULL, NULL, NULL, NULL, '2005-01-15', '13800138001', '10th', 'A', NULL, NULL, NULL, '张父', '13900139000', NULL, NULL, NULL, NULL, NULL, NULL, '北京市朝阳区', NULL, '2025-12-16 00:40:09.505414', NULL);
INSERT INTO public.user_profiles VALUES (15, 'male', NULL, NULL, NULL, NULL, '2005-01-15', '13800138001', '10th', 'A', NULL, NULL, NULL, '张父', '13900139000', NULL, NULL, NULL, NULL, NULL, NULL, '北京市朝阳区', NULL, '2025-12-16 00:41:10.463579', NULL);
INSERT INTO public.user_profiles VALUES (16, 'male', NULL, NULL, NULL, NULL, '2005-01-15', '13800138000', '10th', 'A', 1, NULL, NULL, '张父', '13900139000', NULL, NULL, NULL, NULL, NULL, NULL, '北京市朝阳区', NULL, '2025-12-16 01:19:29.435822', NULL);
INSERT INTO public.user_profiles VALUES (17, 'male', NULL, NULL, NULL, NULL, '2005-01-15', '13800138000', '10th', 'A', 1, NULL, NULL, '张父', '13900139000', NULL, NULL, NULL, NULL, NULL, NULL, '北京市朝阳区', NULL, '2025-12-16 01:20:49.004669', NULL);
INSERT INTO public.user_profiles VALUES (12, 'male', NULL, NULL, NULL, NULL, '2005-01-15', '13800138001', '10th', 'A', NULL, NULL, NULL, '张父224', '13900139000', NULL, NULL, NULL, NULL, NULL, NULL, '北京市朝阳区', NULL, '2025-12-16 00:28:18.02821', NULL);


--
-- Data for Name: user_refresh_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.user_refresh_tokens VALUES (9, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwicm9sZSI6ImFkbWluIiwicm9sZUlkIjoxLCJpYXQiOjE3NjU4MTkwODksImV4cCI6MTc2NTg0Nzg4OX0.ugjaFgRRBfVvYtIgqLbLmu-UqLHT9M-tXxydyazbS4c', 1, '2025-12-16 01:18:08.903861+08', '2025-12-16 09:18:09.033+08');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.users VALUES (13, '张三', 'zhangsan@example1.com', NULL, NULL, 3, '2025-12-16 00:33:54.226408', NULL, NULL, false, 1, NULL, NULL, false);
INSERT INTO public.users VALUES (14, '张三', 'zhangsan@example2.com', NULL, NULL, 3, '2025-12-16 00:40:09.505414', NULL, NULL, false, 1, NULL, NULL, false);
INSERT INTO public.users VALUES (15, '张三', 'zhangsan@example22.com', NULL, NULL, 3, '2025-12-16 00:41:10.463579', NULL, NULL, false, 1, NULL, NULL, false);
INSERT INTO public.users VALUES (1, 'John Doe', 'admin@school-admin.com', '$argon2id$v=19$m=65536,t=3,p=4$21a+bDbESEI60WO1wRKnvQ$i6OrxqNiHvwtf1Xg3bfU5+AXZG14fegW3p+RSMvq1oU', '2025-12-16 01:18:09.035', 1, '2025-12-15 14:10:55.222685', NULL, NULL, true, NULL, NULL, NULL, true);
INSERT INTO public.users VALUES (16, '张三', 'zhangsan@example.com', NULL, NULL, 3, '2025-12-16 01:19:29.435822', NULL, NULL, false, 1, NULL, NULL, false);
INSERT INTO public.users VALUES (17, '张三', 'zhangsan@example222.com', NULL, NULL, 3, '2025-12-16 01:20:49.004669', NULL, NULL, false, 1, NULL, NULL, false);
INSERT INTO public.users VALUES (12, '张三', 'zhangsan@example223.com', NULL, NULL, 3, '2025-12-16 00:28:18.02821', '2025-12-16 01:21:51.811941', NULL, true, 1, '2025-12-16 01:23:04.117', 1, false);


--
-- Name: access_controls_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.access_controls_id_seq', 210, true);


--
-- Name: class_teachers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.class_teachers_id_seq', 1, false);


--
-- Name: classes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.classes_id_seq', 3, true);


--
-- Name: departments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.departments_id_seq', 4, true);


--
-- Name: leave_policies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.leave_policies_id_seq', 1, false);


--
-- Name: leave_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.leave_status_id_seq', 1, true);


--
-- Name: notice_recipient_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notice_recipient_types_id_seq', 1, false);


--
-- Name: notice_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notice_status_id_seq', 1, true);


--
-- Name: notices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notices_id_seq', 1, true);


--
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permissions_id_seq', 1, false);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 1, true);


--
-- Name: sections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sections_id_seq', 3, true);


--
-- Name: user_leave_policy_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_leave_policy_id_seq', 1, false);


--
-- Name: user_leaves_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_leaves_id_seq', 1, false);


--
-- Name: user_refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_refresh_tokens_id_seq', 9, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 17, true);


--
-- Name: access_controls access_controls_path_method_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access_controls
    ADD CONSTRAINT access_controls_path_method_key UNIQUE (path, method);


--
-- Name: access_controls access_controls_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.access_controls
    ADD CONSTRAINT access_controls_pkey PRIMARY KEY (id);


--
-- Name: class_teachers class_teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_teachers
    ADD CONSTRAINT class_teachers_pkey PRIMARY KEY (id);


--
-- Name: classes classes_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_name_key UNIQUE (name);


--
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (id);


--
-- Name: departments departments_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_name_key UNIQUE (name);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: leave_policies leave_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_policies
    ADD CONSTRAINT leave_policies_pkey PRIMARY KEY (id);


--
-- Name: leave_status leave_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_status
    ADD CONSTRAINT leave_status_pkey PRIMARY KEY (id);


--
-- Name: notice_recipient_types notice_recipient_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_recipient_types
    ADD CONSTRAINT notice_recipient_types_pkey PRIMARY KEY (id);


--
-- Name: notice_status notice_status_alias_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_status
    ADD CONSTRAINT notice_status_alias_key UNIQUE (alias);


--
-- Name: notice_status notice_status_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_status
    ADD CONSTRAINT notice_status_name_key UNIQUE (name);


--
-- Name: notice_status notice_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_status
    ADD CONSTRAINT notice_status_pkey PRIMARY KEY (id);


--
-- Name: notices notices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notices
    ADD CONSTRAINT notices_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_role_id_access_control_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_role_id_access_control_id_key UNIQUE (role_id, access_control_id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: sections sections_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT sections_name_key UNIQUE (name);


--
-- Name: sections sections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT sections_pkey PRIMARY KEY (id);


--
-- Name: user_leave_policy user_leave_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leave_policy
    ADD CONSTRAINT user_leave_policy_pkey PRIMARY KEY (id);


--
-- Name: user_leave_policy user_leave_policy_user_id_leave_policy_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leave_policy
    ADD CONSTRAINT user_leave_policy_user_id_leave_policy_id_key UNIQUE (user_id, leave_policy_id);


--
-- Name: user_leaves user_leaves_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leaves
    ADD CONSTRAINT user_leaves_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: user_refresh_tokens user_refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_refresh_tokens
    ADD CONSTRAINT user_refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: class_teachers class_teachers_class_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_teachers
    ADD CONSTRAINT class_teachers_class_name_fkey FOREIGN KEY (class_name) REFERENCES public.classes(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: class_teachers class_teachers_section_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_teachers
    ADD CONSTRAINT class_teachers_section_name_fkey FOREIGN KEY (section_name) REFERENCES public.sections(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: class_teachers class_teachers_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_teachers
    ADD CONSTRAINT class_teachers_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- Name: notice_recipient_types notice_recipient_types_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice_recipient_types
    ADD CONSTRAINT notice_recipient_types_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: notices notices_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notices
    ADD CONSTRAINT notices_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: notices notices_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notices
    ADD CONSTRAINT notices_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.users(id);


--
-- Name: notices notices_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notices
    ADD CONSTRAINT notices_status_fkey FOREIGN KEY (status) REFERENCES public.notice_status(id);


--
-- Name: permissions permissions_access_control_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_access_control_id_fkey FOREIGN KEY (access_control_id) REFERENCES public.access_controls(id);


--
-- Name: permissions permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: user_leave_policy user_leave_policy_leave_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leave_policy
    ADD CONSTRAINT user_leave_policy_leave_policy_id_fkey FOREIGN KEY (leave_policy_id) REFERENCES public.leave_policies(id);


--
-- Name: user_leave_policy user_leave_policy_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leave_policy
    ADD CONSTRAINT user_leave_policy_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_leaves user_leaves_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leaves
    ADD CONSTRAINT user_leaves_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: user_leaves user_leaves_leave_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leaves
    ADD CONSTRAINT user_leaves_leave_policy_id_fkey FOREIGN KEY (leave_policy_id) REFERENCES public.leave_policies(id);


--
-- Name: user_leaves user_leaves_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leaves
    ADD CONSTRAINT user_leaves_status_fkey FOREIGN KEY (status) REFERENCES public.leave_status(id);


--
-- Name: user_leaves user_leaves_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_leaves
    ADD CONSTRAINT user_leaves_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_profiles user_profiles_class_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_class_name_fkey FOREIGN KEY (class_name) REFERENCES public.classes(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: user_profiles user_profiles_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: user_profiles user_profiles_section_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_section_name_fkey FOREIGN KEY (section_name) REFERENCES public.sections(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_refresh_tokens user_refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_refresh_tokens
    ADD CONSTRAINT user_refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_leave_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_leave_policy_id_fkey FOREIGN KEY (leave_policy_id) REFERENCES public.leave_policies(id);


--
-- Name: users users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: users users_status_last_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_status_last_reviewer_id_fkey FOREIGN KEY (status_last_reviewer_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict JzgW4bm0QYTVaTgxgIseiZhXCzdytFwjVs88RCd0UweCOeQSSWGduxH7yu3weEP

