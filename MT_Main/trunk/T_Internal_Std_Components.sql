if exists (select * from dbo.sysobjects where id = object_id(N'[T_Internal_Std_Components]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Internal_Std_Components]
GO

CREATE TABLE [T_Internal_Std_Components] (
	[Seq_ID] [int] NOT NULL ,
	[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Peptide] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Monoisotopic_Mass] [float] NOT NULL ,
	[Charge_Minimum] [int] NULL ,
	[Charge_Maximum] [int] NULL ,
	[Charge_Highest_Abu] [int] NULL ,
	[Min_NET] [real] NULL ,
	[Max_NET] [real] NULL ,
	[Avg_NET] [real] NOT NULL ,
	[Cnt_NET] [int] NULL ,
	[StD_NET] [real] NULL ,
	[PNET] [real] NULL ,
	CONSTRAINT [PK_T_Internal_Std_Components] PRIMARY KEY  CLUSTERED 
	(
		[Seq_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


