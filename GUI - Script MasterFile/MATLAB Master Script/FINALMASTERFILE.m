%% ============================================================

% UNIFIED SOURCE - WEAK GRID MODEL

%

% Source models:

%   "SMSM" = Original synchronous machine 1

%   "B"    = Inverter Controller B

%   "C"    = Inverter Controller C


%

% Available tests:

%   "NONE"          = No disturbance

%   "VREF"          = Voltage reference step

%   "PREF"          = Active power reference step

%   "AEMO324_T1"    = AEMO 3.2.4 Test 1  (SCR 10, Zf = 0)

%   "AEMO324_T4"    = AEMO 3.2.4 Test 4  (SCR 3,  Zf = 0)

%   "AEMO324_T16"   = AEMO 3.2.4 Test 16 (SCR 3,  Zf = Zs)

%   "AEMO3211_T168" = AEMO 3.2.11 Test 168 active-power reference sequence

%

% Optional plant modification:

%   GridLoad.Enable = false -> Original finite-grid plant

%   GridLoad.Enable = true  -> Grid-side load integrator enabled

%

% Grid load integrator:

%

%   dPload/dt = Ki * domega2

%

% When enabled, the grid-side absorbed power slowly adjusts

% to restore Machine 2 frequency to synchronous speed.

%

% ============================================================

clear;

clc;

close all;

%% ============================================================

% MODEL SELECTION

% ============================================================

ModelSelect = "B";

% Options:

% ModelSelect = "SMSM";

% ModelSelect = "B";

% ModelSelect = "C";


ModelSelect = upper(string(ModelSelect));

ValidModels = ["SMSM","B","C"];

assert(any(ModelSelect == ValidModels), 'ModelSelect must be "SMSM", "B", or "C".');

%% ============================================================

% TEST SELECTION

% ============================================================

TestSelect = "AEMO3211_T168";

% Options:

% TestSelect = "NONE";

% TestSelect = "VREF";

% TestSelect = "PREF";

% TestSelect = "AEMO324_T1";

% TestSelect = "AEMO324_T4";

% TestSelect = "AEMO324_T16";

% TestSelect = "AEMO3211_T168";

TestSelect = upper(string(TestSelect));

ValidTests = ["NONE","VREF","PREF","AEMO324_T1","AEMO324_T4","AEMO324_T16","AEMO3211_T168"];

assert(any(TestSelect == ValidTests),'Invalid TestSelect value.');

%% ============================================================

% CONTROLLER PARAMETER SET

% ============================================================

ControllerParameterSet = "MOHAMMED";

% Options:

% ControllerParameterSet = "ORIGINAL";

% ControllerParameterSet = "MOHAMMED";

ControllerParameterSet = upper(string(ControllerParameterSet));

ValidParameterSets = ["ORIGINAL","MOHAMMED"];

assert(any(ControllerParameterSet == ValidParameterSets), 'ControllerParameterSet must be "ORIGINAL" or "MOHAMMED".');

%% ============================================================

% CURRENT LIMITER - VALIDATED MODEL B IMPLEMENTATION

% ============================================================

% Current limiting is applied to inverter models B and C only.
% SMSM remains an unconstrained synchronous-machine model.

CurrentLimiter.Enable = true;
CurrentLimiter.Imax = 1.20;

% Anti-windup / saturation management.
CurrentLimiter.ActivePowerAwareness = true;
CurrentLimiter.ReactiveIntegratorHold = true;

% Controller C has additional active-loop dynamic states. During current
% saturation these states are held to prevent active-loop wind-up, while
% source frequency deviation is allowed to decay through its output pole.

CurrentLimiter.Tolerance = 1e-3;
CurrentLimiter.Eps = 1e-9;

assert(CurrentLimiter.Imax > 0,'CurrentLimiter.Imax must be positive.');
assert(CurrentLimiter.Tolerance >= 0 && CurrentLimiter.Tolerance < 1,'CurrentLimiter.Tolerance must be between 0 and 1.');

%% ============================================================

% FAULT SELECTION

% ============================================================

% Manual fault switch for legacy NONE/VREF/PREF tests.

% AEMO 3.2.4 tests override this automatically.

Fault.ManualEnable = false;

Fault.Enable = Fault.ManualEnable;

%% ============================================================

% COMMON OPERATING POINT

% ============================================================

AEMO.Enable = startsWith(TestSelect,"AEMO");

if AEMO.Enable

    Op.P0 = 1.0;

else

    Op.P0 = 1.2;

end

Op.V1o = 1.0;

Op.V2o = 1.0;

Net.f = 50;

Net.ws = 2*pi*Net.f;

Net.wnom = Net.ws;

%% ============================================================

% TEST PARAMETERS

% ============================================================

Test.tstep = 5;

% Smooth transition to avoid DAE issues

Test.ramp_time = 0.01;

% Voltage reference test

Test.Vref_init = Op.V1o;

Test.Vref_after = 1.07;

% Active power reference test

Test.Pref_init = Op.P0;

Test.Pref_after = 1.30;

% AEMO 3.2.11 Test 168 reference sequence

Test.AEMO_Pref_t1 = 5;

Test.AEMO_Pref_t2 = 15;

Test.AEMO_Pref_t3 = 25;

Test.AEMO_Pref_1 = 1.00;

Test.AEMO_Pref_2 = 0.50;

Test.AEMO_Pref_3 = 0.05;

Test.AEMO_Pref_4 = 1.00;

%% ============================================================

% COMMON NETWORK PARAMETERS

% ============================================================

Net.Xd1 = 0.1;

Net.XT1 = 0.05;

Net.X1 = Net.Xd1 + Net.XT1;

Net.XL = 0.3;

%% ============================================================

% PLANT MODEL - SM2 / FINITE GRID

% ============================================================

Plant.D2 = 0.4;

Plant.H2 = 12;

Plant.Xd2 = 0.05;

Plant.XT2 = 0.05;

Plant.X2 = Plant.Xd2 + Plant.XT2;

Plant.K2 = 4*1.2;

Plant.V2o = Op.V2o;

% Original fixed mechanical/load term

Plant.Pm2 = -Op.P0;

%% ============================================================

% AEMO GRID-STRENGTH CONFIGURATION

% ============================================================

AEMO.SCR = NaN;

AEMO.XR = NaN;

AEMO.Xs = NaN;

AEMO.XL_fraction = 0.75;

AEMO.X2_fraction = 0.25;

switch TestSelect

    case "AEMO324_T1"

        AEMO.SCR = 10;

    case "AEMO324_T4"

        AEMO.SCR = 3;

    case "AEMO324_T16"

        AEMO.SCR = 3;

    case "AEMO3211_T168"

        AEMO.SCR = 3;

end

