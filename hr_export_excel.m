function hr_export_excel(P, FIG)
%HR_EXPORT_EXCEL  Write every figure's numeric data to one Excel worksheet,
% prefixed by its caption, explanation and interpretation. Sheets are named
% Figure_001, Figure_002, ... per the project convention.
%
% INPUT : P (params), FIG (1xN cell of figure-data structs from hr_make_figures)
% Each FIG{i} must provide: .id .name .caption .explanation .interpretation
%                           .xlabel .ylabel .legend(optional) .T(table)
% =========================================================================
xlsx = P.io.xlsx;
if exist(xlsx,'file'); delete(xlsx); end        % fresh workbook

% ---- index sheet ---------------------------------------------------------
idxC = {'Sheet','Figure ID','Title'};
for i=1:numel(FIG)
    idxC(end+1,:) = {sprintf('Figure_%03d',i), FIG{i}.id, FIG{i}.name}; %#ok<AGROW>
end
writecell(idxC, xlsx, 'Sheet','Index');

for i=1:numel(FIG)
    f = FIG{i};
    sh = sprintf('Figure_%03d',i);
    meta = {
        'Figure', f.id ;
        'Name',   f.name ;
        'Caption', char(f.caption) ;
        'Explanation', char(f.explanation) ;
        'Interpretation', char(f.interpretation) ;
        'X axis', char(f.xlabel) ;
        'Y axis', char(f.ylabel) };
    if isfield(f,'legend') && ~isempty(f.legend)
        meta(end+1,:) = {'Legend', char(strjoin(string(f.legend),' | '))}; %#ok<AGROW>
    end
    writecell(meta, xlsx, 'Sheet', sh, 'Range','A1');
    % data table written below the metadata block
    r0 = size(meta,1) + 2;
    if isfield(f,'T') && ~isempty(f.T)
        try
            writetable(f.T, xlsx, 'Sheet', sh, 'Range', sprintf('A%d',r0));
        catch ME
            writecell({['(data export note) ' ME.message]}, xlsx,'Sheet',sh,'Range',sprintf('A%d',r0));
        end
    end
end
fprintf('    wrote %d figure sheets -> %s\n', numel(FIG), xlsx);
end
