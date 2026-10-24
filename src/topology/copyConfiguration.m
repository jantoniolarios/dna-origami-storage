function confOut = copyConfiguration(topSource, topOut)
%COPYCONFIGURATION  Copia el .conf de una estructura junto al .top generado.
%
%   confOut = COPYCONFIGURATION(topSource, topOut) busca un archivo .conf con
%   el mismo nombre que topSource y, si existe, lo copia al lado de topOut
%   con el nombre de éste.

confOut = '';

[srcDir, srcStem] = fileparts(topSource);
confSource = fullfile(srcDir, [srcStem '.conf']);

if exist(confSource, 'file') ~= 2
    return
end

[outDir, outStem] = fileparts(topOut);
confOut = fullfile(outDir, [outStem '.conf']);

[ok, msg] = copyfile(confSource, confOut);
if ~ok
    warning('copyConfiguration:failed', ...
        'No se pudo copiar "%s": %s', confSource, msg);
    confOut = '';
end
end
