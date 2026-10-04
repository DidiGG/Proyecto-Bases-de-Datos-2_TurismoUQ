/* =====================================================================
   PROYECTO INTEGRADOR TurismoUQ - Bases de Datos II (Universidad del Quindio)
   Entrega 1 - Script 03: CONSULTAS DE ANALISIS (7 consultas)

 
   ===================================================================== */

SET LINESIZE 250
SET PAGESIZE 200
SET VERIFY OFF
SET FEEDBACK ON
COLUMN municipio       FORMAT A14
COLUMN nombre_comercial FORMAT A32
COLUMN tipo            FORMAT A16
COLUMN ingresos        FORMAT 999,999,999,999
COLUMN ingreso         FORMAT 999,999,999,999
-- formatos de porcentajes/decimales (solo presentacion: evitan ',4' sin cero y negativos desalineados)
COLUMN var_pct_mensual   FORMAT 99990.0
COLUMN var_pct_anual     FORMAT 99990.0
COLUMN pct_del_municipio FORMAT 990.0
COLUMN pct_del_tipo      FORMAT 990.0
COLUMN ocupacion_pct     FORMAT 990.0
COLUMN calif_promedio    FORMAT 0.00
COLUMN ene FORMAT 990.0
COLUMN feb FORMAT 990.0
COLUMN mar FORMAT 990.0
COLUMN abr FORMAT 990.0
COLUMN may FORMAT 990.0
COLUMN jun FORMAT 990.0
COLUMN jul FORMAT 990.0
COLUMN ago FORMAT 990.0
COLUMN sep FORMAT 990.0
COLUMN oct FORMAT 990.0
COLUMN nov FORMAT 990.0
COLUMN dic FORMAT 990.0


/* =====================================================================
   CONSULTA 1 - PIVOT: OCUPACION POR MUNICIPIO Y MES
   Pregunta de negocio: ¿que porcentaje de la capacidad hotelera de cada municipio se ocupa
   en cada mes del año?
   Definicion:
     ocupacion % = noches-habitacion ocupadas / (habitaciones del municipio x dias del mes)
     * Ocupadas: noches de las lineas de RESERVA_HABITACION de reservas NO canceladas, repartidas
       por mes con las fechas de CADA LINEA (no las de la cabecera), como pide el MER. Una linea
       que cruza de un mes a otro aporta noches a ambos meses.
       noches en el mes = LEAST(checkout, inicio_mes_siguiente) - GREATEST(checkin, inicio_mes)
     * Incluye reservas futuras ya hechas (CONFIRMADA/PENDIENTE), o sea ocupacion "reservada".
   Tecnica: PIVOT convierte los 12 meses en columnas (ENE..DIC), una fila por municipio y año.
   ===================================================================== */
WITH meses AS (   -- calendario de los 36 meses 2024-01 .. 2026-12
  SELECT ADD_MONTHS(DATE '2024-01-01', LEVEL - 1) AS ini
    FROM dual CONNECT BY LEVEL <= 36
),
hab_mun AS (      -- capacidad instalada: habitaciones por municipio
  SELECT a.id_municipio, COUNT(*) AS habitaciones
    FROM habitacion h
    JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
   GROUP BY a.id_municipio
),
ocupadas AS (     -- noches-habitacion ocupadas por municipio y mes
  SELECT a.id_municipio, me.ini,
         SUM(LEAST(rh.fecha_checkout, ADD_MONTHS(me.ini, 1)) - GREATEST(rh.fecha_checkin, me.ini)) AS noches_ocupadas
    FROM reserva_habitacion rh
    JOIN reserva r     ON r.id_reserva = rh.id_reserva
    JOIN alojamiento a ON a.id_alojamiento = rh.id_alojamiento
    JOIN meses me      ON rh.fecha_checkin  < ADD_MONTHS(me.ini, 1)
                      AND rh.fecha_checkout > me.ini
   WHERE r.estado <> 'CANCELADA'
   GROUP BY a.id_municipio, me.ini
)
SELECT *
  FROM (SELECT m.nombre AS municipio,
               EXTRACT(YEAR  FROM me.ini) AS anio,
               EXTRACT(MONTH FROM me.ini) AS mes,
               ROUND(100 * NVL(o.noches_ocupadas, 0) / (hm.habitaciones * (ADD_MONTHS(me.ini, 1) - me.ini)), 1) AS ocupacion_pct
          FROM municipio m
          JOIN hab_mun hm ON hm.id_municipio = m.id_municipio
         CROSS JOIN meses me
          LEFT JOIN ocupadas o ON o.id_municipio = m.id_municipio AND o.ini = me.ini)
       PIVOT (MAX(ocupacion_pct) FOR mes IN (1 AS ene, 2 AS feb, 3 AS mar, 4 AS abr, 5 AS may, 6 AS jun,
                                             7 AS jul, 8 AS ago, 9 AS sep, 10 AS oct, 11 AS nov, 12 AS dic))
 ORDER BY anio, municipio;


