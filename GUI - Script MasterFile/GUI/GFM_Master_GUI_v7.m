function GFM_Master_GUI_v7
% GFM_MASTER_GUI_V7
% Unified front end for:
%   1) Reduced-order MATLAB model
%   2) Detailed Simulink / Simscape models
%
% Put this file in the SAME MATLAB folder as:
%
%   Unified_Weak_Grid_GUIReady_Custom_v2.m
%   GFM_Simulink_Init_GUI_v3.m
%   GFM_Controller_B.slx
%   GFM_Controller_C.slx
%
% Then run:
%   GFM_Master_GUI_v7
%
% Expected To Workspace signals in BOTH Simulink models:
%   P12_GUI
%   Vpcc_GUI
%   Ipcc_GUI
%   Dw_GUI
%
% Recommended Save format: Timeseries
%
% NOTE:
% Custom Simulink Vref steps require Vref_GUI to be connected to the
% voltage-reference input in both Simulink controller models.

baseDir = fileparts(mfilename('fullpath'));

reducedScript = fullfile(baseDir,'Unified_Weak_Grid_GUIReady_Custom_v2.m');
simInitScript = fullfile(baseDir,'GFM_Simulink_Init_GUI_v3.m');

modelBFile = fullfile(baseDir,'GFM_Controller_B.slx');
modelCFile = fullfile(baseDir,'GFM_Controller_C.slx');

%% ============================================================
% MAIN WINDOW
% ============================================================

fig = uifigure( ...
    'Name','GFM Capstone Demonstrator', ...
    'Position',[40 30 1500 900]);

main = uigridlayout(fig,[1 2]);
main.ColumnWidth = {410,'1x'};
main.RowHeight = {'1x'};
main.Padding = [12 12 12 12];
main.ColumnSpacing = 12;

%% ============================================================
% LEFT CONTROL PANEL
% ============================================================

controlPanel = uipanel(main,'Title','Experiment Controls');
controlPanel.Layout.Row = 1;
controlPanel.Layout.Column = 1;

ctrl = uigridlayout(controlPanel,[17 1]);
ctrl.RowHeight = { ...
    22,30, ...  % implementation
    22,30, ...  % controller
    30, ...     % advanced SMSM
    22,30, ...  % test
    0, ...      % custom panel
    30, ...     % limiter
    22,30, ...  % Imax
    72, ...     % reduced-order saturation management
    40, ...     % run
    22, ...     % status heading
    180, ...    % larger results / log
    '1x', ...   % flexible empty space
    32};        % compact clear button
ctrl.Padding = [12 12 12 12];
ctrl.RowSpacing = 7;

uilabel(ctrl, ...
    'Text','Model implementation', ...
    'FontWeight','bold');

fidelityDD = uidropdown(ctrl, ...
    'Items',{'Reduced-order MATLAB model', ...
             'Detailed Simulink / Simscape model'}, ...
    'ItemsData',{'REDUCED','SIMULINK'}, ...
    'Value','REDUCED', ...
    'ValueChangedFcn',@implementationChanged);

uilabel(ctrl, ...
    'Text','Controller', ...
    'FontWeight','bold');

controllerDD = uidropdown(ctrl, ...
    'ValueChangedFcn',@controllerChanged);

advancedSMSMCheck = uicheckbox(ctrl, ...
    'Text','Show advanced AEMO fault tests for synchronous machine', ...
    'Value',false, ...
    'Enable','off', ...
    'Visible','off', ...
    'ValueChangedFcn',@refreshTestList);

uilabel(ctrl, ...
    'Text','Test', ...
    'FontWeight','bold');

testDD = uidropdown(ctrl, ...
    'ValueChangedFcn',@testChanged);

%% ============================================================
% CUSTOM EXPERIMENT PANEL
% ============================================================

customPanel = uipanel(ctrl, ...
    'Title','Custom Experiment', ...
    'Visible','off');

customGrid = uigridlayout(customPanel,[10 2]);
customGrid.ColumnWidth = {155,'1x'};
customGrid.RowHeight = {30,30,30,30,30,30,30,30,30,'1x'};
customGrid.Padding = [8 8 8 8];
customGrid.RowSpacing = 5;

uilabel(customGrid,'Text','Disturbance');
customDisturbanceDD = uidropdown(customGrid, ...
    'Items',{'Active-power step', ...
             'Voltage-reference step', ...
             'Three-phase fault', ...
             'None'}, ...
    'ItemsData',{'PREF','VREF','FAULT','NONE'}, ...
    'Value','FAULT', ...
    'ValueChangedFcn',@customDisturbanceChanged);

uilabel(customGrid,'Text','SCR');
customSCR = uieditfield(customGrid,'numeric', ...
    'Value',3.0, ...
    'Limits',[2 10]);