if isfinite(AEMO.SCR)

    AEMO.XR = 14;

    % The selected AEMO cases use X/R = 14. Resistance is neglected

    % in this reduced-order model because only reactance is represented.

    % Therefore the external-grid equivalent is Xs = 1/SCR.

    AEMO.Xs = 1/AEMO.SCR;

    % Map the total external-grid reactance into the existing

    % finite-grid topology while preserving the original 3:1 split.

    Net.XL = AEMO.XL_fraction*AEMO.Xs;

    Plant.X2 = AEMO.X2_fraction*AEMO.Xs;

end

%% ============================================================

% OPTIONAL GRID-SIDE LOAD INTEGRATOR

% ============================================================

% Kept enabled here to match the validated standalone Model B case.

GridLoad.Enable = true;

GridLoad.Ki = 0.5;

GridLoad.Pload0 = Op.P0;

%% ============================================================

% ORIGINAL SYNCHRONOUS MACHINE 1 PARAMETERS

% ============================================================

SM1.D1 = 0.1;

SM1.H1 = 3;

SM1.K1 = 1.2;

SM1.Pm1 = Op.P0;

SM1.V1o = Op.V1o;

%% ============================================================

% CONTROLLER B PARAMETERS

% ============================================================

CtrlB.Pref = Op.P0;

CtrlB.vnom = Op.V1o;

% Choose Controller B parameter set

CtrlB.ParameterSet = ControllerParameterSet;

switch upper(CtrlB.ParameterSet)

    case "ORIGINAL"

        % Original reduced-order tuning

        CtrlB.H_equiv = 3;

        CtrlB.J = 2*CtrlB.H_equiv/(Net.wnom^2);

        CtrlB.Dp = 0.1;

        CtrlB.nq = 0.05;

        CtrlB.Kiq = 1;

    case "MOHAMMED"

        % Mohammed et al. inverter bases

        Moh.Sbase = 5e6;                % 5 MVA

        Moh.VLL_rms = 690;              % 690 V line-line RMS

        Moh.Vbase = sqrt(2/3)*Moh.VLL_rms;

        % Mohammed et al. VSG parameters in SI units

        Moh.Dp = 1.273e6;               % W\\\\.s/rad

        Moh.J = 4052;                    % W\\\\.s^2/rad

        Moh.nq = 1.5e-5;                % V/Var

        Moh.Kiq = 1e-4;                 % V/(Var.s)

        % Convert to the per-unit form used by our reduced model

        CtrlB.Dp = Moh.Dp/Moh.Sbase;

        CtrlB.J = Moh.J/Moh.Sbase;

        CtrlB.nq = Moh.nq*Moh.Sbase/Moh.Vbase;

        CtrlB.Kiq = Moh.Kiq*Moh.Sbase/Moh.Vbase;

        CtrlB.H_equiv = NaN;

    otherwise

        error('Unknown Controller B parameter set.');

end

%% ============================================================

% CONTROLLER C PARAMETERS - CGVSG DESIGNED FOR SCR = 3

% ============================================================

CtrlC.Pref = Op.P0;

% Rathnayake et al. analytical design inputs.

% 1 percent P-f droop at 50 Hz gives mp = pi rad/s per pu.

% RoCoF design target = 1 Hz/s gives alpha = 0.5 s.

% kg_design is the local power-angle gain calculated at the

% SCR = 3, P0 = 1 pu, Q0 = 0 operating point.

CtrlC.kg_design = 1.8195;

CtrlC.mp = pi;

CtrlC.alpha = 0.5;

% Equations (31)-(32) of Rathnayake et al.

CtrlC.rootTerm = nthroot(CtrlC.kg_design^2*CtrlC.mp^2/CtrlC.alpha - 1,3);

CtrlC.beta = CtrlC.alpha^2*CtrlC.rootTerm;

CtrlC.gamma = 1/CtrlC.rootTerm;

% Final CGVSG parameters.

CtrlC.a = CtrlC.alpha;

CtrlC.b = (CtrlC.beta*CtrlC.gamma)/(CtrlC.beta + CtrlC.gamma - CtrlC.alpha);

CtrlC.c = (CtrlC.beta + CtrlC.gamma - CtrlC.alpha)/CtrlC.mp;

% The implemented damping gain is the inverse of the paper's P-f droop.

CtrlC.Dp = 1/CtrlC.mp;

% Mohammed et al. use the same RPC for VSG and CGVSG.

% Reuse Controller B RPC values from the selected parameter set.

CtrlC.nq = CtrlB.nq;

CtrlC.Kiq = CtrlB.Kiq;

CtrlC.vnom = Op.V1o;

if ModelSelect == "C"

    assert(CtrlC.a > 0 && CtrlC.b > 0 && CtrlC.c > 0,'Controller C parameters a, b and c must be positive.');

end

%% ============================================================

% FAULT PARAMETERS

% ============================================================

% Legacy/manual fault defaults

Fault.tFault = 5;

Fault.tClear = 5.15;

Fault.Rf = 0;

Fault.Xf = 0.10;

Fault.Ramp = 0.002;

Fault.Description = "Manual / legacy fault";

% Numerical approximation used for AEMO Zf = 0 cases.

% A true zero impedance would create an infinite shunt admittance.

Fault.BoltedXf = 1e-3;

if TestSelect == "AEMO324_T1"

    Fault.Enable = true;

    Fault.tFault = 5;

    Fault.tClear = 5.43;

    Fault.Rf = 0;

    Fault.Xf = Fault.BoltedXf;

    Fault.Ramp = 0.02;

    Fault.Description = "AEMO 3.2.4 Test 1: SCR 10, Zf = 0 (numerical bolted-fault approximation)";

elseif TestSelect == "AEMO324_T4"

    Fault.Enable = true;

    Fault.tFault = 5;

    Fault.tClear = 5.43;

    Fault.Rf = 0;

    Fault.Xf = Fault.BoltedXf;

    Fault.Ramp = 0.02;

    Fault.Description = "AEMO 3.2.4 Test 4: SCR 3, Zf = 0 (numerical bolted-fault approximation)";

elseif TestSelect == "AEMO324_T16"

    Fault.Enable = true;

    Fault.tFault = 5;

    Fault.tClear = 5.43;

    Fault.Rf = 0;

    Fault.Xf = AEMO.Xs;

    Fault.Ramp = 0.02;

    Fault.Description = "AEMO 3.2.4 Test 16: SCR 3, Zf = Zs";

elseif TestSelect == "AEMO3211_T168"

    Fault.Enable = false;

    Fault.Description = "No fault - AEMO 3.2.11 Test 168";

end

Fault.Gf = Fault.Rf/(Fault.Rf^2 + Fault.Xf^2);

Fault.Bf = Fault.Xf/(Fault.Rf^2 + Fault.Xf^2);

