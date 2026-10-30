
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF




/* =====================================================================
   1. DISPARADOR COMPUESTO DE AUDITORIA SOBRE TARIFA
   ===================================================================== */

CREATE OR REPLACE TRIGGER trg_auditoria_tarifa
FOR INSERT OR UPDATE OR DELETE ON tarifa
COMPOUND TRIGGER

    -- Estructura para almacenar los cambios de cada fila.
    TYPE r_cambio IS RECORD (
        operacion       VARCHAR2(6),
        id_habitacion   NUMBER,
        id_temporada    NUMBER,
        precio_anterior NUMBER(10,2),
        precio_nuevo    NUMBER(10,2)
    );

    TYPE t_cambios IS TABLE OF r_cambio
        INDEX BY PLS_INTEGER;

    v_cambios  t_cambios;
    v_contador PLS_INTEGER := 0;


    /* ---------------------------------------------------------------
       AFTER EACH ROW:
       Captura los valores anteriores y nuevos de cada operacion.
       --------------------------------------------------------------- */
    AFTER EACH ROW IS
    BEGIN
        v_contador := v_contador + 1;

        IF INSERTING THEN

            v_cambios(v_contador).operacion := 'INSERT';
            v_cambios(v_contador).id_habitacion := :NEW.id_habitacion;
            v_cambios(v_contador).id_temporada := :NEW.id_temporada;
            v_cambios(v_contador).precio_anterior := NULL;
            v_cambios(v_contador).precio_nuevo := :NEW.precio_noche;

        ELSIF UPDATING THEN

            v_cambios(v_contador).operacion := 'UPDATE';
            v_cambios(v_contador).id_habitacion := :NEW.id_habitacion;
            v_cambios(v_contador).id_temporada := :NEW.id_temporada;
            v_cambios(v_contador).precio_anterior := :OLD.precio_noche;
            v_cambios(v_contador).precio_nuevo := :NEW.precio_noche;

        ELSIF DELETING THEN

            v_cambios(v_contador).operacion := 'DELETE';
            v_cambios(v_contador).id_habitacion := :OLD.id_habitacion;
            v_cambios(v_contador).id_temporada := :OLD.id_temporada;
            v_cambios(v_contador).precio_anterior := :OLD.precio_noche;
            v_cambios(v_contador).precio_nuevo := NULL;

        END IF;
    END AFTER EACH ROW;


    /* ---------------------------------------------------------------
       AFTER STATEMENT:
       Registra todos los cambios capturados en AUDITORIA_TARIFA.
       Se ejecuta una vez al finalizar la sentencia SQL.
       --------------------------------------------------------------- */
    AFTER STATEMENT IS
    BEGIN

        FOR i IN 1 .. v_contador LOOP

            INSERT INTO auditoria_tarifa (
                usuario,
                fecha,
                operacion,
                id_habitacion,
                id_temporada,
                precio_anterior,
                precio_nuevo
            )
            VALUES (
                USER,
                SYSDATE,
                v_cambios(i).operacion,
                v_cambios(i).id_habitacion,
                v_cambios(i).id_temporada,
                v_cambios(i).precio_anterior,
                v_cambios(i).precio_nuevo
            );

        END LOOP;

    END AFTER STATEMENT;

END trg_auditoria_tarifa;
/

SHOW ERRORS TRIGGER trg_auditoria_tarifa


/* =====================================================================
   2. DISPARADOR COMPUESTO PARA EVITAR SOLAPAMIENTO DE RESERVAS

   Se aplica sobre RESERVA_HABITACION.

   Funcionamiento:
   - AFTER EACH ROW almacena los identificadores de las filas nuevas
     o modificadas.
   - AFTER STATEMENT consulta la tabla cuando la sentencia ya terminó.
   - Comprueba si alguna de esas filas se cruza con otra reserva activa.

   Se excluyen las reservas cuyo estado sea CANCELADA.

   Codigo de error:
   -20020: la habitacion ya esta ocupada en ese intervalo.
   ===================================================================== */

