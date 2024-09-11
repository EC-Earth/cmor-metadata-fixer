#!/usr/bin/env python
# Thomas Reerink

# Caculate branch times.

import datetime

branch_time_in_child_piControl  = (datetime.datetime(1850,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_piControl = (datetime.datetime(2259,1,1)-datetime.datetime(1850,1,1)).days  # with (the start date of) EC-Earth3-Veg piContol as parent

branch_time_in_child_historical  = (datetime.datetime(1850,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_historical = (datetime.datetime(2260,1,1)-datetime.datetime(1850,1,1)).days

branch_time_in_child_scenarios  = (datetime.datetime(2015,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_scenarios = (datetime.datetime(2015,1,1)-datetime.datetime(1850,1,1)).days

branch_time_in_child_covidmip  = (datetime.datetime(2020,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_covidmip = (datetime.datetime(2020,1,1)-datetime.datetime(1850,1,1)).days

branch_time_in_child_historical_varex  = (datetime.datetime(2000,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_historical_varex = (datetime.datetime(2000,1,1)-datetime.datetime(1850,1,1)).days

branch_time_in_child_scenarios_varex  = (datetime.datetime(2075,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_scenarios_varex = (datetime.datetime(2075,1,1)-datetime.datetime(1850,1,1)).days

branch_time_in_child_carcyclim  = (datetime.datetime(2022,1,1)-datetime.datetime(1850,1,1)).days
branch_time_in_parent_carcyclim = (datetime.datetime(2022,1,1)-datetime.datetime(1850,1,1)).days


print('The branch_time_in_child  = {:7} for the piControl  KNMI r1i1p1f1 run. '.format(branch_time_in_child_piControl ))
print('The branch_time_in_parent = {:7} for the piControl  KNMI r1i1p1f1 run.'.format(branch_time_in_parent_piControl))

print('The branch_time_in_child  = {:7} for the historical KNMI r1i1p1f1 run. '.format(branch_time_in_child_historical ))
print('The branch_time_in_parent = {:7} for the historical KNMI r1i1p1f1 run. '.format(branch_time_in_parent_historical))

print('The branch_time_in_child  = {:7} for the scenario   KNMI r1i1p1f1 runs.'.format(branch_time_in_child_scenarios ))
print('The branch_time_in_parent = {:7} for the scenario   KNMI r1i1p1f1 runs.'.format(branch_time_in_parent_scenarios))

print('The branch_time_in_child  = {:7} for the covidmip   KNMI r1i1p1f2 runs.'.format(branch_time_in_child_covidmip ))
print('The branch_time_in_parent = {:7} for the covidmip   KNMI r1i1p1f2 runs.'.format(branch_time_in_parent_covidmip))

print('The branch_time_in_child  = {:7} for the historical varex KNMI r1i1p1f1 run. '.format(branch_time_in_child_historical_varex ))
print('The branch_time_in_parent = {:7} for the historical varex KNMI r1i1p1f1 run. '.format(branch_time_in_parent_historical_varex))

print('The branch_time_in_child  = {:7} for the scenario varex  KNMI r1i1p5f1 runs.'.format(branch_time_in_child_scenarios_varex ))
print('The branch_time_in_parent = {:7} for the scenario varex  KNMI r1i1p5f1 runs.'.format(branch_time_in_parent_scenarios_varex))

print('The branch_time_in_child  = {:7} for the carcyclim r1i1p5f1 runs.'.format(branch_time_in_child_carcyclim ))
print('The branch_time_in_parent = {:7} for the carcyclim r1i1p5f1 runs.'.format(branch_time_in_parent_carcyclim))
