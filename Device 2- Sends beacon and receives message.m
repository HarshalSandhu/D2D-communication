%set up useSDR and saveToFile to start the transfer  process
useSDR=true;
saveToFile=true;

deviceadd = "0005F78A687F";

%set values of different parameters.
ssid = "TEST_BEACON1";
beaconInterval = 100;
band = 5;
chNum = 52;
%create a object using MACMagament function to genrate a MAc layer object
frameBodyConfig = wlanMACManagementConfig( ...
    BeaconInterval=beaconInterval, ...
    SSID=ssid);
dsElementID = 3;
dsInformation = dec2hex(chNum,2);
frameBodyConfig = frameBodyConfig.addIE(dsElementID,dsInformation);
%genrate beacon frame
beaconFrameConfig = wlanMACFrameConfig(FrameType="Beacon", ...
    ManagementConfig=frameBodyConfig);
beaconFrameConfig.Address3 = '0005F78A687F';
beaconFrameConfig.Address2 = deviceadd;
[mpduBits,mpduLength] = wlanMACFrame(beaconFrameConfig,OutputFormat="bits");
fc = wlanChannelFrequency(chNum,band);
%create beacon packet
cfgNonHT = wlanNonHTConfig(PSDULength=mpduLength);
osf = 2;
tbtt = beaconInterval*1024e-6;
txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,... 
    OversamplingFactor=osf,Idletime=tbtt);

Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);

if saveToFile
    bbw = comm.BasebandFileWriter("nonHTBeaconPacket.bb",Rs,fc);
    bbw(txWaveform);
    release(bbw);
end
if useSDR
    
    sdrPlatform = 'Pluto';
    tx = sdrtx(sdrPlatform);
    tx.BasebandSampleRate = Rs;
    
    tx.CenterFrequency = fc;
end
if useSDR
    
    tx.Gain = 0; 
    transmitRepeat(tx,txWaveform);
    pause(15);
    fprintf("<strong>Beacon sent and signal power %d.</strong>\n",(rms((txWaveform))^2));
    release(tx);
    
end

pause(5);
%reciver of rts
%The ReceiveOnSDR field of the rxsim structure determines whether the example receives a waveform off the air or imports a waveform from a MAT file.
rxsim.ReceiveOnSDR = true;
%The valid 20 MHz control channels for an AP are 32, 36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165, 169, 173, and 177.
if rxsim.ReceiveOnSDR
    rxsim.SDRDeviceName = "Pluto";       % SDR name
    rxsim.RadioIdentifier = 'ip:192.168.2.1';      
    rxsim.RadioSampleRate = 20000000;      % Configured for 20e6 Hz as this is beacon transmission BW
    rxsim.RadioGain = 10;
    rxsim.FrequencyBand = 5;
    rxsim.ChannelNumbers = [40, 52, 56, 60];     % Default scans all 5 GHz beacon channels
    rxsim.ReceiveAntenna = 1;       
    rxsim.CaptureTime = milliseconds(100);         

    % Derived Parameters using inbuilt functions from hardware support.
    rxsim.CenterFrequencies = wlanChannelFrequency(rxsim.ChannelNumbers,rxsim.FrequencyBand);
    rxsim.NumSamplesToCapture = seconds(rxsim.CaptureTime)*rxsim.RadioSampleRate;
        
else
    disp("nothing received");
end
osf = rxsim.RadioSampleRate/20e6;

%What to display. Set true.
retrieveVendorInfo = true;
displayAdditionalInfo = true;
displayScope = false;

%Scan 5 GHz Channels
%First we set establish a link with hardware(sdr).
%Create an SDR object by either calling sdrrx or comm.SDRuReceiver. Then, apply the parameters set in the rxsim structure above to the properties of that object.
if rxsim.ReceiveOnSDR
    if rxsim.SDRDeviceName=="Pluto"        %checks if device name matches.
        sdrReceiver = sdrrx( ...
            rxsim.SDRDeviceName, ...
            BasebandSampleRate=rxsim.RadioSampleRate, ...
            GainSource="Manual");
        
            sdrReceiver.RadioID = rxsim.RadioIdentifier;
                
    else
        fprintf("using some other hardware like usrp etc.");
    end
    sdrReceiver.Gain = rxsim.RadioGain;
    sdrReceiver.OutputDataType = "double";
    sdrReceiver.ChannelMapping = rxsim.ReceiveAntenna;
end

