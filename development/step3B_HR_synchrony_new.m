%% HR synchrony aligned to breathing synchrony (same window/step)
% Requires: H (time x participants), tCommon, fsTarget
fsTarget = 1;
t = tCommon(:);
[N, P] = size(H);

% ---- match breathing settings
win_sec  = 60;        % breathing used 60s
step_sec = 5;         % breathing used 5s

win  = round(win_sec  * fsTarget);
step = round(step_sec * fsTarget);

nWin = floor((N - win) / step) + 1;

sync_t = NaN(nWin,1);
t_mid  = NaN(nWin,1);
nPairs = NaN(nWin,1);

for w = 1:nWin
    idx = (w-1)*step + (1:win);
    X = H(idx, :);  % win x P

    % --- Z-score each participant within this window (important!)
    for k = 1:P
        xk = X(:,k);
        mu = mean(xk,'omitnan');
        sd = std(xk,0,'omitnan');
        if isfinite(sd) && sd > 0
            X(:,k) = (xk - mu) / sd;
        else
            X(:,k) = NaN(size(xk));
        end
    end

    % Correlation matrix (pairwise NaN handling)
    Rw = corr(X, 'Rows','pairwise');

    mask = triu(true(P),1);
    vals = Rw(mask);

    sync_t(w) = mean(vals, 'omitnan');
    nPairs(w) = sum(~isnan(vals));
    t_mid(w)  = mean(t(idx));   % time at window centre
end

% Smooth (match breathing: 3 points at 5s step = ~15s)
sync_s = movmean(sync_t, 3, 'omitnan');

% ---- Quick plot for HR synchrony alone
figure('Color','w'); hold on; grid on;
plot(t_mid/60, sync_t, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
plot(t_mid/60, sync_s, 'k', 'LineWidth', 2.0);
xlabel('Time (min)');
ylabel('Mean inter-participant correlation');
title(sprintf('HR synchrony (win=%ds, step=%ds)', win_sec, step_sec));
legend({'Raw','Smoothed'}, 'Location','best');

% ---- QC: pairs contributing
figure('Color','w');
plot(t_mid/60, nPairs, 'LineWidth', 1.5);
grid on;
xlabel('Time (min)');
ylabel('Number of subject-pairs used');
title('HR synchrony QC: pairs used per window');
%% HR synchrony aligned to breathing synchrony (same window/step)
% Requires: H (time x participants), tCommon, fsTarget

t = tCommon(:);
[N, P] = size(H);

% ---- match breathing settings
win_sec  = 60;        % breathing used 60s
step_sec = 5;         % breathing used 5s

win  = round(win_sec  * fsTarget);
step = round(step_sec * fsTarget);

nWin = floor((N - win) / step) + 1;

sync_t = NaN(nWin,1);
t_mid  = NaN(nWin,1);
nPairs = NaN(nWin,1);

for w = 1:nWin
    idx = (w-1)*step + (1:win);
    X = H(idx, :);  % win x P

    % --- Z-score each participant within this window (important!)
    for k = 1:P
        xk = X(:,k);
        mu = mean(xk,'omitnan');
        sd = std(xk,0,'omitnan');
        if isfinite(sd) && sd > 0
            X(:,k) = (xk - mu) / sd;
        else
            X(:,k) = NaN(size(xk));
        end
    end

    % Correlation matrix (pairwise NaN handling)
    Rw = corr(X, 'Rows','pairwise');

    mask = triu(true(P),1);
    vals = Rw(mask);

    sync_t(w) = mean(vals, 'omitnan');
    nPairs(w) = sum(~isnan(vals));
    t_mid(w)  = mean(t(idx));   % time at window centre
end

% Smooth (match breathing: 3 points at 5s step = ~15s)
sync_s = movmean(sync_t, 3, 'omitnan');

% ---- Quick plot for HR synchrony alone
figure('Color','w'); hold on; grid on;
plot(t_mid/60, sync_t, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
plot(t_mid/60, sync_s, 'k', 'LineWidth', 2.0);
xlabel('Time (min)');
ylabel('Mean inter-participant correlation');
title(sprintf('HR synchrony (win=%ds, step=%ds)', win_sec, step_sec));
legend({'Raw','Smoothed'}, 'Location','best');

% ---- QC: pairs contributing
figure('Color','w');
plot(t_mid/60, nPairs, 'LineWidth', 1.5);
grid on;
xlabel('Time (min)');
ylabel('Number of subject-pairs used');
title('HR synchrony QC: pairs used 