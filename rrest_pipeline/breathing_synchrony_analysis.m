%% breathing_synchrony_analysis.m
% Clean, paste-ready script:
% - Loads RR_final + tGrid (from your cleaned breathing pipeline)
% - Z-scores each subject (focus on co-fluctuation, not absolute RR)
% - Computes sliding-window breathing synchrony = mean pairwise correlation
% - Plots synchrony over time + optional peak marking


clear; clc; close all;

%% ====== 0) Load cleaned breathing matrix ======
matFile = 'RR_final.mat';
if ~exist(matFile,'file')
    error("Can't find %s in current folder. Save RR_final/tGrid first.", matFile);
end

S = load(matFile);

if ~isfield(S,'RR_final') || ~isfield(S,'tGrid')
    error("RR_final.mat must contain RR_final and tGrid.");
end

RR_final = S.RR_final;     % [T x N] breaths/min, cleaned + smoothed, bad subjects removed
tGrid    = S.tGrid(:);     % [T x 1] seconds

dt = median(diff(tGrid),'omitnan');
fprintf("Loaded RR_final: %d timepoints x %d subjects | dt=%.3f s\n", ...
    size(RR_final,1), size(RR_final,2), dt);

%% ====== 1) Basic sanity checks ======
if size(RR_final,1) ~= numel(tGrid)
    error("RR_final rows (%d) must match tGrid length (%d).", size(RR_final,1), numel(tGrid));
end

% Optional: print summary
m_all = mean(RR_final,2,'omitnan');
fprintf("Group mean RR (cleaned): mean=%.2f bpm | min=%.2f | max=%.2f\n", ...
    mean(m_all,'omitnan'), min(m_all,[],'omitnan'), max(m_all,[],'omitnan'));

%% ====== 2) Z-score per subject (key for synchrony) ======
RRz = RR_final;
for k = 1:size(RRz,2)
    x = RRz(:,k);
    mu = mean(x,'omitnan');
    sd = std(x,0,'omitnan');
    if isfinite(sd) && sd > 0
        RRz(:,k) = (x - mu) / sd;
    else
        RRz(:,k) = NaN(size(x)); % subject unusable if flat/NaN
    end
end

%% ====== 3) Sliding-window synchrony settings ======
win_sec  = 60;    % window length in seconds (try 30, 60, 90)
step_sec = 5;     % step in seconds (smaller = smoother curve)

win_samp  = max(3, round(win_sec / dt));
step_samp = max(1, round(step_sec / dt));

fprintf("Synchrony windows: %d samples (%.1fs) | step %d samples (%.1fs)\n", ...
    win_samp, win_samp*dt, step_samp, step_samp*dt);

%% ====== 4) Compute mean pairwise correlation per window ======
T = size(RRz,1);
t_sync = [];
sync_curve = [];
n_pairs_used = [];

upperMask = []; % will define once we know N

for startIdx = 1:step_samp:(T - win_samp + 1)

    seg = RRz(startIdx:startIdx+win_samp-1, :);

    % Require at least 2 subjects with enough non-NaN in this window
    goodCols = sum(~isnan(seg),1) >= round(0.7*win_samp);
    seg = seg(:, goodCols);

    if size(seg,2) < 2
        sync_curve(end+1,1) = NaN;
        n_pairs_used(end+1,1) = 0;
        t_sync(end+1,1) = tGrid(startIdx + floor(win_samp/2));
        continue;
    end

    % Pairwise correlation matrix (handles NaNs)
    C = corr(seg, 'Rows','pairwise');

    % Upper triangle mean (exclude diagonal)
    if isempty(upperMask) || size(upperMask,1) ~= size(C,1)
        upperMask = triu(true(size(C)),1);
    end

    vals = C(upperMask);
    sync_curve(end+1,1) = mean(vals,'omitnan');

    % count usable pairs (non-NaN correlations)
    n_pairs_used(end+1,1) = sum(~isnan(vals));

    % window center time
    t_sync(end+1,1) = tGrid(startIdx + floor(win_samp/2));
end

