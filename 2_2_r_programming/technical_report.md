# Project Development Report: Processing and Comparative Visualization of BDL Forest Inventory Data (2015–2025)

**Authors:** Karol Pietruszka, Łukasz Słowik  
**Research Object:** Piwniczna Forest District  
**Environment:** R (RStudio / VS Code)

---

## 1. Objective and Scope of Work
The objective of the project was to implement an automated data processing pipeline to compare forest inventory attributes (age, height, volume, DBH - diameter at breast height) over a 10-year period (2015–2025). The analysis focused on dominant species within the main canopy.

## 2. System Architecture and Function Description
The project was designed using a modular approach, ensuring high readability and self-documenting code. Naming conventions follow English standards for consistency with system libraries, while technical documentation adheres to the **Roxygen2** standard in Polish.

### 2.1. Main Control Script
*   **`main.R`**: Responsible for configuring input and output paths, loading external modules, and sequentially executing data processing stages and result export.

### 2.2. Module and Functional Description

#### Module `functions/setup_env.R` (Environment Automation)
*   `safe_library(packages)`: This function compares the list of required libraries with system resources, automatically installs missing packages from the CRAN repository, and imports them into the session.

#### Module `functions/data_processing.R` (ETL Processes)
*   `prepare_forest_data(df_input, year_suffix)`: Performs data cleaning (whitespace removal, type casting), filters the dataset to the "TREES" layer and dominant species (rank 1), and maps technical BDL abbreviations into readable attribute names with a year suffix.
*   `create_comparison_table(df_2015, df_2025)`: Integrates multi-temporal data using an *Inner Join* method, calculates differences in inventory attributes, and implements logic for detecting changes in dominant species.

#### Module `functions/visualization_tools.R` (Statistical Visualization)
*   `plot_structure_comparison(...)`: Generates overlapping histograms (alpha = 0.5), allowing for a visual assessment of growth trends and forest aging on a single chart.
*   `plot_species_area_change(...)`: Calculates polygon area directly from geometry (`st_area`), presenting changes in species structure in hectares, which is more substantively significant than a simple count of forest sub-compartments.
*   `plot_structure_by_species(...)`: Performs a panel (faceted) analysis for the 10 most common species, utilizing a variable Y-axis scale (`free_y`) to maintain readability for less frequent taxa.

#### Module `functions/spatial_tools.R` (Spatial Analysis / Spatial Databases)
*   `make_forest_map(...)`: A universal graphical template for thematic maps, ensuring visual consistency (centered titles, Viridis color palettes).
*   `create_comparison_maps(...)`: Coordinates the generation of a set of increment maps for forest attributes and a categorical map showing dominant species changes.

#### Module `functions/utils.R` (Utility Tools)
*   `save_plot(obj, filename, target_dir, w, h)`: Standardizes the graphic export process, enforcing 300 DPI resolution, a white background, and unified PNG file dimensions.

## 3. Generated Project Deliverables
As a result of the script execution, the following datasets and visualizations were generated in the `/output` directory:

### 3.1. Tabular Products (directory `/tables`)
*   **`species_comparison_2015_2025.csv`**: The resulting Master Table containing a comparison of forest inventory attributes for both years and calculated increments for height, volume, and DBH. It also includes a logical flag identifying sub-compartments where the dominant species has changed.

### 3.2. Statistical Visualizations (directory `/plots`)
*   **General Distribution Histograms**: Three charts (age, height, volume) showing overlapping statistical distributions for the years 2015 and 2025.
*   **Area Change Chart**: A bar chart representing the total area [ha] occupied by individual dominant species in both periods.
*   **Detailed Age Distribution**: Breakdown for the 10 most numerous dominant species.

### 3.3. Cartographic Products (directory `/maps`)
*   **Continuous Attribute Difference Maps**: Three thematic maps (height, volume, DBH) illustrating the spatial dimension of growth increments.
*   **Species Change Map**: A categorical map indicating the location of sub-compartments where a change in dominant species occurred over the 10-year cycle.

## 4. Summary and Conclusions
A functional programming approach combined with strong path parameterization was applied. The tool is universal and can be used to analyze any other forest district by simply updating the input constants in the `main.R` file. To maintain clarity, the entire codebase has been documented according to the **Roxygen2** standard.

## 5. Use of AI (AI Fundamentals)
AI models (LLMs) were utilized in this project for R syntax consultation, researching function documentation standards, and supporting the drafting of technical documentation. AI served as a supporting tool, allowing for the efficient transfer of best programming practices from the Python environment to the R environment.