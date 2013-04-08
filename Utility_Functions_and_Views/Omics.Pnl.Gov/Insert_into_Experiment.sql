-- Lookup by Dataset Name
SELECT 'INSERT INTO experiment (id, experiment_name, created, organism_name, reason, biomaterial_list, campaign_id)
VALUES (' + Convert(varchar(12), id) + ',''' + Experiment + ''', ''' + Convert(varchar(32), created, 120) + ''', ''' + Organism + ''', ''' + reason + ''', ''' + biomaterial_list + ''', ' + Convert(varchar(12), Campaign_ID) + ');'
FROM (
SELECT DISTINCT EDR.ID, EDR.Experiment, EDR.Created, EDR.Organism, EDR.[Reason for Experiment] as reason, EDR.[Cell Cultures] as biomaterial_list, 
    C.Campaign_ID
FROM V_Experiment_Detail_Report_Ex EDR INNER JOIN
    T_Campaign C ON EDR.Campaign = C.Campaign_Num
INNER JOIN T_Dataset DS ON EDR.ID = DS.Exp_ID
WHERE (DS.Dataset_Num IN ('SysVirol_ICL012_Mock_0h_1_Protein_A_12Jun12_Sphinx_12-05-04','SysVirol_ICL012_Mock_0h_1_Protein_B_12Jun12_Sphinx_12-05-04'))
) LookupQ


-- Lookup by Dataset ID
SELECT 'INSERT INTO experiment (id, experiment_name, created, organism_name, reason, biomaterial_list, campaign_id)
VALUES (' + Convert(varchar(12), id) + ',''' + Experiment + ''', ''' + Convert(varchar(32), created, 120) + ''', ''' + Organism + ''', ''' + reason + ''', ''' + biomaterial_list + ''', ' + Convert(varchar(12), Campaign_ID) + ');'
FROM (
SELECT DISTINCT EDR.ID, EDR.Experiment, EDR.Created, EDR.Organism, EDR.[Reason for Experiment] as reason, EDR.[Cell Cultures] as biomaterial_list, 
    C.Campaign_ID
FROM V_Experiment_Detail_Report_Ex EDR INNER JOIN
    T_Campaign C ON EDR.Campaign = C.Campaign_Num
INNER JOIN T_Dataset DS ON EDR.ID = DS.Exp_ID
WHERE (DS.Dataset_ID IN (209001, 208992, 208990, 208986, 208982, 208967, 208961, 208952, 208824, 208748))
) LookupQ


INSERT INTO experiment (id, experiment_name, created, organism_name, reason, biomaterial_list, campaign_id)
VALUES (101975,'topdown_LC', '2011-05-11 12:32:52', 'None', 'method development', '(none)', 2653)