uilabel(customGrid,'Text','Initial Pref (pu)');
customPrefInitial = uieditfield(customGrid,'numeric', ...
    'Value',1.00, ...
    'Limits',[0.05 1.20]);

uilabel(customGrid,'Text','Final Pref (pu)');
customPrefFinal = uieditfield(customGrid,'numeric', ...
    'Value',0.80, ...
    'Limits',[0.05 1.20]);

uilabel(customGrid,'Text','Final Vref (pu)');
customVrefFinal = uieditfield(customGrid,'numeric', ...
    'Value',1.05, ...
    'Limits',[0.90 1.10]);

uilabel(customGrid,'Text','Event time (s)');
customEventTime = uieditfield(customGrid,'numeric', ...
    'Value',5.00, ...
    'Limits',[1 20]);

uilabel(customGrid,'Text','Fault duration (s)');
customFaultDuration = uieditfield(customGrid,'numeric', ...
    'Value',0.43, ...
    'Limits',[0.05 2.00]);

uilabel(customGrid,'Text','Fault type');
customFaultTypeDD = uidropdown(customGrid, ...
    'Items',{'Near-bolted / solid','Impedance fault'}, ...
    'ItemsData',{'SOLID','IMPEDANCE'}, ...
    'Value','SOLID', ...
    'ValueChangedFcn',@faultTypeChanged);

uilabel(customGrid,'Text','Zf / Zs');
customZfRatio = uieditfield(customGrid,'numeric', ...
    'Value',1.00, ...
    'Limits',[0.05 3.00]);

uilabel(customGrid,'Text','Fault X/R');
customFaultXR = uieditfield(customGrid,'numeric', ...
    'Value',3.0, ...
    'Limits',[0.1 30]);

%% ============================================================
% LIMITER CONTROLS
% ============================================================

limiterCheck = uicheckbox(ctrl, ...
    'Text','Enable current limiter', ...
    'Value',true, ...
    'ValueChangedFcn',@limiterChanged);

uilabel(ctrl, ...
    'Text','Current limit Imax (pu)', ...
    'FontWeight','bold');

imaxField = uieditfield(ctrl,'numeric', ...
    'Value',1.20, ...
    'Limits',[0.20 5.00]);

%% ============================================================
% REDUCED-ORDER LIMITER SATURATION MANAGEMENT
% ============================================================

saturationPanel = uipanel(ctrl, ...
    'Title','Reduced-order limiter saturation management');

satGrid = uigridlayout(saturationPanel,[2 1]);
satGrid.RowHeight = {24,24};
satGrid.Padding = [8 3 8 3];
satGrid.RowSpacing = 2;

activePowerAwarenessCheck = uicheckbox(satGrid, ...
    'Text','Active-power saturation awareness', ...
    'Value',true);

reactiveIntegratorHoldCheck = uicheckbox(satGrid, ...
    'Text','Hold RPC integrator during limiting', ...
    'Value',true);

runButton = uibutton(ctrl,'push', ...
    'Text','RUN EXPERIMENT', ...
    'FontWeight','bold', ...
    'FontSize',14, ...
    'ButtonPushedFcn',@runExperiment);
runButton.Layout.Row = 13;

statusLabel = uilabel(ctrl, ...
    'Text','Simulation status', ...
    'FontWeight','bold');
statusLabel.Layout.Row = 14;

statusArea = uitextarea(ctrl, ...
    'Editable','off', ...
    'FontName','Consolas', ...
    'Value',{ ...
        'Ready.', ...
        'Choose the implementation, controller and test.'});
statusArea.Layout.Row = 15;

bottomSpacer = uilabel(ctrl,'Text','');
bottomSpacer.Layout.Row = 16;

clearButton = uibutton(ctrl,'push', ...
    'Text','Clear plots', ...
    'ButtonPushedFcn',@clearPlots);
clearButton.Layout.Row = 17;

%% ============================================================
% RIGHT RESULTS PANEL
% ============================================================

resultsPanel = uipanel(main,'Title','Simulation Results');
resultsPanel.Layout.Row = 1;
resultsPanel.Layout.Column = 2;

resultsGrid = uigridlayout(resultsPanel,[2 1]);
resultsGrid.RowHeight = {34,'1x'};
resultsGrid.Padding = [8 8 8 8];
resultsGrid.RowSpacing = 4;

resultBanner = uilabel(resultsGrid, ...
    'Text','REDUCED-ORDER MODEL', ...
    'FontWeight','bold', ...
    'FontSize',14, ...
    'HorizontalAlignment','center');

plots = uigridlayout(resultsGrid,[2 2]);
plots.RowHeight = {'1x','1x'};
plots.ColumnWidth = {'1x','1x'};
plots.RowSpacing = 10;
plots.ColumnSpacing = 10;

