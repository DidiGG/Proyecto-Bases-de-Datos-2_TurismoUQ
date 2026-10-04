/* =====================================================================
   PROYECTO INTEGRADOR TurismoUQ - Bases de Datos II (Universidad del Quindio)
   Entrega 1 - Script 02: CARGA DE DATOS (volumen minimo y datos asimetricos)


   ===================================================================== */

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

/* ---------------------------------------------------------------------
   0. GUARDA: las tablas deben estar vacias (recien creadas con el DDL)
   --------------------------------------------------------------------- */
DECLARE
  v_filas NUMBER;
BEGIN
  SELECT (SELECT COUNT(*) FROM municipio) + (SELECT COUNT(*) FROM reserva)
         + (SELECT COUNT(*) FROM cliente) + (SELECT COUNT(*) FROM rol)
    INTO v_filas FROM dual;
  IF v_filas > 0 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Las tablas ya tienen datos. Vuelva a ejecutar primero el Script 01 (DDL), que las recrea vacias.');
  END IF;
END;
/

/* ---------------------------------------------------------------------
   1. CATALOGOS FIJOS
   --------------------------------------------------------------------- */

-- ROL: dos perfiles de usuarios internos
INSERT INTO rol (nombre, descripcion) VALUES ('ADMINISTRADOR', 'Administrador de la plataforma TurismoUQ');
INSERT INTO rol (nombre, descripcion) VALUES ('ENCARGADO', 'Encargado de gestionar un alojamiento (habitaciones, tarifas y reservas)');

-- MUNICIPIO: los 12 municipios reales del Quindio (sin tildes para evitar problemas de codificacion)
INSERT INTO municipio (nombre) VALUES ('Armenia');
INSERT INTO municipio (nombre) VALUES ('Buenavista');
INSERT INTO municipio (nombre) VALUES ('Calarca');
INSERT INTO municipio (nombre) VALUES ('Circasia');
INSERT INTO municipio (nombre) VALUES ('Cordoba');
INSERT INTO municipio (nombre) VALUES ('Filandia');
INSERT INTO municipio (nombre) VALUES ('Genova');
INSERT INTO municipio (nombre) VALUES ('La Tebaida');
INSERT INTO municipio (nombre) VALUES ('Montenegro');
INSERT INTO municipio (nombre) VALUES ('Pijao');
INSERT INTO municipio (nombre) VALUES ('Quimbaya');
INSERT INTO municipio (nombre) VALUES ('Salento');

-- TIPO_ALOJAMIENTO: los 4 tipos del enunciado
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Hotel', 'Hotel urbano o campestre con recepcion y varias habitaciones');
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Finca cafetera', 'Finca productora de cafe con pocas habitaciones y experiencia rural');
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Glamping', 'Alojamiento de lujo en la naturaleza: domos, tiendas y cabanas');
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Hostal', 'Alojamiento economico con habitaciones sencillas y dobles');

-- TEMPORADA: calendario contiguo 2024-01-01 -> 2027-01-10, sin huecos ni solapes.
--   ALTA  = Semana Santa, mitad de anio, puentes festivos y diciembre-enero.
--   MEDIA / BAJA = los tramos que quedan entre las temporadas altas.
--   La temporada "Diciembre-Enero" cruza de anio (su anio es el de fecha_inicio).
--   Hay temporadas para 2024, 2025 y 2026 (el enunciado pide minimo 6 y 2 anios).
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Diciembre-Enero (cierre)', 'ALTA', 2024, DATE '2024-01-01', DATE '2024-01-10');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 1', 'BAJA', 2024, DATE '2024-01-11', DATE '2024-03-23');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Semana Santa', 'ALTA', 2024, DATE '2024-03-24', DATE '2024-03-31');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 2', 'BAJA', 2024, DATE '2024-04-01', DATE '2024-06-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Mitad de anio', 'ALTA', 2024, DATE '2024-06-15', DATE '2024-07-15');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 1', 'MEDIA', 2024, DATE '2024-07-16', DATE '2024-08-16');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de agosto', 'ALTA', 2024, DATE '2024-08-17', DATE '2024-08-19');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 3', 'BAJA', 2024, DATE '2024-08-20', DATE '2024-10-11');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de octubre', 'ALTA', 2024, DATE '2024-10-12', DATE '2024-10-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 2', 'MEDIA', 2024, DATE '2024-10-15', DATE '2024-11-01');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de noviembre', 'ALTA', 2024, DATE '2024-11-02', DATE '2024-11-04');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 3', 'MEDIA', 2024, DATE '2024-11-05', DATE '2024-12-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Diciembre-Enero', 'ALTA', 2024, DATE '2024-12-15', DATE '2025-01-10');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 1', 'BAJA', 2025, DATE '2025-01-11', DATE '2025-04-12');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Semana Santa', 'ALTA', 2025, DATE '2025-04-13', DATE '2025-04-20');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 2', 'BAJA', 2025, DATE '2025-04-21', DATE '2025-06-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Mitad de anio', 'ALTA', 2025, DATE '2025-06-15', DATE '2025-07-15');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 1', 'MEDIA', 2025, DATE '2025-07-16', DATE '2025-08-15');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de agosto', 'ALTA', 2025, DATE '2025-08-16', DATE '2025-08-18');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 3', 'BAJA', 2025, DATE '2025-08-19', DATE '2025-10-10');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de octubre', 'ALTA', 2025, DATE '2025-10-11', DATE '2025-10-13');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 2', 'MEDIA', 2025, DATE '2025-10-14', DATE '2025-10-31');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de noviembre', 'ALTA', 2025, DATE '2025-11-01', DATE '2025-11-03');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 3', 'MEDIA', 2025, DATE '2025-11-04', DATE '2025-12-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Diciembre-Enero', 'ALTA', 2025, DATE '2025-12-15', DATE '2026-01-10');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 1', 'BAJA', 2026, DATE '2026-01-11', DATE '2026-03-28');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Semana Santa', 'ALTA', 2026, DATE '2026-03-29', DATE '2026-04-05');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 2', 'BAJA', 2026, DATE '2026-04-06', DATE '2026-06-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Mitad de anio', 'ALTA', 2026, DATE '2026-06-15', DATE '2026-07-15');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 1', 'MEDIA', 2026, DATE '2026-07-16', DATE '2026-08-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de agosto', 'ALTA', 2026, DATE '2026-08-15', DATE '2026-08-17');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada baja 3', 'BAJA', 2026, DATE '2026-08-18', DATE '2026-10-09');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de octubre', 'ALTA', 2026, DATE '2026-10-10', DATE '2026-10-12');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 2', 'MEDIA', 2026, DATE '2026-10-13', DATE '2026-10-30');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Puente de noviembre', 'ALTA', 2026, DATE '2026-10-31', DATE '2026-11-02');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Temporada media 3', 'MEDIA', 2026, DATE '2026-11-03', DATE '2026-12-14');
INSERT INTO temporada (nombre, categoria, anio, fecha_inicio, fecha_fin) VALUES ('Diciembre-Enero', 'ALTA', 2026, DATE '2026-12-15', DATE '2027-01-10');
COMMIT;

/* ---------------------------------------------------------------------
   2. OFERTA DE ALOJAMIENTO
   --------------------------------------------------------------------- */

-- 2.1 ALOJAMIENTO: 66 establecimientos repartidos de forma DESIGUAL entre municipios
--     (Armenia 14, Salento 9, ... Genova 1). Tipo, estrellas y direccion varian por establecimiento.
DECLARE
  PROCEDURE pr_aloj(p_mun VARCHAR2, p_tipo VARCHAR2, p_nombre VARCHAR2,
                    p_dir VARCHAR2, p_est NUMBER, p_tel VARCHAR2, p_correo VARCHAR2) IS
  BEGIN
    INSERT INTO alojamiento (id_municipio, id_tipo_alojamiento, nombre_comercial, direccion, estrellas, telefono, correo)
    VALUES ((SELECT id_municipio FROM municipio WHERE nombre = p_mun),
            (SELECT id_tipo_alojamiento FROM tipo_alojamiento WHERE nombre = p_tipo),
            p_nombre, p_dir, p_est, p_tel, p_correo);
  END;
