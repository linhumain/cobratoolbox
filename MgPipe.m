%MgPipe is a MATLAB based pipeline to integrate microbial abundances 
%(coming from metagenomic data) with constraint based modeling, creating 
%individuals' personalized models.
%The pipeline is divided in 3 parts:
%[PART 1] Analysis of individuals' specific microbes abundances are computed.
%[PART 2]: 1 Constructing a global metabolic model (setup) containing all the 
%microbes listed in the study. 2 Building individuals' specific models 
%integrating abundance data retrieved from metagenomics. For each organism,
%reactions are coupled to the objective function.
%[PART 3] Simulations under different diet regimes.
%MgPipe was created (and tested) for AGORA 1.0 please first download AGORA 
%version 1.0 from https://vmh.uni.lu/#downloadview and place the mat files 
%into a folder.

% Federico Baldini, 2017-2018


%%
%Start warning section -> Please don't modify this section !
if compMod == 1
    warning('compatibility mode activated. Output will also be saved in .csv / .sbml format. Time of computations will be affected.')    
else
    warning('pipeline output will be saved in .mat format. Please enable compomod option if you wish to activate compatibility mode.')
end

if nWok<2
   warning('apparently you disabled parallel mode to enable sequential one. Computations might become very slow. Please modify nwok option.')
end
if patStat==0
    disp('Individuals health status not declared. Analysis will ignore that.')
end
%end of warning section
%%
%Automatic detection of number of samples in the study 

[patNumb,sampName,strains]=getIndividualSizeName(infoPath,'normCoverage.csv');

%Auto load for PART1 -> if PART1 was already computed and is alreday
%present in results folder its execution is skipped else its execution starts

resPathc=resPath(1:(length(resPath)-1));
cd(resPathc);
fnames = dir('*.mat');
numfids = length(fnames);
vals = cell(1,numfids);
   for K = 1:numfids
       vals{K} = fnames(K).name;
   end
vals=vals';
mapP = strmatch('mapInfo.mat', vals, 'exact');

 %[PART 1] 
%Genomic Analysis Section -> processing mapping information
if isempty(mapP)
autostat=0;

%Loading names of models not present in the study but in folder: the vector
%containing the name is called extrastrains

modPathc=modPath(1:(length(modPath)-1));
cd(modPathc)
fnames = dir('*.mat');
numfids = length(fnames);
vals = cell(1,numfids);
for K = 1:numfids
   vals{K} = fnames(K).name;
end
vals=vals';
extrastrains=strtok(vals(:,1),'.'); 

%Loading all the models and putting them into a vector

models={[]}; %empty cell array to be filled with models 
 for i = 1:length(strains)
    %reading the models   
    pn=strcat(modPath,strains(i,1),{'.mat'});%complete path from which to read the model  
    cpn=char(pn);%conversion of the path in character
    ldm=load(cpn);
    ldm=ldm.model;
    %creating array with models as required as input from the later functions 
    models(i,1)={ldm};
 end


[reac,micRea,binOrg,patOrg,reacPat,reacNumb,reacSet,reacTab,reacAbun,reacNumber]=getMappingInfo(models,infoPath,'normCoverage.csv',patNumb)
writetable(cell2table(reacAbun),strcat(resPath,'reactions.csv'))

% Genomic Analysis section ->  Plotting section
[PCoA]=plotMappingInfo(resPath,patOrg,reacPat,reacTab,reacNumber,patStat,figForm) 

if compMod==1
   mkdir(strcat(resPath,'compfile'))
   csvwrite(strcat(resPath,'compfile/reacTab.csv'),reacTab)
   writetable(cell2table(reacSet),strcat(resPath,'compfile/reacset.csv'))
   csvwrite(strcat(resPath,'compfile/reacNumb.csv'),reacNumb)
   csvwrite(strcat(resPath,'compfile/ReacPat.csv'),reacPat)
   csvwrite(strcat(resPath,'compfile/PCoA_tab.csv'),Y)
end

%Save all the created variables
save(strcat(resPath,'mapInfo.mat'))
else
    s= 'mapping file found: loading from resPath and skipping [PART1] analysis';
    disp(s)
    load(strcat(resPath,'mapInfo.mat'))