axP = uiaxes(plots);
title(axP,'Active Power');
xlabel(axP,'Time (s)');
ylabel(axP,'P_{PCC} (pu)');
grid(axP,'on');

axV = uiaxes(plots);
title(axV,'PCC Voltage');
xlabel(axV,'Time (s)');
ylabel(axV,'V_{PCC} (pu)');
grid(axV,'on');

axI = uiaxes(plots);
title(axI,'Inverter / Source Current');
xlabel(axI,'Time (s)');
ylabel(axI,'|I| (pu)');
grid(axI,'on');

axF = uiaxes(plots);
title(axF,'Source Frequency Deviation');
xlabel(axF,'Time (s)');
ylabel(axF,'\Delta f (Hz)');
grid(axF,'on');

%% ============================================================
% INITIALISE GUI
% ============================================================

implementationChanged();
customDisturbanceChanged();
faultTypeChanged();
limiterChanged();

%% ============================================================
% IMPLEMENTATION CHANGED
% ============================================================

    function implementationChanged(~,~)

        oldController = "";

        if ~isempty(controllerDD.Value)
            oldController = string(controllerDD.Value);
        end

        if strcmp(fidelityDD.Value,'REDUCED')

            controllerDD.Items = { ...
                'Controller B (VSG)', ...
                'Controller C (CGVSG)', ...
                'Synchronous Machine'};

            controllerDD.ItemsData = {'B','C','SMSM'};

            if any(oldController == ["B","C","SMSM"])
                controllerDD.Value = char(oldController);
            else
                controllerDD.Value = 'B';
            end

            resultBanner.Text = 'REDUCED-ORDER MATLAB MODEL';

        else

            controllerDD.Items = { ...
                'Controller B (VSG)', ...
                'Controller C (CGVSG)'};

            controllerDD.ItemsData = {'B','C'};

            if any(oldController == ["B","C"])
                controllerDD.Value = char(oldController);
            else
                controllerDD.Value = 'B';
            end

            resultBanner.Text = 'DETAILED SIMULINK / SIMSCAPE MODEL';

        end

        controllerChanged();
        customDisturbanceChanged();

    end

%% ============================================================
% CONTROLLER CHANGED
% ============================================================

    function controllerChanged(~,~)

        isReduced = strcmp(fidelityDD.Value,'REDUCED');
        isSMSM = strcmp(controllerDD.Value,'SMSM');

        if isReduced && isSMSM
            advancedSMSMCheck.Visible = 'on';
            advancedSMSMCheck.Enable = 'on';
            limiterCheck.Value = false;
            limiterCheck.Enable = 'off';
        else
            advancedSMSMCheck.Value = false;
            advancedSMSMCheck.Visible = 'off';
            advancedSMSMCheck.Enable = 'off';
            limiterCheck.Enable = 'on';
        end

        limiterChanged();
        refreshTestList();

    end

%% ============================================================
% REFRESH TEST LIST
% ============================================================

    function refreshTestList(~,~)

        oldTest = "";

        if ~isempty(testDD.Value)
            oldTest = string(testDD.Value);
        end

        isReduced = strcmp(fidelityDD.Value,'REDUCED');
        isSMSM = strcmp(controllerDD.Value,'SMSM');

        if isReduced && isSMSM

            items = {'No disturbance','Custom Experiment'};
            data = {'NONE','CUSTOM'};

            if advancedSMSMCheck.Value
                items = [items, { ...
                    'AEMO 3.2.4 Test 1 - SCR 10', ...
                    'AEMO 3.2.4 Test 4 - SCR 3', ...
                    'AEMO 3.2.4 Test 16 - Zf = Zs'}];

                data = [data, { ...
                    'AEMO324_T1', ...
                    'AEMO324_T4', ...
                    'AEMO324_T16'}];
            end

        else

            items = { ...
                'AEMO 3.2.4 Test 1 - SCR 10', ...
                'AEMO 3.2.4 Test 4 - SCR 3', ...
                'AEMO 3.2.4 Test 16 - Zf = Zs', ...
                'AEMO 3.2.11 Test 168 - Power Tracking', ...
                'Custom Experiment'};

            data = { ...
                'AEMO324_T1', ...
                'AEMO324_T4', ...
                'AEMO324_T16', ...
                'AEMO3211_T168', ...
                'CUSTOM'};
        end

        testDD.Items = items;
        testDD.ItemsData = data;

        if any(strcmp(data,char(oldTest)))
            testDD.Value = char(oldTest);
        else
            if isReduced && isSMSM
                testDD.Value = 'NONE';
            else
                testDD.Value = 'AEMO324_T4';
            end
        end

        testChanged();

    end

%% ============================================================
% TEST CHANGED
% ============================================================

    function testChanged(~,~)

        isCustom = strcmp(testDD.Value,'CUSTOM');

        if isCustom
            customPanel.Visible = 'on';
            ctrl.RowHeight{8} = 350;
        else
            customPanel.Visible = 'off';
            ctrl.RowHeight{8} = 0;
        end

    end

