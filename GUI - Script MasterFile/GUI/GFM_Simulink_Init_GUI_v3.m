%% ============================================================
% GFM SIMULINK GUI INITIALISATION
%
% Shared by:
%   GFM_Controller_B.slx
%   GFM_Controller_C.slx
%
% The GUI writes GUIConfig into the base workspace, then runs this script.
% The script can also be run standalone using the defaults below.
%
% Existing model variables retained:
%   SolidFault, RLFault
%   fault_start, fault_duration, fault_clear, fault_times
%   Pref_AEMO
%   SCR, Rs, Xs, Ls
%   Rf, Xf, Lf
%   LimitEnable, Imax
%
% For custom voltage-reference steps this script also creates:
%   Vref_GUI   (timeseries)
%
% To use custom Vref steps, connect Vref_GUI to the controller voltage
% reference input using a From Workspace block in BOTH Simulink models.
% ============================================================

clearvars -except GUIConfig;
clc;

%% ============================================================
% GUI / STANDALONE SELECTION
% ============================================================

if ~exist('GUIConfig','var')
    GUIConfig.TestSelect = "AEMO324_T4";
    GUIConfig.LimiterEnable = true;
    GUIConfig.Imax = 1.20;

    GUIConfig.Custom.Disturbance = "FAULT";
    GUIConfig.Custom.SCR = 3.0;
    GUIConfig.Custom.PrefInitial = 1.00;
    GUIConfig.Custom.PrefFinal = 0.80;
    GUIConfig.Custom.VrefInitial = 1.00;
    GUIConfig.Custom.VrefFinal = 1.05;
    GUIConfig.Custom.EventTime = 5.00;
    GUIConfig.Custom.FaultDuration = 0.43;
    GUIConfig.Custom.FaultType = "SOLID";
    GUIConfig.Custom.ZfOverZs = 1.00;
    GUIConfig.Custom.FaultXR = 3.0;
end

TestSelect = upper(string(GUIConfig.TestSelect));

ValidTests = ["AEMO324_T1","AEMO324_T4","AEMO324_T16", ...
              "AEMO3211_T168","CUSTOM"];

assert(any(TestSelect == ValidTests), ...
    'GUIConfig.TestSelect is invalid.');

%% ============================================================
% SYSTEM BASE VALUES
% ============================================================

f  = 50;
ws = 2*pi*f;

Sbase = 100e6;
Vbase = 132e3;

Zbase = Vbase^2/Sbase;

omega_nom = ws;

%% ============================================================
% CONTROLLER PARAMETERS
% Matched to validated reduced-order MATLAB model
% ============================================================

% ------------------------------------------------------------
% Mohammed et al. VSG / RPC base quantities
% ------------------------------------------------------------

Moh_Sbase   = 5e6;
Moh_VLL_rms = 690;
Moh_Vbase   = sqrt(2/3)*Moh_VLL_rms;

Moh_Dp  = 1.273e6;
Moh_J   = 4052;
Moh_nq  = 1.5e-5;
Moh_Kiq = 1e-4;

% Controller B in the same per-unit form as the reduced-order model
D1  = Moh_Dp/Moh_Sbase;
J   = Moh_J/Moh_Sbase;
nq  = Moh_nq*Moh_Sbase/Moh_Vbase;
Kiq = Moh_Kiq*Moh_Sbase/Moh_Vbase;

% Keep H1 available for the existing ws/(2*H1) Simulink block.
% This makes ws/(2*H1) exactly equivalent to 1/(J*omega_nom).
H1 = J*omega_nom^2/2;

% ------------------------------------------------------------
% Controller C APC parameters - matched to reduced-order design
% ------------------------------------------------------------

kg_design = 1.8195;
mp = pi;
a  = 0.5;

rootTerm = nthroot(kg_design^2*mp^2/a - 1,3);
beta  = a^2*rootTerm;
gamma = 1/rootTerm;

