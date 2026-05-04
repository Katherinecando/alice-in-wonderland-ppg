whos raw

raw{1}

size(raw{1})



% 

% % 1) Headers

% headers = raw(1,:);

% disp(headers)

% 

% % 2) Print header names with column indices

% for c = 1:numel(headers)

%     fprintf('Col %d: %s\n', c, string(headers{c}));

% end

% 

% data = raw(2:end,:);

% headers = raw(1,:);

% 

% % numeric conversion (strings -> numbers)

% X = NaN(size(data,1), size(data,2));

% for c = 1:size(data,2)

%     X(:,c) = str2double(string(data(:,c)));

% end

% 

% utcCol   = 1;

% ppgCol   = 2;  % DATA

% statusCol= 5;  % STATU

% idCol    = 6;  % dummy

% 

% ids = X(:,idCol);

% uids = unique(ids(~isnan(ids)));

% 

% fprintf('Found %d unique IDs in dummy column.\n', numel(uids));

% tab = array2table([uids, arrayfun(@(u) sum(ids==u), uids)], ...

%     'VariableNames', {'ID','Nrows'});

% disp(tab);

% 

% %% Breathing surrogate from PPG DATA (single recording, toolbox-free)

% 

% headers = raw(1,:);

% data = raw(2:end,:);

% 

% % Convert to numeric (strings -> numbers)

% X = NaN(size(data,1), size(data,2));

% for c = 1:size(data,2)

%     X(:,c) = str2double(string(data(:,c)));

% end

% 

% utc = X(:,1);      % UTC

% ppg = X(:,2);      % DATA (PPG)

% st  = X(:,5);      % STATU (optional quality flag)

% 

% % Basic valid mask

% mask = ~isnan(utc) & ~isnan(ppg);

% 

% % Optional: if STATU is a quality flag and you know 1=good, uncomment:

% % mask = mask & (st==1);

% 

% utc = utc(mask);

% ppg = ppg(mask);

% 

% % Sort by time

% [utc, order] = sort(utc);

% ppg = ppg(order);

% 

% % Infer UTC units -> seconds

% dt_med = median(diff(utc));

% fprintf('Median UTC step = %.6f (raw units)\n', dt_med);

% 

% if dt_med > 0.5 && dt_med < 2

%     t_sec = utc - utc(1);          % seconds

% elseif dt_med > 500 && dt_med < 2000

%     t_sec = (utc - utc(1))/1e3;    % milliseconds

% elseif dt_med > 5e5 && dt_med < 2e6

%     t_sec = (utc - utc(1))/1e6;    % microseconds

% else

%     warning('UTC units unclear; assuming seconds.');

%     t_sec = utc - utc(1);

% end

% 

% fs = 1/median(diff(t_sec));

% fprintf('Estimated fs = %.2f Hz\n', fs);

% 

% % Clean + detrend

% ppg = ppg(:);

% ppg = ppg - mean(ppg,'omitnan');

% ppg(isnan(ppg)) = 0;

% 

% baseline_win_sec = 2;                           % remove slow drift

% baseline_win = max(3, round(baseline_win_sec*fs));

% baseline = movmean(ppg, baseline_win);

% x = ppg - baseline;

% 

% % FFT bandpass in respiration band 0.10â0.40 Hz (6â24 breaths/min)

% f1 = 0.10; f2 = 0.40;

% 

% N = numel(x);

% Xf = fft(x);

% f = (0:N-1)'*(fs/N);

% 

% maskBP = (f>=f1 & f<=f2) | (f>=(fs-f2) & f<=(fs-f1));

% Xbp = zeros(size(Xf));

% Xbp(maskBP) = Xf(maskBP);

% 

% resp = real(ifft(Xbp));

% 

% % Breathing rate estimate (dominant frequency)

% Rf = abs(fft(resp));

% bandIdx = (f>=f1 & f<=f2);

% fb = f(bandIdx);

% [~,kmax] = max(Rf(bandIdx));

% f_peak = fb(kmax);

% br_bpm = f_peak*60;

% 

% fprintf('Estimated breathing rate ~ %.1f breaths/min\n', br_bpm);

% 

% % Plot full recording (minutes)

% figure('Color','w');

% plot(t_sec/60, resp, 'k'); grid on;

% xlabel('Time (min)');

% ylabel('Respiration surrogate (a.u.)');

% title(sprintf('PPG-derived breathing surrogate (%.1f breaths/min)', br_bpm));

% 

% figure('Color','w');

% plot(t_sec/60, resp, 'k'); grid on;

% xlim([2 5]);  % change these numbers

% xlabel('Time (min)');

% ylabel('Resp surrogate (a.u.)');

% title('Zoomed breathing surrogate (3 min)');

% 

% 

