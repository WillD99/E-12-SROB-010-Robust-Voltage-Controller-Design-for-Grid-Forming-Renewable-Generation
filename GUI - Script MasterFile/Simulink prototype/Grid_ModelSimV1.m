%% ============================================================
%  SM-SM / GFM SIMULINK MODEL INITIALISATION
%
%  Supported AEMO tests:
%
%   AEMO_test = 1    -> 3.2.4 Test 1
%                       SCR = 10
%                       Solid 3PHG fault
%
%   AEMO_test = 4    -> 3.2.4 Test 4
%                       SCR = 3
%                       Solid 3PHG fault
%
%   AEMO_test = 16   -> 3.2.4 Test 16
%                       SCR = 3
%                       3PHG fault through Zf = Zs
%
%   AEMO_test = 168  -> 3.2.11 Test 168
%                       SCR = 3
%                       Active-power reference sequence
%                       No fault
%
%  Current limiter:
%
%   LimitEnable = 1  -> Current limiter ON
%   LimitEnable = 0  -> Current limiter OFF
%
% ============================================================

clear;
clc;


%% ============================================================
%  USER SETTINGS
% ============================================================

AEMO_test   = 4;      % Choose: 1, 4, 16, or 168

LimitEnable = 1;      % 1 = Current limiter ON
                      % 0 = Current limiter OFF


%% ============================================================
%  SYSTEM BASE VALUES
% ============================================================

f  = 50;              % System frequency [Hz]
ws = 2*pi*f;          % Synchronous angular frequency [rad/s]

Sbase = 100e6;        % 100 MVA
Vbase = 132e3;        % 132 kV line-line

Zbase = Vbase^2/Sbase;


%% ============================================================
%  CONTROLLER PARAMETERS
%  Matched to validated reduced-order MATLAB model
% ============================================================

% ------------------------------------------------------------
% Mohammed et al. VSG / RPC base quantities
% ------------------------------------------------------------

Moh_Sbase   = 5e6;                    % 5 MVA
Moh_VLL_rms = 690;                    % 690 V line-line RMS
Moh_Vbase   = sqrt(2/3)*Moh_VLL_rms; % Voltage base used in reduced model

% Mohammed et al. VSG parameters in SI units
Moh_Dp  = 1.273e6;                    % W.s/rad
Moh_J   = 4052;                       % W.s^2/rad
Moh_nq  = 1.5e-5;                    % V/Var
Moh_Kiq = 1e-4;                      % V/(Var.s)

% Convert to per-unit form used by the reduced-order MATLAB model
D1  = Moh_Dp/Moh_Sbase;               % 0.2546 pu/(rad/s)
J   = Moh_J/Moh_Sbase;                % 8.104e-4 pu.s^2/rad
nq  = Moh_nq*Moh_Sbase/Moh_Vbase;     % ~0.133124 pu/pu
Kiq = Moh_Kiq*Moh_Sbase/Moh_Vbase;    % ~0.887496 1/s


% ------------------------------------------------------------
% Model C APC parameters
% Matched to reduced-order MATLAB design
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
%  CURRENT LIMITER PARAMETERS
% ============================================================

Imax      = 1.20;     % Maximum inverter current [pu]
Tolerance = 1e-3;     % Limiter-active detection tolerance

% LimitEnable is selected at the top of this script.
%
% LimitEnable = 1 -> limiter enabled
% LimitEnable = 0 -> limiter bypassed


%% ============================================================
%  INITIAL OPERATING POINT
% ============================================================

Pref = 1.0;           % Initial active-power reference [pu]
Qref = 0.0;           % Reactive-power reference [pu]
Vref = 1.0;           % Voltage reference [pu]


%% ============================================================
%  DEFAULT FAULT TIMING
%
%  Used for 3.2.4 Tests 1, 4 and 16.
%  Ignored for Test 168 because both fault branches are disabled.
% ============================================================

fault_start     = 5.00;
fault_duration  = 0.43;
fault_clear     = fault_start + fault_duration;

