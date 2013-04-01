SELECT 'INSERT INTO analysis_job (id, created, analysis_tool_name, results_folder_name, comment, dataset_id, archive_file_size_bytes)
VALUES (' + Convert(varchar(12), AJ_jobID) + ',''' + Convert(varchar(32), AJ_created, 120) + ''', ''' + AJT_toolName + ''', ''' + AJ_comment + ''', ''' + AJ_comment + ''', ' + Convert(varchar(32), AJ_datasetID) + ', ' + Convert(varchar(12), 0) + ');'
FROM (SELECT J.AJ_jobID, J.AJ_created, T.AJT_toolName, J.AJ_resultsFolderName, J.AJ_comment, J.AJ_datasetID, 
    0 AS Archive_File_Size_Bytes
FROM T_Analysis_Job J INNER JOIN
    T_Analysis_Tool T ON J.AJ_analysisToolID = T.AJT_toolID
WHERE (J.AJ_jobID IN (777518, 777519))) LookupQ


INSERT INTO analysis_job (id, created, analysis_tool_name, results_folder_name, comment, dataset_id, archive_file_size_bytes)
VALUES (777518,'2011-12-19 13:40:37', 'MSAlign', 'Rerun to re-generate results', 'Rerun to re-generate results', 224022, 0);
