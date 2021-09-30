% The COBRAToolbox: testPanModels.m
%
% Purpose:
%     - tests that pan-species models generated by the createPanModels
%     function can produce biomass and produce reasonable amounts of ATP
%
% Author:
%     - Almut Heinken - September 2021
%
% Note:
%     - The solver libraries must be included separately

% initialize the test
fileDir = fileparts(which('testCreatePanModels'));
cd(fileDir);

% load the AGORA models
websave('AGORA-master.zip','https://github.com/VirtualMetabolicHuman/AGORA/archive/master.zip')
try
    unzip('AGORA-master')
end
modPath = [pwd filesep 'AGORA-master' filesep 'CurrentVersion' filesep 'AGORA_1_03' filesep' 'AGORA_1_03_mat'];

numWorkers=4;

% create the pan-models on species level
panPath=[pwd filesep 'panSpeciesModels'];

createPanModels(modPath,panPath,'Species',numWorkers);

% test that pan-models can grow
[notGrowing,Biomass_fluxes] = plotBiomassTestResults(panPath, 'pan-models','numWorkers',numWorkers);
assert(isempty(notGrowing))

% test that ATP production is not too high
[tooHighATP,ATP_fluxes] = plotATPTestResults(panPath, 'pan-models','numWorkers',numWorkers);
assert(max(cell2mat(ATP_fluxes(2:end,2))) < 200)
assert(max(cell2mat(ATP_fluxes(2:end,3))) < 150)

% create the pan-models on genus level
panPath=[pwd filesep 'panGenusModels'];

createPanModels(modPath,panPath,'Genus',numWorkers);

% test that pan-models can grow
[notGrowing,Biomass_fluxes] = plotBiomassTestResults(panPath, 'pan-models','numWorkers',numWorkers);
assert(isempty(notGrowing))

% test that ATP production is not too high
[tooHighATP,ATP_fluxes] = plotATPTestResults(panPath, 'pan-models','numWorkers',numWorkers);
assert(max(cell2mat(ATP_fluxes(2:end,2))) < 250)
assert(max(cell2mat(ATP_fluxes(2:end,3))) < 200)
