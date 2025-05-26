clc; clear; close all;

% =========================================================================
% Library Load
% =========================================================================
addpath("C:\Field_II_ver_3_30_windows")
addpath("~.\functions")

% =========================================================================
% Set Initial Parameters
% =========================================================================
% Transducer setting
% ATL L7-4 probe(Philips)
Param.Tr.pitch  = 0.298e-3;
Param.Tr.width  = 0.25e-3;
Param.Tr.kerf   = Param.Tr.pitch - Param.Tr.width;
Param.Tr.height = 7.5e-3;

Param.Tr.noElement  = 256;
Param.Tr.noChannel  = 64; 
Param.Tr.fBW        = 0.6; % Bandwidth of center Frequency
Param.BF.noScanline = 192;
Param.BF.F_number   = 1.2;

Param.c         = 1540;                     % speed of sound [m/s]
Param.eTx.f0    = 5.208e+06;                % transducer center frequency [Hz]
Param.eTx.fs    = Param.eTx.f0*4;           % sampling frequency [Hz]
Param.Dunit     = Param.c / (Param.eTx.fs); % unit distance [m]
Param.DR        = 50;                       % Dynamic Range [dB]

Param.Tr.focus_lens = [0 0 30]*1e-3;        % Eleational focus [m] : Mechanical focusing
Param.Tx_focus      = [0 0 40]*1e-3;        % Transmit focus [m] : Electrical focusing
Param.Rx_focus      = [0 0 0]*1e-3;         % Receive focus [m] : Electrical focusing
Param.z_focus       = 30e-3;


% =========================================================================
% Field II Parameter Setting
% =========================================================================
field_init(0);
set_sampling(Param.eTx.fs);     % Set the samling frequency the system uses
set_field('c', Param.c);        % Set the Speed of sound [m/s]
set_field('fs', Param.eTx.fs);  % Set the sampling frequency
set_field('use_rectangles', 1); % Use rectangles for apertures

% Set the Array transducer
Param.Tx = xdc_linear_array(Param.Tr.noElement, Param.Tr.width, Param.Tr.height, Param.Tr.kerf, 1, 1, Param.Tr.focus_lens);
Param.Rx = xdc_linear_array(Param.Tr.noElement, Param.Tr.width, Param.Tr.height, Param.Tr.kerf, 1, 1, Param.Tr.focus_lens);

% Set the impulse response
impulse_response = sin(2*pi*Param.eTx.f0*(0:1/Param.eTx.fs:2/Param.eTx.f0));
impulse_response = impulse_response.*hanning(max(size(impulse_response)))';

xdc_impulse(Param.Tx, impulse_response);    % setting the impulse response of an aperture
xdc_baffle(Param.Tx, impulse_response);     % setting the baffle condition for the aperture (baffle : 불필요한 소리나 초음파 반사를 방지하기 위한 구조물)
xdc_impulse(Param.Rx, impulse_response);
xdc_baffle(Param.Rx, impulse_response);
excitation = sin(2*pi*Param.eTx.f0*(0:1/Param.eTx.fs:2/Param.eTx.f0)); % exctitation : 실제 송신하는 펄스 신호
xdc_excitation(Param.Tx, excitation);

Param.info_trans = xdc_get(Param.Tx, 'rect'); % rect 형태의 element transducer data를 가져옴
Param.BF.trans_pos_x = Param.info_trans(24,:); % Position of center x of the physical element

% time-lag because of transducer impulse response and excitation signal
one_way_ir = conv(impulse_response, excitation);        
two_way_ir = conv(one_way_ir, impulse_response); 
Param.lag = length(two_way_ir)/2+1;                 


% =========================================================================
% Generate Phatom(point target)
% =========================================================================
j = 0;
for i = 1:15
    point.position(i,:) = [0 0 10e-3*(i-1)];
    j = j+1;
end


for i = 1:11
    point.position(i+j,:) = [-50e-3+10e-3*(i-1) 0 30e-3];
    j = j+1;
    point.position(i+j,:) = [-50e-3+10e-3*(i-1) 0 60e-3];
    j = j+1;
    point.position(i+j,:) = [-50e-3+10e-3*(i-1) 0 90e-3];
    j = j+1;
end

% Set point amplitudes
point.amplitude = ones(size(point.position, 1),1);

disp(point.position);


