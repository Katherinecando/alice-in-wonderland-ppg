% % If imported from Excel:
% Q = readtable("C:\Users\katyl\OneDrive - City, University of London\year 3\individual project\questionaire analysis\emotion marker table.xlsx");
% 
% % Basic stats
% mean_eng = mean(Q.Engagement, 'omitnan');
% sd_eng   = std(Q.Engagement, 'omitnan');
% 
% mean_perf = mean(Q.PerformanceRating, 'omitnan');
% sd_perf   = std(Q.PerformanceRating, 'omitnan');
% 
% fprintf('Engagement mean = %.2f ± %.2f\n', mean_eng, sd_eng);
% fprintf('Performance rating mean = %.2f ± %.2f\n', mean_perf, sd_perf);
% 
% % Split emotions
% allEmotions = {};
% for i = 1:height(Q)
%     if ~isempty(Q.EmotionDuring{i})
%         parts = strsplit(Q.EmotionDuring{i}, ';');
%         allEmotions = [allEmotions, parts];
%     end
% end
% 
% % Clean empty
% allEmotions = allEmotions(~cellfun(@isempty, allEmotions));
% 
% % Count frequency
% [uniqueEmo, ~, idx] = unique(allEmotions);
% counts = accumarray(idx, 1);
% 
% % Sort by frequency
% [counts_sorted, order] = sort(counts, 'descend');
% emo_sorted = uniqueEmo(order);
% 
% % Display
% for i = 1:length(emo_sorted)
%     fprintf('%s: %d\n', emo_sorted{i}, counts_sorted(i));
% end
% 
% figure;
% bar(counts_sorted);
% xticklabels(emo_sorted);
% xtickangle(45);
% ylabel('Count');
% title('Emotion frequency (group-level)');
% 
% % Alcohol
% alcohol_counts = groupcounts(Q.Alcohol24h);
% disp(alcohol_counts)
% 
% % Caffeine
% caffeine_counts = groupcounts(Q.Caffeine24h);
% disp(caffeine_counts)

%% Questionnaire collective analysis (meeting-ready)
clear; clc; close all;

% ---- 1) Load questionnaire table (raw sheet) ----
file = fullfile(pwd, "emotion marker table.xlsx");  % must be in the same folder as this script
Q = readtable(file, "VariableNamingRule","preserve");

disp("Detected columns:");
disp(Q.Properties.VariableNames);

% ---- 2) Helper: convert columns safely ----
toNumeric = @(x) local_toNumeric(x);
toYesNo   = @(x) local_toYesNo(x);

% ---- 3) Convert numeric rating columns ----
eng = toNumeric(Q.Engagement);
perf = toNumeric(Q.PerformanceRating);

% Basic stats
mean_eng  = mean(eng,  'omitnan');
sd_eng    = std(eng,   'omitnan');
n_eng     = sum(~isnan(eng));

mean_perf = mean(perf, 'omitnan');
sd_perf   = std(perf,  'omitnan');
n_perf    = sum(~isnan(perf));


% ---- 4) Convert Yes/No columns ----
s = lower(strtrim(string(Q.Alcohol24h)));

alc = NaN(size(s));
alc(startsWith(s,"yes")) = 1;
alc(startsWith(s,"no"))  = 0;
  % returns 1=Yes, 0=No, NaN=missing/unknown
caf = toYesNo(Q.Caffeine24h);

n_alc = sum(~isnan(alc));
p_alc_yes = 100*mean(alc, 'omitnan');   % mean of 0/1 = proportion Yes
p_alc_no  = 100 - p_alc_yes;

n_caf = sum(~isnan(caf));
p_caf_yes = 100*mean(caf, 'omitnan');
p_caf_no  = 100 - p_caf_yes;

% ---- 5) EmotionDuring distribution ----
emo = Q.EmotionDuring;

% Make it categorical safely
if iscell(emo) || isstring(emo) || ischar(emo)
    emo = string(emo);
end
emo = strtrim(lower(string(emo)));
emo(emo=="" | emo=="nan" | emo=="n/a" | emo=="na" | emo=="none") = missing;

emo_cat = categorical(emo);
[emo_counts, emo_labels] = histcounts(emo_cat);
emo_labels = categories(emo_cat);
emo_counts = countcats(emo_cat);

emo_total = sum(emo_counts);
emo_pct = 100 * emo_counts / max(emo_total,1);

% ---- 6) Print meeting summary ----
fprintf('\n===== QUESTIONNAIRE COLLECTIVE SUMMARY =====\n');

fprintf('Engagement:        mean = %.2f, SD = %.2f (n=%d)\n', mean_eng, sd_eng, n_eng);
fprintf('PerformanceRating: mean = %.2f, SD = %.2f (n=%d)\n', mean_perf, sd_perf, n_perf);

fprintf('\nAlcohol24h: Yes = %.1f%%, No = %.1f%% (n=%d)\n', p_alc_yes, p_alc_no, n_alc);
fprintf('Caffeine24h: Yes = %.1f%%, No = %.1f%% (n=%d)\n', p_caf_yes, p_caf_no, n_caf);

fprintf('\nEmotionDuring (n=%d):\n', emo_total);
for i = 1:numel(emo_labels)
    fprintf('  %s: %d (%.1f%%)\n', emo_labels{i}, emo_counts(i), emo_pct(i));
end
fprintf('===========================================\n');

% ---- 7) Figures (simple + clear) ----

