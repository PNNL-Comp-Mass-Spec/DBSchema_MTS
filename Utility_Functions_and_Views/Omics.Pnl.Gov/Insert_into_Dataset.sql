SELECT 'INSERT INTO dataset (id, dataset_name, created, comment, instrument_name, archive_path_id, rating, scan_count, file_size_bytes, experiment_id, archive_file_size_bytes)
VALUES (' + Convert(varchar(12), id) + ',''' + dataset_name + ''', ''' + Convert(varchar(32), created, 120) + ''', ''' + comment + ''', ''' + instrument_name + ''', ' + Convert(varchar(12), archive_path_id) + ', ''' + rating + ''', ' + Convert(varchar(12), scan_count) + ', ' + Convert(varchar(12), file_size_bytes) + ', ' + 
    Convert(varchar(12), experiment_id) + ', ' + Convert(varchar(12), archive_file_size_bytes) + ');'
FROM (SELECT DDR.ID AS id, DDR.Dataset AS dataset_name, DDR.Created AS created, DDR.Comment AS comment, 
          DDR.Instrument AS instrument_name, DA.AS_storage_path_ID AS archive_path_id, DDR.Rating AS rating, 
          DDR.[Scan Count] AS scan_count, convert(bigint, DDR.[File Size (MB)]) * 1024 * 1024 AS file_size_bytes, 
          E.Exp_ID AS experiment_id, convert(bigint, DDR.[File Size (MB)]) * 1024 * 1024 AS archive_file_size_bytes
      FROM T_Dataset_Archive DA INNER JOIN
          V_Dataset_Detail_Report_Ex DDR ON DA.AS_Dataset_ID = DDR.ID INNER JOIN
          T_Experiments E ON DDR.Experiment = E.Experiment_Num
      WHERE (DDR.Dataset IN ('SysVirol_ICL012_Mock_0h_1_Protein_A_12Jun12_Sphinx_12-05-04','SysVirol_ICL012_Mock_0h_1_Protein_B_12Jun12_Sphinx_12-05-04'))) LookupQ


INSERT INTO dataset (id, dataset_name, created, comment, instrument_name, archive_path_id, rating, scan_count, file_size_bytes, experiment_id, archive_file_size_bytes)
VALUES (223687,'test_sample_ETD', 2011-05-17 13:56:52, '', 'VOrbiETD04', 287, 'Released', 8396, 500170752, 101975, 500170752)