BEGIN
  pr_aloj('Armenia', 'Hotel', 'Hotel Torre Central', 'Carrera 16 # 19-85', 4, '3328792174', 'reservas@hoteltorrecentral.com');
  pr_aloj('Armenia', 'Hotel', 'Hotel Los Fundadores', 'Calle 19 # 25-91', 3, '3096792908', 'reservas@hotellosfundadores.com');
  pr_aloj('Armenia', 'Hotel', 'Hotel Cafe Real', 'Calle 3 # 9-40', 3, '3907579383', 'reservas@hotelcafereal.com');
  pr_aloj('Armenia', 'Hotel', 'Hotel Mirador del Valle', 'Carrera 2 # 24-20', 4, '3746814538', 'reservas@hotelmiradordelvalle.com');
  pr_aloj('Armenia', 'Hotel', 'Hotel Palma de Cera', 'Calle 4 # 21-23', 4, '3614610033', 'reservas@hotelpalmadecera.com');
  pr_aloj('Armenia', 'Hotel', 'Hotel Plaza Cafetera', 'Carrera 14 # 25-60', 3, '3619345145', 'reservas@hotelplazacafetera.com');
  pr_aloj('Armenia', 'Finca cafetera', 'Finca El Cafetal', 'Vereda Cantores, km 2 via Armenia', 2, '3231007728', 'reservas@fincaelcafetal.com');
  pr_aloj('Armenia', 'Finca cafetera', 'Finca La Esperanza', 'Vereda La Montana, km 9 via Armenia', 3, '3326616630', 'reservas@fincalaesperanza.com');
  pr_aloj('Armenia', 'Finca cafetera', 'Finca Los Naranjos', 'Vereda Los Pinos, km 5 via Armenia', 3, '3032699102', 'reservas@fincalosnaranjos.com');
  pr_aloj('Armenia', 'Glamping', 'Glamping Luna Verde', 'Vereda La Montana, km 5 via Armenia', 4, '3095461113', 'reservas@glampinglunaverde.com');
  pr_aloj('Armenia', 'Hostal', 'Hostal La Posada del Viajero', 'Calle 21 # 14-57', 2, '3972979262', 'reservas@hostallaposadadelviajero.com');
  pr_aloj('Armenia', 'Hostal', 'Hostal Mochila Cafetera', 'Carrera 9 # 22-41', 2, '3328367916', 'reservas@hostalmochilacafetera.com');
  pr_aloj('Armenia', 'Hostal', 'Hostal El Descanso', 'Calle 5 # 4-75', 1, '3436469748', 'reservas@hostaleldescanso.com');
  pr_aloj('Armenia', 'Hostal', 'Hostal Ruta del Cafe', 'Calle 6 # 10-71', 2, '3899143301', 'reservas@hostalrutadelcafe.com');
  pr_aloj('Buenavista', 'Finca cafetera', 'Finca El Mirador', 'Vereda Cantores, km 8 via Buenavista', 3, '3300245892', 'reservas@fincaelmirador.com');
  pr_aloj('Buenavista', 'Glamping', 'Glamping Nido del Condor', 'Vereda El Roble, km 3 via Buenavista', 3, '3758929007', 'reservas@glampingnidodelcondor.com');
  pr_aloj('Calarca', 'Hotel', 'Hotel Gran Quindio', 'Carrera 3 # 3-86', 4, '3171452117', 'reservas@hotelgranquindio.com');
  pr_aloj('Calarca', 'Finca cafetera', 'Finca San Jose', 'Vereda El Bosque, km 1 via Calarca', 3, '3255171607', 'reservas@fincasanjose.com');
  pr_aloj('Calarca', 'Finca cafetera', 'Finca La Primavera', 'Vereda Los Pinos, km 11 via Calarca', 2, '3669091111', 'reservas@fincalaprimavera.com');
  pr_aloj('Calarca', 'Finca cafetera', 'Finca Las Camelias', 'Vereda Cantores, km 12 via Calarca', 3, '3569777818', 'reservas@fincalascamelias.com');
  pr_aloj('Calarca', 'Finca cafetera', 'Finca El Eden', 'Vereda Pantanillo, km 10 via Calarca', 2, '3170317974', 'reservas@fincaeleden.com');
  pr_aloj('Calarca', 'Glamping', 'Glamping Cielo Abierto', 'Vereda El Roble, km 5 via Calarca', 3, '3293825773', 'reservas@glampingcieloabierto.com');
  pr_aloj('Calarca', 'Hostal', 'Hostal Colibri', 'Carrera 23 # 11-35', 2, '3633639532', 'reservas@hostalcolibri.com');
  pr_aloj('Circasia', 'Finca cafetera', 'Finca Villa Maria', 'Vereda La Montana, km 6 via Circasia', 3, '3014217743', 'reservas@fincavillamaria.com');
  pr_aloj('Circasia', 'Finca cafetera', 'Finca La Catalina', 'Vereda Cantores, km 11 via Circasia', 4, '3875975104', 'reservas@fincalacatalina.com');
  pr_aloj('Circasia', 'Glamping', 'Glamping Bosque de Niebla', 'Vereda Las Brisas, km 12 via Circasia', 3, '3495490267', 'reservas@glampingbosquedeniebla.com');
  pr_aloj('Circasia', 'Hostal', 'Hostal La Siesta', 'Calle 26 # 11-40', 2, '3201718513', 'reservas@hostallasiesta.com');
  pr_aloj('Cordoba', 'Finca cafetera', 'Finca El Arrayan', 'Vereda La Montana, km 5 via Cordoba', 3, '3207802345', 'reservas@fincaelarrayan.com');
  pr_aloj('Cordoba', 'Finca cafetera', 'Finca Alto Bonito', 'Vereda Cantores, km 12 via Cordoba', 3, '3316627730', 'reservas@fincaaltobonito.com');
  pr_aloj('Filandia', 'Finca cafetera', 'Finca Los Guaduales', 'Vereda San Felipe, km 10 via Filandia', 4, '3857531133', 'reservas@fincalosguaduales.com');
  pr_aloj('Filandia', 'Finca cafetera', 'Finca La Palmera', 'Vereda El Cedral, km 5 via Filandia', 4, '3854058107', 'reservas@fincalapalmera.com');
  pr_aloj('Filandia', 'Finca cafetera', 'Finca El Paraiso', 'Vereda San Felipe, km 7 via Filandia', 3, '3470316028', 'reservas@fincaelparaiso.com');
  pr_aloj('Filandia', 'Glamping', 'Glamping Estrella Cafetera', 'Vereda Las Brisas, km 3 via Filandia', 4, '3728877913', 'reservas@glampingestrellacafetera.com');
  pr_aloj('Filandia', 'Glamping', 'Glamping Domo del Valle', 'Vereda San Felipe, km 9 via Filandia', 5, '3482888446', 'reservas@glampingdomodelvalle.com');
  pr_aloj('Filandia', 'Hostal', 'Hostal Cerro Verde', 'Carrera 29 # 7-79', 2, '3849736818', 'reservas@hostalcerroverde.com');
  pr_aloj('Genova', 'Finca cafetera', 'Finca Monte Verde', 'Vereda Los Pinos, km 7 via Genova', 2, '3080868917', 'reservas@fincamonteverde.com');
  pr_aloj('La Tebaida', 'Hotel', 'Hotel Bosque Alto', 'Calle 4 # 20-68', 3, '3664377256', 'reservas@hotelbosquealto.com');
  pr_aloj('La Tebaida', 'Finca cafetera', 'Finca La Aurora', 'Vereda San Felipe, km 6 via La Tebaida', 4, '3136904200', 'reservas@fincalaaurora.com');
  pr_aloj('La Tebaida', 'Finca cafetera', 'Finca Las Acacias', 'Vereda Barcelona, km 4 via La Tebaida', 3, '3045539717', 'reservas@fincalasacacias.com');
  pr_aloj('La Tebaida', 'Glamping', 'Glamping Rio y Montana', 'Vereda San Felipe, km 10 via La Tebaida', 3, '3438606689', 'reservas@glampingrioymontana.com');
  pr_aloj('La Tebaida', 'Hostal', 'Hostal Sombra de Guadua', 'Calle 29 # 23-78', 2, '3383899235', 'reservas@hostalsombradeguadua.com');
  pr_aloj('Montenegro', 'Hotel', 'Hotel Aroma de Cafe', 'Carrera 21 # 13-34', 3, '3331232146', 'reservas@hotelaromadecafe.com');
  pr_aloj('Montenegro', 'Hotel', 'Hotel Portal del Eje', 'Carrera 28 # 16-79', 3, '3236013955', 'reservas@hotelportaldeleje.com');
  pr_aloj('Montenegro', 'Finca cafetera', 'Finca El Recuerdo', 'Vereda El Bosque, km 9 via Montenegro', 2, '3583171008', 'reservas@fincaelrecuerdo.com');
  pr_aloj('Montenegro', 'Finca cafetera', 'Finca Buenos Aires', 'Vereda Barcelona, km 4 via Montenegro', 4, '3213224190', 'reservas@fincabuenosaires.com');
  pr_aloj('Montenegro', 'Finca cafetera', 'Finca La Cumbre', 'Vereda Las Brisas, km 8 via Montenegro', 3, '3115676856', 'reservas@fincalacumbre.com');
  pr_aloj('Montenegro', 'Glamping', 'Glamping Cima Serena', 'Vereda Los Pinos, km 6 via Montenegro', 4, '3003267556', 'reservas@glampingcimaserena.com');
  pr_aloj('Montenegro', 'Hostal', 'Hostal Camino Real', 'Calle 5 # 19-11', 2, '3516993895', 'reservas@hostalcaminoreal.com');
  pr_aloj('Pijao', 'Finca cafetera', 'Finca Los Cerezos', 'Vereda Pantanillo, km 2 via Pijao', 3, '3262585626', 'reservas@fincaloscerezos.com');
  pr_aloj('Pijao', 'Finca cafetera', 'Finca El Diamante', 'Vereda El Bosque, km 3 via Pijao', 3, '3154710590', 'reservas@fincaeldiamante.com');
  pr_aloj('Pijao', 'Glamping', 'Glamping Raices', 'Vereda Pantanillo, km 11 via Pijao', 4, '3453692816', 'reservas@glampingraices.com');
  pr_aloj('Quimbaya', 'Hotel', 'Hotel Casa Grande', 'Carrera 22 # 9-25', 5, '3690191347', 'reservas@hotelcasagrande.com');
  pr_aloj('Quimbaya', 'Finca cafetera', 'Finca Santa Rita', 'Vereda San Felipe, km 1 via Quimbaya', 4, '3360144458', 'reservas@fincasantarita.com');
  pr_aloj('Quimbaya', 'Finca cafetera', 'Finca La Ilusion', 'Vereda San Felipe, km 10 via Quimbaya', 4, '3171890626', 'reservas@fincalailusion.com');
  pr_aloj('Quimbaya', 'Glamping', 'Glamping Brisa Andina', 'Vereda Barcelona, km 8 via Quimbaya', 5, '3899067648', 'reservas@glampingbrisaandina.com');
  pr_aloj('Quimbaya', 'Glamping', 'Glamping Atardecer Cafetero', 'Vereda Los Pinos, km 5 via Quimbaya', 5, '3584748440', 'reservas@glampingatardecercafetero.com');
  pr_aloj('Quimbaya', 'Hostal', 'Hostal El Parador', 'Calle 20 # 4-91', 1, '3266056095', 'reservas@hostalelparador.com');
  pr_aloj('Salento', 'Hotel', 'Hotel Valle Verde', 'Calle 15 # 18-42', 3, '3308172391', 'reservas@hotelvalleverde.com');
  pr_aloj('Salento', 'Finca cafetera', 'Finca Cafe y Sol', 'Vereda Los Pinos, km 7 via Salento', 2, '3713058215', 'reservas@fincacafeysol.com');
  pr_aloj('Salento', 'Finca cafetera', 'Finca El Roble', 'Vereda Barcelona, km 11 via Salento', 4, '3679496582', 'reservas@fincaelroble.com');
  pr_aloj('Salento', 'Finca cafetera', 'Finca Villa Luz', 'Vereda El Bosque, km 3 via Salento', 3, '3371848954', 'reservas@fincavillaluz.com');
  pr_aloj('Salento', 'Finca cafetera', 'Finca Los Tucanes', 'Vereda Los Pinos, km 11 via Salento', 3, '3993433383', 'reservas@fincalostucanes.com');
  pr_aloj('Salento', 'Glamping', 'Glamping Cascada Escondida', 'Vereda Las Brisas, km 1 via Salento', 3, '3044609013', 'reservas@glampingcascadaescondida.com');
  pr_aloj('Salento', 'Glamping', 'Glamping Viento Sur', 'Vereda El Cedral, km 2 via Salento', 4, '3283577535', 'reservas@glampingvientosur.com');
  pr_aloj('Salento', 'Glamping', 'Glamping Colibri Dorado', 'Vereda La Montana, km 12 via Salento', 4, '3211793764', 'reservas@glampingcolibridorado.com');
  pr_aloj('Salento', 'Hostal', 'Hostal Entre Montanas', 'Calle 13 # 7-93', 3, '3954826591', 'reservas@hostalentremontanas.com');
  COMMIT;
