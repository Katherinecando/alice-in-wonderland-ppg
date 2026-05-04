%% synchrony_formula_demo.m
%  Documents and demonstrates the pairwise synchrony calculation used in
%  this study. Run section-by-section (Ctrl+Enter) to follow the logic.
%
%  Reference scripts:  peaks_final_analysis.m  (pulse rate synchrony)
%                      breathing_synchrony_results.mat producer (RR synchrony)
%  Author: Katherine  |  EG3000 Dissertation 2025–26
% =========================================================================

%% ── SECTION 1: What is synchrony? ────────────────────────────────────────
%
%  Synchrony is defined as the degree to which participants' physiological
%  signals rise and fall together at the same time.
%
%  For N participants, there are N(N-1)/2 unique pairs.
%  For each pair (i, j) we compute the Pearson correlation coefficient r_ij
%  over a sliding time window W.
%
%  The group synchrony index S(t) at window centred on time t is:
%
%        S(t) = (2 / N(N-1)) * Σ_{i<j} r_ij(t)
%
%  i.e., the mean of all pairwise Pearson correlations in that window.
%  S(t) ∈ [-1, 1], where:
%       S ≈ 0  → no synchrony (random phases)
%       S → 1  → all participants' signals are perfectly in phase
%       S → -1 → anti-phase (unlikely in practice)

N_demo = 5;   % toy example with 5 participants
fprintf('For N = %d participants:\n', N_demo);
fprintf('  Unique pairs = N*(N-1)/2 = %d\n', N_demo*(N_demo-1)/2);

%% ── SECTION 2: Pearson correlation reminder ─────────────────────────────
%
%  For two time-series x and y over window W of length L:
%
%        r(x,y) = cov(x,y) / (std(x) * std(y))
%               = Σ[(x_k - x̄)(y_k - ȳ)] / sqrt(Σ(x_k-x̄)² * Σ(y_k-ȳ)²)
%
%  Implemented in MATLAB as:   corr(x, y, 'Rows', 'pairwise')
%  The 'pairwise' flag handles NaN: each pair uses all time-points where
%  BOTH signals are non-NaN.

% Quick numerical demo
rng(42);
x = cumsum(randn(120,1));   % simulated 120-s pulse rate trace, participant A
y = x + 0.3*randn(120,1);   % participant B (highly correlated with A)
z = cumsum(randn(120,1));   % participant C (independent)

r_AB = corr(x, y);
r_AC = corr(x, z);
fprintf('\nDemo correlations:\n');
fprintf('  r(A,B) = %.3f  (similar traces → high r)\n', r_AB);
fprintf('  r(A,C) = %.3f  (independent   → low  r)\n', r_AC);

%% ── SECTION 3: Full pairwise correlation matrix ─────────────────────────
%
%  For a segment matrix SEG of size [L × N] (L time-points, N participants):
%
%        R = corr(SEG, 'Rows','pairwise')    % [N × N] symmetric matrix
%
%  R(i,j) = r between participant i and participant j.
%  R(i,i) = 1 always (self-correlation, excluded from mean).
%
%  We take the upper triangle (indices where j > i) to avoid double-counting:
%        ut   = triu(true(N,N), 1)   % logical mask, diagonal+below = false
%        S(t) = mean(R(ut), 'omitnan')

SEG_demo = [x, y, z, cumsum(randn(120,1)), cumsum(randn(120,1))];
R_demo   = corr(SEG_demo, 'Rows','pairwise');

ut_demo  = triu(true(N_demo), 1);              % upper triangle mask
S_demo   = mean(R_demo(ut_demo), 'omitnan');   % group synchrony for this window

fprintf('\nFull correlation matrix R (5-participant demo):\n');
disp(round(R_demo, 3));
fprintf('Group synchrony S = mean of upper triangle = %.3f\n', S_demo);

%% ── SECTION 4: Sliding window parameters used in this study ─────────────
%
%  PULSE RATE synchrony   (peaks_final_analysis.m)
%    Signal:    H  [4801 × N]  pulse rate at 1 Hz, t = 0..4800 s
%    Window:    W  = 120 s   (captures ~2 respiratory cycles of PR fluctuation)
%    Step:      δt = 1  s    (1-second resolution output)
%    QC:        participants with >20% missing PR excluded globally
%               windows with <3 valid participants set to NaN
%               zero-variance columns excluded per window
%
%  RESPIRATORY RATE synchrony   (built from plot_rr_overlay.m output)
%    Signal:    RR [1201 × N]  respiratory rate at 0.25 Hz, t = 0..4800 s
%    Window:    W  = 60  s
%    Step:      δt = 5   s
%    QC:        subjects with >30% NaN on common grid excluded
%               windows require ≥70% valid samples per participant

fprintf('\nStudy parameters:\n');
fprintf('  Pulse rate synchrony:  W = 120 s, step = 1 s\n');
fprintf('  Respiratory synchrony: W = 60  s, step = 5 s\n');
fprintf('  Performance duration:  4800 s (80 min)\n');

%% ── SECTION 5: Reproduce the sliding window loop (pseudocode + real) ─────
%
%  The actual loop from peaks_final_analysis.m:
%
%    t_mid = (1 : step : T-win+1) + floor(win/2);   % window centre indices
%    sync  = nan(numel(t_mid), 1);
%
%    for k = 1 : numel(t_mid)
%        idx0 = (k-1)*step + 1;
%        seg  = H2(idx0 : idx0+win-1, :);          % [win × N] segment
%
%        v    = var(seg, 0, 1);
%        seg  = seg(:, v > 1e-8);                  % drop zero-variance cols
%
%        if size(seg,2) < 3; sync(k) = NaN; continue; end
%
%        R        = corr(seg, 'Rows','pairwise');
%        ut       = triu(true(size(R)), 1);
%        sync(k)  = mean(R(ut), 'omitnan');        % group synchrony at t_k
%    end
%
%  Output: sync(k) = S(t_k)   — the synchrony time-series plotted in results

disp('Section 5: see inline comments above for the full loop.');

%% ── SECTION 6: Statistical comparisons ──────────────────────────────────
%
%  Peak vs baseline comparison (peaks_final_analysis.m):
%    1. Identify peak synchrony time: t* = argmax S(t)
%    2. Peak window:     [t* - W/2 , t* + W/2]
%    3. Baseline window: lowest S(t) at least W seconds away from t*
%    4. Extract r_ij values for each window → distributions peak_r, base_r
%    5. Compare means:  mean(peak_r)  vs  mean(base_r)
%
%  Cross-modal coupling (hrv_syrnchrony_overlay.m):
%    r_coupling = corr(breath_sync, hrv_sync)   % Pearson over full timeline
%    Also: cross-correlation with ±50-step lag test to detect temporal offset

fprintf('\nSynchrony formula documentation complete.\n');
fprintf('See Methods section write-up in: synchrony_methods_text.md\n');
