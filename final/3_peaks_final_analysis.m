%% ASSUMES YOU ALREADY HAVE IN WORKSPACE (loaded from HRV_final.mat):
% H: [T x N] heart rate (or HRM) at 1 Hz, aligned (T=4801, N=33)
% tCommon: [T x 1] time in seconds (0..4800)

fs = 1;                 % Hz
winSec = 120;           % sliding window length in seconds
win = winSec * fs;
step = 1;               % 1 sec steps

[T, N] = size(H);

% --- safety: remove columns with too many NaNs ---
nanFrac = mean(isnan(H),1);
keep = nanFrac < 0.2;   % keep participants with <20% missing
H2 = H(:,keep);
N2 = size(H2,2);

% --- fill small gaps (optional) ---
for i = 1:N2
    H2(:,i) = fillmissing(H2(:,i), 'linear', 'EndValues', 'nearest');
end

% --- sliding synchrony (mean pairwise correlation per window) ---
t_mid = (1:step:(T-win+1)) + floor(win/2);
sync = nan(numel(t_mid),1);

for k = 1:numel(t_mid)
    idx0 = (k-1)*step + 1;
    seg = H2(idx0:idx0+win-1, :);

    % remove any zero-variance columns in this segment (prevents NaN corr)
    v = var(seg,0,1);
    seg = seg(:, v > 1e-8);

    if size(seg,2) < 3
        sync(k) = NaN;
        continue;
    end

    R = corr(seg, 'Rows','pairwise');

    % mean of upper triangle excluding diagonal
    ut = triu(true(size(R)), 1);
    sync(k) = mean(R(ut), 'omitnan');
end

t_sync = tCommon(t_mid);

% --- find peak synchrony time ---
[peakVal, peakIdx] = max(sync);
peakTime = t_sync(peakIdx);

fprintf('Peak synchrony = %.3f at time %.1f seconds\n', peakVal, peakTime);

%% Define PEAK window and BASELINE window
% Peak window centered at peakTime
peakCenter = peakTime;
peakStart  = max(0, peakCenter - winSec/2);
peakEnd    = min(tCommon(end), peakCenter + winSec/2);

% Baseline window: choose a low-synchrony area (e.g., after peak)
% Simple automatic choice: pick the minimum synchrony time at least winSec away from peak
minMask = abs(t_sync - peakTime) > winSec;
[~, minIdxLocal] = min(sync(minMask));
t_candidates = t_sync(minMask);
baseCenter = t_candidates(minIdxLocal);

baseStart = max(0, baseCenter - winSec/2);
baseEnd   = min(tCommon(end), baseCenter + winSec/2);

% Convert time windows to indices in H2
peakIdxRange = round(peakStart):round(peakEnd);
baseIdxRange = round(baseStart):round(baseEnd);

peakIdxRange = peakIdxRange(peakIdxRange>=0 & peakIdxRange<=tCommon(end));
baseIdxRange = baseIdxRange(baseIdxRange>=0 & baseIdxRange<=tCommon(end));

peakSeg = H2(peakIdxRange+1, :);  % +1 because tcommon starts at 0
baseSeg = H2(baseIdxRange+1, :);

%% Compute correlation matrices + mean r
Rp = corr(peakSeg, 'Rows','pairwise');
Rb = corr(baseSeg, 'Rows','pairwise');

utp = triu(true(size(Rp)), 1);
utb = triu(true(size(Rb)), 1);

peak_r = Rp(utp);
base_r = Rb(utb);

mean_peak = mean(peak_r, 'omitnan');
mean_base = mean(base_r, 'omitnan');

fprintf('Mean correlation during peak window    = %.4f\n', mean_peak);
fprintf('Mean correlation during baseline window = %.4f\n', mean_base);

%% PLOT 1: synchrony over time with windows
figure;
plot(t_sync, sync, 'k-', 'LineWidth', 1.5); hold on;
xline(peakStart, '--r'); xline(peakEnd, '--r');
xline(baseStart, '--b'); xline(baseEnd, '--b');
xlabel('Time (s)');
ylabel('Synchrony (mean pairwise r)');
title(sprintf('Synchrony over time (sliding window = %ds)', winSec));
grid on; drawnow;

%% PLOT 2: histogram distributions
figure;
histogram(peak_r, 'Normalization','probability'); hold on;
histogram(base_r, 'Normalization','probability');
legend('Peak window','Baseline window');
xlabel('Pairwise correlation r');
ylabel('Probability');
title('Distribution of correlations: Peak vs Baseline');
grid on; drawnow;

%% PLOT 3: heatmaps
figure;
subplot(1,2,1);
imagesc(Rp); axis image; colorbar;
title(sprintf('Peak window (mean r=%.3f)', mean_peak));
xlabel('Participant'); ylabel('Participant');

subplot(1,2,2);
imagesc(Rb); axis image; colorbar;
title(sprintf('Baseline window (mean r=%.3f)', mean_base));
xlabel('Participant'); ylabel('Participant');
drawnow;

%% Extended analysis: top-1000 synchrony windows vs random baseline
% Take top N sync points and compare their mean sync vs random baseline points
Ntop = min(1000, sum(~isnan(sync)));
[~, order] = sort(sync, 'descend');
topIdx = order(1:Ntop);
topSync = sync(topIdx);

% Random baseline sample matched in count (avoid within peak zone)
validBase = find(minMask & ~isnan(sync));
rng(1);
randIdx = randsample(validBase, Ntop, true);
randSync = sync(randIdx);

fprintf('Top-%d mean synchrony = %.4f\n', Ntop, mean(topSync,'omitnan'));
fprintf('Random baseline mean synchrony = %.4f\n', mean(randSync,'omitnan'));

% Quick plot
figure;
boxplot([topSync(:), randSync(:)], 'Labels', {'Top synchrony points','Random baseline'});
ylabel('Synchrony (mean r)');
title('Top synchrony vs random baseline');
grid on; drawnow;