% Begin Packet Capture and Processing
% Create a structure (APs) for storing this information for each successfully decoded beacon.
% SSID
% BSSID
% Vendor of AP
% Signal-to-noise ratio (SNR)
% Primary 20 MHz channel
% Current channel center frequency index
% Channel width 
% Frequency band
% Operating mode supported by the AP
% MAC frame configuration
% Waveform in which the beacon exists
% Index value at which the non-HT beacon packet begins in the captured waveform
APs = struct(...
    "SSID",[],"BSSID",[],"Vendor",[],"SNR_dB",[],"Beacon_Channel",[], ...
    "Operating_Channel",[],"Channel_Width_MHz",[],"Band",[],"Mode",[], ...
    "MAC_Config",wlanMACFrameConfig,"Waveform",[],"Offset",[],"Power",[],"rtsqualify",[]);
%Initialize a non-HT config object to use for processing incoming waveforms.
cbw = "CBW20";
cfg = wlanNonHTConfig(ChannelBandwidth=cbw);
ind = wlanFieldIndices(cfg);
indexAP = 1;
%Begin scanning and decoding for specified channels.
for i = 1:length(rxsim.ChannelNumbers)    
    
    fprintf("<strong>Scanning channel %d on band %.1f.</strong>\n",rxsim.ChannelNumbers(i),rxsim.FrequencyBand);
    if rxsim.ReceiveOnSDR
        sdrReceiver.CenterFrequency = rxsim.CenterFrequencies(i);
        captureSig = capture(sdrReceiver,rxsim.NumSamplesToCapture);
        fprintf("<strong>Signal Power %d.</strong>\n",(rms((captureSig))^2));
        sigstrength = rms((captureSig))^2;

        if sigstrength<(1e-6)
            continue;
        end


        capturedData = captureWaveform(sdrReceiver,rxsim.NumSamplesToCapture);
    else
        %capturedData = rx.capturedWaveforms(:,i);
    end
    
    % Display
    if displayScope %#ok<*UNRCH>
        scope = spectrumAnalyzer(ViewType="spectrum-and-spectrogram",SampleRate=rxsim.RadioSampleRate,...
            TimeSpanSource="property",TimeSpan=rxsim.NumSamplesToCapture/rxsim.RadioSampleRate);
        scope(capturedData);
    end    
   
    % Resample 
    if osf ~= 1
        capturedData = resample(capturedData,20e6,rxsim.RadioSampleRate);
    end

    searchOffset = 0;
    while searchOffset<length(capturedData)
        
        % recoverPreamble
        [preambleStatus,res] = recoverPreamble(capturedData,cbw,searchOffset);
        
        if matches(preambleStatus,"No packet detected")
            break;
        end

        % Retrieve synchronized data
        
        syncData = capturedData(res.PacketOffset+1:end)./sqrt(res.LSTFPower);
        syncData = frequencyOffset(syncData,rxsim.RadioSampleRate/osf,-res.CFOEstimate);
        
        % Need only 4 OFDM symbols
        fmtDetect = syncData(ind.LSIG(1):(ind.LSIG(2)+4e-6*rxsim.RadioSampleRate/osf*3));        
        
        [LSIGBits, failcheck] = wlanLSIGRecover(fmtDetect(1:4e-6*rxsim.RadioSampleRate/osf*1), ... 
            res.ChanEstNonHT,res.NoiseEstNonHT,cbw);
    
        if ~failcheck            
            format = wlanFormatDetect(fmtDetect,res.ChanEstNonHT,res.NoiseEstNonHT,cbw);
            if matches(format,"Non-HT")
                
                % Extract MCS from first 3 bits of L-SIG
                rate = double(bit2int(LSIGBits(1:3),3));
                if rate <= 1
                    cfg.MCS = rate + 6;
                else
                    cfg.MCS = mod(rate,6);
                end
                
                % Determine PSDU length from L-SIG.
                cfg.PSDULength = double(bit2int(LSIGBits(6:17),12,0));
                ind.NonHTData = wlanFieldIndices(cfg,"NonHT-Data");
                
                if double(ind.NonHTData(2)-ind.NonHTData(1))> ...
                        length(syncData(ind.NonHTData(1):end))
                    % Exit while loop as full packet not captured. 
                    break;
                end
                
                nonHTData = syncData(ind.NonHTData(1):ind.NonHTData(2));                
                bitsData = wlanNonHTDataRecover(nonHTData,res.ChanEstNonHT, ... 
                    res.NoiseEstNonHT,cfg);
                [cfgMAC, ~, decodeStatus] = wlanMPDUDecode(bitsData,cfg, ... 
                    SuppressWarnings=true);
                
                % Print additional information on all successfully packets
                if ~decodeStatus && displayAdditionalInfo
                   payloadSize = floor(length(bitsData)/8);
                   [modulation,coderate] = getRateInfo(cfg.MCS);

                   fprintf("Payload Size: %d | Modulation: %s | Code Rate: %s \n",payloadSize,modulation,coderate);
                   fprintf("Type: %s | Sub-Type: %s",cfgMAC.getType,cfgMAC.getSubtype);
                
                end

                % Extract information about channel from the beacon.
                if ~decodeStatus && matches(cfgMAC.FrameType,"RTS")
                    % Populate the table with information about the beacon.
                    if isempty(cfgMAC.ManagementConfig.SSID)
                        APs(indexAP).SSID = "Hidden";
                    else
                        APs(indexAP).SSID = string(cfgMAC.ManagementConfig.SSID);
                    end

                    fprintf("<strong>%s beacon detected on channel %d in band %.1f.</strong>\n",APs(indexAP).SSID,rxsim.ChannelNumbers(i),rxsim.FrequencyBand);
                    
                    APs(indexAP).BSSID = string(cfgMAC.Address2);
                    recevaddinrts = string(cfgMAC.Address1);
                    if strcmp(recevaddinrts,deviceadd)
                        APs(indexAP).rtsqualify = 1;
                    else
                        APs(indexAP).rtsqualify = 0;
                    end

                    if retrieveVendorInfo 
                        APs(indexAP).Vendor = determineVendor(cfgMAC.Address2);
                    else
                        APs(indexAP).Vendor = "Skipped"; 
                    end
                    [APs(indexAP).Mode, APs(indexAP).Channel_Width_MHz, operatingChannel] = ...
                        determineMode(cfgMAC.ManagementConfig.InformationElements);
                    
                    if isempty(operatingChannel)
                        % Default to scanning channel if operating channel
                        % cannot be determined.  
                        operatingChannel = rxsim.ChannelNumbers(i);
                    end
                    
                    APs(indexAP).Beacon_Channel = rxsim.ChannelNumbers(i);
                    APs(indexAP).Operating_Channel = operatingChannel;
                    APs(indexAP).SNR_dB = res.LLTFSNR;
                    APs(indexAP).MAC_Config = cfgMAC;
                    APs(indexAP).Offset = res.PacketOffset;
                    APs(indexAP).Waveform = capturedData;
                    APs(indexAP).Power = sigstrength;
                    
                    
                    %Sending cts signal to the ones which qualified rts
                    %In CTS there is only one address that is receivers address.

                    

                    
                    if APs(indexAP).rtsqualify~=1
                        fprintf(" not sending cts %d",2);
                        continue;
                    else
                        fprintf("sending cts %d",1);
                        % Configure frame parameters (optional)
                        rtsCfg = wlanMACFrameConfig('FrameType', 'CTS');
                        rtsCfg.Duration = 1000; % Example duration (in microseconds)
                            %rtsCfg.ManagementConfig.SSID = 'Device1';

                            % transmitterAddress = deviceadd;
                            % receiverAddress = APs(i).BSSID;
                            % tAddress3 = transmitterAddress;

                        rtsCfg.Address1 = APs(indexAP).BSSID;
        

                            % rtsFrame = wlanMACFrame(rtsCfg);
                            % disp(rtsFrame);

                        [mpduBits,mpduLength] = wlanMACFrame(rtsCfg,OutputFormat="bits");
                            % disp(mpduLength);
                            % disp(mpduBits);

                            %Additional configuration (optional)
                            ... (code for setting optional RTS frame fields like Frame Control flags) ...

                            % % Configure transmission parameters (channel bandwidth, etc.) based on network
                            % cfg = wlanPDUConfig('ShortPreamble', 'NonHT'); % Adjust as needed
                            % 
                            % % Convert frame to signal samples
                            % signal = wlanPDUtoSignal(rtsFrame, cfg);


                        cfgNonHT = wlanNonHTConfig(PSDULength=mpduLength);

                        osf = 1;
                        txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,OversamplingFactor=osf,IdleTime=100*1024e-6);

                        Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);
                        fc = wlanChannelFrequency(52,5);

                        sdrPlatform = 'Pluto';
                        tx = sdrtx(sdrPlatform);
                        tx.BasebandSampleRate = Rs;
                        tx.CenterFrequency = fc;
                        tx.Gain = 0;
                        transmitRepeat(tx,txWaveform);
                        pause(10);
                        release(tx);


                        fprintf("<strong>Signal Sent %d.<strong>\n",1);

                        % Foloowing this we will receive signal for some
                        % next seconds and this signal will contain some
                        % message signal and afer receiving this message
                        % signal, we will send acknowledgement.
                        chno = [52,100];
                        if rxsim.ReceiveOnSDR
                            rxsim.SDRDeviceName = "Pluto";       % SDR name
                            rxsim.RadioIdentifier = 'ip:192.168.2.1';      
                            rxsim.RadioSampleRate = 20000000;      % Configured for 20e6 Hz as this is beacon transmission BW
                            rxsim.RadioGain = 10;
                            rxsim.FrequencyBand = 5;
                            rxsim.ChannelNumbers = [44,52,56,100];     % Default scans all 5 GHz beacon channels
                            rxsim.ReceiveAntenna = 1;       
                            rxsim.CaptureTime = milliseconds(100);         

    % Derived Parameters using inbuilt functions from hardware support.
                            rxsim.CenterFrequencies = wlanChannelFrequency(rxsim.ChannelNumbers,rxsim.FrequencyBand);
                            rxsim.NumSamplesToCapture = seconds(rxsim.CaptureTime)*rxsim.RadioSampleRate;
        
                        else
                            disp("nothing received");
                        end
                        osf = rxsim.RadioSampleRate/20e6;
                
                
                        retrieveVendorInfo = true;
                        displayAdditionalInfo = true;
                        displayScope = false;
                
