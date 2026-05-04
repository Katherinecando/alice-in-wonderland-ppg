%% poster_hrm_mean_sd.m
% Poster-quality Audience Mean HRM ± SD (0–80 min)
% Works with messy WRT CSV files (sparse UTC, mixed cell types)

clear; clc; close all;

%% ================= USER SETTINGS =================
performanceMinutes = 80;
performanceSeconds = performanceMinutes * 60;
fsTarget = 1;                % 1 Hz resample
minHR = 40;                  % bpm
maxHR = 130;                 % bpm
minValidPoints = 120;        % minimum valid HR samples
minParticipants = 15;        % for mean ± SD
% ==================================================

%% ================= IMPORT CSV FILES =================
files = dir("C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\PPG_data");

if isempty(files)
    error('No WRT_*.csv files found. Place this script in the same folder as the CSV files.');
end

fprintf('Found %d CSV files\n', numel(files));

%% ================= STORAGE =================
HRM_all = {};
T_all   = {};
skipped = 0;

%% ================= PROCESS EACH FILE =================
for k = 1:numel(files)

    fname = files(k).name;
    fprintf('Processing: %s\n', fname);

    % -------- IMPORT CSV --------
    try
        raw = readcell(fname);
    catch
        warning('Skipping %s (cannot read file)', fname);
        skipped = skipped + 1;
        continue;
    end

    % Need UTC (col 1) and HRM (col 3)
    if size(raw,2) < 3
        warning('Skipping %s (less than 3 columns)', fname);
        skipped = skipped + 1;
        continue;
    end

    utc = raw(:,1);   % UTC timestamps (s)
    hrm = raw(:,3);   % HRM values (bpm)

    % -------- SAFE NUMERIC CONVERSION --------
    utc = cellfun(@toScalar, utc);
    hrm = cellfun(@toScalar, hrm);

    % Remove header row if present
    if ~isempty(utc) && isnan(utc(1))
        utc(1) = [];
        hrm(1) = [];
    end

    if numel(utc) < 10
        warning('Skipping %s (too few rows)', fname);
        skipped = skipped + 1;
        continue;
    end

    % -------- FORWARD-FILL UTC --------
    for i = 2:numel(utc)
        if isnan(utc(i))
            utc(i) = utc(i-1);
        end
    end

    % -------- FILTER VALID DATA --------
    valid = ~isnan(utc) & ~isnan(hrm) & hrm>=minHR & hrm<=maxHR;
    utc = utc(valid);
    hrm = hrm(valid);

    if numel(utc) < minValidPoints
        warning('Skipping %s (too few valid HR points)', fname);
        skipped = skipped + 1;
        continue;
    end

    % -------- TIME FROM START --------
    t = utc - utc(1);

    % Keep only performance window
    keep = t >= 0 & t <= performanceSeconds;
    t = t(keep);
    hrm = hrm(keep);

    if numel(t) < minValidPoints
        warning('Skipping %s (not enough data in 0–80 min)', fname);
        skipped = skipped + 1;
        continue;
    end

    % Remove duplicate timestamps
    [tUnique, ia] = unique(t,'stable');
    hrmUnique = hrm(ia);

    % Store
    T_all{end+1}   = tUnique;
    HRM_all{end+1} = hrmUnique;

end

fprintf('Loaded %d participants, skipped %d files\n', numel(HRM_all), skipped);

if numel(HRM_all) < 3
    error('Too few valid participants loaded.');
end

%% ================= RESAMPLE TO COMMON TIME =================
tCommon = (0:1/fsTarget:performanceSeconds)';   % seconds
tMin = tCommon / 60;                            % minutes
Nsamp = numel(tCommon);
nP = numel(HRM_all);

H = nan(Nsamp, nP);

for i = 1:nP
    H(:,i) = interp1(T_all{i}, HRM_all{i}, tCommon, 'linear', NaN);
end

%% ================= MEAN ± SD =================
meanHR = mean(H,2,'omitnan');
stdHR  = std(H,0,2,'omitnan');

nValid = sum(~isnan(H),2);
meanHR(nValid < minParticipants) = NaN;
stdHR(nValid  < minParticipants) = NaN;


%% ===== Poster polish: smooth mean and tidy aesthetics =====
meanSmooth = smoothdata(meanHR, 'movmean', 15, 'omitnan');  % ~15 s at 1 Hz
stdSmooth  = smoothdata(stdHR,  'movmean', 15, 'omitnan');

lo = meanSmooth - stdSmooth;
hi = meanSmooth + stdSmooth;

figure('Color','w','Position',[100 100 1100 520]); hold on;

% Shaded SD band (clean)
fill([tMin; flipud(tMin)], ...
     [lo; flipud(hi)], ...
     [0.2 0.5 0.8], ...
     'FaceAlpha',0.18, ...
     'EdgeColor','none');

% Mean line (clean + thick)
plot(tMin, meanSmooth, 'Color',[0 0.25 0.6], 'LineWidth',2.6);

% Axes & labels (poster sized)
xlim([0 80]);
ylim([55 95]);
xticks(0:10:80);
yticks(55:5:95);

xlabel('Time from performance start (min)','FontSize',16);
ylabel('Pulse rate (bpm)','FontSize',16);
title('Audience mean pulse rate during live performance','FontSize',18);

grid on;
set(gca,'FontSize',14,'LineWidth',1.2);
box off;

hold off;

%% ===== Export (best practice for posters) =====
%exportgraphics(gcf,'Audience_Mean_HRM_Poster.pdf','ContentType','vector');
%exportgraphics(gcf,'Audience_Mean_HRM_Poster.png','Resolution',300);


%% ================= EXPORT =================
%exportgraphics(gcf,'Audience_Mean_HRM_Poster2.png','Resolution',300);
%fprintf('Saved Audience_Mean_HRM_Poster2.png\n');

%% ================= HELPER FUNCTION =================
function y = toScalar(x)
% Converts mixed CSV cell content to numeric scalar or NaN
    if isempty(x)
        y = NaN;
    elseif isnumeric(x)
        y = double(x(1));
    elseif isstring(x) || ischar(x)
        y = str2double(strtrim(string(x)));
        if isnan(y), y = NaN; end
    else
        y = NaN;
    end
end
