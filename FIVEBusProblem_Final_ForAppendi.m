%% Glover 5 bus solution
% knowns
R24 = 0.009;
X24 = 0.1;
b24 = 1.72;
R25 = 0.0045;
X25 = 0.05;
b25 = 0.88;
R45 = 0.00225;
X45 = 0.025;
b45 = 0.44;
R15 = 0.0015;
X15 = 0.02;
R34 = 0.00075;
X34 = 0.01;

% building admittance off diagonals
Y24 = -1/(R24 + 1j*X24);
Y25 = -1/(R25 + 1j*X25);
Y45 = -1/(R45 + 1j*X45);
Y15 = -1/(R15 + 1j*X15);
Y34 = -1/(R34 + 1j*X34);
% admittance diagonals
Y11 = -Y15;
Y22 = -Y24 + -Y25 + 1j*b24/2 + 1j*b25/2;
Y33 = -Y34;
Y44 = -Y24 + -Y45 + -Y34 + 1j*b24/2 + 1j*b45/2;
Y55 = -Y45 + -Y15 + -Y25 + b45*1j/2 + b25*1j/2;
% admittance matrix
Y = [Y11, 0, 0, 0, Y15;
     0, Y22, 0, Y24, Y25;
     0, 0, Y33, Y34, 0;
     0, Y24, Y34, Y44, Y45;
     Y15, Y25, 0, Y45, Y55];
% converting to G and B components
G11 = real(Y11);
B11 = imag(Y11);
G15 = real(Y15);
B15 = imag(Y15);
G22 = real(Y22);
B22 = imag(Y22);
G24 = real(Y24);
B24 = imag(Y24);
G25 = real(Y25);
B25 = imag(Y25);
G33 = real(Y33);
B33 = imag(Y33);
G34 = real(Y34);
B34 = imag(Y34);
G44 = real(Y44);
B44 = imag(Y44);
G45 = real(Y45);
B45 = imag(Y45);
G55 = real(Y55);
B55 = imag(Y55);

V1 = 1;
Theta1 = 0; % PQ unknown
P2 = -8;
Q2 = -2.8; % V theta unknown
P3 = 4.4;
V3 = 1.05; % Q theta unknown
P4 = 0; 
Q4 = 0; % V theta unknown
P5 = 0;
Q5 = 0; % V theta unknown

% finding unknowns using fsolve
% x(1) = theta2, x(2) = theta3, x(3) = theta4, x(4) = theta5
% x(5) = V2, x(6) = V4, x(7) = V5

fun = @(x) [
             %V1*V1*G11 + V1*G15*x(7)*cos(theta1 - x(4)) + V1*B15*x(7)*sin(theta1 - x(4));
             %V1*V1(-B11) + V1*x(7)*(G15*sin(theta1 -x(4)) - B15*cos(theta1-x(4)));

             x(5)*x(5)*(G22*cos(x(1)-x(1))) + x(5)*x(6)*(G24*cos(x(1) - x(3)) +B24*sin(x(1) - x(3))) + x(5)*x(7)*(G25*cos(x(1) - x(4)) +B25*sin(x(1) - x(4))) - P2;
             x(5)*x(5)*(-B22) + x(5)*x(6)*(G24*sin(x(1)-x(3)) -B24*cos(x(1)-x(3))) + x(5)*x(7)*(G25*sin(x(1)-x(4)) - B25*cos(x(1) - x(4))) - Q2;

             V3*V3*(G33) + V3*x(6)*(G34*cos(x(2) - x(3)) + B34*sin(x(2) - x(3))) - P3;

             x(6)*x(5)*(G24*cos(x(3)-x(1)) + B24*sin(x(3)-x(1))) + x(6)*V3*(G34*cos(x(3) - x(2)) + B34*sin(x(3)-x(2))) + x(6)*x(6)*G44 + x(6)*x(7)*(G45*cos(x(3) - x(4)) + B45*sin(x(3)-x(4))) - P4;
             x(6)*x(5)*(G24*sin(x(3)-x(1)) - B24*cos(x(3)-x(1))) + x(6)*V3*(G34*sin(x(3) -x(2)) - B34*cos(x(3)-x(2))) + x(6)*x(6)*(-B44) + x(6)*x(7)*(G45*sin(x(3)-x(4)) - B45*cos(x(3)-x(4))) - Q4;   

             x(7)*V1*(G15*cos(x(4)-Theta1) + B15*sin(x(4)-Theta1)) + x(7)*x(5)*(G25*cos(x(4)-x(1)) + B25*sin(x(4)-x(1))) + x(7)*x(6)*(G45*cos(x(4)-x(3)) + B45*sin(x(4)-x(3))) + x(7)*x(7)*G55 - P5;
             x(7)*V1*(G15*sin(x(4)-Theta1) - B15*cos(x(4)-Theta1)) + x(7)*x(5)*(G25*sin(x(4)-x(1)) - B25*cos(x(4)-x(1))) + x(7)*x(6)*(G45*sin(x(4)-x(3)) - B45*cos(x(4)-x(3))) + x(7)*x(7)*(-B55) - Q5;

    ];

