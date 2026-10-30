/* ---------------------------------------------------------------------
    1. Verificar las rutas disponibles
   --------------------------------------------------------------------- */
SELECT name
FROM v$datafile;

SHOW PARAMETER db_create_file_dest;

/* ---------------------------------------------------------------------
    1. Crear el tablespace
   --------------------------------------------------------------------- */
   
CREATE TABLESPACE TS_HISTORICO_RESERVAS
DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/ts_historico_reservas_01.dbf'
SIZE 100M
AUTOEXTEND ON NEXT 10M
MAXSIZE 1G;
   
/* ---------------------------------------------------------------------
    2. Verificar su creación
   --------------------------------------------------------------------- */   
   
SELECT tablespace_name, status, contents
FROM dba_tablespaces
WHERE tablespace_name = 'TS_HISTORICO_RESERVAS';   

SELECT tablespace_name, file_name, bytes / 1024 / 1024 AS tamanio_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_HISTORICO_RESERVAS';

//2. Verificar los privilegios

SELECT privilege
FROM session_privs
WHERE privilege IN (
    'CREATE TABLE',
    'CREATE TABLESPACE',
    'ALTER TABLESPACE',
    'UNLIMITED TABLESPACE'
)
ORDER BY privilege;

//Cuota de almacenamiento
SELECT tablespace_name, bytes, max_bytes
FROM user_ts_quotas
WHERE tablespace_name = 'TS_HISTORICO_RESERVAS';


//1. Crear la tabla:

CREATE TABLE HISTORICO_RESERVA
TABLESPACE TS_HISTORICO_RESERVAS
AS
SELECT
    id_reserva,
    id_cliente,
    id_alojamiento,
    fecha_creacion,
    fecha_checkin,
    fecha_checkout,
    estado,
    fecha_cancelacion
FROM RESERVA
WHERE 1 = 0;

//2. Agregar la fecha de archivo
ALTER TABLE HISTORICO_RESERVA
ADD (
    fecha_archivado DATE DEFAULT SYSDATE NOT NULL
);

//3. Agregar la llave primaria

ALTER TABLE HISTORICO_RESERVA
ADD CONSTRAINT PK_HISTORICO_RESERVA
PRIMARY KEY (id_reserva);


//verificar su almacenamiento
SELECT
    table_name,
    tablespace_name
FROM user_tables
WHERE table_name = 'HISTORICO_RESERVA';

SELECT COUNT(*) AS TOTAL_HISTORICO
FROM HISTORICO_RESERVA;

//revisar qué reservas podemos archivar
SELECT
    estado,
    COUNT(*) AS cantidad
FROM RESERVA
GROUP BY estado
ORDER BY estado;

//1. Insertar las reservas históricas

INSERT INTO HISTORICO_RESERVA (
    id_reserva,
    id_cliente,
    id_alojamiento,
    fecha_creacion,
    fecha_checkin,
    fecha_checkout,
    estado,
    fecha_cancelacion
)
SELECT
    r.id_reserva,
    r.id_cliente,
    r.id_alojamiento,
    r.fecha_creacion,
    r.fecha_checkin,
    r.fecha_checkout,
    r.estado,
    r.fecha_cancelacion
FROM RESERVA r
WHERE r.estado IN ('COMPLETADA', 'CANCELADA')
AND NOT EXISTS (
    SELECT 1
    FROM HISTORICO_RESERVA h
    WHERE h.id_reserva = r.id_reserva
);

COMMIT;

//2. Verificar los registros archivados
SELECT
    estado,
    COUNT(*) AS cantidad
FROM HISTORICO_RESERVA
GROUP BY estado
ORDER BY estado;

//Verificar el total
SELECT COUNT(*) AS TOTAL_HISTORICO
FROM HISTORICO_RESERVA;

//Y esta para verificar que las reservas originales siguen intactas:
SELECT COUNT(*) AS TOTAL_RESERVAS
FROM RESERVA;

/* ---------------------------------------------------------------------
    1. Crear la vista materializada
   --------------------------------------------------------------------- */   
CREATE MATERIALIZED VIEW MV_OCUPACION_MENSUAL_ALOJ
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    TRUNC(rh.fecha_checkin, 'MM') AS mes,
    a.id_alojamiento,
    a.nombre_comercial,
    COUNT(*) AS habitaciones_reservadas,
    COUNT(DISTINCT rh.id_reserva) AS reservas_iniciadas
FROM reserva_habitacion rh
JOIN reserva r
    ON r.id_reserva = rh.id_reserva
JOIN habitacion h
    ON h.id_habitacion = rh.id_habitacion
   AND h.id_alojamiento = rh.id_alojamiento
JOIN alojamiento a
    ON a.id_alojamiento = rh.id_alojamiento
WHERE r.estado <> 'CANCELADA'
GROUP BY
    TRUNC(rh.fecha_checkin, 'MM'),
    a.id_alojamiento,
    a.nombre_comercial;
    
//2. Consultar los resultados
SELECT
    TO_CHAR(mes, 'YYYY-MM') AS mes,
    id_alojamiento,
    nombre_comercial,
    habitaciones_reservadas,
    reservas_iniciadas
FROM MV_OCUPACION_MENSUAL_ALOJ
ORDER BY mes, nombre_comercial;

//3. Verificar que quedó creada
 SELECT
    mview_name,
    refresh_mode,
    refresh_method
FROM user_mviews
WHERE mview_name = 'MV_OCUPACION_MENSUAL_ALOJ';

