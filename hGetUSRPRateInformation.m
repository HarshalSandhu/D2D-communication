function [mcr, f] = hGetUSRPRateInformation(platform,sampleRate)
%hGetUSRPRateInformation USRP radio sample rate information
%    [MCR,F] = hGetUSRPRateInformation(PLATFORM,SAMPLERATE) returns the
%    required information for specifying the sample rate for a given USRP radio.
%
%    MCR is a scalar value that specifies the master clock rate for the
%    radio.
%
%    F is a scalar value specifying the interpolation or decimation factor
%    for the radio.
%
%    PLATFORM is a character array or string specifying the USRP radio and must be
%    'N200/N210/USRP2', 'N300', 'N310', 'N320/N321', 'B200', 'B210',
%    'X300', or 'X310'.
%
%    SAMPLERATE is a scalar value that specifies the desired sample rate
%    for the USRP radio.
%
%    Further information on supported master clock rates and
%    interpolation/decimation factors for USRP radios can be found in the
%    the comm.SDRuTransmitter and comm.SDRuReceiver documentation pages.
%
%    See also COMM.SDRUTRANSMITTER, COMM.SDRURECEIVER

% Copyright 2022 The MathWorks, Inc.
switch platform
    case 'N200/N210/USRP2'
        masterClockRate = 100e6;
        factor = [4:128 130:2:256 260:4:512];

    case {'N300', 'N310'}
        masterClockRate = [122.88e6 125e6 153.6e6];
        factor = [1:4 6:2:128 130:2:256 260:4:512 520:8:1024];

    case 'N320/N321'
        masterClockRate = [200e6 245.76e6 250e6];
        factor = [1:4 6:2:128 130:2:256 260:4:512 520:8:1024];

    case {'B200', 'B210'}
        minMasterClockRate = 5e6;
        maxMasterClockRate = 56e6;
        masterClockRate = minMasterClockRate:1e3:maxMasterClockRate;
        factor = [1:128 130:2:256 260:4:512];

    case {'X300', 'X310'}
        masterClockRate = [184.32e6 200e6];
        factor = [1:128 130:2:256 260:4:512];

    otherwise
        masterClockRate = nan;
        factor = nan;
end

possibleSampleRates = masterClockRate'./factor;
% do not consider smaller sample rates, to satisfy Nyquist:
possibleSampleRates(possibleSampleRates<sampleRate) = NaN;

err = abs(possibleSampleRates - sampleRate);
minErr = min(err,[],"all");
if isnan(minErr)
    error("wlan:error","The sample rate %.2g is not realizable using the %s radio.",sampleRate,platform);
end

[idxMCR, idxFactor] = find(err==minErr);
mcr = masterClockRate(idxMCR(1));
f = factor(idxFactor(1));
end