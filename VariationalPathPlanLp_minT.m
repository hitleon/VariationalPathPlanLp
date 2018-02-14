%============================== Lp_optimal_rect_3D =============================
%
% @brief    Test script for the kinemetic robot model. (3D)
%
%
% The test script assumes that each obstacle is rectangular, 
% and the robot has a rectangular body shape.
% (Skinny shape)
%
% REMARK: 
%  The piecewise constant B-spline is specified in Optragen by 
%  traj(ninterv,0,1) and a piecewise linear continuous function can be
%  generated by traj(ninterv,1,2).
%
%=============================== Lp_optimal_rect_3D ==============================

%
% @file     Lp_optimal_rect_3D.m
%
% @author   Nak-seung Patrick Hyun,     nhyun3@gatech.edu
% @date     2017/03/27 [created]
%
%=============================== Lp_optimal_rect_3D ==============================

%==[0] Set environment.
%
clear all;
close all;

%%
MATLIBS = {'control/snopt','control/snopt/matlab/matlab', ...
            'control/optimal', ...
            'control/optimal/Optragen/src', 'control/optimal/Optragen'};
ivalab.loadLibraries(MATLIBS);
addpath('autogen');


%==[1] Create the problem.
%
global qf qdf sigma tau m J obs obsOrder obsScale B1 B2;
T = 1;     %10

ninterv =10;                                 %10
xsmoothv = 5;                                 % 5
xorderv  = 9;  % even order n  rotorderv +1 %9
ysmoothv = 5;                               %5
yorderv  = 9;  % even order n  rotorderv +1 %9
thsmoothv = 5;                              %5
thorderv  = 9;  % even order n  rotorderv +1 %9
musmoothv = 2;                               %2
muorderv  = 8;  % even order n  rotorderv +1 %10


scale = 100;
epsillon =10^(-6);
tfinal  = T;

%==[1-1] Initial conditions for robot in SE(2)

