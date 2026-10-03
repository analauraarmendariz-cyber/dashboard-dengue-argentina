# ==============================================================================
# PROYECTO: Dashboard Epidemiológico de Dengue en Argentina (SNVS)
# ==============================================================================

# ------------------------------------------------------------------------------
# FASE 1: Configuración del Entorno y Carga de Librerías
# ------------------------------------------------------------------------------
library(tidyverse)
library(sf)
library(geoAr)
library(janitor)

# ------------------------------------------------------------------------------
# FASE 2: Carga y Limpieza de Datos
# ------------------------------------------------------------------------------

# 1. Cargar la capa cartográfica oficial de provincias (formato sf)
mapa_provincias <- get_geo(geo = "ARGENTINA", level = "provincia") %>% 
  clean_names()

# 2. Cargar el dataset epidemiológico del SNVS (con codificación correcta para tildes)
datos_epidemiologicos <- read_csv2(
  "datos/informacion-publica-dengue-zika-nacional-se-1-2025-a-se38-2026-2026-10-05.csv",
  locale = locale(encoding = "latin1")
) %>% 
  clean_names() %>% 
  mutate(
    # Homogeneizar el nombre del evento si incluye gestación
    evento_clean = if_else(str_detect(evento, "gestac"), "Dengue en Gestación", "Dengue General")
  )

# 3. Inspeccionar la estructura del dataset en la consola
glimpse(datos_epidemiologicos)

# ------------------------------------------------------------------------------
# FASE 3: Agregación Espacial y Unión con el Mapa (Join)
# ------------------------------------------------------------------------------

# 1. Agrupar el total de casos por código provincial INDEC
casos_por_provincia <- datos_epidemiologicos %>% 
  mutate(id_prov_indec_residencia = str_pad(id_prov_indec_residencia, width = 2, pad = "0")) %>% 
  group_by(id_prov_indec_residencia, provincia_residencia) %>% 
  summarise(
    total_casos = sum(cantidad, na.rm = TRUE),
    .groups = "drop"
  )

# 2. Identificar dinámicamente la columna del código en el mapa
col_codigo_mapa <- intersect(c("codprov_censo", "codprov", "id", "cpro"), names(mapa_provincias))[1]

# 3. Unir la capa geográfica con los casos por provincia
mapa_casos <- mapa_provincias %>% 
  mutate(code_join = str_pad(.data[[col_codigo_mapa]], width = 2, pad = "0")) %>% 
  left_join(casos_por_provincia, by = c("code_join" = "id_prov_indec_residencia"))

# ------------------------------------------------------------------------------
# FASE 3b: Tasas por 100.000 habitantes
# (pegar después de la FASE 3, antes de la FASE 4)
# ------------------------------------------------------------------------------

# 1. Año para el cálculo (2026 tiene muy pocos casos, por eso se usa 2025)
anio_tasa <- 2025

# 2. Leer la tabla de población (INDEC, proyección al año indicado)
archivo_pob <- "datos/poblacion_provincias_2025.csv"
lectura <- if (str_detect(readLines(archivo_pob, n = 1, warn = FALSE), ";")) read_csv2 else read_csv

poblacion <- lectura(archivo_pob, col_types = cols(.default = col_character())) %>%
  clean_names() %>%
  mutate(
    id_prov   = str_pad(str_trim(id_prov), width = 2, pad = "0"),
    poblacion = parse_number(poblacion, locale = locale(decimal_mark = ",", grouping_mark = "."))
  ) %>%
  select(id_prov, poblacion)

# 3. Casos del año por provincia y tasa por 100.000 habitantes
tasas_provincia <- datos_epidemiologicos %>%
  filter(anio_min == anio_tasa) %>%
  mutate(id_prov = str_pad(id_prov_indec_residencia, width = 2, pad = "0")) %>%
  group_by(id_prov, provincia_residencia) %>%
  summarise(casos = sum(cantidad, na.rm = TRUE), .groups = "drop") %>%
  inner_join(poblacion, by = "id_prov") %>%       # deja afuera "desconocida"
  mutate(tasa_100k = casos / poblacion * 100000) %>%
  arrange(desc(tasa_100k))

print(tasas_provincia)

# 4. Mapa de tasas
mapa_tasas <- mapa_provincias %>%
  mutate(code_join = str_pad(.data[[col_codigo_mapa]], width = 2, pad = "0")) %>%
  left_join(tasas_provincia, by = c("code_join" = "id_prov"))

ggplot(mapa_tasas) +
  geom_sf(aes(fill = tasa_100k), color = "white", size = 0.2) +
  scale_fill_viridis_c(
    option = "magma", direction = -1, trans = "sqrt",
    na.value = "grey90", name = "Casos por\n100.000 hab."
  ) +
  labs(
    title = "Tasa de casos de dengue por 100.000 habitantes",
    subtitle = paste0("Casos notificados ", anio_tasa, " / población proyectada (INDEC)"),
    caption = "Provincias con pocos casos tienen tasas inestables"
  ) +
  theme_minimal()