CREATE OR REPLACE TRIGGER trg_validar_solapamiento
FOR INSERT OR UPDATE ON reserva_habitacion
COMPOUND TRIGGER

    -- Almacena las filas que deben validarse al terminar la sentencia.
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

    v_ids      t_ids;
    v_contador PLS_INTEGER := 0;


    /* ---------------------------------------------------------------
       AFTER EACH ROW:
       Guarda el identificador de la fila insertada o modificada.
       --------------------------------------------------------------- */
    AFTER EACH ROW IS
    BEGIN

        v_contador := v_contador + 1;
        v_ids(v_contador) := :NEW.id_reserva_habitacion;

    END AFTER EACH ROW;


    /* ---------------------------------------------------------------
       AFTER STATEMENT:
       Consulta RESERVA_HABITACION y RESERVA para detectar cruces.

       Al ejecutarse despues de la sentencia, evita consultar la tabla
       mientras Oracle la esta modificando.
       --------------------------------------------------------------- */
    AFTER STATEMENT IS

        v_solapamientos NUMBER;

    BEGIN

        FOR i IN 1 .. v_contador LOOP

            SELECT COUNT(*)
              INTO v_solapamientos
              FROM reserva_habitacion a
              JOIN reserva ra
                ON ra.id_reserva = a.id_reserva
              JOIN reserva_habitacion b
                ON b.id_habitacion = a.id_habitacion
               AND b.id_reserva_habitacion <> a.id_reserva_habitacion
              JOIN reserva rb
                ON rb.id_reserva = b.id_reserva
             WHERE a.id_reserva_habitacion = v_ids(i)

               -- Las reservas canceladas no bloquean disponibilidad.
               AND ra.estado <> 'CANCELADA'
               AND rb.estado <> 'CANCELADA'

               -- Condicion de cruce entre los intervalos.
               AND a.fecha_checkin < b.fecha_checkout
               AND a.fecha_checkout > b.fecha_checkin;


            IF v_solapamientos > 0 THEN

                RAISE_APPLICATION_ERROR(
                    -20020,
                    'No se puede registrar la reserva: la habitacion '
                    || 'ya tiene otra reserva activa en ese intervalo.'
                );

            END IF;

        END LOOP;

    END AFTER STATEMENT;

END trg_validar_solapamiento;
/

SHOW ERRORS TRIGGER trg_validar_solapamiento


/* =====================================================================
   3. VERIFICACION DE LOS DISPARADORES

   Ambos objetos deben quedar en estado VALID.
   ===================================================================== */

SELECT object_name,
       object_type,
       status
  FROM user_objects
 WHERE object_name IN (
       'TRG_AUDITORIA_TARIFA',
       'TRG_VALIDAR_SOLAPAMIENTO'
 )
 ORDER BY object_name;


/* =====================================================================
   4. PRUEBAS DE AUDITORIA

   Se crea una temporada temporal del año 2099.
   Posteriormente se ejecutan:
   - INSERT de una tarifa.
   - UPDATE de su precio.
   - DELETE de la tarifa.

   Se comprueba que existan los tres registros en AUDITORIA_TARIFA.
   ===================================================================== */

