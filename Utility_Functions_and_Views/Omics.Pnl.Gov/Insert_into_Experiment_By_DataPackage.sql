
SELECT 'INSERT INTO experiment (id, experiment_name, created, organism_name, reason, biomaterial_list, campaign_id)
VALUES (' + Convert(varchar(12), id) + ',''' + Experiment + ''', ''' + Convert(varchar(32), created, 120) + ''', ''' + Organism + ''', ''' + reason + ''', ''' + biomaterial_list + ''', ' + Convert(varchar(12), Campaign_ID) + ');'
FROM (
	SELECT DISTINCT 
	    EDR.ID, EDR.Experiment, EDR.Created, EDR.Organism, EDR.[Reason for Experiment] AS reason, 
	    EDR.[Cell Cultures] AS biomaterial_list, C.Campaign_ID
	FROM V_Experiment_Detail_Report_Ex EDR INNER JOIN
	    T_Campaign C ON EDR.Campaign = C.Campaign_Num INNER JOIN
	    T_Dataset DS ON EDR.ID = DS.Exp_ID
	WHERE (DS.Dataset_Num IN
	        (SELECT dataset
	      FROM S_V_Data_Package_Datasets_Export
	      WHERE data_package_id = 734))
) LookupQ

INSERT INTO experiment (id, experiment_name, created, organism_name, reason, biomaterial_list, campaign_id)  
VALUES (103356,'SysVirol_ICL010_NL602_3moi_0hr_1_protein', '2011-06-30 15:37:20', 'Homo_sapiens', 'To perform quantitative proteomics analyses of Calu-3 cell line infected with H1N1 virus.', '(none)', 2421);