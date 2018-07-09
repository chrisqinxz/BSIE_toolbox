% Run equalization algorithm: LS
% This script runs the least squares (LS)
% algorithm for equalization.
%
% Authors: E.A.P. Habets
%
% History: 2009-07-11 Initial version
%
% Copyright (C) Imperial College London 2009-2010

clc
clear
close all

%% Initialization
M = 2;     % number of channels
fs = 8e3;  % sampling frequency
L = 128;   % channel length
Li = L-1;
k = 0;

% Generate AIRs
air.c = 342;  % speed of sound
air.T60 = 0.3;  % reverberation time
air.room_dim = [10; 10; 3];  % room dimension
air.mic_spacing = 0.2;  % microphone spacing (m)
air.src_pos = [100*pi/180 2*pi/180 3];  % source location
air.cen_pos = [5; 4; 1.6];  % centre pos. of the array
h = generate_data(M, L, fs, air);

% Truncate and normalize room impulse response
h = h(1:L,:)./h(1,1);

% Add identification errors, desired NPM = -30 dB
ie = generate_sie(h,-30,'prop');
h_tilde = h + ie;

%% Load room impulse responses
% load ../Data/ht_3_C;
% h = -ht(91:91+L-1,1:M)./ht(91,1);
% clear ht;

%% Compute equalization system using MINT (Li=L-1)
g = lsinvfilt(h_tilde, Li, k);

%% Compute equalized response
er = zeros(L+Li-1,1);
for m = 1:M
    er = er + conv(h(:,m), g(:,m));
end

%% Plot results
figure(1);
plot([[h(:,1) ; zeros(Li-1,1)] er]);
title('Impulse Responses');
xlabel('Time (samples)');
ylabel('Amplitude');
legend('First channel','Equalized channel');