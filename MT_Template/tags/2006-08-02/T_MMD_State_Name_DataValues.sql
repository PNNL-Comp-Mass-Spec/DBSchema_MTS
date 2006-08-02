set identity_insert dbo.T_MMD_State_Name on
INSERT INTO dbo.T_MMD_State_Name
  (MD_State, MD_State_Name)
  VALUES (1, N'New')
INSERT INTO dbo.T_MMD_State_Name
  (MD_State, MD_State_Name)
  VALUES (2, N'OK')
INSERT INTO dbo.T_MMD_State_Name
  (MD_State, MD_State_Name)
  VALUES (3, N'ET Err')
INSERT INTO dbo.T_MMD_State_Name
  (MD_State, MD_State_Name)
  VALUES (4, N'ET Bad Fit')
INSERT INTO dbo.T_MMD_State_Name
  (MD_State, MD_State_Name)
  VALUES (5, N'Superseded')
INSERT INTO dbo.T_MMD_State_Name
  (MD_State, MD_State_Name)
  VALUES (6, N'Invalid')
set identity_insert dbo.T_MMD_State_Name off

go
