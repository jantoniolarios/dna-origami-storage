function impact = noiseImpactReport(cleanText, noisyText, noiseReport)
%NOISEIMPACTREPORT  Compara el texto limpio con el recuperado de una cadena dañada.
%
%   impact = NOISEIMPACTREPORT(cleanText, noisyText, noiseReport) calcula y
%   muestra el efecto del ruido, y devuelve una estructura con:
%
%     impact.positionalAccuracy - caracteres correctos en su misma posición
%     impact.editDistance       - distancia de Levenshtein
%     impact.similarity         - 100 * (1 - distancia / longitud mayor)
%     impact.charsBeforeFirstError - caracteres intactos antes del primer fallo
%     impact.lengthChange       - diferencia de longitud entre ambos textos

cleanText = reshape(char(cleanText), 1, []);
noisyText = reshape(char(noisyText), 1, []);

nClean = numel(cleanText);
nNoisy = numel(noisyText);

aligned = repmat(char(0), 1, nClean);
m = min(nClean, nNoisy);
aligned(1:m) = noisyText(1:m);
correct = sum(aligned == cleanText);

[distance, similarity] = levenshtein(noisyText, cleanText);

firstError = find(aligned ~= cleanText, 1);
if isempty(firstError)
    charsBefore = nClean;
else
    charsBefore = firstError - 1;
end

impact = struct( ...
    'positionalAccuracy',     100 * correct / max(1, nClean), ...
    'charsCorrect',           correct, ...
    'charsTotal',             nClean, ...
    'editDistance',           distance, ...
    'similarity',             similarity, ...
    'charsBeforeFirstError',  charsBefore, ...
    'lengthChange',           nNoisy - nClean);

fprintf('\n--- Efecto del ruido ----------------------------\n');
fprintf('Errores introducidos  : %d sustituciones, %d eliminaciones, %d inserciones\n', ...
    noiseReport.substitutions, noiseReport.deletions, noiseReport.insertions);
fprintf('Cadena                : %d nt -> %d nt\n', noiseReport.nIn, noiseReport.nOut);

if noiseReport.totalErrors > 0
    fprintf('Tasa real de error    : %.4f%% de los nucleótidos\n', ...
        100 * noiseReport.totalErrors / max(1, noiseReport.nIn));
end

fprintf('Texto                 : %d -> %d caracteres\n', nClean, nNoisy);
fprintf('Exactitud posicional  : %.2f%%  (%d de %d)\n', ...
    impact.positionalAccuracy, correct, nClean);
fprintf('Similitud (Levenshtein): %.2f%%  (distancia %d)\n', similarity, distance);
fprintf('Intactos hasta el 1er fallo: %d caracteres\n', charsBefore);

indels = noiseReport.deletions + noiseReport.insertions;
if indels > 0
    fprintf(['\nHay %d inserciones o eliminaciones: corren el marco de lectura,\n' ...
             'así que todo lo que viene después del primer indel se lee\n' ...
             'desplazado. Por eso la exactitud posicional cae mucho más que\n' ...
             'la similitud.\n'], indels);
elseif noiseReport.substitutions > 0
    fprintf(['\nSolo hay sustituciones. Cada una daña su propio carácter, pero\n' ...
             'si el codón resultante queda sin símbolo asignado (32 de los 256)\n' ...
             'se descarta al decodificar y el texto posterior se recorre.\n']);
end
fprintf('-------------------------------------------------\n');
end