%% ============================================================
% CUSTOM DISTURBANCE CHANGED
% ============================================================

    function customDisturbanceChanged(~,~)

        d = string(customDisturbanceDD.Value);

        customPrefFinal.Enable = 'off';
        customVrefFinal.Enable = 'off';
        customEventTime.Enable = 'off';
        customFaultDuration.Enable = 'off';
        customFaultTypeDD.Enable = 'off';
        customZfRatio.Enable = 'off';
        customFaultXR.Enable = 'off';

        switch d

            case "PREF"
                customPrefFinal.Enable = 'on';
                customEventTime.Enable = 'on';

            case "VREF"
                customVrefFinal.Enable = 'on';
                customEventTime.Enable = 'on';

            case "FAULT"
                customEventTime.Enable = 'on';
                customFaultDuration.Enable = 'on';
                customFaultTypeDD.Enable = 'on';
                faultTypeChanged();

            case "NONE"
                % Nothing else required.

        end

    end

%% ============================================================
% FAULT TYPE CHANGED
% ============================================================

    function faultTypeChanged(~,~)

        isFault = strcmp(customDisturbanceDD.Value,'FAULT');
        isImpedance = strcmp(customFaultTypeDD.Value,'IMPEDANCE');
        isSimulink = strcmp(fidelityDD.Value,'SIMULINK');

        if isFault && isImpedance
            customZfRatio.Enable = 'on';

            % The reduced-order model is reactance-only, therefore the X/R
            % control is meaningful only for the detailed Simulink backend.
            if isSimulink
                customFaultXR.Enable = 'on';
            else
                customFaultXR.Enable = 'off';
            end
        else
            customZfRatio.Enable = 'off';
            customFaultXR.Enable = 'off';
        end

    end

%% ============================================================
% LIMITER CHANGED
% ============================================================

    function limiterChanged(~,~)

        isReduced = strcmp(fidelityDD.Value,'REDUCED');
        isSMSM = strcmp(controllerDD.Value,'SMSM');
        isInverter = ~isSMSM;

        if limiterCheck.Value && isInverter
            imaxField.Enable = 'on';
        else
            imaxField.Enable = 'off';
        end

        % Saturation-management options belong to the reduced-order
        % inverter implementation only. The detailed Simulink models use
        % the limiter / anti-windup logic implemented directly in the .slx.
        showSaturationOptions = isReduced && isInverter;

        if showSaturationOptions
            saturationPanel.Visible = 'on';
            ctrl.RowHeight{12} = 72;

            if limiterCheck.Value
                activePowerAwarenessCheck.Enable = 'on';
                reactiveIntegratorHoldCheck.Enable = 'on';
            else
                activePowerAwarenessCheck.Enable = 'off';
                reactiveIntegratorHoldCheck.Enable = 'off';
            end
        else
            saturationPanel.Visible = 'off';
            ctrl.RowHeight{12} = 0;
        end

    end

%% ============================================================
% RUN EXPERIMENT
% ============================================================

    function runExperiment(~,~)

        runButton.Enable = 'off';
        fidelityDD.Enable = 'off';
        controllerDD.Enable = 'off';
        testDD.Enable = 'off';

        statusLabel.Text = 'Running experiment...';
        statusArea.Value = {'Preparing simulation...'};
        drawnow;

        try

            if strcmp(fidelityDD.Value,'REDUCED')
                Common = runReducedBackend();
            else
                Common = runSimulinkBackend();
            end

            plotCommonResults(Common);
            showSummary(Common);

            statusLabel.Text = 'Simulation complete';

        catch ME

            statusLabel.Text = 'Simulation failed';

            report = getReport(ME,'extended','hyperlinks','off');

            fprintf(2,'\n========== MASTER GUI ERROR ==========\n');
            fprintf(2,'%s\n',report);
            fprintf(2,'======================================\n\n');

            statusArea.Value = cellstr(splitlines(string(report)));

            uialert(fig, ...
                ['Simulation failed. The complete error is shown in the ' ...
                 'status box and MATLAB Command Window.'], ...
                'Simulation Error');

        end

        runButton.Enable = 'on';
        fidelityDD.Enable = 'on';
        controllerDD.Enable = 'on';
        testDD.Enable = 'on';

    end

