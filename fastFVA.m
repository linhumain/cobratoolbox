function [minFlux,maxFlux,optsol,ret] = fastFVA(model,optPercentage,objective,solver)
%fastFVA Flux variablity analysis optimized for the GLPK and CPLEX solvers.
%
% [minFlux,maxFlux] = fastFVA(model,optPercentage,objective, solver)
%
% Solves LPs of the form for all v_j: max/min v_j
%                                     subject to S*v = b
%                                     lb <= v <= ub
% Inputs:
%   model             Model structure
%     Required fields
%       S            Stoichiometric matrix
%       b            Right hand side = 0
%       c            Objective coefficients
%       lb           Lower bounds
%       ub           Upper bounds
%     Optional fields
%       A            General constraint matrix
%       csense       Type of constraints, csense is a vector with elements
%                    'E' (equal), 'L' (less than) or 'G' (greater than).
%     If the optional fields are supplied, following LPs are solved
%                    max/min v_j
%                    subject to Av {'<=' | '=' | '>='} b
%                                lb <= v <= ub
%
%   optPercentage    Only consider solutions that give you at least a certain
%                    percentage of the optimal solution (default = 100
%                    or optimal solutions only)
%   objective        Objective ('min' or 'max') (default 'max')
%   solver           'cplex' or 'glpk' (default 'glpk')
%
% Outputs:
%   minFlux   Minimum flux for each reaction
%   maxFlux   Maximum flux for each reaction
%   optsol    Optimal solution (of the initial FBA)
%   ret       Zero if success
%
% Example:
%    load modelRecon1Biomass.mat % Human reconstruction network
%    SetWorkerCount(4) % Only if you have the parallel toolbox installed
%    [minFlux,maxFlux]=fas tFVA(model, 90);
%
% Reference: "Computationally efficient Flux Variability Analysis"

% Author: Steinn Gudmundsson.
% Last updated: April 21st, 2010.

verbose=1;

if nargin<4, solver='glpk'; end
if nargin<3, objective='max'; end
if nargin<2, optPercentage=100; end

if strcmpi(objective,'max')
   obj=-1;
elseif strcmpi(objective,'min')
   obj=1;
else
   error('Unknown objective')
end

if strmatch('glpk',solver)
   FVAc=@glpkFVAcc;
elseif strmatch('cplex',solver)
   FVAc=@cplexFVAc;
   fprintf('\n>> The solver is CPLEX.\n\n');
else
   error(sprintf('Solver %s not supported', solver))
end

if isfield(model,'A')
   % "Generalized FBA"
   A=model.A;
   csense=model.csense(:);
else
   % Standard FBA
   A=model.S;
   csense=char('E'*ones(size(A,1),1));
end
b=model.b;
[m,n]=size(A);


poolobj = gcp('nocreate'); % If no pool, do not create new one.
if isempty(poolobj)
    nworkers = 0;
else
    nworkers = poolobj.NumWorkers;
end


fprintf('\n>> The number of workers is %d.\n\n', nworkers);

if nworkers<=1
   % Sequential version
   [minFlux,maxFlux,optsol,ret]=FVAc(model.c,A,b,csense,model.lb,model.ub, ...
                                     optPercentage,obj,(1:n)');

   if ret ~= 0 && verbose
      fprintf('Unable to complete the FVA, return code=%d\n', ret);
   end
else
   % Divide the reactions amongst workers
   %
   % The load balancing can be improved for certain problems, e.g. in case
   % of problems involving E-type matrices, some workers will get mostly
   % well-behaved LPs while others may get many badly scaled LPs.
   
   % For debugging, leave out
   if n > 5000
      % A primitive load-balancing strategy for large problems
  %    nworkers=4*nworkers;
   end

   nrxn=repmat(fix(n/nworkers),nworkers,1);
   i=1;
   while sum(nrxn) < n
      nrxn(i)=nrxn(i)+1;
      i=i+1;
   end
   assert(sum(nrxn)==n);
   istart=1; iend=nrxn(1);
   for i=2:nworkers
      istart(i)=iend(i-1)+1;
      iend(i)=istart(i)+nrxn(i)-1;
   end

   minFlux=zeros(n,1); maxFlux=zeros(n,1);
   iopt=zeros(nworkers,1);
   iret=zeros(nworkers,1);

   fprintf('\n -- Starting to loop through the %d workers. -- \n\n', nworkers);

   parfor i=1:nworkers

       t = getCurrentTask();
       fprintf('Worker Nb(i%d) %d: \n', i, t.ID);

  tstart=tic;

      [minf,maxf,iopt(i),iret(i)]=FVAc(model.c,A,b,csense,model.lb,model.ub, ...
                                       optPercentage,obj,(istart(i):iend(i))');
      
   fprintf('Time spent in FVAc: %1.1f seconds.\n', toc(tstart));

      if iret(i) ~= 0 && verbose
         fprintf('Problems solving partition %d, return code=%d\n', i, iret(i))
      end
      minFlux=minFlux+minf;
      maxFlux=maxFlux+maxf;
   end
   optsol=iopt(1);
   ret=max(iret);
end