END;
/

-- 2.2 HABITACION: tamano ASIMETRICO segun el tipo de alojamiento
--     Hotel en Armenia: 30-40 | otros hoteles: 18-30 | Finca cafetera: 3-5
--     Glamping: 4-8 | Hostal: 6-14.   (Minimo garantizado: 425 habitaciones; el enunciado pide 400)
DECLARE
  v_n     PLS_INTEGER;
  v_u     NUMBER;
  v_tipo  VARCHAR2(10);
  v_cap   NUMBER;
  v_num   VARCHAR2(10);
  v_desc  VARCHAR2(300);
BEGIN
  DBMS_RANDOM.SEED(2026);
  FOR r IN (SELECT a.id_alojamiento, t.nombre AS tipo_aloj, m.nombre AS municipio
              FROM alojamiento a
              JOIN tipo_alojamiento t ON t.id_tipo_alojamiento = a.id_tipo_alojamiento
              JOIN municipio m        ON m.id_municipio = a.id_municipio
             ORDER BY a.id_alojamiento)
  LOOP
    -- cuantas habitaciones tiene este alojamiento
    IF r.tipo_aloj = 'Hotel' THEN
      IF r.municipio = 'Armenia' THEN v_n := TRUNC(DBMS_RANDOM.VALUE(30, 41));
      ELSE                            v_n := TRUNC(DBMS_RANDOM.VALUE(18, 31));
      END IF;
    ELSIF r.tipo_aloj = 'Finca cafetera' THEN v_n := TRUNC(DBMS_RANDOM.VALUE(3, 6));
    ELSIF r.tipo_aloj = 'Glamping'       THEN v_n := TRUNC(DBMS_RANDOM.VALUE(4, 9));
    ELSE                                      v_n := TRUNC(DBMS_RANDOM.VALUE(6, 15));  -- Hostal
    END IF;

    FOR i IN 1 .. v_n LOOP
      -- tipo de habitacion segun el tipo de alojamiento
      v_u := DBMS_RANDOM.VALUE;
      IF r.tipo_aloj = 'Hotel' THEN
        v_tipo := CASE WHEN v_u < 0.30 THEN 'SENCILLA' WHEN v_u < 0.80 THEN 'DOBLE' ELSE 'SUITE' END;
      ELSIF r.tipo_aloj = 'Finca cafetera' THEN
        v_tipo := CASE WHEN v_u < 0.15 THEN 'DOBLE' WHEN v_u < 0.80 THEN 'CABANA' ELSE 'SUITE' END;
      ELSIF r.tipo_aloj = 'Glamping' THEN
        v_tipo := CASE WHEN v_u < 0.60 THEN 'CABANA' WHEN v_u < 0.80 THEN 'DOBLE' ELSE 'SUITE' END;
      ELSE
        v_tipo := CASE WHEN v_u < 0.50 THEN 'SENCILLA' ELSE 'DOBLE' END;
      END IF;

      -- capacidad maxima segun el tipo de habitacion
      v_cap := CASE v_tipo
                 WHEN 'SENCILLA' THEN 1 + TRUNC(DBMS_RANDOM.VALUE(0, 2))   -- 1 a 2
                 WHEN 'DOBLE'    THEN 2 + TRUNC(DBMS_RANDOM.VALUE(0, 3))   -- 2 a 4
                 WHEN 'SUITE'    THEN 2 + TRUNC(DBMS_RANDOM.VALUE(0, 4))   -- 2 a 5
                 ELSE                 3 + TRUNC(DBMS_RANDOM.VALUE(0, 5))   -- 3 a 7 (cabana)
               END;

      -- numero: hoteles por piso (101..110, 201..), el resto con prefijo del tipo
      v_num := CASE r.tipo_aloj
                 WHEN 'Hotel'          THEN TO_CHAR(100 * (1 + TRUNC((i - 1) / 10)) + MOD(i - 1, 10) + 1)
                 WHEN 'Finca cafetera' THEN 'F' || LPAD(i, 2, '0')
                 WHEN 'Glamping'       THEN 'G' || LPAD(i, 2, '0')
                 ELSE                       'H' || LPAD(i, 2, '0')
               END;

      v_desc := CASE v_tipo
                  WHEN 'SENCILLA' THEN 'Habitacion sencilla con bano privado'
                  WHEN 'DOBLE'    THEN 'Habitacion doble con bano privado y vista al paisaje'
                  WHEN 'SUITE'    THEN 'Suite amplia con sala, bano privado y balcon'
                  ELSE                 'Cabana independiente rodeada de cafetales'
                END;

      INSERT INTO habitacion (id_alojamiento, numero, capacidad_max, tipo_habitacion, descripcion)
      VALUES (r.id_alojamiento, v_num, v_cap, v_tipo, v_desc);
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- 2.3 TARIFA: una fila por cada combinacion habitacion x temporada (CROSS JOIN, no digitada).
--     El precio NO es un porcentaje fijo: cada alojamiento sube distinto en temporada alta
--     (entre +5% y +45% sobre su base) y baja distinto en temporada baja.
--       base          = segun tipo de habitacion
--       x estrellas   = 0.70 + 0.15 * estrellas
--       x tipo aloj.  = hostal 0.65 | hotel 1.00 | finca 1.15 | glamping 1.35
--       x temporada   = ALTA 1.05-1.45 | MEDIA 1.00-1.10 | BAJA 0.78-0.93  (depende del alojamiento)
--     Se redondea a miles de pesos.
INSERT INTO tarifa (id_habitacion, id_temporada, precio_noche)
SELECT h.id_habitacion, t.id_temporada,
       ROUND(
         CASE h.tipo_habitacion WHEN 'SENCILLA' THEN 90000 WHEN 'DOBLE' THEN 140000
                                WHEN 'SUITE' THEN 260000 ELSE 210000 END
         * (0.70 + 0.15 * a.estrellas)
         * CASE ta.nombre WHEN 'Hostal' THEN 0.65 WHEN 'Hotel' THEN 1.00
                          WHEN 'Finca cafetera' THEN 1.15 ELSE 1.35 END
         * CASE t.categoria
             WHEN 'ALTA'  THEN 1.05 + MOD(a.id_alojamiento * 37, 41) / 100
             WHEN 'MEDIA' THEN 1.00 + MOD(a.id_alojamiento * 13, 11) / 100
             ELSE              0.78 + MOD(a.id_alojamiento * 17, 16) / 100
           END
         * (0.95 + MOD(h.id_habitacion * 7, 11) / 100)
       , -3)
  FROM habitacion h
  JOIN alojamiento a       ON a.id_alojamiento = h.id_alojamiento
  JOIN tipo_alojamiento ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
 CROSS JOIN temporada t;
