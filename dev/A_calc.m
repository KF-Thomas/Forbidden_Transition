%A value calculator

%constants
clear const
hebec_constants
kb = const.kb;
mhe = const.mhe;
h = const.h;
c = const.c;

%trap freq
wx=2*pi*40;
wy=2*pi*427.5;
wz=2*pi*428;
v0=700939267*1e6; %MHz

%% import heating data
load('Y:\TDC_user\ProgramFiles\my_read_tdc_gui_v1.0.1\dld_output\20190716_forbidden427_overnight_heating_method\out\20190724T095142\data_results.mat')
Ti = out_data.data.signal.msr.val(:,2);
Tf = out_data.data.signal.msr.val(:,3);
T=(Ti+Tf)./2;
dT_dt = out_data.data.cal.calibrated_signal.val(:);%out_data.data.signal.msr.val(:,1);
f = out_data.data.signal.msr.freq;
% P = out_data.data.ai_log.pd.mean(~out_data.data.cal.cal_mask).*3.2616e-2; %power in jules
% P(isnan(P)) = 3.2616e-2;
P = ones(1102,1).*3.2616e-2;
%% proportionality constant
alpha = 3*8*pi*h*kb*v0^2/c^2;

%% Energy per photon

energy_per_photon;

%% Integral 1

first_integral;

%% Integral 2

second_integral;

%% Print out final value
A=alpha/E_p*int_1/int_2;
fprintf('A_{ul} = %s\n',A)
       