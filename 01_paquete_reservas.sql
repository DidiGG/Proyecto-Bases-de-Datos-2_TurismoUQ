/* =====================================================================
   PROYECTO INTEGRADOR TurismoUQ - Bases de Datos II (Universidad del Quindio)
   Entrega 2 - Script 01: LOGICA DE NEGOCIO (paquete PKG_RESERVAS)
   Responsable: Kevin Stiven Sanchez

   Contenido:
     1. Paquete PKG_RESERVAS (especificacion)
          - fn_valor_estadia          : valor de la estadia noche por noche
          - fn_habitacion_disponible  : disponibilidad de una habitacion en un rango
          - sp_crear_reserva (x2)     : crea cabecera + lineas (version varias habitaciones / una habitacion)
          - pr_liquidacion_mensual    : liquidacion mensual por alojamiento (cursor explicito con parametros)
     2. Cuerpo del paquete
     3. Pruebas (con resultados PASA / FALLA por DBMS_OUTPUT)

   Requisito previo: Script 01 de la Entrega 1 (DDL) y Script 02 (carga de datos).

   NOTA SOBRE LAS PRUEBAS (sin caducidad): sp_crear_reserva rechaza check-ins en el pasado y la
   TEMPORADA cargada solo llega hasta 2027-01-10. Por eso las pruebas de reservas y de liquidacion
   crean, DENTRO de la transaccion de prueba, un calendario propio de enero-febrero de 2028
   (3 temporadas + una tarifa por habitacion y temporada). Todo se deshace con el ROLLBACK final,
   asi que la base queda igual y el script funciona en cualquier fecha anterior a 2028.
   Las pruebas de fn_valor_estadia (F1-F5, F7) usan fechas reales ya cargadas y no dependen de SYSDATE.

   CODIGOS DE ERROR DE APLICACION (RAISE_APPLICATION_ERROR)
     -20001  Habitacion no disponible (ya ocupada por otra reserva no cancelada en esas noches)
     -20002  Checkout anterior o igual al checkin (o fechas de una linea fuera del rango de la reserva)
     -20003  Capacidad excedida (num_huespedes > HABITACION.CAPACIDAD_MAX)
     -20004  Noche sin temporada o sin tarifa aplicable (no se devuelve un total incompleto)
     -20005  Habitacion / alojamiento inexistente o la habitacion no pertenece al alojamiento
     -20006  Cliente inexistente
     -20007  Parametros nulos, invalidos o repetidos
     -20008  Checkin en el pasado
   Rango reservado para este paquete: -20001 .. -20099.
   (Para el script de disparadores: usar -20101 en adelante.)

   EXCEPCIONES CON NOMBRE (declaradas en la especificacion con PRAGMA EXCEPTION_INIT)
     e_no_disponible (-20001), e_fechas (-20002), e_capacidad (-20003), e_sin_tarifa (-20004),
     e_no_existe (-20005), e_cliente (-20006), e_parametros (-20007), e_checkin_pasado (-20008)
   Quien llama puede capturarlas por nombre:  WHEN pkg_reservas.e_capacidad THEN ...

   Criterio de disponibilidad (debe coincidir con el trigger de solapamiento):
     * Una reserva CANCELADA NO bloquea la habitacion; PENDIENTE, CONFIRMADA y COMPLETADA SI.
     * Dos intervalos [in, out) se cruzan si  a.in < b.out  Y  b.in < a.out
       (el dia de checkout queda libre para un nuevo checkin).

   NOTAS DE DISENO
     * sp_crear_reserva no hace COMMIT: la transaccion la cierra quien llama. Si una validacion
       falla, los bloqueos FOR UPDATE tomados sobre las habitaciones se liberan cuando quien llama
       hace COMMIT o ROLLBACK (no se libera antes porque la transaccion es de quien llama).
     * Liquidacion: los SERVICIOS se asignan al mes del check-in de la cabecera de la reserva; el
       HOSPEDAJE se reparte por noches de cada linea. Un alojamiento con servicios pero sin ninguna
       noche en el mes no aparece en la liquidacion (caso practicamente inexistente: toda reserva
       con check-in en el mes tiene su primera noche en ese mes, salvo lineas que lleguen despues).
   ===================================================================== */

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

/* =====================================================================
   1. ESPECIFICACION DEL PAQUETE
   ===================================================================== */
CREATE OR REPLACE PACKAGE pkg_reservas AS

  -- Codigos de error de aplicacion (ver cabecera del script)
  c_err_no_disponible   CONSTANT PLS_INTEGER := -20001;
  c_err_fechas          CONSTANT PLS_INTEGER := -20002;
  c_err_capacidad       CONSTANT PLS_INTEGER := -20003;
  c_err_sin_tarifa      CONSTANT PLS_INTEGER := -20004;
  c_err_no_existe       CONSTANT PLS_INTEGER := -20005;
  c_err_cliente         CONSTANT PLS_INTEGER := -20006;
  c_err_parametros      CONSTANT PLS_INTEGER := -20007;
  c_err_checkin_pasado  CONSTANT PLS_INTEGER := -20008;

  -- Excepciones con nombre ligadas a esos codigos (se pueden capturar por nombre)
  e_no_disponible   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_no_disponible,  -20001);
  e_fechas          EXCEPTION;  PRAGMA EXCEPTION_INIT(e_fechas,         -20002);
  e_capacidad       EXCEPTION;  PRAGMA EXCEPTION_INIT(e_capacidad,      -20003);
  e_sin_tarifa      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_sin_tarifa,     -20004);
  e_no_existe       EXCEPTION;  PRAGMA EXCEPTION_INIT(e_no_existe,      -20005);
  e_cliente         EXCEPTION;  PRAGMA EXCEPTION_INIT(e_cliente,        -20006);
  e_parametros      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_parametros,     -20007);
  e_checkin_pasado  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_checkin_pasado, -20008);

  -- Una linea de reserva (una habitacion). Si las fechas van en NULL se usan las de la cabecera.
  TYPE r_linea IS RECORD (
    id_habitacion   NUMBER,
    num_huespedes   NUMBER,
    fecha_checkin   DATE,
    fecha_checkout  DATE
  );
  TYPE t_lineas IS TABLE OF r_linea INDEX BY PLS_INTEGER;

  /* fn_valor_estadia
     Suma, noche por noche, la tarifa de la habitacion en la temporada que contiene cada noche.
     La noche del check-in se cobra; la fecha de checkout NO (es el limite de salida).
     Errores: -20007 parametros nulos, -20002 checkout <= checkin, -20005 habitacion inexistente,
              -20004 si alguna noche no tiene temporada o tarifa. */
  FUNCTION fn_valor_estadia(p_id_habitacion IN NUMBER,
                            p_fecha_in      IN DATE,
                            p_fecha_out     IN DATE) RETURN NUMBER;

  /* fn_habitacion_disponible
     TRUE si ninguna reserva NO cancelada ocupa la habitacion en alguna noche de [in, out).
     Errores: -20007 parametros nulos, -20002 checkout <= checkin. */
  FUNCTION fn_habitacion_disponible(p_id_habitacion IN NUMBER,
                                    p_fecha_in      IN DATE,
                                    p_fecha_out     IN DATE) RETURN BOOLEAN;

  /* sp_crear_reserva (varias habitaciones)
     Crea la cabecera en RESERVA (estado PENDIENTE) y una linea en RESERVA_HABITACION por cada
     elemento de p_lineas, con su valor_estadia calculado por fn_valor_estadia.
     Valida TODO antes de insertar; si algo falla no queda nada insertado.
     No hace COMMIT: la transaccion la cierra quien llama. */
  PROCEDURE sp_crear_reserva(p_id_cliente     IN  NUMBER,
                             p_id_alojamiento IN  NUMBER,
                             p_fecha_checkin  IN  DATE,
                             p_fecha_checkout IN  DATE,
                             p_lineas         IN  t_lineas,
                             p_id_reserva     OUT NUMBER);

  /* sp_crear_reserva (sobrecarga: una sola habitacion) */
  PROCEDURE sp_crear_reserva(p_id_cliente     IN  NUMBER,
                             p_id_alojamiento IN  NUMBER,
                             p_id_habitacion  IN  NUMBER,
                             p_fecha_checkin  IN  DATE,
                             p_fecha_checkout IN  DATE,
                             p_num_huespedes  IN  NUMBER,
                             p_id_reserva     OUT NUMBER);

  /* pr_liquidacion_mensual
     Liquidacion de un mes por alojamiento, con un cursor explicito parametrizado
     (alojamiento, primer dia del mes, filtro de estados).
       p_anio, p_mes        mes a liquidar
       p_total              (OUT) total general liquidado (hospedaje + servicios)
       p_id_alojamiento     NULL = todos los alojamientos
       p_solo_completadas   'S' (defecto) = solo reservas COMPLETADAS (ingreso realizado)
                            'N' = todas las no canceladas (ingreso reservado)
       p_imprimir           'S' (defecto) imprime con DBMS_OUTPUT
     Hospedaje: noches de cada linea que caen dentro del mes, valoradas noche a noche con la tarifa
     de la temporada (una estadia que cruza de mes aporta a ambos meses).
     Servicios: de las reservas cuyo check-in cae en el mes. */
  PROCEDURE pr_liquidacion_mensual(p_anio             IN  NUMBER,
                                   p_mes              IN  NUMBER,
                                   p_total            OUT NUMBER,
                                   p_id_alojamiento   IN  NUMBER   DEFAULT NULL,
                                   p_solo_completadas IN  VARCHAR2 DEFAULT 'S',
                                   p_imprimir         IN  VARCHAR2 DEFAULT 'S');