%Scan 5                 GHz Channels
%First w                e set establish a link with hardware(sdr).
%Create                 an SDR object by either calling sdrrx or comm.SDRuReceiver. Then, apply the parameters set in the rxsim structure above to the properties of that object.
                        if rxsim.ReceiveOnSDR
                            if rxsim.SDRDeviceName=="Pluto"        %checks if device name matches.
                                sdrReceiver = sdrrx( ...
                                rxsim.SDRDeviceName, ...
                                BasebandSampleRate=rxsim.RadioSampleRate, ...
                                GainSource="Manual");
                        
                                sdrReceiver.RadioID = rxsim.RadioIdentifier;
                        
                            else
                                fprintf("using some other hardware like usrp etc.");
                            end
                            sdrReceiver.Gain = rxsim.RadioGain;
                            sdrReceiver.OutputDataType = "double";
                            sdrReceiver.ChannelMapping = rxsim.ReceiveAntenna;
                        end
                
                
                        BPs = struct(...
                            "SSID",[],"BSSID",[],"Vendor",[],"SNR_dB",[],"BChannel",[], ...
                            "Operating_Channel",[],"Channel_Width_MHz",[],"Band",[],"Mode",[], ...
                            "MAC_Config",wlanMACFrameConfig,"Waveform",[],"Offset",[],"Power",[]);