COMMIT;

-- 2.4 SERVICIO: cada alojamiento ofrece entre 4 y 8 servicios de un catalogo de 10
--     (el enunciado pide 30 repartidos entre los alojamientos; aqui todos tienen servicios).
--     El mismo servicio tiene precio distinto en cada alojamiento.
DECLARE
  TYPE t_vc  IS TABLE OF VARCHAR2(80) INDEX BY PLS_INTEGER;
  TYPE t_num IS TABLE OF NUMBER       INDEX BY PLS_INTEGER;
  v_nom  t_vc;
  v_desc t_vc;
  v_base t_num;
  v_n    PLS_INTEGER;
BEGIN
  v_nom(1)  := 'Desayuno tipico';          v_desc(1)  := 'Desayuno con arepa, huevos, chocolate y cafe de la finca';   v_base(1)  := 18000;
  v_nom(2)  := 'Tour cafetero';            v_desc(2)  := 'Recorrido guiado por el cultivo y beneficio del cafe';        v_base(2)  := 45000;
  v_nom(3)  := 'Transporte al aeropuerto'; v_desc(3)  := 'Traslado desde y hacia el aeropuerto El Eden';                v_base(3)  := 60000;
  v_nom(4)  := 'Alquiler de bicicletas';   v_desc(4)  := 'Bicicleta de montana por medio dia';                          v_base(4)  := 25000;
  v_nom(5)  := 'Spa y masajes';            v_desc(5)  := 'Sesion de masaje relajante de 60 minutos';                    v_base(5)  := 90000;
  v_nom(6)  := 'Cena romantica';           v_desc(6)  := 'Cena para dos con decoracion y musica en vivo';               v_base(6)  := 120000;
  v_nom(7)  := 'Cabalgata';                v_desc(7)  := 'Paseo a caballo por los senderos cafeteros';                  v_base(7)  := 55000;
  v_nom(8)  := 'Caminata ecologica';       v_desc(8)  := 'Caminata guiada con avistamiento de aves';                    v_base(8)  := 35000;
  v_nom(9)  := 'Almuerzo tipico';          v_desc(9)  := 'Bandeja paisa o trucha con patacones';                        v_base(9)  := 32000;
  v_nom(10) := 'Lavanderia';               v_desc(10) := 'Lavado y planchado por kilo';                                 v_base(10) := 15000;

  FOR a IN (SELECT id_alojamiento, estrellas FROM alojamiento ORDER BY id_alojamiento) LOOP
    v_n := 4 + MOD(a.id_alojamiento, 5);                 -- entre 4 y 8 servicios
    FOR s IN 1 .. 10 LOOP
      -- ventana circular de v_n tipos de servicio, distinta segun el alojamiento
      IF MOD(s - 1 + MOD(a.id_alojamiento, 10), 10) < v_n THEN
        INSERT INTO servicio (id_alojamiento, nombre, descripcion, precio)
        VALUES (a.id_alojamiento, v_nom(s), v_desc(s),
                ROUND(v_base(s) * (0.80 + 0.08 * a.estrellas) * (0.90 + MOD(a.id_alojamiento * s, 21) / 100), -3));
      END IF;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- 2.5 USUARIO_SISTEMA: 3 administradores + 3 encargados por cada tipo de alojamiento (12)
INSERT INTO usuario_sistema (id_rol, id_alojamiento, username, nombre_completo, correo, estado)
VALUES ((SELECT id_rol FROM rol WHERE nombre = 'ADMINISTRADOR'), NULL, 'admin_general', 'Administrador General TurismoUQ', 'admin.general@turismouq.co', 'ACTIVO');
INSERT INTO usuario_sistema (id_rol, id_alojamiento, username, nombre_completo, correo, estado)
VALUES ((SELECT id_rol FROM rol WHERE nombre = 'ADMINISTRADOR'), NULL, 'admin_soporte', 'Administrador de Soporte TurismoUQ', 'admin.soporte@turismouq.co', 'ACTIVO');
INSERT INTO usuario_sistema (id_rol, id_alojamiento, username, nombre_completo, correo, estado)
VALUES ((SELECT id_rol FROM rol WHERE nombre = 'ADMINISTRADOR'), NULL, 'admin_tarifas', 'Administrador de Tarifas TurismoUQ', 'admin.tarifas@turismouq.co', 'INACTIVO');

INSERT INTO usuario_sistema (id_rol, id_alojamiento, username, nombre_completo, correo, estado)
SELECT (SELECT id_rol FROM rol WHERE nombre = 'ENCARGADO'),
       x.id_alojamiento,
       'enc_' || LOWER(REPLACE(x.tipo, ' ', '_')) || '_' || x.rn,
       'Encargado ' || x.nombre_comercial,
       'enc_' || LOWER(REPLACE(x.tipo, ' ', '_')) || '_' || x.rn || '@turismouq.co',
       'ACTIVO'
  FROM (SELECT a.id_alojamiento, a.nombre_comercial, t.nombre AS tipo,
               ROW_NUMBER() OVER (PARTITION BY a.id_tipo_alojamiento ORDER BY a.id_alojamiento) AS rn
          FROM alojamiento a
          JOIN tipo_alojamiento t ON t.id_tipo_alojamiento = a.id_tipo_alojamiento) x
 WHERE x.rn <= 3;
COMMIT;

/* ---------------------------------------------------------------------
   3. CLIENTES: 3.000, con ciudades de origen variadas (93% Colombia, 7% exterior)
   --------------------------------------------------------------------- */
DECLARE
  -- listas separadas por coma; los nombres repetidos dan mas peso a esa ciudad
  c_nombres  CONSTANT VARCHAR2(1000) := 'Andres,Camila,Juan,Valentina,Carlos,Laura,Santiago,Daniela,Felipe,Maria,Sebastian,Paula,David,Natalia,Jorge,Sofia,Luis,Carolina,Diego,Juliana,Mateo,Isabella,Alejandro,Manuela,Nicolas,Luisa,Julian,Andrea,Cristian,Katherine,Oscar,Mariana,Esteban,Johana,Ricardo,Tatiana,Hernan,Lorena,Mauricio,Viviana';
  c_apellidos CONSTANT VARCHAR2(1000) := 'Garcia,Rodriguez,Martinez,Lopez,Gonzalez,Hernandez,Ramirez,Torres,Florez,Diaz,Vargas,Castro,Ortiz,Rojas,Moreno,Jimenez,Gutierrez,Ruiz,Mendoza,Aguirre,Cardona,Giraldo,Ospina,Zapata,Henao,Londono,Marin,Salazar,Quintero,Arango,Montoya,Restrepo,Nunez,Patino,Cortes,Navarro,Herrera,Suarez,Pineda,Bedoya';
  c_ciu_nac  CONSTANT VARCHAR2(1000) := 'Bogota,Bogota,Bogota,Bogota,Bogota,Bogota,Medellin,Medellin,Medellin,Medellin,Cali,Cali,Cali,Pereira,Pereira,Pereira,Pereira,Manizales,Manizales,Armenia,Armenia,Armenia,Ibague,Ibague,Barranquilla,Bucaramanga,Cartagena,Cucuta,Neiva,Pasto,Santa Marta,Villavicencio,Tulua,Cartago,Popayan,Calarca';
  c_ciu_ext  CONSTANT VARCHAR2(300)  := 'Miami,Madrid,Buenos Aires,Ciudad de Mexico,Lima,Quito,Santiago de Chile,Nueva York';
  c_dominios CONSTANT VARCHAR2(200)  := 'gmail.com,hotmail.com,outlook.com,yahoo.com,correo.co';

  n_nom PLS_INTEGER; n_ape PLS_INTEGER; n_nac PLS_INTEGER; n_ext PLS_INTEGER; n_dom PLS_INTEGER;
  v_nombre VARCHAR2(40); v_ape1 VARCHAR2(40); v_ape2 VARCHAR2(40);
  v_ciudad VARCHAR2(80); v_tipo VARCHAR2(3); v_doc VARCHAR2(20); v_correo VARCHAR2(120);

  -- devuelve el elemento p_i de una lista separada por comas
  FUNCTION item(p_lista VARCHAR2, p_i PLS_INTEGER) RETURN VARCHAR2 IS
  BEGIN
    RETURN REGEXP_SUBSTR(p_lista, '[^,]+', 1, p_i);
  END;
