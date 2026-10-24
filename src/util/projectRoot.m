function root = projectRoot()
%PROJECTROOT  Carpeta raíz del repositorio, calculada en tiempo de ejecución.
%
%   root = PROJECTROOT() devuelve la ruta absoluta de la raíz del proyecto
%   deduciéndola de la ubicación de este archivo, no de una ruta fija.

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
end
