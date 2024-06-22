--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

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
-- Name: pos_float; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.pos_float AS numeric
	CONSTRAINT pos_float_check CHECK ((VALUE > (0)::numeric));


ALTER DOMAIN public.pos_float OWNER TO postgres;

--
-- Name: pos_int; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.pos_int AS integer
	CONSTRAINT pos_int_check CHECK ((VALUE > 0));


ALTER DOMAIN public.pos_int OWNER TO postgres;

--
-- Name: телефон; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public."телефон" AS text
	CONSTRAINT "телефон_check" CHECK ((VALUE ~ '^\+\d{11}$'::text));


ALTER DOMAIN public."телефон" OWNER TO postgres;

--
-- Name: добавить_запись_в_таблицу(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."добавить_запись_в_таблицу"(params jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  key TEXT;
  value TEXT;
  columns TEXT := '';
  values TEXT := '';
  first BOOLEAN := TRUE;
  auto_increment_columns TEXT := '';
  auto_increment_values jsonb := '{}';
  result RECORD;
  tablename TEXT;
BEGIN
  -- Извлекаем имя таблицы из params
  tablename := params->>'tableName';
  params := params - 'tableName';

  -- Добавляем контрольное сообщение для отладки
  RAISE NOTICE 'Имя таблицы: %', tablename;

  -- Строим часть запроса с колонками и значениями
  FOR key, value IN SELECT * FROM jsonb_each_text(params)
  LOOP
    IF NOT first THEN
      columns := columns || ', ';
      values := values || ', ';
    ELSE
      first := FALSE;
    END IF;
    columns := columns || quote_ident(key);
    values := values || quote_literal(value);

    -- Добавляем контрольное сообщение для отладки
    RAISE NOTICE 'Колонка: %, Значение: %', key, value;
  END LOOP;

  -- Получаем колонки с автоинкрементацией
  SELECT string_agg(column_name, ', ')
  INTO auto_increment_columns
  FROM information_schema.columns
  WHERE table_name = tablename AND (column_default LIKE 'nextval(%' OR is_identity = 'YES');

  -- Добавляем контрольное сообщение для отладки
  RAISE NOTICE 'Колонки с автоинкрементацией: %', auto_increment_columns;

  -- Если есть колонки с автоинкрементацией, добавляем их в RETURNING часть запроса
  IF auto_increment_columns IS NOT NULL THEN
    EXECUTE 'INSERT INTO ' || quote_ident(tablename) || '(' || columns || ') VALUES (' || values || ') RETURNING ' || auto_increment_columns INTO result;
    -- Преобразуем результат в JSON
    auto_increment_values := row_to_json(result);

    -- Добавляем контрольное сообщение для отладки
    RAISE NOTICE 'Возвращаемые значения автоинкрементных колонок: %', auto_increment_values;
  ELSE
    EXECUTE 'INSERT INTO ' || quote_ident(tablename) || '(' || columns || ') VALUES (' || values || ')';

    -- Добавляем контрольное сообщение для отладки
    RAISE NOTICE 'Запрос без автоинкрементных колонок выполнен.';
  END IF;

  RETURN auto_increment_values;
END;
$$;


ALTER FUNCTION public."добавить_запись_в_таблицу"(params jsonb) OWNER TO postgres;

--
-- Name: изменить_запись_в_таблице(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."изменить_запись_в_таблице"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    key_columns TEXT[]; -- Массив для хранения имен столбцов уникальных ключей
    updateSetClause TEXT := '';
    whereConditions TEXT := '';
    column_name_key TEXT;
    column_value_key TEXT;
    tablename TEXT;
BEGIN
    -- Извлекаем имя таблицы из params
    tablename := params->>'tableName';
    
    -- Удаляем tableName из parameters для дальнейшей обработки
    params := params - 'tableName';

    -- Получаем имена столбцов уникальных ключей из метаданных таблицы
    SELECT array_agg(column_name::text)
    INTO key_columns
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
    WHERE tc.table_name = tablename AND tc.constraint_type = 'PRIMARY KEY';

    -- Перебираем все столбцы в JSON и определяем, какие из них уникальные ключи, а какие данные для обновления
    FOR column_name_key, column_value_key IN SELECT key, value FROM jsonb_each_text(params)
    LOOP
        IF column_name_key = ANY(key_columns) THEN
            -- Формируем условие WHERE для запроса
            whereConditions := whereConditions || format('%I = %L AND ', column_name_key, column_value_key);
        ELSE
            -- Формируем часть запроса с обновлением значений
            updateSetClause := updateSetClause || format('%I = %L, ', column_name_key, column_value_key);
        END IF;
    END LOOP;

    -- Обрезаем лишние запятые и "AND"
    updateSetClause := rtrim(updateSetClause, ', ');
    whereConditions := rtrim(whereConditions, ' AND ');

    -- Выполняем запрос на обновление
    EXECUTE format('UPDATE %I SET %s WHERE %s;', 
                   tablename, 
                   updateSetClause, 
                   whereConditions);

END;
$$;


ALTER PROCEDURE public."изменить_запись_в_таблице"(IN params jsonb) OWNER TO postgres;

--
-- Name: получить_дополнительные_данные(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."получить_дополнительные_данные"(params jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  expanded_source text;
  expanded_columns text[];
  column_name text;
  value text;
  record jsonb;
BEGIN
  -- Извлекаем название таблицы из JSON
  expanded_source := params ->> 'expandedSource';

  -- Извлекаем названия колонок из JSON
  expanded_columns := ARRAY(SELECT jsonb_array_elements_text(params -> 'expandedColumns'));

  -- Извлекаем имя колонки для фильтрации
  column_name := params ->> 'columnName';

  -- Извлекаем значение для фильтрации
  value := params ->> 'value';

  -- Формируем и выполняем динамический SQL запрос для извлечения и фильтрации данных
  EXECUTE format('SELECT row_to_json(t) FROM (SELECT %s FROM %I WHERE %I = %L) t LIMIT 1',
                 array_to_string(expanded_columns, ', '),
                 expanded_source,
                 column_name,
                 value) INTO record;

  -- Возвращаем запись как JSON объект
  RETURN record;

END;
$$;


ALTER FUNCTION public."получить_дополнительные_данные"(params jsonb) OWNER TO postgres;

--
-- Name: получить_записи(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."получить_записи"(params jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Переменная для хранения имени таблицы
    tablename text;

    -- Переменная для формирования динамического SQL запроса
    query TEXT;

    -- Переменная для хранения результата
    result JSON;
BEGIN
    -- Извлечение значения имени таблицы из JSON
    tablename := params->>'tablename';

    -- Проверка наличия необходимых параметров
    IF tablename IS NULL THEN
        RAISE EXCEPTION 'Не указано имя таблицы';
    END IF;

    -- Формирование SQL запроса для получения всех записей из таблицы
    query := format('SELECT row_to_json(t) FROM (SELECT * FROM %I) t', tablename);
    
    -- Возвращение результата запроса
    FOR result IN EXECUTE query LOOP
        RETURN NEXT result;
    END LOOP;
END;
$$;


ALTER FUNCTION public."получить_записи"(params jsonb) OWNER TO postgres;

--
-- Name: получить_записи_join(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."получить_записи_join"(params jsonb) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    tablename text;
    joinTableName text;
    joinTableValue text;
    joinColumnName text;
    query text;
BEGIN
    tablename := params->>'tableName';
    
    params := params - 'tableName';
    
    IF params IS NULL OR params = '{}' THEN
        query := format('SELECT row_to_json(t)::jsonb FROM %I t', tablename);
    ELSE
	
        SELECT params->>'joinTable' INTO joinTableName;
        SELECT params->>'value' INTO joinTableValue;
        SELECT params->>'joinColumn' INTO joinColumnName;

        query := format('
            SELECT row_to_json(t)::jsonb
            FROM %I t
            JOIN %I jt ON t.%I = jt.%I
            WHERE jt.%I = %L',
            tablename, joinTableName, joinColumnName, joinColumnName, joinColumnName, joinTableValue);
    END IF;

    RETURN QUERY EXECUTE query;
END;
$$;


ALTER FUNCTION public."получить_записи_join"(params jsonb) OWNER TO postgres;

--
-- Name: получить_записи_по_атрибуту(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."получить_записи_по_атрибуту"(params jsonb) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    table_name text;
    attributes jsonb;
    query text;
    conditions text := '';
    record jsonb;
    key text;
    value text;
BEGIN
    -- Извлекаем имя таблицы и атрибуты из параметров
    table_name := params->>'tablename';
    attributes := params->'attributes';

    -- Отладочные сообщения
    RAISE NOTICE 'Имя таблицы: %', table_name;
    RAISE NOTICE 'Атрибуты: %', attributes;

    -- Проверяем, пустые ли атрибуты
    IF attributes IS NULL OR attributes = '{}' THEN
        -- Если атрибуты пустые, то составляем запрос без условий
        query := 'SELECT row_to_json(t) FROM ' || quote_ident(table_name) || ' t';
        RAISE NOTICE 'Запрос без условий: %', query;
    ELSE
        -- Если атрибуты не пустые, составляем условия
        FOR key, value IN SELECT * FROM jsonb_each_text(attributes) LOOP
            IF conditions != '' THEN
                conditions := conditions || ' AND ';
            END IF;
            conditions := conditions || format('%I = %L', key, value);
        END LOOP;
        
        -- Отладочное сообщение для условий
        RAISE NOTICE 'Условия запроса: %', conditions;

        -- Далее составляем запрос с условиями
        query := 'SELECT row_to_json(t) FROM ' || quote_ident(table_name) || ' t WHERE ' || conditions;
        RAISE NOTICE 'Запрос с условиями: %', query;
    END IF;

    -- Выполняем запрос и возвращаем результат как множество записей
    FOR record IN EXECUTE query LOOP
        RAISE NOTICE 'Полученная запись: %', record;
        RETURN NEXT record;
    END LOOP;

    RETURN;
END 
$$;


ALTER FUNCTION public."получить_записи_по_атрибуту"(params jsonb) OWNER TO postgres;

--
-- Name: получить_покупателей_и_их_скидки(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."получить_покупателей_и_их_скидки"() RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Переменная для хранения динамического SQL запроса
    query TEXT;

    -- Переменная для хранения результата
    result JSON;
BEGIN
    -- Формирование SQL запроса для получения клиентов и их скидок
    query := 'SELECT json_build_object(
                ''ид_персоны'', p.ид_персоны,
                ''фамилия'', p.фамилия,
                ''имя'', p.имя,
                ''отчество'', p.отчество,
                ''скидка'', COALESCE(c.скидка, 0)
              )
              FROM персона p
              LEFT JOIN покупатель c ON p.ид_персоны = c.ид_персоны';
    
    -- Выполнение запроса и возврат результата
    FOR result IN EXECUTE query LOOP
        RETURN NEXT result;
    END LOOP;
END;
$$;


ALTER FUNCTION public."получить_покупателей_и_их_скидки"() OWNER TO postgres;

--
-- Name: получить_полную_цену(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."получить_полную_цену"(params jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
    лекарства_ids int[];
    запись json;
    retail_price numeric;
BEGIN
    -- Извлекаем массив ид_лекарств из параметров
    SELECT array_agg(value::int)
    INTO лекарства_ids
    FROM jsonb_array_elements_text(params->'ид_лекарств');
    
    -- Проверяем, что массив не NULL и не пуст
    IF лекарства_ids IS NOT NULL AND array_length(лекарства_ids, 1) > 0 THEN
        -- Цикл по каждому ид_лекарства
        FOR i IN 1..array_length(лекарства_ids, 1) LOOP
            -- Получаем розничную цену из таблицы "поставка"
            SELECT p.цена_розничная INTO retail_price
            FROM поставка p
            WHERE p.ид_лекарства = лекарства_ids[i];

            -- Формируем JSON объект результата
            запись := json_build_object(
                'ид_лекарства', лекарства_ids[i],
                'полная_стоимость', retail_price
            );
            
            -- Возвращаем JSON объект
            RETURN NEXT запись;
        END LOOP;
    END IF;
    
    RETURN;
END;
$$;


ALTER FUNCTION public."получить_полную_цену"(params jsonb) OWNER TO postgres;

--
-- Name: проверить_лекарства_по_рецепту(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."проверить_лекарства_по_рецепту"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    productIds INTEGER[];
    recipeIds INTEGER[];
    invalidRecord RECORD;
BEGIN
    -- Извлекаем массивы из JSON параметра и преобразуем к INTEGER
    productIds := ARRAY(
        SELECT (jsonb_array_elements_text(params->'productIds'))::INTEGER
    );
    recipeIds := ARRAY(
        SELECT (jsonb_array_elements_text(params->'recipeIds'))::INTEGER
    );

    -- Проверяем, что все лекарства имеют ид_Каталога из списка recipeIds или разрешены к продаже без рецепта
    FOR invalidRecord IN
        SELECT l.ид_лекарства, l.ид_каталога, к.название, к.производитель, к.дозировка, к.по_рецепту
        FROM лекарство l
        JOIN каталог к ON l.ид_каталога = к.ид_каталога
        WHERE l.ид_лекарства = ANY(productIds) 
          AND l.ид_каталога <> ALL(recipeIds)
          AND к.по_рецепту = true
    LOOP
        RAISE EXCEPTION USING
            ERRCODE = 'P0100',
            MESSAGE = format('Лекарство: %s %s %s не может быть продано по данному рецепту',
                             invalidRecord.название, invalidRecord.производитель, invalidRecord.дозировка);
    END LOOP;

END;
$$;


ALTER PROCEDURE public."проверить_лекарства_по_рецепту"(IN params jsonb) OWNER TO postgres;

--
-- Name: проверить_персональный_код(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."проверить_персональный_код"(data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    employeeId INTEGER;
    personalCode TEXT;
    foundEmployee RECORD;
    accessLevel TEXT;
BEGIN
    -- Извлекаем значения из JSON
    employeeId := (data->>'employeeId')::INTEGER;
    personalCode := data->>'personalCode';

    -- Находим сотрудника с указанным employeeId
    SELECT ид_сотрудника, персональный_код, ид_должности
    INTO foundEmployee
    FROM сотрудник
    WHERE ид_сотрудника = employeeId;

    -- Если сотрудник не найден, выбрасываем ошибку
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Сотрудник с id % не найден', employeeId;
    END IF;

    -- Проверяем, совпадает ли персональный код
    IF foundEmployee.персональный_код != personalCode THEN
        RAISE EXCEPTION 'Указанный персональный код не соотвествует указанному сотруднику';
    END IF;

    -- Получаем уровень доступа из таблицы "должность"
    SELECT уровень_доступа
    INTO accessLevel
    FROM должность
    WHERE ид_должности = foundEmployee.ид_должности;
    
    -- Если уровень доступа не найден, выбрасываем ошибку
    IF accessLevel IS NULL THEN
        RAISE EXCEPTION 'Указанный сотрудник имеет должность без уровня доступа.';
    END IF;

    -- Возвращаем уровень доступа как JSON
    RETURN jsonb_build_object('accessLevel', accessLevel);
END;
$$;


ALTER FUNCTION public."проверить_персональный_код"(data jsonb) OWNER TO postgres;

--
-- Name: создать_клиента(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."создать_клиента"(params jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_person_id INT;
    new_client_id INT;
    birth_date DATE;
    result JSONB;
BEGIN
    -- Попробуем явно преобразовать дату
    birth_date := (params->>'birth_date')::date;

    -- Создаем новую запись в таблице "персона"
    INSERT INTO персона (фамилия, имя, отчество, дата_рождения, телефон)
    VALUES (
        params->>'last_name',
        params->>'first_name',
        params->>'middle_name',
        birth_date,
        params->>'phone'
    )
    RETURNING ид_персоны INTO new_person_id;

    -- Создаем новую запись в таблице "покупатель"
    INSERT INTO покупатель (ид_персоны, скидка)
    VALUES (new_person_id, (params->>'discount')::float4)
    RETURNING ид_клиента INTO new_client_id;

    -- Формируем результат в виде JSON
    result := jsonb_build_object(
        'ид_клиента', new_client_id,
        'фамилия', params->>'last_name',
        'имя', params->>'first_name',
        'отчество', params->>'middle_name',
        'дата_рождения', params->>'birth_date',
        'телефон', params->>'phone',
        'скидка', params->>'discount'
    );

    -- Возвращаем сформированный JSON
    RETURN result;
END;
$$;


ALTER FUNCTION public."создать_клиента"(params jsonb) OWNER TO postgres;

--
-- Name: создать_поставку(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."создать_поставку"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_quantity int;
    v_provider_id int;
    v_catalog_id int;
    v_final_price numeric;
    v_date date;
    v_markup numeric;
    v_provider_quantity int;
    v_new_med_id int;
    v_serial_number varchar;
    v_manufacture_date date;
    v_expiry_date date;
BEGIN
    -- Parse JSON input
    v_quantity := (params->>'quantity')::int;
    v_provider_id := (params->>'provider_id')::int;
    v_catalog_id := (params->>'catalog_id')::int;
    v_final_price := (params->>'final_price')::numeric;
    v_date := (params->>'date')::date;
    v_markup := (params->>'markup')::numeric;

    -- Check provider's quantity
    SELECT количество INTO v_provider_quantity
    FROM public.поставщик
    WHERE ид_поставщика = v_provider_id AND ид_каталога = v_catalog_id;
    
    IF v_quantity > v_provider_quantity OR v_quantity > 1000 THEN
        RAISE EXCEPTION USING ERRCODE = 'P7772';
    END IF;

    -- Insert into public.лекарство
    FOR i IN 1..v_quantity LOOP
        v_serial_number := substr(md5(random()::text), 1, 5) || chr(trunc(65 + random() * 25)::int) || chr(trunc(65 + random() * 25)::int);
        
        v_manufacture_date := CURRENT_DATE + ((random() * 20 - 10) || ' days')::interval;
        v_expiry_date := v_manufacture_date + interval '1 year';

        INSERT INTO public.лекарство (серийный_номер, дата_изготовления, дата_окончания, ид_каталога, в_наличии)
        VALUES (v_serial_number, v_manufacture_date, v_expiry_date, v_catalog_id, true)
        RETURNING ид_лекарства INTO v_new_med_id;

        -- Insert into public.поставка
        INSERT INTO public.поставка (ид_поставщика, цена_розничная, ид_лекарства, дата, наценка)
        VALUES (v_provider_id, v_final_price, v_new_med_id, v_date, v_markup);
    END LOOP;
END;
$$;


ALTER PROCEDURE public."создать_поставку"(IN params jsonb) OWNER TO postgres;

--
-- Name: создать_продажу(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."создать_продажу"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    sale_id BIGINT;
    product_id TEXT;
    product_id_int INTEGER;
    total_sum NUMERIC := 0;
    sale_time TIMESTAMP;
    shift_id INTEGER;
    person_id INTEGER;
    discount FLOAT4 := 0;
BEGIN
    -- Извлекаем и преобразуем время и идентификатор смены из JSON
    sale_time := (params->>'time')::timestamp;
    shift_id := (params->>'shiftId')::integer;

    -- Извлекаем идентификатор персоны, если он есть и не является пустой строкой
    IF params ? 'personId' AND params->>'personId' != '' THEN
        person_id := (params->>'personId')::integer;
    ELSE
        person_id := NULL;
    END IF;

    -- 1. Создаем запись в таблице "продажа"
    INSERT INTO продажа (время, ид_смены, ид_персоны)
    VALUES (sale_time, shift_id, person_id)
    RETURNING ид_продажи INTO sale_id;

    -- 2. Создаем записи в таблице "продажа_лекарство"
    FOR product_id IN SELECT jsonb_array_elements_text(params->'productIds')
    LOOP
        product_id_int := product_id::integer;

        -- Проверка, что лекарство есть в наличии
        IF EXISTS (SELECT 1 FROM лекарство WHERE ид_лекарства = product_id_int AND в_наличии = true) THEN
            -- Вставляем запись в таблицу "продажа_лекарство"
            INSERT INTO продажа_лекарство (ид_продажи, ид_лекарства)
            VALUES (sale_id, product_id_int);

            -- Обновляем столбец "в_наличии" для проданного лекарства
            UPDATE лекарство
            SET в_наличии = false
            WHERE ид_лекарства = product_id_int;
        ELSE
            -- Если лекарство не в наличии, выбрасываем ошибку с кодом P0200
            RAISE EXCEPTION USING
                ERRCODE = 'P0200',
                MESSAGE = 'Лекарство с ид ' || product_id_int || ' не в наличии';
        END IF;
    END LOOP;

    -- 3. Вычисляем сумму продажи
    SELECT SUM(цена_розничная) INTO total_sum
    FROM лекарство
    JOIN продажа_лекарство ON лекарство.ид_лекарства = продажа_лекарство.ид_лекарства
    JOIN поставка ON лекарство.ид_лекарства = поставка.ид_лекарства
    WHERE продажа_лекарство.ид_продажи = sale_id;

    -- 4. Если есть personId, вычисляем скидку
    IF person_id IS NOT NULL THEN
        SELECT скидка INTO discount
        FROM покупатель
        WHERE ид_персоны = person_id;

        -- Применяем скидку
        total_sum := total_sum - (total_sum * discount / 100);
    END IF;

    -- 5. Обновляем поле "сумма" в таблице "продажа"
    UPDATE продажа
    SET сумма = total_sum
    WHERE ид_продажи = sale_id;
END;
$$;


ALTER PROCEDURE public."создать_продажу"(IN params jsonb) OWNER TO postgres;

--
-- Name: создать_сотрудника(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."создать_сотрудника"(params jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_person_id INT;
    new_employee_id INT;
    birth_date DATE;
    result JSONB;
    position_title VARCHAR;
    access_level VARCHAR;
BEGIN
    -- Попробуем явно преобразовать дату
    birth_date := (params->>'birth_date')::date;

    -- Создаем новую запись в таблице "персона"
    INSERT INTO персона (фамилия, имя, отчество, дата_рождения, телефон)
    VALUES (
        params->>'last_name',
        params->>'first_name',
        params->>'middle_name',
        birth_date,
        params->>'phone'
    )
    RETURNING ид_персоны INTO new_person_id;

    -- Создаем новую запись в таблице "сотрудник"
    INSERT INTO сотрудник (ид_персоны, ид_должности, персональный_код, номер_паспорта, серия_паспорта, адрес)
    VALUES (
        new_person_id,
        (params->>'position')::int,
        params->>'personal_code',
        params->>'passport_number',
        params->>'passport_serial',
        params->>'address'
    )
    RETURNING ид_сотрудника INTO new_employee_id;

    -- Получаем название и уровень доступа из таблицы "должность"
    SELECT название, уровень_доступа
    INTO position_title, access_level
    FROM должность
    WHERE ид_должности = (params->>'position')::int;

    -- Формируем результат в виде JSON
    result := jsonb_build_object(
        'ид_сотрудника', new_employee_id,
        'фамилия', params->>'last_name',
        'имя', params->>'first_name',
        'отчество', params->>'middle_name',
        'дата_рождения', params->>'birth_date',
        'телефон', params->>'phone',
        'ид_должности', params->>'position',
        'персональный_код', params->>'personal_code',
        'номер_паспорта', params->>'passport_number',
        'серия_паспорта', params->>'passport_serial',
        'адрес', params->>'address',
        'название', position_title,
        'уровень_доступа', access_level
    );

    -- Возвращаем сформированный JSON
    RETURN result;
END;
$$;


ALTER FUNCTION public."создать_сотрудника"(params jsonb) OWNER TO postgres;

--
-- Name: сформировать_отчет_поставки(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."сформировать_отчет_поставки"(params jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
    начальная_дата date;
    конечная_дата date;
    query TEXT;
    result RECORD;
BEGIN
    -- Извлечение дат из входного параметра
    начальная_дата := (params ->> 'начальная_дата')::date;
    конечная_дата := (params ->> 'конечная_дата')::date;

    -- Проверка наличия необходимых параметров
    IF начальная_дата IS NULL OR конечная_дата IS NULL THEN
        RAISE EXCEPTION 'Не указана начальная или конечная дата';
    END IF;
    
    -- Проверка, что начальная дата меньше конечной даты
    IF начальная_дата >= конечная_дата THEN
        RAISE EXCEPTION 'Начальная дата должна быть меньше конечной даты';
    END IF;

    -- Формирование SQL запроса для вычисления суммы расходов за период
    query := format('
        SELECT
            пост.ид_поставщика,
            пост.название AS название_поставщика,
            пост.оптовая_цена,
            кат.название AS название_каталога,
            кат.производитель,
            SUM(пост.оптовая_цена)::public."pos_float" AS сумма_расходов
        FROM
            public.поставка AS п
        JOIN
            public.поставщик AS пост ON п.ид_поставщика = пост.ид_поставщика
        JOIN
            public.каталог AS кат ON пост.ид_каталога = кат.ид_каталога
        WHERE
            п.дата BETWEEN %L AND %L
        GROUP BY
            пост.ид_поставщика, пост.название, пост.оптовая_цена, кат.название, кат.производитель
    ', начальная_дата, конечная_дата);

    -- Выполнение запроса и возврат результатов
    FOR result IN EXECUTE query LOOP
        RETURN NEXT json_build_object(
            'ид_поставщика', result.ид_поставщика,
            'название_поставщика', result.название_поставщика,
            'оптовая_цена', result.оптовая_цена,
            'название_каталога', result.название_каталога,
            'производитель', result.производитель,
            'сумма_расходов', result.сумма_расходов
        );
    END LOOP;
END; $$;


ALTER FUNCTION public."сформировать_отчет_поставки"(params jsonb) OWNER TO postgres;

--
-- Name: сформировать_отчет_продажи(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."сформировать_отчет_продажи"(params jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
    начальная_дата date;
    конечная_дата date;
    query TEXT;
    result RECORD;
BEGIN
    -- Извлечение дат из входного параметра
    начальная_дата := (params ->> 'начальная_дата')::date;
    конечная_дата := (params ->> 'конечная_дата')::date;

    -- Проверка наличия необходимых параметров
    IF начальная_дата IS NULL OR конечная_дата IS NULL THEN
        RAISE EXCEPTION 'Не указана начальная или конечная дата';
    END IF;
    
    -- Проверка, что начальная дата меньше конечной даты
    IF начальная_дата >= конечная_дата THEN
        RAISE EXCEPTION 'Начальная дата должна быть меньше конечной даты';
    END IF;

    -- Формирование SQL запроса для получения данных о продажах
    query := format('
        SELECT
            прд.ид_продажи,
            прд.время,
            прд.сумма,
            COALESCE(CAST(пер.ид_персоны AS TEXT), ''-'') AS ид_персоны,
            COALESCE(пер.фамилия, ''-'') AS фамилия,
            COALESCE(пер.имя, ''-'') AS имя,
            COALESCE(пер.отчество, ''-'') AS отчество,
            кат.название,
            кат.производитель,
            кат.дозировка,
            кат.по_рецепту,
            лек.ид_лекарства
        FROM
            public.продажа AS прд
        LEFT JOIN
            public.персона AS пер ON прд.ид_персоны = пер.ид_персоны
        JOIN
            public.продажа_лекарство AS прд_лек ON прд.ид_продажи = прд_лек.ид_продажи
        JOIN
            public.лекарство AS лек ON прд_лек.ид_лекарства = лек.ид_лекарства
        JOIN
            public.каталог AS кат ON лек.ид_каталога = кат.ид_каталога
        WHERE
            прд.время BETWEEN %L AND %L
    ', начальная_дата, конечная_дата);

    -- Выполнение запроса и возврат результатов
    FOR result IN EXECUTE query LOOP
        RETURN NEXT json_build_object(
            'время', result.время,
            'сумма', result.сумма,
            'ид_персоны', result.ид_персоны,
            'фамилия', result.фамилия,
            'имя', result.имя,
            'отчество', result.отчество,
            'название', result.название,
            'производитель', result.производитель,
            'дозировка', result.дозировка,
            'по_рецепту', result.по_рецепту,
            'ид_лекарства', result.ид_лекарства
        );
    END LOOP;
END;
$$;


ALTER FUNCTION public."сформировать_отчет_продажи"(params jsonb) OWNER TO postgres;

--
-- Name: удалить_запись_из_таблицы(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."удалить_запись_из_таблицы"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
  query TEXT;
  key TEXT;
  value TEXT;
  tablename TEXT;
BEGIN
  -- Извлекаем имя таблицы из parameters
  tablename := params->>'tableName';
  
  -- Удаляем tableName из parameters для дальнейшей обработки
  params := params - 'tableName';

  query := 'DELETE FROM ' || tablename || ' WHERE ';

  FOR key, value IN SELECT * FROM jsonb_each_text(params)
  LOOP
    query := query || format('%I = %L AND ', key, value);
  END LOOP;

  -- Удаляем последний лишний 'AND '
  query := rtrim(query, ' AND ');

  -- Выполняем запрос
  EXECUTE query;
END;
$$;


ALTER PROCEDURE public."удалить_запись_из_таблицы"(IN params jsonb) OWNER TO postgres;

--
-- Name: удалить_клиента(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."удалить_клиента"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    client_id INT;
    person_id INT;
    person_count INT;
BEGIN
    -- Получение ид_клиента из JSON объекта
    client_id := params->>'ид_клиента';

    -- Проверка существует ли клиент с данным ид_клиента
    SELECT ид_персоны INTO person_id 
    FROM public.покупатель 
    WHERE ид_клиента = client_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Клиент с ид_клиента % не найден', client_id;
    END IF;

    -- Проверка не является ли персона сотрудником
    SELECT COUNT(*) INTO person_count 
    FROM public.сотрудник 
    WHERE ид_персоны = person_id;

    -- Удаление клиента
    DELETE FROM public.покупатель 
    WHERE ид_клиента = client_id;

    -- Если персона не является сотрудником, удаляем её
    IF person_count = 0 THEN
        DELETE FROM public.персона 
        WHERE ид_персоны = person_id;
    END IF;
    
    RAISE NOTICE 'Клиент с ид_клиента % успешно удален', client_id;
    
    IF person_count = 0 THEN 
        RAISE NOTICE 'Персона с ид_персоны % также удалена', person_id;
    ELSE 
        RAISE NOTICE 'Персона с ид_персоны % не удалена, так как является сотрудником', person_id;
    END IF;
    
END;
$$;


ALTER PROCEDURE public."удалить_клиента"(IN params jsonb) OWNER TO postgres;

--
-- Name: удалить_сотрудника(jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public."удалить_сотрудника"(IN params jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    employee_id INT;
    person_id INT;
    person_count INT;
    access_level INT;
    customer_count INT;
BEGIN
    -- Получение ид_сотрудника из JSON объекта
    employee_id := (params->>'ид_сотрудника')::int;

    -- Проверка существует ли сотрудник с данным ид_сотрудника
    SELECT ид_персоны, ид_должности INTO person_id, access_level
    FROM public.сотрудник 
    WHERE ид_сотрудника = employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Сотрудник с ид_сотрудника % не найден', employee_id;
    END IF;

    -- Проверка, является ли сотрудник администратором (ид_должности с уровнем_доступа 3)
    SELECT уровень_доступа INTO access_level
    FROM public.должность
    WHERE ид_должности = access_level;

    IF access_level = 3 THEN
        RAISE EXCEPTION 'Нельзя удалить пользователя администратора';
    END IF;

    -- Проверка не является ли персона другим сотрудником
    SELECT COUNT(*) INTO person_count 
    FROM public.сотрудник 
    WHERE ид_персоны = person_id;

    -- Удаление сотрудника
    DELETE FROM public.сотрудник 
    WHERE ид_сотрудника = employee_id;

    -- Проверка существует ли персона в таблице покупатель
    SELECT COUNT(*) INTO customer_count
    FROM public.покупатель
    WHERE ид_персоны = person_id;

    -- Если персона не является другим сотрудником и не связана с покупателем, удаляем её
    IF person_count = 1 AND customer_count = 0 THEN
        DELETE FROM public.персона 
        WHERE ид_персоны = person_id;
        RAISE NOTICE 'Персона с ид_персоны % также удалена', person_id;
    ELSE
        RAISE NOTICE 'Персона с ид_персоны % не удалена, так как связана с другими записями', person_id;
    END IF;

    RAISE NOTICE 'Сотрудник с ид_сотрудника % успешно удален', employee_id;

END;
$$;


ALTER PROCEDURE public."удалить_сотрудника"(IN params jsonb) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: покупатель; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."покупатель" (
    "ид_клиента" integer NOT NULL,
    "ид_персоны" integer,
    "скидка" public.pos_float
);


ALTER TABLE public."покупатель" OWNER TO postgres;

--
-- Name: Клиент_ид_клиента_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."покупатель" ALTER COLUMN "ид_клиента" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Клиент_ид_клиента_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 11111111
    CACHE 1
);


--
-- Name: лекарство; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."лекарство" (
    "ид_лекарства" integer NOT NULL,
    "серийный_номер" character varying NOT NULL,
    "дата_изготовления" date NOT NULL,
    "дата_окончания" date NOT NULL,
    "ид_каталога" integer NOT NULL,
    "в_наличии" boolean NOT NULL,
    CONSTRAINT "дата_проверка" CHECK (("дата_окончания" > "дата_изготовления"))
);


ALTER TABLE public."лекарство" OWNER TO postgres;

--
-- Name: Лекарство_ид_лекарства_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."лекарство" ALTER COLUMN "ид_лекарства" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Лекарство_ид_лекарства_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 11111111
    CACHE 1
);


--
-- Name: продажа; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."продажа" (
    "ид_продажи" integer NOT NULL,
    "время" timestamp without time zone NOT NULL,
    "сумма" public.pos_float,
    "ид_персоны" integer,
    "ид_смены" integer NOT NULL
);


ALTER TABLE public."продажа" OWNER TO postgres;

--
-- Name: Продажа_ид_продажи_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."продажа" ALTER COLUMN "ид_продажи" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Продажа_ид_продажи_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 11111111
    CACHE 1
);


--
-- Name: сотрудник; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."сотрудник" (
    "ид_сотрудника" integer NOT NULL,
    "ид_персоны" integer NOT NULL,
    "ид_должности" integer NOT NULL,
    "персональный_код" character varying NOT NULL,
    "ид_документа" integer NOT NULL
);


ALTER TABLE public."сотрудник" OWNER TO postgres;

--
-- Name: Сотрудник_ид_сотрудника_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."сотрудник" ALTER COLUMN "ид_сотрудника" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Сотрудник_ид_сотрудника_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 11111111
    CACHE 1
);


--
-- Name: продажа_лекарство; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."продажа_лекарство" (
    "ид_продажа_лекарство" integer NOT NULL,
    "ид_продажи" integer NOT NULL,
    "ид_лекарства" integer NOT NULL
);


ALTER TABLE public."продажа_лекарство" OWNER TO postgres;

--
-- Name: Транзакция_ид_транзакции_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."продажа_лекарство" ALTER COLUMN "ид_продажа_лекарство" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."Транзакция_ид_транзакции_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 111111111
    CACHE 1
);


--
-- Name: документ; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."документ" (
    "серия" character varying,
    "номер" character varying,
    "ид_документа" integer NOT NULL
);


ALTER TABLE public."документ" OWNER TO postgres;

--
-- Name: документ_ид_докмента_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."документ" ALTER COLUMN "ид_документа" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."документ_ид_докмента_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: должность; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."должность" (
    "ид_должности" integer NOT NULL,
    "уровень_доступа" character varying NOT NULL,
    "название" character varying NOT NULL
);


ALTER TABLE public."должность" OWNER TO postgres;

--
-- Name: должность_ид_должности_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."должность" ALTER COLUMN "ид_должности" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."должность_ид_должности_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: каталог; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."каталог" (
    "ид_каталога" integer NOT NULL,
    "название" character varying NOT NULL,
    "производитель" character varying NOT NULL,
    "по_рецепту" boolean NOT NULL,
    "дозировка" character varying NOT NULL
);


ALTER TABLE public."каталог" OWNER TO postgres;

--
-- Name: каталог_ид_каталога_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."каталог" ALTER COLUMN "ид_каталога" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."каталог_ид_каталога_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: каталог_классификация; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."каталог_классификация" (
    "ид_каталог_классификация" integer NOT NULL,
    "ид_каталога" integer NOT NULL,
    "ид_классификации" integer NOT NULL
);


ALTER TABLE public."каталог_классификация" OWNER TO postgres;

--
-- Name: каталог_классиф_ид_каталог_клас_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."каталог_классификация" ALTER COLUMN "ид_каталог_классификация" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."каталог_классиф_ид_каталог_клас_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: классификация; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."классификация" (
    "код" character varying NOT NULL,
    "ид_классификации" integer NOT NULL
);


ALTER TABLE public."классификация" OWNER TO postgres;

--
-- Name: классификация_ид_классификации_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."классификация" ALTER COLUMN "ид_классификации" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."классификация_ид_классификации_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 1111111
    CACHE 1
);


--
-- Name: персона; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."персона" (
    "ид_персоны" integer NOT NULL,
    "фамилия" character varying NOT NULL,
    "имя" character varying NOT NULL,
    "отчество" character varying NOT NULL,
    "дата_рождения" date NOT NULL,
    "телефон" public."телефон" NOT NULL
);


ALTER TABLE public."персона" OWNER TO postgres;

--
-- Name: персона_ид_персоны_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."персона" ALTER COLUMN "ид_персоны" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."персона_ид_персоны_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: поставка; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."поставка" (
    "ид_поставки" integer NOT NULL,
    "ид_поставщика" integer NOT NULL,
    "цена_розничная" public.pos_float NOT NULL,
    "ид_лекарства" integer NOT NULL,
    "дата" date NOT NULL,
    "наценка" public.pos_float NOT NULL
);


ALTER TABLE public."поставка" OWNER TO postgres;

--
-- Name: поставка_ид_поставщик_каталог_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."поставка" ALTER COLUMN "ид_поставки" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."поставка_ид_поставщик_каталог_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: поставщик; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."поставщик" (
    "ид_поставщика" integer NOT NULL,
    "ид_каталога" integer NOT NULL,
    "оптовая_цена" public.pos_float NOT NULL,
    "название" character varying NOT NULL,
    "количество" public.pos_int NOT NULL
);


ALTER TABLE public."поставщик" OWNER TO postgres;

--
-- Name: поставщик_ид_поставщика_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."поставщик" ALTER COLUMN "ид_поставщика" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."поставщик_ид_поставщика_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: смена; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."смена" (
    "ид_смены" integer NOT NULL,
    "ид_сотрудника" integer NOT NULL,
    "время_начала" timestamp without time zone NOT NULL,
    "время_конца" timestamp without time zone
);


ALTER TABLE public."смена" OWNER TO postgres;

--
-- Name: смена_ид_смены_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."смена" ALTER COLUMN "ид_смены" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."смена_ид_смены_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: документ; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."документ" ("серия", "номер", "ид_документа") FROM stdin;
АА	123456	1
ББ	234567	2
ВВ	345678	3
ГГ	456789	4
\.


--
-- Data for Name: должность; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."должность" ("ид_должности", "уровень_доступа", "название") FROM stdin;
6	3	Администратор
7	2	Менеджер
8	1	Кассир
\.


--
-- Data for Name: каталог; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."каталог" ("ид_каталога", "название", "производитель", "по_рецепту", "дозировка") FROM stdin;
19	Ципрофлоксацин	Фармакор	t	250mg
28	Метопролол	КРКА	f	500mg
24	Омепразол	Сандоз	t	500mg
20	Азитромицин	Здоровье	f	500mg
29	Нифедипин	Медокеми	f	750mg
25	Левотироксин	Мерк	t	750mg
21	Амоксициллин	Пфайзер	f	750mg
30	Лоратадин	Штада	t	1000mg
26	Метформин	Ново Нордиск	f	1000mg
22	Аспирин	Байер	t	1000mg
18	Амоксициллин	Биофабрика	f	1000mg
16	Парацетамол	Фармфабрика	t	100mg
23	Ибупрофен	Тева	f	250mg
17	Ибупрофен	Здоровье	f	750mg
\.


--
-- Data for Name: каталог_классификация; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."каталог_классификация" ("ид_каталог_классификация", "ид_каталога", "ид_классификации") FROM stdin;
\.


--
-- Data for Name: классификация; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."классификация" ("код", "ид_классификации") FROM stdin;
\.


--
-- Data for Name: лекарство; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."лекарство" ("ид_лекарства", "серийный_номер", "дата_изготовления", "дата_окончания", "ид_каталога", "в_наличии") FROM stdin;
524	77617LF	2024-05-22	2025-05-22	22	f
525	b9021NY	2024-06-07	2025-06-07	22	f
526	24eb2KG	2024-05-29	2025-05-29	22	f
527	ea1f6JU	2024-05-30	2025-05-30	22	f
528	4294bDB	2024-06-08	2025-06-08	22	f
514	ea8b6IP	2024-05-26	2025-05-26	24	f
515	7a587VI	2024-05-30	2025-05-30	24	f
529	d82e4GY	2024-06-09	2025-06-09	22	f
530	b4666YG	2024-05-27	2025-05-27	22	f
531	c3005LI	2024-05-27	2025-05-27	22	f
532	2a7fdOF	2024-06-06	2025-06-06	22	f
533	db239NE	2024-05-31	2025-05-31	22	f
534	41711KL	2024-06-04	2025-06-04	22	f
535	8eabeEQ	2024-06-08	2025-06-08	22	f
536	cbe7cTS	2024-05-30	2025-05-30	22	f
537	3d426MF	2024-06-05	2025-06-05	22	f
538	41b04IV	2024-05-31	2025-05-31	22	f
539	ad7d6QO	2024-05-22	2025-05-22	22	f
450	2b674TF	2024-06-04	2025-06-04	25	f
451	867d4ME	2024-05-31	2025-05-31	25	f
452	8a59cJE	2024-06-07	2025-06-07	25	f
453	e803aEU	2024-06-01	2025-06-01	25	f
540	cb26dHQ	2024-05-31	2025-05-31	22	f
459	5140fFY	2024-05-27	2025-05-27	25	f
454	e03d1HB	2024-06-06	2025-06-06	25	f
456	322e0BW	2024-06-04	2025-06-04	25	f
461	10b8cKN	2024-06-04	2025-06-04	25	f
462	07ac4GH	2024-06-01	2025-06-01	25	f
455	dc71fIW	2024-06-08	2025-06-08	25	f
457	24850NJ	2024-05-21	2025-05-21	25	f
458	3b12cCX	2024-06-02	2025-06-02	25	f
460	b3bdfFT	2024-05-23	2025-05-23	25	f
463	e8b8dRW	2024-05-29	2025-05-29	25	f
464	3f192GS	2024-05-28	2025-05-28	25	f
465	9c7a4BU	2024-06-07	2025-06-07	25	f
466	59b09CY	2024-05-27	2025-05-27	25	f
467	2cc5aEO	2024-06-04	2025-06-04	25	f
468	44fd5NA	2024-05-24	2025-05-24	25	f
469	5fc23IN	2024-05-22	2025-05-22	25	f
470	e6511TH	2024-06-03	2025-06-03	25	f
471	2c925MH	2024-05-25	2025-05-25	25	f
541	6d0fcKA	2024-06-01	2025-06-01	22	f
542	feb1cIL	2024-05-24	2025-05-24	22	f
543	94bccWM	2024-05-28	2025-05-28	22	f
544	6388aNK	2024-06-04	2025-06-04	22	f
545	6d358IN	2024-05-27	2025-05-27	22	f
546	be9acAS	2024-06-08	2025-06-08	22	f
547	76b08KW	2024-06-10	2025-06-10	22	f
548	383d3YG	2024-05-22	2025-05-22	22	f
549	3594cDO	2024-05-29	2025-05-29	22	f
550	3459eEC	2024-05-31	2025-05-31	22	f
551	81efcJG	2024-05-25	2025-05-25	22	f
552	9e76bUE	2024-06-07	2025-06-07	22	f
553	85be8UJ	2024-05-29	2025-05-29	22	f
554	bb91bPK	2024-05-23	2025-05-23	22	f
555	b2a61KF	2024-06-07	2025-06-07	22	f
556	e3064PH	2024-06-02	2025-06-02	22	f
557	b6ca9LB	2024-06-01	2025-06-01	22	f
558	8c7ffCG	2024-06-07	2025-06-07	22	f
559	aea30EY	2024-05-23	2025-05-23	22	f
560	d3d78MX	2024-06-03	2025-06-03	22	f
561	2defdXL	2024-05-30	2025-05-30	22	f
562	2b4b7VV	2024-06-06	2025-06-06	22	f
563	ebe79SX	2024-06-02	2025-06-02	22	f
564	dc670OF	2024-05-26	2025-05-26	22	f
708	a816aVM	2024-06-04	2025-06-04	22	f
584	c0f1cMP	2024-05-29	2025-05-29	25	f
585	c5858KX	2024-06-01	2025-06-01	25	f
586	92e38KN	2024-05-30	2025-05-30	25	f
472	995ecHE	2024-06-02	2025-06-02	19	f
473	24f20KD	2024-05-25	2025-05-25	19	f
474	f85aeYE	2024-05-28	2025-05-28	19	f
475	99602SS	2024-06-06	2025-06-06	19	f
476	fee79FB	2024-06-03	2025-06-03	19	f
477	073f8EH	2024-05-30	2025-05-30	19	f
478	a9151NK	2024-06-04	2025-06-04	19	f
479	62065PA	2024-06-05	2025-06-05	19	f
480	297c0RE	2024-05-23	2025-05-23	19	f
481	08633IJ	2024-06-08	2025-06-08	19	f
482	99e25LW	2024-06-10	2025-06-10	19	f
587	13076PH	2024-06-01	2025-06-01	25	f
582	34711IF	2024-06-01	2025-06-01	25	f
583	b1480GR	2024-06-01	2025-06-01	25	f
588	33a0eOY	2024-06-03	2025-06-03	25	f
589	aaa3bIV	2024-05-27	2025-05-27	25	f
590	ea15eAR	2024-05-23	2025-05-23	25	f
591	6668eOS	2024-06-06	2025-06-06	25	f
592	645baEH	2024-06-11	2025-06-11	25	f
483	38046NR	2024-06-08	2025-06-08	19	f
484	a63b7CR	2024-05-24	2025-05-24	19	f
485	0e900JD	2024-06-09	2025-06-09	19	f
486	34d09SB	2024-06-06	2025-06-06	19	f
493	b5f7cPX	2024-06-10	2025-06-10	19	f
495	9891dPS	2024-05-24	2025-05-24	19	f
496	cf0c3GQ	2024-06-07	2025-06-07	19	f
497	6291dHT	2024-05-25	2025-05-25	19	f
498	920f3IN	2024-06-04	2025-06-04	19	f
499	ec23bBV	2024-05-30	2025-05-30	19	f
500	70c3ePT	2024-05-30	2025-05-30	19	f
501	37c82WT	2024-05-26	2025-05-26	19	f
502	d9a9bYF	2024-05-23	2025-05-23	19	f
503	82f04HR	2024-06-09	2025-06-09	19	f
504	11bc8LK	2024-06-05	2025-06-05	19	f
505	4cfb9CL	2024-06-10	2025-06-10	19	f
506	d670eED	2024-06-02	2025-06-02	19	f
507	e0866VO	2024-05-29	2025-05-29	19	f
508	b992aDS	2024-06-05	2025-06-05	19	f
509	b7857CX	2024-06-05	2025-06-05	19	f
510	93a05OB	2024-05-30	2025-05-30	19	f
511	8b7ebXY	2024-06-08	2025-06-08	19	f
565	7338dMN	2024-06-09	2025-06-09	22	f
566	5c2aeQA	2024-05-22	2025-05-22	22	f
567	204a8WX	2024-06-03	2025-06-03	22	f
575	2a260UT	2024-05-30	2025-05-30	22	f
576	9db76GT	2024-05-23	2025-05-23	22	f
577	922f1GL	2024-05-31	2025-05-31	22	f
714	6bfebDF	2024-05-27	2025-05-27	22	t
715	38f67BC	2024-05-29	2025-05-29	22	t
487	3a347QI	2024-05-25	2025-05-25	19	f
488	63a4cBI	2024-06-09	2025-06-09	19	f
489	1af2aRJ	2024-06-05	2025-06-05	19	f
490	b8721IJ	2024-06-06	2025-06-06	19	f
491	99c2eJD	2024-05-31	2025-05-31	19	f
492	3cfe3TM	2024-06-06	2025-06-06	19	f
494	6dbd3BR	2024-06-02	2025-06-02	19	f
512	2b192LF	2024-06-09	2025-06-09	19	f
513	77ccbOL	2024-05-24	2025-05-24	19	f
516	5b938DS	2024-06-06	2025-06-06	22	f
517	88223LW	2024-06-07	2025-06-07	22	f
518	482efTK	2024-06-10	2025-06-10	22	f
519	e4a64FQ	2024-06-08	2025-06-08	22	f
520	f2651FF	2024-06-09	2025-06-09	22	f
521	c7213VD	2024-05-24	2025-05-24	22	f
522	fd930PE	2024-05-29	2025-05-29	22	f
523	12108SE	2024-06-10	2025-06-10	22	f
568	111fdRP	2024-06-02	2025-06-02	22	f
569	f3035KB	2024-06-09	2025-06-09	22	f
570	5ce56EX	2024-05-30	2025-05-30	22	f
571	66892HE	2024-06-09	2025-06-09	22	f
572	96d7aGT	2024-05-28	2025-05-28	22	f
573	181e4FY	2024-06-06	2025-06-06	22	f
574	0647aGI	2024-06-03	2025-06-03	22	f
716	02ea1UT	2024-05-28	2025-05-28	22	t
717	2404aYA	2024-06-09	2025-06-09	22	t
718	fb4d2DJ	2024-06-10	2025-06-10	22	t
719	2619bYG	2024-05-25	2025-05-25	22	t
720	dd14fPE	2024-06-03	2025-06-03	22	t
721	b1addKA	2024-06-12	2025-06-12	22	t
722	1ee26UK	2024-05-31	2025-05-31	22	t
723	b481dAO	2024-06-05	2025-06-05	22	t
724	e871fEC	2024-06-09	2025-06-09	22	t
725	488f6YK	2024-05-26	2025-05-26	22	t
726	00b64SO	2024-06-08	2025-06-08	22	t
727	b360aDM	2024-06-01	2025-06-01	22	t
728	91b3aTE	2024-05-30	2025-05-30	22	t
729	1dd1aIC	2024-06-12	2025-06-12	22	t
730	82c48UE	2024-05-26	2025-05-26	22	t
731	efc19KT	2024-05-30	2025-05-30	22	t
732	7975aLA	2024-05-25	2025-05-25	22	t
733	976d2WQ	2024-05-25	2025-05-25	22	t
734	211baRV	2024-06-11	2025-06-11	22	t
735	9305fNW	2024-05-28	2025-05-28	22	t
736	b7a81QM	2024-06-03	2025-06-03	22	t
737	a491bBO	2024-06-09	2025-06-09	22	t
738	d34b5QK	2024-05-29	2025-05-29	22	t
739	449c5SM	2024-06-02	2025-06-02	22	t
740	5aa03LJ	2024-05-25	2025-05-25	22	t
741	ea1c4HC	2024-06-01	2025-06-01	22	t
742	53f03KV	2024-06-12	2025-06-12	22	t
743	8bfa8VW	2024-06-03	2025-06-03	22	t
744	0311aBM	2024-06-10	2025-06-10	22	t
745	5149eEO	2024-05-31	2025-05-31	22	t
746	30674ON	2024-05-26	2025-05-26	22	t
747	5c01aBU	2024-06-08	2025-06-08	22	t
748	1a476EY	2024-06-05	2025-06-05	22	t
749	8d8d9JB	2024-06-12	2025-06-12	22	t
750	8b536CU	2024-06-10	2025-06-10	22	t
751	ecc3bXB	2024-06-03	2025-06-03	22	t
578	e9634NS	2024-05-24	2025-05-24	25	f
579	f5af1QL	2024-06-05	2025-06-05	25	f
580	b06a6EP	2024-06-05	2025-06-05	25	f
581	b77e9WP	2024-05-28	2025-05-28	25	f
752	1e327PM	2024-06-02	2025-06-02	22	t
753	d2b48RH	2024-06-12	2025-06-12	22	t
754	beff6JQ	2024-05-25	2025-05-25	22	t
755	ed9f2PU	2024-06-13	2025-06-13	22	t
756	54e00UP	2024-06-06	2025-06-06	22	t
712	18734KK	2024-05-30	2025-05-30	22	f
713	b7e4eOM	2024-06-09	2025-06-09	22	f
633	750b2VB	2024-05-26	2025-05-26	22	f
634	48ee6VX	2024-06-10	2025-06-10	22	f
635	a61e9YV	2024-06-02	2025-06-02	22	f
636	2517cEK	2024-06-07	2025-06-07	22	f
637	72a95YN	2024-06-03	2025-06-03	22	f
638	c0f1dUY	2024-06-02	2025-06-02	22	f
639	f9a1bLC	2024-05-24	2025-05-24	22	f
640	d9cebLL	2024-06-08	2025-06-08	22	f
641	6923eLH	2024-06-07	2025-06-07	22	f
642	84a84MQ	2024-05-26	2025-05-26	22	f
643	87a3eYF	2024-06-09	2025-06-09	22	f
644	99a21XU	2024-06-02	2025-06-02	22	f
645	9d654PO	2024-05-31	2025-05-31	22	f
646	f5273NK	2024-06-02	2025-06-02	22	f
647	27f58UR	2024-05-24	2025-05-24	22	f
648	c6a28AN	2024-05-24	2025-05-24	22	f
649	3a31bTR	2024-06-09	2025-06-09	22	f
650	7b8e0DV	2024-06-04	2025-06-04	22	f
651	f3949SS	2024-06-11	2025-06-11	22	f
652	f7a06KX	2024-06-01	2025-06-01	22	f
653	4ea1dWC	2024-06-06	2025-06-06	22	f
654	a10d3HX	2024-06-09	2025-06-09	22	f
655	df73cTD	2024-06-07	2025-06-07	22	f
656	842bbPL	2024-06-02	2025-06-02	22	f
657	f4de2PE	2024-06-02	2025-06-02	22	f
658	5190cKF	2024-05-31	2025-05-31	22	f
659	b1d5bYM	2024-06-04	2025-06-04	22	f
660	d8615JB	2024-05-25	2025-05-25	22	f
661	6ff4eVI	2024-06-12	2025-06-12	22	f
662	8ef28XU	2024-06-05	2025-06-05	22	f
663	9905bKN	2024-06-08	2025-06-08	22	f
664	d9c1aQA	2024-05-26	2025-05-26	22	f
665	44242YN	2024-06-12	2025-06-12	22	f
666	0e1c5EH	2024-05-24	2025-05-24	22	f
667	123a8EG	2024-06-08	2025-06-08	22	f
668	54985BK	2024-05-26	2025-05-26	22	f
669	e90d1IM	2024-05-28	2025-05-28	22	f
670	f61acEX	2024-05-31	2025-05-31	22	f
757	f4f04FN	2024-05-30	2025-05-30	22	t
758	f94e9OJ	2024-06-06	2025-06-06	22	t
763	95c3dXV	2024-06-01	2025-06-01	22	t
764	d35d5FG	2024-06-01	2025-06-01	22	t
698	30bf4JV	2024-06-13	2025-06-13	17	f
705	2926eJQ	2024-05-31	2025-05-31	22	f
706	408cdHI	2024-06-02	2025-06-02	22	f
707	2f08fPU	2024-05-26	2025-05-26	22	f
759	89c54PK	2024-06-04	2025-06-04	22	f
760	85ad9IT	2024-06-11	2025-06-11	22	f
593	1ba05HF	2024-06-10	2025-06-10	25	f
594	cbac5PK	2024-05-31	2025-05-31	25	f
595	3aa18NQ	2024-05-26	2025-05-26	25	f
596	54ee3VK	2024-05-23	2025-05-23	25	f
597	76be3YM	2024-05-24	2025-05-24	25	f
598	84ab0HV	2024-05-30	2025-05-30	25	f
599	f2642UF	2024-05-27	2025-05-27	25	f
600	ff9faCA	2024-06-08	2025-06-08	25	f
601	fda78NG	2024-05-29	2025-05-29	25	f
602	63d38EQ	2024-05-25	2025-05-25	25	f
603	1d108SR	2024-06-01	2025-06-01	25	f
604	12a91LP	2024-05-29	2025-05-29	25	f
605	0754aJG	2024-05-27	2025-05-27	25	f
606	80971HB	2024-05-29	2025-05-29	25	f
607	0a34cPF	2024-05-29	2025-05-29	25	f
608	877e2MY	2024-06-02	2025-06-02	25	f
609	c04b5BQ	2024-06-07	2025-06-07	25	f
610	d248fMR	2024-05-23	2025-05-23	25	f
611	ac46aQJ	2024-06-02	2025-06-02	25	f
612	d36f0QR	2024-06-10	2025-06-10	25	f
613	4aac0LI	2024-06-09	2025-06-09	25	f
614	59bb3CC	2024-05-28	2025-05-28	25	f
615	bc32bVM	2024-05-27	2025-05-27	25	f
616	91b73FM	2024-06-03	2025-06-03	25	f
617	a799fWY	2024-06-10	2025-06-10	25	f
618	1f0a6IF	2024-05-31	2025-05-31	25	f
619	06993GL	2024-06-04	2025-06-04	25	f
620	0d967GR	2024-06-01	2025-06-01	25	f
621	f9696CJ	2024-05-26	2025-05-26	25	f
622	81576PS	2024-05-24	2025-05-24	25	f
623	11eb4RO	2024-06-02	2025-06-02	25	f
624	3ac86LC	2024-05-28	2025-05-28	25	f
625	733e2CK	2024-06-09	2025-06-09	25	f
626	b5da8EF	2024-06-01	2025-06-01	25	f
627	d1e41WT	2024-05-31	2025-05-31	25	f
628	eeb31RQ	2024-05-31	2025-05-31	25	f
629	375e3VN	2024-05-25	2025-05-25	25	f
630	37ce1NT	2024-05-30	2025-05-30	25	f
631	4f91aOR	2024-05-23	2025-05-23	25	f
632	01d3dMW	2024-05-26	2025-05-26	25	f
671	c3a59XV	2024-05-26	2025-05-26	22	f
672	e8072OT	2024-05-24	2025-05-24	22	f
673	7c548RC	2024-05-26	2025-05-26	22	f
674	38bd4FA	2024-06-11	2025-06-11	22	f
675	e5c47LC	2024-06-11	2025-06-11	22	f
676	a5d04LF	2024-06-10	2025-06-10	22	f
677	0a3ffWQ	2024-05-27	2025-05-27	22	f
678	f4616RI	2024-05-31	2025-05-31	22	f
679	d7b68UD	2024-05-24	2025-05-24	22	f
680	8ac82WO	2024-06-07	2025-06-07	22	f
681	b6c49QR	2024-06-08	2025-06-08	22	f
682	1b294ES	2024-06-02	2025-06-02	22	f
683	f37a6WS	2024-06-07	2025-06-07	22	f
684	8cc00HG	2024-05-24	2025-05-24	22	f
685	e77d5DO	2024-06-12	2025-06-12	22	f
686	ff18cJS	2024-05-29	2025-05-29	22	f
687	74c21NM	2024-06-11	2025-06-11	22	f
688	f7b7cVF	2024-06-07	2025-06-07	22	f
689	69f2aAE	2024-06-11	2025-06-11	22	f
690	44be0AM	2024-05-29	2025-05-29	22	f
691	ed7aaLJ	2024-05-29	2025-05-29	22	f
692	fecb0EV	2024-06-06	2025-06-06	22	f
693	dbbf0KO	2024-06-09	2025-06-09	22	f
761	f50d3CE	2024-05-30	2025-05-30	22	f
762	deb0cRM	2024-05-25	2025-05-25	22	f
694	e31c9MG	2024-05-26	2025-05-26	17	f
695	c84d7AA	2024-05-28	2025-05-28	17	f
696	f6045HR	2024-06-03	2025-06-03	17	f
697	677b6KX	2024-06-03	2025-06-03	17	f
709	1e2f7XM	2024-06-05	2025-06-05	22	f
710	b0e71QI	2024-05-29	2025-05-29	22	f
711	c7e41RC	2024-06-03	2025-06-03	22	f
700	7b74bFA	2024-06-06	2025-06-06	17	f
701	a6794KS	2024-05-30	2025-05-30	17	f
702	19953TO	2024-05-27	2025-05-27	17	f
703	3bbc0YX	2024-06-05	2025-06-05	17	f
704	c67ddGU	2024-05-29	2025-05-29	17	f
765	68c0bLO	2024-05-28	2025-05-28	19	t
766	0332fOK	2024-06-12	2025-06-12	19	t
767	a3b8aPW	2024-05-26	2025-05-26	19	t
768	9646fVL	2024-06-13	2025-06-13	19	t
769	c6c4eWV	2024-06-07	2025-06-07	19	t
770	83c2fYW	2024-06-07	2025-06-07	19	t
771	796d9CP	2024-06-11	2025-06-11	19	t
772	0af2eDY	2024-06-09	2025-06-09	19	t
773	a19d8FS	2024-06-06	2025-06-06	19	t
774	591caHJ	2024-06-05	2025-06-05	19	t
775	b9eb9IM	2024-06-04	2025-06-04	19	t
776	06369PR	2024-05-28	2025-05-28	19	t
777	9e8a6DN	2024-06-12	2025-06-12	19	t
778	84574WU	2024-06-13	2025-06-13	19	t
779	82b56GX	2024-06-13	2025-06-13	19	t
780	18f8aYI	2024-06-01	2025-06-01	19	t
781	282fcSJ	2024-06-07	2025-06-07	19	t
782	2fc2eGD	2024-06-13	2025-06-13	19	t
783	9128bAO	2024-06-06	2025-06-06	19	t
784	ee9a5YE	2024-06-06	2025-06-06	19	t
785	ed604CN	2024-06-05	2025-06-05	19	t
786	54540AL	2024-06-05	2025-06-05	19	t
787	0c4fdPK	2024-06-08	2025-06-08	19	t
788	f5babER	2024-06-02	2025-06-02	19	t
790	77617LF	2024-05-22	2025-05-22	22	t
\.


--
-- Data for Name: персона; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."персона" ("ид_персоны", "фамилия", "имя", "отчество", "дата_рождения", "телефон") FROM stdin;
11	Иванов	Иван	Иванович	1980-01-01	+79991234567
12	Петров	Петр	Петрович	1985-02-14	+79992345678
13	Сидоров	Сидор	Сидорович	1990-03-25	+79993456789
14	Михайлов	Михаил	Михайлович	1995-04-10	+79994567890
15	Кузнецов	Алексей	Алексеевич	2000-05-20	+79995678901
16	Иванов	Иван	Иванович	1980-01-15	+79111234567
17	Петров	Петр	Петрович	1985-05-25	+79122345678
18	Сидоров	Сидор	Сидорович	1990-03-10	+79133456789
19	Смирнова	Анна	Викторовна	1992-12-01	+79144567890
20	Кузнецов	Максим	Александрович	1977-07-07	+79155678901
21	Попова	Мария	Игоревна	1983-09-18	+79166789012
22	Васильев	Дмитрий	Сергеевич	1988-11-30	+79177890123
23	Орлова	Екатерина	Андреевна	1991-02-14	+79188901234
24	Морозов	Алексей	Николаевич	1975-04-27	+79199012345
25	Зайцева	Людмила	Федоровна	1969-08-19	+79200123456
26	Григорьев	Николай	Евгеньевич	1984-06-06	+79211234567
27	Соловьев	Анатолий	Михайлович	1973-03-03	+79222345678
28	Степанова	Елена	Павловна	1986-10-20	+79233456789
29	Федоров	Андрей	Владимирович	1994-01-11	+79244567890
30	Максимова	Ольга	Романовна	1997-05-22	+79255678901
31	Никитина	Юлия	Константиновна	1981-12-08	+79266789012
32	Михайлов	Сергей	Петрович	1972-09-09	+79277890123
33	Ковалева	Вера	Алексеевна	1993-03-30	+79288901234
34	Егорова	Татьяна	Григорьевна	1987-11-15	+79299012345
35	Лебедев	Владимир	Ильич	1974-07-21	+79300123456
36	Козлов	Артем	Валентинович	1982-04-05	+79311234567
37	Новикова	Ирина	Семеновна	1989-05-15	+79322345678
38	Фролова	Лидия	Матвеевна	1976-08-25	+79333456789
39	Беляев	Роман	Филиппович	1995-09-14	+79344567890
40	Демидова	Оксана	Игоревна	1981-11-21	+79355678901
41	Гусев	Павел	Аркадьевич	1980-03-03	+79366789012
42	Павлова	Валентина	Сергеевна	1992-05-30	+79377890123
43	Исаков	Леонид	Егорович	1978-10-02	+79388901234
44	Тихомирова	Диана	Юрьевна	1991-12-19	+79399012345
45	Осипов	Георгий	Михайлович	1984-07-22	+79400123456
46	Рябова	Галина	Никитична	1970-08-09	+79411234567
47	Борисова	Елена	Станиславовна	1987-03-15	+79422345678
48	Миронова	Евгения	Альбертовна	1973-06-18	+79433456789
49	Федотов	Владислав	Павлович	1990-09-27	+79444567890
50	Борисов	Евгений	Рудольфович	1982-10-05	+79455678901
51	Жукова	Марина	Ивановна	1985-04-12	+79466789012
52	Макаров	Петр	Львович	1979-01-30	+79477890123
53	Волкова	Оксана	Мироновна	1993-11-11	+79488901234
54	Киселев	Илья	Олегович	1988-12-20	+79499012345
\.


--
-- Data for Name: покупатель; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."покупатель" ("ид_клиента", "ид_персоны", "скидка") FROM stdin;
43	11	5
44	12	10
45	14	10
46	15	15
47	16	20
48	17	25
49	18	30
50	19	35
51	20	5
52	21	10
53	22	15
54	23	20
55	24	25
56	25	30
57	26	35
58	27	5
59	28	10
60	29	15
61	30	20
62	31	25
63	32	30
64	33	35
65	34	5
66	35	10
67	36	15
68	37	20
69	38	25
70	39	30
71	40	35
72	41	5
73	42	10
74	43	15
75	44	20
76	45	25
77	46	30
78	47	35
79	48	5
80	49	10
81	50	15
82	51	20
83	52	25
84	53	30
85	54	35
91	13	12
\.


--
-- Data for Name: поставка; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."поставка" ("ид_поставки", "ид_поставщика", "цена_розничная", "ид_лекарства", "дата", "наценка") FROM stdin;
294	10	145.2	450	2024-05-31	32
295	10	145.2	451	2024-05-31	32
296	10	145.2	452	2024-05-31	32
297	10	145.2	453	2024-05-31	32
298	10	145.2	454	2024-05-31	32
299	10	145.2	455	2024-05-31	32
300	10	145.2	456	2024-05-31	32
301	10	145.2	457	2024-05-31	32
302	10	145.2	458	2024-05-31	32
303	10	145.2	459	2024-05-31	32
304	10	145.2	460	2024-05-31	32
305	10	145.2	461	2024-05-31	32
306	10	145.2	462	2024-05-31	32
307	10	145.2	463	2024-05-31	32
308	10	145.2	464	2024-05-31	32
309	10	145.2	465	2024-05-31	32
310	10	145.2	466	2024-05-31	32
311	10	145.2	467	2024-05-31	32
312	10	145.2	468	2024-05-31	32
313	10	145.2	469	2024-05-31	32
314	10	145.2	470	2024-05-31	32
315	10	145.2	471	2024-05-31	32
316	4	58.44	472	2024-06-01	29
317	4	58.44	473	2024-06-01	29
318	4	58.44	474	2024-06-01	29
319	4	58.44	475	2024-06-01	29
320	4	58.44	476	2024-06-01	29
321	4	58.44	477	2024-06-01	29
322	4	58.44	478	2024-06-01	29
323	4	58.44	479	2024-06-01	29
324	4	58.44	480	2024-06-01	29
325	4	58.44	481	2024-06-01	29
326	4	58.44	482	2024-06-01	29
327	4	58.44	483	2024-06-01	29
328	4	58.44	484	2024-06-01	29
329	4	58.44	485	2024-06-01	29
330	4	58.44	486	2024-06-01	29
331	4	58.44	487	2024-06-01	29
332	4	58.44	488	2024-06-01	29
333	4	58.44	489	2024-06-01	29
334	4	58.44	490	2024-06-01	29
335	4	58.44	491	2024-06-01	29
336	4	58.44	492	2024-06-01	29
337	4	58.44	493	2024-06-01	29
338	4	58.44	494	2024-06-01	29
339	4	58.44	495	2024-06-01	29
340	4	58.44	496	2024-06-01	29
341	4	58.44	497	2024-06-01	29
342	4	58.44	498	2024-06-01	29
343	4	58.44	499	2024-06-01	29
344	4	58.44	500	2024-06-01	29
345	4	58.44	501	2024-06-01	29
346	4	58.44	502	2024-06-01	29
347	4	58.44	503	2024-06-01	29
348	4	58.44	504	2024-06-01	29
349	4	58.44	505	2024-06-01	29
350	4	58.44	506	2024-06-01	29
351	4	58.44	507	2024-06-01	29
352	4	58.44	508	2024-06-01	29
353	4	58.44	509	2024-06-01	29
354	4	58.44	510	2024-06-01	29
355	4	58.44	511	2024-06-01	29
356	4	58.44	512	2024-06-01	29
357	4	58.44	513	2024-06-01	29
358	9	469.5	514	2024-06-01	424
359	9	469.5	515	2024-06-01	424
360	7	121.99	516	2024-06-01	22
361	7	121.99	517	2024-06-01	22
362	7	121.99	518	2024-06-01	22
363	7	121.99	519	2024-06-01	22
364	7	121.99	520	2024-06-01	22
365	7	121.99	521	2024-06-01	22
366	7	121.99	522	2024-06-01	22
367	7	121.99	523	2024-06-01	22
368	7	121.99	524	2024-06-01	22
369	7	121.99	525	2024-06-01	22
370	7	121.99	526	2024-06-01	22
371	7	121.99	527	2024-06-01	22
372	7	121.99	528	2024-06-01	22
373	7	121.99	529	2024-06-01	22
374	7	121.99	530	2024-06-01	22
375	7	121.99	531	2024-06-01	22
376	7	121.99	532	2024-06-01	22
377	7	121.99	533	2024-06-01	22
378	7	121.99	534	2024-06-01	22
379	7	121.99	535	2024-06-01	22
380	7	121.99	536	2024-06-01	22
381	7	121.99	537	2024-06-01	22
382	7	121.99	538	2024-06-01	22
383	7	121.99	539	2024-06-01	22
384	7	121.99	540	2024-06-01	22
385	7	121.99	541	2024-06-01	22
386	7	121.99	542	2024-06-01	22
387	7	121.99	543	2024-06-01	22
388	7	121.99	544	2024-06-01	22
389	7	121.99	545	2024-06-01	22
390	7	121.99	546	2024-06-01	22
391	7	121.99	547	2024-06-01	22
392	7	121.99	548	2024-06-01	22
393	7	121.99	549	2024-06-01	22
394	7	121.99	550	2024-06-01	22
395	7	121.99	551	2024-06-01	22
396	7	121.99	552	2024-06-01	22
397	7	121.99	553	2024-06-01	22
398	7	121.99	554	2024-06-01	22
399	7	121.99	555	2024-06-01	22
400	7	121.99	556	2024-06-01	22
401	7	121.99	557	2024-06-01	22
402	7	121.99	558	2024-06-01	22
403	7	121.99	559	2024-06-01	22
404	7	121.99	560	2024-06-01	22
405	7	121.99	561	2024-06-01	22
406	7	121.99	562	2024-06-01	22
407	7	121.99	563	2024-06-01	22
408	7	121.99	564	2024-06-01	22
409	7	121.99	565	2024-06-01	22
410	7	121.99	566	2024-06-01	22
411	7	121.99	567	2024-06-01	22
412	7	121.99	568	2024-06-01	22
413	7	121.99	569	2024-06-01	22
414	7	121.99	570	2024-06-01	22
415	7	121.99	571	2024-06-01	22
416	7	121.99	572	2024-06-01	22
417	7	121.99	573	2024-06-01	22
418	7	121.99	574	2024-06-01	22
419	7	121.99	575	2024-06-01	22
420	7	121.99	576	2024-06-01	22
421	7	121.99	577	2024-06-01	22
422	10	167.2	578	2024-06-02	52
423	10	167.2	579	2024-06-02	52
424	10	167.2	580	2024-06-02	52
425	10	167.2	581	2024-06-02	52
426	10	167.2	582	2024-06-02	52
427	10	167.2	583	2024-06-02	52
428	10	167.2	584	2024-06-02	52
429	10	167.2	585	2024-06-02	52
430	10	167.2	586	2024-06-02	52
431	10	167.2	587	2024-06-02	52
432	10	167.2	588	2024-06-02	52
433	10	167.2	589	2024-06-02	52
434	10	167.2	590	2024-06-02	52
435	10	167.2	591	2024-06-02	52
436	10	167.2	592	2024-06-02	52
437	10	167.2	593	2024-06-02	52
438	10	167.2	594	2024-06-02	52
439	10	167.2	595	2024-06-02	52
440	10	167.2	596	2024-06-02	52
441	10	167.2	597	2024-06-02	52
442	10	167.2	598	2024-06-02	52
443	10	167.2	599	2024-06-02	52
444	10	167.2	600	2024-06-02	52
445	10	167.2	601	2024-06-02	52
446	10	167.2	602	2024-06-02	52
447	10	167.2	603	2024-06-02	52
448	10	167.2	604	2024-06-02	52
449	10	167.2	605	2024-06-02	52
450	10	167.2	606	2024-06-02	52
451	10	167.2	607	2024-06-02	52
452	10	167.2	608	2024-06-02	52
453	10	167.2	609	2024-06-02	52
454	10	167.2	610	2024-06-02	52
455	10	167.2	611	2024-06-02	52
456	10	167.2	612	2024-06-02	52
457	10	167.2	613	2024-06-02	52
458	10	167.2	614	2024-06-02	52
459	10	167.2	615	2024-06-02	52
460	10	167.2	616	2024-06-02	52
461	10	167.2	617	2024-06-02	52
462	10	167.2	618	2024-06-02	52
463	10	167.2	619	2024-06-02	52
464	10	167.2	620	2024-06-02	52
465	10	167.2	621	2024-06-02	52
466	10	167.2	622	2024-06-02	52
467	10	167.2	623	2024-06-02	52
468	10	167.2	624	2024-06-02	52
469	10	167.2	625	2024-06-02	52
470	10	167.2	626	2024-06-02	52
471	10	167.2	627	2024-06-02	52
472	10	167.2	628	2024-06-02	52
473	10	167.2	629	2024-06-02	52
474	10	167.2	630	2024-06-02	52
475	10	167.2	631	2024-06-02	52
476	10	167.2	632	2024-06-02	52
477	7	106.99	633	2024-06-03	7
478	7	106.99	634	2024-06-03	7
479	7	106.99	635	2024-06-03	7
480	7	106.99	636	2024-06-03	7
481	7	106.99	637	2024-06-03	7
482	7	106.99	638	2024-06-03	7
483	7	106.99	639	2024-06-03	7
484	7	106.99	640	2024-06-03	7
485	7	106.99	641	2024-06-03	7
486	7	106.99	642	2024-06-03	7
487	7	106.99	643	2024-06-03	7
488	7	106.99	644	2024-06-03	7
489	7	106.99	645	2024-06-03	7
490	7	106.99	646	2024-06-03	7
491	7	106.99	647	2024-06-03	7
492	7	106.99	648	2024-06-03	7
493	7	106.99	649	2024-06-03	7
494	7	106.99	650	2024-06-03	7
495	7	106.99	651	2024-06-03	7
496	7	106.99	652	2024-06-03	7
497	7	106.99	653	2024-06-03	7
498	7	106.99	654	2024-06-03	7
499	7	106.99	655	2024-06-03	7
500	7	106.99	656	2024-06-03	7
501	7	106.99	657	2024-06-03	7
502	7	106.99	658	2024-06-03	7
503	7	106.99	659	2024-06-03	7
504	7	106.99	660	2024-06-03	7
505	7	106.99	661	2024-06-03	7
506	7	106.99	662	2024-06-03	7
507	7	106.99	663	2024-06-03	7
508	7	106.99	664	2024-06-03	7
509	7	106.99	665	2024-06-03	7
510	7	106.99	666	2024-06-03	7
511	7	106.99	667	2024-06-03	7
512	7	106.99	668	2024-06-03	7
513	7	106.99	669	2024-06-03	7
514	7	106.99	670	2024-06-03	7
515	7	106.99	671	2024-06-03	7
516	7	106.99	672	2024-06-03	7
517	7	106.99	673	2024-06-03	7
518	7	106.99	674	2024-06-03	7
519	7	106.99	675	2024-06-03	7
520	7	106.99	676	2024-06-03	7
521	7	106.99	677	2024-06-03	7
522	7	106.99	678	2024-06-03	7
523	7	106.99	679	2024-06-03	7
524	7	106.99	680	2024-06-03	7
525	7	106.99	681	2024-06-03	7
526	7	106.99	682	2024-06-03	7
527	7	106.99	683	2024-06-03	7
528	7	106.99	684	2024-06-03	7
529	7	106.99	685	2024-06-03	7
530	7	106.99	686	2024-06-03	7
531	7	106.99	687	2024-06-03	7
532	7	106.99	688	2024-06-03	7
533	7	106.99	689	2024-06-03	7
534	7	106.99	690	2024-06-03	7
535	7	106.99	691	2024-06-03	7
536	7	106.99	692	2024-06-03	7
537	7	106.99	693	2024-06-03	7
538	2	82.16	694	2024-06-04	4
539	2	82.16	695	2024-06-04	4
540	2	82.16	696	2024-06-04	4
541	2	82.16	697	2024-06-04	4
542	2	82.16	698	2024-06-04	4
544	2	82.95	700	2024-06-04	5
545	2	82.95	701	2024-06-04	5
546	2	82.95	702	2024-06-04	5
547	2	82.95	703	2024-06-04	5
548	2	82.95	704	2024-06-04	5
549	7	321.97	705	2024-06-04	222
550	7	321.97	706	2024-06-04	222
551	7	321.97	707	2024-06-04	222
552	7	321.97	708	2024-06-04	222
553	7	321.97	709	2024-06-04	222
554	7	321.97	710	2024-06-04	222
555	7	321.97	711	2024-06-04	222
556	7	321.97	712	2024-06-04	222
557	7	321.97	713	2024-06-04	222
558	7	321.97	714	2024-06-04	222
559	7	321.97	715	2024-06-04	222
560	7	321.97	716	2024-06-04	222
561	7	321.97	717	2024-06-04	222
562	7	321.97	718	2024-06-04	222
563	7	321.97	719	2024-06-04	222
564	7	321.97	720	2024-06-04	222
565	7	321.97	721	2024-06-04	222
566	7	321.97	722	2024-06-04	222
567	7	321.97	723	2024-06-04	222
568	7	321.97	724	2024-06-04	222
569	7	321.97	725	2024-06-04	222
570	7	321.97	726	2024-06-04	222
571	7	321.97	727	2024-06-04	222
572	7	321.97	728	2024-06-04	222
573	7	321.97	729	2024-06-04	222
574	7	321.97	730	2024-06-04	222
575	7	321.97	731	2024-06-04	222
576	7	321.97	732	2024-06-04	222
577	7	321.97	733	2024-06-04	222
578	7	321.97	734	2024-06-04	222
579	7	321.97	735	2024-06-04	222
580	7	321.97	736	2024-06-04	222
581	7	321.97	737	2024-06-04	222
582	7	321.97	738	2024-06-04	222
583	7	321.97	739	2024-06-04	222
584	7	321.97	740	2024-06-04	222
585	7	321.97	741	2024-06-04	222
586	7	321.97	742	2024-06-04	222
587	7	321.97	743	2024-06-04	222
588	7	321.97	744	2024-06-04	222
589	7	321.97	745	2024-06-04	222
590	7	321.97	746	2024-06-04	222
591	7	321.97	747	2024-06-04	222
592	7	321.97	748	2024-06-04	222
593	7	321.97	749	2024-06-04	222
594	7	321.97	750	2024-06-04	222
595	7	321.97	751	2024-06-04	222
596	7	321.97	752	2024-06-04	222
597	7	321.97	753	2024-06-04	222
598	7	321.97	754	2024-06-04	222
599	7	321.97	755	2024-06-04	222
600	7	321.97	756	2024-06-04	222
601	7	321.97	757	2024-06-04	222
602	7	321.97	758	2024-06-04	222
603	7	321.97	759	2024-06-04	222
604	7	321.97	760	2024-06-04	222
605	7	321.97	761	2024-06-04	222
606	7	321.97	762	2024-06-04	222
607	7	321.97	763	2024-06-04	222
608	7	321.97	764	2024-06-04	222
609	4	51.19	765	2024-06-04	13
610	4	51.19	766	2024-06-04	13
611	4	51.19	767	2024-06-04	13
612	4	51.19	768	2024-06-04	13
613	4	51.19	769	2024-06-04	13
614	4	51.19	770	2024-06-04	13
615	4	51.19	771	2024-06-04	13
616	4	51.19	772	2024-06-04	13
617	4	51.19	773	2024-06-04	13
618	4	51.19	774	2024-06-04	13
619	4	51.19	775	2024-06-04	13
620	4	51.19	776	2024-06-04	13
621	4	51.19	777	2024-06-04	13
622	4	51.19	778	2024-06-04	13
623	4	51.19	779	2024-06-04	13
624	4	51.19	780	2024-06-04	13
625	4	51.19	781	2024-06-04	13
626	4	51.19	782	2024-06-04	13
627	4	51.19	783	2024-06-04	13
628	4	51.19	784	2024-06-04	13
629	4	51.19	785	2024-06-04	13
630	4	51.19	786	2024-06-04	13
631	4	51.19	787	2024-06-04	13
632	4	51.19	788	2024-06-04	13
\.


--
-- Data for Name: поставщик; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."поставщик" ("ид_поставщика", "ид_каталога", "оптовая_цена", "название", "количество") FROM stdin;
1	16	99.99	ООО "Продукт-Сервис"	4
2	17	79	ИП Иванов Петр Николаевич	5
3	18	120.5	ЗАО "Глобал Трейд"	6
4	19	45.3	ООО "Фрукты и Овощи"	77
5	20	200	ИП Смирнов Алексей Викторович	52
6	21	150.75	ООО "Российские Продукты"	3
7	22	99.99	ОАО "ТоргСервис"	62
8	23	34.99	ООО "ЭкоПоставка"	44
9	24	89.6	ИП Кузнецова Мария Сергеевна	643
10	25	110	ЗАО "Поставка Плюс"	55
\.


--
-- Data for Name: продажа; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."продажа" ("ид_продажи", "время", "сумма", "ид_персоны", "ид_смены") FROM stdin;
62	2024-06-03 21:30:34	668.8	\N	178
63	2024-06-04 15:27:49	6688.0	\N	216
64	2024-06-04 15:27:55	501.6	\N	216
65	2024-06-04 15:28:41	5873.751	14	216
66	2024-06-04 17:59:23	82.16	\N	228
67	2024-06-04 17:59:39	724.4325	17	228
68	2024-06-04 17:59:54	1287.88	\N	228
69	2024-06-04 17:59:59	164.32	\N	228
70	2024-06-04 18:00:07	1130.23	\N	228
71	2024-06-04 18:08:09	1104.528	16	229
73	2024-06-04 20:46:43	1000.50	11	44
\.


--
-- Data for Name: продажа_лекарство; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."продажа_лекарство" ("ид_продажа_лекарство", "ид_продажи", "ид_лекарства") FROM stdin;
179	62	582
180	62	583
181	62	588
182	62	589
183	63	593
184	63	594
185	63	595
186	63	596
187	63	597
188	63	598
189	63	599
190	63	600
191	63	601
192	63	602
193	63	603
194	63	604
195	63	605
196	63	606
197	63	607
198	63	608
199	63	609
200	63	610
201	63	611
202	63	612
203	63	613
204	63	614
205	63	615
206	63	616
207	63	617
208	63	618
209	63	619
210	63	620
211	63	621
212	63	622
213	63	623
214	63	624
215	63	625
216	63	626
217	63	627
218	63	628
219	63	629
220	63	630
221	63	631
222	63	632
223	64	590
224	64	591
225	64	592
226	65	633
227	65	634
228	65	635
229	65	636
230	65	637
231	65	638
232	65	639
233	65	640
234	65	641
235	65	642
236	65	643
237	65	644
238	65	645
239	65	646
240	65	647
241	65	648
242	65	649
243	65	650
244	65	651
245	65	652
246	65	653
247	65	654
248	65	655
249	65	656
250	65	657
251	65	658
252	65	659
253	65	660
254	65	661
255	65	662
256	65	663
257	65	664
258	65	665
259	65	666
260	65	667
261	65	668
262	65	669
263	65	670
264	65	671
265	65	672
266	65	673
267	65	674
268	65	675
269	65	676
270	65	677
271	65	678
272	65	679
273	65	680
274	65	681
275	65	682
276	65	683
277	65	684
278	65	685
279	65	686
280	65	687
281	65	688
282	65	689
283	65	690
284	65	691
285	65	692
286	65	693
287	66	698
288	67	705
289	67	706
290	67	707
291	68	759
292	68	760
293	68	761
294	68	762
295	69	694
296	69	695
297	70	696
298	70	697
299	70	709
300	70	710
301	70	711
302	71	700
303	71	701
304	71	702
305	71	703
306	71	704
307	71	708
308	71	712
309	71	713
\.


--
-- Data for Name: смена; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."смена" ("ид_смены", "ид_сотрудника", "время_начала", "время_конца") FROM stdin;
44	40	2024-05-31 21:44:35	\N
45	40	2024-05-31 21:45:49	\N
46	40	2024-06-01 14:40:47	\N
47	40	2024-06-01 14:46:03	\N
48	40	2024-06-01 14:47:57	\N
49	40	2024-06-01 14:48:56	\N
50	40	2024-06-01 14:50:01	\N
51	40	2024-06-01 15:11:17	\N
52	40	2024-06-01 15:12:00	\N
53	40	2024-06-01 15:17:50	\N
54	40	2024-06-01 15:19:30	\N
55	40	2024-06-01 15:20:32	\N
56	40	2024-06-01 15:22:21	\N
57	40	2024-06-01 15:24:00	\N
58	40	2024-06-01 15:27:04	\N
59	40	2024-06-01 15:28:07	\N
60	40	2024-06-01 15:37:03	\N
61	40	2024-06-01 15:38:43	\N
62	40	2024-06-01 16:17:30	\N
63	40	2024-06-01 16:19:49	\N
64	40	2024-06-01 16:22:41	\N
65	40	2024-06-01 17:20:47	\N
66	40	2024-06-01 17:32:25	\N
67	40	2024-06-01 17:32:42	\N
68	40	2024-06-01 17:34:55	\N
69	40	2024-06-01 17:36:55	\N
70	40	2024-06-01 17:37:56	\N
71	40	2024-06-01 17:43:15	\N
72	40	2024-06-01 17:43:53	\N
73	40	2024-06-01 17:46:23	\N
74	40	2024-06-01 17:47:11	\N
75	40	2024-06-01 17:51:46	\N
76	40	2024-06-01 18:17:38	\N
77	40	2024-06-01 18:21:43	\N
78	40	2024-06-01 18:22:59	\N
79	40	2024-06-01 18:25:43	\N
80	40	2024-06-01 18:27:58	\N
81	40	2024-06-01 18:54:46	\N
82	40	2024-06-01 18:55:23	\N
83	40	2024-06-01 18:56:31	\N
84	40	2024-06-01 18:57:45	\N
85	40	2024-06-01 19:01:50	\N
86	40	2024-06-01 19:02:22	\N
87	40	2024-06-01 19:03:56	\N
88	40	2024-06-01 19:05:08	\N
89	40	2024-06-01 19:07:59	\N
90	40	2024-06-01 19:09:17	\N
91	40	2024-06-01 19:09:33	\N
92	40	2024-06-01 19:10:21	\N
93	40	2024-06-01 19:15:21	\N
94	40	2024-06-01 19:16:22	\N
95	40	2024-06-01 20:07:49	\N
96	40	2024-06-01 20:09:10	\N
97	40	2024-06-01 20:09:25	\N
98	40	2024-06-01 20:10:07	\N
99	40	2024-06-01 20:11:04	\N
100	40	2024-06-01 20:11:17	\N
101	40	2024-06-01 20:12:32	\N
102	40	2024-06-01 20:15:30	\N
103	40	2024-06-01 20:16:04	\N
104	40	2024-06-01 20:16:54	\N
105	40	2024-06-01 20:17:11	\N
106	40	2024-06-01 20:17:43	\N
107	40	2024-06-01 20:18:02	\N
108	40	2024-06-01 20:18:57	\N
109	40	2024-06-01 20:20:24	\N
110	40	2024-06-01 20:34:49	\N
111	40	2024-06-01 20:56:34	\N
112	40	2024-06-01 21:05:26	\N
113	40	2024-06-01 21:07:01	\N
114	40	2024-06-01 21:07:53	\N
115	40	2024-06-01 21:14:30	\N
116	40	2024-06-01 21:38:15	\N
117	40	2024-06-01 21:41:41	\N
118	40	2024-06-01 22:00:04	\N
119	40	2024-06-01 22:01:31	\N
120	40	2024-06-01 22:04:31	\N
121	40	2024-06-01 22:06:28	\N
122	40	2024-06-01 22:09:22	\N
123	40	2024-06-01 22:11:12	\N
124	40	2024-06-01 22:13:26	\N
125	40	2024-06-01 22:15:38	\N
126	40	2024-06-01 22:18:29	\N
127	40	2024-06-01 22:21:54	\N
128	40	2024-06-01 22:24:16	\N
129	40	2024-06-01 22:25:12	\N
130	40	2024-06-01 22:26:46	\N
131	40	2024-06-01 23:26:34	\N
132	40	2024-06-01 23:34:44	\N
133	40	2024-06-01 23:36:36	\N
134	40	2024-06-01 23:37:49	\N
135	40	2024-06-01 23:39:26	2024-06-01 23:39:29
136	40	2024-06-01 23:54:31	\N
137	40	2024-06-01 23:57:59	\N
138	40	2024-06-02 00:00:11	\N
139	40	2024-06-02 00:01:06	\N
140	40	2024-06-02 00:03:52	\N
141	40	2024-06-02 00:04:56	\N
142	40	2024-06-02 00:07:20	\N
143	40	2024-06-02 00:08:26	\N
144	40	2024-06-02 00:08:40	\N
145	40	2024-06-02 00:09:57	\N
146	40	2024-06-02 00:10:58	\N
147	40	2024-06-02 00:12:38	2024-06-02 00:12:44
160	40	2024-06-02 19:25:29	\N
148	40	2024-06-02 00:13:44	2024-06-02 00:13:52
149	40	2024-06-02 00:14:43	2024-06-02 00:14:45
150	40	2024-06-02 00:16:43	2024-06-02 00:16:54
151	40	2024-06-02 00:17:41	\N
152	40	2024-06-02 00:18:17	2024-06-02 00:18:33
153	40	2024-06-02 00:20:30	2024-06-02 00:20:36
161	40	2024-06-02 19:53:22	\N
154	40	2024-06-02 00:21:31	2024-06-02 00:21:43
155	40	2024-06-02 00:24:31	2024-06-02 00:24:34
162	40	2024-06-02 20:37:11	\N
156	40	2024-06-02 00:28:17	2024-06-02 00:29:21
157	40	2024-06-02 13:36:39	\N
158	40	2024-06-02 13:37:10	\N
159	40	2024-06-02 13:44:32	\N
163	40	2024-06-02 20:39:35	2024-06-02 20:42:03
164	40	2024-06-02 20:42:55	\N
165	40	2024-06-02 20:50:20	\N
166	40	2024-06-02 20:58:38	\N
167	40	2024-06-02 21:03:14	\N
168	40	2024-06-02 21:04:21	\N
169	40	2024-06-02 21:06:42	\N
170	40	2024-06-02 21:15:01	\N
171	40	2024-06-02 21:16:39	\N
172	40	2024-06-02 21:16:53	\N
173	40	2024-06-02 21:17:31	\N
174	40	2024-06-02 21:18:39	\N
175	40	2024-06-02 21:20:27	\N
176	40	2024-06-02 21:25:13	\N
177	40	2024-06-03 16:37:41	\N
178	40	2024-06-03 21:30:23	\N
179	40	2024-06-03 22:05:47	\N
180	40	2024-06-03 22:11:12	\N
181	40	2024-06-03 22:15:56	\N
182	40	2024-06-03 22:34:48	\N
183	40	2024-06-03 22:36:07	\N
184	40	2024-06-04 11:56:27	\N
185	40	2024-06-04 11:59:34	\N
186	40	2024-06-04 12:00:13	\N
187	40	2024-06-04 12:02:09	\N
188	40	2024-06-04 12:05:18	\N
189	40	2024-06-04 12:13:17	\N
190	40	2024-06-04 12:13:43	\N
191	40	2024-06-04 12:14:37	\N
192	40	2024-06-04 12:15:11	\N
193	40	2024-06-04 12:16:28	\N
194	40	2024-06-04 12:17:10	\N
195	40	2024-06-04 12:21:22	\N
196	40	2024-06-04 12:25:24	\N
197	40	2024-06-04 12:25:56	\N
198	40	2024-06-04 13:17:45	\N
199	40	2024-06-04 13:17:51	\N
200	40	2024-06-04 13:18:03	\N
201	40	2024-06-04 13:18:24	\N
202	40	2024-06-04 13:19:22	\N
203	40	2024-06-04 13:20:10	\N
204	40	2024-06-04 13:25:02	\N
205	40	2024-06-04 13:27:15	\N
206	40	2024-06-04 13:32:15	\N
207	40	2024-06-04 15:12:21	\N
208	40	2024-06-04 15:12:46	\N
209	40	2024-06-04 15:14:02	\N
210	40	2024-06-04 15:14:13	\N
211	40	2024-06-04 15:16:52	\N
212	40	2024-06-04 15:19:32	\N
213	40	2024-06-04 15:20:23	\N
214	40	2024-06-04 15:21:23	\N
215	40	2024-06-04 15:23:53	\N
216	40	2024-06-04 15:25:57	\N
217	40	2024-06-04 15:29:01	\N
218	40	2024-06-04 15:30:30	\N
219	40	2024-06-04 16:53:00	\N
220	40	2024-06-04 16:55:49	\N
221	40	2024-06-04 16:57:22	\N
222	40	2024-06-04 17:01:16	\N
223	40	2024-06-04 17:01:48	\N
224	40	2024-06-04 17:03:24	\N
225	40	2024-06-04 17:05:32	\N
226	40	2024-06-04 17:07:21	\N
227	40	2024-06-04 17:07:56	\N
228	40	2024-06-04 17:08:53	\N
229	40	2024-06-04 18:07:27	\N
230	40	2024-06-04 22:47:38	\N
231	40	2024-06-04 23:28:11	\N
232	40	2024-06-04 23:31:52	\N
233	40	2024-06-05 00:59:43	\N
234	40	2024-06-05 01:55:17	\N
235	40	2024-06-13 23:36:35	\N
236	40	2024-06-14 22:22:41	\N
237	40	2024-06-14 22:24:08	\N
238	40	2024-06-14 22:24:58	\N
\.


--
-- Data for Name: сотрудник; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."сотрудник" ("ид_сотрудника", "ид_персоны", "ид_должности", "персональный_код", "ид_документа") FROM stdin;
40	12	7	password	1
39	11	6	password	2
\.


--
-- Name: Клиент_ид_клиента_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Клиент_ид_клиента_seq"', 91, true);


--
-- Name: Лекарство_ид_лекарства_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Лекарство_ид_лекарства_seq"', 791, true);


--
-- Name: Продажа_ид_продажи_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Продажа_ид_продажи_seq"', 74, true);


--
-- Name: Сотрудник_ид_сотрудника_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Сотрудник_ид_сотрудника_seq"', 45, true);


--
-- Name: Транзакция_ид_транзакции_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Транзакция_ид_транзакции_seq"', 309, true);


--
-- Name: документ_ид_докмента_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."документ_ид_докмента_seq"', 4, true);


--
-- Name: должность_ид_должности_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."должность_ид_должности_seq"', 10, true);


--
-- Name: каталог_ид_каталога_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."каталог_ид_каталога_seq"', 32, true);


--
-- Name: каталог_классиф_ид_каталог_клас_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."каталог_классиф_ид_каталог_клас_seq"', 1, false);


--
-- Name: классификация_ид_классификации_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."классификация_ид_классификации_seq"', 1, false);


--
-- Name: персона_ид_персоны_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."персона_ид_персоны_seq"', 67, true);


--
-- Name: поставка_ид_поставщик_каталог_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."поставка_ид_поставщик_каталог_seq"', 633, true);


--
-- Name: поставщик_ид_поставщика_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."поставщик_ид_поставщика_seq"', 10, true);


--
-- Name: смена_ид_смены_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."смена_ид_смены_seq"', 238, true);


--
-- Name: покупатель Клиент_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."покупатель"
    ADD CONSTRAINT "Клиент_pkey" PRIMARY KEY ("ид_клиента");


--
-- Name: лекарство Лекарство_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."лекарство"
    ADD CONSTRAINT "Лекарство_pkey" PRIMARY KEY ("ид_лекарства");


--
-- Name: продажа Продажа_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."продажа"
    ADD CONSTRAINT "Продажа_pkey" PRIMARY KEY ("ид_продажи");


--
-- Name: сотрудник Сотрудник_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."сотрудник"
    ADD CONSTRAINT "Сотрудник_pkey" PRIMARY KEY ("ид_сотрудника");


--
-- Name: продажа_лекарство Транзакция_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."продажа_лекарство"
    ADD CONSTRAINT "Транзакция_pkey" PRIMARY KEY ("ид_продажа_лекарство");


--
-- Name: документ документ_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."документ"
    ADD CONSTRAINT "документ_pk" PRIMARY KEY ("ид_документа");


--
-- Name: должность должность_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."должность"
    ADD CONSTRAINT "должность_pk" PRIMARY KEY ("ид_должности");


--
-- Name: должность должность_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."должность"
    ADD CONSTRAINT "должность_unique" UNIQUE ("уровень_доступа", "название");


--
-- Name: каталог каталог_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."каталог"
    ADD CONSTRAINT "каталог_pk" PRIMARY KEY ("ид_каталога");


--
-- Name: каталог каталог_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."каталог"
    ADD CONSTRAINT "каталог_unique" UNIQUE ("название", "производитель", "дозировка");


--
-- Name: каталог_классификация каталог_классификация_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."каталог_классификация"
    ADD CONSTRAINT "каталог_классификация_pk" PRIMARY KEY ("ид_каталог_классификация");


--
-- Name: классификация классификация_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."классификация"
    ADD CONSTRAINT "классификация_pk" PRIMARY KEY ("ид_классификации");


--
-- Name: классификация классификация_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."классификация"
    ADD CONSTRAINT "классификация_unique" UNIQUE ("код");


--
-- Name: лекарство лекарство_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."лекарство"
    ADD CONSTRAINT "лекарство_unique" UNIQUE ("серийный_номер", "в_наличии");


--
-- Name: персона персона_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."персона"
    ADD CONSTRAINT "персона_pk" PRIMARY KEY ("ид_персоны");


--
-- Name: персона персона_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."персона"
    ADD CONSTRAINT "персона_unique" UNIQUE ("фамилия", "имя", "отчество", "дата_рождения", "телефон");


--
-- Name: поставщик поставщик_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."поставщик"
    ADD CONSTRAINT "поставщик_pk" PRIMARY KEY ("ид_поставщика");


--
-- Name: поставка поставщик_каталог_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."поставка"
    ADD CONSTRAINT "поставщик_каталог_pk" PRIMARY KEY ("ид_поставки");


--
-- Name: смена смена_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."смена"
    ADD CONSTRAINT "смена_pk" PRIMARY KEY ("ид_смены");


--
-- Name: продажа_лекарство Транзакция_ид_лекарства_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."продажа_лекарство"
    ADD CONSTRAINT "Транзакция_ид_лекарства_fkey" FOREIGN KEY ("ид_лекарства") REFERENCES public."лекарство"("ид_лекарства") NOT VALID;


--
-- Name: продажа_лекарство Транзакция_ид_продажи_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."продажа_лекарство"
    ADD CONSTRAINT "Транзакция_ид_продажи_fkey" FOREIGN KEY ("ид_продажи") REFERENCES public."продажа"("ид_продажи") NOT VALID;


--
-- Name: каталог_классификация каталог_классификация_каталог_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."каталог_классификация"
    ADD CONSTRAINT "каталог_классификация_каталог_fk" FOREIGN KEY ("ид_каталога") REFERENCES public."каталог"("ид_каталога");


--
-- Name: каталог_классификация каталог_классификация_классифика; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."каталог_классификация"
    ADD CONSTRAINT "каталог_классификация_классифика" FOREIGN KEY ("ид_классификации") REFERENCES public."классификация"("ид_классификации");


--
-- Name: покупатель клиент_персона_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."покупатель"
    ADD CONSTRAINT "клиент_персона_fk" FOREIGN KEY ("ид_персоны") REFERENCES public."персона"("ид_персоны");


--
-- Name: лекарство лекарство_каталог_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."лекарство"
    ADD CONSTRAINT "лекарство_каталог_fk" FOREIGN KEY ("ид_каталога") REFERENCES public."каталог"("ид_каталога");


--
-- Name: поставка поставка_лекарство_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."поставка"
    ADD CONSTRAINT "поставка_лекарство_fk" FOREIGN KEY ("ид_лекарства") REFERENCES public."лекарство"("ид_лекарства");


--
-- Name: поставщик поставщик_каталог_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."поставщик"
    ADD CONSTRAINT "поставщик_каталог_fk" FOREIGN KEY ("ид_каталога") REFERENCES public."каталог"("ид_каталога");


--
-- Name: поставка поставщик_каталог_поставщик_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."поставка"
    ADD CONSTRAINT "поставщик_каталог_поставщик_fk" FOREIGN KEY ("ид_поставщика") REFERENCES public."поставщик"("ид_поставщика");


--
-- Name: продажа продажа_персона_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."продажа"
    ADD CONSTRAINT "продажа_персона_fk" FOREIGN KEY ("ид_персоны") REFERENCES public."персона"("ид_персоны");


--
-- Name: продажа продажа_смена_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."продажа"
    ADD CONSTRAINT "продажа_смена_fk" FOREIGN KEY ("ид_смены") REFERENCES public."смена"("ид_смены");


--
-- Name: смена смена_сотрудник_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."смена"
    ADD CONSTRAINT "смена_сотрудник_fk" FOREIGN KEY ("ид_сотрудника") REFERENCES public."сотрудник"("ид_сотрудника");


--
-- Name: сотрудник сотрудник_документ_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."сотрудник"
    ADD CONSTRAINT "сотрудник_документ_fk" FOREIGN KEY ("ид_документа") REFERENCES public."документ"("ид_документа");


--
-- Name: сотрудник сотрудник_должность_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."сотрудник"
    ADD CONSTRAINT "сотрудник_должность_fk" FOREIGN KEY ("ид_должности") REFERENCES public."должность"("ид_должности");


--
-- Name: сотрудник сотрудник_персона_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."сотрудник"
    ADD CONSTRAINT "сотрудник_персона_fk" FOREIGN KEY ("ид_персоны") REFERENCES public."персона"("ид_персоны");


--
-- Name: FUNCTION "добавить_запись_в_таблицу"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."добавить_запись_в_таблицу"(params jsonb) TO cashier;


--
-- Name: PROCEDURE "изменить_запись_в_таблице"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."изменить_запись_в_таблице"(IN params jsonb) TO cashier;


--
-- Name: FUNCTION "получить_дополнительные_данные"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."получить_дополнительные_данные"(params jsonb) TO cashier;


--
-- Name: FUNCTION "получить_записи"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."получить_записи"(params jsonb) TO cashier;


--
-- Name: FUNCTION "получить_записи_join"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."получить_записи_join"(params jsonb) TO cashier;


--
-- Name: FUNCTION "получить_записи_по_атрибуту"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."получить_записи_по_атрибуту"(params jsonb) TO cashier;


--
-- Name: FUNCTION "получить_покупателей_и_их_скидки"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."получить_покупателей_и_их_скидки"() TO cashier;


--
-- Name: FUNCTION "получить_полную_цену"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."получить_полную_цену"(params jsonb) TO cashier;


--
-- Name: PROCEDURE "проверить_лекарства_по_рецепту"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."проверить_лекарства_по_рецепту"(IN params jsonb) TO cashier;


--
-- Name: FUNCTION "проверить_персональный_код"(data jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."проверить_персональный_код"(data jsonb) TO cashier;


--
-- Name: FUNCTION "создать_клиента"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."создать_клиента"(params jsonb) TO cashier;


--
-- Name: PROCEDURE "создать_поставку"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."создать_поставку"(IN params jsonb) TO cashier;


--
-- Name: PROCEDURE "создать_продажу"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."создать_продажу"(IN params jsonb) TO cashier;


--
-- Name: FUNCTION "создать_сотрудника"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."создать_сотрудника"(params jsonb) TO cashier;


--
-- Name: FUNCTION "сформировать_отчет_поставки"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."сформировать_отчет_поставки"(params jsonb) TO cashier;


--
-- Name: FUNCTION "сформировать_отчет_продажи"(params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public."сформировать_отчет_продажи"(params jsonb) TO cashier;


--
-- Name: PROCEDURE "удалить_запись_из_таблицы"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."удалить_запись_из_таблицы"(IN params jsonb) TO cashier;


--
-- Name: PROCEDURE "удалить_клиента"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."удалить_клиента"(IN params jsonb) TO cashier;


--
-- Name: PROCEDURE "удалить_сотрудника"(IN params jsonb); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public."удалить_сотрудника"(IN params jsonb) TO cashier;


--
-- Name: TABLE "лекарство"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."лекарство" TO cashier;


--
-- Name: TABLE "продажа"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."продажа" TO cashier;


--
-- Name: TABLE "продажа_лекарство"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."продажа_лекарство" TO cashier;


--
-- Name: TABLE "каталог"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public."каталог" TO cashier;


--
-- Name: TABLE "каталог_классификация"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public."каталог_классификация" TO cashier;


--
-- Name: TABLE "классификация"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public."классификация" TO cashier;


--
-- Name: TABLE "смена"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."смена" TO cashier;


--
-- PostgreSQL database dump complete
--