%% ====== 5) Optional light smoothing of synchrony curve ======
sync_smooth = movmean(sync_curve, 3, 'omitnan');  % 3-point smoothing

%% ====== 6) Plot synchrony ======
figure('Color','w');
plot(t_sync/60, sync_curve, 'LineWidth',1.5); hold on;
plot(t_sync/60, sync_smooth, 'LineWidth',2);
grid on;
xlabel('Time (min)');
ylabel('Mean inter-subject correlation');
title(sprintf('Breathing synchrony (win=%ds, step=%ds)', win_sec, step_sec));
legend('Raw synchrony','Smoothed', 'Location','best');
ylim([-0.2 1]);

%% ====== 7) Plot pairs-used (QC) ======
figure('Color','w');
plot(t_sync/60, n_pairs_used, 'LineWidth',1.5);
grid on;
xlabel('Time (min)');
ylabel('Number of subject-pairs used');
title('QC: pairs contributing to synchrony per window');

%% ====== 8) Peak moments (top K peaks) ======

% ===== Better peak picking (distinct peaks) =====
minPeakDistance_min = 2;                      % separate events by >=2 minutes
minPeakDistance_samp = round((minPeakDistance_min*60) / step_sec);

minPeakHeight = 0.30;                         % ignore tiny peaks

[pks, locs] = findpeaks(sync_smooth, ...
    'MinPeakDistance', minPeakDistance_samp, ...
    'MinPeakHeight', minPeakHeight);

% Sort by height, take top K
K = 5;
[~, order] = sort(pks, 'descend');
order = order(1:min(K, numel(order)));

fprintf("\nTop %d distinct synchrony peaks:\n", numel(order));
for i = 1:numel(order)
    ii = order(i);
    fprintf("  %2d) t = %6.2f min | synchrony = %.3f | pairs=%d\n", ...
        i, t_sync(locs(ii))/60, pks(ii), n_pairs_used(locs(ii)));
end


% K = 5; % how many peaks to list
% tmp = sync_smooth;
% tmp(~isfinite(tmp)) = -Inf;
% 
% [pkVals, pkIdx] = maxk(tmp, K);
% fprintf("\nTop %d synchrony peaks (smoothed):\n", K);
% for i = 1:numel(pkIdx)
%     fprintf("  %2d) t = %6.2f min | synchrony = %.3f | pairs=%d\n", ...
%         i, t_sync(pkIdx(i))/60, pkVals(i), n_pairs_used(pkIdx(i)));
% end
% 
% Optional: annotate peaks on synchrony plot
% ===== Plot synchrony + annotate DISTINCT peaks =====
figure('Color','w');
plot(t_sync/60, sync_smooth, 'LineWidth',2); grid on; hold on;
xlabel('Time (min)');
ylabel('Synchrony');
title(sprintf('Breathing synchrony (smoothed) + top %d distinct peaks', numel(order)));
ylim([-0.2 1]);

for i = 1:numel(order)
    ii = order(i);                 % index into pks/locs
    idxPeak = locs(ii);            % index into t_sync / sync_smooth
    x = t_sync(idxPeak)/60;
    y = sync_smooth(idxPeak);

    plot(x, y, 'ro', 'MarkerSize',7, 'LineWidth',2);
    text(x, y, sprintf('  #%d', i), 'VerticalAlignment','bottom', 'FontSize',10);
end
% for i = 1:numel(pkIdx)
%     x = t_sync(pkIdx(i))/60;
%     y = sync_smooth(pkIdx(i));
%     plot(x, y, 'o', 'MarkerSize',6, 'LineWidth',1.5);
%     text(x, y, sprintf('  #%d', i), 'VerticalAlignment','bottom');
% end
% ylim([-0.2 1]);

%% ====== 9) Save outputs for later HR/HRV comparison ======
% out.sync_curve = sync_curve;
% out.sync_smooth = sync_smooth;
% out.t_sync = t_sync;
% out.win_sec = win_sec;
% out.step_sec = step_sec;
% out.n_pairs_used = n_pairs_used;
% 
% save('breathing_synchrony_results.mat','out');
% fprintf("\nSaved breathing_synchrony_results.mat\n");