/* =====================================================================
   CONSULTA 2 - ROLLUP con GROUPING: INGRESOS POR MUNICIPIO, TIPO DE ALOJAMIENTO Y TEMPORADA
   Pregunta de negocio: ¿cuanto se factura por municipio, desglosado por tipo de alojamiento y
   categoria de temporada, con subtotales por (municipio, tipo), por municipio y gran total?
   Tecnica: ROLLUP(municipio, tipo, categoria) genera la jerarquia de subtotales de derecha a
   izquierda. GROUPING(col) = 1 marca que esa columna fue "colapsada" en la fila (es un
   subtotal); asi se distingue de un NULL real y se rotula cada nivel.
   El ingreso por temporada es noche a noche (ver criterios comunes).
   Nivel (GROUPING_ID): 0 = detalle, 1 = subtotal municipio+tipo, 3 = subtotal municipio, 7 = gran total.
   ===================================================================== */
WITH ingreso_tramo AS (
  SELECT m.nombre  AS nom_municipio,   -- (no llamarla 'municipio': chocaria con el alias del SELECT final en el ORDER BY)
         ta.nombre AS tipo,
         t.categoria,
         (LEAST(rh.fecha_checkout, t.fecha_fin + 1) - GREATEST(rh.fecha_checkin, t.fecha_inicio)) AS noches,
         (LEAST(rh.fecha_checkout, t.fecha_fin + 1) - GREATEST(rh.fecha_checkin, t.fecha_inicio))
           * tf.precio_noche AS ingreso
    FROM reserva_habitacion rh
    JOIN reserva r            ON r.id_reserva = rh.id_reserva
    JOIN alojamiento a        ON a.id_alojamiento = rh.id_alojamiento
    JOIN municipio m          ON m.id_municipio = a.id_municipio
    JOIN tipo_alojamiento ta  ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
    JOIN temporada t          ON t.fecha_inicio < rh.fecha_checkout
                             AND t.fecha_fin   >= rh.fecha_checkin
    JOIN tarifa tf            ON tf.id_habitacion = rh.id_habitacion
                             AND tf.id_temporada  = t.id_temporada
   WHERE r.estado = 'COMPLETADA'
)
SELECT CASE WHEN GROUPING(nom_municipio) = 1 THEN 'GRAN TOTAL' ELSE nom_municipio END AS municipio,
       CASE WHEN GROUPING(tipo) = 1 AND GROUPING(nom_municipio) = 0 THEN '-- Subtotal municipio --'
            WHEN GROUPING(tipo) = 1 THEN NULL
            ELSE tipo END AS tipo_alojamiento,
       CASE WHEN GROUPING(categoria) = 1 AND GROUPING(tipo) = 0 THEN '-- Subtotal tipo --'
            WHEN GROUPING(categoria) = 1 THEN NULL
            ELSE categoria END AS temporada,
       SUM(noches)  AS noches_vendidas,
       SUM(ingreso) AS ingresos,
       GROUPING_ID(nom_municipio, tipo, categoria) AS nivel
  FROM ingreso_tramo
 GROUP BY ROLLUP (nom_municipio, tipo, categoria)
 ORDER BY GROUPING(nom_municipio), nom_municipio, GROUPING(tipo), tipo, GROUPING(categoria), categoria;


/* =====================================================================
   CONSULTA 3 - RANK con PARTITION BY
   Pregunta de negocio: ¿cuales son los 3 alojamientos que mas ingresan dentro de cada
   municipio, y que parte del ingreso municipal concentran?
   Tecnica: RANK() OVER (PARTITION BY municipio ORDER BY ingresos DESC) reinicia el ranking
   en cada municipio; el RANK global (sin PARTITION) permite comparar contra todo el
   departamento. RANK deja huecos en empates (1,1,3), a diferencia de DENSE_RANK.
   Lectura: Genova solo tiene 1 alojamiento, por eso aparece un unico puesto.
   ===================================================================== */