%% ============================================================

% INITIAL CONDITIONS - COMMON POWER FLOW

% ============================================================

domega10 = 0;

domega20 = 0;

V2PCCmag0 = Op.V2o;

delta2PCC0 = 0;

if AEMO.Enable

    % AEMO selected cases start at P = 1 pu and Q = 0 pu.

    % With a lossless line this requires V1 = V2*cos(delta).

    arg = 2*Op.P0*Net.XL/(V2PCCmag0^2);

    if abs(arg) > 1

        error('No P = 1 pu, Q = 0 pu equilibrium exists for the selected AEMO grid strength.');

    end

    delta1PCC0 = 0.5*asin(arg);

    V1PCCmag0 = V2PCCmag0*cos(delta1PCC0);

    Q12 = 0;

    Q21 = (V2PCCmag0^2 - V2PCCmag0*V1PCCmag0*cos(delta2PCC0-delta1PCC0))/Net.XL;

    Op.Qref = 0;

else

    V1PCCmag0 = Op.V1o;

    delta1PCC0 = asin(Op.P0*Net.XL/(V1PCCmag0*V2PCCmag0));

    Q12 = (V1PCCmag0^2 - V1PCCmag0*V2PCCmag0*cos(delta1PCC0-delta2PCC0))/Net.XL;

    Q21 = (V2PCCmag0^2 - V2PCCmag0*V1PCCmag0*cos(delta2PCC0-delta1PCC0))/Net.XL;

    Op.Qref = Q12;

end

if AEMO.Enable

    SM1.VregBias = V1PCCmag0 - Test.Vref_init;

else

    SM1.VregBias = 0;

end

%% ============================================================

% INITIAL SOURCE INTERNAL VOLTAGE

% ============================================================

E10 = hypot(Op.P0*Net.X1/V1PCCmag0, V1PCCmag0 + Q12*Net.X1/V1PCCmag0);

delta10 = delta1PCC0 + atan2(Op.P0*Net.X1/V1PCCmag0, V1PCCmag0 + Q12*Net.X1/V1PCCmag0);

%% ============================================================

% INITIAL SM2 INTERNAL VOLTAGE

% ============================================================

E20 = hypot(Plant.Pm2*Plant.X2/V2PCCmag0, V2PCCmag0 + Q21*Plant.X2/V2PCCmag0);

delta20 = delta2PCC0 + atan2(Plant.Pm2*Plant.X2/V2PCCmag0, V2PCCmag0 + Q21*Plant.X2/V2PCCmag0);

%% ============================================================

% UNIFIED STATE VECTOR

% ============================================================

%

% SOURCE:

%

% x(1) = delta1

% x(2) = source frequency deviation

%

% x(3):

%   SMSM  -> E1

%   B/C/D -> RPC integrator state

%

% x(4) = Controller C auxiliary state

% x(5) = Controller C auxiliary state

%

%

% PLANT:

%

% x(6) = delta2

% x(7) = domega2

% x(8) = E2

%

% x(9) = Pload

%

%

% NETWORK ALGEBRAIC:

%

% x(10) = V1PCC

% x(11) = delta1PCC

% x(12) = V2PCC

% x(13) = delta2PCC

%

% ============================================================

switch ModelSelect

    case "SMSM"

        sourceState30 = E10;

        sourceState40 = 0;

        sourceState50 = 0;

    case "B"

        sourceState30 = E10 - CtrlB.vnom;

        sourceState40 = 0;

        sourceState50 = 0;

    case "C"

        sourceState30 = E10 - CtrlC.vnom;

        sourceState40 = 0;

        sourceState50 = (CtrlC.a/CtrlC.c)*Op.P0;


end

x0 = [delta10;

      domega10;

      sourceState30;

      sourceState40;

      sourceState50;

      delta20;

      domega20;

      E20;

      GridLoad.Pload0;

      V1PCCmag0;

      delta1PCC0;

      V2PCCmag0;

      delta2PCC0];

%% ============================================================

% DYNAMIC EQUATIONS

% ============================================================

DynamicsEqs = @(t,x) UnifiedDynamics(t,x,ModelSelect,TestSelect,Test,Net,Plant,GridLoad,SM1,CtrlB,CtrlC,Op,Fault,CurrentLimiter);

%% ============================================================

% MASS MATRIX

% ============================================================

%

% First 9 variables = differential states

% Last 4 variables  = algebraic network states

%

Mass = diag([1 1 1 1 1 1 1 1 1 0 0 0 0]);

%% ============================================================

% SOLVER OPTIONS

% ============================================================

if Fault.Enable

    Solver.MaxStep = 0.001;

else

    Solver.MaxStep = 0.01;

end

options = odeset('Mass',Mass,'RelTol',1e-7,'AbsTol',1e-9,'MaxStep',Solver.MaxStep);

%% ============================================================

% SIMULATION TIME

% ============================================================

if any(TestSelect == ["AEMO324_T1","AEMO324_T4","AEMO324_T16"])

    Sim.tEnd = 15;

elseif TestSelect == "AEMO3211_T168"

    Sim.tEnd = 35;

else

    Sim.tEnd = 30;

end

Sim.dt = 0.001;

tspan = 0:Sim.dt:Sim.tEnd;

%% ============================================================

% CHECK DYNAMICS DIMENSION

% ============================================================

testDynamics = DynamicsEqs(0,x0);

assert(isequal(size(testDynamics),[13 1]), 'DynamicsEqs must return a 13x1 column vector.');

%% ============================================================

% SOLVE DAE

% ============================================================

[t,x] = ode15s(DynamicsEqs,tspan,x0,options);

%% ============================================================

% EXTRACT STATES

% ============================================================

delta1 = x(:,1);

domega1 = x(:,2);

sourceState3 = x(:,3);

sourceState4 = x(:,4);

sourceState5 = x(:,5);

delta2 = x(:,6);

domega2 = x(:,7);

E2 = x(:,8);

Pload = x(:,9);

V1PCCmag = x(:,10);

delta1PCC = x(:,11);

V2PCCmag = x(:,12);

delta2PCC = x(:,13);

%% ============================================================

% RECONSTRUCT TEST COMMANDS

% ============================================================

alpha_plot = max(0,min((t-Test.tstep)/Test.ramp_time,1));

Vref_plot = Test.Vref_init*ones(size(t));

Pref_plot = Test.Pref_init*ones(size(t));

EventTimes = [];

EventLabels = strings(1,0);