b = (beta*gamma)/(beta + gamma - a);
c = (beta + gamma - a)/mp;

Dp_C = 1/mp;
ac_C = a/c;

%% ============================================================
% CURRENT LIMITER
% ============================================================

if isfield(GUIConfig,'LimiterEnable')
    LimitEnable = double(logical(GUIConfig.LimiterEnable));
else
    LimitEnable = 0;
end

if isfield(GUIConfig,'Imax')
    Imax = GUIConfig.Imax;
else
    Imax = 1.20;
end

Tolerance = 1e-3;

assert(Imax > 0,'Imax must be positive.');

%% ============================================================
% INITIAL OPERATING POINT
% ============================================================

Pref = 1.0;
Qref = 0.0;
Vref = 1.0;

%% ============================================================
% DEFAULT TEST / FAULT SETTINGS
% ============================================================

SCR = 3;
XR_grid = 14;

SolidFault = 0;
RLFault = 0;

fault_start = 5.00;
fault_duration = 0.43;
fault_clear = fault_start + fault_duration;
fault_times = [fault_start fault_clear];

fault_case = 'No_fault';

XR_fault = 3;
CustomZfOverZs = 1.0;

Tstop = 10;

% Custom metadata for the GUI
CustomDisturbance = "NONE";
CustomFaultType = "NONE";

%% ============================================================
% SELECT TEST
% ============================================================

switch TestSelect

    case "AEMO324_T1"

        AEMO_test = 1;
        SCR = 10;

        SolidFault = 1;
        RLFault = 0;

        fault_case = 'Solid';
        fault_start = 5.00;
        fault_duration = 0.43;
        fault_clear = fault_start + fault_duration;
        fault_times = [fault_start fault_clear];

        Pref = 1.0;
        Vref = 1.0;

        Tstop = 10;

    case "AEMO324_T4"

        AEMO_test = 4;
        SCR = 3;

        SolidFault = 1;
        RLFault = 0;

        fault_case = 'Solid';
        fault_start = 5.00;
        fault_duration = 0.43;
        fault_clear = fault_start + fault_duration;
        fault_times = [fault_start fault_clear];

        Pref = 1.0;
        Vref = 1.0;

        Tstop = 10;

    case "AEMO324_T16"

        AEMO_test = 16;
        SCR = 3;

        SolidFault = 0;
        RLFault = 1;

        fault_case = 'Zf_equals_Zs';
        fault_start = 5.00;
        fault_duration = 0.43;
        fault_clear = fault_start + fault_duration;
        fault_times = [fault_start fault_clear];

        Pref = 1.0;
        Vref = 1.0;

        XR_fault = 3;
        CustomZfOverZs = 1.0;

        Tstop = 10;

    case "AEMO3211_T168"

        AEMO_test = 168;
        SCR = 3;

        SolidFault = 0;
        RLFault = 0;

        fault_case = 'No_fault';

        Pref = 1.0;
        Vref = 1.0;

        Tstop = 35;

    case "CUSTOM"

        AEMO_test = 0;

        C = GUIConfig.Custom;

        CustomDisturbance = upper(string(C.Disturbance));

        assert(C.SCR >= 2 && C.SCR <= 10, ...
            'Custom SCR must be between 2 and 10.');

        SCR = C.SCR;

        Pref = C.PrefInitial;
        Vref = C.VrefInitial;

        fault_start = C.EventTime;
        fault_duration = C.FaultDuration;
        fault_clear = fault_start + fault_duration;
        fault_times = [fault_start fault_clear];

        Tstop = max(10,C.EventTime + 5);

        switch CustomDisturbance

            case "PREF"

                SolidFault = 0;
                RLFault = 0;
                fault_case = 'No_fault';

            case "VREF"

                SolidFault = 0;
                RLFault = 0;
                fault_case = 'No_fault';

            case "FAULT"

                CustomFaultType = upper(string(C.FaultType));

                switch CustomFaultType

                    case "SOLID"

                        SolidFault = 1;
                        RLFault = 0;
                        fault_case = 'Custom_solid';

                    case "IMPEDANCE"

                        SolidFault = 0;
                        RLFault = 1;
                        fault_case = 'Custom_impedance';

                        CustomZfOverZs = C.ZfOverZs;
                        XR_fault = C.FaultXR;

                        assert(CustomZfOverZs > 0, ...
                            'Custom Zf/Zs must be positive.');

                        assert(XR_fault > 0, ...
                            'Custom fault X/R must be positive.');

                    otherwise

                        error('Custom fault type must be SOLID or IMPEDANCE.');

                end

            case "NONE"

                SolidFault = 0;
                RLFault = 0;
                fault_case = 'No_fault';

            otherwise

                error('Custom disturbance must be PREF, VREF, FAULT or NONE.');

        end