%Initial                ize a non-HT config object to use for processing incoming waveforms.
                        cbw = "CBW20";
                        cfg = wlanNonHTConfig(ChannelBandwidth=cbw);
                        ind = wlanFieldIndices(cfg);
                        indexA = 1;
%Begin s                canning and decoding for specified channels.
                        for j = 1:length(rxsim.ChannelNumbers)    
                    
                            fprintf("<strong>Scanning channel %d on band %.1f.</strong>\n",rxsim.ChannelNumbers(j),rxsim.FrequencyBand);
                            if rxsim.ReceiveOnSDR
                                sdrReceiver.CenterFrequency = rxsim.CenterFrequencies(j);
                                captureSig = capture(sdrReceiver,rxsim.NumSamplesToCapture);
                                fprintf("<strong>Signal Power %d.</strong>\n",(rms((captureSig))^2));
                                sigstrength = rms((captureSig))^2;
                
                        
                
                
                                capturedData = captureWaveform(sdrReceiver,rxsim.NumSamplesToCapture);
                            else
                        %capturedData = rx.capturedWaveforms(:,i);
                            end
                    
    % Di                splay
                            if displayScope %#ok<*UNRCH>
                                scope = spectrumAnalyzer(ViewType="spectrum-and-spectrogram",SampleRate=rxsim.RadioSampleRate,...
                                    TimeSpanSource="property",TimeSpan=rxsim.NumSamplesToCapture/rxsim.RadioSampleRate);
                                scope(capturedData);
                            end    
                
    % Re                sample 
                            if osf ~= 1
                                capturedData = resample(capturedData,20e6,rxsim.RadioSampleRate);
                            end
                
                            searchOffset = 0;
                            while searchOffset<length(capturedData)
                        
                        % recoverPreamble
                                [preambleStatus,res] = recoverPreamble(capturedData,cbw,searchOffset);
                        
                                if matches(preambleStatus,"No packet detected")
                                    break;
                                end
                
                        % Retrieve synchronized data
                        
                                syncData = capturedData(res.PacketOffset+1:end)./sqrt(res.LSTFPower);
                                syncData = frequencyOffset(syncData,rxsim.RadioSampleRate/osf,-res.CFOEstimate);
                        
                        % Need only 4 OFDM symbols
                                fmtDetect = syncData(ind.LSIG(1):(ind.LSIG(2)+4e-6*rxsim.RadioSampleRate/osf*3));        
                        
                                [LSIGBits, failcheck] = wlanLSIGRecover(fmtDetect(1:4e-6*rxsim.RadioSampleRate/osf*1), ... 
                                    res.ChanEstNonHT,res.NoiseEstNonHT,cbw);
                    
                                if ~failcheck            
                                    format = wlanFormatDetect(fmtDetect,res.ChanEstNonHT,res.NoiseEstNonHT,cbw);
                                    if matches(format,"Non-HT")
                        
                                % Extract MCS from first 3 bits of L-SIG
                                        rate = double(bit2int(LSIGBits(1:3),3));
                                        if rate <= 1
                                            cfg.MCS = rate + 6;
                                        else
                                            cfg.MCS = mod(rate,6);
                                        end
                        
                                % Determine PSDU length from L-SIG.
                                        cfg.PSDULength = double(bit2int(LSIGBits(6:17),12,0));
                                        ind.NonHTData = wlanFieldIndices(cfg,"NonHT-Data");
                        
                                        if double(ind.NonHTData(2)-ind.NonHTData(1))> ...
                                                length(syncData(ind.NonHTData(1):end))
                                    % Exit while loop as full packet not captured. 
                                            break;
                                        end
                        
                                        nonHTData = syncData(ind.NonHTData(1):ind.NonHTData(2));                
                                        bitsData = wlanNonHTDataRecover(nonHTData,res.ChanEstNonHT, ... 
                                            res.NoiseEstNonHT,cfg);
                                        [cfgMAC, ~, decodeStatus] = wlanMPDUDecode(bitsData,cfg, ... 
                                            SuppressWarnings=true);
                        
                                % Print additional information on all successfully packets
                                        if ~decodeStatus && displayAdditionalInfo
                                            payloadSize = floor(length(bitsData)/8);
                                            [modulation,coderate] = getRateInfo(cfg.MCS);
                
                                            fprintf("Payload Size: %d | Modulation: %s | Code Rate: %s \n",payloadSize,modulation,coderate);
                                            fprintf("Type: %s | Sub-Type: %s",cfgMAC.getType,cfgMAC.getSubtype);
                        
                                        end
                
                                % Extract information about channel from the beacon.
                                        if ~decodeStatus && matches(cfgMAC.FrameType,"Data")
                                    % Populate the table with information about the beacon.
                                            if isempty(cfgMAC.ManagementConfig.SSID)
                                                BPs(indexA).SSID = "Hidden";
                                            else
                                                BPs(indexA).SSID = string(cfgMAC.ManagementConfig.SSID);
                                            end
                
                                            fprintf("<strong>%s data detected on channel %d in band %.1f.</strong>\n",BPs(indexA).SSID,rxsim.ChannelNumbers(i),rxsim.FrequencyBand);
                        
                                            BPs(indexAP).BSSID = string(cfgMAC.Address2);
                                            if retrieveVendorInfo 
                                                BPs(indexA).Vendor = determineVendor(cfgMAC.Address2);
                                            else
                                                BPs(indexA).Vendor = "Skipped"; 
                                            end
                                            [BPs(indexA).Mode, BPs(indexA).Channel_Width_MHz, operatingChannel] = ...
                                                determineMode(cfgMAC.ManagementConfig.InformationElements);
                        
                                            if isempty(operatingChannel)
                                        % Default to scanning channel if operating channel
                                        % cannot be determined.  
                                                operatingChannel = rxsim.ChannelNumbers(j);
                                            end
                        
                                            BPs(indexA).BChannel = rxsim.ChannelNumbers(j);
                                            BPs(indexA).Operating_Channel = operatingChannel;
                                            BPs(indexA).SNR_dB = res.LLTFSNR;
                                            BPs(indexA).MAC_Config = cfgMAC;
                                            BPs(indexA).Offset = res.PacketOffset;
                                            BPs(indexA).Waveform = capturedData;
                                            BPs(indexA).Power = sigstrength;

                                            [rxCfgMPDU,payload,status] = wlanMPDUDecode(bitsData,wlanNonHTConfig);
                                            tble=payload{1,1};
                                            %disp(tbl);
                                            sttt = "";
                                            for k=1:1:length(tble)
                                                sttt = strcat(sttt,string(tble(k,1)));
                                                sttt = strcat(sttt,string(tble(k,2)));
                    
                                            end
                                            disp(sttt);
                
                                            %hex_pairs = reshape(stt, 2, [])';
                
                                            % Convert each hex pair to decimal (base 16)
                                            decimal_values = hex2dec(tble);
                
                                            % Convert decimal values to characters using ASCII table
                                            ascii_string1 = char(decimal_values);
                                            ascii_string1 = transpose(ascii_string1);
                
                                            disp(ascii_string1);
                
    


                
                
                                            % we check for the condition that the receivers
                                            % signal address and address of the device
                                            % matches and if it matches,we configure and
                                            % transmit the message signal to the present
                                            % device.
                
                                            %Data type frame consists of all the three addresses-address1 for
                
