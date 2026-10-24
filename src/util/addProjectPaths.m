function addProjectPaths()
%ADDPROJECTPATHS  Añade al path de MATLAB las carpetas de código del proyecto.
%
%   ADDPROJECTPATHS() registra src/ y sus subcarpetas.

root = projectRoot();
addpath(genpath(fullfile(root, 'src')));
end
