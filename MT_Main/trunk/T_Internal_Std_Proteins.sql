if exists (select * from dbo.sysobjects where id = object_id(N'[T_Internal_Std_Proteins]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Internal_Std_Proteins]
GO

CREATE TABLE [T_Internal_Std_Proteins] (
	[Internal_Std_Protein_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Protein_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Protein_ID] [int] NULL ,
	[Protein_Sequence] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[Protein_DB_ID] [int] NULL ,
	CONSTRAINT [PK_T_Internal_Std_Proteins] PRIMARY KEY  CLUSTERED 
	(
		[Internal_Std_Protein_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


