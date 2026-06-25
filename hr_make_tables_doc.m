function hr_make_tables_doc(P, TBL)
%HR_MAKE_TABLES_DOC  Write the scientific tables + figure index to a Word
% document as NATIVE Word tables (via COM ConvertToTable), publication-ready.
%
% INPUT : P (params), TBL (struct of MATLAB tables from hr_make_tables)
% OUTPUT: output/HeatRoute_FirmH2_Tables.docx
% =========================================================================
outfile = fullfile(P.io.outdir,'HeatRoute_FirmH2_Tables.docx');
titles = struct( ...
 'T01_Nomenclature','Table 1. Nomenclature', ...
 'T02_Parameters','Table 2. Principal model parameters', ...
 'T03_Headline_Results','Table 3. Headline results', ...
 'T04_Site_Results','Table 4. Per-site firm-hydrogen results (measured NASA POWER climatology)', ...
 'T05_Sizing_HeatRoute','Table 5. Optimal heat-route (CSP+TES+SOEC) sizing by site', ...
 'T05b_Sizing_ElecRoute','Table 6. Optimal electricity-route (PV+battery+LT) sizing by site', ...
 'T06_Energy_Exergy','Table 7. Energy and exergy balance (exemplar site)', ...
 'T07_Efficiency','Table 8. First- and second-law efficiencies by site', ...
 'T08_Dimensionless','Table 9. Dimensionless groups and their physical meaning', ...
 'T09_Economics','Table 10. Techno-economic metrics by route (exemplar site)', ...
 'T10_Environmental','Table 11. Environmental indicators by site', ...
 'T11_Cost_Scenarios','Table 12. Firm LCOH under 2025/2030/2050 cost scenarios', ...
 'T12_Uncertainty','Table 13. Comprehensive uncertainty of all results', ...
 'T13_Validation','Table 14. Validation against physical bounds and benchmarks', ...
 'Figure_Index','Table 15. Index of all generated figures');
order = fieldnames(titles);

word = actxserver('Word.Application'); word.Visible=false;
doc = word.Documents.Add; sel = word.Selection;
% title
sel.Font.Size=16; sel.Font.Bold=1;
sel.TypeText('Scientific Tables - The Heat Route to Firm Green Hydrogen'); sel.TypeParagraph;
sel.Font.Size=11; sel.Font.Bold=0;
sel.TypeText('Companion tables to the MATLAB implementation (measured NASA POWER climatology).');
sel.TypeParagraph; sel.TypeParagraph;

for i=1:numel(order)
    key=order{i};
    if ~isfield(TBL,key), continue; end
    C = table2cellstr(TBL.(key));
    % heading
    sel.Font.Bold=1; sel.Font.Size=12;
    sel.TypeText(titles.(key)); sel.TypeParagraph;
    sel.Font.Bold=0; sel.Font.Size=9;
    insertTable(word, doc, sel, C);
    sel.TypeParagraph;
end

if exist(outfile,'file'), delete(outfile); end
doc.SaveAs2(outfile); doc.Close(false); word.Quit;
fprintf('Wrote tables document -> %s\n', outfile);
end

% -------------------------------------------------------------------------
function insertTable(word, doc, sel, C)
% Insert a native Word table from a cell array of strings C (RxK), using
% tab-separated text + ConvertToTable for speed and reliability.
[nr,nc]=size(C);
lines=strings(nr,1);
for r=1:nr
    fields=strings(1,nc);
    for c=1:nc
        t=char(C{r,c}); t=regexprep(t,'[\t\r\n]',' ');
        fields(c)=string(t);
    end
    lines(r)=strjoin(fields, char(9));     % tab-separated
end
block=strjoin(lines, char(13));            % CR between rows
startPos=sel.Range.End;
sel.TypeText(char(block));
endPos=sel.Range.End;
rng=doc.Range(startPos,endPos);
tbl=rng.ConvertToTable(char(9));           % wdSeparateByTabs (the tab char)
tbl.Borders.Enable=1;
tbl.Rows.Item(1).Range.Font.Bold=1;
try, tbl.AutoFitBehavior(2); catch, end    % wdAutoFitWindow
sel.EndKey(6);                             % move to end of story
sel.TypeParagraph;
end

% -------------------------------------------------------------------------
function C = table2cellstr(T)
% Convert a MATLAB table to a cell array of strings (header row + data).
vn = T.Properties.VariableNames;
nr = height(T); nc = numel(vn);
C = cell(nr+1, nc);
C(1,:) = vn;
for c=1:nc
    col = T.(vn{c});
    for r=1:nr
        v = col(r,:);
        if isnumeric(v)
            if v==round(v) && abs(v)<1e5, C{r+1,c}=sprintf('%g',v);
            else, C{r+1,c}=sprintf('%.3g',v); end
        elseif iscell(v)
            C{r+1,c}=char(string(v{1}));
        else
            C{r+1,c}=char(string(v));
        end
    end
end
end