end

%% ============================================================
% GRID THEVENIN IMPEDANCE FROM SCR
% ============================================================

Zs_mag = Zbase/SCR;

Rs = Zs_mag/sqrt(1 + XR_grid^2);
Xs = XR_grid*Rs;
Ls = Xs/ws;

% Per-unit total external-grid impedance
Rs_grid_pu = Rs/Zbase;
Xs_grid_pu = Xs/Zbase;

%% ============================================================
% EXTERNAL GRID IMPEDANCE SPLIT
%
% Same finite-grid topology as the reduced-order model:
%   75%% -> transmission line
%   25%% -> grid-side transformer/source impedance
% ============================================================

GridLineFraction   = 0.75;
GridSourceFraction = 0.25;

% Transmission-line portion
Rs_line = GridLineFraction*Rs;
Xs_line = GridLineFraction*Xs;
Ls_line = Xs_line/ws;
Rs_line_pu = Rs_line/Zbase;
Xs_line_pu = Xs_line/Zbase;

% Grid-side transformer portion
Rs_grid_tf = GridSourceFraction*Rs;
Xs_grid_tf = GridSourceFraction*Xs;

Rtf_grid_total_pu = Rs_grid_tf/Zbase;
Xtf_grid_total_pu = Xs_grid_tf/Zbase;

Rtf_grid_pri_pu = Rtf_grid_total_pu/2;
Rtf_grid_sec_pu = Rtf_grid_total_pu/2;
Xtf_grid_pri_pu = Xtf_grid_total_pu/2;
Xtf_grid_sec_pu = Xtf_grid_total_pu/2;

% Source-side transformer (left of PCC)
% Total leakage X = 0.15 pu, matching reduced-order X1.
Rtf_src_pri_pu = 0.001;
Rtf_src_sec_pu = 0.001;
Xtf_src_pri_pu = 0.075;
Xtf_src_sec_pu = 0.075;

Rtf_src_total_pu = Rtf_src_pri_pu + Rtf_src_sec_pu;
Xtf_src_total_pu = Xtf_src_pri_pu + Xtf_src_sec_pu;

%% ============================================================
% FAULT IMPEDANCE
% ============================================================

if RLFault == 1

    if TestSelect == "AEMO324_T16"
        Zf_mag = Zs_mag;
        XR_fault = 3;
    else
        Zf_mag = CustomZfOverZs*Zs_mag;
    end

    Rf = Zf_mag/sqrt(1 + XR_fault^2);
    Xf = XR_fault*Rf;
    Lf = Xf/ws;

else

    % Harmless values for the disconnected RL branch.
    Zf_mag = NaN;
    Rf = 1.0;
    Lf = 1e-3;
    Xf = ws*Lf;

end

%% ============================================================
% ACTIVE-POWER REFERENCE SIGNAL
% ============================================================

if TestSelect == "AEMO3211_T168"

    Pref_time = [0 5 15 25 35]';

    Pref_value = [1.00 0.50 0.05 1.00 1.00]';

