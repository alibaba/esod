function [gt,dt] = evalRes( gt0, dt0, thr, mul )
% Evaluates detections against ground truth data.
%
% Uses modified Pascal criteria that allows for "ignore" regions. The
% Pascal criteria states that a ground truth bounding box (gtBb) and a
% detected bounding box (dtBb) match if their overlap area (oa):
%  oa(gtBb,dtBb) = area(intersect(gtBb,dtBb)) / area(union(gtBb,dtBb))
% is over a sufficient threshold (typically .5). In the modified criteria,
% the dtBb can match any subregion of a gtBb set to "ignore". Choosing
% gtBb' in gtBb that most closely matches dtBb can be done by using
% gtBb'=intersect(dtBb,gtBb). Computing oa(gtBb',dtBb) is equivalent to
%  oa'(gtBb,dtBb) = area(intersect(gtBb,dtBb)) / area(dtBb)
% For gtBb set to ignore the above formula for oa is used.
%
% Highest scoring detections are matched first. Matches to standard,
% (non-ignore) gtBb are preferred. Each dtBb and gtBb may be matched at
% most once, except for ignore-gtBb which can be matched multiple times.
% Unmatched dtBb are false-positives, unmatched gtBb are false-negatives.
% Each match between a dtBb and gtBb is a true-positive, except matches
% between dtBb and ignore-gtBb which do not affect the evaluation criteria.
%
% In addition to taking gt/dt results on a single image, evalRes() can take
% cell arrays of gt/dt bbs, in which case evaluation proceeds on each
% element. Use bbGt>loadAll() to load gt/dt for multiple images.
%
% Each gt/dt output row has a flag match that is either -1/0/1:
%  for gt: -1=ignore,  0=fn [unmatched],  1=tp [matched]
%  for dt: -1=ignore,  0=fp [unmatched],  1=tp [matched]
%
% USAGE
%  [gt, dt] = bbGt( 'evalRes', gt0, dt0, [thr], [mul] )
%
% INPUTS
%  gt0  - [mx5] ground truth array with rows [x y w h ignore]
%  dt0  - [nx5] detection results array with rows [x y w h score]
%  thr  - [.5] the threshold on oa for comparing two bbs
%  mul  - [0] if true allow multiple matches to each gt
%
% OUTPUTS
%  gt   - [mx5] ground truth results [x y w h match]
%  dt   - [nx6] detection results [x y w h score match]
%
% EXAMPLE
%
% See also bbGt, bbGt>compOas, bbGt>loadAll

% get parameters
if(nargin<3 || isempty(thr)), thr=.7; end
if(nargin<4 || isempty(mul)), mul=0; end

% if gt0 and dt0 are cell arrays run on each element in turn
if( iscell(gt0) && iscell(dt0) ), n=length(gt0);
    assert(length(dt0)==n); gt=cell(1,n); dt=gt;
    for i=1:n, [gt{i},dt{i}] = evalRes(gt0{i},dt0{i},thr,mul); end; return;
end

% check inputs
if(isempty(gt0)), gt0=zeros(0,5); end
if(isempty(dt0)), dt0=zeros(0,5); end
assert( size(dt0,2)==5 ); nd=size(dt0,1);
assert( size(gt0,2)==5 ); ng=size(gt0,1);

% sort dt highest score first, sort gt ignore last
[~,ord]=sort(dt0(:,5),'descend'); dt0=dt0(ord,:);
[~,ord]=sort(gt0(:,5),'ascend'); gt0=gt0(ord,:);
gt=gt0; gt(:,5)=-gt(:,5); dt=dt0; dt=[dt zeros(nd,1)];

% Attempt to match each (sorted) dt to each (sorted) gt
oa = compOas( dt(:,1:4), gt(:,1:4), gt(:,5)==-1 );
for d=1:nd
    bstOa=thr; bstg=0; bstm=0; % info about best match so far
    for g=1:ng
        % if this gt already matched, continue to next gt
        m=gt(g,5);
        if( m==1 && ~mul ), continue; end
        % if dt already matched, and on ignore gt, nothing more to do
        if( bstm~=0 && m==-1 ), break; end
        % compute overlap area, continue to next gt unless better match made
        if(oa(d,g)<bstOa), continue; end
        % match successful and best so far, store appropriately
        bstOa=oa(d,g); bstg=g;
        if(m==0), bstm=1; else bstm=-1; end
    end;
    g=bstg; m=bstm;
    % store type of match for both dt and gt
    if(m==-1), dt(d,6)=m; elseif(m==1), gt(g,5)=m; dt(d,6)=m; end
end