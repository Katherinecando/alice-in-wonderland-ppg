function [sync_t, sync_val] = sliding_synchrony(X, tCommon, win_s, step_s, minFracValid)

% X: (T x P) matrix (e.g., RMSSD_mat)

% tCommon: (T x 1) time in seconds

% win_s: window length in seconds (e.g., 180)

% step_s: step in seconds (e.g., 5)

% minFracValid: fraction of valid samples per participant in window (e.g., 0.7)



tStart = tCommon(1);

tEnd   = tCommon(end);



edges = tStart:step_s:(tEnd-win_s);

nW = numel(edges);



sync_t = edges(:) + win_s/2;

sync_val = nan(nW,1);



for k = 1:nW

    a = edges(k); b = a + win_s;

    idx = (tCommon >= a) & (tCommon < b);



    W = X(idx,:);



    % Require enough valid samples per participant

    fracValid = sum(~isnan(W),1) / size(W,1);

    keepP = fracValid >= minFracValid;



    W = W(:,keepP);

    if size(W,2) < 3

        continue

    end



    % Fill remaining NaNs inside this window (per participant)

    for p = 1:size(W,2)

        W(:,p) = fillmissing(W(:,p), 'linear', 'EndValues', 'nearest');

    end



    % Correlation across participants

    C = corr(W, 'Rows','pairwise');

    mask = ~eye(size(C));

    sync_val(k) = mean(C(mask), 'omitnan');

end

end