fault_times = [fault_start fault_clear];


%% ============================================================
%  DEFAULT FAULT ENABLES
%
%  SolidFault = 1 -> Direct 3PHG fault branch enabled
%  RLFault    = 1 -> RL impedance fault branch enabled
%
%  Both = 0 -> No fault
% ============================================================

SolidFault = 0;
RLFault    = 0;


%% ============================================================
%  GRID PARAMETERS
% ============================================================

XR_grid = 14;


%% ============================================================
%  SELECT AEMO TEST
% ============================================================

switch AEMO_test

    case 1

        % ====================================================
        % AEMO 3.2.4 TEST 1
        %
        % SCR = 10
        % X/R = 14
        % P = 1 pu
        % Q = 0 pu
        % Solid 3PHG fault
        % ====================================================

        SCR = 10;

        SolidFault = 1;
        RLFault    = 0;

        fault_case = 'Solid';

        Tstop = 10;


    case 4

        % ====================================================
        % AEMO 3.2.4 TEST 4
        %
        % SCR = 3
        % X/R = 14
        % P = 1 pu
        % Q = 0 pu
        % Solid 3PHG fault
        % ====================================================

        SCR = 3;

        SolidFault = 1;
        RLFault    = 0;

        fault_case = 'Solid';

        Tstop = 10;


    case 16

        % ====================================================
        % AEMO 3.2.4 TEST 16
        %
        % SCR = 3
        % X/R = 14
        % P = 1 pu
        % Q = 0 pu
        % Zf = Zs
        % ====================================================

        SCR = 3;

        SolidFault = 0;
        RLFault    = 1;

        fault_case = 'Zf_equals_Zs';

        Tstop = 10;


    case 168

        % ====================================================
        % AEMO 3.2.11 TEST 168
        %
        % Active-power reference change test
        %
        % SCR = 3
        % X/R = 14
        % Initial P = 1 pu
        % Q = 0 pu
        %
        % No fault
        % ====================================================

        SCR = 3;

        SolidFault = 0;
        RLFault    = 0;

        fault_case = 'No_fault';

        Tstop = 35;


    otherwise

        error('AEMO_test must be 1, 4, 16 or 168');

end


%% ============================================================
%  GRID THEVENIN IMPEDANCE FROM SCR
% ============================================================

% Grid impedance magnitude

Zs_mag = Zbase/SCR;

% Grid resistance

Rs = Zs_mag/sqrt(1 + XR_grid^2);

% Grid reactance

Xs = XR_grid*Rs;

% Grid inductance

Ls = Xs/ws;

% Per-unit external-grid quantities on the 100 MVA / 132 kV base
Rs_grid_pu = Rs/Zbase;
Xs_grid_pu = Xs/Zbase;

%% ============================================================
%  EXTERNAL GRID IMPEDANCE SPLIT
%
%  Match the reduced-order MATLAB finite-grid topology:
%
%      75% of SCR-derived grid impedance -> transmission line
%      25% of SCR-derived grid impedance -> grid-side transformer
%
%  The detailed model retains X/R = 14, so R and X are split
%  using the same fractions.
% ============================================================

GridLineFraction   = 0.75;
GridSourceFraction = 0.25;

% ------------------------------------------------------------
% Transmission-line portion: 75% of external-grid impedance
% ------------------------------------------------------------

Rs_line = GridLineFraction*Rs;
Xs_line = GridLineFraction*Xs;
Ls_line = Xs_line/ws;

Rs_line_pu = Rs_line/Zbase;
Xs_line_pu = Xs_line/Zbase;

% ------------------------------------------------------------
% Grid-side transformer portion: 25% of external-grid impedance
% ------------------------------------------------------------

Rs_grid_tf = GridSourceFraction*Rs;
Xs_grid_tf = GridSourceFraction*Xs;

Rtf_grid_total_pu = Rs_grid_tf/Zbase;
Xtf_grid_total_pu = Xs_grid_tf/Zbase;

