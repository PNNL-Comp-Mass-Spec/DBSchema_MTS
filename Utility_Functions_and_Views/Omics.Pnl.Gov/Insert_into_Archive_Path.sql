-- Lookup by Dataset ID
SELECT 'INSERT INTO archive_path (id, instrument_name, archive_path, note)
VALUES (' + Convert(varchar(12), AP_path_ID) + ',''' + IN_name + ''', ''' + AP_archive_path + 
       ''', ''' + note + ''');'
FROM ( SELECT DISTINCT AP.AP_path_ID,
                       T_Instrument_Name.IN_name,
                       AP.AP_archive_path,
                       AP.Note
       FROM T_Dataset_Archive DA
            INNER JOIN V_Dataset_Detail_Report_Ex DDR
              ON DA.AS_Dataset_ID = DDR.ID
            INNER JOIN T_Experiments E
              ON DDR.Experiment = E.Experiment_Num
            INNER JOIN T_Archive_Path AP
              ON DA.AS_storage_path_ID = AP.AP_path_ID
            INNER JOIN T_Instrument_Name
              ON AP.AP_instrument_name_ID = T_Instrument_Name.Instrument_ID
       WHERE (DDR.ID IN (279303, 279302)) ) LookupQ



INSERT INTO archive_path (id, instrument_name, archive_path, note)  VALUES (1012,'VOrbiETD04', '/archive/dmsarch/VOrbiETD04/2012_3', 'VOrbiETD04');