%% ============================================================
% REDUCED-ORDER BACKEND
% ============================================================

    function Common = runReducedBackend()

        if ~isfile(reducedScript)
            error(['Could not find ' ...
                'Unified_Weak_Grid_GUIReady_Custom_v2.m in the GUI folder.']);
        end

        statusLabel.Text = 'Running reduced-order model...';
        statusArea.Value = {'Running MATLAB reduced-order simulation...'};
        drawnow;

        GUIConfig.ModelSelect = string(controllerDD.Value);
        GUIConfig.TestSelect = string(testDD.Value);

        GUIConfig.LimiterEnable = limiterCheck.Value;
        GUIConfig.Imax = imaxField.Value;

        % Reduced-order limiter saturation / anti-windup management.
        % These are intentionally user-toggleable so the effect of the
        % saturation logic can be demonstrated directly.
        GUIConfig.ActivePowerAwareness = activePowerAwarenessCheck.Value;
        GUIConfig.ReactiveIntegratorHold = reactiveIntegratorHoldCheck.Value;

        GUIConfig.Custom.Disturbance = string(customDisturbanceDD.Value);
        GUIConfig.Custom.SCR = customSCR.Value;
        GUIConfig.Custom.PrefInitial = customPrefInitial.Value;
        GUIConfig.Custom.PrefFinal = customPrefFinal.Value;
        GUIConfig.Custom.VrefFinal = customVrefFinal.Value;
        GUIConfig.Custom.EventTime = customEventTime.Value;
        GUIConfig.Custom.FaultDuration = customFaultDuration.Value;

        % Reduced-order fault is purely reactive.
        % Solid -> numerical near-bolted Xf.
        % Impedance -> map Zf/Zs to Xf = ratio * Xs, with Xs = 1/SCR pu.
        if strcmp(customFaultTypeDD.Value,'SOLID')
            GUIConfig.Custom.FaultXf = 1e-3;
        else
            GUIConfig.Custom.FaultXf = ...
                customZfRatio.Value*(1/customSCR.Value);
        end

        assignin('base','GUIConfig',GUIConfig);
        assignin('base','GUIMasterReducedScript',reducedScript);

        evalin('base','run(GUIMasterReducedScript);');

        R = evalin('base','Results');

        Common = struct();

        Common.Fidelity = "REDUCED";
        Common.Controller = string(R.Model);
        Common.Test = string(R.Test);

        Common.tP = R.t(:);
        Common.P = R.Ppcc(:);
        Common.tPref = R.t(:);
        Common.Pref = R.Pref(:);

        Common.tV = R.t(:);
        Common.V = R.Vpcc(:);

        Common.tI = R.t(:);
        Common.I = R.I(:);

        Common.tF = R.t(:);
        Common.Df = R.SourceDeltaF(:);

        Common.SCR = R.SCR;
        Common.LimiterEnabled = R.CurrentLimiterEnabled;
        Common.Imax = R.CurrentLimit;
        Common.ActivePowerAwareness = activePowerAwarenessCheck.Value;
        Common.ReactiveIntegratorHold = reactiveIntegratorHoldCheck.Value;

        if isfield(R,'EventTimes')
            Common.EventTimes = R.EventTimes;
        else
            Common.EventTimes = [];
        end

        Common.ShowVref = false;
        Common.VrefLabel = "";
        Common.tVref = [];
        Common.Vref = [];

        if isfield(R,'Custom') && ...
                string(R.Custom.Disturbance) == "VREF"

            Common.ShowVref = true;
            Common.tVref = R.t(:);

            if string(R.Model) == "SMSM"

                Vtarget = R.Vpcc(1)*ones(size(R.t(:)));
                Vtarget(R.t(:) >= R.Custom.EventTime) = R.Custom.VrefFinal;

                Common.Vref = Vtarget;
                Common.VrefLabel = "V_{PCC} target";

            else

                Common.Vref = R.Vref(:);
                Common.VrefLabel = "V_{ref} command";

            end
        end

        Common.IsFault = false;
        Common.FaultStart = NaN;
        Common.FaultClear = NaN;
        Common.FaultDuration = NaN;

        if isfield(R,'MaxFaultCurrent')
            Common.IsFault = true;

            if numel(Common.EventTimes) >= 2
                Common.FaultStart = Common.EventTimes(1);
                Common.FaultClear = Common.EventTimes(2);
                Common.FaultDuration = ...
                    Common.FaultClear - Common.FaultStart;
            end
        end

    end

