function [nt, codonList] = encodeWithTable(text, ref)
%ENCODEWITHTABLE  Codifica texto usando exactamente la tabla de un dataset.
%
%   [nt, codonList] = ENCODEWITHTABLE(text, ref) codifica text a codones de
%   4 nucleótidos, pero solo con los codones presentes en ref.allSource.
%   Devuelve la cadena y la lista de codones.

cb = dnaCodebook();
allowed = containers.Map(ref.allSource, repmat({true}, ref.nTotal, 1));

text = reshape(char(text), 1, []);
codonList = cell(1, numel(text));

n = 0;
for i = 1:numel(text)
    c = double(text(i));
    if c < 1 || c > numel(cb.sym2idx)
        continue
    end
    idx = cb.sym2idx(c);
    if idx == 0
        continue
    end
    codon = cb.codons(idx, :);
    if ~isKey(allowed, codon)
        continue
    end
    n = n + 1;
    codonList{n} = codon;
end

codonList = codonList(1:n);

if n == 0
    nt = '';
else
    nt = reshape(char(codonList).', 1, []);
end
end
