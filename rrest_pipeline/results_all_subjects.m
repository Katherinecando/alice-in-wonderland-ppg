clear; clc; close all;
up = setup_universal_params('theatre');

dt = 1;                 % 1 Hz time grid
Tmax = 80*60;           % first 80 minutes
tGrid = (0:dt:Tmax)';   % seconds

RR_mat = nan(numel(tGrid), numel(up.paramSet.subj_list));

% ===== 1) BUILD RR_mat FIRST =====
for k = 1:numel(up.paramSet.subj_list)
    subj = up.paramSet.subj_list(k);
    rrPath = [up.paths.data_save_folder, num2str(subj), up.paths.filenames.rrEsts, '.mat'];

    if ~exist(rrPath,'file'); continue; end
    S = load(rrPath);

    % Prefer fused if present
    if isfield(S,'ppg1_flt_BFi_WCH_TFu')
        rr = S.ppg1_flt_BFi_WCH_TFu;
    elseif isfield(S,'ppg1_flt_BFi_WCH')
        rr = S.ppg1_flt_BFi_WCH;
    else
        continue;
    end

    RR_mat(:,k) = interp1(rr.t, rr.v, tGrid, 'linear', nan);
end

% ===== 2) NOW CLEAN =====
RR_clean = RR_mat;

% Hard physiological bounds
RR_clean(RR_clean < 6)  = NaN;
RR_clean(RR_clean > 25) = NaN;

% Robust outlier removal per subject
for k = 1:size(RR_clean,2)
    x = RR_clean(:,k);
    med = median(x,'omitnan');
    madv = mad(x,1);

    if madv > 0
        RR_clean(abs(x - med) > 4*madv, k) = NaN;
    end
end

m_subj_c = mean(RR_clean,1,'omitnan');
mx_subj_c = max(RR_clean,[],1,'omitnan');
[sortedMaxC, idxC] = sort(mx_subj_c, 'descend');

disp("Top 5 subject max RRs (cleaned):");
disp(table(idxC(1:5)', sortedMaxC(1:5)', m_subj_c(idxC(1:5))', ...
    'VariableNames', {'Subject','MaxRR','MeanRR'}));

% Smooth for group trend
RR_smooth = RR_clean;
for k = 1:size(RR_clean,2)
    RR_smooth(:,k) = movmedian(RR_clean(:,k), 15, 'omitnan'); % 15 sec
end

% ===== 3) QC: Top max RRs BEFORE cleaning =====
m_subj = mean(RR_mat,1,'omitnan');
mx_subj = max(RR_mat,[],1,'omitnan');
[sortedMax, idx] = sort(mx_subj, 'descend');

disp("Top 5 subject max RRs (raw):");
disp(table(idx(1:5)', sortedMax(1:5)', m_subj(idx(1:5))', ...
    'VariableNames', {'Subject','MaxRR','MeanRR'}));


nan_pct_clean = mean(isnan(RR_clean),1)*100;
bad_flags = nan_pct_clean > 40;   % threshold, adjust (30–50% typical)

fprintf("Subjects flagged (>40%% missing after cleaning): %d / %d\n", sum(bad_flags), numel(bad_flags));
disp(find(bad_flags));

good_subj_mask = ~bad_flags;
RR_final = RR_smooth(:, good_subj_mask);
fprintf("Final sample size: %d subjects\n", sum(good_subj_mask));
% ===== 4) Plot cleaned mean ± SD =====
% m = mean(RR_smooth,2,'omitnan');
% sd = std(RR_smooth,0,2,'omitnan');
% 
% figure('Color','w');
% plot(tGrid/60, m, 'LineWidth',1.5); hold on;
% plot(tGrid/60, m+sd, '--');
% plot(tGrid/60, m-sd, '--');
% grid on;
% xlabel('Time (min)');
% ylabel('Breaths/min');
% title('Breathing rate (cleaned, mean ± SD)');

m = mean(RR_final,2,'omitnan');
sd = std(RR_final,0,2,'omitnan');

figure('Color','w');
plot(tGrid/60, m, 'LineWidth',2); hold on;
fill([tGrid/60; flipud(tGrid/60)], ...
     [m-sd; flipud(m+sd)], ...
     [0.8 0.85 1], 'EdgeColor','none','FaceAlpha',0.4);
grid on;
xlabel('Time (min)');
ylabel('Breaths/min');
title('Audience Breathing Rate (Mean ± SD)');
 
%second plot bad subject example 
badSubj = 4;                 % from your top list
k = badSubj;                 % because your table uses Subject index = column index

figure('Color','w');
plot(tGrid/60, RR_mat(:,k), 'DisplayName','Raw'); hold on;
plot(tGrid/60, RR_clean(:,k), 'DisplayName','Cleaned');
plot(tGrid/60, RR_smooth(:,k), 'DisplayName','Cleaned + Smoothed');
grid on; xlabel('Time (min)'); ylabel('Breaths/min');
legend; title(sprintf('Subject %d RR: raw vs cleaned', badSubj));
ylim([0 30]);

save('RR_final.mat','RR_final','tGrid');