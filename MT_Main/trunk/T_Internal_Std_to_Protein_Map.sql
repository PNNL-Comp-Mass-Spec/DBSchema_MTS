if exists (select * from dbo.sysobjects where id = object_id(N'[T_Internal_Std_to_Protein_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Internal_Std_to_Protein_Map]
GO

CREATE TABLE [T_Internal_Std_to_Protein_Map] (
	[Seq_ID] [int] NOT NULL ,
	[Mass_Tag_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Internal_Std_Protein_ID] [int] NOT NULL ,
	[Cleavage_State] [tinyint] NULL ,
	[Fragment_Number] [smallint] NULL ,
	[Fragment_Span] [smallint] NULL ,
	[Residue_Start] [int] NULL ,
	[Residue_End] [int] NULL ,
	[Repeat_Count] [smallint] NULL ,
	[Terminus_State] [tinyint] NULL ,
	CONSTRAINT [PK_T_Internal_Std_to_Protein_Map] PRIMARY KEY  CLUSTERED 
	(
		[Seq_ID],
		[Internal_Std_Protein_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Internal_Std_to_Protein_Map_T_Internal_Std_Proteins] FOREIGN KEY 
	(
		[Internal_Std_Protein_ID]
	) REFERENCES [T_Internal_Std_Proteins] (
		[Internal_Std_Protein_ID]
	)
) ON [PRIMARY]
GO