switch TestSelect

    case "VREF"

        Vref_plot = Test.Vref_init + (Test.Vref_after-Test.Vref_init).*alpha_plot;

        EventTimes = Test.tstep;

        EventLabels = "Vref step";

    case "PREF"

        Pref_plot = Test.Pref_init + (Test.Pref_after-Test.Pref_init).*alpha_plot;

        EventTimes = Test.tstep;

        EventLabels = "Pref step";

    case "AEMO3211_T168"

        Pref_plot(:) = Test.AEMO_Pref_1;

        Pref_plot(t >= Test.AEMO_Pref_t1 & t < Test.AEMO_Pref_t2) = Test.AEMO_Pref_2;

        Pref_plot(t >= Test.AEMO_Pref_t2 & t < Test.AEMO_Pref_t3) = Test.AEMO_Pref_3;

        Pref_plot(t >= Test.AEMO_Pref_t3) = Test.AEMO_Pref_4;

        EventTimes = [Test.AEMO_Pref_t1 Test.AEMO_Pref_t2 Test.AEMO_Pref_t3];

        EventLabels = ["Pref = 0.50" "Pref = 0.05" "Pref = 1.00"];

    case "AEMO324_T1"

        EventTimes = [Fault.tFault Fault.tClear];

        EventLabels = ["Fault applied" "Fault cleared"];

    case "AEMO324_T4"

        EventTimes = [Fault.tFault Fault.tClear];

        EventLabels = ["Fault applied" "Fault cleared"];

    case "AEMO324_T16"

        EventTimes = [Fault.tFault Fault.tClear];

        EventLabels = ["Fault applied" "Fault cleared"];

    case "NONE"

        % References remain at initial values

end

%% ============================================================

% FAULT SWITCHING SIGNAL

% ============================================================

FaultSignal = zeros(length(t),1);

for n = 1:length(t)

    FaultSignal(n) = FaultLevel(t(n),Fault);

end

%% ============================================================

% NETWORK POWER CALCULATIONS

% ============================================================

Pline = (V1PCCmag.*V2PCCmag/Net.XL).*sin(delta1PCC-delta2PCC);

Qline = V1PCCmag.^2/Net.XL - (V1PCCmag.*V2PCCmag/Net.XL).*cos(delta1PCC-delta2PCC);

Pfault = FaultSignal.*Fault.Gf.*V1PCCmag.^2;

Qfault = FaultSignal.*Fault.Bf.*V1PCCmag.^2;

Ppcc = Pline + Pfault;

Qpcc = Qline + Qfault;

%% ============================================================

% RECONSTRUCT SELECTED SOURCE MODEL OUTPUTS

% ============================================================

Perror = zeros(length(t),1);

Qerror = zeros(length(t),1);

E1 = zeros(length(t),1);

SourceAcceleration = zeros(length(t),1);

APC_x1 = NaN(length(t),1);

C_FilterState = NaN(length(t),1);

C_DampedSignal = NaN(length(t),1);

C_IntegralState = NaN(length(t),1);

C_BlockOutput = NaN(length(t),1);

switch ModelSelect

    %% --------------------------------------------------------

    % SYNCHRONOUS MACHINE

    % ---------------------------------------------------------

    case "SMSM"

        E1 = sourceState3;

        Pe1 = (E1.*V1PCCmag/Net.X1).*sin(delta1-delta1PCC);

        Perror = Pref_plot - Pe1;

        SourceAcceleration = (Net.ws/(2*SM1.H1)) .* (Pref_plot - Pe1 - SM1.D1.*domega1);

        Qerror(:) = NaN;

    %% --------------------------------------------------------

    % MODEL B

    % ---------------------------------------------------------

    case "B"

        Perror = Pref_plot - Ppcc;

        Qerror = Op.Qref - Qpcc;

        E1 = Vref_plot + CtrlB.nq.*Qerror + sourceState3;

        APC_x1 = (1/(CtrlB.J*Net.wnom)) .* (Pref_plot - Ppcc - CtrlB.Dp.*domega1);

        SourceAcceleration = APC_x1;

    %% --------------------------------------------------------

    % MODEL C

    % ---------------------------------------------------------

    case "C"

        Perror = Pref_plot - Ppcc;

        Qerror = Op.Qref - Qpcc;

        E1 = Vref_plot + CtrlC.nq.*Qerror + sourceState3;

        C_FilterState = sourceState4;

        C_DampedSignal = C_FilterState - CtrlC.Dp.*domega1;

        C_IntegralState = sourceState5;

        C_BlockOutput = (CtrlC.a/CtrlC.c).*C_DampedSignal + C_IntegralState;

        C_BInput = C_BlockOutput - (CtrlC.a/CtrlC.c).*Ppcc;

        SourceAcceleration = (1/CtrlC.b).*(C_BInput-domega1);


end

%% ============================================================

% SOURCE TERMINAL CURRENT / COMPLEX POWER

% ============================================================

E1_command_complex = E1.*exp(1j*delta1);
V1_complex = V1PCCmag.*exp(1j*delta1PCC);

I1cmd_complex = (E1_command_complex - V1_complex)/(1j*Net.X1);
I1cmd_mag = abs(I1cmd_complex);

CurrentLimiterScale = ones(size(t));
E1_actual_complex = E1_command_complex;

IsInverterModel = any(ModelSelect == ["B","C"]);

if IsInverterModel && CurrentLimiter.Enable
    CurrentLimiterScale = min(ones(size(I1cmd_mag)),CurrentLimiter.Imax./max(I1cmd_mag,CurrentLimiter.Eps));
    E1_actual_complex = V1_complex + CurrentLimiterScale.*(E1_command_complex - V1_complex);
end

E1Actual = abs(E1_actual_complex);

I1_complex = (E1_actual_complex - V1_complex)/(1j*Net.X1);
I1mag = abs(I1_complex);

I1_PCCframe = I1_complex.*exp(-1j*delta1PCC);
Iactive = real(I1_PCCframe);
Ireactive = -imag(I1_PCCframe);

Ssource = V1_complex.*conj(I1_complex);
Psource = real(Ssource);
Qsource = imag(Ssource);

% Reconstruct saturation-aware active-control quantities for plotting.
LimiterActivePlot = false(size(t));
if IsInverterModel && CurrentLimiter.Enable
    LimiterActivePlot = CurrentLimiterScale < (1-CurrentLimiter.Tolerance);
end

PerrorRaw = Pref_plot - Ppcc;

if ModelSelect == "B"
    Perror = PerrorRaw;

    if CurrentLimiter.ActivePowerAwareness
        Perror(LimiterActivePlot) = 0;
    end

    APC_x1 = (1/(CtrlB.J*Net.wnom)).*(Perror - CtrlB.Dp.*domega1);
    SourceAcceleration = APC_x1;