% Split the grid-side transformer impedance equally between windings
Rtf_grid_pri_pu = Rtf_grid_total_pu/2;
Rtf_grid_sec_pu = Rtf_grid_total_pu/2;

Xtf_grid_pri_pu = Xtf_grid_total_pu/2;
Xtf_grid_sec_pu = Xtf_grid_total_pu/2;


%% ============================================================
%  SOURCE-SIDE TRANSFORMER PARAMETERS
%
%  These correspond to the left-hand transformer between the
%  controlled GFM source and the PCC.
%
%  Total source-side leakage reactance = 0.15 pu, matching the
%  reduced-order model X1 = Xd1 + XT1 = 0.10 + 0.05 = 0.15 pu.
% ============================================================

Rtf_src_pri_pu = 0.001;
Rtf_src_sec_pu = 0.001;

Xtf_src_pri_pu = 0.075;
Xtf_src_sec_pu = 0.075;

Rtf_src_total_pu = Rtf_src_pri_pu + Rtf_src_sec_pu;
Xtf_src_total_pu = Xtf_src_pri_pu + Xtf_src_sec_pu;


%% ============================================================
%  FAULT IMPEDANCE
%
%  Only physically used when RLFault = 1.
%
%  For the other tests, harmless valid R and L values are
%  assigned so the unused Simscape RLC block remains valid.
% ============================================================

if RLFault == 1

    % --------------------------------------------------------
    % Test 16
    %
    % Fault impedance magnitude equals grid impedance magnitude.
    % Fault X/R = 3
    % --------------------------------------------------------

    XR_fault = 3;

    Zf_mag = Zs_mag;

    Rf = Zf_mag/sqrt(1 + XR_fault^2);

    Xf = XR_fault*Rf;

    Lf = Xf/ws;

else

    % --------------------------------------------------------
    % RL branch disconnected.
    %
    % These values do NOT represent the actual fault.
    % They simply keep the unused RLC block valid.
    % --------------------------------------------------------

    XR_fault = NaN;
    Zf_mag   = NaN;

    Rf = 1.0;
    Lf = 1e-3;
    Xf = ws*Lf;

end


%% ============================================================
%  ACTIVE POWER REFERENCE SIGNAL
% ============================================================

if AEMO_test == 168

    % ========================================================
    % AEMO 3.2.11 TEST 168
    %
    % Active-power reference:
    %
    % t = 0 s      -> 1.00 pu
    % t = 5 s      -> 0.50 pu
    % t = 15 s     -> 0.05 pu
    % t = 25 s     -> 1.00 pu
    %
    % ========================================================

    Pref_time = [ ...
         0
         5
        15
        25
        35 ];

    Pref_value = [ ...
        1.00
        0.50
        0.05
        1.00
        1.00 ];

    Pref_AEMO = timeseries(Pref_value,Pref_time);

else

    % ========================================================
    % 3.2.4 FAULT TESTS
    %
    % Pref remains fixed at 1 pu.
    % ========================================================

    Pref_time = [0 Tstop];

    Pref_value = [Pref Pref];

    Pref_AEMO = timeseries(Pref_value,Pref_time);

end


%% ============================================================
%  MACHINE 1 / GFM DYNAMICS
%  Controller B matched to reduced-order MATLAB model
% ============================================================

omega_nom = ws;              % Nominal angular frequency [rad/s]

% D1 and J are defined above from the Mohammed parameter set.
%
% Keep H1 available for any existing Simulink blocks that still use
% ws/(2*H1). This value is chosen so that:
%
%       1/(J*omega_nom) = omega_nom/(2*H1)
%
% and therefore the H-form and J-form of the VSG equation are equivalent.

H1 = J*omega_nom^2/2;        % ~39.9916 s equivalent inertia constant

% Initial active-power operating point.
%
% For Test 168 the APC reference itself comes from Pref_AEMO.

Pm1 = Pref;


%% ============================================================
%  MACHINE 2 / EQUIVALENT GRID DYNAMICS
%  Matched to reduced-order MATLAB finite-grid plant
% ============================================================