%destina                tion,address2 for source and address3 for AP or same as source in
%our cas                e.
                        
                                            % if ~strcmp(BPs(indexAP).BSSID,deviceAddress)
                                            %     continue
                                            % else
                                            % 
                                            % 
                                            %     % Replace placeholders with your actual values
                                            %     transmitterAddress = deviceAddress; % Your device's MAC address
                                            %     receiverAddress = string(APs(indexAP).BSSID); % Target receiver's MAC address
                                            % 
                                            %     % Configure frame parameters (optional)
                                            %     rtsCfg = wlanMACFrameConfig('FrameType', 'Data');
                                            % 
                                            %     rtsCfg.Duration = 1000; % Example duration (in microseconds)
                                            % 
                                            %     % Generate the message frame
                                            % 
                                            % 
                                            %     % Set transmitter and receiver addresses
                                            %     rtsCfg.Address1 = receiverAddress;
                                            %     rtsCfg.Address2 = transmitterAddress;
                                            %     rtsCfg.Address3 = transmitterAddress;
                                            %     %disp(rtsCfg);
                                            % 
                                            %     % rtsFrame = wlanMACFrame(rtsCfg);
                                            %     % disp(rtsFrame);
                                            % 
                                            %     %data octet represents the octet representation of the message signal we
                                            %     %are willing to send. This can be set manually in form of octets or we can
                                            %     %write a separate function to convert some string to octets form.
                                            %     dataoctet = "68692120546869732069732064657669636520312E";
                                            % 
                                            %     [mpduBits,mpduLength] = wlanMACFrame(dataoctet,rtsCfg,OutputFormat="bits");
                                            %     %disp(mpduLength);
                                            %     strmpduBits = mpduBits;
                                            %     revmpduBits = (strmpduBits);
                                            %     st = "";
                                            %     for k=1:1:392
                                            %         st = strcat(st,string(strmpduBits(k)));
                                            %     end
                                            %     %disp(strlength(st));
                                            %     %disp(st);
                                            %     %st = reverse(st);
                                            %     %disp(st);
                                            % 
                                            %     [rxCfgMPDU,payload,status] = wlanMPDUDecode(mpduBits,wlanNonHTConfig);
                                            %     tbl=payload{1,1};
                                            %     %disp(tbl);
                                            %     stt = "";
                                            %     for k=1:1:length(tbl)
                                            %         stt = strcat(stt,string(tbl(k,1)));
                                            %         stt = strcat(stt,string(tbl(k,2)));
                                            % 
                                            %     end
                                            %     disp(stt);
                                            % 
                                            %     %hex_pairs = reshape(stt, 2, [])';
                                            % 
                                            %     % Convert each hex pair to decimal (base 16)
                                            %     decimal_values = hex2dec(tbl);
                                            % 
                                            %     % Convert decimal values to characters using ASCII table
                                            %     ascii_string = char(decimal_values);
                                            %     ascii_string = transpose(ascii_string);
                                            % 
                                            %     disp(ascii_string);
                                            % 
                                            % 
                                            %     % sst = "000000000000101000001110111101110111000110111001";
                                            %     % disp(strlength(sst));
                                            % 
                                            %     %disp(revmpduBits(81:128));
                                            % 
                                            %     %Additional configuration (optional)
                                            %     ... (code for setting optional RTS frame fields like Frame Control flags) ...
                                            % 
                                            %     % % Configure transmission parameters (channel bandwidth, etc.) based on network
                                            %     % cfg = wlanPDUConfig('ShortPreamble', 'NonHT'); % Adjust as needed
                                            %     % 
                                            %     % % Convert frame to signal samples
                                            %     % signal = wlanPDUtoSignal(rtsFrame, cfg);
                                            % 
                                            % 
                                            %     cfgNonHT = wlanNonHTConfig(PSDULength=mpduLength);
                                            % 
                                            %     osf = 2;
                                            %     txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,OversamplingFactor=osf,IdleTime=100*1024e-6);
                                            % 
                                            %     %mentioning the fc or central frequency based upon the channel and band the
                                            %     %receiving device.
                                            %     if APs(j).Beacon_Channel==52
                                            % 
                                            %         fc = wlanChannelFrequency(56,5);
                                            %     else
                                            %         fc = wlanChannelFrequency(104,5);
                                            %     end
                                            % 
                                            % 
                                            %     Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);
                                            % 
                                            %     sdrPlatform = 'Pluto';
                                            %     tx = sdrtx(sdrPlatform);
                                            %     tx.BasebandSampleRate = Rs;
                                            %     tx.CenterFrequency = fc;
                                            %     tx.Gain = 0;
                                            %     transmitRepeat(tx,txWaveform);
                                            % 
                                            %     pause(20);
                                            %     release(tx);
                                            %     fprintf("<strong> Message Signal Sent %s.</strong>\n",string(APs(indexAP).BSSID));
                                            % end
                
                        
                
                
                
                                            %sent the message signal
                                            indexA = indexA + 1;
                                        end
                                % Shift packet search offset for next iteration of while loop.
                                        searchOffset = res.PacketOffset + double(ind.NonHTData(2));
                                    else
                                % Packet is NOT non-HT; shift packet search offset by 10 OFDM symbols (minimum
                                % packet length of non-HT) for next iteration of while loop.
                                        searchOffset = res.PacketOffset + 4e-6*rxsim.RadioSampleRate/osf*10;
                                    end
                                else
                            % L-SIG recovery failed; shift packet search offset by 10 OFDM symbols (minimum
                            % packet length of non-HT) for next iteration of while loop.
                                    searchOffset = res.PacketOffset + 4e-6*rxsim.RadioSampleRate/osf*10;
                                end
                            end
                        end




                        



                   end
                   indexAP = indexAP + 1; 



                end
                % Shift packet search offset for next iteration of while loop.
                searchOffset = res.PacketOffset + double(ind.NonHTData(2));
            else
                % Packet is NOT non-HT; shift packet search offset by 10 OFDM symbols (minimum
                % packet length of non-HT) for next iteration of while loop.
                searchOffset = res.PacketOffset + 4e-6*rxsim.RadioSampleRate/osf*10;
            end
        else
            % L-SIG recovery failed; shift packet search offset by 10 OFDM symbols (minimum
            % packet length of non-HT) for next iteration of while loop.
            searchOffset = res.PacketOffset + 4e-6*rxsim.RadioSampleRate/osf*10;
        end

    end