q0 = [-3; 0; pi/4]; % [x, y, th]
qf = [3; 0.5; 0]; % [x, y, th] 
qd0 = [0; 0; 0]; % [x', y', th']
qdf = [0; 0; 0]; % [x', y', th']

%==[1-2] Constant
sigma = 1; % Weight on the cost for the length
tau = 1; % Weight on Obstacle cost
m =1; % Riemanian metric
J =1; % Riemanian metric

%==[1-3] Circular Obstacle
obs = [0;0;0]; % [x, y, th] Circular obstacle
obsOrder = 2       %6
radius = 1;
obsScale = [1; 5];  % [2,4]
%==[1-4] Initial guess

mu0 = 1;
muf = 1;
Tf0 = 1;

%==[1-5] Velocity constriants

B1= 5;
B2 = pi/2;
%==[2] Define the optimization variables.
%
%-- Robot state and input variables.
%   Since theta is directly controlled, leave derivative unconstrained.
%

gSym={'x'; 'y'; 'th'; 'mu'; 'tf'};
gpSym={'x'; 'y'; 'th'; 'mu';...
       'xd'; 'yd'; 'thd'; 'mud';... 
       'xdd'; 'ydd'; 'thdd';... 
       'xddd'; 'yddd'; 'thddd';... 
       'xdddd'; 'ydddd'; 'thdddd'; 'tf'};

x  = traj('x', ninterv, xsmoothv, xorderv); % Center of mass
y  = traj('y', ninterv, ysmoothv, yorderv);
th = traj('th', ninterv, thsmoothv, thorderv);
mu = traj('mu', ninterv, musmoothv, muorderv);
tf = traj('mu', 1, 0, 1);

nFreex = ninterv*(xorderv-xsmoothv)+xsmoothv;
nFreey = ninterv*(yorderv-ysmoothv)+ysmoothv;
nFreeth = ninterv*(thorderv-thsmoothv)+thsmoothv;
nFreemu = ninterv*(muorderv-musmoothv)+musmoothv;

nTotFree = nFreex + nFreey + nFreeth + nFreemu

% tf = traj('tf',1,0,1);

%-- State derivatives.

xd  = x.deriv('xd');
yd  = y.deriv('yd');
thd = th.deriv('thd');
mud  = mu.deriv('mud');

xdd  = xd.deriv('xdd');
ydd  = yd.deriv('ydd');
thdd = thd.deriv('thdd');
xddd  = xdd.deriv('xddd');
yddd  = ydd.deriv('yddd');
thddd = thdd.deriv('thddd');
xdddd  = xddd.deriv('xdddd');
ydddd  = yddd.deriv('ydddd');
thdddd = thddd.deriv('thdddd');

%%
%-- Trajectory variables used in problem
%
TrajList = traj.trajList(x, xd, xdd, xddd, xdddd, y, yd, ydd, yddd, ydddd, th, thd, thdd, thddd, thdddd, mu, mud, tf);

%-- Parameter list (What role does this play in overall setup????)
%
ParamList = { 'qf', 'qdf', 'sigma', 'm', 'J', 'tau', 'obs', 'obsOrder', 'obsScale', 'B1', 'B2'};

lambda =0.1;
%==[3] Define the optimization setup.
%

%-- Cost Function
%
   Cost = cost('(xd*sin(th)-yd*cos(th))^2', 'trajectory');
   Cost = cost('tf', 'final');

   %   Cost = cost('(xdd^2+ydd^2)+sigma*(xd^2+yd^2)+tau/(((x-obs(1))/obsScale(1))^obsOrder+((y-obs(2))/obsScale(2))^obsOrder-1^obsOrder)', 'trajectory');

% cost('(x-qf(1))^2+(y-qf(2))^2+(th-qf(3))^2+(xd-qdf(1))^2+(yd-qdf(2))^2+(thd-qdf(3))^2','final'); % 6 unknown
nonHolonomic = strcat('xd*sin(th)-yd*cos(th)');
dynamics ={'-thdddd+sigma*thdd*tf^2-mu/J*(xd*tf^3*cos(th)+yd*tf^3*sin(th))',... 
            '-xdddd+sigma*xdd*tf^2+tau*obsOrder/2*((x-obs(1))/obsScale(1))^(obsOrder-1)/obsScale(1)/(((x-obs(1))/obsScale(1))^obsOrder+((y-obs(2))/obsScale(2))^obsOrder-1^obsOrder)^2+1/m*(mud*tf^3*sin(th)+mu*thd*tf^3*cos(th))',...
            '-ydddd+sigma*ydd*tf^2+tau*obsOrder/2*((y-obs(2))/obsScale(2))^(obsOrder-1)/obsScale(2)/(((x-obs(1))/obsScale(1))^obsOrder+((y-obs(2))/obsScale(2))^obsOrder-1^obsOrder)^2+1/m*(-mud*tf^3*cos(th)+mu*thd*tf^3*sin(th))'};
Holonomic = strcat('(((x-obs(1))/obsScale(1))^obsOrder+((y-obs(2))/obsScale(2))^obsOrder)^(1/obsOrder)-1');
Speed_linear = strcat('B1^2*tf^2-xd^2-yd^2');
Speed_angular = strcat('B2^2*tf^2-thd^2');

%-- Constraints
%

% + constraint.finalCondition(gSym{1}, rF(1)) ... 
%     + constraint.finalCondition(gSym{2}, rF(2)) ...
%     + constraint.finalCondition(gSym{3}, rF(3)) ...
    
Constr = constraint.initialCondition(gSym{1}, q0(1)) ... 
    + constraint.initialCondition(gSym{2}, q0(2)) ...
    + constraint.initialCondition(gSym{3}, q0(3)) ...
    + constraint.initialCondition(gpSym{5}, qd0(1)) ... 
    + constraint.initialCondition(gpSym{6}, qd0(2)) ...
    + constraint.initialCondition(gpSym{7}, qd0(3)) ...
     + constraint.finalCondition(gpSym{1}, qf(1)) ... 
    + constraint.finalCondition(gpSym{2}, qf(2)) ...
    + constraint.finalCondition(gpSym{3}, qf(3)) ...
     + constraint.finalCondition(gpSym{5}, qdf(1)) ... 
    + constraint.finalCondition(gpSym{6}, qdf(2)) ...
    + constraint.finalCondition(gpSym{7}, qdf(3)) ...
    + constraint(0, 'tf', Inf, 'trajectory', gSym)...
    + constraint(0, nonHolonomic, 0, 'trajectory', gpSym)...
    + constraint(0, Holonomic, Inf, 'trajectory', gpSym)...
    + constraint(0, Speed_linear, Inf, 'trajectory', gpSym)...
    + constraint(0, Speed_angular, Inf, 'trajectory', gpSym)...
    + constraint(-epsillon, dynamics{1}, epsillon, 'trajectory', gpSym)...
    + constraint(-epsillon, dynamics{2}, epsillon, 'trajectory', gpSym)...
    + constraint(-epsillon, dynamics{3}, epsillon, 'trajectory', gpSym);
                      ...
% % Safety constraint
% Constr_init = Constr + LpConstraint3DCoM_quater(gSym, robScale, obsRo, obsCent, obsScale, [robOrder, obsOrder]);
%  Constr = Constr + LpConstraint3DBent_quater(gSym, robScale, obsRo, obsCent, obsScale, [robOrder, obsOrder]);
%  % Dynamics
% Constr_dyn = kinemetics3D_quater(gSym, gpSym, vSym, e0);
% Constr = Constr ...
%          + Constr_dyn;
%      
% Constr_init = Constr_init + Constr_dyn;
%-- Collocation Points, using Gaussian Quadrature formula
%

hl = tfinal;

numBreaks = (2*ninterv+1);
breaks = linspace(0, hl, numBreaks);
gauss  = [-1 1]*sqrt(1/3)/2;
temp   = ((breaks(2:numBreaks)+breaks(1:numBreaks-1))/2);
temp   = temp(ones(1,length(gauss)),:) + gauss'*diff(breaks);
colpnts = temp(:).';

HL = [0 colpnts hl];

%HL = nodesCGL(0,hl,25);
%-- Location of auto-generated functions.
%
pathName = './autogen';         % Save generated code to directory ...
probName = 'VariationalPathPlanFunction';        % Name of generated interface function.
% probName_init = 'VariationalPathPlan_init';

%-- Create specification of the nonlinear programming problem.
%
nlp = ocp2nlp(TrajList, Cost,Constr, HL, ParamList, pathName, probName);
% nlp_init = ocp2nlp(TrajList, Cost,Constr_init, HL, ParamList, pathName, probName_init);


xlow = -Inf*ones(nlp.nIC,1);
xupp =  Inf*ones(nlp.nIC,1);

Time = linspace(0,1,100);


    xval  = linspace(q0(1),qf(1),100);
    yval  = linspace(q0(2),qf(2)+10,100);  % Straight line
    thval = linspace(q0(3),qf(3),100);  % Constant heading.
    
    muval = linspace(mu0,muf,100);  % Straight line
    tfval = linspace(1,1,100);
    %-- Generate spline coefficients from initial guess.
    xsp  = createGuess(x,Time,xval);
    ysp  = createGuess(y,Time,yval);
    thsp = createGuess(th,Time,thval);
    
    musp  = createGuess(mu,Time,muval);
    tfsp = createGuess(tf,Time,tfval);

init = [xsp.coefs ysp.coefs thsp.coefs musp.coefs tfsp.coefs];

%==[4] Run the solver.
%

tic
ghSnopt = ipoptFunction(nlp);
% [x,F,inform] = snopt(init', xlow, xupp, [], [], ...
%                     [0;nlp.LinCon.lb;nlp.nlb], [Inf;nlp.LinCon.ub;nlp.nub], ...
%                       [], [], ...
%                     ghSnopt);
toc;

grad_Const_full = getSparseJacobian(TrajList, Constr, nlp);
grad_Const = sparse(grad_Const_full);
[~,~,nobj, nlinConstr, nnlConstr]=ghSnopt(init');
nFreeVar=length(init);
nConstraint = nlinConstr+nnlConstr;
%% OPTRAGEN + IPOPT code 
profile on;
tic;
 [x, info]=optragen_ipopt_v2(ghSnopt,nobj,nFreeVar,nConstraint,init,xlow,xupp,[nlp.LinCon.lb;nlp.nlb],[nlp.LinCon.ub;nlp.nub],nlp,grad_Const);
%[x, info]=optragen_ipopt(ghSnopt,nobj,nFreeVar,nConstraint,init,xlow,xupp,[nlp.LinCon.lb;nlp.nlb],[nlp.LinCon.ub;nlp.nub]);

toc;
profile off;
profile viewer;
%% ==[5] Extract the trajectory from the solution.
%       Also snag points evaluated at specific times.
%

sp   = getTrajSplines(nlp,x);


[xSP, ySP, thSP, muSP, tfSP] = deal(sp{:});
   
% load('TRO_regular_cuboid3dBend_Optimal4_Initial_obspi4.mat')
% tfinalOpt = fnval(tfSP,min(HL));
tgrid = linspace(min(HL),max(HL),ninterv*scale);
colindex = 1:size(HL,2);

X  = fnval(xSP,tgrid);
Xd = fnval(fnder(xSP),tgrid);

Y  = fnval(ySP,tgrid);
Yd = fnval(fnder(ySP),tgrid);

TH  = fnval(thSP,tgrid);
THd = fnval(fnder(thSP),tgrid);

Xcol = fnval(xSP,HL);
Ycol = fnval(ySP,HL);
THcol = fnval(thSP,HL);
Xdcol =fnval(fnder(xSP),HL);
Ydcol =fnval(fnder(ySP),HL);
THdcol =fnval(fnder(thSP),HL);
Xddcol =fnval(fnder(xSP,2),HL);
Yddcol =fnval(fnder(ySP,2),HL);
THddcol =fnval(fnder(thSP,2),HL);
Xdddcol =fnval(fnder(xSP,3),HL);
Ydddcol =fnval(fnder(ySP,3),HL);
THdddcol =fnval(fnder(thSP,3),HL);
Xddddcol =fnval(fnder(xSP,4),HL);
Yddddcol =fnval(fnder(ySP,4),HL);
THddddcol =fnval(fnder(thSP,4),HL);

MU    = fnval(muSP,tgrid);
MUcol    = fnval(muSP,HL);
MUdcol =fnval(fnder(muSP),HL);

TF    = fnval(tfSP,tgrid);
TFcol    = fnval(tfSP,HL);
TF_opt = TF(1);
% %-- [5-1] ODE forward solution by having 1
% 
% mu0Opt = MU(1);
% init_forward = [THcol(1),THdcol(1),THddcol(1),THdddcol(1),...
%                 Xcol(1),Xdcol(1),Xddcol(1),Xdddcol(1),...
%                 Ycol(1),Ydcol(1),Yddcol(1),Ydddcol(1),...
%                 mu0Opt];
% tspan = linspace(0, TF_opt,scale);
% [tt_forward,xx_forward] = ode15s(@ForwardVarPathPlan,[0 TF_opt],init_forward');
% 
% TH_forward = xx_forward(:,1);
% X_forward = xx_forward(:,5);
% Y_forward = xx_forward(:,9);
% %==[6] Display results.
% Visualization
 set(groot, 'defaultAxesTickLabelInterpreter','latex');
 set(groot, 'defaultTextInterpreter','latex');

fh = figure(1);
  clf;
plot(X, Y,'b','LineWidth',1.5);           % Plot trajectory.
hold on;
%    plot(X_forward, Y_forward,'g','LineWidth',1.5);           % Plot trajectory.
plot(Xcol, Ycol,'ro','MarkerSize', 5, 'LineWidth',1);           % Plot trajectory.
plot(X(1:scale:end),Y(1:scale:end),'bo','MarkerSize', 8, 'LineWidth',1);
 
grid on;
  axis tight;
  
  box on;
  
LpGenNormFigure(obs(1),obs(2),obsScale(1),obsScale(2),obsOrder,obs(3),1,'r')

   hold off;
  axis equal;
  axis tight;
  set(fh, 'Name', 'World'); 
  xlabel('$x$'); ylabel('$y$'); zlabel('$z$');
  set(gca,'fontsize',16)
  set(fh,'Units','Inches');
  set(gcf, 'Color', 'w');
pos = get(fh,'Position');

set(fh,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-0.5, pos(4)])

%%
%   print(fh,'VariationalPathPlan_Rec3','-dpdf','-r0') 
%   print(fh,'TRO_figure_bend_cub_2','-dpdf','-r0')  

%%
fh1= figure(2);
  subplot(2,3,1);
    q0error = q0-[Xcol(1);Ycol(1);THcol(1)];
    qd0error = qd0-[Xdcol(1);Ydcol(1);THdcol(1)];
    qferror = qf-[X(end);Y(end);TH(end)];
    qdferror = qdf-[Xd(end);Yd(end);THd(end)];
    q0error = norm(q0error);
    qd0error = norm(qd0error);
    qferror = norm(qferror);
    qdferror = norm(qdferror);
    
    plot([q0error, qd0error qferror, qdferror,], 'bo-');
    
       axis tight;
       xlabel('$q0$, $\dot{q}(0)$, $q_f$, $\dot{q}_f$'); ylabel('Error');
    
    
    subplot(2,3,2);
      nonholonomic_opt = Xdcol.*sin(THcol)-Ydcol.*cos(THcol);
    
    plot(HL,nonholonomic_opt,'b-o');xlabel('time'); ylabel('Error(Nonholonomic)');
   axis square;
    xlim([0, tfinal])
    
    subplot(2,3,3);
      dynamics_TH_opt = -THddddcol+sigma.*THddcol*TF_opt^2-1/J.*MUcol.*(Xdcol.*cos(THcol)*TF_opt^3+Ydcol.*sin(THcol)*TF_opt^3);
    
    plot(HL,dynamics_TH_opt,'b-o');xlabel('time'); ylabel('Error(TH dynamics)');
   axis square;
    xlim([0, tfinal])
    
    subplot(2,3,4);
      dynamics_X_opt = -Xddddcol+sigma.*Xddcol*TF_opt^2+tau.*obsOrder/2.*((Xcol-obs(1))./obsScale(1)).^(obsOrder-1)./obsScale(1)./(((Xcol-obs(1))./obsScale(1)).^obsOrder+((Ycol-obs(2))./obsScale(2)).^obsOrder-1^obsOrder).^2+1/m.*(MUdcol.*sin(THcol)*TF_opt^3+MUcol.*THdcol.*cos(THcol)*TF_opt^3);
    
    plot(HL,dynamics_X_opt,'b-o');xlabel('time'); ylabel('Error(X dynamics)');
   axis square;
    xlim([0, tfinal])
      subplot(2,3,5);
      dynamics_Y_opt = -Yddddcol+sigma.*Yddcol*TF_opt^2+tau.*obsOrder/2.*((Ycol-obs(2))./obsScale(2)).^(obsOrder-1)./obsScale(2)./(((Xcol-obs(1))./obsScale(1)).^obsOrder+((Ycol-obs(2))./obsScale(2)).^obsOrder-1^obsOrder).^2+1/m.*(-MUdcol.*cos(THcol)*TF_opt^3+MUcol.*THdcol.*sin(THcol)*TF_opt^3);
    
    plot(HL,dynamics_Y_opt,'b-o');xlabel('time'); ylabel('Error(Y dynamics)');
   axis square;
    xlim([0, tfinal])
     subplot(2,3,6);
      Speed_L_opt = B1^2*ones(1,size(HL,2))-(Xdcol.^2+Ydcol.^2)./TFcol.^2;
      Speed_A_opt = B2^2*ones(1,size(HL,2))-THdcol.^2./TFcol.^2;
    plot(HL,Speed_L_opt,'b-o',HL,Speed_A_opt,'r-o');xlabel('time'); ylabel('Speed bounds');
   axis square;
    xlim([0, tfinal])
            
% subplot(2,3,3)
%     plot(HL, dHdv(colindex,1), 'r-o', ...
%        HL, dHdv(colindex,2), 'g-o', ...
%        HL, dHdv(colindex,3), 'b-o');
%     legend('dH/dv(1)','dH/dv(2)','dH/dv(3)');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
%     
%     subplot(2,3,4)
%      plot(HL, error_rot, 'r-o');
%      legend('Vector space error norm');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
% %   set(fh1, 'Name', 'Validity Check for Optimality'); 
%   
%   subplot(2,3,5)
%      plot(HL, suff_Cond, 'r-o');
%      legend('lambda (sufficiency)');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
  set(fh1, 'Name', 'Validity Check for Optimality'); 

  HL_opt = HL*TF_opt;
  
  fh3= figure(3);
    subplot(3,5,1)
    plot(HL_opt, Xcol,'r-o');xlabel('time'); ylabel('$x(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,2)
    plot(HL_opt, Xdcol/TF_opt,'r-o');xlabel('time'); ylabel('$x^{(1)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,3)
    plot(HL_opt, Xddcol/TF_opt^2,'r-o');xlabel('time'); ylabel('$x^{(2)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,4)
    plot(HL_opt, Xdddcol/TF_opt^3,'r-o');xlabel('time'); ylabel('$x^{(3)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,5)
    plot(HL_opt, Xddddcol/TF_opt^4,'r-o');xlabel('time'); ylabel('$x^{(4)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,6)
    plot(HL_opt, Ycol,'r-o');xlabel('time'); ylabel('$y(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,7)
    plot(HL_opt, Ydcol/TF_opt,'r-o');xlabel('time'); ylabel('$y^{(1)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,8)
    plot(HL_opt, Yddcol/TF_opt^2,'r-o');xlabel('time'); ylabel('$y^{(2)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,9)
    plot(HL_opt, Ydddcol/TF_opt^3,'r-o');xlabel('time'); ylabel('$y^{(3)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,10)
    plot(HL_opt, Yddddcol/TF_opt^4,'r-o');xlabel('time'); ylabel('$y^{(4)}(t)$');
    axis square;
    subplot(3,5,11)
    plot(HL_opt, THcol,'r-o');xlabel('time'); ylabel('$\theta(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,12)
    plot(HL_opt, THdcol/TF_opt,'r-o');xlabel('time'); ylabel('$\theta^{(1)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,13)
    plot(HL_opt, THddcol/TF_opt^2,'r-o');xlabel('time'); ylabel('$\theta^{(2)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,14)
    plot(HL_opt, THdddcol/TF_opt^3,'r-o');xlabel('time'); ylabel('$\theta^{(3)}(t)$');
    axis square;
    xlim([0, tfinal])
    subplot(3,5,15)
    plot(HL_opt, THddddcol/TF_opt^4,'r-o');xlabel('time'); ylabel('$\theta^{(4)}(t)$');
    axis square;
    
  set(fh3, 'Name', 'Optimal state solution'); 
% fh4= figure(4);
% subplot(2,2,1)
%      plot(HL, error_rot, 'r-o');
%      legend('Vector space error norm');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
%     
%     subplot(2,2,2)
%      plot(HL, error_rotX, 'r-o');
%      legend('X error norm');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
%     
%     subplot(2,2,3)
%    plot(HL, error_rotY, 'r-o');
%      legend('X error norm');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
%     
%     subplot(2,2,4)
%     plot(HL, error_rotZ, 'r-o');
%      legend('X error norm');
%     axis square;
%     xlabel('time');
%     xlim([0, tfinal])
%     
%   set(fh4, 'Name', 'Validity Check for CMS vector'); 
% 
%     
%   fh5= figure(5);
%     subplot(2,2,1)
%     plot(tgrid, U,'r-o');xlabel('time'); ylabel('Speed');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,2,2)
%     plot(tgrid, W1,'r-o');xlabel('time'); ylabel('$W1$');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,2,3)
%     plot(tgrid, W2,'r-o');xlabel('time'); ylabel('$W2$');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,2,4)
%     plot(tgrid, W3,'r-o');xlabel('time'); ylabel('$W3$');
%     axis square;
%     xlim([0, tfinal])
%     
%   set(fh5, 'Name', 'Control'); 
%  fh6= figure(6);
%     subplot(3,2,1)
%     plot(HL, Q0col,'r-o');xlabel('time'); ylabel('$q0$');
%     hold on;
%     plot([0 HL(end)],[X0(4) rF(4)],'bo')
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(3,2,2)
%     plot(HL, Q1col,'r-o');xlabel('time'); ylabel('$q1$');
%     hold on;
%     plot([0 HL(end)],[X0(5) rF(5)],'bo')
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(3,2,3)
%     plot(HL, Q2col,'r-o');xlabel('time'); ylabel('$q2$');
%     hold on;
%     plot([0 HL(end)],[X0(6) rF(6)],'bo')
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(3,2,4)
%     plot(HL, Q3col,'r-o');xlabel('time'); ylabel('$q3$');
%     hold on;
%     plot([0 HL(end)],[X0(7) rF(7)],'bo')
%     axis square;
%     xlim([0, tfinal])
%     
%   set(fh6, 'Name', 'Validity Check for Quaternion with initial condition'); 
% fh7= figure(7);
%     subplot(2,4,1)
%     plot(HL, errorTopNE,'r-o');xlabel('time'); ylabel('TopNE');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,2)
%     plot(HL, errorTopNW,'r-o');xlabel('time'); ylabel('TopNW');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,3)
%     plot(HL, errorTopSW,'r-o');xlabel('time'); ylabel('TopSW');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,4)
%     plot(HL, errorTopSE,'r-o');xlabel('time'); ylabel('TopSE');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,5)
%     plot(HL, errorBotmNE,'r-o');xlabel('time'); ylabel('BotmNE');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,6)
%     plot(HL, errorBotmNW,'r-o');xlabel('time'); ylabel('BotmNW');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,7)
%     plot(HL, errorBotmSW,'r-o');xlabel('time'); ylabel('BotmSW');
%     axis square;
%     xlim([0, tfinal])
%     
%     subplot(2,4,8)
%     plot(HL, errorBotmSE,'r-o');xlabel('time'); ylabel('BotmSE');
%     axis square;
%     xlim([0, tfinal])
%   set(fh7, 'Name', 'Validity Check for Corner condition '); 
% 
%  
%  fh8 = figure(8);
%   clf;
%   subplot(1,4,1);
%  
%     
%     plot(HL,1./KBENDcol,'b-o');xlabel('time'); ylabel('radius of curvature');
% %     plot(HL,RBENDcol,'b-o');xlabel('time'); ylabel('radius of curvature');
%     
%     axis square;
%     xlim([0, tfinal])
%   subplot(1,4,2);
% %     plot(tgrid, dHdv(1,:), 'b', tgrid, dHdv(2,:), 'r');
%    plot(HL,THBENDcol,'b-o');xlabel('time'); ylabel('angle of curvature');
%     
%     axis square;
%     xlim([0, tfinal])
% %     subplot(1,4,3);
% % %     plot(tgrid, dHdv(1,:), 'b', tgrid, dHdv(2,:), 'r');
% %     plot(HL,LpBend_error(:,1),'b-o');xlabel('time'); ylabel('Lp error');
% %     hold on
% %     plot(HL,LpBend_error(:,2),'r-o');xlabel('time'); ylabel('Lp error');
% %     legend('Obs1', 'Obs2');
% %     
% %     axis square;
% %     xlim([0, tfinal])
%   subplot(1,4,4);
% %     plot(tgrid, dHdv(1,:), 'b', tgrid, dHdv(2,:), 'r');
%     plot(HL,KBENDcol,'b-o');xlabel('time'); ylabel('kappa');
%     
%     axis square;
%     xlim([0, tfinal])
%   set(fh8, 'Name', 'Validity Check for Bending Control'); 
%   
%   
%  %%
%   fh9 = figure(9);
%   clf;
%     plot(tgrid*tfinalOpt,KBEND,'-');xlabel('time'); ylabel('$\kappa$');
%     
% %     axis square;
%     xlim([0, tfinalOpt])
%   set(fh9, 'Name', 'Validity Check for Bending Control'); 
%     set(gca,'fontsize',26)
% 
%      set(fh9,'Units','Inches');
%    set(gcf, 'Color', 'w');
% %%
%    pos = get(fh9,'Position');
% % 
%  set(fh9,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-0.0, pos(4)])
% % 
%  print(fh9,'TRO_figure_bend_kappa2','-dpdf','-r0')  
%   
% 
% %%
%   fh10 = figure(10);
%   clf;
%    plot(tgrid*tfinalOpt, U,'r-');xlabel('time'); ylabel('$u$');
% %     axis square;
%     xlim([0, tfinalOpt])
%   set(fh10, 'Name', 'Validity Check for Bending Control'); 
%     set(gca,'fontsize',26)
% 
%      set(fh10,'Units','Inches');
%    set(gcf, 'Color', 'w');
% %%
%    pos = get(fh10,'Position');
% % 
%  set(fh10,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-0.0, pos(4)])
% % 
%  print(fh10,'TRO_figure_bend_speed2','-dpdf','-r0')  
% 
%  %%
%    fh11 = figure(11);
%   clf;
%    plot(tgrid*tfinalOpt, W1,'k-');xlabel('time'); ylabel('$\omega_1$');
%     axis square;
%     xlim([0, tfinalOpt])
%   set(fh11, 'Name', 'Validity Check for Bending Control'); 
%     set(gca,'fontsize',26)
% 
%      set(fh11,'Units','Inches');
%    set(gcf, 'Color', 'w');
%  pos = get(fh11,'Position');
% % 
%  set(fh11,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-0.8, pos(4)])
% % 
%  print(fh11,'TRO_figure_bend_w1','-dpdf','-r0')  
%   
%   fh12 = figure(12);
%   clf;
%    plot(tgrid*tfinalOpt, W2,'k-');xlabel('time'); ylabel('$\omega_2$');
%     axis square;
%     xlim([0, tfinalOpt])
%   set(fh12, 'Name', 'Validity Check for Bending Control'); 
%     set(gca,'fontsize',26)
% 
%      set(fh12,'Units','Inches');
%    set(gcf, 'Color', 'w');
%  pos = get(fh12,'Position');
% % 
%  set(fh12,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-0.8, pos(4)])
% % 
%  print(fh12,'TRO_figure_bend_w2','-dpdf','-r0')  
%   
%   fh13 = figure(13);
%   clf;
%    plot(tgrid*tfinalOpt, W3,'k-');xlabel('time'); ylabel('$\omega_3$');
%     axis square;
%     xlim([0, tfinalOpt])
%   set(fh13, 'Name', 'Validity Check for Bending Control'); 
%     set(gca,'fontsize',26)
% 
%      set(fh13,'Units','Inches');
%    set(gcf, 'Color', 'w');
%  pos = get(fh13,'Position');
% % 
%  set(fh13,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-0.8, pos(4)])
% % 
%  print(fh13,'TRO_figure_bend_w3','-dpdf','-r0')  
%   
%   %  %% Save image
% %   set(fh,'Units','Inches');
% %   set(gcf, 'Color', 'w');
% % pos = get(fh,'Position');
% % 
% % set(fh,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3)-1.5, pos(4)])
% % 
% % print(fh,'RAL_figure_rec_rec_IPOPT','-dpdf','-r0')  