//4. Actualizar la vista cuando cambien los datos La opción 'C' indica actualización completa.
BEGIN
    DBMS_MVIEW.REFRESH(
        'MV_OCUPACION_MENSUAL_ALOJ',
        'C'
    );
END;
/

/* ---------------------------------------------------------------------
    elimino la vista anterior
   --------------------------------------------------------------------- */  
DROP MATERIALIZED VIEW MV_OCUPACION_MENSUAL_ALOJ;

//Se crea la nueva
CREATE MATERIALIZED VIEW MV_OCUPACION_MENSUAL_ALOJ
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
WITH limites AS (
    SELECT
        TRUNC(MIN(fecha_checkin), 'MM') AS min_mes,
        TRUNC(MAX(fecha_checkout - 1), 'MM') AS max_mes
    FROM reserva_habitacion
),
meses AS (
    SELECT ADD_MONTHS(min_mes, LEVEL - 1) AS mes
    FROM limites
    CONNECT BY LEVEL <= MONTHS_BETWEEN(max_mes, min_mes) + 1
)
SELECT
    m.mes,
    a.id_alojamiento,
    a.nombre_comercial,
    SUM(
        LEAST(rh.fecha_checkout, ADD_MONTHS(m.mes, 1))
        - GREATEST(rh.fecha_checkin, m.mes)
    ) AS noches_habitacion_ocupadas,
    COUNT(DISTINCT rh.id_reserva) AS reservas
FROM meses m
JOIN reserva_habitacion rh
    ON rh.fecha_checkin < ADD_MONTHS(m.mes, 1)
   AND rh.fecha_checkout > m.mes
JOIN reserva r
    ON r.id_reserva = rh.id_reserva
JOIN habitacion h
    ON h.id_habitacion = rh.id_habitacion
   AND h.id_alojamiento = rh.id_alojamiento
JOIN alojamiento a
    ON a.id_alojamiento = rh.id_alojamiento
WHERE r.estado <> 'CANCELADA'
GROUP BY
    m.mes,
    a.id_alojamiento,
    a.nombre_comercial;
    
//Consultar el resultado
SELECT
    TO_CHAR(mes, 'YYYY-MM') AS mes,
    id_alojamiento,
    nombre_comercial,
    noches_habitacion_ocupadas,
    reservas
FROM MV_OCUPACION_MENSUAL_ALOJ
ORDER BY mes, nombre_comercial;

/* ---------------------------------------------------------------------
   Crear la tarea automática
   --------------------------------------------------------------------- */  
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_REFRESH_OCUPACION',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
            BEGIN
                DBMS_MVIEW.REFRESH(
                    ''MV_OCUPACION_MENSUAL_ALOJ'',
                    ''C''
                );
            END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=0;BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Actualizacion diaria de la ocupacion mensual por alojamiento'
    );
END;
/

//Verificar que el trabajo quedó programado
SELECT
    job_name,
    enabled,
    state,
    repeat_interval
FROM user_scheduler_jobs
WHERE job_name = 'JOB_REFRESH_OCUPACION';

//consultar las ejecuciones:
SELECT
    job_name,
    status,
    actual_start_date,
    run_duration
FROM user_scheduler_job_run_details
WHERE job_name = 'JOB_REFRESH_OCUPACION'
ORDER BY log_date DESC;

/* ---------------------------------------------------------------------
   1.Verificar la existencia del tablespace
   --------------------------------------------------------------------- */  
SELECT
    tablespace_name,
    status,
    contents
FROM user_tablespaces
WHERE tablespace_name = 'TS_HISTORICO_RESERVAS';

//Para comprobar también la ubicación física del archivo
SELECT
    tablespace_name,
    file_name,
    bytes / 1024 / 1024 AS tamano_mb,
    autoextensible
FROM dba_data_files
WHERE tablespace_name = 'TS_HISTORICO_RESERVAS';

//2. Verificar la ubicación del segmento histórico
SELECT
    table_name,
    tablespace_name
FROM user_tables
WHERE table_name = 'HISTORICO_RESERVA';

//Para comprobar que el segmento ocupa espacio en ese tablespace
SELECT
    segment_name,
    segment_type,
    tablespace_name,
    bytes / 1024 / 1024 AS tamano_mb
FROM user_segments
WHERE segment_name = 'HISTORICO_RESERVA';

//3. Verificar la definición de la vista materializada
SELECT
    mview_name,
    refresh_mode,
    refresh_method,
    build_mode
FROM user_mviews
WHERE mview_name = 'MV_OCUPACION_MENSUAL_ALOJ';

//Para consultar su definición SQL completa
SELECT DBMS_METADATA.GET_DDL(
    'MATERIALIZED_VIEW',
    'MV_OCUPACION_MENSUAL_ALOJ'
)
FROM dual;

//4. Verificar los datos después del refresco Consultar los registros
SELECT
    TO_CHAR(mes, 'YYYY-MM') AS mes,
    id_alojamiento,
    nombre_comercial,
    noches_habitacion_ocupadas,
    reservas
FROM MV_OCUPACION_MENSUAL_ALOJ
ORDER BY mes, nombre_comercial;

//Comprobar cuántas filas contiene:
SELECT COUNT(*) AS total_registros
FROM MV_OCUPACION_MENSUAL_ALOJ;

//Consultar el último refresco registrado
SELECT
    mview_name,
    last_refresh_type,
    last_refresh_date
FROM user_mviews
WHERE mview_name = 'MV_OCUPACION_MENSUAL_ALOJ';