% Order: [d2, d3, d4, d5, V2, V4, V5]
x0 = [0, 0, 0, 0, 1.0, 1.0, 1.0];

[sol, fval] = fsolve(fun, x0);

% Unpack results
delta_results = rad2deg(sol(1:4)); % Convert angles to degrees
V_results = [1.0, sol(5), 1.05, sol(6), sol(7)]; % All 5 voltages (including constants)

% Quick Printout
fprintf('\nPower Flow Results:\n');
fprintf('Bus #    Voltage    Phase       PG      QG      PL      QL\n');
fprintf('%3d      %6.3f   %8.3f    %6.3f  %6.3f  %6.3f  %6.3f\n', 1, V_final(1), 0,              P1_calc,  Q1_calc,        0,   0);
fprintf('%3d      %6.3f   %8.3f    %6.3f  %6.3f  %6.3f  %6.3f\n', 2, V_final(2), delta_results(1), 0,        0,              8,   2.8);
fprintf('%3d      %6.3f   %8.3f    %6.3f  %6.3f  %6.3f  %6.3f\n', 3, V_final(3), delta_results(2), P3+0.8,   Q3_calc+0.4,    0.8, 0.4);
fprintf('%3d      %6.3f   %8.3f    %6.3f  %6.3f  %6.3f  %6.3f\n', 4, V_final(4), delta_results(3), 0,        0,              0,   0);
fprintf('%3d      %6.3f   %8.3f    %6.3f  %6.3f  %6.3f  %6.3f\n', 5, V_final(5), delta_results(4), 0,        0,              0,   0);


V_final = [V1; sol(5); V3; sol(6); sol(7)]; % V magnitude at all 5 buses
d_final = [0; sol(1); sol(2); sol(3); sol(4)]; % delta in radians at all 5 buses

P1_calc = V_final(1)^2 * G11 + ...
          V_final(1)*V_final(5)*(G15*cos(d_final(1)-d_final(5)) + B15*sin(d_final(1)-d_final(5)));

Q1_calc = -V_final(1)^2 * B11 + ...
          V_final(1)*V_final(5)*(G15*sin(d_final(1)-d_final(5)) - B15*cos(d_final(1)-d_final(5)));

Q3_calc = -V_final(3)^2 * B33 + ...
          V_final(3)*V_final(4)*(G34*sin(d_final(3)-d_final(4)) - B34*cos(d_final(3)-d_final(4)));

P_gen_total = (P1_calc + 0) + (4.4 + 0.8); % P1 + P3 + P_load3

P_load_total = 8.0 + 0.8 + 0 + 0; % From Table 6.1

% System Losses
P_losses = P_gen_total - P_load_total;

fprintf('Power Balance Check:\n');
fprintf('Total Generation: %.4f pu\n', P_gen_total);
fprintf('Total Load:       %.4f pu\n', P_load_total);
fprintf('System Losses:    %.4f pu\n', P_losses);


P_injections = [P1_calc; P2; P3; P4; P5];
sum_Pi = sum(P_injections);

fprintf('Conservation of Power Check:\n');
fprintf('P generation and demand sum: %.4f pu\n', sum_Pi);
fprintf('Resistive system Losses:     %.4f pu\n', P_losses);
fprintf('Difference:                  %.4e pu\n', sum_Pi - P_losses);