elseif ModelSelect == "C"

    Pcontrol_plot = Ppcc;

    if CurrentLimiter.ActivePowerAwareness
        Pcontrol_plot(LimiterActivePlot) = Pref_plot(LimiterActivePlot);
    end

    Perror = Pref_plot - Pcontrol_plot;

    C_FilterState = sourceState4;
    C_DampedSignal = C_FilterState - CtrlC.Dp.*domega1;
    C_IntegralState = sourceState5;

    C_BlockOutput = ...
        (CtrlC.a/CtrlC.c).*C_DampedSignal + C_IntegralState;

    C_BInput = ...
        C_BlockOutput - (CtrlC.a/CtrlC.c).*Pcontrol_plot;

    SourceAcceleration = ...
        (1/CtrlC.b).*(C_BInput - domega1);

end



%% ============================================================

% FREQUENCY AND RoCoF

% ============================================================

SourceDeltaF = domega1/(2*pi);

GridDeltaF = domega2/(2*pi);

SourceRoCoF = SourceAcceleration/(2*pi);

%% ============================================================

% GRID INTEGRATOR STATUS STRING

% ============================================================

if GridLoad.Enable

    GridLoadLabel = "Grid Integrator ON";

else

    GridLoadLabel = "Grid Integrator OFF";

end

%% ============================================================

% COMMON RESPONSE PLOTS

% ============================================================

IsAEMOFaultTest = any(TestSelect == ["AEMO324_T1","AEMO324_T4","AEMO324_T16"]);