DECLARE

    v_habitacion NUMBER;
    v_temporada  NUMBER;

    v_insert     NUMBER;
    v_update     NUMBER;
    v_delete     NUMBER;

    PROCEDURE resultado(
        p_nombre VARCHAR2,
        p_ok     BOOLEAN,
        p_detalle VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(
            RPAD(p_nombre, 55)
            || CASE WHEN p_ok THEN 'PASA' ELSE 'FALLA' END
            || CASE
                 WHEN p_detalle IS NOT NULL
                 THEN ' - ' || p_detalle
               END
        );
    END;

BEGIN

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== PRUEBAS DE AUDITORIA TARIFA ===');

    -- Seleccionar una habitacion existente.
    SELECT MIN(id_habitacion)
      INTO v_habitacion
      FROM habitacion;

    -- Crear una temporada temporal para las pruebas.
    INSERT INTO temporada (
        nombre,
        categoria,
        anio,
        fecha_inicio,
        fecha_fin
    )
    VALUES (
        'TEMPORADA PRUEBA AUDITORIA',
        'MEDIA',
        2099,
        DATE '2099-01-01',
        DATE '2099-12-31'
    )
    RETURNING id_temporada INTO v_temporada;


    /* ---------------------------------------------------------------
       A1. INSERT:
       El precio anterior debe ser NULL y el nuevo debe tener valor.
       --------------------------------------------------------------- */
    INSERT INTO tarifa (
        id_habitacion,
        id_temporada,
        precio_noche
    )
    VALUES (
        v_habitacion,
        v_temporada,
        100000
    );


    /* ---------------------------------------------------------------
       A2. UPDATE:
       Debe registrar el precio anterior y el precio nuevo.
       --------------------------------------------------------------- */
    UPDATE tarifa
       SET precio_noche = 120000
     WHERE id_habitacion = v_habitacion
       AND id_temporada = v_temporada;


    /* ---------------------------------------------------------------
       A3. DELETE:
       El precio anterior debe conservarse y el nuevo ser NULL.
       --------------------------------------------------------------- */
    DELETE FROM tarifa
     WHERE id_habitacion = v_habitacion
       AND id_temporada = v_temporada;


    -- Comprobar que cada operacion quedo registrada correctamente.
    SELECT COUNT(*)
      INTO v_insert
      FROM auditoria_tarifa
     WHERE id_habitacion = v_habitacion
       AND id_temporada = v_temporada
       AND operacion = 'INSERT'
       AND precio_anterior IS NULL
       AND precio_nuevo = 100000;


    SELECT COUNT(*)
      INTO v_update
      FROM auditoria_tarifa
     WHERE id_habitacion = v_habitacion
       AND id_temporada = v_temporada
       AND operacion = 'UPDATE'
       AND precio_anterior = 100000
       AND precio_nuevo = 120000;


    SELECT COUNT(*)
      INTO v_delete
      FROM auditoria_tarifa
     WHERE id_habitacion = v_habitacion
       AND id_temporada = v_temporada
       AND operacion = 'DELETE'
       AND precio_anterior = 120000
       AND precio_nuevo IS NULL;


    resultado('A1 - Auditoria de INSERT',
              v_insert = 1);

    resultado('A2 - Auditoria de UPDATE',
              v_update = 1);

    resultado('A3 - Auditoria de DELETE',
              v_delete = 1);

    resultado('A4 - Total de operaciones auditadas',
              v_insert + v_update + v_delete = 3,
              'Registros encontrados: '
              || (v_insert + v_update + v_delete));


    DBMS_OUTPUT.PUT_LINE(
        'Habitacion utilizada para auditoria: ' || v_habitacion
    );

END;
/


/* =====================================================================
   5. PRUEBAS DE SOLAPAMIENTO DE RESERVAS

   Se realizan tres operaciones:

   R1. Registrar una primera reserva.
   R2. Intentar registrar otra reserva con fechas cruzadas.
       Debe rechazarse con el error -20020.
   R3. Registrar una reserva cuyo check-in coincide con el checkout
       de la primera. Debe aceptarse.

   Se utilizan fechas del año 2099 para evitar interferir con
   las reservas existentes.
   ===================================================================== */

DECLARE

    v_cliente       NUMBER;
    v_habitacion    NUMBER;
    v_alojamiento   NUMBER;

    v_reserva1      NUMBER;
    v_reserva2      NUMBER;
    v_reserva3      NUMBER;

    v_error         NUMBER;

    PROCEDURE resultado(
        p_nombre VARCHAR2,
        p_ok     BOOLEAN,
        p_detalle VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(
            RPAD(p_nombre, 60)
            || CASE WHEN p_ok THEN 'PASA' ELSE 'FALLA' END
            || CASE
                 WHEN p_detalle IS NOT NULL
                 THEN ' - ' || p_detalle
               END
        );
    END;

BEGIN

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== PRUEBAS DE SOLAPAMIENTO ===');

    -- Obtener registros existentes para construir las reservas.
    SELECT MIN(id_cliente)
      INTO v_cliente
      FROM cliente;

    SELECT id_habitacion, id_alojamiento
      INTO v_habitacion, v_alojamiento
      FROM habitacion
     WHERE id_habitacion = (
           SELECT MIN(id_habitacion)
             FROM habitacion
     );


    /* ---------------------------------------------------------------
       R1. Primera reserva:
       Del 10 al 15 de enero de 2099.
       --------------------------------------------------------------- */
    INSERT INTO reserva (
        id_cliente,
        id_alojamiento,
        fecha_checkin,
        fecha_checkout,
        estado
    )
    VALUES (
        v_cliente,
        v_alojamiento,
        DATE '2099-01-10',
        DATE '2099-01-15',
        'PENDIENTE'
    )
    RETURNING id_reserva INTO v_reserva1;


    INSERT INTO reserva_habitacion (
        id_reserva,
        id_habitacion,
        id_alojamiento,
        fecha_checkin,
        fecha_checkout,
        num_huespedes,
        valor_estadia
    )
    VALUES (
        v_reserva1,
        v_habitacion,
        v_alojamiento,
        DATE '2099-01-10',
        DATE '2099-01-15',
        1,
        0
    );

    resultado(
        'R1 - Primera reserva registrada',
        TRUE,
        'Reserva ' || v_reserva1
    );


    /* ---------------------------------------------------------------
       R2. Reserva solapada:
       Del 14 al 18 de enero de 2099.

       Se cruza con la primera reserva, por lo tanto debe rechazarse.
       --------------------------------------------------------------- */
    INSERT INTO reserva (
        id_cliente,
        id_alojamiento,
        fecha_checkin,
        fecha_checkout,
        estado
    )
    VALUES (
        v_cliente,
        v_alojamiento,
        DATE '2099-01-14',
        DATE '2099-01-18',
        'PENDIENTE'
    )
    RETURNING id_reserva INTO v_reserva2;


    BEGIN

        INSERT INTO reserva_habitacion (
            id_reserva,
            id_habitacion,
            id_alojamiento,
            fecha_checkin,
            fecha_checkout,
            num_huespedes,
            valor_estadia
        )
        VALUES (
            v_reserva2,
            v_habitacion,
            v_alojamiento,
            DATE '2099-01-14',
            DATE '2099-01-18',
            1,
            0
        );

        -- Si llega aquí, el disparador no rechazó el cruce.
        resultado(
            'R2 - Reserva solapada rechazada',
            FALSE,
            'La reserva fue aceptada incorrectamente'
        );

    EXCEPTION
        WHEN OTHERS THEN

            v_error := SQLCODE;

            resultado(
                'R2 - Reserva solapada rechazada',
                v_error = -20020,
                SQLERRM
            );

    END;


    /* ---------------------------------------------------------------
       R3. Reserva compatible:
       Del 15 al 18 de enero de 2099.

       El check-in coincide con el checkout de R1.
       No existe solapamiento y debe aceptarse.
       --------------------------------------------------------------- */
    INSERT INTO reserva (
        id_cliente,
        id_alojamiento,
        fecha_checkin,
        fecha_checkout,
        estado
    )
    VALUES (
        v_cliente,
        v_alojamiento,
        DATE '2099-01-15',
        DATE '2099-01-18',
        'PENDIENTE'
    )
    RETURNING id_reserva INTO v_reserva3;


    INSERT INTO reserva_habitacion (
        id_reserva,
        id_habitacion,
        id_alojamiento,
        fecha_checkin,
        fecha_checkout,
        num_huespedes,
        valor_estadia
    )
    VALUES (
        v_reserva3,
        v_habitacion,
        v_alojamiento,
        DATE '2099-01-15',
        DATE '2099-01-18',
        1,
        0
    );


    resultado(
        'R3 - Reserva compatible aceptada',
        TRUE,
        'Reserva ' || v_reserva3
    );


    DBMS_OUTPUT.PUT_LINE(
        'Habitacion utilizada para las pruebas: ' || v_habitacion
    );

END;
/


/* =====================================================================
   6. CONSULTA DE VERIFICACION DE AUDITORIA

   Muestra los registros generados durante las pruebas.
   ===================================================================== */

SELECT id_auditoria,
       usuario,
       fecha,
       operacion,
       id_habitacion,
       id_temporada,
       precio_anterior,
       precio_nuevo
  FROM auditoria_tarifa
 ORDER BY id_auditoria DESC
 FETCH FIRST 10 ROWS ONLY;


/* ===================================================================== */

ROLLBACK;

/* ======================== FIN DEL SCRIPT 02 ======================== */
