# 📊 Dashboard Epidemiológico: Vigilancia de Dengue en Argentina

Un tablero de control interactivo y reporte de análisis epidemiológico sobre la dinámica de transmisión del Dengue en Argentina, desarrollado en **R** y compilado de forma nativa con **Quarto Dashboards**.

🔗 **Ver Dashboard Interactivo en vivo:** [Explorar Tablero Web](https://tu-usuario.github.io/dashboard-dengue-argentina/) *(reemplazá este enlace por tu URL de GitHub Pages)*

---

## 📌 Descripción del Proyecto

Este proyecto integra herramientas de **minería de datos, cartografía interactiva y estadística inferencial** a partir de los registros del Sistema Nacional de Vigilancia de la Salud (SNVS). Su objetivo es caracterizar la propagación espacio-temporal del brote, analizar las tasas de incidencia por 100.000 habitantes y evaluar perfiles de riesgo específicos, como la notificación de casos en población gestante.

---

## 🔬 Componentes y Pestañas del Tablero

### 1. 📊 Panorama General
* **Tarjetas de Métricas (Value Boxes):** Total de casos notificados, provincia con mayor volumen de notificación, semana epidemiológica pico y porcentaje de casos en gestación.
* **Distribución Geográfica:** Mapa interactivo con proyección `leaflet` y escala ajustada ($\sqrt{n}$) para mitigar el sesgo de dispersión.
* **Curva Epidémica:** Análisis temporal por Semana Epidemiológica (SE) desagregado por evento y temporada.

### 2. 🗺️ Tasas por 100.000 habitantes
* **Ajuste Demográfico:** Normalización de la incidencia utilizando proyecciones poblacionales provinciales del INDEC.
* **Ranking Provincial:** Identificación de jurisdicciones de mayor impacto relativo, distinguiendo aquellas con baja estabilidad por volumen de casos ($n < 20$).
* **Tabla Dinámica:** Exploración de casos absolutos, población y tasa ajustada (`DT`).

### 3. 👥 Perfil Demográfico
* **Distribución por Edad:** Descomposición de la afectación por grupos etarios y comparación entre Dengue General y Dengue en Gestación.
* **Distribución Jurisdiccional:** Matriz de porcentajes acumulados por provincia.

### 4. 🧪 Análisis Inferencial
* **Regresión Logística Binomial ($OR$):** Cuantificación de factores asociados a la notificación en gestantes (*Forest Plot* e intervalos de confianza del 95%).
* **Gradiente Espacio-Temporal (Norte-Sur):** Evaluación de la aceleración/retraso de la semana pico provincial según su latitud mediante la **Correlación de Spearman** ($\rho$).
* **Estabilidad Etaria Interanual:** Test de **$\chi^2$ de Pearson** y matriz de residuos estandarizados para evaluar cambios interanuales en la estructura de edad de la población afectada.

### 5. 📝 Conclusiones y Cautelas Epidemiológicas
* Síntesis ejecutiva automatizada y discusión sobre limitaciones metodológicas (subregistro, sesgo de notificación, potencia analítica y variabilidad provincial).

---

## 🛠️ Tecnologías y Librerías Utilizadas

* **Lenguaje:** R 4.5.x
* **Entorno de Publicación:** Quarto Dashboard (`.qmd`)
* **Procesamiento de Datos:** `tidyverse`, `janitor`, `broom`
* **Geoprocesamiento y Mapas:** `sf`, `geoAr`, `leaflet`
* **Visualización Interactiva:** `plotly`, `DT`

---

## 📁 Estructura del Repositorio

```text
├── DATOS/
│   ├── informacion-publica-dengue-zika-nacional-se-1-2025-a-se38-2026-2026-10-05.csv
│   └── poblacion_provincias_2025.csv
├── dashboard_dengue_estatico.qmd   # Código fuente del dashboard en Quarto
├── index.html                       # Documento HTML renderizado para GitHub Pages
└── README.md                        # Documentación del proyecto
