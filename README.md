# Sensing the Heart: Quantifying the Audience Experience During a Live Performance of *Alice in Wonderland* via PPG Sensing

**EG3000 Individual Project — Katherine Cando | City, St George's University of London | 2025–26**

---

## Overview

This repository contains all MATLAB analysis scripts developed for an EG3000 engineering dissertation investigating physiological synchrony among live theatre audiences using wrist-worn PPG (photoplethysmography) sensors.

The study measured pulse rate, heart rate variability (HRV), and respiratory rate from 37 audience members during a full-length live performance of *Alice in Wonderland* by the Jasmin Vardimon Company (~80 minutes). Physiological synchrony was quantified using sliding-window mean pairwise Pearson correlation, applied separately to pulse rate and respiratory rate signals, to identify moments of collective physiological co-fluctuation during the performance.

**Key findings:**
- A structured pulse rate synchrony peak was identified at t ≈ 1,325 s (~22 minutes) with mean pairwise r = 0.168, substantially above the minimum-synchrony baseline (r = −0.019)
- Respiratory synchrony showed five oscillatory peaks across the performance, largely independent of the cardiac synchrony timecourse
- Post-performance questionnaire data (N = 32) indicated high engagement (mean 7.28/10) and a predominantly positive, high-arousal emotional profile

---

## Requirements

