if exists (select * from dbo.sysobjects where id = object_id(N'[T_Mass_Defect_Stats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Mass_Defect_Stats]
GO

CREATE TABLE [T_Mass_Defect_Stats] (
	[Sampling_Size] [int] NOT NULL ,
	[Mass_Start] [int] NOT NULL ,
	[Mass_Defect_Bin] [real] NOT NULL ,
	[Bin_Count] [int] NOT NULL ,
	[Query_Date] [datetime] NOT NULL CONSTRAINT [DF_T_Mass_Defect_Stats_Query_Date] DEFAULT (getdate()),
	CONSTRAINT [PK_T_Mass_Defect_Stats] PRIMARY KEY  CLUSTERED 
	(
		[Sampling_Size],
		[Mass_Start],
		[Mass_Defect_Bin]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


