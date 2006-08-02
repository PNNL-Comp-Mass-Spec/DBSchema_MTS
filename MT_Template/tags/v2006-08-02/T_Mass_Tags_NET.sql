if exists (select * from dbo.sysobjects where id = object_id(N'[T_Mass_Tags_NET]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Mass_Tags_NET]
GO

CREATE TABLE [T_Mass_Tags_NET] (
	[Mass_Tag_ID] [int] NOT NULL ,
	[Min_GANET] [real] NULL ,
	[Max_GANET] [real] NULL ,
	[Avg_GANET] [real] NULL ,
	[Cnt_GANET] [int] NULL ,
	[StD_GANET] [real] NULL ,
	[StdError_GANET] [real] NULL ,
	[PNET] [real] NULL ,
	[PNET_Variance] [real] NULL ,
	CONSTRAINT [PK_T_Mass_Tags_NET] PRIMARY KEY  CLUSTERED 
	(
		[Mass_Tag_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Mass_Tags_NET_T_Mass_Tags] FOREIGN KEY 
	(
		[Mass_Tag_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	)
) ON [PRIMARY]
GO