END pkg_reservas;
/
SHOW ERRORS

/* =====================================================================
   2. CUERPO DEL PAQUETE
   ===================================================================== */
CREATE OR REPLACE PACKAGE BODY pkg_reservas AS

  /* ------------------------------------------------------------------
     fn_valor_estadia
     ------------------------------------------------------------------ */
  FUNCTION fn_valor_estadia(p_id_habitacion IN NUMBER,
                            p_fecha_in      IN DATE,
                            p_fecha_out     IN DATE) RETURN NUMBER IS
    v_in         DATE;
    v_out        DATE;
    v_existe     NUMBER;
    v_total      NUMBER;
    v_noches     NUMBER;
    v_sin_tarifa NUMBER;
  BEGIN
    IF p_id_habitacion IS NULL OR p_fecha_in IS NULL OR p_fecha_out IS NULL THEN
      RAISE_APPLICATION_ERROR(c_err_parametros, 'fn_valor_estadia: habitacion y fechas son obligatorias.');
    END IF;
    v_in  := TRUNC(p_fecha_in);
    v_out := TRUNC(p_fecha_out);
    IF v_out <= v_in THEN
      RAISE_APPLICATION_ERROR(c_err_fechas, 'El checkout (' || TO_CHAR(v_out, 'YYYY-MM-DD')
        || ') debe ser posterior al checkin (' || TO_CHAR(v_in, 'YYYY-MM-DD') || ').');
    END IF;

    SELECT COUNT(*) INTO v_existe FROM habitacion WHERE id_habitacion = p_id_habitacion;
    IF v_existe = 0 THEN
      RAISE_APPLICATION_ERROR(c_err_no_existe, 'La habitacion ' || p_id_habitacion || ' no existe.');
    END IF;

    -- Una fila por temporada que toca la estadia; noches del tramo = LEAST(out, fin+1) - GREATEST(in, inicio)
    SELECT NVL(SUM((LEAST(v_out, t.fecha_fin + 1) - GREATEST(v_in, t.fecha_inicio)) * tf.precio_noche), 0),
           NVL(SUM(LEAST(v_out, t.fecha_fin + 1) - GREATEST(v_in, t.fecha_inicio)), 0),
           NVL(SUM(CASE WHEN tf.precio_noche IS NULL THEN 1 ELSE 0 END), 0)
      INTO v_total, v_noches, v_sin_tarifa
      FROM temporada t
      LEFT JOIN tarifa tf ON tf.id_temporada = t.id_temporada
                         AND tf.id_habitacion = p_id_habitacion
     WHERE t.fecha_inicio < v_out
       AND t.fecha_fin   >= v_in;

    IF v_sin_tarifa > 0 THEN
      RAISE_APPLICATION_ERROR(c_err_sin_tarifa, 'La habitacion ' || p_id_habitacion
        || ' no tiene tarifa en alguna temporada de la estadia ' || TO_CHAR(v_in, 'YYYY-MM-DD')
        || ' a ' || TO_CHAR(v_out, 'YYYY-MM-DD') || '.');
    END IF;
    -- si las temporadas no cubren todas las noches (hueco) o se solapan, las noches no coinciden
    IF v_noches <> v_out - v_in THEN
      RAISE_APPLICATION_ERROR(c_err_sin_tarifa, 'Hay noches sin temporada definida entre '
        || TO_CHAR(v_in, 'YYYY-MM-DD') || ' y ' || TO_CHAR(v_out, 'YYYY-MM-DD')
        || ' (cubiertas ' || v_noches || ' de ' || (v_out - v_in) || ').');
    END IF;

    RETURN v_total;
  END fn_valor_estadia;

  /* ------------------------------------------------------------------
     fn_habitacion_disponible
     ------------------------------------------------------------------ */
  FUNCTION fn_habitacion_disponible(p_id_habitacion IN NUMBER,
                                    p_fecha_in      IN DATE,
                                    p_fecha_out     IN DATE) RETURN BOOLEAN IS
    v_choques NUMBER;
  BEGIN
    -- sin esta guarda, una comparacion con NULL nunca es verdadera y la funcion diria "disponible"
    IF p_id_habitacion IS NULL OR p_fecha_in IS NULL OR p_fecha_out IS NULL THEN
      RAISE_APPLICATION_ERROR(c_err_parametros, 'fn_habitacion_disponible: habitacion y fechas son obligatorias.');
    END IF;
    IF TRUNC(p_fecha_out) <= TRUNC(p_fecha_in) THEN
      RAISE_APPLICATION_ERROR(c_err_fechas, 'El checkout (' || TO_CHAR(TRUNC(p_fecha_out), 'YYYY-MM-DD')
        || ') debe ser posterior al checkin (' || TO_CHAR(TRUNC(p_fecha_in), 'YYYY-MM-DD') || ').');
    END IF;

    SELECT COUNT(*)
      INTO v_choques
      FROM reserva_habitacion rh
      JOIN reserva r ON r.id_reserva = rh.id_reserva
     WHERE rh.id_habitacion = p_id_habitacion
       AND r.estado <> 'CANCELADA'
       AND rh.fecha_checkin  < TRUNC(p_fecha_out)
       AND rh.fecha_checkout > TRUNC(p_fecha_in);
    RETURN v_choques = 0;
  END fn_habitacion_disponible;

  /* ------------------------------------------------------------------
     sp_crear_reserva (varias habitaciones)
     ------------------------------------------------------------------ */
  PROCEDURE sp_crear_reserva(p_id_cliente     IN  NUMBER,
                             p_id_alojamiento IN  NUMBER,
                             p_fecha_checkin  IN  DATE,
                             p_fecha_checkout IN  DATE,
                             p_lineas         IN  t_lineas,
                             p_id_reserva     OUT NUMBER) IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_vistas   t_num;                 -- habitaciones ya vistas (detecta repetidas)
    v_in       DATE;
    v_out      DATE;
    v_i        PLS_INTEGER;
    v_n        NUMBER;
    v_cap      NUMBER;
    v_aloj_hab NUMBER;
    v_li       DATE;
    v_lo       DATE;
    v_valor    NUMBER;
  BEGIN
    p_id_reserva := NULL;

    -- 1. parametros obligatorios
    IF p_id_cliente IS NULL OR p_id_alojamiento IS NULL
       OR p_fecha_checkin IS NULL OR p_fecha_checkout IS NULL THEN
      RAISE_APPLICATION_ERROR(c_err_parametros, 'Cliente, alojamiento y fechas son obligatorios.');
    END IF;
    IF p_lineas.COUNT = 0 THEN
      RAISE_APPLICATION_ERROR(c_err_parametros, 'La reserva debe incluir al menos una habitacion.');
    END IF;
    v_in  := TRUNC(p_fecha_checkin);
    v_out := TRUNC(p_fecha_checkout);

    -- 2. fechas (error exigido: checkout <= checkin)
    IF v_out <= v_in THEN
      RAISE_APPLICATION_ERROR(c_err_fechas, 'El checkout (' || TO_CHAR(v_out, 'YYYY-MM-DD')
        || ') debe ser posterior al checkin (' || TO_CHAR(v_in, 'YYYY-MM-DD') || ').');
    END IF;
    IF v_in < TRUNC(SYSDATE) THEN
      RAISE_APPLICATION_ERROR(c_err_checkin_pasado, 'El checkin ' || TO_CHAR(v_in, 'YYYY-MM-DD')
        || ' ya paso; no se pueden crear reservas en el pasado.');
    END IF;

    -- 3. cliente y alojamiento
    SELECT COUNT(*) INTO v_n FROM cliente WHERE id_cliente = p_id_cliente;
    IF v_n = 0 THEN
      RAISE_APPLICATION_ERROR(c_err_cliente, 'El cliente ' || p_id_cliente || ' no existe.');
    END IF;
    SELECT COUNT(*) INTO v_n FROM alojamiento WHERE id_alojamiento = p_id_alojamiento;
    IF v_n = 0 THEN
      RAISE_APPLICATION_ERROR(c_err_no_existe, 'El alojamiento ' || p_id_alojamiento || ' no existe.');
    END IF;

    -- 4. validar cada linea ANTES de insertar nada
    v_i := p_lineas.FIRST;
    WHILE v_i IS NOT NULL LOOP
      IF p_lineas(v_i).id_habitacion IS NULL OR p_lineas(v_i).num_huespedes IS NULL
         OR p_lineas(v_i).num_huespedes < 1 THEN
        RAISE_APPLICATION_ERROR(c_err_parametros, 'Cada linea requiere habitacion y num_huespedes >= 1.');
      END IF;
      IF v_vistas.EXISTS(p_lineas(v_i).id_habitacion) THEN
        RAISE_APPLICATION_ERROR(c_err_parametros, 'La habitacion ' || p_lineas(v_i).id_habitacion
          || ' esta repetida en la reserva.');
      END IF;
      v_vistas(p_lineas(v_i).id_habitacion) := 1;

      -- bloquea la habitacion: serializa reservas concurrentes sobre la misma habitacion
      BEGIN
        SELECT capacidad_max, id_alojamiento
          INTO v_cap, v_aloj_hab
          FROM habitacion
         WHERE id_habitacion = p_lineas(v_i).id_habitacion
           FOR UPDATE;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RAISE_APPLICATION_ERROR(c_err_no_existe, 'La habitacion ' || p_lineas(v_i).id_habitacion || ' no existe.');
      END;
      IF v_aloj_hab <> p_id_alojamiento THEN
        RAISE_APPLICATION_ERROR(c_err_no_existe, 'La habitacion ' || p_lineas(v_i).id_habitacion
          || ' no pertenece al alojamiento ' || p_id_alojamiento || '.');
      END IF;

      -- fechas propias de la linea (por defecto las de la cabecera) dentro del rango de la reserva
      v_li := TRUNC(NVL(p_lineas(v_i).fecha_checkin,  v_in));
      v_lo := TRUNC(NVL(p_lineas(v_i).fecha_checkout, v_out));
      IF v_lo <= v_li THEN
        RAISE_APPLICATION_ERROR(c_err_fechas, 'Habitacion ' || p_lineas(v_i).id_habitacion
          || ': el checkout debe ser posterior al checkin.');
      END IF;
      IF v_li < v_in OR v_lo > v_out THEN
        RAISE_APPLICATION_ERROR(c_err_fechas, 'Habitacion ' || p_lineas(v_i).id_habitacion
          || ': las fechas de la linea quedan fuera del rango de la reserva.');
      END IF;

      -- capacidad (error exigido)
      IF p_lineas(v_i).num_huespedes > v_cap THEN
        RAISE_APPLICATION_ERROR(c_err_capacidad, 'Habitacion ' || p_lineas(v_i).id_habitacion
          || ': ' || p_lineas(v_i).num_huespedes || ' huespedes exceden la capacidad maxima (' || v_cap || ').');
      END IF;

      -- disponibilidad (error exigido)
      IF NOT fn_habitacion_disponible(p_lineas(v_i).id_habitacion, v_li, v_lo) THEN
        RAISE_APPLICATION_ERROR(c_err_no_disponible, 'La habitacion ' || p_lineas(v_i).id_habitacion
          || ' no esta disponible entre ' || TO_CHAR(v_li, 'YYYY-MM-DD') || ' y ' || TO_CHAR(v_lo, 'YYYY-MM-DD') || '.');
      END IF;

      -- tarifa: falla con -20004 si alguna noche no tiene temporada/tarifa
      v_valor := fn_valor_estadia(p_lineas(v_i).id_habitacion, v_li, v_lo);

      v_i := p_lineas.NEXT(v_i);
    END LOOP;

    -- 5. todo valido: insertar cabecera y lineas
    SAVEPOINT sp_crear_reserva;
    BEGIN
      INSERT INTO reserva (id_cliente, id_alojamiento, fecha_creacion, fecha_checkin, fecha_checkout, estado)
      VALUES (p_id_cliente, p_id_alojamiento, SYSDATE, v_in, v_out, 'PENDIENTE')
      RETURNING id_reserva INTO p_id_reserva;

      v_i := p_lineas.FIRST;
      WHILE v_i IS NOT NULL LOOP
        v_li := TRUNC(NVL(p_lineas(v_i).fecha_checkin,  v_in));
        v_lo := TRUNC(NVL(p_lineas(v_i).fecha_checkout, v_out));
        INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento,
                                        fecha_checkin, fecha_checkout, num_huespedes, valor_estadia)
        VALUES (p_id_reserva, p_lineas(v_i).id_habitacion, p_id_alojamiento,
                v_li, v_lo, p_lineas(v_i).num_huespedes,
                fn_valor_estadia(p_lineas(v_i).id_habitacion, v_li, v_lo));
        v_i := p_lineas.NEXT(v_i);
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT sp_crear_reserva;   -- no deja cabecera huerfana (p.ej. si un trigger rechaza)
        p_id_reserva := NULL;
        RAISE;
    END;
  END sp_crear_reserva;

  /* ------------------------------------------------------------------
     sp_crear_reserva (una habitacion)
     ------------------------------------------------------------------ */
  PROCEDURE sp_crear_reserva(p_id_cliente     IN  NUMBER,
                             p_id_alojamiento IN  NUMBER,
                             p_id_habitacion  IN  NUMBER,
                             p_fecha_checkin  IN  DATE,
                             p_fecha_checkout IN  DATE,
                             p_num_huespedes  IN  NUMBER,
                             p_id_reserva     OUT NUMBER) IS
    v_lineas t_lineas;
  BEGIN
    v_lineas(1).id_habitacion  := p_id_habitacion;
    v_lineas(1).num_huespedes  := p_num_huespedes;
    v_lineas(1).fecha_checkin  := NULL;
    v_lineas(1).fecha_checkout := NULL;
    sp_crear_reserva(p_id_cliente, p_id_alojamiento, p_fecha_checkin, p_fecha_checkout, v_lineas, p_id_reserva);
  END sp_crear_reserva;

  /* ------------------------------------------------------------------
     pr_liquidacion_mensual  (cursor explicito con parametros)
     ------------------------------------------------------------------ */
  PROCEDURE pr_liquidacion_mensual(p_anio             IN  NUMBER,
                                   p_mes              IN  NUMBER,
                                   p_total            OUT NUMBER,
                                   p_id_alojamiento   IN  NUMBER   DEFAULT NULL,
                                   p_solo_completadas IN  VARCHAR2 DEFAULT 'S',
                                   p_imprimir         IN  VARCHAR2 DEFAULT 'S') IS

    -- Cursor explicito parametrizado: alojamiento (NULL = todos), primer dia del mes y filtro de estados
    CURSOR c_liquidacion(p_aloj NUMBER, p_inicio DATE, p_solo VARCHAR2) IS
      SELECT a.id_alojamiento,
             a.nombre_comercial,
             COUNT(DISTINCT r.id_reserva) AS reservas,
             SUM(LEAST(rh.fecha_checkout, t.fecha_fin + 1, ADD_MONTHS(p_inicio, 1))
                 - GREATEST(rh.fecha_checkin, t.fecha_inicio, p_inicio)) AS noches,
             SUM((LEAST(rh.fecha_checkout, t.fecha_fin + 1, ADD_MONTHS(p_inicio, 1))
                  - GREATEST(rh.fecha_checkin, t.fecha_inicio, p_inicio)) * tf.precio_noche) AS hospedaje,
             -- servicios de las reservas cuyo check-in cae en el mes
             NVL((SELECT SUM(rs.cantidad * rs.precio_unitario)
                    FROM reserva_servicio rs
                    JOIN reserva r2 ON r2.id_reserva = rs.id_reserva
                   WHERE rs.id_alojamiento = a.id_alojamiento
                     AND r2.fecha_checkin >= p_inicio
                     AND r2.fecha_checkin <  ADD_MONTHS(p_inicio, 1)
                     AND ((p_solo = 'S' AND r2.estado = 'COMPLETADA')
                       OR (p_solo <> 'S' AND r2.estado <> 'CANCELADA'))), 0) AS servicios
        FROM reserva_habitacion rh
        JOIN reserva r     ON r.id_reserva = rh.id_reserva
        JOIN alojamiento a ON a.id_alojamiento = rh.id_alojamiento
        JOIN temporada t   ON t.fecha_inicio < rh.fecha_checkout
                          AND t.fecha_fin   >= rh.fecha_checkin
                          AND t.fecha_inicio < ADD_MONTHS(p_inicio, 1)
                          AND t.fecha_fin   >= p_inicio
        JOIN tarifa tf     ON tf.id_habitacion = rh.id_habitacion
                          AND tf.id_temporada  = t.id_temporada
       WHERE rh.fecha_checkin  < ADD_MONTHS(p_inicio, 1)
         AND rh.fecha_checkout > p_inicio
         AND ((p_solo = 'S' AND r.estado = 'COMPLETADA')
           OR (p_solo <> 'S' AND r.estado <> 'CANCELADA'))
         AND (p_aloj IS NULL OR a.id_alojamiento = p_aloj)
       GROUP BY a.id_alojamiento, a.nombre_comercial
       ORDER BY a.nombre_comercial;

    v_inicio  DATE;
    v_solo    VARCHAR2(1);
    v_fila    c_liquidacion%ROWTYPE;
    v_filas   PLS_INTEGER := 0;
    v_tot_hosp NUMBER := 0;
    v_tot_serv NUMBER := 0;
    v_tot_noches NUMBER := 0;
    v_tot_reservas NUMBER := 0;

    PROCEDURE p(p_txt VARCHAR2) IS
    BEGIN
      IF UPPER(p_imprimir) = 'S' THEN DBMS_OUTPUT.PUT_LINE(p_txt); END IF;
    END;
  BEGIN
    IF p_anio IS NULL OR p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 THEN
      RAISE_APPLICATION_ERROR(c_err_parametros, 'Anio y mes (1-12) son obligatorios para la liquidacion.');
    END IF;
    v_inicio := TO_DATE(LPAD(p_anio, 4, '0') || LPAD(p_mes, 2, '0') || '01', 'YYYYMMDD');
    v_solo   := CASE WHEN UPPER(NVL(p_solo_completadas, 'S')) = 'N' THEN 'N' ELSE 'S' END;

    p('LIQUIDACION ' || TO_CHAR(v_inicio, 'YYYY-MM') || ' - '
      || CASE WHEN v_solo = 'S' THEN 'reservas COMPLETADAS' ELSE 'reservas no canceladas' END
      || CASE WHEN p_id_alojamiento IS NULL THEN ' - todos los alojamientos'
              ELSE ' - alojamiento ' || p_id_alojamiento END);
    p(RPAD('ALOJAMIENTO', 32) || LPAD('RESERVAS', 9) || LPAD('NOCHES', 8)
      || LPAD('HOSPEDAJE', 17) || LPAD('SERVICIOS', 15) || LPAD('TOTAL', 17));

    OPEN c_liquidacion(p_id_alojamiento, v_inicio, v_solo);
    LOOP
      FETCH c_liquidacion INTO v_fila;
      EXIT WHEN c_liquidacion%NOTFOUND;
      v_filas      := v_filas + 1;
      v_tot_hosp   := v_tot_hosp + v_fila.hospedaje;
      v_tot_serv   := v_tot_serv + v_fila.servicios;
      v_tot_noches := v_tot_noches + v_fila.noches;
      v_tot_reservas := v_tot_reservas + v_fila.reservas;
      p(RPAD(SUBSTR(v_fila.nombre_comercial, 1, 31), 32)
        || LPAD(v_fila.reservas, 9) || LPAD(v_fila.noches, 8)
        || LPAD(TO_CHAR(v_fila.hospedaje, 'FM999G999G999G990'), 17)
        || LPAD(TO_CHAR(v_fila.servicios, 'FM999G999G999G990'), 15)
        || LPAD(TO_CHAR(v_fila.hospedaje + v_fila.servicios, 'FM999G999G999G990'), 17));
    END LOOP;
    CLOSE c_liquidacion;

    p_total := v_tot_hosp + v_tot_serv;
    IF v_filas = 0 THEN
      p('(sin movimiento en el periodo)');
    ELSE
      p(RPAD('TOTAL (' || v_filas || ' alojamientos)', 32) || LPAD(v_tot_reservas, 9) || LPAD(v_tot_noches, 8)
        || LPAD(TO_CHAR(v_tot_hosp, 'FM999G999G999G990'), 17)
        || LPAD(TO_CHAR(v_tot_serv, 'FM999G999G999G990'), 15)
        || LPAD(TO_CHAR(p_total, 'FM999G999G999G990'), 17));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF c_liquidacion%ISOPEN THEN CLOSE c_liquidacion; END IF;
      RAISE;
  END pr_liquidacion_mensual;