BEGIN
  DBMS_RANDOM.SEED(3000);
  n_nom := REGEXP_COUNT(c_nombres, ',') + 1;   n_ape := REGEXP_COUNT(c_apellidos, ',') + 1;
  n_nac := REGEXP_COUNT(c_ciu_nac, ',') + 1;   n_ext := REGEXP_COUNT(c_ciu_ext, ',') + 1;
  n_dom := REGEXP_COUNT(c_dominios, ',') + 1;

  FOR i IN 1 .. 3000 LOOP
    v_nombre := item(c_nombres,   1 + TRUNC(DBMS_RANDOM.VALUE(0, n_nom)));
    v_ape1   := item(c_apellidos, 1 + TRUNC(DBMS_RANDOM.VALUE(0, n_ape)));
    v_ape2   := item(c_apellidos, 1 + TRUNC(DBMS_RANDOM.VALUE(0, n_ape)));

    IF DBMS_RANDOM.VALUE < 0.07 THEN                       -- turista del exterior
      v_ciudad := item(c_ciu_ext, 1 + TRUNC(DBMS_RANDOM.VALUE(0, n_ext)));
      v_tipo   := CASE WHEN DBMS_RANDOM.VALUE < 0.60 THEN 'PAS' ELSE 'CE' END;
    ELSE
      v_ciudad := item(c_ciu_nac, 1 + TRUNC(DBMS_RANDOM.VALUE(0, n_nac)));
      v_tipo   := CASE WHEN DBMS_RANDOM.VALUE < 0.97 THEN 'CC' ELSE 'CE' END;
    END IF;

    -- documento estrictamente creciente con i => nunca se repite
    v_doc := TO_CHAR(10000000 + i * 12347 + MOD(i * i, 1000));
    IF v_tipo = 'PAS' THEN v_doc := 'P' || v_doc; END IF;

    -- el correo se arma aqui (las funciones locales no se pueden llamar dentro de un INSERT)
    v_correo := LOWER(v_nombre) || '.' || LOWER(v_ape1) || i || '@'
                || item(c_dominios, 1 + TRUNC(DBMS_RANDOM.VALUE(0, n_dom)));

    INSERT INTO cliente (tipo_documento, num_documento, nombres, apellidos, correo, telefono, ciudad_origen)
    VALUES (v_tipo, v_doc, v_nombre, v_ape1 || ' ' || v_ape2, v_correo,
            '3' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 1000000000)), 9, '0'),
            v_ciudad);
  END LOOP;
  COMMIT;
END;
/

/* ---------------------------------------------------------------------
   4. RESERVAS: 26.000 (minimo 25.000), con RESERVA_HABITACION y RESERVA_SERVICIO
   ---------------------------------------------------------------------
   Idea del generador (todo en memoria PL/SQL, un INSERT por fila):
     - Fecha de check-in: se sortea con PESOS por dia -> temporada ALTA pesa 5, MEDIA 2, BAJA 1,
       viernes/sabado x1.8 y el 2026 un poco mas fuerte que el 2024 (estacionalidad real).
     - Alojamiento: se sortea con pesos segun su tamano, un factor de popularidad y el municipio
       (Salento y Armenia atraen mas) -> unos alojamientos reciben muchas mas reservas que otros.
     - Noches: 1 a 7 (lo mas comun 2-3). 70% de reservas con 1 habitacion, el resto con 2 a 6.
       En reservas de varias habitaciones, algunas lineas llegan un dia despues o salen un dia antes.
     - Estado segun la fecha de corte (4/oct/2026): pasadas -> COMPLETADA (88%) o CANCELADA (12%);
       en curso -> CONFIRMADA; futuras -> CONFIRMADA / PENDIENTE / CANCELADA.
     - Una habitacion NUNCA queda ocupada dos veces en la misma noche por reservas no canceladas
       (se lleva un calendario de ocupacion en memoria). Las canceladas no ocupan la habitacion.
     - Clientes: algunos reservan mucho mas que otros (sorteo sesgado hacia los primeros).
     - Servicios: ~90% de las reservas contratan de 1 a 4 servicios (con sesgo a los mas populares).
   valor_estadia se deja en 0 aqui y se calcula despues, noche por noche, en la seccion 5.
   --------------------------------------------------------------------- */
DECLARE
  -- parametros del generador
  c_num_reservas CONSTANT PLS_INTEGER := 26000;
  c_corte        CONSTANT DATE := DATE '2026-10-04';  -- "hoy" para decidir el estado
  c_inicio       CONSTANT DATE := DATE '2024-01-01';
  c_ultimo_ci    CONSTANT DATE := DATE '2026-12-28';  -- ultimo check-in posible
  c_max_checkout CONSTANT DATE := DATE '2027-01-10';  -- ultimo dia cubierto por TEMPORADA

  TYPE t_num  IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE t_date IS TABLE OF DATE   INDEX BY PLS_INTEGER;
  -- habitaciones ordenadas por alojamiento: posicion -> id / capacidad
  a_hab_id   t_num;  a_hab_cap t_num;
  a_h_ini    t_num;  a_h_cnt   t_num;   -- id_alojamiento -> primera posicion / cantidad
  -- servicios, igual
  a_s_id     t_num;  a_s_precio t_num;
  a_s_ini    t_num;  a_s_cnt   t_num;
  -- alojamientos con peso acumulado
  a_aloj     t_num;  c_aloj    t_num;
  n_aloj     PLS_INTEGER := 0;
  -- dias con peso acumulado (indice 1 = c_inicio)
  c_dia      t_num;
  n_dias     PLS_INTEGER;
  -- clientes
  a_cli      t_num;
  n_cli      PLS_INTEGER := 0;
  -- calendario de ocupacion: (id_habitacion*10000 + dia) -> 1
  ocupado    t_num;
  -- lineas de la reserva en construccion
  l_pos      t_num;  l_ci t_date;  l_co t_date;

  v_p PLS_INTEGER := 0;  v_acum NUMBER := 0;  v_peso NUMBER;
  v_d DATE;  v_cat VARCHAR2(5);
  v_creadas PLS_INTEGER := 0;  v_intentos PLS_INTEGER := 0;
  v_u NUMBER;  v_idx PLS_INTEGER;  v_ci DATE;  v_co DATE;  v_noches PLS_INTEGER;
  v_ia PLS_INTEGER;  v_aloj NUMBER;  v_k PLS_INTEGER;
  v_estado VARCHAR2(10);  v_ocupa BOOLEAN;
  v_creacion DATE;  v_cancel DATE;  v_cli NUMBER;
  v_n PLS_INTEGER;  v_off PLS_INTEGER;  v_pos PLS_INTEGER;  v_cnt PLS_INTEGER;
  v_lci DATE;  v_lco DATE;  v_libre BOOLEAN;  v_d1 PLS_INTEGER;  v_d2 PLS_INTEGER;  v_key PLS_INTEGER;
  v_id_res NUMBER;  v_hues NUMBER;  v_huespedes NUMBER;
  v_ns PLS_INTEGER;  v_ks PLS_INTEGER;  v_s0 PLS_INTEGER;  v_sp PLS_INTEGER;
  v_lineas PLS_INTEGER := 0;  v_servs PLS_INTEGER := 0;

  -- sorteo ponderado: dada una lista de pesos ACUMULADOS devuelve la posicion elegida (busqueda binaria)
  FUNCTION elegir(p_acum IN t_num, p_n IN PLS_INTEGER) RETURN PLS_INTEGER IS
    v_u   NUMBER := DBMS_RANDOM.VALUE(0, p_acum(p_n));
    v_lo  PLS_INTEGER := 1;
    v_hi  PLS_INTEGER := p_n;
    v_mid PLS_INTEGER;
  BEGIN
    WHILE v_lo < v_hi LOOP
      v_mid := TRUNC((v_lo + v_hi) / 2);
      IF p_acum(v_mid) >= v_u THEN v_hi := v_mid; ELSE v_lo := v_mid + 1; END IF;
    END LOOP;
    RETURN v_lo;
  END;