%% ============================================================
% SIMULINK / SIMSCAPE BACKEND
% ============================================================

    function Common = runSimulinkBackend()

        if ~isfile(simInitScript)
            error('Could not find GFM_Simulink_Init_GUI_v3.m in the GUI folder.');
        end

        if strcmp(controllerDD.Value,'B')
            modelFile = modelBFile;
            modelName = 'GFM_Controller_B';
        else
            modelFile = modelCFile;
            modelName = 'GFM_Controller_C';
        end

        if ~isfile(modelFile)
            error('Could not find %s.slx in the GUI folder.',modelName);
        end

        GUIConfig.TestSelect = string(testDD.Value);
        GUIConfig.LimiterEnable = limiterCheck.Value;
        GUIConfig.Imax = imaxField.Value;

        GUIConfig.Custom.Disturbance = string(customDisturbanceDD.Value);
        GUIConfig.Custom.SCR = customSCR.Value;
        GUIConfig.Custom.PrefInitial = customPrefInitial.Value;
        GUIConfig.Custom.PrefFinal = customPrefFinal.Value;
        GUIConfig.Custom.VrefInitial = 1.00;
        GUIConfig.Custom.VrefFinal = customVrefFinal.Value;
        GUIConfig.Custom.EventTime = customEventTime.Value;
        GUIConfig.Custom.FaultDuration = customFaultDuration.Value;
        GUIConfig.Custom.FaultType = string(customFaultTypeDD.Value);
        GUIConfig.Custom.ZfOverZs = customZfRatio.Value;
        GUIConfig.Custom.FaultXR = customFaultXR.Value;

        assignin('base','GUIConfig',GUIConfig);
        assignin('base','GUIMasterSimInit',simInitScript);

        statusLabel.Text = 'Initialising Simulink model...';
        statusArea.Value = {'Preparing detailed Simulink / Simscape model...'};
        drawnow;

        evalin('base','run(GUIMasterSimInit);');

        Tstop = evalin('base','Tstop');
        S = evalin('base','GUIStatus');

        statusLabel.Text = 'Loading Simulink model...';
        drawnow;

        load_system(modelFile);

        % AEMO 3.2.11 Test 168 uses true step changes in Pref.
        % From Workspace defaults to linear interpolation, which turns the
        % command into ramps. Force zero-order hold for Pref_AEMO.
        configureFromWorkspaceZOH(modelName,'Pref_AEMO');

        % Do the same for custom Vref steps if that signal is present.
        configureFromWorkspaceZOH(modelName,'Vref_GUI');

        statusLabel.Text = 'Running Simulink / Simscape...';
        statusArea.Value = { ...
            sprintf('Controller %s',controllerDD.Value), ...
            sprintf('Test: %s',string(S.TestSelect)), ...
            sprintf('Stop time: %.2f s',Tstop), ...
            'Simulation running...'};
        drawnow;

        simOut = sim(modelName, ...
            'StopTime',num2str(Tstop), ...
            'ReturnWorkspaceOutputs','on');

        statusLabel.Text = 'Processing detailed-model results...';
        drawnow;

        Pts = getOutputTimeseries(simOut,'P12_GUI');
        Vts = getOutputTimeseries(simOut,'Vpcc_GUI');
        Its = getOutputTimeseries(simOut,'Ipcc_GUI');
        Dwts = getOutputTimeseries(simOut,'Dw_GUI');

        Common = struct();

        Common.Fidelity = "SIMULINK";
        Common.Controller = string(controllerDD.Value);
        Common.Test = string(S.TestSelect);

        Common.tP = Pts.Time(:);
        Common.P = squeeze(Pts.Data);
        Common.P = Common.P(:);

        PrefTS = evalin('base','Pref_AEMO');
        Common.tPref = PrefTS.Time(:);
        Common.Pref = PrefTS.Data(:);

        Common.tV = Vts.Time(:);
        Common.V = squeeze(Vts.Data);
        Common.V = Common.V(:);

        Common.tI = Its.Time(:);
        Common.I = squeeze(Its.Data);
        Common.I = Common.I(:);

        Common.tF = Dwts.Time(:);
        Common.Df = squeeze(Dwts.Data)/(2*pi);
        Common.Df = Common.Df(:);

        Common.SCR = S.SCR;
        Common.LimiterEnabled = logical(S.LimitEnable);
        Common.Imax = S.Imax;
        Common.ActivePowerAwareness = NaN;
        Common.ReactiveIntegratorHold = NaN;

        Common.EventTimes = [];

        if S.SolidFault || S.RLFault
            Common.EventTimes = [S.FaultStart S.FaultClear];

        elseif string(S.TestSelect) == "CUSTOM" && ...
                any(string(S.CustomDisturbance) == ["PREF","VREF"])

            Common.EventTimes = GUIConfig.Custom.EventTime;

        elseif string(S.TestSelect) == "AEMO3211_T168"
            Common.EventTimes = [5 15 25];
        end

        Common.ShowVref = false;
        Common.VrefLabel = "";
        Common.tVref = [];
        Common.Vref = [];

        if string(S.TestSelect) == "CUSTOM" && ...
                string(S.CustomDisturbance) == "VREF"

            VrefTS = evalin('base','Vref_GUI');

            Common.ShowVref = true;
            Common.tVref = VrefTS.Time(:);
            Common.Vref = VrefTS.Data(:);
            Common.VrefLabel = "V_{ref} command";
        end

        Common.IsFault = logical(S.SolidFault || S.RLFault);
        Common.FaultStart = S.FaultStart;
        Common.FaultClear = S.FaultClear;
        Common.FaultDuration = S.FaultDuration;

    end