H2 = 12;
D2 = 0.4;

%% ============================================================
%  GRID LOAD CONTROLLER
%  Matched to reduced-order MATLAB model
%
%  Secondary frequency-restoration integral gain
% ============================================================

Ki = 0.5;


%% ============================================================
%  NETWORK REACTANCE BOOKKEEPING
%
%  Source-side impedance:
%      X1 = 0.15 pu from the left-hand transformer.
%
%  External grid:
%      X_line    = 0.75*Xs_grid
%      X_grid_tf = 0.25*Xs_grid
%
%  Therefore the SCR-derived external-grid impedance is not
%  double-counted.
% ============================================================

X1 = Xtf_src_total_pu;       % 0.15 pu

XL = Xs_line_pu;             % 75% external-grid reactance
X2 = Xtf_grid_total_pu;      % 25% external-grid reactance

% Total series reactance from controlled GFM source to equivalent
% grid source, used only as an initial-angle approximation.
Xtot = X1 + XL + X2;


%% ============================================================
%  CURRENT LIMITER SOURCE REACTANCE
%
%  Reactance between the controlled GFM source and the PCC.
%  This now matches both the physical left transformer and the
%  reduced-order model source-side X1 = 0.15 pu.
%
%      Icmd = |Ecmd - Vpcc| / X1
% ============================================================


%% ============================================================
%  STEADY-STATE INITIAL OPERATING POINT
%
%  This replaces the old lumped:
%
%      delta1_0 = asin(P12_0*Xtot/(E1_0*E2_0))
%
%  initialisation.
%
%  The initial operating point is now constructed using the same
%  finite-grid power-flow method as the reduced-order MATLAB model:
%
%      P12 = Pref = 1 pu
%      Q12 = Qref = 0 pu
%      Dw1 = Dw2 = 0
%
%  Network mapping:
%
%      X1 = source-side transformer reactance
%      XL = 75% SCR-derived transmission-line reactance
%      X2 = 25% SCR-derived grid-side transformer reactance
%
% ============================================================

P12_0   = Pref;
Pload_0 = P12_0;

% ------------------------------------------------------------
% Grid-side PCC reference
% ------------------------------------------------------------

V2PCCmag0  = 1.0;
delta2PCC0 = 0.0;

% ------------------------------------------------------------
% PCC operating point for P = Pref and Q = 0
%
% For the lossless reduced-order line:
%
%   P = (V1*V2/XL)*sin(delta1PCC-delta2PCC)
%
% with Q12 = 0, which gives:
%
%   V1 = V2*cos(delta1PCC-delta2PCC)
%
% and therefore:
%
%   sin(2*delta) = 2*P*XL/V2^2
% ------------------------------------------------------------

arg_PCC = 2*P12_0*XL/(V2PCCmag0^2);

if abs(arg_PCC) > 1
    error(['No valid P = %.3f pu, Q = 0 pu initial operating point ' ...
           'exists for XL = %.6f pu.'],P12_0,XL);
end

delta1PCC0 = 0.5*asin(arg_PCC);
V1PCCmag0  = V2PCCmag0*cos(delta1PCC0);

% Initial source-side reactive power target
Q12_0 = Qref;

% Reactive power seen from the grid side of the line
Q21_0 = ...
    (V2PCCmag0^2 ...
    - V2PCCmag0*V1PCCmag0*cos(delta2PCC0-delta1PCC0)) ...
    / XL;


%% ============================================================
%  GFM INTERNAL VOLTAGE AND ANGLE
%
%  Back-calculate the internal GFM source phasor behind X1.
% ============================================================

E1_0 = hypot( ...
    P12_0*X1/V1PCCmag0, ...
    V1PCCmag0 + Q12_0*X1/V1PCCmag0 );

delta1_0 = delta1PCC0 + atan2( ...
    P12_0*X1/V1PCCmag0, ...
    V1PCCmag0 + Q12_0*X1/V1PCCmag0 );


