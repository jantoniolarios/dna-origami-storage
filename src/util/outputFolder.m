function folder = outputFolder()
%OUTPUTFOLDER  Carpeta donde se guardan las estructuras generadas.
%
%   folder = OUTPUTFOLDER() devuelve <raíz>/output y la crea si no existe.

folder = fullfile(projectRoot(), 'output');
if exist(folder, 'dir') ~= 7
    mkdir(folder);
end
end
