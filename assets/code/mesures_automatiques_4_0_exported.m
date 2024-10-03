classdef mesures_automatiques_4_0_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        HomingButton                  matlab.ui.control.Button
        SerialmonitorEditField        matlab.ui.control.EditField
        SerialmonitorEditFieldLabel   matlab.ui.control.Label
        TableZernike                  matlab.ui.control.Table
        ConfigurationexpriencePanel   matlab.ui.container.Panel
        GridLayout3                   matlab.ui.container.GridLayout
        MesurenEditField              matlab.ui.control.NumericEditField
        MesurenEditFieldLabel         matlab.ui.control.Label
        NomfichierscsvdefaulttimestampEditField  matlab.ui.control.EditField
        NomfichierscsvdefaulttimestampEditFieldLabel  matlab.ui.control.Label
        NombredemesuresSpinner        matlab.ui.control.Spinner
        NombredemesuresSpinnerLabel   matlab.ui.control.Label
        save_path_field               matlab.ui.control.EditField
        ChemindesauvegardeLabel       matlab.ui.control.Label
        StartExperimentButton         matlab.ui.control.Button
        StopExperimentButton          matlab.ui.control.Button
        ButtonSelPath                 matlab.ui.control.Button
        ConfigurationcamraPanel       matlab.ui.container.Panel
        GridLayout2                   matlab.ui.container.GridLayout
        AutocalibrationButton         matlab.ui.control.Button
        CameraAveragingDropDown       matlab.ui.control.DropDown
        CameraAveragingDropDownLabel  matlab.ui.control.Label
        ConnectCamera                 matlab.ui.control.Button
        CameraportDropDown            matlab.ui.control.DropDown
        CameraportDropDownLabel       matlab.ui.control.Label
        TournerButton                 matlab.ui.control.Button
        ConfigurationarduinoPanel     matlab.ui.container.Panel
        GridLayout                    matlab.ui.container.GridLayout
        Distancedetranslationmm0mmpasdetranslationLabel  matlab.ui.control.Label
        DistanceTranslationSpinner    matlab.ui.control.Spinner
        SpinnerLabel                  matlab.ui.control.Label
        DistancerotationSpinner       matlab.ui.control.Spinner
        DistancerotationSpinnerLabel  matlab.ui.control.Label
        RefreshArduinoCom             matlab.ui.control.Button
        DisconnectButton              matlab.ui.control.Button
        ConnectButton                 matlab.ui.control.Button
        BaudRateDropDown              matlab.ui.control.DropDown
        BaudRateDropDownLabel         matlab.ui.control.Label
        COMportDropDown               matlab.ui.control.DropDown
        COMportDropDownLabel          matlab.ui.control.Label
    end


    % Public properties that correspond to the Simulink model
    properties (Access = public, Transient)
        Simulation simulink.Simulation
    end

    
    properties (Access = private)
        wfs % obparula de camera thorlab
        wfs_format % formattage pour dropdown

        com_ports % obparula des comports
        format_ports %com_ports formatés pour le dropdown

        camera_state = 0 % état de connexion de la caméra
        motor_state =0 % état de connexion du moteur

        serial_ports %c'est la liste de serial détecté si la fonction arduino detect rate
        arduinoObj %c'est le serial object de la board arduino
        
        save_path = pwd() % Le chemin de sauvegarde des fichiers (default dossier courant)

        time % sert à la prise de mesures pour le timer
        Camera_update_timer % sert à lire le plus possible les valeurs de la caméra

        n_exec % compte le nombre de mesures faites 

        nom_data_save % le nom des sauvegarde de données

        polzer_array %ou sont stockés les écrans des différents polynomes de zernike

        Zernike_array % c'est le array qui va stocker les mesures entre les moyennes
        Zernike_index = 1 %c'est l'indice pour remplir le Zernike_array 
        Zernike_mean %C'est la variable qui stock le average calculé des coeffs de Zernike

        compte_update % compte les boucles d'update de la camera
        
        wf_update %c'est la variable qui stock le front d'onde mis à jour chaques secondes
        
        Averaging_num = 0

        Axes

        plot

        numero_Zernike = [1:66]

        

    end
    
    methods (Access = private)
        
        function setAppState(app,state)%change les états des éléments d'interface suivant le status du code
            switch state
                case "DeviceSelection"
                    app.COMportDropDown.Enable = "on";
                    app.BaudRateDropDown.Enable = "on";
                    app.ConnectButton.Enable = "on";
                    app.RefreshArduinoCom.Enable ="on";
                    app.CameraportDropDown.Enable = "on";

                    if app.camera_state == 0
                        app.ConnectCamera.Enable = "on";
                    end

                    app.DisconnectButton.Enable = "off";
                    %app.DistancederotationSlider.Enable = "off";
                    app.DistancerotationSpinner.Enable = "off";
                    app.DistanceTranslationSpinner.Enable = "off";
                    app.TournerButton.Enable = "off";
                    app.ConfigurationexpriencePanel.Visible = "off";
                    app.TableZernike.Visible= "off";
                    app.HomingButton.Enable = "off";
                    
                case "Connected"
                    % Enable everything, disable the "configuration"
                    % options (except for disconnect)
                    app.motor_state = 1;

                    app.DisconnectButton.Enable = "on";
                    app.DistancerotationSpinner.Enable = "on";
                    app.DistanceTranslationSpinner.Enable = "on";
                    app.TournerButton.Enable = "on";
                    app.HomingButton.Enable = "on";

                    app.COMportDropDown.Enable = "off";
                    app.BaudRateDropDown.Enable = "off";
                    app.ConnectButton.Enable = "off";
                    app.RefreshArduinoCom.Enable = "off";



                    
                    if app.camera_state == 1 && app.motor_state == 1
                        app.ConfigurationexpriencePanel.Visible = "on";
                    end
                case "CameraConnected"
                    app.camera_state = 1;
                    
                    app.ConnectCamera.Enable ="off";

                    if app.camera_state == 1 && app.motor_state == 1
                        app.ConfigurationexpriencePanel.Visible = "on";
                    end

                    % Create UIAxes
                    app.Axes = axes(app.UIFigure); 
                    xlabel(app.Axes, 'X')
                    ylabel(app.Axes, 'Y')
                    zlabel(app.Axes, 'Z')
                    axis(app.Axes,'equal');
                    app.Axes.Units = "pixels";
                    app.Axes.Position = [387 83 320 320];
                    title(app.Axes, 'Spotfield')
                    app.Axes.Color = "black";
            

                    app.plot = imagesc(app.Axes,zeros([73,73]));

                    app.TableZernike.Visible= "on";
                    app.CameraAveragingDropDown.Visible = "on";
                    app.AutocalibrationButton.Visible = "on";
                    app.CameraAveragingDropDownLabel.Visible = "on";

                case "Experiment_started"

                    app.StartExperimentButton.Enable = "off";

                    app.StopExperimentButton.Enable = "on";

                    app.AutocalibrationButton.Enable = "off" ;

                    app.CameraAveragingDropDown.Enable = "off";

                case "Experiment_stopped"

                    app.StartExperimentButton.Enable = "on";

                    app.StopExperimentButton.Enable = "off";

                    app.AutocalibrationButton.Enable = "on" ;

                    app.CameraAveragingDropDown.Enable = "on";



            end
        end
        
        function timer_mesureFcn(app,src,event)%fonction appelée par le timer de mesure, pour lancer les mouvements et les mesures du WFS
            stop(app.Camera_update_timer)

            Wavefront = app.wfs.Wavefront;
           
            
            Wavefront_save_name = sprintf("%s\\Wavefront_%s_%d.csv",app.save_path,app.nom_data_save,app.n_exec); %formatte le save path
            Zernike_save_name = sprintf("%s\\Zernike_%s_%d.csv",app.save_path,app.nom_data_save,app.n_exec); %formatte le save path
            
            writetable(struct2table(Wavefront),Wavefront_save_name);%sauve les mesures

            writetable(array2table(app.Zernike_mean),Zernike_save_name);%sauve les mesures
                
                colormap( app.Axes,'parula');
                app.compte_update = 0;

                drawnow limitrate

            steps = string(round(app.DistancerotationSpinner.Value * 2048/360)) ;

            
            steps_translation = string(round(app.DistanceTranslationSpinner.Value/(0.9*pi/180 * 12.94/2)));

            if app.DistanceTranslationSpinner.Value == 0
                write(app.arduinoObj,"0,0,0,"+ steps,"string"); % envoie le nombre de pas à effectuer à l'arduino

            else
                write(app.arduinoObj,"0,1,"+ steps_translation + ","+ steps,"string");
            end

            flush(app.arduinoObj);

            test = readline(app.arduinoObj);
            
            disp(test);
            app.n_exec = app.n_exec + 1 ;
            app.MesurenEditField.Value = app.n_exec;
            
            if app.n_exec >= app.NombredemesuresSpinner.Value % stoppe la prise de mesure après avoir atteint le nombre cible
                app.StopExperimentButtonPushed
            end

            start(app.Camera_update_timer)
        end
        
        function Camera_update_data(app,src,event)
            stop(app.Camera_update_timer);%arrête le timer d'update
            app.wfs.Spotfield_Image;
            Average_ready = app.wfs.Average_Image(app.Averaging_num);

            tmp = app.wfs.Zernike;

            app.Zernike_array(app.Zernike_index,:) = tmp.Zernike;

            app.Zernike_index = app.Zernike_index + 1;


            if Average_ready == 1
                stop(app.Camera_update_timer);
                app.Zernike_index = 1; 

                app.Zernike_mean = mean(app.Zernike_array,1);
                disp(app.Zernike_mean);
                
                app.TableZernike.Data(:,2) = app.Zernike_mean';%calcule la moyenne des n mesures d'average
                app.wf_update = squeeze(sum(reshape(app.Zernike_mean, 66, 1, 1) .* app.polzer_array, 1));              
                
                colormap( app.Axes,'parula');
                app.compte_update = 0;

                set(app.plot,'Cdata',app.wf_update)


                
            end
            start(app.Camera_update_timer);
             
             
        end
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            

            app.compte_update = 0;
            app.polzer_array = importdata("polzer_array.mat");

            app.nom_data_save = string(datetime('now','Format','dd_MM_uuuu')); % c'est le nom par défaut des mesures, la date d'aujourd'hui
            app.NomfichierscsvdefaulttimestampEditField.Value = app.nom_data_save;% display le chemin de sauvegarde dans la boite de l'interface

            app.time = timer("ExecutionMode","fixedRate","BusyMode","queue","Period",12,"TimerFcn",@app.timer_mesureFcn);%crée un callback du timer pour les mesures !
            app.Camera_update_timer = timer("ExecutionMode","fixedRate",'BusyMode','drop',"Period",0.1,"TimerFcn",@app.Camera_update_data); % crée un callback d'un timer pour lire les mesures de la caméra toutes les 0.1 secondes

            app.wfs = thorlabswfs; %liste les caméras
            app.com_ports = arduinolist("Timeout",1);%liste les arduinos
            

            app.wfs_format = string(zeros([size(app.wfs,1),1])); %formatte le wfs pour le display dans le dropdown
                for i=1:length(app.wfs_format)
                    app.wfs_format(i) = sprintf("Port: %s",app.wfs(i).Resource_Name);
                end
            app.CameraportDropDown.Items = app.wfs_format; %mets les valeurs formatées dans le dropdown

            if isempty(app.com_ports) % si on ne trouve pas de arduino on va retourner les ports serial
               app.serial_ports  = serialportlist("available");
               app.COMportDropDown.Items = app.serial_ports; %mets les valeurs formatées dans le dropdown
            else
            %formatte la liste des arduino pour le dropdown
       
                app.format_ports = string(zeros([size(app.com_ports,1),1]));
                for i=1:length(app.format_ports)
                    app.format_ports(i) = sprintf("Port: %s | Board: %s",app.com_ports{i,"Port"},app.com_ports{i,"Board"});
                end
                app.COMportDropDown.Items = app.format_ports; %mets les valeurs formatées dans le dropdown
            end
            
            app.save_path_field.Value = app.save_path;

            app.Averaging_num = str2double(app.CameraAveragingDropDown.Value) 
            app.Zernike_array = zeros([app.Averaging_num,66]);%crée un tableau pour stocker les valeurs intermédiaire des coeffs de Zernike

            setAppState(app,"DeviceSelection"); % actualise l'état des boutons

        end

        % Button pushed function: ConnectButton
        function ConnectButtonPushed(app, event)
            if isempty(app.com_ports) % si les com port sont vide, veut dire qu'on travaille avec un arduino officiel !           
                setAppState(app,"Connected")% actualise les boutons
                app.arduinoObj = serialport(app.COMportDropDown.Value,str2double(app.BaudRateDropDown.Value),"Timeout",20);
            else %sinon on travaille avec un clone il faut donc utiliser d'autres commandes !

                setAppState(app,"Connected")% actualise les boutons 
                try
                    app.arduinoObj = serialport(app.com_ports{app.COMportDropDown.ValueIndex,"Port"} ,str2double(app.BaudRateDropDown.Value),'Timeout',20);
                catch ME
                    uialert(app.UIFigure,ME.message,"Serialport Connection Error",Interpreter="html")
                    setAppState(app,"DeviceSelection");
                    return
                end
            end

            
        end

        % Button pushed function: TournerButton
        function TournerButtonPushed(app, event)

            app.TournerButton.Enable = "off";
            app.SerialmonitorEditField.Value = "...";

            steps = string(round(app.DistancerotationSpinner.Value * 2048/360)) ; %convertis les degrés du spinner en pas
            steps_translation = string(round(app.DistanceTranslationSpinner.Value/(0.9*pi/180 * 12.94/2)));
            disp(steps_translation);
            if app.DistanceTranslationSpinner.Value == 0
                write(app.arduinoObj,"0,0,0,"+ steps,"string"); % envoie le nombre de pas à effectuer à l'arduino

            else
                write(app.arduinoObj,"0,1,"+ steps_translation + ","+ steps,"string");
            end
            flush(app.arduinoObj);

            app.SerialmonitorEditField.Value = readline(app.arduinoObj);
            app.TournerButton.Enable = "on";
        end

        % Button pushed function: DisconnectButton
        function DisconnectButtonPushed(app, event)
            delete(app.arduinoObj);
            app.motor_state = 0;
            app.setAppState("DeviceSelection")
        end

        % Button pushed function: RefreshArduinoCom
        function RefreshArduinoComButtonPushed(app, event)
            app.COMportDropDown.Items = "";
            app.com_ports = arduinolist("Timeout",1);%liste les arduinos

            if isempty(app.com_ports) % si on ne trouve pas de arduino on va retourner les ports serial
               app.serial_ports  = serialportlist("available");
               app.COMportDropDown.Items = app.serial_ports;
            else
            %formatte la liste des arduino pour le dropdown
       
                app.format_ports = string(zeros([size(app.com_ports,1),1]));
                for i=1:length(app.format_ports)
                    app.format_ports(i) = sprintf("Port: %s | Board: %s",app.com_ports{i,"Port"},app.com_ports{i,"Board"});
                end
                app.COMportDropDown.Items = app.format_ports;
            end
            
            setAppState(app,"DeviceSelection");
        end

        % Button pushed function: ConnectCamera
        function ConnectCameraButtonPushed(app, event)
            app.wfs.connect(app.wfs(app.CameraportDropDown.ValueIndex).Resource_Name); % on se connecte à la caméra

            app.wfs.configureDevice(0); % configure l'array de lentilles
            app.wfs.setTrigger(3);

            
            app.wfs.Cancel_Wavefront_Tilt = 1; % Flag to cancel average wavefront tip and tilt during calculations 
            app.wfs.setReferencePlane(0) % règle le plan de référence sur celui fait par l'utilisateur
            app.wfs.Dynamic_Noise_Cut = 1; %active la suppression du bruit dynamique
            app.wfs.Pupil = [0.050,-0.100,8.000,8.000]; % set the Beam Pupil position [-0.5;-2.0] in mm and Beam Pupil Size [1.1;1.6] in mm
            app.wfs.Black_Level_Offset = 50; % Set/get the black offset value of the WFS camera. A higher black level will increase the intensity level of a dark camera image.
            app.wfs.adjustImageBrightness % call autoadjustment routine to set Camera Exposure and Gain
            app.wfs.Zernike_Order = 10; % règle l'ordre des coeff de Zernike à 10 (= 66 coeffs)
            app.wfs.setAoi = [0,0,11.264,11.264]; % règle la zone d'intéret du capteur = où on fait les mesures (centre : 0,0, diamètre x,y = 11.264)
            app.wfs.getAoi();

            

            app.wfs.Beam_Centroid       % get 1x4 vector [ctrX, ctrY, diaX, diaY] with Beam Centroid position [X, Y] in mm and Beam diameter [X, Y] in mm

            %formatte les nombres de 1à66 en string
            txt = zeros(1,66);
            for i = 1:66
                txt(i) = sprintf("%g",app.numero_Zernike(i));
            end
            
           
            app.TableZernike.Data(:,1) = txt; %initialise les numéros des coeff de Zernike
            app.TableZernike.ColumnFormat = {'char','numeric'}; %paramètre les formats des cases de la table

            setAppState(app,"CameraConnected");
            stop(app.Camera_update_timer);
            app.Camera_update_timer.period = 0.1;
            app.Camera_update_timer.StartDelay = 0.1;
            %start(app.Camera_update_timer);
            start(app.Camera_update_timer); % on commence à update / lire les datas en arrière plan 
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if app.camera_state == 1
                app.wfs.disconnect
            end
            stop(app.time)
            stop(app.Camera_update_timer)
            delete(app.Camera_update_timer)
            delete(app.time)
            delete(app)
            
            
        end

        % Button pushed function: ButtonSelPath
        function ButtonSelPathPushed(app, event)
            app.save_path = uigetdir();
            if app.save_path ~= 0
                app.save_path_field.Value = app.save_path;
            end
        end

        % Button pushed function: StartExperimentButton
        function StartExperimentButtonPushed(app, event)
            app.n_exec = 0 ;

            setAppState(app,"Experiment_started");
            
            start(app.time); %démarre le timer pour faire les mesures automatiques
        end

        % Button pushed function: StopExperimentButton
        function StopExperimentButtonPushed(app, event)
            setAppState(app,"Experiment_stopped");
            stop(app.time); %stoppe le timer pour faire les mesures automatiques
        end

        % Value changed function: NomfichierscsvdefaulttimestampEditField
        function NomfichierscsvdefaulttimestampEditFieldValueChanged(app, event)
            app.nom_data_save = app.NomfichierscsvdefaulttimestampEditField.Value;
            
        end

        % Button pushed function: AutocalibrationButton
        function AutocalibrationButtonPushed(app, event)
            stop(app.Camera_update_timer);
            app.wfs.adjustImageBrightness
            start(app.Camera_update_timer)
        end

        % Value changed function: CameraAveragingDropDown
        function CameraAveragingDropDownValueChanged(app, event)
            stop(app.Camera_update_timer);

            app.Averaging_num = str2double(app.CameraAveragingDropDown.Value);
            app.wfs.setAveraging(app.Averaging_num);

            start(app.Camera_update_timer);
            

        end

        % Button pushed function: HomingButton
        function HomingButtonPushed(app, event)
            app.HomingButton.Enable = "off";
            write(app.arduinoObj,"1,1,0,0","string"); % envoie la trame correspondant au homing
            app.HomingButton.Enable = "on";
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 978 678];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Resize = 'off';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create ConfigurationarduinoPanel
            app.ConfigurationarduinoPanel = uipanel(app.UIFigure);
            app.ConfigurationarduinoPanel.AutoResizeChildren = 'off';
            app.ConfigurationarduinoPanel.Title = 'Configuration arduino';
            app.ConfigurationarduinoPanel.Position = [11 426 393 243];

            % Create GridLayout
            app.GridLayout = uigridlayout(app.ConfigurationarduinoPanel);
            app.GridLayout.ColumnWidth = {'1x', '1x', 37};
            app.GridLayout.RowHeight = {'1x', '1x', '1x', '1x', 'fit'};

            % Create COMportDropDownLabel
            app.COMportDropDownLabel = uilabel(app.GridLayout);
            app.COMportDropDownLabel.Layout.Row = 1;
            app.COMportDropDownLabel.Layout.Column = 1;
            app.COMportDropDownLabel.Text = 'COM port';

            % Create COMportDropDown
            app.COMportDropDown = uidropdown(app.GridLayout);
            app.COMportDropDown.Items = {};
            app.COMportDropDown.Placeholder = 'Select';
            app.COMportDropDown.Layout.Row = 1;
            app.COMportDropDown.Layout.Column = 2;
            app.COMportDropDown.Value = {};

            % Create BaudRateDropDownLabel
            app.BaudRateDropDownLabel = uilabel(app.GridLayout);
            app.BaudRateDropDownLabel.Layout.Row = 2;
            app.BaudRateDropDownLabel.Layout.Column = 1;
            app.BaudRateDropDownLabel.Text = 'Baud Rate';

            % Create BaudRateDropDown
            app.BaudRateDropDown = uidropdown(app.GridLayout);
            app.BaudRateDropDown.Items = {'115200'};
            app.BaudRateDropDown.Layout.Row = 2;
            app.BaudRateDropDown.Layout.Column = 2;
            app.BaudRateDropDown.Value = '115200';

            % Create ConnectButton
            app.ConnectButton = uibutton(app.GridLayout, 'push');
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.ConnectButton.Layout.Row = 3;
            app.ConnectButton.Layout.Column = 1;
            app.ConnectButton.Text = 'Connect';

            % Create DisconnectButton
            app.DisconnectButton = uibutton(app.GridLayout, 'push');
            app.DisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @DisconnectButtonPushed, true);
            app.DisconnectButton.Interruptible = 'off';
            app.DisconnectButton.Enable = 'off';
            app.DisconnectButton.Layout.Row = 3;
            app.DisconnectButton.Layout.Column = 2;
            app.DisconnectButton.Text = 'Disconnect';

            % Create RefreshArduinoCom
            app.RefreshArduinoCom = uibutton(app.GridLayout, 'push');
            app.RefreshArduinoCom.ButtonPushedFcn = createCallbackFcn(app, @RefreshArduinoComButtonPushed, true);
            app.RefreshArduinoCom.Icon = fullfile(pathToMLAPP, 'icons', 'refresh_icon.png');
            app.RefreshArduinoCom.IconAlignment = 'center';
            app.RefreshArduinoCom.Layout.Row = 1;
            app.RefreshArduinoCom.Layout.Column = 3;
            app.RefreshArduinoCom.Text = '';

            % Create DistancerotationSpinnerLabel
            app.DistancerotationSpinnerLabel = uilabel(app.GridLayout);
            app.DistancerotationSpinnerLabel.HorizontalAlignment = 'center';
            app.DistancerotationSpinnerLabel.Layout.Row = 4;
            app.DistancerotationSpinnerLabel.Layout.Column = 1;
            app.DistancerotationSpinnerLabel.Text = 'Distance rotation [°]';

            % Create DistancerotationSpinner
            app.DistancerotationSpinner = uispinner(app.GridLayout);
            app.DistancerotationSpinner.Step = 0.176;
            app.DistancerotationSpinner.Limits = [0.2 360];
            app.DistancerotationSpinner.Enable = 'off';
            app.DistancerotationSpinner.Layout.Row = 4;
            app.DistancerotationSpinner.Layout.Column = 2;
            app.DistancerotationSpinner.Value = 0.2;

            % Create SpinnerLabel
            app.SpinnerLabel = uilabel(app.GridLayout);
            app.SpinnerLabel.HorizontalAlignment = 'right';
            app.SpinnerLabel.Visible = 'off';
            app.SpinnerLabel.Layout.Row = 5;
            app.SpinnerLabel.Layout.Column = 1;
            app.SpinnerLabel.Text = '';

            % Create DistanceTranslationSpinner
            app.DistanceTranslationSpinner = uispinner(app.GridLayout);
            app.DistanceTranslationSpinner.Step = 0.10163052234363;
            app.DistanceTranslationSpinner.Limits = [0 40];
            app.DistanceTranslationSpinner.Enable = 'off';
            app.DistanceTranslationSpinner.Layout.Row = 5;
            app.DistanceTranslationSpinner.Layout.Column = 2;

            % Create Distancedetranslationmm0mmpasdetranslationLabel
            app.Distancedetranslationmm0mmpasdetranslationLabel = uilabel(app.GridLayout);
            app.Distancedetranslationmm0mmpasdetranslationLabel.HorizontalAlignment = 'center';
            app.Distancedetranslationmm0mmpasdetranslationLabel.Layout.Row = 5;
            app.Distancedetranslationmm0mmpasdetranslationLabel.Layout.Column = 1;
            app.Distancedetranslationmm0mmpasdetranslationLabel.Text = {'Distance de translation [mm]'; ''; '(0mm = pas de translation)'};

            % Create TournerButton
            app.TournerButton = uibutton(app.UIFigure, 'push');
            app.TournerButton.ButtonPushedFcn = createCallbackFcn(app, @TournerButtonPushed, true);
            app.TournerButton.Position = [11 329 100 23];
            app.TournerButton.Text = 'Tourner';

            % Create ConfigurationcamraPanel
            app.ConfigurationcamraPanel = uipanel(app.UIFigure);
            app.ConfigurationcamraPanel.AutoResizeChildren = 'off';
            app.ConfigurationcamraPanel.Title = 'Configuration caméra';
            app.ConfigurationcamraPanel.Position = [403 506 260 163];

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ConfigurationcamraPanel);
            app.GridLayout2.RowHeight = {'1x', '1x', '1x', '1x'};

            % Create CameraportDropDownLabel
            app.CameraportDropDownLabel = uilabel(app.GridLayout2);
            app.CameraportDropDownLabel.Layout.Row = 1;
            app.CameraportDropDownLabel.Layout.Column = 1;
            app.CameraportDropDownLabel.Text = 'Camera port';

            % Create CameraportDropDown
            app.CameraportDropDown = uidropdown(app.GridLayout2);
            app.CameraportDropDown.Items = {};
            app.CameraportDropDown.Placeholder = 'Select';
            app.CameraportDropDown.Layout.Row = 1;
            app.CameraportDropDown.Layout.Column = 2;
            app.CameraportDropDown.Value = {};

            % Create ConnectCamera
            app.ConnectCamera = uibutton(app.GridLayout2, 'push');
            app.ConnectCamera.ButtonPushedFcn = createCallbackFcn(app, @ConnectCameraButtonPushed, true);
            app.ConnectCamera.Enable = 'off';
            app.ConnectCamera.Layout.Row = 2;
            app.ConnectCamera.Layout.Column = 1;
            app.ConnectCamera.Text = 'Connect';

            % Create CameraAveragingDropDownLabel
            app.CameraAveragingDropDownLabel = uilabel(app.GridLayout2);
            app.CameraAveragingDropDownLabel.Visible = 'off';
            app.CameraAveragingDropDownLabel.Layout.Row = 3;
            app.CameraAveragingDropDownLabel.Layout.Column = 1;
            app.CameraAveragingDropDownLabel.Text = 'Camera Averaging';

            % Create CameraAveragingDropDown
            app.CameraAveragingDropDown = uidropdown(app.GridLayout2);
            app.CameraAveragingDropDown.Items = {'3', '10', '30', '50', '100'};
            app.CameraAveragingDropDown.ValueChangedFcn = createCallbackFcn(app, @CameraAveragingDropDownValueChanged, true);
            app.CameraAveragingDropDown.Visible = 'off';
            app.CameraAveragingDropDown.Layout.Row = 3;
            app.CameraAveragingDropDown.Layout.Column = 2;
            app.CameraAveragingDropDown.Value = '10';

            % Create AutocalibrationButton
            app.AutocalibrationButton = uibutton(app.GridLayout2, 'push');
            app.AutocalibrationButton.ButtonPushedFcn = createCallbackFcn(app, @AutocalibrationButtonPushed, true);
            app.AutocalibrationButton.Visible = 'off';
            app.AutocalibrationButton.Layout.Row = 4;
            app.AutocalibrationButton.Layout.Column = [1 2];
            app.AutocalibrationButton.Text = 'Auto-calibration';

            % Create ConfigurationexpriencePanel
            app.ConfigurationexpriencePanel = uipanel(app.UIFigure);
            app.ConfigurationexpriencePanel.AutoResizeChildren = 'off';
            app.ConfigurationexpriencePanel.Title = 'Configuration expérience';
            app.ConfigurationexpriencePanel.Position = [12 76 316 233];

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.ConfigurationexpriencePanel);
            app.GridLayout3.ColumnWidth = {27, 32, 68, '1x', 98, 22};
            app.GridLayout3.RowHeight = {27, 25, 30, 23, '1x'};
            app.GridLayout3.ColumnSpacing = 4.14285714285714;
            app.GridLayout3.RowSpacing = 14.6;
            app.GridLayout3.Padding = [4.14285714285714 14.6 4.14285714285714 14.6];

            % Create ButtonSelPath
            app.ButtonSelPath = uibutton(app.GridLayout3, 'push');
            app.ButtonSelPath.ButtonPushedFcn = createCallbackFcn(app, @ButtonSelPathPushed, true);
            app.ButtonSelPath.Icon = fullfile(pathToMLAPP, 'icons', 'app_folder_icon.png');
            app.ButtonSelPath.Layout.Row = 1;
            app.ButtonSelPath.Layout.Column = 6;
            app.ButtonSelPath.Text = '';

            % Create StopExperimentButton
            app.StopExperimentButton = uibutton(app.GridLayout3, 'push');
            app.StopExperimentButton.ButtonPushedFcn = createCallbackFcn(app, @StopExperimentButtonPushed, true);
            app.StopExperimentButton.Enable = 'off';
            app.StopExperimentButton.Layout.Row = 4;
            app.StopExperimentButton.Layout.Column = [5 6];
            app.StopExperimentButton.Text = 'Stop';

            % Create StartExperimentButton
            app.StartExperimentButton = uibutton(app.GridLayout3, 'push');
            app.StartExperimentButton.ButtonPushedFcn = createCallbackFcn(app, @StartExperimentButtonPushed, true);
            app.StartExperimentButton.Layout.Row = 4;
            app.StartExperimentButton.Layout.Column = [2 3];
            app.StartExperimentButton.Text = 'Start';

            % Create ChemindesauvegardeLabel
            app.ChemindesauvegardeLabel = uilabel(app.GridLayout3);
            app.ChemindesauvegardeLabel.Layout.Row = 1;
            app.ChemindesauvegardeLabel.Layout.Column = [1 3];
            app.ChemindesauvegardeLabel.Text = 'Chemin de sauvegarde';

            % Create save_path_field
            app.save_path_field = uieditfield(app.GridLayout3, 'text');
            app.save_path_field.Editable = 'off';
            app.save_path_field.Layout.Row = 1;
            app.save_path_field.Layout.Column = [4 5];

            % Create NombredemesuresSpinnerLabel
            app.NombredemesuresSpinnerLabel = uilabel(app.GridLayout3);
            app.NombredemesuresSpinnerLabel.Layout.Row = 2;
            app.NombredemesuresSpinnerLabel.Layout.Column = [1 3];
            app.NombredemesuresSpinnerLabel.Text = 'Nombre de mesures';

            % Create NombredemesuresSpinner
            app.NombredemesuresSpinner = uispinner(app.GridLayout3);
            app.NombredemesuresSpinner.Limits = [1 Inf];
            app.NombredemesuresSpinner.Layout.Row = 2;
            app.NombredemesuresSpinner.Layout.Column = [4 6];
            app.NombredemesuresSpinner.Value = 1;

            % Create NomfichierscsvdefaulttimestampEditFieldLabel
            app.NomfichierscsvdefaulttimestampEditFieldLabel = uilabel(app.GridLayout3);
            app.NomfichierscsvdefaulttimestampEditFieldLabel.WordWrap = 'on';
            app.NomfichierscsvdefaulttimestampEditFieldLabel.Layout.Row = 3;
            app.NomfichierscsvdefaulttimestampEditFieldLabel.Layout.Column = [1 3];
            app.NomfichierscsvdefaulttimestampEditFieldLabel.Text = 'Nom fichiers .csv (default timestamp)';

            % Create NomfichierscsvdefaulttimestampEditField
            app.NomfichierscsvdefaulttimestampEditField = uieditfield(app.GridLayout3, 'text');
            app.NomfichierscsvdefaulttimestampEditField.ValueChangedFcn = createCallbackFcn(app, @NomfichierscsvdefaulttimestampEditFieldValueChanged, true);
            app.NomfichierscsvdefaulttimestampEditField.Layout.Row = 3;
            app.NomfichierscsvdefaulttimestampEditField.Layout.Column = [4 6];

            % Create MesurenEditFieldLabel
            app.MesurenEditFieldLabel = uilabel(app.GridLayout3);
            app.MesurenEditFieldLabel.HorizontalAlignment = 'right';
            app.MesurenEditFieldLabel.Layout.Row = 5;
            app.MesurenEditFieldLabel.Layout.Column = [1 2];
            app.MesurenEditFieldLabel.Text = 'Mesure n°';

            % Create MesurenEditField
            app.MesurenEditField = uieditfield(app.GridLayout3, 'numeric');
            app.MesurenEditField.HorizontalAlignment = 'center';
            app.MesurenEditField.Layout.Row = 5;
            app.MesurenEditField.Layout.Column = 3;

            % Create TableZernike
            app.TableZernike = uitable(app.UIFigure);
            app.TableZernike.ColumnName = {'Zernike N°'; 'Valeur'};
            app.TableZernike.ColumnWidth = {'fit'};
            app.TableZernike.RowName = {};
            app.TableZernike.Visible = 'off';
            app.TableZernike.FontSize = 10;
            app.TableZernike.Position = [780 59 189 517];

            % Create SerialmonitorEditFieldLabel
            app.SerialmonitorEditFieldLabel = uilabel(app.UIFigure);
            app.SerialmonitorEditFieldLabel.HorizontalAlignment = 'right';
            app.SerialmonitorEditFieldLabel.Position = [138 329 79 22];
            app.SerialmonitorEditFieldLabel.Text = 'Serial monitor';

            % Create SerialmonitorEditField
            app.SerialmonitorEditField = uieditfield(app.UIFigure, 'text');
            app.SerialmonitorEditField.Position = [242 329 100 22];

            % Create HomingButton
            app.HomingButton = uibutton(app.UIFigure, 'push');
            app.HomingButton.ButtonPushedFcn = createCallbackFcn(app, @HomingButtonPushed, true);
            app.HomingButton.Position = [11 362 100 23];
            app.HomingButton.Text = 'Homing';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = mesures_automatiques_4_0_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end