%% ============================================================
%  EQUIVALENT GRID INTERNAL VOLTAGE AND ANGLE
%
%  The equivalent grid absorbs the initial exported power, hence
%  its mechanical/load power is negative in the reduced-order
%  sign convention.
% ============================================================

Pm2_0 = -Pload_0;

E2_0 = hypot( ...
    Pm2_0*X2/V2PCCmag0, ...
    V2PCCmag0 + Q21_0*X2/V2PCCmag0 );

delta2_0 = delta2PCC0 + atan2( ...
    Pm2_0*X2/V2PCCmag0, ...
    V2PCCmag0 + Q21_0*X2/V2PCCmag0 );


%% ============================================================
%  INITIAL SPEED DEVIATIONS
% ============================================================

Dw1_0 = 0;
Dw2_0 = 0;


%% ============================================================
%  INTEGRATOR INITIAL CONDITIONS
% ============================================================

% VSG / inverter speed and angle states
Dw1_IC     = Dw1_0;
delta1_IC  = delta1_0;

% Equivalent-grid speed and angle states
Dw2_IC     = Dw2_0;
delta2_IC  = delta2_0;

% Grid load-controller integrator.
%
% The Simulink implementation has:
%
%     Pload = Ki * integral(Dw2)
%
% therefore the integrator state must begin at Pload_0/Ki.
GridLoadInt_IC = Pload_0/Ki;

% Reactive-power-controller integrator.
%
% At Qerror = 0:
%
%     Ecmd = Vref + RPC integrator output
%
% so initialise it to reproduce the required steady-state
% internal GFM voltage E1_0.
RPCInt_IC = E1_0 - Vref;


%% ============================================================
%  DISPLAY TEST SETTINGS
% ============================================================

fprintf('\n');
fprintf('============================================\n');

if AEMO_test == 168

    fprintf('AEMO 3.2.11 TEST 168\n');

else

    fprintf('AEMO 3.2.4 TEST %d\n',AEMO_test);

end

fprintf('============================================\n');

fprintf('SCR                 = %.1f\n',SCR);
fprintf('Grid X/R            = %.1f\n',XR_grid);


fprintf('\nCurrent limiter:\n');

if LimitEnable == 1

    fprintf('Limiter             = ENABLED\n');

else

    fprintf('Limiter             = DISABLED\n');

end

fprintf('Imax                = %.2f pu\n',Imax);
fprintf('X1                  = %.3f pu\n',X1);
fprintf('Tolerance           = %.4f\n',Tolerance);


fprintf('\nGrid impedance:\n');

fprintf('|Zs| total          = %.4f ohm\n',Zs_mag);
fprintf('Rs total            = %.4f ohm\n',Rs);
fprintf('Xs total            = %.4f ohm\n',Xs);
fprintf('Ls total            = %.6f H\n',Ls);
fprintf('Xs total            = %.6f pu\n',Xs_grid_pu);

fprintf('\n75/25 external-grid split:\n');
fprintf('Line fraction       = %.2f\n',GridLineFraction);
fprintf('Line Rs             = %.4f ohm\n',Rs_line);
fprintf('Line Xs             = %.4f ohm\n',Xs_line);
fprintf('Line Ls             = %.6f H\n',Ls_line);
fprintf('Line X              = %.6f pu\n',Xs_line_pu);
fprintf('Grid-TF fraction    = %.2f\n',GridSourceFraction);
fprintf('Grid-TF R total     = %.6f pu\n',Rtf_grid_total_pu);
fprintf('Grid-TF X total     = %.6f pu\n',Xtf_grid_total_pu);
fprintf('Grid-TF R pri/sec   = %.6f / %.6f pu\n',Rtf_grid_pri_pu,Rtf_grid_sec_pu);
fprintf('Grid-TF X pri/sec   = %.6f / %.6f pu\n',Xtf_grid_pri_pu,Xtf_grid_sec_pu);