% Figure 1: Engagement + Performance mean ± SD
figure('Color','w'); 
bar([mean_eng, mean_perf]); hold on;
errorbar(1:2, [mean_eng, mean_perf], [sd_eng, sd_perf], 'k.', 'LineWidth', 1.5);
set(gca,'XTick',1:2,'XTickLabel',{'Engagement','Performance'});
ylabel('Score'); title('Questionnaire ratings (mean ± SD)');
grid on;

% Figure 2: EmotionDuring distribution
figure('Color','w');
bar(emo_pct);
set(gca,'XTick',1:numel(emo_labels),'XTickLabel',emo_labels, 'XTickLabelRotation', 30);
ylabel('Percentage (%)'); title('Emotion during performance (distribution)');
grid on;

% Figure 3: Alcohol/Caffeine Yes %
figure('Color','w');
bar([p_alc_yes, p_caf_yes]);
set(gca,'XTick',1:2,'XTickLabel',{'Alcohol 24h','Caffeine 24h'});
ylabel('Yes (%)'); ylim([0 100]);
title('Lifestyle factors (Yes %)');
grid on;

%% ===== EmotionDuring summary: per-emotion totals + top combinations =====
% Assumes Q is a table and Q.EmotionDuring contains strings like:
% "happy;excited;delighted;" or "sad;sleepy;" etc.
% Delimiter assumed ';' (we handle extra spaces + trailing ';').

emoRaw = string(Q.EmotionDuring);
emoRaw = strtrim(emoRaw);

% Keep only non-missing / non-empty rows
valid = ~(ismissing(emoRaw) | emoRaw=="");
emoRaw_valid = emoRaw(valid);
nE = sum(valid);

fprintf('\nEmotionDuring (n=%d valid rows)\n', nE);

%% 1) TOP COMBINATIONS (exact strings, but cleaned)
% Clean: lowercase, remove extra spaces, remove duplicate ';', remove trailing ';'
comb = lower(emoRaw_valid);
comb = regexprep(comb, '\s+', '');      % remove spaces entirely inside
comb = regexprep(comb, ';+', ';');      % collapse multiple semicolons
comb = regexprep(comb, ';$', '');       % remove trailing semicolon

% Count combinations
[G, comboNames] = findgroups(comb);
comboCounts = splitapply(@numel, comb, G);

% Sort descending
[comboCounts, idx] = sort(comboCounts, 'descend');
comboNames = comboNames(idx);

fprintf('\nTop emotion combinations:\n');
topK = min(10, numel(comboNames));
for i = 1:topK
    fprintf('  %s: %d (%.1f%%)\n', comboNames(i), comboCounts(i), 100*comboCounts(i)/nE);
end

%% 2) PER-EMOTION TOTALS (ignores combinations)
% Split each row into tokens and count per emotion (presence/absence per person)
allTokens = strings(0,1);

% Build a list of token lists per participant row
tokenLists = cell(nE,1);
for i = 1:nE
    toks = split(comb(i), ';');
    toks = toks(toks ~= "");                 % remove empties
    toks = unique(strtrim(toks));            % unique within row
    tokenLists{i} = toks;
    allTokens = [allTokens; toks]; %#ok<AGROW>
end

% Unique emotion labels across dataset
emoLabels = unique(allTokens);
emoLabels = sort(emoLabels);

% Count how many rows contain each emotion
emoCounts = zeros(numel(emoLabels),1);
for k = 1:numel(emoLabels)
    lab = emoLabels(k);
    present = cellfun(@(t) any(t==lab), tokenLists);
    emoCounts(k) = sum(present);
end

% Sort descending
[emoCounts, idx2] = sort(emoCounts, 'descend');
emoLabels = emoLabels(idx2);

fprintf('\nPer-emotion selection totals (selected at least once):\n');
for k = 1:numel(emoLabels)
    fprintf('  %-12s %3d (%.1f%%)\n', emoLabels(k), emoCounts(k), 100*emoCounts(k)/nE);
end

%% OPTIONAL: If you want a simple bar chart (quick and clear for meetings)
figure;
bar(emoCounts / nE);
xticks(1:numel(emoLabels));
xticklabels(emoLabels);
xtickangle(45);
ylabel('Proportion of participants');
title('EmotionDuring: per-emotion proportions');
grid on;


%% ---- Local helper functions ----
function out = local_toNumeric(x)
    % Converts numeric column that might be stored as cell/text to double.
    if isnumeric(x)
        out = double(x);
        return;
    end
    if iscell(x)
        x = string(x);
    end
    if ischar(x)
        x = string(x);
    end
    x = strtrim(string(x));
    x(x=="" | lower(x)=="nan" | lower(x)=="n/a" | lower(x)=="na") = missing;
    out = str2double(x); % non-numeric becomes NaN
end

function out = local_toYesNo(x)
    % Converts Yes/No column to 1/0/NaN (missing)
    if islogical(x)
        out = double(x);
        return;
    end
    if isnumeric(x)
        % assume 1/0 already, but keep NaNs
        out = double(x);
        return;
    end

    if iscell(x)
        x = string(x);
    end
    if ischar(x)
        x = string(x);
    end
    x = strtrim(lower(string(x)));
    x(x=="" | x=="nan" | x=="n/a" | x=="na") = missing;

    out = NaN(size(x));
    out(x=="yes" | x=="y" | x=="true" | x=="1") = 1;
    out(x=="no"  | x=="n" | x=="false"| x=="0") = 0;
end