WITH ingreso_aloj AS (
  SELECT a.id_alojamiento,
         a.nombre_comercial,
         m.nombre AS municipio,
         ta.nombre AS tipo,
         COUNT(DISTINCT r.id_reserva) AS reservas,
         SUM(rh.valor_estadia)        AS ingresos
    FROM reserva_habitacion rh
    JOIN reserva r            ON r.id_reserva = rh.id_reserva
    JOIN alojamiento a        ON a.id_alojamiento = rh.id_alojamiento
    JOIN municipio m          ON m.id_municipio = a.id_municipio
    JOIN tipo_alojamiento ta  ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
   WHERE r.estado = 'COMPLETADA'
   GROUP BY a.id_alojamiento, a.nombre_comercial, m.nombre, ta.nombre
)
SELECT municipio,
       puesto_municipio,
       nombre_comercial,
       tipo,
       reservas,
       ingresos,
       pct_del_municipio,
       puesto_departamento
  FROM (SELECT municipio, nombre_comercial, tipo, reservas, ingresos,
               RANK() OVER (PARTITION BY municipio ORDER BY ingresos DESC) AS puesto_municipio,
               ROUND(100 * ingresos / SUM(ingresos) OVER (PARTITION BY municipio), 1) AS pct_del_municipio,
               RANK() OVER (ORDER BY ingresos DESC) AS puesto_departamento
          FROM ingreso_aloj)
 WHERE puesto_municipio <= 3
 ORDER BY municipio, puesto_municipio;


/* =====================================================================
   CONSULTA 4 - LAG
   Pregunta de negocio: ¿como evolucionan los ingresos mes a mes, y como se comparan contra
   el mes anterior y contra el mismo mes del año anterior?
   Tecnica: LAG(ingresos, 1) trae el valor del mes previo y LAG(ingresos, 12) el de hace un
   año, sobre los meses ordenados cronologicamente (todos los meses tienen datos, por eso
   12 posiciones atras = mismo mes del año anterior).
   Lectura: la variacion anual elimina el efecto estacional (Semana Santa, mitad de año,
   dic-ene); la mensual lo muestra. Los primeros 12 meses no tienen comparativo anual (NULL).
   El mes se toma por fecha de check-in de la linea. Se excluye el mes de corte (oct/2026) por estar incompleto.
   ===================================================================== */
WITH mensual AS (
  SELECT TRUNC(rh.fecha_checkin, 'MM') AS mes,
         COUNT(DISTINCT r.id_reserva)  AS reservas,
         SUM(rh.valor_estadia)         AS ingresos
    FROM reserva_habitacion rh
    JOIN reserva r ON r.id_reserva = rh.id_reserva
   WHERE r.estado = 'COMPLETADA'
     AND rh.fecha_checkin < TRUNC(DATE '2026-10-04', 'MM')   -- excluye octubre/2026: mes incompleto (corte 4/oct) que distorsiona la variacion
   GROUP BY TRUNC(rh.fecha_checkin, 'MM')
)
SELECT TO_CHAR(mes, 'YYYY-MM') AS mes,
       reservas,
       ingresos,
       LAG(ingresos, 1)  OVER (ORDER BY mes) AS ingresos_mes_anterior,
       ROUND(100 * (ingresos - LAG(ingresos, 1) OVER (ORDER BY mes))
                 / NULLIF(LAG(ingresos, 1) OVER (ORDER BY mes), 0), 1) AS var_pct_mensual,
       LAG(ingresos, 12) OVER (ORDER BY mes) AS ingresos_mismo_mes_anio_ant,
       ROUND(100 * (ingresos - LAG(ingresos, 12) OVER (ORDER BY mes))
                 / NULLIF(LAG(ingresos, 12) OVER (ORDER BY mes), 0), 1) AS var_pct_anual
  FROM mensual
 ORDER BY mes;


/* =====================================================================
   CONSULTA 5 - CONSULTA PARAMETRIZADA CON VARIABLES DE ENLACE (BIND)
   Pregunta de negocio: dado un rango de fechas elegido por el usuario, ¿cuanto ingreso,
   cuantas noches y que ocupacion tiene cada municipio dentro de ese rango?
   Variables de enlace (se declaran con VARIABLE y se asignan con EXEC; cambie los valores y
   vuelva a ejecutar; en SQL Developer tambien puede ejecutar solo el SELECT con F9 y le
   pedira los valores de :p_fecha_inicio y :p_fecha_fin):
     :p_fecha_inicio  primer dia del rango (AAAA-MM-DD)
     :p_fecha_fin     ultimo dia del rango, inclusive (AAAA-MM-DD). Rango valido: 2024-01-01 .. 2027-01-10
   Logica:
     * Cuenta reservas NO canceladas (ingreso reservado). Cada linea se recorta al rango:
       solo se cobran las noches que caen dentro de [inicio, fin], y por temporada, noche a noche,
       con la TARIFA de la habitacion; una estadia que cruza el limite del rango o de una
       temporada aporta solo la parte que corresponde.
     * Ocupacion % = noches vendidas / (habitaciones del municipio x dias del rango).
   Los valores por defecto cubren la temporada alta de mitad de año 2025.
   ===================================================================== */
