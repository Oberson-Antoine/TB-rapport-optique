close all; clear; clc;
%modifier le path avec celui qui a été réglé dans le GUI
path = "/Users/antoine/Library/CloudStorage/OneDrive-Personal/HEIG/TB/Mesures automatiques/Visualisation Zernicke/mesure_ecran_100sec_rota/";%ne pas oublier le "/" à la fin
all_files = dir("/Users/antoine/Library/CloudStorage/OneDrive-Personal/HEIG/TB/Mesures automatiques/Visualisation Zernicke/mesure_ecran_100sec_rota");
all_names = {all_files(arrayfun(@(x) ~x.isdir, all_files)).name};

%enlève les csv des wavefront 
indicesToDelete = find(~cellfun(@isempty, strfind(all_names, 'Wavefront')));

all_names(indicesToDelete) = [];
indice_Vide = find(~cellfun(@isempty, strfind(all_names, 'ref')));%on trouve la mesure avec "ref" dans son nom


if isempty(indice_Vide) == 0 % si l'indice vide n'est pas vide on sauvegarde les coeff de Zernike de ce dernier
    a_offset = table2array(readtable(path+string(all_names(indice_Vide)),"Range","A2:BN2"));
end

all_names(indice_Vide) = []; %on enlève le a_offset des mesures

aj= zeros([length(all_names),66]); %le tableau qui contient tout les coeffs de Zernike de toutes les mesures
 

for i = 1 : length(all_names)
    aj(i,:)=table2array( readtable(path+string(all_names(i)),"Range","A2:BN2"));
end


%soustraction de l'offset
if isempty(indice_Vide) == 0
    for i = 1 : length(all_names)
        aj(i,:) = aj(i,:)- a_offset(1,:);
    end
end

sigma_aj = var(aj,1);%calcul de la variance de toutes les mesures

Noll = zeros([1,66]);
for i = 1:66
     tmp = indzer(i);
     
     Noll(i) = varianceNoll(tmp(2))^2;
end


%partie où on fit les mesures à la variance de Noll pour D/r0 = 1 pour
%trouver le r0
%à noter on ignore les 3 premier coeffs de Zernike (indépendants de la turbulance)
xfit = (1:66);

ft = fittype("Noll*(0.7/r)^(5/3)",independent = "Noll",dependent = "sigma_aj", coefficients = "r");
p = fit(Noll(4:66)',sigma_aj(4:66)',ft,'start',0.0002)
%fx = linspace(1,66,1000);

sigma_fit = Noll .* (0.7/p.r).^(5/3);%calcul les variances de Noll pour le r_0 calculé

% Define the model function
model_sigma_aj = @(r, Noll) Noll .* (0.7/r).^(5/3);

% Use lsqcurvefit to find the best fit for r
initial_guess = 1; % Initial guess for r
optimal_r = lsqcurvefit(@(r, x) model_sigma_aj(r, x), initial_guess, Noll, sigma_aj);


figure;
hold on ;



%plot(p,xfit(4:66),sigma_fit(4:66));

loglog((1:66),(Noll),'-x');
loglog((1:66),(sigma_aj),'-o');
plot(xfit,sigma_fit);
legend("Variance Noll","Variance mesures","Variance Noll avec r_0 calculé");
xlabel("j");
ylabel("Variance");

set(gca, 'XScale', 'log') % But you can explicitly force it to be logarithmic
set(gca, 'YScale', 'log') % But you can explicitly force it to be logarithmic


hold off;

figure;
histogram(aj)