% =========================================================================
% Display Setting (S24R35xFZ)
% =========================================================================
Param.disp.Row = 1080;
Param.disp.Col = 1920;
Param.disp.Xctr = Param.disp.Col/2;
Param.disp.Zstr = 30; 
Param.disp.Zstr = 0; 
Param.DR = 60;
Param.pixelDist = 0.1e-3;

Param.lamba = Param.c / (Param.eTx.f0);  % wave length [m]
Param.img.Depth = Param.disp.Row * Param.pixelDist;
Param.img.Sample = ceil(2*Param.img.Depth/Param.Dunit);
Param.img.ROI = [-20e-3 20e-3 0 Param.img.Depth];


% =========================================================================
% Generate RF Data
% =========================================================================
Param.x_pos = Param.info_trans(8,:);  % Lateral position of elements
Param.z_pos = Param.info_trans(10,:);  % Axial position of elements

Param.x_sc = linspace( (Param.x_pos(Param.Tr.noChannel/2)+Param.x_pos(Param.Tr.noChannel/2+1))/2 ,(Param.x_pos(end-Param.Tr.noChannel/2) + Param.x_pos(end-Param.Tr.noChannel/2+1))/2, Param.BF.noScanline);   % Scanline lateral position
Param.z_sc = linspace( (Param.z_pos(Param.Tr.noChannel/2)+Param.z_pos(Param.Tr.noChannel/2+1))/2 ,(Param.z_pos(end-Param.Tr.noChannel/2) + Param.z_pos(end-Param.Tr.noChannel/2+1))/2, Param.BF.noScanline);   % Scanline axial position

for sc_idx = 1 : Param.BF.noScanline
    disp([num2str(sc_idx)]);

    x = Param.x_sc(sc_idx);
    z = Param.z_sc(sc_idx);

    % set the focus for Tx focusing
    xdc_center_focus(Param.Tx, [x 0 0]);     % 각 스캔라인 별 트랜스듀서의 기준 중심점 설정
    xdc_focus(Param.Tx, 0, [x 0 Param.z_focus]);               % 송신 초점 위치 설정 ( 초점잡고 싶은 위치 )

    % set the focus for Rx focusing
    xdc_center_focus(Param.Rx, [x 0 0]);
    xdc_focus(Param.Rx, 0, [0 0 100000]);

    apo_ch = ones(1, Param.Tr.noChannel);
    apo = [zeros(1, sc_idx-1) apo_ch zeros(1, Param.Tr.noElement - sc_idx - Param.Tr.noChannel+1)]; % 활성화된 element(=1)의 물리적 배열..?

    xdc_apodization(Param.Tx, 0, apo);
    xdc_apodization(Param.Rx, 0, apo);

    [Param.RF_data, t_str] = calc_scat_multi(Param.Tx, Param.Rx, point.position, point.amplitude);

    no_zeros = round((t_str - Param.lag/Param.eTx.fs)*Param.eTx.fs);

    preBF{1, sc_idx} =  [zeros(no_zeros, Param.Tr.noElement); Param.RF_data];

    Param.depth(sc_idx) = size(preBF{1, sc_idx} ,1);
    Param.times(sc_idx) = t_str;
end

% Set the image data
Param.MinDepth = min(Param.depth);
Param.RF_data_org = zeros(Param.MinDepth, Param.Tr.noChannel, Param.BF.noScanline);

for i  = 1: Param.BF.noScanline
    Param.RF_data_org(:,:,i) = preBF{1, i}(1:Param.MinDepth,i:Param.Tr.noChannel+i-1);
end


% =========================================================================
% Beamforming & Display Pixel Matching(DSC, DPBF, CDPB)
% =========================================================================
% Conventioanl DSC
Param.IMG_DSC = DAS(Param);

% DPBF (Display Pixel Beamforming)
Param.IMG_DPBF = DPBF(Param);

% CDPB (Compounded Direct Pixel Beamforming)
Param.IMG_CDPB = compounded(Param);


% =========================================================================
% Show Figure
% =========================================================================

figure,
imagesc(Param.IMG_DSC);
colormap gray; colorbar; axis image;
title(['B-mode (DSC) ) ' num2str(Param.DR) 'dB'])

figure,
imagesc(Param.IMG_DPBF);
colormap gray; colorbar; axis image;
title(['B-mode (DPBF) ) ' num2str(Param.DR) 'dB'])

figure,
imagesc(Param.IMG_CDPB);
colormap gray; colorbar; axis image;
title(['B-mode (CDPB) ) ' num2str(Param.DR) 'dB'])