%% ============================================================
% READ SIMULINK TO WORKSPACE OUTPUT
% ============================================================

    function ts = getOutputTimeseries(simOut,varName)

        ts = [];

        try
            ts = simOut.get(varName);
        catch
        end

        if isempty(ts)
            try
                ts = simOut.(varName);
            catch
            end
        end

        if isempty(ts)
            try
                ts = evalin('base',varName);
            catch
            end
        end

        if isempty(ts)
            error(['Could not find Simulink output "' varName '". ' ...
                   'Check the To Workspace block variable name.']);
        end

        if isa(ts,'timeseries')
            return;
        end

        if isstruct(ts) && isfield(ts,'time') && isfield(ts,'signals')
            ts = timeseries(ts.signals.values,ts.time);
            return;
        end

        error(['Output "' varName '" is not a timeseries. ' ...
               'Set the To Workspace Save format to Timeseries.']);

    end

%% ============================================================
% FORCE FROM WORKSPACE INPUT TO ZERO-ORDER HOLD
% ============================================================

    function configureFromWorkspaceZOH(modelName,varName)

        blocks = find_system(modelName, ...
            'LookUnderMasks','all', ...
            'FollowLinks','on', ...
            'BlockType','FromWorkspace');

        for k = 1:numel(blocks)

            try
                expr = strtrim(string(get_param(blocks{k},'VariableName')));
            catch
                continue;
            end

            % Match the workspace variable used by the block.
            if expr == string(varName)

                set_param(blocks{k},'Interpolate','off');

                % Keep the last commanded value after the final breakpoint.
                try
                    set_param(blocks{k}, ...
                        'OutputAfterFinalValue','Holding final value');
                catch
                    % Older releases may expose this differently; the key
                    % fix is Interpolate = off.
                end
            end
        end

    end

%% ============================================================
% COMMON PLOTTING
% ============================================================

    function plotCommonResults(C)

        cla(axP);
        cla(axV);
        cla(axI);
        cla(axF);

        % ----- Active power
        plot(axP,C.tP,C.P,'LineWidth',1.6);
        hold(axP,'on');

        if ~isempty(C.Pref)
            stairs(axP,C.tPref,C.Pref,'--','LineWidth',1.2);
            legend(axP,{'P_{PCC}','P_{ref}'},'Location','best');
        else
            legend(axP,{'P_{PCC}'},'Location','best');
        end

        addEventLines(axP,C.EventTimes);
        hold(axP,'off');
        grid(axP,'on');

        % ----- PCC voltage
        plot(axV,C.tV,C.V,'LineWidth',1.6);
        hold(axV,'on');

        if C.ShowVref
            stairs(axV,C.tVref,C.Vref,'--','LineWidth',1.2);
            legend(axV,{'V_{PCC}',char(C.VrefLabel)},'Location','best');
        else
            legend(axV,{'V_{PCC}'},'Location','best');
        end

        addEventLines(axV,C.EventTimes);
        hold(axV,'off');
        grid(axV,'on');

        % ----- Current
        plot(axI,C.tI,C.I,'LineWidth',1.6);
        hold(axI,'on');

        if C.LimiterEnabled
            yline(axI,C.Imax,'--','I_{max}','LineWidth',1.0);
        end

        addEventLines(axI,C.EventTimes);
        hold(axI,'off');
        grid(axI,'on');

        % ----- Frequency deviation
        plot(axF,C.tF,C.Df,'LineWidth',1.6);
        hold(axF,'on');
        yline(axF,0,'--','HandleVisibility','off');
        addEventLines(axF,C.EventTimes);
        hold(axF,'off');
        grid(axF,'on');

        tEnd = max([ ...
            C.tP(end), ...
            C.tV(end), ...
            C.tI(end), ...
            C.tF(end)]);

        xlim(axP,[0 tEnd]);
        xlim(axV,[0 tEnd]);
        xlim(axI,[0 tEnd]);
        xlim(axF,[0 tEnd]);

        linkaxes([axP axV axI axF],'x');

        autoScaleY(axP,[C.P(:); C.Pref(:)],0.08);

        if C.ShowVref
            autoScaleY(axV,[C.V(:); C.Vref(:)],0.08);
        else
            autoScaleY(axV,C.V(:),0.08);
        end

        if C.LimiterEnabled
            autoScaleY(axI,[C.I(:); C.Imax],0.08);
        else
            autoScaleY(axI,C.I(:),0.08);
        end

        autoScaleY(axF,[C.Df(:); 0],0.10);

        if C.Fidelity == "REDUCED"
            resultBanner.Text = sprintf( ...
                'REDUCED-ORDER MATLAB MODEL  |  CONTROLLER %s', ...
                char(C.Controller));
        else
            resultBanner.Text = sprintf( ...
                'DETAILED SIMULINK / SIMSCAPE MODEL  |  CONTROLLER %s', ...
                char(C.Controller));
        end

        drawnow;

    end

