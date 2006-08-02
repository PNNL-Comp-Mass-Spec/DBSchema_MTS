INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (1, N'Datafile (.PEK) load error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (2, N'Ini file load error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (4, N'Database mass tag retrieval error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (8, N'UMC search error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (16, N'NET adjustment error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (32, N'DB search error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (64, N'Export results to DB error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (128, N'Tolerance refinement error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (256, N'Save 2D graphic error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (512, N'Save error distribution error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (1024, N'Save chromatogram error')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (2048, N'Number of mass tags with null mass or null NET values is abnormally high')
INSERT INTO dbo.T_Peak_Matching_Error_Bits
  VALUES (4096, N'Pairs-based DB search error')

go