- **MATLAB** R2020b or later
- **Signal Processing Toolbox** (for `butter`, `filtfilt`, `findpeaks`)
- **Statistics and Machine Learning Toolbox** (for `corr`, `mad`, `movmedian`)
- **RRest toolbox v3.0** — required for the respiratory rate pipeline (`rrest_pipeline/`). Download from [github.com/peterhcharlton/RRest](https://github.com/peterhcharlton/RRest) and place the `RRest-master` folder alongside your working directory.

---

## Repository Structure

```
alice-in-wonderland-ppg/
│
├── final/                              ← Core analysis scripts (run these to reproduce all figures)
│   ├── 1_HRV_extraction_fixed2.m              Step 1 — PPG pre-processing, IBI extraction, HRV
│   ├── 2_build_theatre_data_for_RRest_v3.m    Step 2 — Build theatre_data.mat for RR pipeline
│   ├── 3_peaks_final_analysis.m               Step 3 — Pulse rate synchrony analysis (Figures 2–5)
│   ├── 4_plot_fig6_from_RRest.m               Step 4 — Figure 6: RR overlay (from RRest output)
│   ├── 5_overlay_HR_breathing_synchrony.m     Step 5 — Figure 8: PR + RR synchrony overlay
│   ├── 6_hrm_plot_try2.m                    Step 6 — Figure 1: Group mean pulse rate
│   ├── 7_questionarie_collective_analysis.m   Step 7 — Figures 9–10: Questionnaire analysis
│   └── sliding_synchrony.m                   Helper — sliding-window synchrony (called by script 3)
│
├── rrest_pipeline/                     ← Custom scripts that run inside the RRest pipeline
│   ├── setup_universal_params.m               RRest configuration (paths, subject list, settings)
│   ├── result_subject_1.m                     QC: inspect raw vs fused RR for one subject
│   ├── results_all_subjects.m                 Aggregate RRest output → RR_final.mat
│   └── breathing_synchrony_analysis.m         Compute breathing synchrony → breathing_synchrony_results.mat
│
├── development/                        ← Exploratory and superseded scripts (kept for transparency)
│   └── *.m
│
└── README.md
```

> **Note on RRest:** The `rrest_pipeline/` folder contains only the custom scripts written for this project. The RRest toolbox itself (Charlton et al., 2017) must be downloaded separately — it is third-party code and is not reproduced here.

---

## How to Run

Scripts must be run **in order**. Each script depends on variables or `.mat` files produced by the previous one.

---

### Step 1 — PPG pre-processing and HRV extraction
**Script:** `final/1_HRV_extraction_fixed2.m`

**What it does:** Reads all participant CSV files, cleans the PPG waveform (artefact masking, bandpass filtering), detects systolic peaks using `findpeaks`, extracts and cleans the IBI series, and computes time-domain HRV metrics (RMSSD, SDNN) in 60-second sliding windows.

**Before running:** Update `dataFolder` on line 18 to point to your local PPG CSV folder.

**Output:** `HRV_final.mat` — contains `HRM_mat`, `RMSSD_mat`, `SDNN_mat`, `tCommon` [4801 × N]

---

### Step 2 — Build theatre data for respiratory pipeline
**Script:** `final/2_build_theatre_data_for_RRest_v3_FORMATFIX.m`

**What it does:** Reads all CSV files, resamples and cleans each PPG waveform to 25 Hz, and packages them into the `theatre_data.mat` struct required by the RRest pipeline.

**Before running:** Update `csvFolder` to point to your PPG CSV folder.

**Output:** `theatre_data.mat`

---

### Step 2b — Run RRest respiratory rate estimation *(separate pipeline)*
**Scripts:** `rrest_pipeline/` folder

This sub-pipeline runs the RRest toolbox (Charlton et al., 2017) on the PPG data to extract per-participant respiratory rate estimates. Run in this order:

1. `final/2_build_theatre_data_for_RRest_v3_FORMATFIX.m` — formats PPG CSVs into `theatre_data.mat` (also Step 2 above)
2. `rrest_pipeline/setup_universal_params.m` — sets paths and subject list for RRest
3. Run `RRest.m` (from the downloaded RRest toolbox) — produces `N_rrEsts.mat` per subject
4. `rrest_pipeline/results_all_subjects.m` — aggregates and cleans all estimates → `RR_final.mat`
5. `rrest_pipeline/breathing_synchrony_analysis.m` — computes sliding-window RR synchrony → `breathing_synchrony_results.mat`

`rrest_pipeline/result_subject_1.m` is a QC utility to visually inspect the raw vs temporally-fused RR trace for a single subject.

---

### Step 3 — Pulse rate synchrony analysis
**Script:** `final/3_peaks_final_analysis.m`

**What it does:** Takes `HRM_mat` from Step 1 and computes the sliding-window (W = 120 s, step = 1 s) mean pairwise Pearson correlation synchrony timecourse. Identifies the primary synchrony peak and a minimum-synchrony baseline window, then produces correlation matrices, distribution plots, and a boxplot comparison.

**Before running:** Run Step 1 first (or load `HRV_final.mat`), then set `H = HRM_mat;` in the workspace.

**Output:** Figures 5–8 in dissertation. Variables `t_mid` and `sync_s` remain in workspace for Step 5.

---

### Step 4 — Figure 6: Respiratory rate overlay
**Script:** `final/4_plot_fig6_from_RRest.m`

**What it does:** Loads `RR_final.mat` produced by the RRest pipeline (Step 2b) and plots all 32 participants' cleaned, bounded respiratory rate traces overlaid with the smoothed group mean.

**Before running:** Complete Step 2b first so `RR_final.mat` exists.

**Output:** `Figure6_RR_overlay_RRest.png` (Figure 9 in dissertation)

---

### Step 5 — Figure 8: Pulse rate and respiratory synchrony overlay
**Script:** `final/5_overlay_HR_breathing_synchrony.m`

**What it does:** Loads `breathing_synchrony_results.mat` from the RRest pipeline and the pulse rate synchrony variables (`t_mid`, `sync_s`) from Step 3, interpolates both onto a common timeline, and plots them overlaid. Also computes cross-correlation between the two synchrony timecourses.

**Before running:** Complete Steps 2b and 3. Step 3 must still be active in the workspace.

**Output:** Figure 11 in dissertation (PR and RR synchrony overlay)

---

### Step 6 — Group mean pulse rate figure
**Script:** `final/6_hrm_group_trend.m`

**What it does:** Reads all CSV files, extracts device-computed HRM values, interpolates to 1 Hz, and plots the group mean ± 1 SD across the 80-minute performance.

**Before running:** Update `dataFolder` to point to your PPG CSV folder.

**Output:** Figure 1 in dissertation (group mean pulse rate)

---

### Step 7 — Questionnaire analysis
**Script:** `final/7_questionarie_collective_analysis.m`

**What it does:** Loads the questionnaire Excel file, computes group-level statistics for engagement, performance ratings, and emotion distribution, and produces bar charts.

**Before running:** Questionnaire Excel file required.
**Output:** Figures 9–10 in dissertation (questionnaire ratings and emotion distribution)

---

## Data Availability

The raw PPG waveform CSV files and questionnaire data are not included in this repository as they contain data from human participants collected under an institutional ethics protocol. The dataset was provided by the project supervisor.

If you are an assessor and require access to the raw data for verification, please contact the project supervisor.

---

## Development Scripts

The `development/` folder contains all earlier, exploratory, and superseded scripts written during the project. These are retained for transparency and to document the iterative development process, but they are **not** required to reproduce the final results. They include:

- Early pipeline attempts (`HRV_extraction_attempt.m`, `HRV_extraction_fixed.m`)
- Exploratory visualisation scripts (`step1_*.m`, `step2_*.m`, `variation_over_time.m`)
- Initial RRest setup and HR synchrony scripts (`setup_01_rrest.m`, `step3B_HR_synchrony_new.m`)
- Debugging and diagnostic snippets (`draft.m`, `hrv_check.m`, `rescue_script.m`)
- The synchrony formula documentation script (`synchrony_formula_demo.m`) — useful for understanding the mathematical approach

---

## Key References

- P. H. Charlton et al., "Extraction of respiratory signals from the ECG and PPG," *Physiol. Meas.*, vol. 38, no. 5, pp. 669–690, 2017. *(RRest toolbox)*
- F. Carter et al., "From story to heartbeats: physiological synchrony in theater audiences," *Psychol. Aesthetics Creativity Arts*, 2024.
- H. Hammond et al., "Narrative predicts cardiac synchrony in audiences," *Sci. Rep.*, vol. 14, p. 26369, 2024.
- F. Shaffer and J. P. Ginsberg, "An overview of heart rate variability metrics and norms," *Front. Public Health*, vol. 5, p. 258, 2017.

Full reference list is available in the dissertation.

---

## Acknowledgements

Sincere thanks to **Professor Caroline Li** for supervision and guidance throughout this project, and to the research team responsible for collecting the original PPG dataset.

---

*EG3000 Individual Project | Department of Engineering | City, St George's University of London | 2025–26*