fprintf('\nSource-side transformer:\n');
fprintf('Source-TF R pri/sec = %.6f / %.6f pu\n',Rtf_src_pri_pu,Rtf_src_sec_pu);
fprintf('Source-TF X pri/sec = %.6f / %.6f pu\n',Xtf_src_pri_pu,Xtf_src_sec_pu);
fprintf('Current limiter X1  = %.6f pu\n',X1);
fprintf('Initial Xtot approx = %.6f pu\n',Xtot);


fprintf('\nFault selection:\n');

fprintf('SolidFault          = %d\n',SolidFault);
fprintf('RLFault             = %d\n',RLFault);


if AEMO_test ~= 168

    fprintf('\nFault timing:\n');

    fprintf('Fault start         = %.2f s\n',fault_start);
    fprintf('Fault clear         = %.2f s\n',fault_clear);
    fprintf('Fault duration      = %.2f s\n',fault_duration);

end


if RLFault == 1

    fprintf('\nRL fault impedance:\n');

    fprintf('|Zf|                = %.4f ohm\n',Zf_mag);
    fprintf('Fault X/R           = %.1f\n',XR_fault);

    fprintf('Rf                  = %.6f ohm\n',Rf);
    fprintf('Xf                  = %.6f ohm\n',Xf);
    fprintf('Lf                  = %.6f H\n',Lf);

end


fprintf('\nMatched controller / grid parameters:\n');
fprintf('Controller B D1     = %.6f\n',D1);
fprintf('Controller B J      = %.9f\n',J);
fprintf('Equivalent H1       = %.6f s\n',H1);
fprintf('RPC nq              = %.9f\n',nq);
fprintf('RPC Kiq             = %.9f\n',Kiq);
fprintf('Controller C mp     = %.6f\n',mp);
fprintf('Controller C Dp     = %.6f\n',Dp_C);
fprintf('Controller C a      = %.6f\n',a);
fprintf('Controller C b      = %.6f\n',b);
fprintf('Controller C c      = %.6f\n',c);
fprintf('Grid H2             = %.6f s\n',H2);
fprintf('Grid D2             = %.6f\n',D2);
fprintf('Grid Ki             = %.6f\n',Ki);

fprintf('\nOperating point:\n');

fprintf('Initial Pref        = %.2f pu\n',Pref);
fprintf('Qref                = %.2f pu\n',Qref);
fprintf('Vref                = %.2f pu\n',Vref);


if AEMO_test == 168

    fprintf('\n3.2.11 Pref sequence:\n');

    fprintf('0-5 s               = 1.00 pu\n');
    fprintf('5-15 s              = 0.50 pu\n');
    fprintf('15-25 s             = 0.05 pu\n');
    fprintf('25-35 s             = 1.00 pu\n');

end


fprintf('\nSteady-state initial conditions:\n');

fprintf('V1 PCC initial      = %.6f pu\n',V1PCCmag0);
fprintf('delta1 PCC initial  = %.3f degrees\n',rad2deg(delta1PCC0));
fprintf('V2 PCC initial      = %.6f pu\n',V2PCCmag0);
fprintf('delta2 PCC initial  = %.3f degrees\n',rad2deg(delta2PCC0));

fprintf('E1 internal initial = %.6f pu\n',E1_0);
fprintf('delta1 initial      = %.3f degrees\n',rad2deg(delta1_0));

fprintf('E2 internal initial = %.6f pu\n',E2_0);
fprintf('delta2 initial      = %.3f degrees\n',rad2deg(delta2_0));

fprintf('Initial P12         = %.3f pu\n',P12_0);
fprintf('Initial Q12         = %.3f pu\n',Q12_0);
fprintf('Initial Pload       = %.3f pu\n',Pload_0);

fprintf('Grid load int IC    = %.6f\n',GridLoadInt_IC);
fprintf('RPC integrator IC   = %.6f\n',RPCInt_IC);

fprintf('\nSimulation stop time = %.1f s\n',Tstop);

fprintf('============================================\n\n');