END pkg_reservas;
/
SHOW ERRORS

-- El paquete debe quedar VALID
SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'PKG_RESERVAS' ORDER BY object_type;


/* =====================================================================
   3. PRUEBAS
   Cada prueba imprime PASA / FALLA. Todo lo que se inserta (incluido el calendario de prueba de
   2028) se deshace con ROLLBACK al final, asi que la base queda igual.
   Calendario de prueba (solo existe durante la ejecucion):
     'PRUEBA media 2028'  MEDIA  2028-01-01 .. 2028-01-14   (100.000 + 5.000 * MOD(id_habitacion,10))
     'PRUEBA alta 2028'   ALTA   2028-01-15 .. 2028-01-31   (150.000 + 5.000 * MOD(id_habitacion,10))
     'PRUEBA baja 2028'   BAJA   2028-02-01 .. 2028-02-29   ( 80.000 + 5.000 * MOD(id_habitacion,10))
   Entre 2027-01-11 y 2027-12-31 no hay temporada: sirve para las pruebas de "noche sin temporada".
   ===================================================================== */
DECLARE
  v_hab      habitacion.id_habitacion%TYPE;
  v_aloj     habitacion.id_alojamiento%TYPE;
  v_cap      habitacion.capacidad_max%TYPE;
  v_cli      cliente.id_cliente%TYPE;
  v_res      NUMBER;
  v_valor    NUMBER;
  v_esperado NUMBER;
  v_lineas   pkg_reservas.t_lineas;
  v_total    NUMBER;
  v_n1       NUMBER;
  v_n2       NUMBER;
  v_t1       NUMBER;   -- id de la temporada de prueba media
  v_t2       NUMBER;   -- id de la temporada de prueba alta
  v_t3       NUMBER;   -- id de la temporada de prueba baja
  v_disp     BOOLEAN;

  PROCEDURE ver(p_nombre VARCHAR2, p_ok BOOLEAN, p_detalle VARCHAR2 DEFAULT NULL) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD(p_nombre, 66) || CASE WHEN p_ok THEN 'PASA' ELSE 'FALLA' END
                         || CASE WHEN p_detalle IS NOT NULL THEN '  (' || p_detalle || ')' END);
  END;

  -- valor esperado calculado de forma independiente: una fila por NOCHE
  FUNCTION esperado(p_hab NUMBER, p_in DATE, p_out DATE) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT SUM(tf.precio_noche) INTO v
      FROM (SELECT p_in + LEVEL - 1 AS noche FROM dual CONNECT BY LEVEL <= p_out - p_in) n
      JOIN temporada t ON n.noche BETWEEN t.fecha_inicio AND t.fecha_fin
      JOIN tarifa tf   ON tf.id_temporada = t.id_temporada AND tf.id_habitacion = p_hab;
    RETURN v;
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== PRUEBAS PKG_RESERVAS ===');

  -- 0. calendario de prueba 2028 (se deshace con el ROLLBACK final)
  INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin)
  VALUES ('PRUEBA media 2028', 'MEDIA', 2028, DATE '2028-01-01', DATE '2028-01-14')
  RETURNING id_temporada INTO v_t1;
  INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin)
  VALUES ('PRUEBA alta 2028', 'ALTA', 2028, DATE '2028-01-15', DATE '2028-01-31')
  RETURNING id_temporada INTO v_t2;
  INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin)
  VALUES ('PRUEBA baja 2028', 'BAJA', 2028, DATE '2028-02-01', DATE '2028-02-29')
  RETURNING id_temporada INTO v_t3;
  INSERT INTO tarifa (id_habitacion, id_temporada, precio_noche)
    SELECT id_habitacion, v_t1, 100000 + 5000 * MOD(id_habitacion, 10) FROM habitacion;
  INSERT INTO tarifa (id_habitacion, id_temporada, precio_noche)
    SELECT id_habitacion, v_t2, 150000 + 5000 * MOD(id_habitacion, 10) FROM habitacion;
  INSERT INTO tarifa (id_habitacion, id_temporada, precio_noche)
    SELECT id_habitacion, v_t3,  80000 + 5000 * MOD(id_habitacion, 10) FROM habitacion;

  -- habitacion libre en el calendario de prueba (capacidad >= 2) y un cliente
  SELECT id_habitacion, id_alojamiento, capacidad_max
    INTO v_hab, v_aloj, v_cap
    FROM (SELECT h.id_habitacion, h.id_alojamiento, h.capacidad_max
            FROM habitacion h
           WHERE h.capacidad_max >= 2
             AND NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                               JOIN reserva r ON r.id_reserva = rh.id_reserva
                              WHERE rh.id_habitacion = h.id_habitacion AND r.estado <> 'CANCELADA'
                                AND rh.fecha_checkin  < DATE '2028-03-01'
                                AND rh.fecha_checkout > DATE '2028-01-01')
           ORDER BY h.id_habitacion)
   WHERE ROWNUM = 1;
  SELECT MIN(id_cliente) INTO v_cli FROM cliente;
  DBMS_OUTPUT.PUT_LINE('Habitacion de prueba: ' || v_hab || ' (alojamiento ' || v_aloj
                       || ', capacidad ' || v_cap || '), cliente ' || v_cli);

  DBMS_OUTPUT.PUT_LINE('--- fn_valor_estadia ---');

  -- F1. estadia dentro de una sola temporada (3 noches, Temporada media 3 de 2026)
  v_valor    := pkg_reservas.fn_valor_estadia(v_hab, DATE '2026-11-10', DATE '2026-11-13');
  v_esperado := esperado(v_hab, DATE '2026-11-10', DATE '2026-11-13');
  ver('F1 una temporada (3 noches)', v_valor = v_esperado, v_valor || ' = ' || v_esperado);

  -- F2. estadia que cruza de MEDIA a ALTA el 15-dic (2 noches + 2 noches)
  v_valor    := pkg_reservas.fn_valor_estadia(v_hab, DATE '2026-12-13', DATE '2026-12-17');
  v_esperado := esperado(v_hab, DATE '2026-12-13', DATE '2026-12-17');
  ver('F2 cruza de temporada (13-dic a 17-dic)', v_valor = v_esperado, v_valor || ' = ' || v_esperado);

  -- F3. estadia larga que cruza 3 temporadas (puente de nov., media 3 y alta)
  v_valor    := pkg_reservas.fn_valor_estadia(v_hab, DATE '2026-10-31', DATE '2026-12-20');
  v_esperado := esperado(v_hab, DATE '2026-10-31', DATE '2026-12-20');
  ver('F3 cruza 3 temporadas (31-oct a 20-dic)', v_valor = v_esperado, v_valor || ' = ' || v_esperado);

  -- F4. el checkout no se cobra: 1 noche = tarifa de la noche del checkin
  v_valor := pkg_reservas.fn_valor_estadia(v_hab, DATE '2026-12-14', DATE '2026-12-15');
  SELECT tf.precio_noche INTO v_esperado
    FROM temporada t JOIN tarifa tf ON tf.id_temporada = t.id_temporada AND tf.id_habitacion = v_hab
   WHERE DATE '2026-12-14' BETWEEN t.fecha_inicio AND t.fecha_fin;
  ver('F4 checkout no se cobra (noche del 14-dic)', v_valor = v_esperado, v_valor || ' = ' || v_esperado);

  -- F5. coherencia con lo cargado: recalcular 1 de cada 20 lineas (repartidas en 2024-2026)
  --     debe dar exactamente su valor_estadia
  SELECT COUNT(*),
         NVL(SUM(CASE WHEN pkg_reservas.fn_valor_estadia(id_habitacion, fecha_checkin, fecha_checkout) <> valor_estadia
                      THEN 1 ELSE 0 END), 0)
    INTO v_n2, v_n1
    FROM (SELECT rh.id_habitacion, rh.fecha_checkin, rh.fecha_checkout, rh.valor_estadia
            FROM reserva_habitacion rh WHERE MOD(rh.id_reserva_habitacion, 20) = 0);
  ver('F5 coincide con valor_estadia cargado (1 de cada 20 lineas)', v_n1 = 0, v_n1 || ' diferencias en ' || v_n2 || ' lineas');

  -- F6. sin temporada para las noches (2027-06: entre el fin de la carga y el calendario de prueba)
  BEGIN
    v_valor := pkg_reservas.fn_valor_estadia(v_hab, DATE '2027-06-10', DATE '2027-06-15');
    ver('F6 noche sin temporada -> error -20004', FALSE, 'devolvio ' || v_valor);
  EXCEPTION WHEN OTHERS THEN ver('F6 noche sin temporada -> error -20004', SQLCODE = -20004, SQLERRM);
  END;

  -- F7. checkout <= checkin
  BEGIN
    v_valor := pkg_reservas.fn_valor_estadia(v_hab, DATE '2026-11-13', DATE '2026-11-10');
    ver('F7 checkout anterior -> error -20002', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('F7 checkout anterior -> error -20002', SQLCODE = -20002, SQLERRM);
  END;

  -- F8. estadia que cruza del calendario de prueba (MEDIA -> ALTA el 15-ene-2028): 2 + 2 noches
  v_valor    := pkg_reservas.fn_valor_estadia(v_hab, DATE '2028-01-13', DATE '2028-01-17');
  SELECT 2 * (SELECT precio_noche FROM tarifa WHERE id_habitacion = v_hab AND id_temporada = v_t1)
       + 2 * (SELECT precio_noche FROM tarifa WHERE id_habitacion = v_hab AND id_temporada = v_t2)
    INTO v_esperado FROM dual;
  ver('F8 cruce media->alta con calendario de prueba (2+2 noches)', v_valor = v_esperado, v_valor || ' = ' || v_esperado);

  DBMS_OUTPUT.PUT_LINE('--- fn_habitacion_disponible ---');

  -- D1. parametros nulos ya no devuelven "disponible": error -20007
  BEGIN
    v_disp := pkg_reservas.fn_habitacion_disponible(v_hab, NULL, DATE '2028-01-10');
    ver('D1 parametros nulos -> error -20007', FALSE, 'devolvio ' || CASE WHEN v_disp THEN 'TRUE' ELSE 'FALSE' END);
  EXCEPTION WHEN OTHERS THEN ver('D1 parametros nulos -> error -20007', SQLCODE = -20007, SQLERRM);
  END;

  -- D2. checkout <= checkin: error -20002
  BEGIN
    v_disp := pkg_reservas.fn_habitacion_disponible(v_hab, DATE '2028-01-10', DATE '2028-01-10');
    ver('D2 checkout = checkin -> error -20002', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('D2 checkout = checkin -> error -20002', SQLCODE = -20002, SQLERRM);
  END;

  -- D3. habitacion libre en el calendario de prueba
  ver('D3 habitacion libre -> TRUE',
      pkg_reservas.fn_habitacion_disponible(v_hab, DATE '2028-01-05', DATE '2028-01-07'));

  DBMS_OUTPUT.PUT_LINE('--- sp_crear_reserva ---');

  -- R1. reserva valida (una habitacion, cruza de temporada media a alta)
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-13', DATE '2028-01-17', 1, v_res);
    SELECT valor_estadia INTO v_valor FROM reserva_habitacion WHERE id_reserva = v_res AND id_habitacion = v_hab;
    ver('R1 reserva valida', v_res IS NOT NULL AND v_valor = esperado(v_hab, DATE '2028-01-13', DATE '2028-01-17'),
        'id_reserva=' || v_res || ', valor=' || v_valor);
  EXCEPTION WHEN OTHERS THEN ver('R1 reserva valida', FALSE, SQLERRM);
  END;

  -- R2. misma habitacion y fechas que solapan -> no disponible (se captura por NOMBRE)
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-15', DATE '2028-01-18', 1, v_res);
    ver('R2 habitacion no disponible -> e_no_disponible (-20001)', FALSE);
  EXCEPTION
    WHEN pkg_reservas.e_no_disponible THEN ver('R2 habitacion no disponible -> e_no_disponible (-20001)', SQLCODE = -20001, SQLERRM);
    WHEN OTHERS THEN ver('R2 habitacion no disponible -> e_no_disponible (-20001)', FALSE, SQLERRM);
  END;

  -- R3. checkin del nuevo = checkout de la anterior: SI es posible (el dia de salida queda libre)
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-17', DATE '2028-01-19', 1, v_res);
    ver('R3 checkin el dia del checkout anterior es valido', v_res IS NOT NULL, 'id_reserva=' || v_res);
  EXCEPTION WHEN OTHERS THEN ver('R3 checkin el dia del checkout anterior es valido', FALSE, SQLERRM);
  END;

  -- R4. checkout igual al checkin (se captura por NOMBRE)
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-05', DATE '2028-01-05', 1, v_res);
    ver('R4 checkout = checkin -> e_fechas (-20002)', FALSE);
  EXCEPTION
    WHEN pkg_reservas.e_fechas THEN ver('R4 checkout = checkin -> e_fechas (-20002)', SQLCODE = -20002, SQLERRM);
    WHEN OTHERS THEN ver('R4 checkout = checkin -> e_fechas (-20002)', FALSE, SQLERRM);
  END;

  -- R5. checkout anterior al checkin
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-07', DATE '2028-01-05', 1, v_res);
    ver('R5 checkout < checkin -> error -20002', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('R5 checkout < checkin -> error -20002', SQLCODE = -20002, SQLERRM);
  END;

  -- R6. capacidad excedida (se captura por NOMBRE)
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-05', DATE '2028-01-07', v_cap + 1, v_res);
    ver('R6 capacidad excedida -> e_capacidad (-20003)', FALSE);
  EXCEPTION
    WHEN pkg_reservas.e_capacidad THEN ver('R6 capacidad excedida -> e_capacidad (-20003)', SQLCODE = -20003, SQLERRM);
    WHEN OTHERS THEN ver('R6 capacidad excedida -> e_capacidad (-20003)', FALSE, SQLERRM);
  END;

  -- R7. checkin en el pasado
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2024-03-01', DATE '2024-03-03', 1, v_res);
    ver('R7 checkin en el pasado -> error -20008', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('R7 checkin en el pasado -> error -20008', SQLCODE = -20008, SQLERRM);
  END;

  -- R8. cliente inexistente
  BEGIN
    pkg_reservas.sp_crear_reserva(-1, v_aloj, v_hab, DATE '2028-01-05', DATE '2028-01-07', 1, v_res);
    ver('R8 cliente inexistente -> error -20006', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('R8 cliente inexistente -> error -20006', SQLCODE = -20006, SQLERRM);
  END;

  -- R9. habitacion de otro alojamiento
  BEGIN
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj + 1, v_hab, DATE '2028-01-05', DATE '2028-01-07', 1, v_res);
    ver('R9 habitacion no es del alojamiento -> error -20005', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('R9 habitacion no es del alojamiento -> error -20005', SQLCODE = -20005, SQLERRM);
  END;

  -- R10. sin temporada en las noches -> no queda nada insertado
  BEGIN
    SELECT COUNT(*) INTO v_n1 FROM reserva;
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2027-06-10', DATE '2027-06-15', 1, v_res);
    ver('R10 sin tarifa -> error -20004 y nada insertado', FALSE);
  EXCEPTION WHEN OTHERS THEN
    SELECT COUNT(*) INTO v_n2 FROM reserva;
    ver('R10 sin tarifa -> error -20004 y nada insertado', SQLCODE = -20004 AND v_n1 = v_n2, SQLERRM);
  END;

  -- R11. reserva de TRES habitaciones con fechas propias por linea: la 2a llega un dia despues
  --      y la 3a sale un dia antes. Se elige un alojamiento con >= 3 habitaciones libres en la ventana.
  DECLARE
    v_aloj2  alojamiento.id_alojamiento%TYPE;
    v_l      pkg_reservas.t_lineas;
    v_k2     PLS_INTEGER := 0;
    v_res2   NUMBER;
    v_lin    NUMBER;
    v_val_ok NUMBER;
    v_fec_ok NUMBER;
    v_cab_ok NUMBER;
    v_h1     NUMBER;
    v_h2     NUMBER;
    v_h3     NUMBER;
  BEGIN
    SELECT id_alojamiento INTO v_aloj2
      FROM (SELECT h.id_alojamiento
              FROM habitacion h
             WHERE NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                                   JOIN reserva rr ON rr.id_reserva = rh.id_reserva
                                  WHERE rh.id_habitacion = h.id_habitacion AND rr.estado <> 'CANCELADA'
                                    AND rh.fecha_checkin  < DATE '2028-01-28'
                                    AND rh.fecha_checkout > DATE '2028-01-20')
             GROUP BY h.id_alojamiento
            HAVING COUNT(*) >= 3
             ORDER BY h.id_alojamiento)
     WHERE ROWNUM = 1;

    FOR r IN (SELECT h.id_habitacion
                FROM habitacion h
               WHERE h.id_alojamiento = v_aloj2
                 AND NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                                   JOIN reserva rr ON rr.id_reserva = rh.id_reserva
                                  WHERE rh.id_habitacion = h.id_habitacion AND rr.estado <> 'CANCELADA'
                                    AND rh.fecha_checkin  < DATE '2028-01-28'
                                    AND rh.fecha_checkout > DATE '2028-01-20')
               ORDER BY h.id_habitacion) LOOP
      EXIT WHEN v_k2 = 3;
      v_k2 := v_k2 + 1;
      v_l(v_k2).id_habitacion  := r.id_habitacion;
      v_l(v_k2).num_huespedes  := 1;
      v_l(v_k2).fecha_checkin  := CASE WHEN v_k2 = 2 THEN DATE '2028-01-25' END;   -- llega un dia despues
      v_l(v_k2).fecha_checkout := CASE WHEN v_k2 = 3 THEN DATE '2028-01-26' END;   -- sale un dia antes
    END LOOP;

    v_h1 := v_l(1).id_habitacion;  v_h2 := v_l(2).id_habitacion;  v_h3 := v_l(3).id_habitacion;
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj2, DATE '2028-01-24', DATE '2028-01-27', v_l, v_res2);

    SELECT COUNT(*) INTO v_lin FROM reserva_habitacion WHERE id_reserva = v_res2;
    -- cada linea guarda el valor de fn_valor_estadia con SUS fechas
    SELECT COUNT(*) INTO v_val_ok
      FROM reserva_habitacion rh
     WHERE rh.id_reserva = v_res2
       AND rh.valor_estadia = pkg_reservas.fn_valor_estadia(rh.id_habitacion, rh.fecha_checkin, rh.fecha_checkout);
    -- cada linea quedo con las fechas esperadas
    SELECT COUNT(*) INTO v_fec_ok
      FROM reserva_habitacion rh
     WHERE rh.id_reserva = v_res2
       AND ((rh.id_habitacion = v_h1 AND rh.fecha_checkin = DATE '2028-01-24' AND rh.fecha_checkout = DATE '2028-01-27')
         OR (rh.id_habitacion = v_h2 AND rh.fecha_checkin = DATE '2028-01-25' AND rh.fecha_checkout = DATE '2028-01-27')
         OR (rh.id_habitacion = v_h3 AND rh.fecha_checkin = DATE '2028-01-24' AND rh.fecha_checkout = DATE '2028-01-26'));
    -- cabecera: PENDIENTE y con el rango general
    SELECT COUNT(*) INTO v_cab_ok
      FROM reserva
     WHERE id_reserva = v_res2 AND id_alojamiento = v_aloj2 AND estado = 'PENDIENTE'
       AND fecha_checkin = DATE '2028-01-24' AND fecha_checkout = DATE '2028-01-27';
    ver('R11 reserva de 3 habitaciones con fechas propias por linea',
        v_lin = 3 AND v_val_ok = 3 AND v_fec_ok = 3 AND v_cab_ok = 1,
        'alojamiento ' || v_aloj2 || ', lineas=' || v_lin || ', valores ok=' || v_val_ok
        || ', fechas ok=' || v_fec_ok || ', cabecera ok=' || v_cab_ok);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('R11 omitida: ningun alojamiento tiene 3 habitaciones libres en la ventana');
    WHEN OTHERS THEN
      ver('R11 reserva de 3 habitaciones con fechas propias por linea', FALSE, SQLERRM);
  END;

  -- R12. una linea con fechas fuera del rango de la cabecera se rechaza (-20002)
  BEGIN
    v_lineas.DELETE;
    v_lineas(1).id_habitacion  := v_hab;
    v_lineas(1).num_huespedes  := 1;
    v_lineas(1).fecha_checkin  := DATE '2028-01-03';
    v_lineas(1).fecha_checkout := DATE '2028-01-09';
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, DATE '2028-01-05', DATE '2028-01-07', v_lineas, v_res);
    ver('R12 linea fuera del rango de la reserva -> error -20002', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('R12 linea fuera del rango de la reserva -> error -20002', SQLCODE = -20002, SQLERRM);
  END;

  -- R13. la misma habitacion repetida en dos lineas se rechaza (-20007)
  BEGIN
    v_lineas.DELETE;
    v_lineas(1).id_habitacion := v_hab;  v_lineas(1).num_huespedes := 1;
    v_lineas(2).id_habitacion := v_hab;  v_lineas(2).num_huespedes := 1;
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, DATE '2028-01-05', DATE '2028-01-07', v_lineas, v_res);
    ver('R13 habitacion repetida en la reserva -> error -20007', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('R13 habitacion repetida en la reserva -> error -20007', SQLCODE = -20007, SQLERRM);
  END;

  -- R14. temporada SIN tarifa para la habitacion (se borra la tarifa y se deshace con el savepoint)
  BEGIN
    SAVEPOINT antes_tarifa;
    DELETE FROM tarifa WHERE id_habitacion = v_hab AND id_temporada = v_t1;
    pkg_reservas.sp_crear_reserva(v_cli, v_aloj, v_hab, DATE '2028-01-04', DATE '2028-01-06', 1, v_res);
    ROLLBACK TO SAVEPOINT antes_tarifa;
    ver('R14 temporada sin tarifa -> error -20004', FALSE);
  EXCEPTION WHEN OTHERS THEN
    ver('R14 temporada sin tarifa -> error -20004',
        SQLCODE = -20004 AND INSTR(SQLERRM, 'no tiene tarifa') > 0, SQLERRM);
    ROLLBACK TO SAVEPOINT antes_tarifa;
  END;

  DBMS_OUTPUT.PUT_LINE('--- pr_liquidacion_mensual (cursor explicito con parametros) ---');

  -- L1. todos los alojamientos, julio 2025 (temporada alta de mitad de anio)
  pkg_reservas.pr_liquidacion_mensual(p_anio => 2025, p_mes => 7, p_total => v_total);

  -- L2. verificacion INDEPENDIENTE: se cuenta noche a noche (calendario de noches x temporada x
  --     tarifa), distinto de la formula por tramos que usa el cursor.
  DECLARE
    v_tot2     NUMBER;
    v_noch     NUMBER;
    v_noch_cal NUMBER;
    v_hosp     NUMBER;
    v_serv     NUMBER;
  BEGIN
    -- noches COMPLETADAS dentro del mes segun el recorte por rango de cada linea
    SELECT NVL(SUM(LEAST(rh.fecha_checkout, DATE '2025-08-01') - GREATEST(rh.fecha_checkin, DATE '2025-07-01')), 0)
      INTO v_noch
      FROM reserva_habitacion rh
      JOIN reserva r ON r.id_reserva = rh.id_reserva
     WHERE r.estado = 'COMPLETADA'
       AND rh.fecha_checkin < DATE '2025-08-01' AND rh.fecha_checkout > DATE '2025-07-01';

    -- hospedaje y noches contadas una por una con su temporada y tarifa
    SELECT NVL(SUM(tf.precio_noche), 0), COUNT(*)
      INTO v_hosp, v_noch_cal
      FROM reserva_habitacion rh
      JOIN reserva r ON r.id_reserva = rh.id_reserva
      JOIN (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 60) d
        ON d.n < rh.fecha_checkout - rh.fecha_checkin
      JOIN temporada t ON rh.fecha_checkin + d.n BETWEEN t.fecha_inicio AND t.fecha_fin
      JOIN tarifa tf   ON tf.id_temporada = t.id_temporada AND tf.id_habitacion = rh.id_habitacion
     WHERE r.estado = 'COMPLETADA'
       AND rh.fecha_checkin + d.n >= DATE '2025-07-01'
       AND rh.fecha_checkin + d.n <  DATE '2025-08-01';

    SELECT NVL(SUM(rs.cantidad * rs.precio_unitario), 0) INTO v_serv
      FROM reserva_servicio rs JOIN reserva r ON r.id_reserva = rs.id_reserva
     WHERE r.estado = 'COMPLETADA' AND r.fecha_checkin >= DATE '2025-07-01' AND r.fecha_checkin < DATE '2025-08-01';

    pkg_reservas.pr_liquidacion_mensual(p_anio => 2025, p_mes => 7, p_total => v_tot2, p_imprimir => 'N');

    ver('L2 total liquidacion = hospedaje + servicios (noche a noche)',
        v_tot2 = v_hosp + v_serv, v_tot2 || ' = ' || (v_hosp + v_serv));
    ver('L2b todas las noches COMPLETADAS del mes tienen temporada y tarifa',
        v_noch_cal = v_noch, v_noch_cal || ' = ' || v_noch || ' noches');
  END;

  -- L3. un solo alojamiento (el de la habitacion de prueba), reservas no canceladas, enero 2028
  --     (incluye las reservas de prueba R1 y R3, aun sin ROLLBACK), contra un calculo independiente
  --     noche a noche y contra la suma de los valor_estadia guardados por sp_crear_reserva.
  DECLARE
    v_hosp   NUMBER;
    v_serv   NUMBER;
    v_sumval NUMBER;
  BEGIN
    pkg_reservas.pr_liquidacion_mensual(p_anio => 2028, p_mes => 1, p_total => v_total,
                                        p_id_alojamiento => v_aloj, p_solo_completadas => 'N');
    SELECT NVL(SUM(tf.precio_noche), 0) INTO v_hosp
      FROM reserva_habitacion rh
      JOIN reserva r ON r.id_reserva = rh.id_reserva
      JOIN (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 60) d
        ON d.n < rh.fecha_checkout - rh.fecha_checkin
      JOIN temporada t ON rh.fecha_checkin + d.n BETWEEN t.fecha_inicio AND t.fecha_fin
      JOIN tarifa tf   ON tf.id_temporada = t.id_temporada AND tf.id_habitacion = rh.id_habitacion
     WHERE r.estado <> 'CANCELADA' AND rh.id_alojamiento = v_aloj
       AND rh.fecha_checkin + d.n >= DATE '2028-01-01'
       AND rh.fecha_checkin + d.n <  DATE '2028-02-01';
    SELECT NVL(SUM(rs.cantidad * rs.precio_unitario), 0) INTO v_serv
      FROM reserva_servicio rs JOIN reserva r ON r.id_reserva = rs.id_reserva
     WHERE r.estado <> 'CANCELADA' AND rs.id_alojamiento = v_aloj
       AND r.fecha_checkin >= DATE '2028-01-01' AND r.fecha_checkin < DATE '2028-02-01';
    ver('L3 liquidacion de un alojamiento (ene-2028, reservadas)',
        v_total > 0 AND v_total = v_hosp + v_serv, 'total=' || v_total || ' esperado=' || (v_hosp + v_serv));

    -- las lineas de R1 y R3 caen enteras en enero: el total debe ser la suma de sus valor_estadia
    SELECT NVL(SUM(rh.valor_estadia), 0) INTO v_sumval
      FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
     WHERE r.estado <> 'CANCELADA' AND rh.id_alojamiento = v_aloj
       AND rh.fecha_checkin >= DATE '2028-01-01' AND rh.fecha_checkout <= DATE '2028-02-01';
    ver('L3b total = suma de valor_estadia de las reservas de enero',
        v_total = v_sumval + v_serv, 'total=' || v_total || ' suma=' || (v_sumval + v_serv));
  END;

  -- L4. mes invalido
  BEGIN
    pkg_reservas.pr_liquidacion_mensual(p_anio => 2025, p_mes => 13, p_total => v_total);
    ver('L4 mes invalido -> error -20007', FALSE);
  EXCEPTION WHEN OTHERS THEN ver('L4 mes invalido -> error -20007', SQLCODE = -20007, SQLERRM);
  END;

  ROLLBACK;   -- deshace las reservas de prueba y el calendario de prueba 2028
  DBMS_OUTPUT.PUT_LINE('=== FIN (se hizo ROLLBACK de las reservas y del calendario de prueba) ===');
END;
/

/* ============================ FIN DEL SCRIPT 01 ============================ */