BEGIN
  DBMS_RANDOM.SEED(25000);

  /* --- A. Cargar en memoria habitaciones, servicios, clientes --- */
  FOR r IN (SELECT id_habitacion, id_alojamiento, capacidad_max FROM habitacion ORDER BY id_alojamiento, id_habitacion) LOOP
    v_p := v_p + 1;
    a_hab_id(v_p) := r.id_habitacion;  a_hab_cap(v_p) := r.capacidad_max;
    IF NOT a_h_ini.EXISTS(r.id_alojamiento) THEN
      a_h_ini(r.id_alojamiento) := v_p;  a_h_cnt(r.id_alojamiento) := 0;
    END IF;
    a_h_cnt(r.id_alojamiento) := a_h_cnt(r.id_alojamiento) + 1;
  END LOOP;

  v_p := 0;
  FOR r IN (SELECT id_servicio, id_alojamiento, precio FROM servicio ORDER BY id_alojamiento, id_servicio) LOOP
    v_p := v_p + 1;
    a_s_id(v_p) := r.id_servicio;  a_s_precio(v_p) := r.precio;
    IF NOT a_s_ini.EXISTS(r.id_alojamiento) THEN
      a_s_ini(r.id_alojamiento) := v_p;  a_s_cnt(r.id_alojamiento) := 0;
    END IF;
    a_s_cnt(r.id_alojamiento) := a_s_cnt(r.id_alojamiento) + 1;
  END LOOP;

  FOR r IN (SELECT id_cliente FROM cliente ORDER BY id_cliente) LOOP
    n_cli := n_cli + 1;  a_cli(n_cli) := r.id_cliente;
  END LOOP;

  IF n_cli = 0 OR a_h_cnt.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Faltan clientes o habitaciones: revise que las secciones 2 y 3 se ejecutaron sin error.');
  END IF;

  /* --- B. Peso de cada alojamiento: tamano^0.7 x popularidad x municipio --- */
  FOR r IN (SELECT a.id_alojamiento,
                   POWER(COUNT(h.id_habitacion), 0.7)
                   * (0.6 + MOD(a.id_alojamiento * 29, 100) / 100)
                   * CASE m.nombre WHEN 'Salento' THEN 1.6 WHEN 'Armenia' THEN 1.3 WHEN 'Filandia' THEN 1.2
                                   WHEN 'Buenavista' THEN 0.7 WHEN 'Genova' THEN 0.6 ELSE 1 END AS peso
              FROM alojamiento a
              JOIN municipio m  ON m.id_municipio = a.id_municipio
              JOIN habitacion h ON h.id_alojamiento = a.id_alojamiento
             GROUP BY a.id_alojamiento, m.nombre
             ORDER BY a.id_alojamiento) LOOP
    n_aloj := n_aloj + 1;
    v_acum := v_acum + r.peso;
    a_aloj(n_aloj) := r.id_alojamiento;  c_aloj(n_aloj) := v_acum;
  END LOOP;

  /* --- C. Peso de cada dia de check-in (estacionalidad) --- */
  n_dias := c_ultimo_ci - c_inicio + 1;
  v_acum := 0;
  FOR i IN 1 .. n_dias LOOP
    v_d := c_inicio + (i - 1);
    SELECT categoria INTO v_cat FROM temporada WHERE v_d BETWEEN fecha_inicio AND fecha_fin;
    v_peso := CASE v_cat WHEN 'ALTA' THEN 5 WHEN 'MEDIA' THEN 2 ELSE 1 END;
    IF (v_d - TRUNC(v_d, 'IW')) IN (4, 5) THEN v_peso := v_peso * 1.8; END IF;   -- viernes y sabado
    v_peso := v_peso * CASE EXTRACT(YEAR FROM v_d) WHEN 2024 THEN 0.85 WHEN 2025 THEN 1.0 ELSE 1.12 END;
    v_acum := v_acum + v_peso;
    c_dia(i) := v_acum;
  END LOOP;

  /* --- D. Generar las reservas --- */
  WHILE v_creadas < c_num_reservas LOOP
    v_intentos := v_intentos + 1;
    IF v_intentos > c_num_reservas * 10 THEN
      RAISE_APPLICATION_ERROR(-20002, 'El generador no logra ubicar reservas: demasiada ocupacion.');
    END IF;

    -- D1. fechas
    v_idx := elegir(c_dia, n_dias);
    v_ci  := c_inicio + (v_idx - 1);
    v_u   := DBMS_RANDOM.VALUE;
    v_noches := CASE WHEN v_u < 0.12 THEN 1 WHEN v_u < 0.42 THEN 2 WHEN v_u < 0.70 THEN 3
                     WHEN v_u < 0.84 THEN 4 WHEN v_u < 0.92 THEN 5 WHEN v_u < 0.96 THEN 6 ELSE 7 END;
    v_co := v_ci + v_noches;
    IF v_co > c_max_checkout THEN CONTINUE; END IF;

    -- D2. estado segun la fecha de corte
    IF v_co <= c_corte THEN
      v_estado := CASE WHEN DBMS_RANDOM.VALUE < 0.88 THEN 'COMPLETADA' ELSE 'CANCELADA' END;
    ELSIF v_ci <= c_corte THEN
      v_estado := 'CONFIRMADA';                              -- huesped hospedado ahora mismo
    ELSE
      v_u := DBMS_RANDOM.VALUE;
      v_estado := CASE WHEN v_u < 0.62 THEN 'CONFIRMADA' WHEN v_u < 0.86 THEN 'PENDIENTE' ELSE 'CANCELADA' END;
    END IF;
    v_ocupa := (v_estado <> 'CANCELADA');                    -- solo las no canceladas ocupan habitacion

    -- D3. alojamiento y cuantas habitaciones pide el grupo
    v_ia   := elegir(c_aloj, n_aloj);
    v_aloj := a_aloj(v_ia);
    v_cnt  := a_h_cnt(v_aloj);
    v_u    := DBMS_RANDOM.VALUE;
    v_k    := CASE WHEN v_u < 0.70 THEN 1 WHEN v_u < 0.88 THEN 2 WHEN v_u < 0.96 THEN 3
                   ELSE 4 + TRUNC(DBMS_RANDOM.VALUE(0, 3)) END;
    v_k    := LEAST(v_k, v_cnt);

    -- D4. buscar habitaciones libres (recorrido circular desde un punto al azar)
    v_n   := 0;
    v_off := TRUNC(DBMS_RANDOM.VALUE(0, v_cnt));
    FOR j IN 0 .. v_cnt - 1 LOOP
      EXIT WHEN v_n >= v_k;
      v_pos := a_h_ini(v_aloj) + MOD(v_off + j, v_cnt);
      -- fechas de esta linea: la primera usa todo el rango; las demas pueden llegar 1 dia despues / salir 1 antes
      v_lci := v_ci;  v_lco := v_co;
      IF v_n > 0 AND v_noches >= 3 THEN
        IF DBMS_RANDOM.VALUE < 0.30 THEN v_lci := v_ci + 1; END IF;
        IF DBMS_RANDOM.VALUE < 0.20 THEN v_lco := v_co - 1; END IF;
      END IF;
      v_libre := TRUE;
      IF v_ocupa THEN
        v_d1 := v_lci - c_inicio;  v_d2 := v_lco - c_inicio - 1;
        FOR d IN v_d1 .. v_d2 LOOP
          v_key := a_hab_id(v_pos) * 10000 + d;
          IF ocupado.EXISTS(v_key) THEN v_libre := FALSE; EXIT; END IF;
        END LOOP;
      END IF;
      IF v_libre THEN
        v_n := v_n + 1;
        l_pos(v_n) := v_pos;  l_ci(v_n) := v_lci;  l_co(v_n) := v_lco;
      END IF;
    END LOOP;
    IF v_n = 0 THEN CONTINUE; END IF;                        -- nada libre: sortear otra reserva

    -- D5. cabecera: cliente, fecha de creacion y de cancelacion
    v_cli := a_cli(1 + TRUNC(n_cli * POWER(DBMS_RANDOM.VALUE, 1.6)));          -- unos clientes reservan mas
    v_creacion := v_ci - (1 + TRUNC(POWER(DBMS_RANDOM.VALUE, 2) * 120));       -- 1 a 120 dias antes
    IF v_creacion > c_corte THEN v_creacion := c_corte - TRUNC(DBMS_RANDOM.VALUE(0, 15)); END IF;
    IF v_estado = 'CANCELADA' THEN
      -- cancela entre 0 y 39 dias antes del check-in, nunca antes de crear ni despues del corte
      v_cancel := GREATEST(v_creacion, LEAST(v_ci - TRUNC(POWER(DBMS_RANDOM.VALUE, 1.5) * 40), c_corte));
    ELSE
      v_cancel := NULL;
    END IF;

    INSERT INTO reserva (id_cliente, id_alojamiento, fecha_creacion, fecha_checkin, fecha_checkout, estado, fecha_cancelacion)
    VALUES (v_cli, v_aloj, v_creacion, v_ci, v_co, v_estado, v_cancel)
    RETURNING id_reserva INTO v_id_res;

    -- D6. lineas de habitacion (y marcar la ocupacion)
    v_huespedes := 0;
    FOR j IN 1 .. v_n LOOP
      v_pos  := l_pos(j);
      v_hues := 1 + TRUNC(DBMS_RANDOM.VALUE(0, a_hab_cap(v_pos)));             -- 1 .. capacidad_max
      INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento, fecha_checkin, fecha_checkout, num_huespedes, valor_estadia)
      VALUES (v_id_res, a_hab_id(v_pos), v_aloj, l_ci(j), l_co(j), v_hues, 0);
      v_huespedes := v_huespedes + v_hues;
      v_lineas := v_lineas + 1;
      IF v_ocupa THEN
        v_d1 := l_ci(j) - c_inicio;  v_d2 := l_co(j) - c_inicio - 1;
        FOR d IN v_d1 .. v_d2 LOOP
          ocupado(a_hab_id(v_pos) * 10000 + d) := 1;
        END LOOP;
      END IF;
    END LOOP;

    -- D7. servicios contratados (10% de las reservas no contrata ninguno)
    IF a_s_cnt.EXISTS(v_aloj) THEN v_ns := a_s_cnt(v_aloj); ELSE v_ns := 0; END IF;
    IF v_ns > 0 AND DBMS_RANDOM.VALUE >= 0.10 THEN
      v_ks := LEAST(v_ns, 1 + TRUNC(DBMS_RANDOM.VALUE(0, 4)));                 -- 1 a 4 servicios distintos
      v_s0 := TRUNC(v_ns * POWER(DBMS_RANDOM.VALUE, 2));                       -- favorece los primeros del alojamiento
      FOR j IN 0 .. v_ks - 1 LOOP
        v_sp := a_s_ini(v_aloj) + MOD(v_s0 + j, v_ns);
        INSERT INTO reserva_servicio (id_reserva, id_servicio, id_alojamiento, cantidad, precio_unitario)
        VALUES (v_id_res, a_s_id(v_sp), v_aloj,
                1 + TRUNC(DBMS_RANDOM.VALUE(0, LEAST(v_huespedes, 4))),        -- 1 a 4 unidades
                a_s_precio(v_sp));
        v_servs := v_servs + 1;
      END LOOP;
    END IF;

    v_creadas := v_creadas + 1;
    IF MOD(v_creadas, 2000) = 0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Reservas creadas:            ' || v_creadas);
  DBMS_OUTPUT.PUT_LINE('Lineas de habitacion:        ' || v_lineas);
  DBMS_OUTPUT.PUT_LINE('Lineas de servicio:          ' || v_servs);
  DBMS_OUTPUT.PUT_LINE('Intentos de sorteo:          ' || v_intentos);
