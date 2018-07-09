% Run adaptive BSI algorithm: RNMCFLMS
% This script runs the RNMCFLMS algorithm for blind
% system identification, the acoustic source is
% a male speaker
%
% References:
%   [1] J. Allen and D. Berkley, "Image method for 
%       efficiently simulating small room acoustics",
%       JASA, 1979.
%   [2] Y. Huang and J. Benesty, "Frequency-Domain 
%       adaptive approaches to blind multi-channel
%       identification," IEEE Trans. Sig. Process., 
%       Vol. 51, No. 1, Jan 2003.
%   [3] M. Haque and M. Hasan, "Noise robust multi-
%       channel frequency-domain LMS algorithms
%       for blind channel identification," IEEE Signal 
%       Process. Lett., vol. 15, pp. 305-308, 2008.
%
% Authors: E.A.P. Habets
%
% History: 2009-07-10 Initial version
%
% Copyright (C) Imperial College London 2009-2010

clc;
clear; 
close all;

%% Initialization
M = 4;          % number of channels
fs = 8e3;       % sampling frequency
L = 256;        % channel length
F = 2*L;        % frame-length
SNR = 50;       % signal to noise ratio (in dB)
rho = 0.2;      % step-size
lambda = 0.98;  % forgetting-factor

% Generate AIRs
air.c = 342;  % speed of sound
air.T60 = 0.3;  % reverberation time
air.room_dim = [5; 6; 3];  % room dimension
air.mic_spacing = 0.2;  % microphone spacing (m)
air.src_pos = [100*pi/180 2*pi/180 2];  % source location
air.cen_pos = [2.5; 2; 1.6];  % centre pos. of the array
h = generate_data(M, L, fs, air);

% Load source signal
N = 18*fs;  % Simulation time in seconds
[s, fs_wav] = audioread([datapath 'male_english_8k.wav']);
if fs_wav ~= fs
    error('Incorrect sample frequency.');
end
s = s(1:N);
% Add small amount of noise to source signal to improve stability
RandStream.setGlobalStream(RandStream('mt19937ar','Seed',1));
va = randn(size(s,1), 1);
va = sqrt(var(s)/(10^(40/10)*mean(var(va)))) .* va;
s = s + va;
s = 0.9 * s' / max(abs(s));

% Calculate noisy sensor signals with correct SNR
z = fftfilt(h, s);
RandStream.setGlobalStream(RandStream('mt19937ar','Seed',50));
v = randn(N, M);  % Generate additive noise
v = sqrt(var(s)*norm(h(:),2).^2/(10^(SNR/10)*M*mean(var(v)))) .* v;
x = z + v;

% Initialize RNMCFLMS
[h_hat, P_k_avg] = init_nmcflms(L, F, M, x(1:F,:));
ns = L/8;  % number of new samples per iteration
B = fix(N/ns);  % number of input blocks of length L
npm_dB = zeros(B,1);

%% Processing Loop: run RNMCFLMS [2,3]
wbar = waitbar(0,'RNMCFLMS');
for bb = 1 : B
    waitbar(bb/B);
    if bb == 1
        xm = [zeros(F-ns,M); x(1:ns,:)]; 
    else
        xm = [xm(ns+1:end,:); x((bb-1)*ns+1:bb*ns,:)]; 
    end
    
    Xm = fft(xm,F);
    P_x = conj(Xm).*Xm;
    delta = (M-1)*mean(mean(P_x));
    
    [h_hat, P_k_avg] = rnmcflms(xm, h_hat, P_k_avg,...
        rho, lambda, delta);
    npm_dB(bb) = 20*log10(npm(h, h_hat));
end
close(wbar);

%% Plot results
% NPM
figure(1); plot_npm(npm_dB, fs, ns);  
legend('RNMCFLMS');
title(['L= ',num2str(L), ', \rho= ',num2str(rho), ...
    ', \lambda= ',num2str(lambda), ', SNR= ', ...
    num2str(SNR), ', M= ', num2str(M)]);

% Filter coeff.
figure(2); plot_filter(h,h_hat);  

% Magnitude response
figure(3);
freqs = (0:(fs/2)/(L/2):(fs/2))/1000;
H = fft(h(:,1)./norm(h(:,1)),L);
H_hat = fft(h_hat(:,1)./norm(h_hat(:,1)),L);
plot(freqs,20*log10(abs(H(1:end/2+1)))); hold on; 
plot(freqs,20*log10(abs(H_hat(1:end/2+1))), 'r'); grid on; hold off;
xlabel('Frequency (kHz)');
ylabel('Magnitude (dB)');
legend('h','h_{hat}');
axis tight;

% First microphone signal
figure(4); 
plot_time(x(:,1), fs);  