VARIABLE p_fecha_inicio VARCHAR2(10)
VARIABLE p_fecha_fin    VARCHAR2(10)
EXEC :p_fecha_inicio := '2025-06-15';
EXEC :p_fecha_fin    := '2025-07-15';

WITH hab_mun AS (
  SELECT a.id_municipio, COUNT(*) AS habitaciones
    FROM habitacion h
    JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
   GROUP BY a.id_municipio
),
tramo AS (
  SELECT a.id_municipio,
         r.id_reserva,
         LEAST(rh.fecha_checkout, t.fecha_fin + 1, TO_DATE(:p_fecha_fin, 'YYYY-MM-DD') + 1)
           - GREATEST(rh.fecha_checkin, t.fecha_inicio, TO_DATE(:p_fecha_inicio, 'YYYY-MM-DD')) AS noches,
         (LEAST(rh.fecha_checkout, t.fecha_fin + 1, TO_DATE(:p_fecha_fin, 'YYYY-MM-DD') + 1)
           - GREATEST(rh.fecha_checkin, t.fecha_inicio, TO_DATE(:p_fecha_inicio, 'YYYY-MM-DD')))
           * tf.precio_noche AS ingreso
    FROM reserva_habitacion rh
    JOIN reserva r     ON r.id_reserva = rh.id_reserva
    JOIN alojamiento a ON a.id_alojamiento = rh.id_alojamiento
    JOIN temporada t   ON t.fecha_inicio < rh.fecha_checkout
                      AND t.fecha_fin   >= rh.fecha_checkin
                      AND t.fecha_inicio < TO_DATE(:p_fecha_fin, 'YYYY-MM-DD') + 1
                      AND t.fecha_fin   >= TO_DATE(:p_fecha_inicio, 'YYYY-MM-DD')
    JOIN tarifa tf     ON tf.id_habitacion = rh.id_habitacion
                      AND tf.id_temporada  = t.id_temporada
   WHERE r.estado <> 'CANCELADA'
     AND rh.fecha_checkin  < TO_DATE(:p_fecha_fin, 'YYYY-MM-DD') + 1
     AND rh.fecha_checkout > TO_DATE(:p_fecha_inicio, 'YYYY-MM-DD')
)
SELECT m.nombre AS municipio,
       COUNT(DISTINCT tr.id_reserva) AS reservas,
       SUM(tr.noches)                AS noches_vendidas,
       SUM(tr.ingreso)               AS ingresos,
       ROUND(SUM(tr.ingreso) / NULLIF(SUM(tr.noches), 0)) AS precio_promedio_noche,
       ROUND(100 * SUM(tr.noches)
             / (hm.habitaciones * (TO_DATE(:p_fecha_fin, 'YYYY-MM-DD') - TO_DATE(:p_fecha_inicio, 'YYYY-MM-DD') + 1)), 1) AS ocupacion_pct
  FROM tramo tr
  JOIN municipio m ON m.id_municipio = tr.id_municipio
  JOIN hab_mun hm  ON hm.id_municipio = tr.id_municipio
 GROUP BY m.nombre, hm.habitaciones
 ORDER BY ingresos DESC;


/* =====================================================================
   CONSULTA 6 - UNPIVOT
   Pregunta de negocio: ¿como se reparten las reservas de cada tipo de alojamiento entre los
   4 estados, y que tan alta es la tasa de cancelacion?
   Tecnica: primero se arma una tabla ANCHA (una columna por estado, con SUM(CASE...));
   UNPIVOT la vuelve a convertir en filas (tipo, estado, reservas), formato ideal para graficar
   o para aplicar funciones analiticas. RATIO_TO_REPORT calcula la fraccion de cada estado
   dentro de su tipo.
   ===================================================================== */