elseif TestSelect == "CUSTOM" && CustomDisturbance == "PREF"

    Pref_time = [0 GUIConfig.Custom.EventTime Tstop]';

    Pref_value = [GUIConfig.Custom.PrefInitial ...
                  GUIConfig.Custom.PrefFinal ...
                  GUIConfig.Custom.PrefFinal]';

else

    Pref_time = [0 Tstop]';

    Pref_value = [Pref Pref]';

end

Pref_AEMO = timeseries(Pref_value,Pref_time);
% IMPORTANT: AEMO 3.2.11 and custom Pref commands are step commands,
% not ramps. Force zero-order-hold interpolation on the source data.
Pref_AEMO = setinterpmethod(Pref_AEMO,'zoh');

%% ============================================================
% VOLTAGE-REFERENCE SIGNAL
%
% IMPORTANT:
% Custom VREF requires both Simulink controllers to use Vref_GUI
% through a From Workspace block at the voltage-reference input.
% For all other tests this remains fixed at Vref.
% ============================================================

if TestSelect == "CUSTOM" && CustomDisturbance == "VREF"

    Vref_time = [0 GUIConfig.Custom.EventTime Tstop]';

    Vref_value = [GUIConfig.Custom.VrefInitial ...
                  GUIConfig.Custom.VrefFinal ...
                  GUIConfig.Custom.VrefFinal]';

else

    Vref_time = [0 Tstop]';

    Vref_value = [Vref Vref]';

end

Vref_GUI = timeseries(Vref_value,Vref_time);
Vref_GUI = setinterpmethod(Vref_GUI,'zoh');

%% ============================================================
% MACHINE / GRID DYNAMICS
% Matched to reduced-order MATLAB finite-grid plant
% ============================================================

Pm1 = Pref;

H2 = 12;
D2 = 0.4;
Ki = 0.5;

%% ============================================================
% NETWORK REACTANCE BOOKKEEPING
% ============================================================

% Source-side GFM impedance (left transformer)
X1 = Xtf_src_total_pu;       % 0.15 pu

% SCR-derived external-grid split
XL = Xs_line_pu;             % 75% line portion
X2 = Xtf_grid_total_pu;      % 25% grid-side transformer portion

% Total series reactance retained only as a diagnostic quantity.
Xtot = X1 + XL + X2;

%% ============================================================
% STEADY-STATE INITIAL OPERATING POINT
%
% Same finite-grid initialisation method used by the reduced-order
% MATLAB model.  It targets:
%   P12 = Pref
%   Q12 = Qref
%   Dw1 = Dw2 = 0
% ============================================================

P12_0   = Pref;
Pload_0 = P12_0;

V2PCCmag0  = 1.0;
delta2PCC0 = 0.0;

% For the normal AEMO/custom operating point Qref is zero.  The
% analytical PCC solution below is the same one used by the reduced model.
arg_PCC = 2*P12_0*XL/(V2PCCmag0^2);

assert(abs(arg_PCC) <= 1, ...
    'No valid initial P/Q operating point exists for the selected SCR.');

delta1PCC0 = 0.5*asin(arg_PCC);
V1PCCmag0  = V2PCCmag0*cos(delta1PCC0);

Q12_0 = Qref;
Q21_0 = (V2PCCmag0^2 ...
    - V2PCCmag0*V1PCCmag0*cos(delta2PCC0-delta1PCC0))/XL;

% Internal GFM voltage behind X1
E1_0 = hypot( ...
    P12_0*X1/V1PCCmag0, ...
    V1PCCmag0 + Q12_0*X1/V1PCCmag0 );

delta1_0 = delta1PCC0 + atan2( ...
    P12_0*X1/V1PCCmag0, ...
    V1PCCmag0 + Q12_0*X1/V1PCCmag0 );

% Equivalent-grid internal voltage behind X2
Pm2_0 = -Pload_0;

