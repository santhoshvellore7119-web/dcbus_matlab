%% run_project.m
% Simple launcher for the DC-Bus PI Controller Tuning Project.
% Calls main.m to run the end-to-end data-driven pipeline.

function [metricsTable, simResults] = run_project(varargin)
    [metricsTable, simResults] = main(varargin{:});
end