end
%Convert the APs structure to a table and display the information specified in step 6 by using the local function generateBeaconTable.
detectedRTSInfo = generateRTSTable(APs,rxsim.FrequencyBand,retrieveVendorInfo);
if rxsim.ReceiveOnSDR
    release(sdrReceiver);
end






%These functions assist in processing the incoming beacons.
function waveform = captureWaveform(sdrReceiver,numSamplesToCapture)
% CAPTUREWAVEFORM returns a column vector of complex values given an
% SDRRECEIVER object and a scalar NUMSAMPLESTOCAPTURE value.
    % For a comm.SDRuReceiver object, use the burst capture technique to
    % acquire the waveform
    if isa(sdrReceiver,'comm.SDRuReceiver')
        waveform = complex(zeros(numSamplesToCapture,1));
        samplesPerFrame = sdrReceiver.SamplesPerFrame;rate
        for i = 1:sdrReceiver.NumFramesInBurst
            waveform(samplesPerFrame*(i-1)+(1:samplesPerFrame)) = sdrReceiver();
        end
    else
        waveform = capture(sdrReceiver,numSamplesToCapture);
    end
end

function [modulation,coderate] = getRateInfo(mcs)
% GETRATEINFO returns the modulation scheme as a character array and the
% code rate of a packet given a scalar integer representing the modulation
% coding scheme
switch mcs
    case 0 % BPSK
        modulation = 'BPSK';
        coderate = '1/2';
    case 1 % BPSK
        modulation = 'BPSK';
        coderate = '3/4';
    case 2 % QPSK
        modulation = 'QPSK';
        coderate = '1/2';
    case 3 % QPSK
        modulation = 'QPSK';
        coderate = '3/4';
    case 4 % 16QAM
        modulation = '16QAM';
        coderate = '1/2';
    case 5 % 16QAM
        modulation = '16QAM';
        coderate = '3/4';
    case 6 % 64QAM
        modulation = '64QAM';
        coderate = '2/3';
    otherwise % 64QAM
        modulation = '64QAM';
        coderate = '3/4';