E2_0 = hypot( ...
    Pm2_0*X2/V2PCCmag0, ...
    V2PCCmag0 + Q21_0*X2/V2PCCmag0 );

delta2_0 = delta2PCC0 + atan2( ...
    Pm2_0*X2/V2PCCmag0, ...
    V2PCCmag0 + Q21_0*X2/V2PCCmag0 );

Dw1_0 = 0;
Dw2_0 = 0;

Dw1_IC = Dw1_0;
delta1_IC = delta1_0;
Dw2_IC = Dw2_0;
delta2_IC = delta2_0;

GridLoadInt_IC = Pload_0/Ki;
RPCInt_IC = E1_0 - Vref;

%% ============================================================
% GUI STATUS STRUCTURE
% ============================================================

GUIStatus.TestSelect = TestSelect;
GUIStatus.SCR = SCR;
GUIStatus.XR_grid = XR_grid;
GUIStatus.Tstop = Tstop;

GUIStatus.SolidFault = SolidFault;
GUIStatus.RLFault = RLFault;

GUIStatus.FaultStart = fault_start;
GUIStatus.FaultDuration = fault_duration;
GUIStatus.FaultClear = fault_clear;

GUIStatus.CustomDisturbance = CustomDisturbance;
GUIStatus.CustomFaultType = CustomFaultType;

GUIStatus.LimitEnable = LimitEnable;
GUIStatus.Imax = Imax;

GUIStatus.Rs = Rs;
GUIStatus.Xs = Xs;
GUIStatus.Ls = Ls;

GUIStatus.Rs_line = Rs_line;
GUIStatus.Xs_line = Xs_line;
GUIStatus.Ls_line = Ls_line;
GUIStatus.X1 = X1;
GUIStatus.X2 = X2;
GUIStatus.H2 = H2;
GUIStatus.D2 = D2;
GUIStatus.Ki = Ki;
GUIStatus.D1 = D1;
GUIStatus.J = J;
GUIStatus.H1 = H1;
GUIStatus.nq = nq;
GUIStatus.Kiq = Kiq;
GUIStatus.Dp_C = Dp_C;
GUIStatus.a = a;
GUIStatus.b = b;
GUIStatus.c = c;

if RLFault == 1
    GUIStatus.Rf = Rf;
    GUIStatus.Xf = Xf;
    GUIStatus.Lf = Lf;
else
    GUIStatus.Rf = NaN;
    GUIStatus.Xf = NaN;
    GUIStatus.Lf = NaN;
end

%% ============================================================
% DISPLAY
% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('GFM SIMULINK GUI INITIALISATION\n');
fprintf('Test                : %s\n',TestSelect);
fprintf('SCR                 : %.3f\n',SCR);
fprintf('Grid X/R            : %.3f\n',XR_grid);
fprintf('Limiter             : %d\n',LimitEnable);
fprintf('Imax                : %.3f pu\n',Imax);
fprintf('Simulation stop     : %.3f s\n',Tstop);
fprintf('Controller B D1     : %.6f\n',D1);
fprintf('Controller B J      : %.9f\n',J);
fprintf('Equivalent H1       : %.6f s\n',H1);
fprintf('Grid H2 / D2 / Ki   : %.3f / %.3f / %.3f\n',H2,D2,Ki);
fprintf('Line / grid X split : %.6f / %.6f pu\n',XL,X2);
fprintf('Initial delta1      : %.3f deg\n',rad2deg(delta1_0));
fprintf('Initial delta2      : %.3f deg\n',rad2deg(delta2_0));

if SolidFault || RLFault
    fprintf('Fault start         : %.3f s\n',fault_start);
    fprintf('Fault duration      : %.3f s\n',fault_duration);
    fprintf('Fault clear         : %.3f s\n',fault_clear);
end

if RLFault
    fprintf('Fault |Zf|          : %.6f ohm\n',Zf_mag);
    fprintf('Fault X/R           : %.3f\n',XR_fault);
end

fprintf('============================================\n\n');
