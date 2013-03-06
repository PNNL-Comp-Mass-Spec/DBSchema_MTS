GO
CREATE TABLE [dbo].[T_DDL_Change_Log] 
    ( 
      [Entry_ID] [int] IDENTITY(1, 1) NOT NULL, 
      [Entered] [datetime] NOT NULL 
        CONSTRAINT [DF_ddl_log_Entered]  
            DEFAULT ( GETDATE() ), 
      [Entered_By] [nvarchar](256) NOT NULL 
        CONSTRAINT [DF_T_DDL_Change_Log_Entered_By]   
            DEFAULT ( CONVERT([nvarchar](256), SUSER_SNAME(), ( 0 )) ), 
      [UserName] [nvarchar](256) NOT NULL 
        CONSTRAINT [DF_ddl_log_UserName]   
            DEFAULT ( CONVERT([nvarchar](256), USER_NAME(), ( 0 )) ), 
      [Login_Name] [nvarchar](256) NOT NULL 
        CONSTRAINT [DF_T_DDL_Change_Log_Login_Name]   
            DEFAULT ( CONVERT([nvarchar](256), original_login(),(0)) ), 
      [Event_Type] [nvarchar](256) NULL, 
      [Object] [nvarchar](256) NULL, 
      [Object_Type] [nvarchar](256) NULL, 
      [tsql] [nvarchar](MAX) NULL 
    ) 
ON  [PRIMARY] 

GO

ALTER TABLE dbo.T_DDL_Change_Log ADD CONSTRAINT
	PK_T_DDL_Change_Log PRIMARY KEY CLUSTERED 
	(
	Entry_ID
	)

GO