end
end

function vendor = determineVendor(mac)
% DETERMINEVENDOR returns the vendor name of the AP by extracting the
% organizationally unique identifier (OUI) from the specified MAC address.

persistent ouis

vendor = strings(0);
try
    if isempty(ouis)
        if ~exist("oui.csv","file")
            disp("Downloading oui.csv from IEEE Registration Authority...")
            options = weboptions("Timeout",10);
            websave("oui.csv","http://standards-oui.ieee.org/oui/oui.csv",options);

        end
        ouis = readtable("oui.csv",VariableNamingRule="preserve");
    end

    % Extract OUI from MAC Address.
    oui = mac(1:6);

    % Extract vendors name based on OUI.
    vendor = string(cell2mat(ouis.("Organization Name")(matches(ouis.Assignment,oui))));

catch ME
    % Rethrow caught error as warning.
    warning(ME.message+"\nTo skip the determineVendor function call, set retrieveVendorInfo to false.",[]);
end

if isempty(vendor)
    vendor = "Unknown";
end

end

function [mode,bw,operatingChannel] = determineMode(informationElements)
% DETERMINEMODE determines the 802.11 standard that the AP uses. 
% The function checks for the presence of HT, VHT, and HE capability
% elements and determines the 802.11 standard that the AP uses. The element
% IDs are defined in IEEE Std 802.11-2020 and IEEE Std 802.11ax-2021.


