%% Example 10.5 - Time-domain simulation using ode45

clear; clc; close all;

%% GIVEN DATA
H   = 3;
D   = 0;
f   = 50;
w0  = 2*pi*f;

Xd1 = 0.30;
XT  = 0.15;
XL  = 0.10;

%% VALUES FROM EXAMPLE 10.2
E = 1.2042;
V = 0.8732;

delta0 = deg2rad(24.74);

%% TRANSFER REACTANCE
Xe = Xd1 + XT + XL;

%% POWER-ANGLE CURVE
Pmax = E*V/Xe;

%% MECHANICAL POWER
Pm = Pmax*sin(delta0);

%% INITIAL STATE
% x(1) = delta
% x(2) = speed deviation d(delta)/dt
x0 = [delta0; 0];

%% TIME SETTINGS
t_fault = 1.0;
t_end   = 5.0;

t_clear_stable   = t_fault + 0.228;
t_clear_unstable = t_fault + 0.229;

%% ODEs

% Prefault and postfault: normal electrical power transfer
ode_normal = @(t,x)[ ...
    x(2); ...
    (w0/(2*H))*(Pm - Pmax*sin(x(1)) - D*x(2)) ...
];

% Fault-on: sending-end 3-phase fault means Pe = 0
ode_fault = @(t,x)[ ...
    x(2); ...
    (w0/(2*H))*(Pm - 0 - D*x(2)) ...
];

%% STABLE CASE: clearing at 228 ms

[t1a,x1a] = ode45(ode_normal, [0 t_fault], x0);
[t1b,x1b] = ode45(ode_fault, [t_fault t_clear_stable], x1a(end,:));
[t1c,x1c] = ode45(ode_normal, [t_clear_stable t_end], x1b(end,:));

t1 = [t1a; t1b(2:end); t1c(2:end)];
x1 = [x1a; x1b(2:end,:); x1c(2:end,:)];

%% UNSTABLE CASE: clearing at 229 ms

[t2a,x2a] = ode45(ode_normal, [0 t_fault], x0);
[t2b,x2b] = ode45(ode_fault, [t_fault t_clear_unstable], x2a(end,:));
[t2c,x2c] = ode45(ode_normal, [t_clear_unstable t_end], x2b(end,:));

t2 = [t2a; t2b(2:end); t2c(2:end)];
x2 = [x2a; x2b(2:end,:); x2c(2:end,:)];

%% DISPLAY RESULTS

fprintf('Xe     = %.4f pu\n', Xe);
fprintf('Pmax   = %.4f pu\n', Pmax);
fprintf('Pm     = %.4f pu\n', Pm);
fprintf('delta0 = %.4f deg\n', rad2deg(delta0));

%% PLOT ROTOR ANGLE

figure;
plot(t1, rad2deg(x1(:,1)), 'LineWidth', 2); hold on;
plot(t2, rad2deg(x2(:,1)), '--', 'LineWidth', 2);

xline(t_fault, ':k', 'Fault applied');
xline(t_clear_stable, ':b', 'Clear 228 ms');
xline(t_clear_unstable, ':r', 'Clear 229 ms');

grid on;
xlabel('Time (s)');
ylabel('\delta (degrees)');
title('Example 10.5 Rotor Angle Response');
legend('Stable: 228 ms','Unstable: 229 ms','Location','best');

%% PLOT SPEED DEVIATION

figure;
plot(t1, x1(:,2), 'LineWidth', 2); hold on;
plot(t2, x2(:,2), '--', 'LineWidth', 2);

xline(t_fault, ':k', 'Fault applied');
xline(t_clear_stable, ':b', 'Clear 228 ms');
xline(t_clear_unstable, ':r', 'Clear 229 ms');

grid on;
xlabel('Time (s)');
ylabel('\Delta\omega = d\delta/dt (rad/s)');
title('Example 10.5 Rotor Speed Deviation');
legend('Stable: 228 ms','Unstable: 229 ms','Location','best');