# ------------------------------------------------------------------------------
# FASE 4: Mapeo Temático (Mapa Choropleth)
# ------------------------------------------------------------------------------
ggplot(data = mapa_casos) +
  geom_sf(aes(fill = total_casos), color = "white", size = 0.2) +
  scale_fill_viridis_c(
    option = "magma", 
    trans = "sqrt", 
    na.value = "grey90",
    name = "Total de Casos"
  ) +
  labs(
    title = "Distribución Geográfica de Casos de Dengue en Argentina",
    subtitle = "Fuente: Sistema Nacional de Vigilancia de la Salud (SNVS)",
    caption = "Elaborado en R con sf, geoAr y ggplot2"
  ) +
  theme_minimal()

# ------------------------------------------------------------------------------
# FASE 5: Análisis Temporal (Curva Epidémica por Semana y Evento)
# ------------------------------------------------------------------------------
datos_epidemiologicos %>% 
  group_by(anio_min, sepi_min, evento_clean) %>% 
  summarise(total_casos = sum(cantidad, na.rm = TRUE), .groups = "drop") %>% 
  ggplot(aes(x = sepi_min, y = total_casos, color = evento_clean, group = evento_clean)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  facet_wrap(evento_clean ~ anio_min, scales = "free_y") +
  scale_color_manual(values = c("Dengue General" = "#d95f02", "Dengue en Gestación" = "#7570b3")) +
  labs(
    title = "Evolución Temporal de Casos por Semana Epidemiológica",
    subtitle = "Comparativa entre Dengue General y Dengue en Gestación",
    x = "Semana Epidemiológica (SE)",
    y = "Total de Casos",
    color = "Categoría"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# ------------------------------------------------------------------------------
# FASE 6: Perfil Demográfico (Casos por Grupo Etario)
# ------------------------------------------------------------------------------
datos_epidemiologicos %>% 
  filter(!is.na(grupo_etario)) %>% 
  group_by(grupo_etario, evento_clean) %>% 
  summarise(total_casos = sum(cantidad, na.rm = TRUE), .groups = "drop") %>% 
  ggplot(aes(x = reorder(grupo_etario, total_casos), y = total_casos, fill = evento_clean)) +
  geom_col(position = "dodge") +
  coord_flip() +
  scale_fill_manual(values = c("Dengue General" = "#d95f02", "Dengue en Gestación" = "#7570b3")) +
  labs(
    title = "Distribución de Casos según Grupo Etario",
    subtitle = "Comparativa por categoría de notificación",
    x = "Grupo Etario",
    y = "Total de Casos",
    fill = "Evento"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
# ------------------------------------------------------------------------------
# FASE 7: Análisis Inferencial I - Regresión Logística (Odds Ratios)
# ------------------------------------------------------------------------------

# 1. Preparar la variable respuesta binaria (1 = Gestación, 0 = General)
# Expandimos la base agregada por la columna 'cantidad' usando uncount() para modelar cada caso individualmente
datos_modelo_log <- datos_epidemiologicos %>% 
  filter(!is.na(grupo_etario)) %>% 
  uncount(weights = cantidad) %>% 
  mutate(
    es_gestacion = if_else(evento_clean == "Dengue en Gestación", 1, 0),
    grupo_etario = as.factor(grupo_etario),
    anio_min = as.factor(anio_min)
  )

# 2. Ajustar el Modelo Lineal Generalizado (GLM Binomial)
modelo_logistico <- glm(
  es_gestacion ~ grupo_etario + anio_min, 
  data = datos_modelo_log, 
  family = binomial(link = "logit")
)

# 3. Extraer los Odds Ratios (OR), Intervalos de Confianza al 95% y p-valores
tabla_or <- broom::tidy(modelo_logistico, exponentiate = TRUE, conf.int = TRUE) %>% 
  select(term, estimate, conf.low, conf.high, p.value) %>% 
  rename(
    Variable = term,
    `Odds Ratio (OR)` = estimate,
    `IC 2.5%` = conf.low,
    `IC 97.5%` = conf.high,
    `p-valor` = p.value
  )

# Mostrar la tabla de resultados en la consola
print(tabla_or)

# 4. Graficar los Odds Ratios con sus Intervalos de Confianza (Forest Plot)
tabla_or %>% 
  filter(Variable != "(Intercept)") %>% 
  ggplot(aes(x = `Odds Ratio (OR)`, y = reorder(Variable, `Odds Ratio (OR)`))) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "red", linewidth = 0.8) +
  geom_point(size = 3, color = "#2b5c8f") +
  geom_errorbarh(aes(xmin = `IC 2.5%`, xmax = `IC 97.5%`), height = 0.2, color = "#2b5c8f") +
  scale_x_log10() +
  labs(
    title = "Forest Plot: Factores asociados a Dengue en Gestación",
    subtitle = "Odds Ratios (OR) e Intervalos de Confianza del 95%",
    x = "Odds Ratio (Escala Logarítmica)",
    y = "Variables / Categorías",
    caption = "Línea roja discontinua representa OR = 1 (Sin asociación / Riesgo Neutro)"
  ) +
  theme_minimal()
# ------------------------------------------------------------------------------
# FASE 8: Análisis Inferencial II - Gradiente Espacio-Temporal (Latitud vs. SE Pico)
# ------------------------------------------------------------------------------

# 1. Obtener los centroides y la latitud de cada provincia por código INDEC
centroides_provincias <- mapa_provincias %>% 
  st_centroid() %>% 
  mutate(
    latitud = st_coordinates(.)[,2],
    code_join = str_pad(.data[[col_codigo_mapa]], width = 2, pad = "0")
  ) %>% 
  st_drop_geometry() %>% 
  select(code_join, latitud)

# 2. Identificar la Semana Epidemiológica Pico por Provincia
pico_por_provincia <- datos_epidemiologicos %>% 
  mutate(id_prov_indec_residencia = str_pad(id_prov_indec_residencia, width = 2, pad = "0")) %>% 
  group_by(id_prov_indec_residencia, provincia_residencia, sepi_min) %>% 
  summarise(total_casos = sum(cantidad, na.rm = TRUE), .groups = "drop") %>% 
  group_by(id_prov_indec_residencia, provincia_residencia) %>% 
  slice_max(order_by = total_casos, n = 1, with_ties = FALSE) %>% 
  ungroup() %>% 
  left_join(centroides_provincias, by = c("id_prov_indec_residencia" = "code_join")) %>% 
  filter(!is.na(latitud))

# 3. Test de Correlación de Spearman (Latitud vs. Semana Pico)
test_correlacion <- cor.test(
  pico_por_provincia$latitud, 
  pico_por_provincia$sepi_min, 
  method = "spearman"
)

# Mostrar el resultado en la consola
print(test_correlacion)

# 4. Gráfico de Dispersión y Regresión (Gradiente Latitudinal)
ggplot(pico_por_provincia, aes(x = latitud, y = sepi_min)) +
  geom_point(aes(size = total_casos), color = "#d95f02", alpha = 0.7) +
  geom_smooth(method = "lm", color = "#2b5c8f", se = TRUE) +
  geom_text(aes(label = provincia_residencia), vjust = -0.7, size = 2.8, check_overlap = TRUE) +
  labs(
    title = "Gradiente Espacio-Temporal: Latitud vs. Semana Epidémica Pico",
    subtitle = "Evaluación del avance del brote según posición geográfica (Norte a Sur)",
    x = "Latitud (Grados Sur - Más negativo hacia el Sur)",
    y = "Semana Epidemiológica Pico (SE)",
    size = "Casos en SE Pico",
    caption = paste0("Correlación de Spearman rho: ", round(test_correlacion$estimate, 2), 
                     " (p-valor: ", round(as.numeric(test_correlacion$p.value), 4), ")")
  ) +
  theme_minimal()
# ------------------------------------------------------------------------------
# FASE 9: Análisis Inferencial III - Test de Chi-Cuadrado (Grupo Etario vs. Año)
# ------------------------------------------------------------------------------

# 1. Crear la Tabla de Contingencia (Grupo Etario vs. Año)
tabla_contingencia <- datos_epidemiologicos %>% 
  filter(!is.na(grupo_etario)) %>% 
  group_by(grupo_etario, anio_min) %>% 
  summarise(total_casos = sum(cantidad, na.rm = TRUE), .groups = "drop") %>% 
  pivot_wider(names_from = anio_min, values_from = total_casos, values_fill = 0) %>% 
  column_to_rownames("grupo_etario") %>% 
  as.matrix()

# 2. Ejecutar la Prueba de Chi-Cuadrado de Pearson
test_chisq <- chisq.test(tabla_contingencia)

# Mostrar los resultados principales en la consola
print(test_chisq)

# 3. Visualización de Residuos Estandarizados (Aportes a la asociación)
residuos_df <- as.data.frame(as.table(test_chisq$residuals)) %>% 
  rename(GrupoEtario = Var1, Anio = Var2, Residuo = Freq)

ggplot(residuos_df, aes(x = Anio, y = reorder(GrupoEtario, Residuo), fill = Residuo)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(
    low = "#2b5c8f", mid = "white", high = "#d95f02", 
    midpoint = 0, name = "Residuo\nAjustado"
  ) +
  labs(
    title = "Asociación entre Grupo Etario y Año de Notificación",
    subtitle = "Residuos estandarizados del Test de Chi-Cuadrado",
    x = "Año",
    y = "Grupo Etario",
    caption = paste0("Prueba de Chi-Cuadrado p-valor: ", format.pval(test_chisq$p.value, digits = 3))
  ) +
  theme_minimal()