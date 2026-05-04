# Sensing the Heart: Quantifying the Audience Experience During a Live Performance of *Alice in Wonderland* via PPG Sensing

**EG3000 Individual Project — Katherine Cando | City, St George's University of London | 2025–26**

---

## Overview

This repository contains all MATLAB analysis scripts developed for an EG3000 engineering dissertation investigating physiological synchrony among live theatre audiences using wrist-worn PPG (photoplethysmography) sensors.

The study measured pulse rate, pulse rate variability (PRV), and respiratory rate from 37 audience members during a full-length live performance of *Alice in Wonderland* by the Jasmin Vardimon Company (~80 minutes). Physiological synchrony was quantified using sliding-window mean pairwise Pearson correlation, applied separately to pulse rate and respiratory rate signals, to identify moments of collective physiological co-fluctuation during the performance.

**Key findings:**
- A structured pulse rate synchrony peak was identified at t ≈ 1,325 s (~22 minutes) with mean pairwise r = 0.168, substantially above the minimum-synchrony baseline (r = −0.019)
- Respiratory synchrony showed five oscillatory peaks across the performance, largely independent of the cardiac synchrony time course
- Post-performance questionnaire data (N = 32) indicated high engagement (mean 7.28/10) and a predominantly positive, high-arousal emotional profile

---

## Requirements

- **MATLAB** R2020b or later
- **Signal Processing Toolbox** (for `butter`, `filtfilt`, `findpeaks`)
- **Statistics and Machine Learning Toolbox** (for `corr`, `mad`, `movmedian`)

No additional toolboxes beyond the above are required. The respiratory rate estimation algorithm was adapted from the RRest toolbox (Charlton et al., 2017) but is implemented directly using standard MATLAB signal processing functions — the RRest toolbox itself does not need to be installed.

---

## Repository Structure

```
alice-in-wonderland-ppg/
│
├── final/                         ← Core analysis scripts (run these)
│   ├── 1_HRV_extraction_fixed2.m          Step 1 — PPG pre-processing, IBI extraction, HRV
│   ├── 2_build_theatre_data_for_RRest_v2.m Step 2 — Build theatre_data.mat for RR pipeline
│   ├── 3_peaks_final_analysis.m            Step 3 — Pulse rate synchrony analysis
│   ├── 4_plot_rr_overlay.m                 Step 4 — Respiratory rate extraction + RR synchrony
│   ├── 5_overlay_HR_breathing_synchrony.m  Step 5 — Overlay PR and RR synchrony timecourses
│   ├── 6_hrm_group_trend.m                 Step 6 — Group mean pulse rate figure
│   ├── 7_questionarie_collective_analysis.m Step 7 — Questionnaire analysis
│   └── sliding_synchrony.m                Helper function — called by scripts 3 and 4
│
└── README.md
```

---

## How to Run

Scripts must be run **in order**. Each script depends on variables or `.mat` files produced by the previous one.

### Step 1 — PPG pre-processing and HRV extraction
**Script:** `final/1_HRV_extraction_fixed2.m`

**What it does:** Reads all participant CSV files, cleans the PPG waveform (artefact masking, bandpass filtering), detects systolic peaks using `findpeaks`, extracts and cleans the IBI series, and computes time-domain HRV metrics (RMSSD, SDNN) in 60-second sliding windows.

**Before running:** Update `dataFolder` on line 18 to point to your local PPG CSV folder.

**Output:** `HRV_final.mat` — contains `HRM_mat`, `RMSSD_mat`, `SDNN_mat`, `tCommon` [4801 × N]

---

### Step 2 — Build theatre data for respiratory pipeline
**Script:** `final/2_build_theatre_data_for_RRest_v2.m`

**What it does:** Reads all CSV files again, resamples and cleans each PPG waveform to 25 Hz, and packages them into the `theatre_data.mat` struct required by the RR pipeline.

**Before running:** Update `csvFolder` on line 6 to point to your PPG CSV folder.

**Output:** `theatre_data.mat`

---

### Step 3 — Pulse rate synchrony analysis
**Script:** `final/3_peaks_final_analysis.m`

**What it does:** Takes `HRM_mat` from Step 1 and computes the sliding-window (W = 120 s, step = 1 s) mean pairwise Pearson correlation synchrony timecourse. Identifies the primary synchrony peak and a minimum-synchrony baseline, then produces correlation matrices, distribution plots, and a boxplot comparison.

**Before running:** Run Step 1 first, then add this line at the top of the script (or run in the same MATLAB session):
```matlab
H = HRM_mat;
```

**Output:** Figures 2–5 in dissertation (synchrony timecourse, correlation matrices, distribution, boxplot). Variables `sync`, `t_sync`, `t_mid`, `sync_s` remain in workspace for Step 5.

---

### Step 4 — Respiratory rate extraction and synchrony
**Script:** `final/4_plot_rr_overlay.m`

**What it does:** Loads `theatre_data.mat`, applies a three-stage RR estimation pipeline to each participant (BFi bandpass filter 0.15–0.55 Hz → WCH sliding Welch PSD 32 s/4 s → physiological gate 6–30 br/min), plots all participants' RR overlaid with the group mean, and computes + saves the respiratory synchrony timecourse.

**Before running:** Run Step 2 first. Ensure `sliding_synchrony.m` is on the MATLAB path.

**Output:** `RR_overlay_all_subjects.png` (Figure 6), `breathing_synchrony_results.mat` (used in Step 5)

---

### Step 5 — Overlay pulse rate and respiratory synchrony
**Script:** `final/5_overlay_HR_breathing_synchrony.m`

**What it does:** Loads `breathing_synchrony_results.mat` (Step 4) and interpolates the pulse rate synchrony curve (`sync_s`, `t_mid` from Step 3 workspace) onto the same timeline, then plots both on the same axes.

**Before running:** Run Steps 3 and 4 first (Step 3 must still be in the workspace for `sync_s` and `t_mid`).

**Output:** Figure 8 in dissertation (PR and RR synchrony overlay)

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

**Before running:** Place `emotion marker table.xlsx` in the same folder as the script, or update the `file` path on line 58.

**Output:** Figure 9 in dissertation (questionnaire ratings) and printed summary statistics

---

## Data Availability

The raw PPG waveform CSV files and questionnaire data are not included in this repository as they contain data from human participants collected under an institutional ethics protocol. The dataset was provided by the project supervisor.

If you are an assessor and require access to the raw data for verification purposes, please contact the project supervisor.

---

## Key References

- P. H. Charlton et al., "Extraction of respiratory signals from the ECG and PPG," *Physiol. Meas.*, vol. 38, no. 5, pp. 669–690, 2017. *(RRest toolbox)*
- F. Carter et al., "From story to heartbeats: physiological synchrony in theater audiences," *Psychol. Aesthetics Creativity Arts*, 2024.
- H. Hammond et al., "Narrative predicts cardiac synchrony in audiences," *Sci. Rep.*, vol. 14, p. 26369, 2024.
- F. Shaffer and J. P. Ginsberg, "An overview of heart rate variability metrics and norms," *Front. Public Health*, vol. 5, p. 258, 2017.

Full reference list is available in the dissertation.

---

## Acknowledgements

Sincere thanks to **Professor Caroline Li** for supervision and guidance throughout this project and to the research team responsible for collecting the original PPG dataset.

---

*EG3000 Individual Project | Department of Engineering | City, St George's University of London | 2025–26*
