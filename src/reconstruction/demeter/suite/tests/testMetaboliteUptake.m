function [TruePositives, FalseNegatives] = testMetaboliteUptake(model, microbeID, biomassReaction, database, inputDataFolder)
% Performs an FVA and reports those metabolites (exchange reactions)
% that can be taken up by the model and should be taken up according to
% data (true positives) and those metabolites that cannot be taken up by
% the model but should be taken up according to in vitro data (false
% negatives).
% Based on literature search of reported vitamin-secreting probiotics
% performed 11/2017, and a compendium of uptake and uptake products
% (PMID:28585563)
%
% INPUT
% model             COBRA model structure
% microbeID         Microbe ID in uptake product data file
% biomassReaction   Biomass objective functions (low flux through BOF
%                   required in analysis)
% database          Structure containing rBioNet reaction and metabolite
%                   database
% inputDataFolder   Folder with experimental data and database files
%                   to load
%
% OUTPUT
% TruePositives     Cell array of strings listing all metabolites
%                   (exchange reactions) that can be taken up by the model
%                   and in in vitro data.
% FalseNegatives    Cell array of strings listing all metabolites
%                   (exchange reactions) that cannot be taken up by the model
%                   but should be taken up according to in vitro data.
%
% .. Author:
%      Almut Heinken, August 2019
%                     March  2022 - changed code to string-matching to make
%                     it more robust

global CBT_LP_SOLVER
if isempty(CBT_LP_SOLVER)
    initCobraToolbox
end

% read uptake product tables
dataTable = readInputTableForPipeline([inputDataFolder filesep 'uptakeTable.txt']);

% remove the reference columns
dataTable(:,find(strncmp(dataTable(1,:),'Ref',3))) = [];

% list reactions corresponding to each data point
corrRxns = {'Ammonia','EX_nh4(e)','','';'Hydrogen','EX_h2(e)','','';'Isethionate','EX_isetac(e)','','';'Menaquinone','EX_mqn7(e)','EX_mqn8(e)','';'Methanol','EX_meoh(e)','','';'Methylamine','EX_mma(e)','','';'Niacin','EX_nac(e)','EX_ncam(e)','';'Nitrogen (N2)','EX_n2(e)','','';'Nitrite','EX_no2(e)','','';'Nitrate','EX_no3(e)','','';'Pantothenate','EX_pnto_R(e)','','';'Phenol','EX_phenol(e)','','';'2-methylbutyrate','EX_2mbut(e)','','';'1,2-propanediol','EX_12ppd_S(e)','','';'Cobalamin','EX_cbl1(e)','EX_adocbl(e)','';'Linoleic acid','EX_lnlc(e)','','';'alpha-Linolenic acid','EX_lnlnca(e)','','';'Benzoate','EX_bz(e)','','';'Betaine','EX_glyb(e)','','';'Bicarbonate','EX_hco3(e)','','';'Biotin','EX_btn(e)','','';'Chenodeoxycholate','EX_C02528(e)','','';'Cholate','EX_cholate(e)','','';'Dimethylamine','EX_dma(e)','','';'Folate','EX_fol(e)','','';'Formate','EX_for(e)','','';'Glycochenodeoxycholate','EX_dgchol(e)','','';'Pyridoxal','EX_pydx(e)','EX_pydxn(e)','EX_pydam(e)';'Propanol','EX_ppoh(e)','','';'Uridine','EX_uri(e)','','';'Urea','EX_urea(e)','','';'Riboflavin','EX_ribflv(e)','','';'Shikimate','EX_skm(e)','','';'Spermidine','EX_spmd(e)','','';'Sulfate','EX_so4(e)','','';'Valerate','EX_M03134(e)','','';'Tryptamine','EX_trypta(e)','','';'Tyramine','EX_tym(e)','','';'Trimethylamine','EX_tma(e)','','';'Taurine','EX_taur(e)','','';'Taurochenodeoxycholate','EX_tdchola(e)','','';'Taurocholate','EX_tchola(e)','','';'Thiamine','EX_thm(e)','','';'Thymidine','EX_thymd(e)','','';'Thiosulfate','EX_tsul(e)','','';'Glycocholate','EX_gchola(e)','','';'4-Aminobenzoate','EX_4abz(e)','','';'4-Aminobutyrate','EX_4abut(e)','','';'2,3-Butanediol ','EX_btd_RR(e)','','';'Glycodeoxycholate','EX_M01989(e)','','';'Glycolithocholate','EX_HC02193(e)','','';'Taurodeoxycholate','EX_tdechola(e)','','';'Taurolithocholate','EX_HC02192(e)','','';'1,2-Ethanediol','EX_12ethd(e)','','';'L-alanine','EX_ala_L(e)','','';'L-arginine','EX_arg_L(e)','','';'L-asparagine','EX_asn_L(e)','','';'L-aspartate','EX_asp_L(e)','','';'L-cysteine','EX_cys_L(e)','','';'L-glutamate','EX_glu_L(e)','','';'L-glutamine','EX_gln_L(e)','','';'Glycine','EX_gly(e)','','';'L-histidine','EX_his_L(e)','','';'L-isoleucine','EX_ile_L(e)','','';'L-leucine','EX_leu_L(e)','','';'L-lysine','EX_lys_L(e)','','';'L-methionine','EX_met_L(e)','','';'L-phenylalanine','EX_phe_L(e)','','';'L-proline','EX_pro_L(e)','','';'L-serine','EX_ser_L(e)','','';'L-threonine','EX_thr_L(e)','','';'L-tryptophan','EX_trp_L(e)','','';'L-tyrosine','EX_tyr_L(e)','','';'L-valine','EX_val_L(e)','',''};