elementIDs = cell2mat(informationElements(:,1));
IDs = elementIDs(:,1);

if any(IDs==255)
    if any(elementIDs(IDs==255,2)==35)
        % HE Packet Format
        mode = "802.11ax";
    else
        mode = "Unknown";
    end
    vhtElement = informationElements{IDs==192,2};
    htElement = informationElements{IDs==61,2};
    [bw,operatingChannel] = determineChannelWidth(htElement,vhtElement);
elseif any(IDs==191)
    % VHT Packet Format
    mode = "802.11ac";
    vhtElement = informationElements{IDs==192,2};
    htElement = informationElements{IDs==61,2};
    [bw,operatingChannel] = determineChannelWidth(htElement,vhtElement);
elseif any(IDs==45)
    % HT Packet Format
    mode = "802.11n";
    htElement = informationElements{IDs==61,2};
    [bw,operatingChannel] = determineChannelWidth(htElement);
else
    % Non-HT Packet Format
    % Exclude b as only DSSS is supported
    mode ="802.11a/g/j/p";
    bw = "Unknown";
    operatingChannel = [];
end

end

function [bw,operatingChannel] = determineChannelWidth(htElement,varargin)
% DETERMINECHANNELWIDTH returns the bandwidth of the channel from the
% beacons operation information elements as defined in IEEE Std 802.11-2020
% Table 11-23.

msbFirst = false;

% Convert to bits to get STA channel width value in 3rd bit.
htOperationInfoBits = int2bit(htElement(2),5*8,msbFirst);
operatingChannel = 0;

if nargin == 2
    vhtElement = varargin{1};

    % VHT Operation Channel Width Field
    CW = vhtElement(1);
    % Channel Center Frequency Segment 0
    CCFS0 = vhtElement(2);
    % Channel Center Frequency Segment 1
    CCFS1 = vhtElement(3);

    if htOperationInfoBits(3) == 0
        bw = "20";
        operatingChannel = CCFS0;
    elseif CW == 0
        % HT Operation Channel Width Field is 1
        bw = "40";
        operatingChannel = CCFS0;
    elseif CCFS1 == 0
        % HT Operation Channel Width Field is 1 and
        % VHT Operation Channel Width Field is 1
        bw = "80";
        operatingChannel = CCFS0;
    elseif abs(CCFS1 - CCFS0) == 8
        % HT Operation Channel Width Field is 1 and
        % VHT Operation Channel Width Field is 1 and
        % CCFS1 is greater than 0
        bw = "160";
        operatingChannel = CCFS1;
    else
        % HT Operation Channel Width Field is 1 and
        % VHT Operation Channel Width Field is 1 and
        % CCFS1 is greater than 0 and
        % |CCFS1 - CCFS0| is greater than 16
        bw = "80+80";
    end
end

if operatingChannel == 0
    if htOperationInfoBits(3) == 1
        bw = "40";
        secondaryChannelOffset = bit2int(htOperationInfoBits(1:2),2,false);
        if secondaryChannelOffset == 1
            % Secondary Channel is above the primary channel.
            operatingChannel = htElement(1) + 2;
        elseif secondaryChannelOffset == 3
            % Secondary Channel is below the primary channel.
            operatingChannel = htElement(1) - 2;
        else
            warning("Could not determine operating channel.")
        end

    else
        bw = "20";
        operatingChannel = htElement(1);
    end
end

end

function tbl = generateRTSTable(APs,band,retrieveVendorInfo)
% GENERATEBEACONTABLE converts the access point structure to a table and
% cleans up the variable names.

tbl = struct2table(APs,"AsArray",true);
tbl.Band = repmat(band,length(tbl.SSID),1);
tbl = renamevars(tbl,["SNR_dB","Beacon_Channel","Operating_Channel","Channel_Width_MHz","Power","rtsqualify"], ...
    ["SNR (dB)","Primary 20 MHz Channel","Current Channel Center Frequency Index", ...
    "Channel Width (MHz)","Power","rtsqualify"]);
if retrieveVendorInfo
    tbl = tbl(:,1:14);
else
    tbl = tbl(:,[1:2,4:14]);
end
fprintf("\n");

end