if IsAEMOFaultTest

    figure('Visible','on');

    subplot(2,3,1);

    plot(t,V1PCCmag,'LineWidth',1.5);

    hold on;

    plot(t,Vref_plot,'--','LineWidth',1.2);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Voltage (pu)');

    title('PCC Voltage');

    legend('V\\\\\\\_{PCC1}','V\\\\\\\_{ref}','Location','best');

    grid on;

    subplot(2,3,2);

    plot(t,Ppcc,'LineWidth',1.5);

    hold on;

    plot(t,Pref_plot,'--','LineWidth',1.2);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P (pu)');

    title('Active Power');

    legend('P\\\\\\\_{PCC}','P\\\\\\\_{ref}','Location','best');

    grid on;

    subplot(2,3,3);

    plot(t,Qpcc,'LineWidth',1.5);

    hold on;

    plot(t,Qline,'--','LineWidth',1.2);

    plot(t,Qfault,':','LineWidth',1.2);

    yline(Op.Qref,'--','LineWidth',1.0);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Q (pu)');

    title('Reactive Power');

    legend('Q\\\\\\\_{plant}','Q\\\\\\\_{line}','Q\\\\\\\_{fault}','Q\\\\\\\_{ref}','Location','best');

    grid on;

    subplot(2,3,4);

    plot(t,I1mag,'LineWidth',1.5);

    hold on;

    if any(ModelSelect == ["B","C"]) && CurrentLimiter.Enable

        yline(CurrentLimiter.Imax,'--','I\_{max}','LineWidth',1.0);

    end

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('|I| (pu)');

    title('Source Terminal Current');

    grid on;

    subplot(2,3,5);

    plot(t,Iactive,'LineWidth',1.5);

    hold on;

    plot(t,Ireactive,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Current (pu)');

    title('Active and Reactive Current');

    legend('I_P','I_Q','Location','best');

    grid on;

    subplot(2,3,6);

    plot(t,SourceDeltaF,'LineWidth',1.5);

    hold on;

    plot(t,GridDeltaF,'LineWidth',1.5);

    yline(0,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Delta f (Hz)');

    title('Frequency Deviation');

    legend('Source','Grid','Location','best');

    grid on;

    sgtitle("Model " + ModelSelect + " - " + TestSelect + " - SCR " + string(AEMO.SCR));

else

    figure('Visible','on');

    subplot(2,2,1);

    plot(t,V1PCCmag,'LineWidth',1.5);

    hold on;

    plot(t,Vref_plot,'--','LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Voltage (pu)');

    title('Terminal Voltage');

    legend('V\\\\\\\_{PCC1}','V\\\\\\\_{ref}','Location','best');

    grid on;

    subplot(2,2,2);

    plot(t,Ppcc,'LineWidth',1.5);

    hold on;

    plot(t,Pref_plot,'--','LineWidth',1.5);

    if GridLoad.Enable

        plot(t,Pload,'LineWidth',1.5);

        legend('P\\\\\\\_{PCC}','P\\\\\\\_{ref}','P\\\\\\\_{load}','Location','best');

    else

        legend('P\\\\\\\_{PCC}','P\\\\\\\_{ref}','Location','best');

    end

    AddEventLines(EventTimes,EventLabels,TestSelect == "AEMO3211_T168");

    xlabel('Time (s)');

    ylabel('P (pu)');

    title('Active Power');

    grid on;

    subplot(2,2,3);

    plot(t,Qpcc,'LineWidth',1.5);

    hold on;

    yline(Op.Qref,'--','LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Q (pu)');

    title('Reactive Power');

    legend('Q\\\\\\\_{PCC}','Q\\\\\\\_{ref}','Location','best');

    grid on;

    subplot(2,2,4);

    plot(t,SourceDeltaF,'LineWidth',1.5);

    hold on;

    plot(t,GridDeltaF,'LineWidth',1.2);

    yline(0,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Delta f (Hz)');

    title('Source and Grid Frequency Deviation');

    legend('Source','Grid','Location','best');

    grid on;

    sgtitle("Model " + ModelSelect + " - " + TestSelect + " - " + GridLoadLabel);

end

%% ============================================================

% GRID LOAD / FREQUENCY VERIFICATION PLOTS

% ============================================================

if GridLoad.Enable

    figure('Visible','on');

    %% Grid Frequency

    subplot(2,2,1);

    plot(t,GridDeltaF,'LineWidth',1.5);

    hold on;

    yline(0,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('\Delta f_2 (Hz)');

    title('Grid Frequency Deviation');

    grid on;

    %% Grid Load

    subplot(2,2,2);

    plot(t,Pload,'LineWidth',1.5);

    hold on;

    yline(GridLoad.Pload0,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P\\\\\\\_{load} (pu)');

    title('Grid Load Integrator Output');

    grid on;

    %% Source and Grid Frequency

    subplot(2,2,3);

    plot(t,SourceDeltaF,'LineWidth',1.5);

    hold on;

    plot(t,GridDeltaF,'LineWidth',1.5);

    yline(0,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('\Delta f (Hz)');

    title('Source and Grid Frequency');

    legend('Source','Grid','Location','best');

    grid on;

    %% Power Balance

    subplot(2,2,4);

    plot(t,Ppcc,'LineWidth',1.5);

    hold on;

    plot(t,Pload,'LineWidth',1.5);

    plot(t,Pref_plot,'--','LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P (pu)');

    title('Power Balance');

    legend('P\\\\\\\_{PCC}','P\\\\\\\_{load}','P\\\\\\\_{ref}','Location','best');

    grid on;

    sgtitle("Grid-Side Load Integrator Verification");

end

%% ============================================================

% INVERTER CURRENT LIMITER VERIFICATION

% ============================================================

if any(ModelSelect == ["B","C"]) && CurrentLimiter.Enable

    figure('Visible','on');

    subplot(2,2,1);
    plot(t,E1,'LineWidth',1.5);
    hold on;
    plot(t,E1Actual,'LineWidth',1.5);
    AddEventLines(EventTimes,EventLabels,false);
    xlabel('Time (s)');
    ylabel('Voltage (pu)');
    title('Commanded and Actual Internal Voltage');
    legend('E_{cmd}','E_{actual}','Location','best');
    grid on;

    subplot(2,2,2);
    plot(t,I1cmd_mag,'LineWidth',1.2);
    hold on;
    plot(t,I1mag,'LineWidth',1.5);
    yline(CurrentLimiter.Imax,'--','I_{max}','LineWidth',1.0);
    AddEventLines(EventTimes,EventLabels,false);
    xlabel('Time (s)');
    ylabel('|I| (pu)');
    title('Commanded and Actual Current');
    legend('|I_{cmd}|','|I_{actual}|','I_{max}','Location','best');
    grid on;

    subplot(2,2,3);
    plot(t,CurrentLimiterScale,'LineWidth',1.5);
    hold on;
    yline(1,'--','LineWidth',1.0);
    AddEventLines(EventTimes,EventLabels,false);
    xlabel('Time (s)');
    ylabel('Limiter Scale');
    ylim([0 1.05]);
    title('Current Limiter Scaling');
    grid on;

    subplot(2,2,4);
    plot(t,PerrorRaw,'LineWidth',1.2);
    hold on;
    plot(t,Perror,'LineWidth',1.5);
    yline(0,'--','LineWidth',1.0);
    AddEventLines(EventTimes,EventLabels,false);
    xlabel('Time (s)');
    ylabel('P Error (pu)');
    title('Raw and Saturation-Aware Active Error');
    legend('Raw error','Effective error','Location','best');
    grid on;

    sgtitle("Current Limiter Verification - Model " + ModelSelect);

end

%% ============================================================

% MODEL B VERIFICATION PLOTS

% ============================================================

if ModelSelect == "B"

    figure('Visible','on');

    %% P PCC and Pref

    subplot(3,2,1);

    plot(t,Ppcc,'LineWidth',1.5);

    hold on;

    plot(t,Pref_plot,'--','LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P (pu)');

    title('P\\\\\\\_{PCC} and P\\\\\\\_{ref}');

    legend('P\\\\\\\_{PCC}','P\\\\\\\_{ref}','Location','best');

    grid on;

    %% APC Error

    subplot(3,2,2);

    plot(t,Perror,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P Error (pu)');

    title('Active Power Error');

    grid on;

    %% RPC Reactive Power

    subplot(3,2,3);

    plot(t,Qpcc,'LineWidth',1.5);

    hold on;

    yline(Op.Qref,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Q (pu)');

    title('Q\\\\\\\_{PCC} and Q\\\\\\\_{ref}');

    grid on;

    %% RPC Integrator State

    subplot(3,2,4);

    plot(t,sourceState3,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('x_3');

    title('RPC Integrator State');

    grid on;

    %% Internal Voltage

    subplot(3,2,5);

    plot(t,E1,'LineWidth',1.5);

    hold on;

    plot(t,E1Actual,'LineWidth',1.2);

    plot(t,Vref_plot,'--','LineWidth',1.2);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('E_1 (pu)');

    title('Model B Internal Voltage');

    legend('E_{cmd}','E_{actual}','V_{ref}','Location','best');

    grid on;

    %% RoCoF

    subplot(3,2,6);

    plot(t,SourceRoCoF,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('RoCoF (Hz/s)');

    title('Model B RoCoF');

    grid on;

    sgtitle("Model B Internal Verification - " + TestSelect);

end

%% ============================================================

% MODEL C VERIFICATION PLOTS

% ============================================================

if ModelSelect == "C"

    figure('Visible','on');

    subplot(3,2,1);

    plot(t,Ppcc,'LineWidth',1.5);

    hold on;

    plot(t,Pref_plot,'--','LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P (pu)');

    title('P\\\_{PCC} and P\\\_{ref}');

    legend('P\\\_{PCC}','P\\\_{ref}','Location','best');

    grid on;

    subplot(3,2,2);

    plot(t,Perror,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('P Error (pu)');

    title('Active Power Error');

    grid on;

    subplot(3,2,3);

    plot(t,C_FilterState,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('x_f');

    title('CGVSG Filter State');

    grid on;

    subplot(3,2,4);

    plot(t,C_IntegralState,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('xi_c');

    title('CGVSG Integral State');

    grid on;

    subplot(3,2,5);

    plot(t,SourceDeltaF,'LineWidth',1.5);

    hold on;

    plot(t,GridDeltaF,'LineWidth',1.2);

    yline(0,'--');

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('Delta f (Hz)');

    title('Source and Grid Frequency');

    legend('Source','Grid','Location','best');

    grid on;

    subplot(3,2,6);

    plot(t,SourceRoCoF,'LineWidth',1.5);

    AddEventLines(EventTimes,EventLabels,false);

    xlabel('Time (s)');

    ylabel('RoCoF (Hz/s)');

    title('Controller C RoCoF');

    grid on;

    sgtitle("Model C Internal Verification - " + TestSelect);

end

%% ============================================================

% DISPLAY TEST INFORMATION

% ============================================================

fprintf('\n');

fprintf('============================================\n');

fprintf('SIMULATION COMPLETE\n');

fprintf('Model selected        : %s\n',ModelSelect);

fprintf('Test selected         : %s\n',TestSelect);

fprintf('Initial Pref          : %.3f pu\n',Pref_plot(1));

fprintf('Final Pref            : %.3f pu\n',Pref_plot(end));

fprintf('Initial Vref          : %.3f pu\n',Vref_plot(1));

fprintf('Final Vref            : %.3f pu\n',Vref_plot(end));

fprintf('SM2 inertia H2        : %.3f s\n',Plant.H2);

fprintf('Grid load integrator  : %d\n',GridLoad.Enable);

if any(ModelSelect == ["B","C"])

    fprintf('Current limiter        : %d\n',CurrentLimiter.Enable);
    fprintf('Current limit Imax     : %.3f pu\n',CurrentLimiter.Imax);
    fprintf('AP saturation awareness: %d\n',CurrentLimiter.ActivePowerAwareness);
    fprintf('RPC integrator hold    : %d\n',CurrentLimiter.ReactiveIntegratorHold);

end

if AEMO.Enable

    fprintf('AEMO SCR              : %.3f\n',AEMO.SCR);

    fprintf('AEMO X/R specified    : %.1f (R neglected in model)\n',AEMO.XR);

    fprintf('Equivalent Xs         : %.6f pu\n',AEMO.Xs);

    fprintf('Net.XL                : %.6f pu\n',Net.XL);

    fprintf('Plant.X2              : %.6f pu\n',Plant.X2);

    fprintf('Initial Qref          : %.6f pu\n',Op.Qref);

end

if Fault.Enable

    fprintf('Fault description     : %s\n',Fault.Description);

    fprintf('Fault duration        : %.3f s\n',Fault.tClear-Fault.tFault);

    fprintf('Fault Xf used         : %.6f pu\n',Fault.Xf);

end

if GridLoad.Enable

    fprintf('Grid load Ki          : %.4f\n',GridLoad.Ki);

    fprintf('Initial Pload         : %.6f pu\n',GridLoad.Pload0);

    fprintf('Final Pload           : %.6f pu\n',Pload(end));

    fprintf('Final grid Delta f    : %.8f Hz\n',GridDeltaF(end));

    fprintf('Final source Delta f  : %.8f Hz\n',SourceDeltaF(end));

end

if IsAEMOFaultTest

    fault_idx = t >= Fault.tFault & t <= Fault.tClear;

    post_idx = t > Fault.tClear;

    fprintf('Minimum fault Vpcc    : %.6f pu\n',min(V1PCCmag(fault_idx)));

    fprintf('Maximum fault |I|     : %.6f pu\n',max(I1mag(fault_idx)));

    fprintf('Minimum fault P       : %.6f pu\n',min(Ppcc(fault_idx)));

    fprintf('Maximum post-fault P  : %.6f pu\n',max(Ppcc(post_idx)));

end

if ModelSelect == "C"

    fprintf('Controller C kg design : %.6f pu/rad\n',CtrlC.kg_design);

    fprintf('Controller C mp        : %.6f rad/s/pu\n',CtrlC.mp);

    fprintf('Controller C Dp impl   : %.6f pu/(rad/s)\n',CtrlC.Dp);

    fprintf('Controller C alpha     : %.6f s\n',CtrlC.alpha);

    fprintf('Controller C beta      : %.6f s\n',CtrlC.beta);

    fprintf('Controller C gamma     : %.6f s\n',CtrlC.gamma);

    fprintf('Controller C a         : %.6f\n',CtrlC.a);

    fprintf('Controller C b         : %.6f\n',CtrlC.b);

    fprintf('Controller C c         : %.6f\n',CtrlC.c);

end

if TestSelect == "AEMO3211_T168"

    idx_05 = t >= 14 & t < 15;

    idx_005 = t >= 24 & t < 25;

    idx_10 = t >= 34;

    fprintf('P before 15 s         : %.6f pu (target 0.500000)\n',mean(Ppcc(idx_05)));

    fprintf('P before 25 s         : %.6f pu (target 0.050000)\n',mean(Ppcc(idx_005)));

    fprintf('Final-window P        : %.6f pu (target 1.000000)\n',mean(Ppcc(idx_10)));

end

fprintf('============================================\n');

fprintf('\n');

%% ============================================================

% LOCAL FUNCTION - COMPLETE UNIFIED DYNAMIC MODEL

% ============================================================

function dx = UnifiedDynamics(t,x,ModelSelect,TestSelect,Test,Net,Plant,GridLoad,SM1,CtrlB,CtrlC,Op,Fault,CurrentLimiter)

    %% SOURCE VARIABLES

    delta1 = x(1);

    domega1 = x(2);

    sourceState3 = x(3);

    sourceState4 = x(4);

    sourceState5 = x(5);

    %% PLANT VARIABLES

    delta2 = x(6);

    domega2 = x(7);

    E2 = x(8);

    Pload = x(9);

    %% NETWORK ALGEBRAIC VARIABLES

    V1 = x(10);

    delta1PCC = x(11);

    V2 = x(12);

    delta2PCC = x(13);

    %% FAULT

    fault = FaultLevel(t,Fault);

    Pfault = fault*Fault.Gf*V1^2;

    Qfault = fault*Fault.Bf*V1^2;

    %% COMMON PCC POWER

    Pline = (V1*V2/Net.XL)*sin(delta1PCC-delta2PCC);

    Qline = V1^2/Net.XL - (V1*V2/Net.XL)*cos(delta1PCC-delta2PCC);

    Ppcc = Pline + Pfault;

    Qpcc = Qline + Qfault;

    %% SELECT TEST INPUTS

    alpha = max(0,min((t-Test.tstep)/Test.ramp_time,1));

    Vref_current = Test.Vref_init;

    Pref_current = Test.Pref_init;

    switch TestSelect

        case "VREF"

            Vref_current = Test.Vref_init + (Test.Vref_after-Test.Vref_init)*alpha;

        case "PREF"

            Pref_current = Test.Pref_init + (Test.Pref_after-Test.Pref_init)*alpha;

        case "AEMO3211_T168"

            if t < Test.AEMO_Pref_t1

                Pref_current = Test.AEMO_Pref_1;

            elseif t < Test.AEMO_Pref_t2

                Pref_current = Test.AEMO_Pref_2;

            elseif t < Test.AEMO_Pref_t3

                Pref_current = Test.AEMO_Pref_3;

            else

                Pref_current = Test.AEMO_Pref_4;

            end

        case "NONE"

            % No reference change

        case "AEMO324_T1"

            % Fault-only test: references remain fixed

        case "AEMO324_T4"

            % Fault-only test: references remain fixed

        case "AEMO324_T16"

            % Fault-only test: references remain fixed

    end

    %% ========================================================

    % SELECT SOURCE MODEL

    % ========================================================

    % Source phasor applied to the network.

    % For SMSM/C it equals the controller/source command.

    % For Model B it may be modified by the current limiter.

    E1_network = NaN;

    delta1_network = delta1;

    switch ModelSelect

        %% ----------------------------------------------------
        % SYNCHRONOUS MACHINE
        % -----------------------------------------------------
        case "SMSM"

            E1 = sourceState3;
            Pe1 = (E1*V1/Net.X1)*sin(delta1-delta1PCC);

            d_delta1 = domega1;
            d_domega1 = (Net.ws/(2*SM1.H1))*(Pref_current - Pe1 - SM1.D1*domega1);
            d_sourceState3 = SM1.K1*(Vref_current + SM1.VregBias - V1);
            d_sourceState4 = 0;
            d_sourceState5 = 0;

            E1_network = E1;
            delta1_network = delta1;

        %% ----------------------------------------------------
        % CONTROLLER B
        % -----------------------------------------------------
        case "B"

            Qerror = Op.Qref - Qpcc;
            E1 = Vref_current + CtrlB.nq*Qerror + sourceState3;

            [E1_network,delta1_network,CurrentScale] = ApplyCurrentLimiter(E1,delta1,V1,delta1PCC,Net.X1,CurrentLimiter);
            LimiterActive = CurrentLimiter.Enable && CurrentScale < (1-CurrentLimiter.Tolerance);

            Perror_raw = Pref_current - Ppcc;
            Perror_eff = Perror_raw;

            if LimiterActive && CurrentLimiter.ActivePowerAwareness
                Perror_eff = 0;
            end

            x1_APC = (1/(CtrlB.J*Net.wnom))*(Perror_eff - CtrlB.Dp*domega1);

            d_delta1 = domega1;
            d_domega1 = x1_APC;

            if LimiterActive && CurrentLimiter.ReactiveIntegratorHold
                d_sourceState3 = 0;
            else
                d_sourceState3 = CtrlB.Kiq*Qerror;
            end

            d_sourceState4 = 0;
            d_sourceState5 = 0;

        %% ----------------------------------------------------
        % CONTROLLER C
        % -----------------------------------------------------
        case "C"

    Qerror = Op.Qref - Qpcc;
    E1 = Vref_current + CtrlC.nq*Qerror + sourceState3;

    [E1_network,delta1_network,CurrentScale] = ApplyCurrentLimiter(E1,delta1,V1,delta1PCC,Net.X1,CurrentLimiter);
    LimiterActive = CurrentLimiter.Enable && CurrentScale < (1-CurrentLimiter.Tolerance);

    Pcontrol = Ppcc;

    if LimiterActive && CurrentLimiter.ActivePowerAwareness
        Pcontrol = Pref_current;
    end

    eP = Pref_current - Pcontrol;

    y = sourceState4;
    d_y = (1/CtrlC.a)*(eP-y);

    u = y - CtrlC.Dp*domega1;

    zInt = sourceState5;
    d_zInt = (1/CtrlC.c)*u;

    z = (CtrlC.a/CtrlC.c)*u + zInt;

    inputB = z - (CtrlC.a/CtrlC.c)*Pcontrol;

    d_domega1 = (1/CtrlC.b)*(inputB-domega1);

    d_delta1 = domega1;

    if LimiterActive && CurrentLimiter.ReactiveIntegratorHold
        d_sourceState3 = 0;
    else
        d_sourceState3 = CtrlC.Kiq*Qerror;
    end

    d_sourceState4 = d_y;
    d_sourceState5 = d_zInt;

    end

    %% ========================================================

    % PLANT MODEL - SM2 / FINITE GRID

    % ========================================================

    Pe2 = (E2*V2/Plant.X2)*sin(delta2-delta2PCC);

    d_delta2 = domega2;

    %% OPTIONAL GRID-SIDE LOAD INTEGRATOR

    if GridLoad.Enable

        % Grid-side load acts like negative mechanical power

        Pm2_effective = -Pload;

        % Secondary frequency restoration

        d_Pload = GridLoad.Ki*domega2;

    else

        % Original finite-grid plant

        Pm2_effective = Plant.Pm2;

        % Keep unused load state constant

        d_Pload = 0;

    end

    d_domega2 = (Net.ws/(2*Plant.H2)) *(Pm2_effective - Pe2 - Plant.D2*domega2);

    d_E2 = Plant.K2*(Plant.V2o-V2);

    %% ========================================================

    % COMMON NETWORK ALGEBRAIC EQUATIONS

    % ========================================================

    F10 = (E1_network*V1/Net.X1)*sin(delta1_network-delta1PCC) - (V1*V2/Net.XL)*sin(delta1PCC-delta2PCC) - Pfault;

    F11 = (E1_network*V1*cos(delta1_network-delta1PCC) - V1^2)/Net.X1 - (V1^2 - V1*V2*cos(delta1PCC-delta2PCC))/Net.XL - Qfault;

    F12 = (E2*V2/Plant.X2)*sin(delta2-delta2PCC) - (V2*V1/Net.XL)*sin(delta2PCC-delta1PCC);

    F13 = (E2*V2*cos(delta2-delta2PCC) - V2^2)/Plant.X2 - (V2^2 - V2*V1*cos(delta2PCC-delta1PCC))/Net.XL;

    %% RETURN DAE EQUATIONS

    dx = [d_delta1;

          d_domega1;

          d_sourceState3;

          d_sourceState4;

          d_sourceState5;

          d_delta2;

          d_domega2;

          d_E2;

          d_Pload;

          F10;

          F11;

          F12;

          F13];

end

%% ============================================================

% LOCAL FUNCTION - INVERTER CURRENT LIMITER (MODELS B/C)

% ============================================================

function [Eactual,deltaActual,scale] = ApplyCurrentLimiter(Ecmd,deltaCmd,Vpcc,deltaPCC,X1,CurrentLimiter)

    Ecmd_complex = Ecmd*exp(1j*deltaCmd);

    Vpcc_complex = Vpcc*exp(1j*deltaPCC);

    Icmd_complex = (Ecmd_complex - Vpcc_complex)/(1j*X1);

    Icmd_mag = abs(Icmd_complex);

    if CurrentLimiter.Enable

        scale = min(1,CurrentLimiter.Imax/max(Icmd_mag,CurrentLimiter.Eps));

    else

        scale = 1;

    end

    Eactual_complex = Vpcc_complex + scale*(Ecmd_complex - Vpcc_complex);

    Eactual = abs(Eactual_complex);

    deltaActual = angle(Eactual_complex);

end

%% ============================================================

% LOCAL FUNCTION - FAULT SWITCHING

% ============================================================

function fault = FaultLevel(t,Fault)

    if ~Fault.Enable

        fault = 0;

        return;

    end

    if Fault.Ramp <= 0

        fault = double(t >= Fault.tFault && t < Fault.tClear);

        return;

    end

    if t < Fault.tFault

        fault = 0;

    elseif t < Fault.tFault + Fault.Ramp

        fault = (t-Fault.tFault)/Fault.Ramp;

    elseif t < Fault.tClear - Fault.Ramp

        fault = 1;

    elseif t < Fault.tClear

        fault = (Fault.tClear-t)/Fault.Ramp;

    else

        fault = 0;

    end

end

%% ============================================================

% LOCAL FUNCTION - EVENT LINES

% ============================================================

function AddEventLines(EventTimes,EventLabels,ShowLabels)

    for k = 1:numel(EventTimes)

        if ShowLabels && k <= numel(EventLabels)

            xline(EventTimes(k),'--',EventLabels(k));

        else

            xline(EventTimes(k),'--');

        end

    end

end