-- Lookup by Job ID
SELECT 'INSERT INTO analysis_job (id, created, analysis_tool_name, results_folder_name, comment, dataset_id, archive_file_size_bytes)
VALUES (' + Convert(varchar(12), AJ_jobID) + ',''' + Convert(varchar(32), AJ_created, 120) + ''', ''' + AJT_toolName + ''', ''' + AJ_comment + ''', ''' + AJ_comment + ''', ' + Convert(varchar(32), AJ_datasetID) + ', ' + Convert(varchar(12), 0) + ');'
FROM (SELECT J.AJ_jobID, J.AJ_created, T.AJT_toolName, J.AJ_resultsFolderName, J.AJ_comment, J.AJ_datasetID, 
    0 AS Archive_File_Size_Bytes
FROM T_Analysis_Job J INNER JOIN
    T_Analysis_Tool T ON J.AJ_analysisToolID = T.AJT_toolID
WHERE (J.AJ_jobID IN (706657, 706658, 706659, 706660, 706661, 706662, 706663, 706664, 706665, 706666, 706667, 706668, 706669, 706670, 706671, 706672, 706673, 706674, 706675, 706676, 706677, 706678, 706679, 706680, 706681, 706682, 706683, 706684, 706685, 706686, 706687, 706688, 706689, 706690, 706691, 706692, 706693, 706694, 706695, 706696, 706697, 706698, 706699, 706700, 706701, 707142, 707143, 707144, 743963, 743964, 743965, 743966, 743967, 743968, 743969, 743970, 743971, 743972, 743973, 743974, 743975, 743976, 743977, 743978, 743979, 743980, 743981, 743982, 743983, 743984, 743985, 743986, 743987, 743988, 743989, 743990, 743991, 743992, 743993, 743994, 743995, 743996, 743997, 743998, 743999, 744000, 744001, 744002, 744003, 744004, 744005, 744006, 744007, 744008, 744009, 744010, 744616, 744617, 744618, 744620, 744621, 744622, 744623, 744624, 744625, 744626, 744627, 744628, 744629, 744630, 744631, 744632, 744633, 744634, 744636, 744637, 744638, 744639, 744640, 744641, 744642, 744643, 744644, 744645, 744646, 744647, 744648, 744649, 744650, 744652, 744653, 744654, 744655, 744656, 744657, 744658, 744659, 744660, 744661, 744662, 744663, 744955, 744956, 744957))) LookupQ


-- Lookup by Data Package ID
SELECT 'INSERT INTO analysis_job (id, created, analysis_tool_name, results_folder_name, comment, dataset_id, archive_file_size_bytes)
VALUES (' + Convert(varchar(12), AJ_jobID) + ',''' + Convert(varchar(32), AJ_created, 120) + ''', ''' + AJT_toolName + ''', ''' + AJ_comment + ''', ''' + AJ_comment + ''', ' + Convert(varchar(32), AJ_datasetID) + ', ' + Convert(varchar(12), 0) + ');'
FROM (SELECT J.AJ_jobID, J.AJ_created, T.AJT_toolName, J.AJ_resultsFolderName, J.AJ_comment, J.AJ_datasetID, 
    0 AS Archive_File_Size_Bytes
FROM T_Analysis_Job J INNER JOIN
    T_Analysis_Tool T ON J.AJ_analysisToolID = T.AJT_toolID
WHERE (J.AJ_jobID IN (SELECT Job
      FROM S_V_Data_Package_Analysis_Jobs_Export
      WHERE data_package_id = 804))) LookupQ


INSERT INTO analysis_job (id, created, analysis_tool_name, results_folder_name, comment, dataset_id, archive_file_size_bytes)
VALUES (777518,'2011-12-19 13:40:37', 'MSAlign', 'Rerun to re-generate results', 'Rerun to re-generate results', 224022, 0);