END;
/

/* ---------------------------------------------------------------------
   5. DERIVADOS DE LAS RESERVAS
   --------------------------------------------------------------------- */

-- 5.1 valor_estadia NOCHE A NOCHE: se cruza cada linea con cada temporada que toca su rango,
--     se cuentan las noches que caen dentro de esa temporada y se multiplican por la tarifa
--     de esa habitacion en esa temporada. Si la estadia cruza dos temporadas, suma dos tramos.
--     noches del tramo = LEAST(checkout, fecha_fin + 1) - GREATEST(checkin, fecha_inicio)
UPDATE reserva_habitacion rh
   SET valor_estadia = (
         SELECT SUM( (LEAST(rh.fecha_checkout, t.fecha_fin + 1) - GREATEST(rh.fecha_checkin, t.fecha_inicio))
                     * tf.precio_noche )
           FROM temporada t
           JOIN tarifa tf ON tf.id_temporada = t.id_temporada
          WHERE tf.id_habitacion = rh.id_habitacion
            AND t.fecha_inicio < rh.fecha_checkout
            AND t.fecha_fin   >= rh.fecha_checkin);
COMMIT;

-- 5.2 PAGO: se calcula primero el total de cada reserva (estadia + servicios) en una tabla de trabajo.
--     Reglas que reflejan el enunciado:
--       * COMPLETADA: 55% pago unico por el total; 45% anticipo (30-50%) + saldo al check-in.
--       * CONFIRMADA: 25% pago unico; 75% solo anticipo (si ya esta hospedado, tambien paga el saldo).
--       * PENDIENTE:  un pago en estado PENDIENTE por el anticipo.
--       * CANCELADA:  se pago el anticipo; si cancelo con MAS de 5 dias de anticipacion el pago pasa a
--                     REEMBOLSADO con 80% devuelto; si no, el pago se queda EXITOSO (sin reembolso).
--       * ~6% de las reservas tienen ademas un intento de pago FALLIDO.
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE tmp_total_reserva PURGE';
EXCEPTION WHEN OTHERS THEN NULL;   -- no existia: no pasa nada
END;
/

CREATE TABLE tmp_total_reserva AS
SELECT r.id_reserva, r.estado, r.fecha_creacion, r.fecha_checkin, r.fecha_cancelacion,
       NVL(h.valor, 0) + NVL(s.valor, 0)                          AS total,
       ORA_HASH(r.id_reserva, 99)                                 AS bucket,
       ROUND((NVL(h.valor, 0) + NVL(s.valor, 0)) * (0.30 + ORA_HASH(r.id_reserva, 20, 5) / 100), -3) AS anticipo,
       CASE WHEN ORA_HASH(r.id_reserva, 99, 13) < 35 THEN 'TARJETA_CREDITO'
            WHEN ORA_HASH(r.id_reserva, 99, 13) < 55 THEN 'TARJETA_DEBITO'
            WHEN ORA_HASH(r.id_reserva, 99, 13) < 78 THEN 'PSE'
            WHEN ORA_HASH(r.id_reserva, 99, 13) < 93 THEN 'TRANSFERENCIA'
            ELSE 'EFECTIVO' END                                   AS metodo
  FROM reserva r
  LEFT JOIN (SELECT id_reserva, SUM(valor_estadia) AS valor FROM reserva_habitacion GROUP BY id_reserva) h
         ON h.id_reserva = r.id_reserva
  LEFT JOIN (SELECT id_reserva, SUM(cantidad * precio_unitario) AS valor FROM reserva_servicio GROUP BY id_reserva) s
         ON s.id_reserva = r.id_reserva;

-- pago principal: una fila por reserva
INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado, monto_reembolsado)
SELECT t.id_reserva, t.fecha_creacion,
       CASE WHEN t.estado = 'COMPLETADA' AND t.bucket < 55 THEN t.total
            WHEN t.estado = 'CONFIRMADA' AND t.bucket < 25 THEN t.total
            ELSE t.anticipo END,
       t.metodo,
       CASE WHEN t.estado = 'PENDIENTE' THEN 'PENDIENTE'
            WHEN t.estado = 'CANCELADA' AND t.fecha_checkin - TRUNC(t.fecha_cancelacion) > 5 THEN 'REEMBOLSADO'
            ELSE 'EXITOSO' END,
       CASE WHEN t.estado = 'CANCELADA' AND t.fecha_checkin - TRUNC(t.fecha_cancelacion) > 5
            THEN t.anticipo * 0.8 END
  FROM tmp_total_reserva t;

-- saldo al llegar (segundo pago de la misma reserva)
INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado, monto_reembolsado)
SELECT t.id_reserva, t.fecha_checkin, t.total - t.anticipo,
       CASE MOD(t.bucket, 3) WHEN 0 THEN 'EFECTIVO' WHEN 1 THEN 'TARJETA_DEBITO' ELSE 'TRANSFERENCIA' END,
       'EXITOSO', NULL
  FROM tmp_total_reserva t
 WHERE (t.estado = 'COMPLETADA' AND t.bucket >= 55)
    OR (t.estado = 'CONFIRMADA' AND t.bucket >= 25 AND t.fecha_checkin <= DATE '2026-10-04');

-- intentos de pago fallidos (antes del pago que si funciono)
INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado, monto_reembolsado)
SELECT t.id_reserva, t.fecha_creacion, t.anticipo,
       CASE WHEN MOD(t.bucket, 2) = 0 THEN 'PSE' ELSE 'TARJETA_CREDITO' END,
       'FALLIDO', NULL
  FROM tmp_total_reserva t
 WHERE t.estado IN ('COMPLETADA', 'CONFIRMADA', 'PENDIENTE')
   AND ORA_HASH(t.id_reserva, 99, 9) < 6;
COMMIT;

DROP TABLE tmp_total_reserva PURGE;

-- 5.3 RESENA: ~52% de las reservas COMPLETADAS dejan resena (el enunciado pide minimo 40%).
--     La calificacion depende de la "calidad" de cada alojamiento (3.0 a 4.8) mas un ruido, asi
--     hay alojamientos mejor y peor calificados. 25% de las resenas no trae comentario.
INSERT INTO resena (id_reserva, calificacion, comentario, fecha_resena)
SELECT x.id_reserva, x.calif,
       CASE WHEN MOD(x.id_reserva, 4) = 0 THEN NULL
            ELSE CASE x.calif
                   WHEN 5 THEN CASE MOD(x.id_reserva, 3) WHEN 0 THEN 'Excelente atencion y una ubicacion espectacular.'
                                                         WHEN 1 THEN 'Volveriamos sin dudarlo, todo estuvo impecable.'
                                                         ELSE 'Cafe delicioso y un personal muy amable.' END
                   WHEN 4 THEN CASE MOD(x.id_reserva, 3) WHEN 0 THEN 'Muy buena estadia, habitaciones comodas y limpias.'
                                                         WHEN 1 THEN 'Buen servicio, solo mejoraria el desayuno.'
                                                         ELSE 'Lindo lugar, recomendado para ir en pareja o en familia.' END
                   WHEN 3 THEN CASE MOD(x.id_reserva, 3) WHEN 0 THEN 'Cumple lo basico, pero esperaba algo mas por el precio.'
                                                         WHEN 1 THEN 'Buena ubicacion, aunque la habitacion estaba algo desgastada.'
                                                         ELSE 'Estadia aceptable, el servicio fue lento.' END
                   WHEN 2 THEN CASE MOD(x.id_reserva, 3) WHEN 0 THEN 'No coincide con las fotos, mucho ruido en la noche.'
                                                         WHEN 1 THEN 'Poca limpieza y atencion deficiente.'
                                                         ELSE 'La experiencia no valio lo que pagamos.' END
                   ELSE 'Mala experiencia, no lo recomiendo.'
                 END
       END,
       x.fecha_resena
  FROM (SELECT r.id_reserva,
               LEAST(5, GREATEST(1, ROUND(3.0 + MOD(r.id_alojamiento * 7, 19) / 10
                                          + (ORA_HASH(r.id_reserva, 1000, 11) - 500) / 500 * 1.8))) AS calif,
               LEAST(DATE '2026-10-04', r.fecha_checkout + ORA_HASH(r.id_reserva, 14, 7))          AS fecha_resena
          FROM reserva r
         WHERE r.estado = 'COMPLETADA'
           AND ORA_HASH(r.id_reserva, 99, 3) < 52) x;
COMMIT;