SELECT tipo,
       estado,
       reservas,
       ROUND(100 * RATIO_TO_REPORT(reservas) OVER (PARTITION BY tipo), 1) AS pct_del_tipo
  FROM (SELECT *
          FROM (SELECT ta.nombre AS tipo,
                       SUM(CASE WHEN r.estado = 'PENDIENTE'  THEN 1 ELSE 0 END) AS pendiente,
                       SUM(CASE WHEN r.estado = 'CONFIRMADA' THEN 1 ELSE 0 END) AS confirmada,
                       SUM(CASE WHEN r.estado = 'COMPLETADA' THEN 1 ELSE 0 END) AS completada,
                       SUM(CASE WHEN r.estado = 'CANCELADA'  THEN 1 ELSE 0 END) AS cancelada
                  FROM reserva r
                  JOIN alojamiento a        ON a.id_alojamiento = r.id_alojamiento
                  JOIN tipo_alojamiento ta  ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
                 GROUP BY ta.nombre)
               UNPIVOT (reservas FOR estado IN (pendiente  AS 'PENDIENTE',
                                                confirmada AS 'CONFIRMADA',
                                                completada AS 'COMPLETADA',
                                                cancelada  AS 'CANCELADA')))
 ORDER BY tipo, DECODE(estado, 'PENDIENTE', 1, 'CONFIRMADA', 2, 'COMPLETADA', 3, 4);


/* =====================================================================
   CONSULTA 7 - CONSULTA LIBRE
   Pregunta de negocio: ¿que alojamientos generan mucho ingreso pero tienen mala calificacion
   (riesgo reputacional), y cuales tienen excelente calificacion pero ingresan poco
   (oportunidad de promocion)?
   Tecnica: se agregan por separado ingresos (reservas COMPLETADAS) y calificacion promedio
   (RESENA) para no multiplicar filas al unirlos; NTILE(2) parte los alojamientos en mitad
   superior / inferior en cada metrica, y un CASE cruza ambas para clasificarlos.
   Solo se consideran alojamientos con al menos 5 resenas, para que el promedio sea confiable.
   Clasificacion:
     ESTRELLA     = ingreso alto y calificacion alta
     RIESGO       = ingreso alto pero calificacion baja
     OPORTUNIDAD  = ingreso bajo pero calificacion alta
     EN OBSERVACION = ingreso bajo y calificacion baja
   ===================================================================== */
WITH ingreso AS (
  SELECT rh.id_alojamiento, SUM(rh.valor_estadia) AS ingresos
    FROM reserva_habitacion rh
    JOIN reserva r ON r.id_reserva = rh.id_reserva
   WHERE r.estado = 'COMPLETADA'
   GROUP BY rh.id_alojamiento
),
calificacion AS (
  SELECT r.id_alojamiento,
         COUNT(*)                        AS resenas,
         ROUND(AVG(rs.calificacion), 2)  AS calif_promedio
    FROM resena rs
    JOIN reserva r ON r.id_reserva = rs.id_reserva
   GROUP BY r.id_alojamiento
  HAVING COUNT(*) >= 5
),
cuartiles AS (
  SELECT a.id_alojamiento,
         a.nombre_comercial,
         m.nombre  AS municipio,
         ta.nombre AS tipo,
         a.estrellas,
         i.ingresos,
         c.resenas,
         c.calif_promedio,
         NTILE(2) OVER (ORDER BY i.ingresos DESC, a.id_alojamiento)       AS mitad_ingreso,
         NTILE(2) OVER (ORDER BY c.calif_promedio DESC, a.id_alojamiento) AS mitad_calif
    FROM alojamiento a
    JOIN municipio m          ON m.id_municipio = a.id_municipio
    JOIN tipo_alojamiento ta  ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
    JOIN ingreso i            ON i.id_alojamiento = a.id_alojamiento
    JOIN calificacion c       ON c.id_alojamiento = a.id_alojamiento
)
SELECT nombre_comercial,
       municipio,
       tipo,
       estrellas,
       ingresos,
       resenas,
       calif_promedio,
       CASE WHEN mitad_ingreso = 1 AND mitad_calif = 1 THEN 'ESTRELLA'
            WHEN mitad_ingreso = 1 AND mitad_calif = 2 THEN 'RIESGO'
            WHEN mitad_ingreso = 2 AND mitad_calif = 1 THEN 'OPORTUNIDAD'
            ELSE 'EN OBSERVACION' END AS segmento
  FROM cuartiles
 ORDER BY DECODE(CASE WHEN mitad_ingreso = 1 AND mitad_calif = 2 THEN 'RIESGO'
                      WHEN mitad_ingreso = 2 AND mitad_calif = 1 THEN 'OPORTUNIDAD'
                      WHEN mitad_ingreso = 1 AND mitad_calif = 1 THEN 'ESTRELLA'
                      ELSE 'EN OBSERVACION' END,
                 'RIESGO', 1, 'OPORTUNIDAD', 2, 'ESTRELLA', 3, 4),
          ingresos DESC;

/* ============================ FIN DEL SCRIPT 03 ============================ */