end
%end of trigger for Autoload
%% %% [PART 2.1]


%Importing names of models from reformatted coverages files
orglist=strains;

%Autofix part 
%Checking consistence of inputs: if autofix == 0 halts execution with error 
%msg if inconsistences are detected, otherwise it really tries hard to fix 
%the problem and continues execution when possible. 

if autoFix == 0

    for i=1:length(orglist)
    check=strmatch(orglist(i,1),orglist);
        if length(check) > 1
        vecErr=orglist(check)
        msg = 'Nomenclature error: one or more organisms have ambiguous ID. Ambiguity indexes stored in check vector';
        error(msg)
        end
    end
else
    for i=1:length(orglist)
    check=strmatch(orglist(i,1),orglist);
        if length(check) > 1
        vecErr=orglist(check)
        %Autodebug, suffix '_extended' is added to solve ambiguity: 
        orglist(i)
        fixVec(i)=orglist(i)
        fixNam= strcat(orglist(i),'_extended')
        orglist(i)=fixNam
        autostat=1
        end
    end
        
%Second cycle: checking multiple times is always better idea 
    for i=1:length(orglist)
    check=strmatch(orglist(i,1),orglist);
        if length(check) > 1
        vecErr=orglist(check)
        msg = 'Nomenclature error: one or more organisms have ambiguous ID. Ambiguity indexes stored in check vector';
        error(msg)
        end
    end
end
%end of Autofix part

%Auto load for PART2.1 -> if PART2.1 was already computed and is alreday
%present in results folder its execution is skipped else its execution starts
resPathc=resPath(1:(length(resPath)-1));
cd(resPathc);
fnames = dir('*.mat');
numfids = length(fnames);
vals = cell(1,numfids);
    for K = 1:numfids
        vals{K} = fnames(K).name;
    end
vals=vals';
extrastrains=strtok(vals(:,1),'.');
mapP = strmatch('Setup_allbacs.mat', vals, 'exact');
if isempty(mapP)
    modbuild = 1;
else
    modbuild = 0;
    s= 'global setup file found: loading from resPath and skipping [PART2.1] analysis';
    disp(s)
end
%end of trigger for Autoload

if modbuild == 1
%Preparing models (removing constrains) and inserting models in an array
   models={[]}; %empty cell array to be filled with models 
   parfor i = 1:length(strains)
       %reading the models   
       pn=strcat(modPath,strains(i,1),{'.mat'});%complete path from which to read the models  
       cpn=char(pn);%conversion of the path in character
       ldm=load(cpn);
       ldm=ldm.model;
       %removing possible constraints of the bacs
       [selExc,selUpt] = findExcRxns(ldm);
       Reactions2 = ldm.rxns(find(selExc));
       allex=Reactions2(strmatch('EX',Reactions2));
       biomass=allex(strmatch(objre,allex));
       finrex=setdiff(allex,biomass);
       ldm = changeRxnBounds(ldm, finrex, -1000,'l');
       %creating array with models as required as input from the following functions 
       models(i,1)={ldm};
   end

   %Creating global model -> setup creator will be called
   setup=fastSetupCreator(models, orglist, {})
   setup.name='Global reconstruction with lumen / fecal compartments no host'
   setup.recon=0
   save(strcat(resPath,'Setup_allbacs.mat'), 'setup')
end

if modbuild==0
load(strcat(resPath,'Setup_allbacs.mat')) 
end
% [PART 2.2]

%Create microbiota models -> Integrate metagenomic data to create individualized models 

[createdModels]=createPersonalizedModel(infoPath,resPath,setup,sampName,orglist,patNumb)

%%
%[PART 3]
disp('Framework for fecal diet compartments microbiota model in use')

[ID,fvaCt,nsCt,presol,inFesMat]=microbiotaModelSimulator(resPath,setup,sampName,sdiet,rDiet,0,extSolve,patNumb,fvaType)

[Fsp,Y]= mgSimResCollect(resPath,ID,rDiet,0,patNumb,fvaCt,figForm)




