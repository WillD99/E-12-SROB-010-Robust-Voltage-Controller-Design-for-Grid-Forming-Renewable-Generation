%% SM-SM Simulink Model Initialisation

clear;
clc;

%% System frequency
f = 50;
ws = 2*pi*f;
a = 0.5;
b = 0.332731;
c = 0.239165;
mp = 9.42;

%% Time values (seconds)
t = [0 5 15 25 25 35 ]';

% Active power reference (pu)
Pref = [1 0.5 0.05 1 1 1 ]';

% Create timeseries for Simulink
Pref_AEMO = timeseries(Pref, t);

% Plot reference
figure;
stairs(t, Pref, 'LineWidth', 2);
xlabel('Time [s]');
ylabel('Active Power Reference [pu]');
title('AEMO Test 3.2.11 - Active Power Reference');
grid on;
ylim([0 1.2]);
xlim([0 40]);


%% Machine 1
H1  = 3;
D1  = 2;
Pm1 = 0.8;

%% Machine 2 / Grid
H2 = 5;
D2 = 3;

%% Grid load controller
Ki = 0.5;

%% Network
Xd1 = 0.30;
XT1 = 0.15;

Xd2 = 0.15;
XT2 = 0.10;

XL = 0.10;

Xtot = Xd1 + XT1 + XL + Xd2 + XT2;

%% Internal voltages
E1_0 = 1.0;
E2_0 = 1.0;

%% Initial active power
P12_0   = Pm1;
Pload_0 = P12_0;

%% Initial rotor angles

delta2_0 = 0;

delta1_0 = asin( ...
    P12_0*Xtot/(E1_0*E2_0) );

%% Initial speed deviations
Dw1_0 = 0;
Dw2_0 = 0;

%% Display initial conditions

fprintf('Initial delta1 = %.3f degrees\n',rad2deg(delta1_0));
fprintf('Initial delta2 = %.3f degrees\n',rad2deg(delta2_0));
fprintf('Initial P12    = %.3f pu\n',P12_0);
fprintf('Initial Pload  = %.3f pu\n',Pload_0);