TruePositives = {};  % true positives (uptake in vitro and in silico)
FalseNegatives = {};  % false negatives (uptake in vitro not in silico)

% find microbe index in uptake table
mInd = find(strcmp(dataTable(:,1), microbeID));
if isempty(mInd)
    warning(['Microbe "', microbeID, '" not found in metabolite uptake data file.'])
else
    % perform FVA to identify uptake metabolites
    % set BOF
    if ~any(ismember(model.rxns, biomassReaction)) || nargin < 3
        error(['Biomass reaction "', biomassReaction, '" not found in model.'])
    end
    model = changeObjective(model, biomassReaction);
    % set a low lower bound for biomass
    %     model = changeRxnBounds(model, biomassReaction, 1e-3, 'l');
    % list exchange reactions
    exchanges = model.rxns(strncmp('EX_', model.rxns, 3));
    % open all exchanges
    model = changeRxnBounds(model, exchanges, -1000, 'l');
    model = changeRxnBounds(model, exchanges, 1000, 'u');

    % get the reactions to test
    rxns = {};
    for i=2:size(dataTable,2)
        if contains(version,'(R202') % for Matlab R2020a and newer
            if dataTable{mInd,i}==1
                findCorrRxns = find(strcmp(corrRxns(:,1),dataTable{1,i}));
                rxns = union(rxns,corrRxns(findCorrRxns,2:end));
            end
        else
            if strcmp(dataTable{mInd,i},'1')
                findCorrRxns = find(strcmp(corrRxns(:,1),dataTable{1,i}));
                rxns = union(rxns,corrRxns(findCorrRxns,2:end));
            end
        end
    end

    % flux variability analysis on reactions of interest
    rxns = unique(rxns);
    rxns = rxns(~cellfun('isempty', rxns));
    rxnsInModel=intersect(rxns,model.rxns);
    if ~isempty(rxnsInModel)
        currentDir=pwd;
        try
            [minFlux, maxFlux, ~, ~] = fastFVA(model, 0, 'max', 'ibm_cplex', ...
                rxnsInModel, 'S');
        catch
            warning('fastFVA could not run, so fluxVariability is instead used. Consider installing fastFVA for shorter computation times.');
            cd(currentDir)
            [minFlux, maxFlux] = fluxVariability(model, 0, 'max', rxnsInModel);
        end

        % active flux
        flux = rxnsInModel(minFlux < -1e-6);
    end
    % check all exchanges corresponding to each uptake
    % with multiple exchanges per uptake, at least one should be
    % consumed
    % so if there is least one true positive per secretion false negatives
    % are not considered

    for i=2:size(dataTable,2)
        if contains(version,'(R202') % for Matlab R2020a and newer
            if dataTable{mInd,i}==1
                findCorrRxns = find(strcmp(corrRxns(:,1),dataTable{1,i}));
            else
                if strcmp(dataTable{mInd,i},'1')
                    findCorrRxns = find(strcmp(corrRxns(:,1),dataTable{1,i}));
                end
            end
            allEx = corrRxns(findCorrRxns,2:end);
            allEx = allEx(~cellfun(@isempty, allEx));
            if ~isempty(intersect(allEx, rxnsInModel))
                if isempty(intersect(allEx, flux))
                    FalseNegatives = union(FalseNegatives, setdiff(allEx{1}, flux));
                else
                    TruePositives = union(TruePositives, intersect(allEx{1}, flux));
                end
            else
                % add any that are not in model to the false negatives
                % if there are multiple exchanges per metabolite, only
                % take the first one
                FalseNegatives=union(FalseNegatives,allEx{1});
            end
        end
    end
end

% replace reaction IDs with metabolite names
if ~isempty(TruePositives)
    TruePositives = TruePositives(~cellfun(@isempty, TruePositives));
    TruePositives=strrep(TruePositives,'EX_','');
    TruePositives=strrep(TruePositives,'(e)','');

    for i=1:length(TruePositives)
        TruePositives{i}=database.metabolites{find(strcmp(database.metabolites(:,1),TruePositives{i})),2};
    end
end

% warn about false negatives
if ~isempty(FalseNegatives)
    FalseNegatives = FalseNegatives(~cellfun(@isempty, FalseNegatives));
    FalseNegatives=strrep(FalseNegatives,'EX_','');
    FalseNegatives=strrep(FalseNegatives,'(e)','');
    for i = 1:length(FalseNegatives)
        FalseNegatives{i}=database.metabolites{find(strcmp(database.metabolites(:,1),FalseNegatives{i})),2};
    end
end

end