/* ---------------------------------------------------------------------
   6. ESTADISTICAS DEL OPTIMIZADOR (utiles para los planes de la Entrega 3)
   --------------------------------------------------------------------- */
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER);
END;
/

/* =====================================================================
   7. VERIFICACION: volumen minimo del enunciado (todas las filas deben decir OK)
   ===================================================================== */
SELECT tabla, filas, minimo, CASE WHEN filas >= minimo THEN 'OK' ELSE 'FALTA' END AS cumple
  FROM (SELECT 'MUNICIPIO' AS tabla, (SELECT COUNT(*) FROM municipio) AS filas, 12 AS minimo FROM dual
        UNION ALL SELECT 'TIPO_ALOJAMIENTO',    (SELECT COUNT(*) FROM tipo_alojamiento),    4      FROM dual
        UNION ALL SELECT 'ALOJAMIENTO',         (SELECT COUNT(*) FROM alojamiento),         60     FROM dual
        UNION ALL SELECT 'HABITACION',          (SELECT COUNT(*) FROM habitacion),          400    FROM dual
        UNION ALL SELECT 'TEMPORADA',           (SELECT COUNT(*) FROM temporada),           6      FROM dual
        UNION ALL SELECT 'TARIFA (= hab x temp)', (SELECT COUNT(*) FROM tarifa),
                         (SELECT COUNT(*) FROM habitacion) * (SELECT COUNT(*) FROM temporada)      FROM dual
        UNION ALL SELECT 'CLIENTE',             (SELECT COUNT(*) FROM cliente),             3000   FROM dual
        UNION ALL SELECT 'RESERVA',             (SELECT COUNT(*) FROM reserva),             25000  FROM dual
        UNION ALL SELECT 'RESERVA_HABITACION',  (SELECT COUNT(*) FROM reserva_habitacion),  25000  FROM dual
        UNION ALL SELECT 'PAGO',                (SELECT COUNT(*) FROM pago),                25000  FROM dual
        UNION ALL SELECT 'SERVICIO',            (SELECT COUNT(*) FROM servicio),            30     FROM dual
        UNION ALL SELECT 'RESERVA_SERVICIO',    (SELECT COUNT(*) FROM reserva_servicio),    40000  FROM dual
        UNION ALL SELECT 'USUARIO_SISTEMA',     (SELECT COUNT(*) FROM usuario_sistema),     10     FROM dual
       )
 ORDER BY 1;

-- RESENA: al menos 40% de las reservas COMPLETADAS (debe dar >= 40)
SELECT (SELECT COUNT(*) FROM resena) AS resenas,
       (SELECT COUNT(*) FROM reserva WHERE estado = 'COMPLETADA') AS completadas,
       ROUND(100 * (SELECT COUNT(*) FROM resena) / (SELECT COUNT(*) FROM reserva WHERE estado = 'COMPLETADA'), 1) AS porcentaje,
       CASE WHEN 100 * (SELECT COUNT(*) FROM resena) / (SELECT COUNT(*) FROM reserva WHERE estado = 'COMPLETADA') >= 40
            THEN 'OK' ELSE 'FALTA' END AS cumple
  FROM dual;

-- Cada reserva tiene al menos una linea (RESERVA_HABITACION >= RESERVA) y algunas tienen varias
SELECT COUNT(*) AS reservas,
       SUM(CASE WHEN n_hab > 1 THEN 1 ELSE 0 END) AS con_varias_habitaciones,
       MAX(n_hab) AS max_habitaciones_en_una_reserva
  FROM (SELECT id_reserva, COUNT(*) AS n_hab FROM reserva_habitacion GROUP BY id_reserva);

-- Algunas reservas con mas de un pago (anticipo + saldo)
SELECT COUNT(*) AS reservas,
       SUM(CASE WHEN n_pagos > 1 THEN 1 ELSE 0 END) AS con_varios_pagos
  FROM (SELECT id_reserva, COUNT(*) AS n_pagos FROM pago GROUP BY id_reserva);

/* =====================================================================
   8. VERIFICACION: asimetria y coherencia de los datos
   ===================================================================== */

-- 8.1 Alojamientos y habitaciones por municipio (distribucion desigual)
SELECT m.nombre AS municipio, COUNT(DISTINCT a.id_alojamiento) AS alojamientos, COUNT(h.id_habitacion) AS habitaciones
  FROM municipio m
  LEFT JOIN alojamiento a ON a.id_municipio = m.id_municipio
  LEFT JOIN habitacion h  ON h.id_alojamiento = a.id_alojamiento
 GROUP BY m.nombre ORDER BY alojamientos DESC, m.nombre;

-- 8.2 Tamano por tipo de alojamiento (hoteles grandes, fincas pequenas)
SELECT t.nombre AS tipo, COUNT(DISTINCT a.id_alojamiento) AS alojamientos,
       MIN(c.n) AS min_hab, ROUND(AVG(c.n), 1) AS prom_hab, MAX(c.n) AS max_hab
  FROM tipo_alojamiento t
  JOIN alojamiento a ON a.id_tipo_alojamiento = t.id_tipo_alojamiento
  JOIN (SELECT id_alojamiento, COUNT(*) AS n FROM habitacion GROUP BY id_alojamiento) c
    ON c.id_alojamiento = a.id_alojamiento
 GROUP BY t.nombre ORDER BY prom_hab DESC;

-- 8.3 Reservas por anio y mes (estacionalidad: picos en Semana Santa, mitad de anio y dic-ene)
SELECT TO_CHAR(fecha_checkin, 'YYYY-MM') AS mes, COUNT(*) AS reservas
  FROM reserva GROUP BY TO_CHAR(fecha_checkin, 'YYYY-MM') ORDER BY 1;

-- 8.4 Reservas por estado
SELECT estado, COUNT(*) AS reservas FROM reserva GROUP BY estado ORDER BY reservas DESC;

-- 8.5 Calificacion promedio por tipo de alojamiento (varia entre alojamientos)
SELECT t.nombre AS tipo, COUNT(*) AS resenas, ROUND(AVG(rs.calificacion), 2) AS promedio
  FROM resena rs
  JOIN reserva r ON r.id_reserva = rs.id_reserva
  JOIN alojamiento a ON a.id_alojamiento = r.id_alojamiento
  JOIN tipo_alojamiento t ON t.id_tipo_alojamiento = a.id_tipo_alojamiento
 GROUP BY t.nombre ORDER BY promedio DESC;

-- 8.6 Estadias que cruzan dos o mas temporadas (deben existir varias)
SELECT COUNT(*) AS lineas_que_cruzan_temporadas
  FROM reserva_habitacion rh
 WHERE (SELECT COUNT(*) FROM temporada t
         WHERE t.fecha_inicio < rh.fecha_checkout AND t.fecha_fin >= rh.fecha_checkin) > 1;

-- 8.7 CONTROLES DE INTEGRIDAD (todos deben dar 0)
-- (a) lineas cuyo valor no se calculo o cuyas noches no quedaron cubiertas por las temporadas
SELECT COUNT(*) AS lineas_con_valor_incorrecto
  FROM reserva_habitacion rh
 WHERE rh.valor_estadia <= 0
    OR (SELECT SUM(LEAST(rh.fecha_checkout, t.fecha_fin + 1) - GREATEST(rh.fecha_checkin, t.fecha_inicio))
          FROM temporada t
         WHERE t.fecha_inicio < rh.fecha_checkout AND t.fecha_fin >= rh.fecha_checkin)
       <> rh.fecha_checkout - rh.fecha_checkin;

-- (b) la misma habitacion ocupada dos veces en las mismas noches por reservas no canceladas
SELECT COUNT(*) AS solapes_de_habitacion
  FROM reserva_habitacion a
  JOIN reserva ra ON ra.id_reserva = a.id_reserva AND ra.estado <> 'CANCELADA'
  JOIN reserva_habitacion b ON b.id_habitacion = a.id_habitacion AND b.id_reserva_habitacion > a.id_reserva_habitacion
  JOIN reserva rb ON rb.id_reserva = b.id_reserva AND rb.estado <> 'CANCELADA'
 WHERE a.fecha_checkin < b.fecha_checkout AND b.fecha_checkin < a.fecha_checkout;

-- (c) lineas fuera del rango de su reserva, o con mas huespedes que la capacidad de la habitacion
SELECT COUNT(*) AS lineas_fuera_de_rango_o_capacidad
  FROM reserva_habitacion rh
  JOIN reserva r    ON r.id_reserva = rh.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
 WHERE rh.fecha_checkin < r.fecha_checkin OR rh.fecha_checkout > r.fecha_checkout
    OR rh.num_huespedes > h.capacidad_max;

-- (d) reservas COMPLETADAS que no quedaron pagadas por completo (suma de pagos EXITOSOS < total)
SELECT COUNT(*) AS completadas_sin_pago_total
  FROM reserva r
 WHERE r.estado = 'COMPLETADA'
   AND NVL((SELECT SUM(p.monto) FROM pago p WHERE p.id_reserva = r.id_reserva AND p.estado = 'EXITOSO'), 0)
       < NVL((SELECT SUM(valor_estadia) FROM reserva_habitacion WHERE id_reserva = r.id_reserva), 0)
         + NVL((SELECT SUM(cantidad * precio_unitario) FROM reserva_servicio WHERE id_reserva = r.id_reserva), 0);