%% ============================================================
% SUMMARY
% ============================================================

    function showSummary(C)

        maxI = max(abs(C.I),[],'all');
        maxP = max(C.P,[],'all');
        minV = min(C.V,[],'all');
        maxDf = max(abs(C.Df),[],'all');

        if C.Controller == "B"
            controllerName = 'B (VSG)';
        elseif C.Controller == "C"
            controllerName = 'C (CGVSG)';
        else
            controllerName = 'Synchronous Machine';
        end

        if C.Fidelity == "REDUCED"
            implementationName = 'Reduced-order MATLAB';
        else
            implementationName = 'Detailed Simulink / Simscape';
        end

        testName = getCurrentTestName();

        if C.LimiterEnabled
            limiterText = sprintf('ON   (Imax = %.2f pu)',C.Imax);
        else
            limiterText = 'OFF';
        end

        lines = { ...
            sprintf('Model        %s',implementationName), ...
            sprintf('Controller   %s',controllerName), ...
            sprintf('Test         %s',testName), ...
            sprintf('SCR          %.2f',C.SCR), ...
            sprintf('Limiter      %s',limiterText)};

        if C.Fidelity == "REDUCED" && C.LimiterEnabled
            if C.ActivePowerAwareness
                apText = 'ON';
            else
                apText = 'OFF';
            end

            if C.ReactiveIntegratorHold
                rpcText = 'ON';
            else
                rpcText = 'OFF';
            end

            lines{end+1} = sprintf('P sat aware  %s',apText);
            lines{end+1} = sprintf('RPC hold     %s',rpcText);
        end

        lines{end+1} = sprintf('Max current  %.3f pu',maxI);
        lines{end+1} = sprintf('Max P        %.3f pu',maxP);
        lines{end+1} = sprintf('Min Vpcc     %.3f pu',minV);
        lines{end+1} = sprintf('Max |Df|     %.4f Hz',maxDf);

        if C.IsFault && isfinite(C.FaultStart)
            lines{end+1} = sprintf( ...
                'Fault        %.3f - %.3f s  (%.3f s)', ...
                C.FaultStart,C.FaultClear,C.FaultDuration);
        end

        statusArea.Value = lines;

    end

%% ============================================================
% CURRENT TEST DISPLAY NAME
% ============================================================

    function name = getCurrentTestName()

        idx = find(strcmp(testDD.ItemsData,testDD.Value),1);

        if isempty(idx)
            name = char(string(testDD.Value));
        else
            name = testDD.Items{idx};
        end

    end

%% ============================================================
% EVENT LINES
% ============================================================

    function addEventLines(ax,eventTimes)

        if isempty(eventTimes)
            return;
        end

        for k = 1:numel(eventTimes)
            xline(ax,eventTimes(k),':','HandleVisibility','off');
        end

    end

%% ============================================================
% AUTO Y SCALE
% ============================================================

    function autoScaleY(ax,yData,padFraction)

        yData = yData(isfinite(yData));

        if isempty(yData)
            ylim(ax,'auto');
            return;
        end

        yMin = min(yData);
        yMax = max(yData);
        span = yMax-yMin;

        if span < 1e-12
            reference = max(abs([yMin yMax]));

            if reference < 1e-6
                margin = 0.1;
            else
                margin = max(0.05*reference,1e-3);
            end
        else
            margin = padFraction*span;
        end

        ylim(ax,[yMin-margin yMax+margin]);

    end

%% ============================================================
% CLEAR PLOTS
% ============================================================

    function clearPlots(~,~)

        cla(axP);
        cla(axV);
        cla(axI);
        cla(axF);

        title(axP,'Active Power');
        xlabel(axP,'Time (s)');
        ylabel(axP,'P_{PCC} (pu)');
        grid(axP,'on');

        title(axV,'PCC Voltage');
        xlabel(axV,'Time (s)');
        ylabel(axV,'V_{PCC} (pu)');
        grid(axV,'on');

        title(axI,'Converter / Source Current');
        xlabel(axI,'Time (s)');
        ylabel(axI,'|I| (pu)');
        grid(axI,'on');

        title(axF,'Source Frequency Deviation');
        xlabel(axF,'Time (s)');
        ylabel(axF,'\Delta f (Hz)');
        grid(axF,'on');

        statusLabel.Text = 'Simulation status';
        statusArea.Value = {'Plots cleared. Ready for next experiment.'};

        if strcmp(fidelityDD.Value,'REDUCED')
            resultBanner.Text = 'REDUCED-ORDER MATLAB MODEL';
        else
            resultBanner.Text = 'DETAILED SIMULINK / SIMSCAPE MODEL';
        end

    end

end
